import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/customers/customer_form_ops.dart';
import 'package:sipario/screens/customers/customer_form_screen.dart';
import 'package:sipario/screens/customers/customer_widgets.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'support/yetki_yardimcilari.dart';

/// SİPARİO 3.0 müşteri ekranları — liste satırı, bakiye kartı, tahsilat, düzeltme, çoklu telefon,
/// adres bölgesi ve salt-okunur kapısı.
///
/// Widget-test sahte zamanında HER gerçek drift çağrısı `tester.runAsync` içinde beklenir
/// (Dilim 1-3 dersi: düz Future sorgular da asılır). Akışa abone db widget-testte KAPATILMAZ —
/// bellek-içi db süreç sonunda gider. Dar ekranda taşma olmasın diye viewport büyütülür.
/// MÜŞTERİ — DEFTER, TAHSİLAT ve FORM.
///
/// Bölme gerekçesi: `ui_musteri_test.dart` başlığı.
void main() {

  /// Gerçek zamanda birkaç tur bekleyip kare çizer. TEK tur YETMEZ: müşteri detayındaki
  /// StreamBuilder'lar iç içedir (müşteri → telefon/adres → defter); içteki akış ancak
  /// dıştaki veri gösterildikten SONRA abone olur, yani her katman kendi turunu ister.
  Future<void> akislariBekle(WidgetTester tester, {int tur = 4}) async {
    for (var i = 0; i < tur; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump();
    }
  }

  /// Test ağacı: gerçek tema (jetonlar ThemeExtension'dan gelsin) + geniş viewport.
  Future<void> ekranaKoy(WidgetTester tester, Widget ekran) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: SipTheme.acik(), home: ekran));
    await akislariBekle(tester);
  }

  /// Kapanış: ağacı boşalt + bekleyen zamanlayıcılar (toast/parıltı) sönsün.
  Future<void> kapat(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  /// Müşteri formunu (sheet) tek başına açar — liste ekranının arama kutusu ağaca karışmasın,
  /// böylece `find.byType(TextField)` sırası formun kendi alanlarıdır: ad · telefon(lar) ·
  /// adres · bölge · not.
  Future<void> formuAc(WidgetTester tester, AppDatabase db) async {
    await ekranaKoy(
      tester,
      Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => musteriEkleSheet(ctx, db: db),
              child: const Text('AÇ'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('AÇ'));
    await tester.pumpAndSettle();
  }

  /// Kaydet düğmesine basıp asenkron yazmanın (mükerrer sorgusu + repo) bitmesini bekler.
  Future<void> kaydetVeBekle(WidgetTester tester, String etiket) async {
    await tester.tap(find.text(etiket));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  group('Defter (CSS .dhar — HAREKET_META etiketleri)', () {
    testWidgets('etiketler tasarımın dört sözcüğü: Borç · Tahsilat · Alacak · Düzeltme',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String id;
      await tester.runAsync(() async {
        id = await CustomerRepository(db).create(name: 'Dört Hareket');
        final ledger = LedgerRepository(db);
        await ledger.borcEkle(id, 10000);
        await ledger.tahsilat(id, 2000, 'nakit');
        await ledger.alacak(id, 1000);
      });

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));

      expect(find.text('Borç'), findsOneWidget);
      expect(find.text('Tahsilat'), findsWidgets, reason: 'hızlı eylemde de aynı sözcük var');
      expect(find.text('Alacak'), findsOneWidget);
      // Tasarımda olmayan iki etiket:
      expect(find.text('Sipariş borcu'), findsNothing);
      expect(find.text('Alacak / indirim'), findsNothing);

      await kapat(tester);
    });

    testWidgets('hareket satırına dokunmak ters kayıt AÇMAZ (tasarımda .dhar tıklanmaz)',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String id;
      await tester.runAsync(() async {
        id = await CustomerRepository(db).create(name: 'Dokunulmaz Defter');
        await LedgerRepository(db).borcEkle(id, 4500);
      });

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));

      await tester.tap(find.text('Borç'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Ters kayıtla düzelt'), findsNothing);
      // APPEND-ONLY değişmedi: kaynak satır yerinde, hiçbir kayıt eklenmedi/silinmedi.
      late List<LedgerEntry> hepsi;
      await tester.runAsync(() async {
        hepsi = await (db.select(db.ledgerEntries)..where((e) => e.customerId.equals(id))).get();
      });
      expect(hepsi, hasLength(1));

      await kapat(tester);
    });
  });

  group('Tahsilat tutarı (çip TAM LİRA, alan KURUŞ — s-musteriler.jsx:88,160-161)', () {
    testWidgets('"Yarısı" TAM LİRAYA yuvarlar: 85,50 ₺ borçta 43', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String id;
      await tester.runAsync(() async {
        id = await CustomerRepository(db).create(name: 'Küsuratlı Borç');
        await LedgerRepository(db).borcEkle(id, 8550);
      });

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));
      await tester.tap(find.text('Tahsilat'));
      await tester.pumpAndSettle();

      final alan = find.byType(TextField).first;
      // Ön dolgu açık borcun TAMAMI, kuruşuyla: "borcu tam kapat" en sık iştir ve kart/havale
      // tahsilatında kuruş gerçektir (payment_type nakit|kart|havale).
      expect(tester.widget<TextField>(alan).controller?.text, '85,50');

      await tester.tap(find.text('Yarısı'));
      await tester.pump();
      expect(tester.widget<TextField>(alan).controller?.text, '43',
          reason: 'çip bir KISAYOL: Math.round(8550/200) = 43 — 42,75 değil');

      // Kuruş YAZILABİLİR: ayraç süzülmez, TR yazımını `parseKurus` çözer.
      await tester.enterText(alan, '12,34');
      await tester.pump();
      expect(tester.widget<TextField>(alan).controller?.text, '12,34');

      await kapat(tester);
    });
  });

  group('Müşteri formu (CSS .ym-*)', () {
    testWidgets('telefon alanı eklenip silinebilir (en çok 3)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await formuAc(tester, db);

      // Açılışta: ad · telefon · adres · bölge · not
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text('Telefon ekle (1/3)'), findsOneWidget);

      await tester.tap(find.text('Telefon ekle (1/3)'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(5));
      expect(find.text(trBuyuk('Telefon 2')), findsOneWidget);
      expect(find.text('Telefon ekle (2/3)'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Telefonu sil'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text(trBuyuk('Telefon 2')), findsNothing);

      await kapat(tester);
    });

    testWidgets('aynı numara başka müşteride varsa uyarı çıkar, kayıt olmaz', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CustomerRepository(db).create(
            name: 'Ayşe Yılmaz',
            phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)]);
      });
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(0), 'Yeni Kişi');
      await tester.enterText(find.byType(TextField).at(1), '0532 111 22 33');
      await tester.pump();
      await kaydetVeBekle(tester, 'Müşteriyi Kaydet');

      expect(find.text('Bu numara zaten kayıtlı: Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Müşteriyi Kaydet'), findsOneWidget, reason: 'sheet açık kalmalı');

      late List<Customer> hepsi;
      await tester.runAsync(() async {
        hepsi = await db.select(db.customers).get();
      });
      expect(hepsi.map((c) => c.name), ['Ayşe Yılmaz'], reason: 'mükerrer kayıt yazılmaz');

      await kapat(tester);
    });

    testWidgets('aynı numarayı iki alana yazmak HATA DEĞİL (sessizce tekilleşir)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await formuAc(tester, db);

      await tester.tap(find.text('Telefon ekle (1/3)'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Tek Numara');
      await tester.enterText(find.byType(TextField).at(1), '0532 111 22 33');
      await tester.enterText(find.byType(TextField).at(2), '0532 111 22 33');
      await tester.pump();
      await kaydetVeBekle(tester, 'Müşteriyi Kaydet');

      // Tasarım mükerreri yalnız KAYITLI müşterilerde arar (s-musteriler.jsx:241-245).
      expect(find.text('Bu numarayı zaten yazdınız'), findsNothing);

      late List<CustomerPhone> telefonlar;
      await tester.runAsync(() async {
        telefonlar = await db.select(db.customerPhones).get();
      });
      expect(telefonlar, hasLength(1), reason: 'aynı numara bir kez yazılır');
      expect(telefonlar.single.phoneE164, '+905321112233');

      await kapat(tester);
    });

    testWidgets('düzenleme sheet\'inde de Konum Al VAR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late Customer musteri;
      late List<CustomerPhone> telefonlar;
      late CustomerAddressesData adres;
      await tester.runAsync(() async {
        final id = await CustomerRepository(db).create(
          name: 'Düzenlenen',
          phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)],
          addresses: [AddressInput(addressText: 'Bahçe Sk. no:5', region: 'Kepez', isPrimary: true)],
        );
        musteri = await (db.select(db.customers)..where((c) => c.id.equals(id))).getSingle();
        telefonlar = await db.select(db.customerPhones).get();
        adres = await db.select(db.customerAddresses).getSingle();
      });

      await ekranaKoy(
        tester,
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => musteriDuzenleSheet(ctx,
                    db: db, musteri: musteri, telefonlar: telefonlar, adres: adres),
                child: const Text('AÇ'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('AÇ'));
      await tester.pumpAndSettle();

      expect(find.text('Değişiklikleri Kaydet'), findsOneWidget, reason: 'düzenleme sheet\'i açık');
      expect(find.text(trBuyuk('Adres')), findsOneWidget);
      // KULLANICI KARARI DEĞİŞTİ (2026-07-29): "müşteri bilgisi düzenlerken konum aldır
      // çıkmıyor". Önceki davranış tasarım dosyasını izliyordu (`MusteriDuzenle` düz etiket
      // gösteriyordu, s-musteriler.jsx:353) ve konumun tek yolu müşteri DETAYIYDI. Sahada
      // tutmadı: adres yanlışsa bayi zaten düzenleme ekranındadır ve konumu orada almak ister.
      // Tasarım dosyası ölçü/renk çatışmalarında bağlayıcıdır; bu bir ÜRÜN kararıdır.
      expect(find.text('Konum Al'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('yeni müşteri sheet\'inde de Konum Al DURUYOR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await formuAc(tester, db);

      expect(find.text('Konum Al'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('formda BÖLGE ALANI YOK; adres tek başına kaydedilir', (tester) async {
      // 2026-07-28 kullanıcı kararı: "Bölge'ye gerek yok, tamamen kaldır". Semt/ilçe adres
      // metninin içine yazılır — iki alan aynı bilgiyi iki kez soruyordu.
      final db = AppDatabase(NativeDatabase.memory());
      await formuAc(tester, db);

      expect(find.text(trBuyuk('Bölge')), findsNothing, reason: 'alan tamamen kalkmalı');
      expect(find.bySemanticsLabel('Sesle yaz (Bölge)'), findsNothing,
          reason: 'kalkan alanın mikrofonu da kalkmalı');

      await tester.enterText(find.byType(TextField).at(0), 'Adresli Kişi');
      await tester.enterText(find.byType(TextField).at(1), '0532 999 88 77');
      await tester.enterText(find.byType(TextField).at(2), 'Bahçe Sk. no:5, Kepez');
      await tester.pump();
      await kaydetVeBekle(tester, 'Müşteriyi Kaydet');

      late CustomerAddressesData adres;
      await tester.runAsync(() async {
        adres = await db.select(db.customerAddresses).getSingle();
      });

      expect(adres.addressText, 'Bahçe Sk. no:5, Kepez');
      // Kolon şemada DURUYOR (senkronlanan bir kolonu düşürmek eski kayıtları siler) ama
      // yeni kayıtlarda artık HİÇ doldurulmaz.
      expect(adres.region, isNull);

      await kapat(tester);
    });
  });

  group('Form yardımcıları (saf)', () {
    test('normalizePhoneTR üç yazımı da E.164 yapar', () {
      expect(normalizePhoneTR('0532 111 22 33'), '+905321112233');
      expect(normalizePhoneTR('5321112233'), '+905321112233');
      expect(normalizePhoneTR('+90 532 111 22 33'), '+905321112233');
      expect(normalizePhoneTR('12345'), isNull);
    });

    // trBuyuk/trKucuk paylaşılan katmanındır — sağlaması ui_temel_test.dart'ta durur, burada
    // tekrarlanmaz (iki kopya = biri düzeltilip diğeri unutulur).

    // BÖLGE KALDIRILDI (2026-07-28): `adresGosterimi` artık yalnız adres metnini döner.
    // Boş/whitespace `null` döner ki çağıran satırı hiç çizmesin — tek başına "—" gösterilmez.
    test('adresGosterimi boş adresi null yapar, doluyu kırpar', () {
      expect(adresGosterimi('Bahçe Sk. no:5'), 'Bahçe Sk. no:5');
      expect(adresGosterimi('  Bahçe Sk. no:5  '), 'Bahçe Sk. no:5');
      expect(adresGosterimi(''), isNull);
      expect(adresGosterimi('   '), isNull);
      expect(adresGosterimi(null), isNull);
    });

    test('tutarGirdisi kuruşu ayrıştırılabilir metne çevirir', () {
      expect(tutarGirdisi(12345), '123,45');
      expect(tutarGirdisi(10000), '100,00');
    });
  });

  group('mukerrerTelefonSahibi (aynı numara iki müşteride olamaz)', () {
    test('kayıtlı numaranın sahibini döner, kendi kaydını saymaz', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CustomerRepository(db);
      final id = await repo.create(
          name: 'Ayşe Yılmaz',
          phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)]);

      expect(await mukerrerTelefonSahibi(db, '+905321112233'), 'Ayşe Yılmaz');
      expect(await mukerrerTelefonSahibi(db, '+905321112233', haricCustomerId: id), isNull);
      expect(await mukerrerTelefonSahibi(db, '+905339998877'), isNull);
    });
  });

  group('konumKaydet (adresi bozmadan koordinat ekler)', () {
    test('adres metni ve bölge korunur, lat/lng yazılır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await CustomerRepository(db).create(
        name: 'Konumlu',
        addresses: [
          AddressInput(
              addressText: 'Bahçe Sk. no:5', region: 'Kepez', label: 'Ev', isPrimary: true),
        ],
      );

      final once = await db.select(db.customerAddresses).getSingle();
      await konumKaydet(db, once, 36.8969, 30.7133);
      final sonra = await db.select(db.customerAddresses).getSingle();

      expect(sonra.lat, 36.8969);
      expect(sonra.lng, 30.7133);
      expect(sonra.addressText, 'Bahçe Sk. no:5');
      expect(sonra.region, 'Kepez');
      expect(sonra.label, 'Ev');
      expect(sonra.isPrimary, isTrue);
    });
  });
}
