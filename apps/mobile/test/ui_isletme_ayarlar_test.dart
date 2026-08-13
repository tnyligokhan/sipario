import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/exempt_number_repository.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:sipario/screens/cagri/arayan_tanima_ayari.dart';
import 'package:sipario/screens/cagri/cagri_gunlugu.dart';
import 'package:sipario/screens/isletme/ayarlar/bildirim_ayarlari_ekrani.dart';
import 'package:sipario/screens/isletme/ayarlar/hakkinda_ekrani.dart';
import 'package:sipario/screens/isletme/ayarlar/isletme_ayarlari_ekrani.dart';
import 'package:sipario/screens/isletme/ayarlar/uygulama_ayarlari_ekrani.dart';
import 'package:sipario/screens/isletme/ayarlar_ekrani.dart';
import 'package:sipario/screens/isletme/isletme_profili_ekrani.dart';
import 'package:sipario/screens/isletme/kuryeler_ekrani.dart';
import 'package:sipario/screens/isletme/muaf_ekrani.dart';
import 'package:sipario/screens/products/product_list_screen.dart';
import 'package:sipario/subscription/subscription_locked_screen.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/ekran_yardimcilari.dart';
import 'support/yetki_yardimcilari.dart';

/// SİPARİO 3.0 AYAR/YÖNETİM ekranları — muaf telefonlar, işletme profili, kuryeler, ayarlar,
/// abonelik kilidi. Ürünler ve Gün Sonu `ui_isletme_test.dart` içinde kaldı; dosya 500 satır
/// sınırını aşınca bölündü ve paylaşılan yardımcılar `support/ekran_yardimcilari.dart`a taşındı.
/// Ekrandan bağımsız kurallar `isletme_kurallari_test.dart` içinde.
void main() {
  // Ayarlar ekranındaki arayan tanıma satırı gerçek deposuyla platform kanalına (sqflite
  // dizini) uzanır; widget testinde bellek deposuyla değiştirilir ve geri alınır.
  setUp(() {
    final eski = arayanTanimaDeposu;
    arayanTanimaDeposu = ArayanTanimaDeposu.bellek();
    addTearDown(() => arayanTanimaDeposu = eski);
  });
  // ═════════════════════════════════════════════════════════════════════════════════════════
  group('Muaf telefonlar', () {
    testWidgets('eklenen numara DB\'ye yazılır ve listede görünür', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ExemptNumberRepository(db);

      await ekranaKoy(tester, MuafEkrani(db: db));
      expect(find.text('Muaf numara yok'), findsOneWidget);

      await tester.tap(find.text('Muaf numara ekle'));
      await sheetAnimasyonu(tester);

      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'Kurye Ali');
      await tester.enterText(alanlar.at(1), '05324152290');
      await tester.pump();
      await dokun(tester, find.text('Listeye Ekle'));
      await sheetAnimasyonu(tester);

      // Kalıcılık: bellekte değil, exempt_numbers tablosunda.
      final muafMi = await tester.runAsync(() => repo.isExempt('+905324152290'));
      expect(muafMi, isTrue,
          reason: 'çağrı kartı kapısı bu tabloya bakar — kayıt oraya düşmeli');

      expect(find.text('Kurye Ali'), findsOneWidget);
      expect(find.text(sipTelefon('05324152290')), findsOneWidget);
      expect(find.text('1 numara · çağrı kartı çıkmaz'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('bilgi notu "Caller ID kartı açılmaz" vurgusunu taşır, boş durum tek satır',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, MuafEkrani(db: db));

      // `SipNotKutusu.onEtiket` kalın parçayı metnin başına alır (tema kilitli: cümle ORTASINDA
      // kalınlaştırma yok) — ama vurgulanan cümle tasarımın cümlesidir.
      expect(find.textContaining('Caller ID kartı açılmaz.'), findsOneWidget);
      expect(find.textContaining('Kurye, tedarikçi, kişisel numaralar'), findsOneWidget);
      expect(find.text('Muaf numara yok'), findsOneWidget);
      expect(find.textContaining('Eklediğiniz numaralar'), findsNothing,
          reason: 'boş durum açıklaması üstteki notu kelime kelime tekrar ediyordu');

      await kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  group('İşletme profili', () {
    testWidgets('kaydedilen profil tenant_settings\'ten geri okunur', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = TenantSettingsRepository(db);

      await ekranaKoy(tester, IsletmeProfiliEkrani(db: db));

      // Alan sırası: ad · sahip · telefon · whatsapp · adres · vergi dairesi · vergi no ·
      // açılış · kapanış · fiş notu.
      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'Merkez Bayi');
      await tester.enterText(alanlar.at(1), 'Gökhan Tonyalı');
      await tester.enterText(alanlar.at(2), '0242 111 22 33');
      await tester.enterText(alanlar.at(4), 'Muratpaşa / Antalya');
      await tester.pump();

      await dokun(tester, find.text('Kaydet'));

      final satir = await tester.runAsync(() => repo.get());
      expect(satir, isNotNull, reason: 'profil tek satır (id=1) olarak kalıcıdır');
      expect(satir!.businessName, 'Merkez Bayi');
      expect(satir.ownerName, 'Gökhan Tonyalı');
      expect(satir.phone, '0242 111 22 33');
      expect(satir.addressText, 'Muratpaşa / Antalya');
      expect(satir.opensAt, '08:00');
      expect(satir.closesAt, '19:00');
      expect(satir.whatsapp, isNull, reason: 'boş bırakılan alan null yazılır');

      await kapat(tester);
    });

    testWidgets('IBAN alıcı adı ve mesaj şablonu görünür, kaydedilir; çip imlece jeton ekler',
        (tester) async {
      // Kullanıcı isteği 2026-08-06. Alanlar `_alan` sırasına göre: … iban(9) · ibanAlici(10) ·
      // sablon(11) · fisNotu(12).
      final db = AppDatabase(NativeDatabase.memory());
      final repo = TenantSettingsRepository(db);

      await ekranaKoy(tester, IsletmeProfiliEkrani(db: db));

      // Alanların VARLIĞI etiketleriyle kanıtlanır: alan sırasına dayanan bir test, araya bir
      // alan eklendiğinde sessizce başka bir alanı sınamaya başlardı.
      expect(find.text('IBAN ALICI ADI'), findsOneWidget);
      expect(find.text('Hatırlatma Mesajı'), findsOneWidget);
      // Bayi yer tutucuları EZBERLEMEK zorunda kalmamalı — ekranda dururlar.
      expect(find.text('Müşteri adı'), findsOneWidget);
      expect(find.text('IBAN + alıcı'), findsOneWidget);

      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'Merkez Bayi');
      await tester.enterText(alanlar.at(1), 'Gökhan Tonyalı');
      await tester.enterText(alanlar.at(2), '0242 111 22 33');
      await tester.enterText(alanlar.at(10), 'Mehmet Yılmaz');
      await tester.enterText(alanlar.at(11), 'Sayın ');
      await tester.pump();

      // Çip: imleç (enterText sonrası metnin SONUNDA) konumuna jeton eklenir.
      await dokun(tester, find.text('Müşteri adı'));
      expect(tester.widget<TextField>(alanlar.at(11)).controller!.text, 'Sayın *musteriadi*');

      await dokun(tester, find.text('Kaydet'));

      final satir = await tester.runAsync(() => repo.get());
      expect(satir!.ibanOwnerName, 'Mehmet Yılmaz');
      expect(satir.reminderTemplate, 'Sayın *musteriadi*');

      await kapat(tester);
    });

    testWidgets('şablonu boş bırakmak varsayılana döner — null yazılır, boş dize değil',
        (tester) async {
      // null ile boş dize AYRI şeyler olsaydı, boşaltılan şablon "özel metin var ama boş" diye
      // okunur ve borçluya BOŞ bir WhatsApp mesajı hazırlanırdı.
      final db = AppDatabase(NativeDatabase.memory());
      final repo = TenantSettingsRepository(db);

      await ekranaKoy(tester, IsletmeProfiliEkrani(db: db));

      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'Merkez Bayi');
      await tester.enterText(alanlar.at(1), 'Gökhan Tonyalı');
      await tester.enterText(alanlar.at(2), '0242 111 22 33');
      await tester.pump();
      await dokun(tester, find.text('Kaydet'));

      final satir = await tester.runAsync(() => repo.get());
      expect(satir!.reminderTemplate, isNull);
      expect(satir.ibanOwnerName, isNull);

      await kapat(tester);
    });

    testWidgets('zorunlu alanlar yıldızlı; fiş notunda ikinci etiket yok', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, IsletmeProfiliEkrani(db: db));

      // Tasarım `s-isletme.jsx:32,35,40` — yıldız olmadan zorunluluk ancak Kaydet'e basıp hata
      // alınca öğreniliyordu.
      expect(find.text('İŞLETME ADI *'), findsOneWidget);
      expect(find.text('YETKİLİ *'), findsOneWidget);
      expect(find.text('TELEFON *'), findsOneWidget);
      expect(find.text('WHATSAPP HATTI'), findsOneWidget,
          reason: 'opsiyonel alan yıldız TAŞIMAZ — işaret ayırt edici olmalı');
      expect(find.text('FİŞ NOTU'), findsNothing,
          reason: 'bölüm başlığı "Fiş Alt Notu" zaten aynı şeyi söylüyor (tasarımda etiket yok)');

      await kapat(tester);
    });

    testWidgets('FİŞ ALANI PASİF ve "Çok yakında" işaretli; adres fiş VAAT ETMEZ',
        (tester) async {
      // Kullanıcı kararı 2026-08-13. `receipt_note` kolonu var, form yazıyor, senkron taşıyor
      // — ama onu OKUYAN hiçbir yer yok: uygulamada fiş/teslim belgesi diye bir çıktı
      // üretilmiyor. Alan normal görünümde kaldığı sürece ürün tutmayacağı bir söz veriyordu:
      // bayi doldurur, kaydeder, sonucunu hiçbir yerde göremez.
      //
      // BU TEST GERİ AÇILMAYI ENGELLER: fiş özelliği gelince alan bilinçli olarak açılacak ve
      // bu test o gün BİLEREK güncellenecek. Kilit olmasaydı, alan bir refactor sırasında
      // sessizce yazılabilir hâle döner ve aynı yanlış söz geri gelirdi.
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, IsletmeProfiliEkrani(db: db));

      expect(find.text('Çok yakında'), findsOneWidget);
      expect(find.text('Fiş Alt Notu'), findsOneWidget,
          reason: 'bölüm görünür kalır — özellik geliyor, kaldırılmıyor');

      // Alan PASİF: rozet tek başına yetmez, yazılabilir bırakmak aynı sözü kibarca vermektir.
      final fisAlani = find.widgetWithText(SipInput, 'Teslim fişi özelliğiyle birlikte açılacak');
      expect(tester.widget<SipInput>(fisAlani).aktif, isFalse);

      // ADRES İPUCU ARTIK FİŞ VAAT ETMİYOR (eskiden "Dükkân adresi (fişte görünür)").
      expect(find.text('Dükkân adresi'), findsOneWidget);
      expect(find.textContaining('fişte görünür'), findsNothing);

      await kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  group('Kuryeler', () {
    testWidgets('liste ad ve telefonu gösterir, pasif kuryeyi işaretler', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre', telefon: '05324152290');
        await kuryeEkle(db, id: 'k2', ad: 'Ali', durum: 'disabled');
        await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
      });

      await ekranaKoy(tester, KuryelerEkrani(db: db));

      expect(find.text('1 aktif · 2 kayıtlı'), findsOneWidget,
          reason: 'patron listeye girmez — bu ekran yalnız kuryeleri yönetir');
      expect(find.text('Emre'), findsOneWidget);
      expect(find.text(sipTelefon('05324152290')), findsOneWidget);
      expect(find.text('Telefon yok'), findsOneWidget);
      expect(find.text('PASİF'), findsOneWidget);
      expect(find.text('Patron'), findsNothing);

      await kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  group('Mağaza kuralı ve rol kapıları', () {
    // ⚠️ TARAMA BEŞ SAYFAYI DA KAPSAR (2026-08-13). Ayarlar tek uzun listeden hub + beş sayfaya
    // bölündü; tarama eski hâlinde kalsaydı yalnız HUB'ı gezecekti — yani mağaza kuralını
    // koruyan test, kuralın geçerli olduğu yüzeyin beşte dördünü görmez hâle gelirdi. Bölünme,
    // taramanın kapsamını daraltmak için bir bahane değildir.
    const yasakliSozcukler = [
      'Abone',
      'Satın al',
      'Üye ol',
      'Kayıt ol',
      'Kaydol',
      'Ödeme yap',
      'Fiyat',
      '₺',
    ];

    void yasakliAra(String sayfa) {
      for (final yasak in yasakliSozcukler) {
        expect(find.textContaining(yasak), findsNothing,
            reason: '"$yasak" mobilde $sayfa sayfasında gösterilemez');
      }
    }

    testWidgets('AYARLARIN BEŞ SAYFASINDA da abonelik/ödeme/satın alma sözcüğü GEÇMEZ',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      // 1) Hub
      await ekranaKoy(tester, AyarlarEkrani(db: db, rol: 'patron', yetki: tamYetki));
      yasakliAra('Ayarlar');
      await kapat(tester);

      // 2) İşletme
      await ekranaKoy(tester, IsletmeAyarlariEkrani(db: db, writable: true));
      yasakliAra('İşletme');
      await kapat(tester);

      // 3) Uygulama
      await ekranaKoy(tester, const UygulamaAyarlariEkrani());
      yasakliAra('Uygulama');
      await kapat(tester);

      // 4) Bildirimler
      await ekranaKoy(tester, const BildirimAyarlariEkrani());
      yasakliAra('Bildirimler');
      await kapat(tester);

      // 5) Hakkında — lisans/sürüm burada yaşıyor, yani kuralın en çok zorlandığı sayfa.
      await ekranaKoy(tester, HakkindaEkrani(db: db));
      yasakliAra('Hakkında');

      // Lisans NÖTR bilgi olarak durabilir.
      expect(find.text('Lisans'), findsOneWidget);

      // SÜRÜM SATIRI ARTIK SABİT METİN DEĞİL — APK'dan okunuyor (`package_info_plus`), yapı
      // numarası da git commit sayısından türüyor. Eski hâli `'Sipario 3.2'` sabitiydi ve
      // APK'daki gerçek sürümle hiçbir bağı yoktu; testin o sabiti kilitlemesi, yalanı
      // kilitlemek anlamına geliyordu. Artık kilitlenen şey ikisi:
      //   1) satırın VAR olması (mağaza kuralı gereği lisans/sürüm bilgisi nötr biçimde durur),
      //   2) platform kanalı YOKKEN bile çökmeden çizilmesi — test ortamında `PackageInfo`
      //      çözülemez ve nötr 'Sipario'ya düşer. Bu düşüş yolu ürünü de korur: iOS'ta ya da
      //      eklenti kaydı eksikken ayarlar ekranının tamamı bir sürüm satırı yüzünden
      //      açılamaz hâle gelemez (LateInitializationError dersi, 2026-07-27).
      expect(find.text('Sürüm'), findsOneWidget);
      expect(find.textContaining('Sipario'), findsOneWidget,
          reason: 'sürüm satırı çizilmeli — platform kanalı yoksa nötr metne düşer');

      await kapat(tester);
    });

    // AYARLAR ARTIK BİR HUB'DIR (2026-08-13): beş kategori satırı, her biri kendi sayfası.
    // Eski test "tasarımın dört bölümü"nü kilitliyordu; o prototip bildirimler, sipariş kodu,
    // kurye yetkileri ve hesap kavramı yokken çizilmişti ve uygulama onu çoktan aşmıştı.
    // Kilitlenen şey artık kategori kümesidir — ve hub'ın İÇERİK TAŞIMADIĞI.
    testWidgets('Ayarlar bir HUB: beş kategori satırı, gövdede ayar YOK', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(
        tester,
        AyarlarEkrani(db: db, rol: 'patron', yetki: tamYetki, onOlcumler: () {}),
      );

      for (final kategori in ['İşletme', 'Uygulama', 'Bildirimler', 'Hakkında']) {
        expect(find.text(kategori), findsOneWidget, reason: '$kategori kategorisi hub\'da VAR');
      }

      // HUB İÇERİK TAŞIMAZ: ayarın kendisi sayfasında yaşar. Hub hem menü hem içerik olsaydı,
      // bölmenin tek sebebi olan "her tür kendi yerinde" kuralı ilk günden delinirdi.
      expect(find.text('Koyu tema'), findsNothing);
      expect(find.text('Lisans'), findsNothing);
      expect(find.text('Gecikme ölçümleri'), findsNothing);

      // Yönetim girişleri ÇEKMECEDE — iki giriş noktası olmaz.
      expect(find.text('Kuryeler'), findsNothing);
      expect(find.text('Muaf telefonlar'), findsNothing);
      // ÇAĞRI GEÇMİŞİ AYARLARDAN ÇIKTI (kullanıcı tespiti): bir iş kaydıdır, tercih değil.
      expect(find.text('Çağrı Geçmişi'), findsNothing);

      await kapat(tester);
    });

    testWidgets('İŞLETME satırı yalnız PATRONDA çizilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, AyarlarEkrani(db: db, rol: 'kurye', yetki: tamYetki));

      expect(find.text('İşletme'), findsNothing,
          reason: 'kalıcı kapalı kapı gösterilmez — pasif satır değil, hiç satır');
      expect(find.text('Uygulama'), findsOneWidget, reason: 'kendi cihaz tercihleri açık kalır');

      await kapat(tester);
    });

    // Faz 0 ölçüm ekranı tasarımda YOK ama silinemez: çağrı kartının 1 SANİYELİK bütçesini
    // (BRIEF kırmızı çizgisi) ölçen tek araç orası. Girişi tamamen kaldırınca ekran hiçbir
    // yerden açılamaz hâle geldi, o yüzden `kDebugMode` ile geri kondu. Test sürümü debug
    // derlemesidir; üretim derlemesinde satır hiç derlenmez.
    testWidgets('Gecikme ölçümleri satırı geliştirme derlemesinde VAR ve ekranı açar',
        (tester) async {
      var acildi = false;

      // Satır UYGULAMA sayfasına taşındı (2026-08-13 bölünmesi); hub yalnız kategori taşır.
      await ekranaKoy(
        tester,
        UygulamaAyarlariEkrani(onOlcumler: () => acildi = true),
      );

      expect(find.text('Gecikme ölçümleri'), findsOneWidget,
          reason: 'ölü dal bırakmıyoruz: araç geliştirme derlemesinde erişilebilir kalmalı');
      expect(find.textContaining('yalnız geliştirme derlemesi'), findsOneWidget,
          reason: 'satır neden koşullu olduğunu kendi altyazısında söylüyor');

      await tester.tap(find.text('Gecikme ölçümleri'));
      await tester.pump();
      expect(acildi, isTrue);

      await kapat(tester);
    });

    // "Arayan Tanıma öbeği çağrı geçmişini açar" TESTİ BURADAN KALDIRILDI (2026-08-13):
    // çağrı geçmişinin girişi artık ÇEKMECEDE. Kapsam kaybolmadı, iki parçaya ayrıldı:
    //   • Girişin ayarlarda OLMADIĞI → yukarıdaki "Ayarlar bir HUB" testi.
    //   • Girişin çekmecede olduğu ve doğru hedefi açtığı → `ui_kabuk_test.dart`
    //     ("İŞ bölümü menüden ulaşılamayan üç ekranı taşır").
    // Testi silmek yerine taşımak şart: bu depoda bir ekranın girişi bir kez kayboldu ve
    // ekran aylarca ölü kaldı.

    // Geçmiş satırı çağrı ANINDAKİ eşleşmeyi taşır (`call_logs.customer_id`). Arayan o çağrıdan
    // SONRA müşteri olarak kaydedilmişse satır hâlâ "kayıtsız" der; kayıt durumu bu yüzden
    // dokunma anında `cagriKisiCoz` ile yeniden çözülür. Eskiden burada koşulsuz
    // `CagriKisi.kayitsiz` geçiliyordu ve borçlu bir müşteri bile kartta kayıtsız görünüyordu.
    testWidgets('geçmişte kayıtsız görünen numara, sonradan kaydedildiyse defteri açar',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CustomerRepository(db).create(
          name: 'Sonradan Kaydedilen',
          phones: [PhoneInput(phoneE164: '+905324152290')],
        );
        // Çağrı kaydı O ANDA eşleşmemişti: customerId NULL.
        await db.into(db.callLogs).insert(CallLogsCompanion.insert(
              id: 'cl1',
              phoneE164: '+905324152290',
              phoneLast10: '5324152290',
              direction: 'in',
              occurredAt: '2026-07-26T09:00:00Z',
              updatedOccurredAt: '2026-07-26T09:00:00Z',
            ));
      });

      // AKIŞ KABUĞA TAŞINDI (2026-08-13): çağrı geçmişi artık çekmeceden açılıyor ve arama
      // satırına dokunma mantığı `HomeShell._aramayiAc`ta yaşıyor. Ekran burada DOĞRUDAN
      // kurulur ve kabuğun geri çağrımı taklit EDİLMEZ — taklit etseydik test kendi sahte
      // kodunu doğrulardı. Sınanan şey `CagriGunluguSayfasi`nin satırı çizmesi ve dokunuşu
      // dışarı bildirmesi; "kayıtlıysa defter açılır" kararının kendisi kabuk testindedir.
      String? acilanNumara;
      await ekranaKoy(
        tester,
        CagriGunluguSayfasi(
          db: db,
          onGeri: () {},
          onAc: (arama) async => acilanNumara = arama.numara,
        ),
      );

      // Satır numarayla çizilir (kayıt anında eşleşme yoktu, `call_logs.customer_id` NULL).
      final satir = find.text(sipTelefon('+905324152290'));
      expect(satir, findsOneWidget, reason: 'geçmiş satırı kayıtsız gibi görünüyor — beklenen');
      await dokun(tester, satir);
      await akislariBekle(tester);

      expect(acilanNumara, '+905324152290',
          reason: 'satır dokunuşu numarayı olduğu gibi dışarı bildirir');

      await kapat(tester);
    });

    // Kilit ekranı: NÖTR kalmalı (Apple 3.1.3(f) / Google Play) ama çıkışsız duvar da olmamalı —
    // salt-okunur kipte mevcut kayıtlar OKUNABİLİR, tasarım bunun için "Kayıtları Görüntüle"
    // düğmesini koyuyor (`s-giris.jsx:69`).
    testWidgets('abonelik kilidi: tasarım metni + Kayıtları Görüntüle, satın alma çağrısı YOK',
        (tester) async {
      var goruntulendi = false;

      await ekranaKoy(
        tester,
        Scaffold(
          body: SubscriptionLockedScreen(
            bitis: DateTime(2026, 6, 30),
            onKayitlar: () => goruntulendi = true,
          ),
        ),
      );

      expect(find.text('Aboneliğiniz sona erdi'), findsOneWidget);
      expect(find.textContaining('salt-okunur kipte'), findsOneWidget);
      expect(find.textContaining('işletme yöneticinizle görüşün'), findsOneWidget);
      expect(find.text('Bitiş: 30 Haziran 2026'), findsOneWidget);

      for (final yasak in ['Abone ol', 'Satın al', 'Üye ol', 'Kaydol', 'Ödeme yap', '₺']) {
        expect(find.textContaining(yasak), findsNothing,
            reason: '"$yasak" kilit ekranında gösterilemez (mağaza kuralı)');
      }

      await tester.tap(find.text('Kayıtları Görüntüle'));
      await tester.pump();
      expect(goruntulendi, isTrue, reason: 'düğme kabuğa geri dönüşü bildirir');

      await kapat(tester);
    });

    testWidgets('abonelik kilidi: kabuk geri dönüş vermezse düğme çizilmez', (tester) async {
      await ekranaKoy(tester, const Scaffold(body: SubscriptionLockedScreen()));

      expect(find.text('Kayıtları Görüntüle'), findsNothing,
          reason: 'rota sahibi kabuktur; işini yapamayacak düğme çizilmez');
      expect(find.textContaining('Bitiş:'), findsNothing,
          reason: 'bitiş bilinmiyorsa uydurma tarih basılmaz');

      await kapat(tester);
    });

    testWidgets('kurye rolü Ürünler / Kuryeler / Muaf ekranlarını göremez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      for (final ekran in <Widget>[
        ProductListScreen(db: db, writable: true, rol: 'kurye'),
        KuryelerEkrani(db: db, rol: 'kurye'),
        MuafEkrani(db: db, rol: 'kurye'),
      ]) {
        await ekranaKoy(tester, ekran);
        expect(find.text('Bu ekran yöneticilere açık'), findsOneWidget,
            reason: '${ekran.runtimeType} kurye rolünde kapalı olmalı (K2)');
        expect(find.text('Yeni ürün ekle'), findsNothing);
        await kapat(tester);
      }
    });

    testWidgets('yönetici rolünde Kuryeler ekranı açılır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, KuryelerEkrani(db: db, rol: 'operator'));
      expect(find.text('Bu ekran yöneticilere açık'), findsNothing);
      // Liste boşken ayrı bir boş-durum bloğu YOK (tasarımda yok): bilgi notu hem neden boş
      // olduğunu hem nereden doldurulacağını söylüyor.
      expect(find.text('Kayıtlı kurye yok'), findsNothing);
      expect(
        find.textContaining('yönetim panelinden açılır'),
        findsOneWidget,
        reason: 'kurye EKLENEMEZ kısıtı ekranda açıkça yazılı olmalı — düğme yerine cümle',
      );
      expect(find.text('Yeni kurye ekle'), findsNothing,
          reason: 'repo kullanıcı oluşturamaz; işini yapamayacak düğme çizilmez');

      await kapat(tester);
    });
  });
}
