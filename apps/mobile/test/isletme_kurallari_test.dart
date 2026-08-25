import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/tr_gun.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/isletme/ayarlar_ekrani.dart';
import 'package:sipario/screens/isletme/gun_kapatma_sheet.dart';
import 'package:sipario/screens/isletme/isletme_profili_ekrani.dart';
import 'package:sipario/screens/isletme/kuryeler_ekrani.dart';
import 'package:sipario/screens/isletme/muaf_ekrani.dart';
import 'package:sipario/screens/barkod/barkod_kamera.dart' show barkodKabulEt;
import 'package:sipario/screens/orders/order_queries.dart' show katalogSuz;
import 'package:sipario/screens/products/product_form_sheet.dart';
import 'package:sipario/screens/sihirbaz/izin_adimlari.dart';

/// İŞLETME ekranlarının EKRANDAN BAĞIMSIZ kuralları: form doğrulamaları ve para invariantları.
/// Widget çizimi `ui_isletme_test.dart` içinde — doğrulama mantığı saf fonksiyonlarda tutulduğu
/// için burada sahte zaman, viewport ve akış zamanlaması olmadan sınanır.
void main() {
  // Barkod ikonu artık KAMERAYI açar (2026-07-26 kullanıcı kararı: "okuduğu barkodu direkt
  // inputa yazsın"). Kameranın kendisi cihaz işidir ve buradan sınanamaz; sınanabilir olan
  // KABUL KURALI, yani kameradan çıkan ham metnin ne zaman alana yazılacağıdır.
  group('barkodKabulEt — okunan kodun kapısı', () {
    test('rakam ve en az 8 hane olan kod kabul edilir', () {
      expect(barkodKabulEt('8690123456789'), '8690123456789');
      expect(barkodKabulEt('12345678'), '12345678');
      expect(barkodKabulEt('  8690123456789  '), '8690123456789',
          reason: 'okuyucu baş/son boşluk döndürebilir');
    });

    test('kısa kod ve boş girdi reddedilir', () {
      // Form da en az 8 hane ister; okuyucu alana form'un reddedeceği bir şey yazmamalı.
      expect(barkodKabulEt('1234567'), isNull);
      expect(barkodKabulEt(''), isNull);
      expect(barkodKabulEt('   '), isNull);
      expect(barkodKabulEt(null), isNull);
    });

    // HARFLİ kodun rakamları AYIKLANMAZ. "AB12345678"den "12345678" üretmek sessizce yanlış
    // ürüne bağlanmış bir barkod demektir ve o barkod sonra yanlış fiyat keser — hiç
    // okumamak daha güvenlidir.
    test('harf içeren kod reddedilir, rakamları ayıklanmaz', () {
      expect(barkodKabulEt('AB12345678'), isNull);
      expect(barkodKabulEt('8690-1234-5678'), isNull);
      expect(barkodKabulEt('https://ornek/12345678'), isNull);
    });
  });

  // POS süzgeci sipariş katmanının dosyasında yaşar ama BURADA sınanır: aynı özelliğin
  // (barkod okuma) diğer yarısıdır ve `ui_siparis_test.dart` 500 satır sınırının üstünde.
  group('katalogSuz — okutulan barkod ürünü bulur', () {
    Product urun(String ad, {String? barkod}) => Product(
          id: ad,
          name: ad,
          unitPriceKurus: 1000,
          unit: 'adet',
          barcode: barkod,
          isActive: true,
          updatedOccurredAt: '2026-07-26T00:00:00Z',
        );

    final katalog = [
      urun('Damacana 19 L', barkod: '8690123456789'),
      urun('Pet Su 1,5 L', barkod: '8690987654321'),
      urun('Bardak Su', barkod: null),
    ];

    // Asıl gerileme: okuyucu kodu arama alanına yazar; süzgeç yalnız ADA baksaydı okuma
    // başarılıyken katalog "sonuç yok" derdi.
    test('barkodla arandığında o ürün gelir', () {
      final bulunan = katalogSuz(katalog, '8690123456789');
      expect(bulunan.map((u) => u.name), ['Damacana 19 L']);
    });

    test('adla arama çalışmaya devam eder ve büyük/küçük harf gözetmez', () {
      expect(katalogSuz(katalog, 'pet').map((u) => u.name), ['Pet Su 1,5 L']);
      expect(katalogSuz(katalog, 'SU').map((u) => u.name),
          ['Pet Su 1,5 L', 'Bardak Su'],
          reason: 'büyük harfli sorgu küçük harfli adları bulmalı');
    });

    test('boş sorgu tüm kataloğu verir, eşleşmeyen kod boş liste', () {
      expect(katalogSuz(katalog, '   ').length, katalog.length);
      expect(katalogSuz(katalog, '1111111111111'), isEmpty);
    });

    // Barkodu olmayan ürün, barkod sorgusunda null'a takılıp patlamamalı.
    test('barkodsuz ürün barkod sorgusunda sessizce elenir', () {
      expect(katalogSuz(katalog, '8690').map((u) => u.name),
          ['Damacana 19 L', 'Pet Su 1,5 L']);
    });
  });

  group('Ürün formu', () {
    test('barkod ve görsel alanları kolonlara yazılır; düzenleme imageUrl\'i silmez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ProductRepository(db);
      final id = await repo.create(
        name: 'Damacana',
        unitPriceKurus: 4500,
        barcode: '8690123456789',
        imageUrl: 'https://cdn.example/damacana.webp',
        imageLocalPath: '/veri/urun/damacana.jpg',
      );

      var urun = await (db.select(db.products)..where((t) => t.id.equals(id))).getSingle();
      expect(urunBarkodu(urun), '8690123456789');
      expect(urunGorseli(urun), '/veri/urun/damacana.jpg',
          reason: 'cihaz-yerel dosya sunucu işaretçisinin önüne geçer');

      // Ekranın yaptığının aynısı: `update` TÜM alanları yazar, imageUrl geri verilmezse silinir.
      await repo.update(
        id,
        name: 'Damacana 19 L',
        unitPriceKurus: 5000,
        barcode: '8690123456789',
        imageUrl: urun.imageUrl,
        imageLocalPath: urun.imageLocalPath,
      );

      urun = await (db.select(db.products)..where((t) => t.id.equals(id))).getSingle();
      expect(urun.imageUrl, 'https://cdn.example/damacana.webp');
      expect(urun.barcode, '8690123456789');

      await db.close();
    });
  });

  group('Gün sonu', () {
    test('kasa toplamı nakit + kart + havale toplamına eşittir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final musteriler = CustomerRepository(db);
      final siparisler = OrderRepository(db);

      Future<void> teslim(String ad, int kurus, String tip) async {
        final cid = await musteriler.create(name: ad);
        final oid = await siparisler.create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: kurus, qty: 1)],
        );
        await siparisler.deliver(oid, paymentType: tip);
      }

      await teslim('Nakitçi', 4500, 'nakit');
      await teslim('Kartlı', 12000, 'kart');
      await teslim('Havaleci', 7500, 'havale');

      final kasa = (await gunSonuOzeti(db, bugunTr())).kasa;

      expect(kasa.nakit, 4500);
      expect(kasa.kart, 12000);
      expect(kasa.havale, 7500);
      expect(kasa.toplam, kasa.nakit + kasa.kart + kasa.havale,
          reason: 'toplam ayrı hesaplanmaz, üç kalemin toplamıdır');
      expect(kasa.toplam, 24000);

      await db.close();
    });

    test('kapanış arşive donar ve aynı kapsam bir daha açılmaz', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(name: 'Ayşe');
      final siparisler = OrderRepository(db);
      final oid = await siparisler.create(
        customerId: cid,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1)],
      );
      await siparisler.deliver(oid, paymentType: 'nakit');

      final kapanislar = DayClosingRepository(db);
      expect(await kapanislar.kapaliMi(ClosingScope.day), isFalse);

      await kapanislar.kapat(scope: ClosingScope.day, countedCashKurus: 4500);

      expect(await kapanislar.kapaliMi(ClosingScope.day), isTrue);
      final arsiv = await kapanislar.watchArchive().first;
      expect(arsiv, hasLength(1));
      expect(arsiv.single.cashNakitKurus, 4500);
      expect(arsiv.single.totalCollectedKurus, 4500);
      expect(arsiv.single.diffKurus, 0);

      await db.close();
    });
  });

  group('Kasa devri', () {
    test('fark ≠ 0 devri ENGELLEMEZ; fark kanıt olarak kaydedilir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k1',
            name: 'Emre',
            role: 'kurye',
            status: 'active',
          ));

      final cid = await CustomerRepository(db).create(name: 'Ayşe');
      final siparisler = OrderRepository(db);
      final oid = await siparisler.create(
        customerId: cid,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2)],
      );
      await siparisler.deliver(oid, paymentType: 'nakit', collectedByUserId: 'k1');

      final devirler = CashHandoverRepository(db);
      expect((await devirler.onizle('k1')).expectedKurus, 9000);

      // 500 kuruş EKSİK sayıldı — BRIEF: eksik para görünür kalır, devir engellenmez.
      final id = await devirler.devret(fromUserId: 'k1', countedCashKurus: 8500);

      final kayit =
          await (db.select(db.cashHandovers)..where((t) => t.id.equals(id))).getSingle();
      expect(kayit.countedCashKurus, 8500);
      expect(kayit.expectedCashKurus, 9000);
      expect(kayit.diffKurus, -500,
          reason: 'eksik para silinmez, farkla birlikte deftere yazılır');

      await db.close();
    });
  });

  // AYRI kasa devri EKRANI kaldırıldı; DAVRANIŞ kalmalı. Kanıt burada: kurye hesabını kapatmak
  // `cash_handovers`a bir satır YAZAR (`DayClosingRepository.kapat(alsoHandover: true)` yolu,
  // `day_end_screen.dart` kurye kapsamında bunu geçiriyor). Bu test kırmızıya dönerse ekranı
  // kaldırırken devir kaydını da kaybetmişiz demektir.
  group('Kurye kapanışı kasa devrini YAZAR (ekran kaldırıldı, davranış durdu mu?)', () {
    test('kurye kapanışı → cash_handovers satırı; gün kapanışı → YAZMAZ', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.users).insert(
          UsersCompanion.insert(id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));

      // BEKLENEN NAKİT ATIFTAN GELİR: `CashHandoverRepository` yalnız `collected_by = k1` olan
      // nakit tahsilatları sayar, `collected_by` da OTURUMDAN (`sync_meta.user_id`) yazılır.
      // Oturum kurulmadan yazılan tahsilat kimseye atfedilmez (collected_by null) → beklenen 0
      // çıkar ve fark "+4500 fazla" olur. Kurgunun eksik parçası buydu; repo doğru davranıyor.
      await db.syncState(); // meta satırı (id=1) hazır olsun
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
          const SyncMetaCompanion(userId: Value('k1'), userRole: Value('kurye')));

      final custId = await CustomerRepository(db).create(name: 'Nakitçi');
      await LedgerRepository(db).tahsilat(custId, 5000, 'nakit'); // collected_by = k1

      final kapanislar = DayClosingRepository(db);
      await kapanislar.kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 4500,
        alsoHandover: true, // ekranın kurye kapsamında geçirdiği bayrak
      );

      final devirler = await db.select(db.cashHandovers).get();
      expect(devirler, hasLength(1),
          reason: 'kurye kapanışı devir kaydını da yazar — ayrı ekran gitti, kayıt gitmedi');
      expect(devirler.single.fromUserId, 'k1');
      expect(devirler.single.countedCashKurus, 4500);
      expect(devirler.single.expectedCashKurus, 5000,
          reason: 'beklenen nakit = k1\'in topladığı nakit (atıf `collected_by` üzerinden)');
      expect(devirler.single.diffKurus, 4500 - 5000,
          reason: 'fark = sayılan − beklenen; eksik para kanıt olarak devir kaydında durur');

      // Gün hesabı kapanışı bir KURYE devri değildir: fiziksel kasayı kimse kimseye devretmiyor.
      await kapanislar.kapat(scope: ClosingScope.day, countedCashKurus: 0);
      expect(await db.select(db.cashHandovers).get(), hasLength(1),
          reason: 'gün kapanışı devir satırı üretmez');
    });
  });

  group('Muaf numara doğrulaması', () {
    test('kısa numara reddedilir, mükerrer kayıt son 10 haneden yakalanır', () {
      expect(muafNumaraHatasi('0532 415 22 90', mevcutSon10: const []), isNull);
      expect(muafNumaraHatasi('532415', mevcutSon10: const []),
          'Geçerli telefon girin (10-11 hane)');
      // Ülke kodu / baştaki sıfır farkı yutulur — native taraf da aynı anahtara bakar.
      expect(
        muafNumaraHatasi('+90 532 415 22 90', mevcutSon10: const ['5324152290']),
        'Bu numara zaten muaf listesinde',
      );
    });

    // Sınır METİNLE TUTARLI olmalı: kapı 13 haneye kadar kabul ederken hata "10-11 hane" diyordu.
    test('sınır hata metniyle tutarlıdır: ülke kodu ayıklanır, fazlası reddedilir', () {
      expect(muafNumaraHatasi('+905324152290', mevcutSon10: const []), isNull,
          reason: 'ülke kodlu giriş 12 hanedir ama 90 ayıklanınca 10 haneye iner');
      expect(muafNumaraHatasi('053241522901', mevcutSon10: const []),
          'Geçerli telefon girin (10-11 hane)',
          reason: '12 hane ve ülke kodu değil → metnin söylediği gibi reddedilir');
    });
  });

  group('Arşiv zaman etiketi (gunSaatBicimi)', () {
    // Arşiv çok günlüdür; yalnız saat basılınca iki farklı günün kapanışı aynı görünüyordu.
    // TR +03:00 sabit offset — gün sınırı kuralıyla aynı.
    //
    // REFERANS GÜN ARTIK PARAMETREDİR (inceleme bulgusu 2026-08-06): imza `{DateTime? simdi}`
    // iken boş bırakılan çağrılar CİHAZ saatine düşüyordu, oysa kaydın GÜNÜ düzeltilmiş saatten
    // çıkıyor. Çağıran artık düzeltilmiş TR takvim gününü VERMEK ZORUNDA.
    final bugun = trGunu(DateTime.utc(2026, 7, 26, 15, 5)); // TR 26.07, saat 18:05

    test('bugün / dün / öncesi ayrı biçimlenir', () {
      expect(gunSaatBicimi('2026-07-26T15:05:00Z', bugun: bugun), 'Bugün 18:05');
      expect(gunSaatBicimi('2026-07-25T06:20:00Z', bugun: bugun), 'Dün 09:20');
      expect(gunSaatBicimi('2026-07-20T15:05:00Z', bugun: bugun), '20.07 18:05');
    });

    test('TR gün sınırı: UTC 22:30 ERTESİ gündür (yerel 01:30)', () {
      expect(gunSaatBicimi('2026-07-25T22:30:00Z', bugun: bugun), 'Bugün 01:30',
          reason: 'UTC günü 25 ama TR günü 26 — kapanış TR gününe göre okunur');
    });

    test('çözülemeyen değer olduğu gibi döner (uydurma tarih basılmaz)', () {
      expect(gunSaatBicimi('bozuk', bugun: bugun), 'bozuk');
    });
  });

  group('Lisans satırı (lisansMetni)', () {
    SyncMetaData meta({String? bitis, int hak = 0, int aylik = 0}) => SyncMetaData(
          id: 1,
          lastPulledSeq: 0,
          serverTimeOffsetMs: 0,
          snapshotDone: true,
          validUntilIso: bitis,
          routeCredits: hak,
          routeCreditsMonthly: aylik,
        );

    test('gün + oto sıralama hakkı birlikte yazılır (tasarım s-ayarlar.jsx:50)', () {
      expect(
        lisansMetni(
          meta(bitis: '2026-08-05T00:00:00Z', hak: 34, aylik: 50),
          simdi: DateTime.utc(2026, 7, 26),
        ),
        '10 gün kaldı, oto sıralama 34 hak',
      );
    });

    test('özellik KAPALIYKEN (aylık 0) kontör parçası hiç yazılmaz', () {
      expect(
        lisansMetni(
          meta(bitis: '2026-08-05T00:00:00Z', hak: 0),
          simdi: DateTime.utc(2026, 7, 26),
        ),
        '10 gün kaldı',
        reason: 'kapalı bayide "0 hak" görmek özelliği var sanmaya yol açardı',
      );
    });

    test('süre dolmuşsa NÖTR salt-okunur bilgisi; bitiş bilinmiyorsa uydurulmaz', () {
      expect(
        lisansMetni(
          meta(bitis: '2026-07-01T00:00:00Z'),
          simdi: DateTime.utc(2026, 7, 26),
        ),
        'Süre doldu, yeni kayıt eklenemiyor',
      );
      expect(lisansMetni(null), 'Durum bilinmiyor');
      expect(lisansMetni(meta()), 'Durum bilinmiyor');
    });
  });

  group('Sihirbaz izin adımları', () {
    // Liste eskiden cihaza göre uzayıp kısalıyordu (MIUI'de +1 adım, SDK≤33'te kilit adımı yok):
    // karşılamadaki "N izin isteyeceğiz" 5/6/7 oynuyor, "Adım 3/6" iki telefonda farklı izni
    // gösteriyordu. Tasarımın dizisi (`s-sihirbaz.jsx:3-10`) SABİT altı adımdır.
    test('altı SABİT adım, tasarımdaki sırayla', () {
      expect(
        izinAdimlari.map((i) => i.anahtar).toList(),
        ['tarama', 'rehber', 'overlay', 'bildirim', 'kilit', 'pil'],
      );
      expect(izinAdimlari.where((i) => i.anahtar == 'miui'), isEmpty,
          reason: 'Xiaomi adımı tasarımda YOK (CSS .xiaomi-toggle de ölüydü)');
    });

    test('zorunlu izinler yalnız kartı çizen ikisi', () {
      expect(izinAdimlari.where((i) => i.zorunlu).map((i) => i.anahtar).toList(),
          ['tarama', 'overlay']);
    });

    test('bildirim gerekçesi tasarımın cümlesidir (anlam kayması regresyonu)', () {
      final bildirim = izinAdimlari.firstWhere((i) => i.anahtar == 'bildirim');
      expect(bildirim.neden,
          'Yeni sipariş ve borç hatırlatmalarını size iletebilmek için',
          reason: 'kilit ekranı gerekçesi buraya yazılmıştı — o ayrı bir adımın işi');
      expect(izinAdimlari.firstWhere((i) => i.anahtar == 'kilit').neden,
          'Telefon kilitliyken bile çağrı kartının çıkması için');
    });
  });

  group('İşletme profili doğrulaması', () {
    final gecerli = {
      'ad': 'Merkez Bayi',
      'sahip': 'Gökhan Tonyalı',
      'telefon': '0242 111 22 33',
      'whatsapp': '',
      'vergiNo': '',
      'acilis': '08:00',
      'kapanis': '19:00',
    };

    test('geçerli form hata üretmez', () {
      expect(isletmeProfilHatalari(gecerli), isEmpty);
    });

    test('zorunlu alanlar ve biçimler yakalanır', () {
      expect(isletmeProfilHatalari({...gecerli, 'ad': 'M'}), contains('ad'));
      expect(isletmeProfilHatalari({...gecerli, 'sahip': ''}), contains('sahip'));
      expect(isletmeProfilHatalari({...gecerli, 'telefon': '242111'}), contains('telefon'));
      expect(isletmeProfilHatalari({...gecerli, 'whatsapp': '532'}), contains('whatsapp'));
      expect(isletmeProfilHatalari({...gecerli, 'vergiNo': '123'}), contains('vergiNo'));
      expect(isletmeProfilHatalari({...gecerli, 'kapanis': '25:00'}), contains('saat'),
          reason: '25 geçerli bir saat değil');
      expect(isletmeProfilHatalari({...gecerli, 'acilis': '8:00'}), contains('saat'),
          reason: 'biçim SS:DD — tek haneli saat kabul edilmez');
    });
  });

  group('Kurye formu doğrulaması', () {
    const emre =
        User(id: 'k1', name: 'Emre', role: 'kurye', status: 'active', username: 'emre');
    const ali = User(id: 'k2', name: 'Ali', role: 'kurye', status: 'disabled', username: 'ali');

    test('geçerli form hata üretmez', () {
      expect(
        kuryeFormHatalari(
            ad: 'Emre', telefon: '', aktif: true, duzenlenenId: 'k1', tumKuryeler: [emre, ali]),
        isEmpty,
      );
    });

    // GİRİŞ BİLGİLERİ (2026-08-04) — kurallar sunucudakiyle aynı; buradaki kapı, bayiyi bir ağ
    // turu bekletip sonra hayal kırıklığına uğratmamak için var.
    test('kullanıcı adı boş bırakılabilir ama bozuk girilemez', () {
      Map<String, String> ile(String? k) => kuryeFormHatalari(
          ad: 'Emre',
          telefon: '',
          aktif: true,
          duzenlenenId: 'k1',
          tumKuryeler: [emre],
          kullaniciAdi: k);

      // Boş = "dokunma". Eski bir sunucudan gelen ayna kaydında bu alan boştur ve o cihazda
      // kuryenin ADINI düzenlemek de kilitlenmemeli.
      expect(ile(''), isEmpty);
      expect(ile('   '), isEmpty);

      expect(ile('ab'), contains('kullaniciAdi'), reason: '3 karakterden kısa');
      expect(ile('boşluk var'), contains('kullaniciAdi'));
      expect(ile('emre@bayi'), contains('kullaniciAdi'), reason: '@ izinli karakter değil');
      expect(ile('emre.usta_2-x'), isEmpty);
      // Büyük harf REDDEDİLMEZ: kaydederken küçültülür (sunucu da öyle yapar).
      expect(ile('EMRE'), isEmpty);
    });

    test('parola boş bırakılabilir ama 4 karakterden kısa olamaz', () {
      Map<String, String> ile(String? p) => kuryeFormHatalari(
          ad: 'Emre',
          telefon: '',
          aktif: true,
          duzenlenenId: 'k1',
          tumKuryeler: [emre],
          parola: p);

      // Boş alan bir parola DEĞİLDİR — formu her açan kuryenin parolasını sıfırlamamalı.
      expect(ile(''), isEmpty);
      expect(ile('123'), contains('parola'));
      expect(ile('1111'), isEmpty);
    });

    test('ad kısa ya da mükerrer olamaz (Türkçe harf duyarlı)', () {
      expect(
        kuryeFormHatalari(
            ad: 'E', telefon: '', aktif: true, duzenlenenId: 'k1', tumKuryeler: [emre]),
        contains('ad'),
      );

      // trKucuk: 'İ' → 'i'. Dart'ın yerelden bağımsız toLowerCase()i 'i̇' üretip eşleşmeyi kaçırırdı.
      const ismet =
          User(id: 'k3', name: 'İsmet', role: 'kurye', status: 'active', username: 'ismet');
      expect(
        kuryeFormHatalari(
            ad: 'İSMET', telefon: '', aktif: true, duzenlenenId: 'k1', tumKuryeler: [ismet]),
        contains('ad'),
      );
    });

    test('telefon boş bırakılabilir ama yarım girilemez', () {
      expect(
        kuryeFormHatalari(
            ad: 'Emre', telefon: '532', aktif: true, duzenlenenId: 'k1', tumKuryeler: [emre]),
        contains('telefon'),
      );
    });

    test('son aktif kurye pasife alınamaz', () {
      expect(
        kuryeFormHatalari(
            ad: 'Emre', telefon: '', aktif: false, duzenlenenId: 'k1', tumKuryeler: [emre, ali]),
        contains('aktif'),
        reason: 'atama hedefi kalmazsa sipariş ekranı kilitlenir',
      );
    });
  });
}
