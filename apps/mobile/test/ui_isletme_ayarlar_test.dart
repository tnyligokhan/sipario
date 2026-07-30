import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/exempt_number_repository.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:sipario/screens/cagri/arayan_tanima_ayari.dart';
import 'package:sipario/screens/cagri/cagri_gunlugu.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/isletme/ayarlar_ekrani.dart';
import 'package:sipario/screens/isletme/isletme_profili_ekrani.dart';
import 'package:sipario/screens/isletme/kuryeler_ekrani.dart';
import 'package:sipario/screens/isletme/muaf_ekrani.dart';
import 'package:sipario/screens/products/product_list_screen.dart';
import 'package:sipario/subscription/subscription_locked_screen.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/ekran_yardimcilari.dart';

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
    testWidgets('Ayarlar ekranında abonelik/ödeme/satın alma sözcüğü GEÇMEZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, AyarlarEkrani(db: db, rol: 'patron'));

      // Apple 3.1.3(f) / Google Play: mobilde kayıt · üyelik · fiyat · abonelik · ödeme YOK.
      for (final yasak in [
        'Abone',
        'Satın al',
        'Üye ol',
        'Kayıt ol',
        'Kaydol',
        'Ödeme yap',
        'Fiyat',
        '₺',
      ]) {
        expect(find.textContaining(yasak), findsNothing,
            reason: '"$yasak" mobil ayarlar ekranında gösterilemez');
      }

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

    // Tasarım (`s-ayarlar.jsx`) DÖRT bölüm taşır: Görünüm · Arayan Tanıma · İşletme · Hakkında.
    // Fazlalıkların hepsi tek testte kilitli, çünkü hepsi aynı hatanın örneğiydi: uygulamada
    // olup tasarımda olmayan satır, ya ikinci bir giriş noktası ya da ölü bir anahtar üretiyordu.
    testWidgets('Ayarlar yalnız tasarımın dört bölümünü taşır (Yönetim/Xiaomi YOK)',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, AyarlarEkrani(db: db, rol: 'patron'));

      for (final bolum in ['Görünüm', 'Arayan Tanıma', 'İşletme', 'Hakkında']) {
        expect(find.text(bolum), findsOneWidget, reason: '$bolum bölümü tasarımda VAR');
      }
      expect(find.text('Yönetim'), findsNothing,
          reason: 'Kuryeler/Muaf girişleri ÇEKMECEDE — iki giriş noktası olmaz');
      expect(find.text('Kuryeler'), findsNothing);
      expect(find.text('Muaf telefonlar'), findsNothing);
      expect(find.textContaining('Xiaomi'), findsNothing,
          reason: 'MIUI ek izni satırı ölüydü: anahtar hiçbir şeyi kalıcılaştırmıyordu');
      // Kabuk `onOlcumler` geçirmezse satır hiç çizilmez — bağlanmamış bir tanı aracı için
      // menüde yer tutmaz.
      expect(find.text('Gecikme ölçümleri'), findsNothing);

      await kapat(tester);
    });

    // Faz 0 ölçüm ekranı tasarımda YOK ama silinemez: çağrı kartının 1 SANİYELİK bütçesini
    // (BRIEF kırmızı çizgisi) ölçen tek araç orası. Girişi tamamen kaldırınca ekran hiçbir
    // yerden açılamaz hâle geldi, o yüzden `kDebugMode` ile geri kondu. Test sürümü debug
    // derlemesidir; üretim derlemesinde satır hiç derlenmez.
    testWidgets('Gecikme ölçümleri satırı geliştirme derlemesinde VAR ve ekranı açar',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      var acildi = false;

      await ekranaKoy(
        tester,
        AyarlarEkrani(db: db, rol: 'patron', onOlcumler: () => acildi = true),
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

    testWidgets('Arayan Tanıma öbeği çağrı geçmişini açar', (tester) async {
      // Çağrı geçmişinin TEK giriş noktası burası (ana ekrandaki "Son Arama" kutusunun
      // dokunma davranışı tasarımda zaten dolu) — bağlantı kopmasın diye sınanıyor.
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, AyarlarEkrani(db: db, rol: 'patron'));
      expect(find.text('Çağrı Geçmişi'), findsOneWidget);

      await tester.tap(find.text('Çağrı Geçmişi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await akislariBekle(tester);

      expect(find.byType(CagriGunluguSayfasi), findsOneWidget);

      await kapat(tester);
    });

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

      await ekranaKoy(tester, AyarlarEkrani(db: db, rol: 'patron'));
      await dokun(tester, find.text('Çağrı Geçmişi'));
      await sheetAnimasyonu(tester);

      // Satır numarayla çizilir (kayıt anında eşleşme yoktu, `call_logs.customer_id` NULL).
      final satir = find.text(sipTelefon('+905324152290'));
      expect(satir, findsOneWidget, reason: 'geçmiş satırı kayıtsız gibi görünüyor — beklenen');
      await dokun(tester, satir);
      await sheetAnimasyonu(tester);

      expect(find.byType(CustomerDetailScreen), findsOneWidget,
          reason: 'numara artık defterde: kart yerine müşteri defteri açılır (s-uygulama.jsx:90)');

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
