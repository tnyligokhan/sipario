import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/screens/customers/customer_detail_cards.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/tokens.dart';
import 'support/yetki_yardimcilari.dart';

/// SİPARİO 3.0 müşteri ekranları — liste satırı, bakiye kartı, tahsilat, düzeltme, çoklu telefon,
/// adres bölgesi ve salt-okunur kapısı.
///
/// Widget-test sahte zamanında HER gerçek drift çağrısı `tester.runAsync` içinde beklenir
/// (Dilim 1-3 dersi: düz Future sorgular da asılır). Akışa abone db widget-testte KAPATILMAZ —
/// bellek-içi db süreç sonunda gider. Dar ekranda taşma olmasın diye viewport büyütülür.
/// MÜŞTERİ — LİSTE ve DETAY ekranları.
///
/// DOSYA İKİYE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 715 satırdı): defter, tahsilat ve
/// form testleri `ui_musteri_form_test.dart`ta. Yardımcılar iki dosyada da duruyor (küçük
/// ve ekrana özgü; ortak dosyaya çıkarmak dolaylılık ekler, kural değil kalıp taşırlar).
void main() {
  final t = SipTokens.acik;

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
  /// Kaydet düğmesine basıp asenkron yazmanın (mükerrer sorgusu + repo) bitmesini bekler.
  Future<void> kaydetVeBekle(WidgetTester tester, String etiket) async {
    await tester.tap(find.text(etiket));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  group('Müşteri listesi (CSS .mrow)', () {
    testWidgets('satırda ad ve bakiye çipi görünür; bakiyesi 0 olanda çip YOK', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = CustomerRepository(db);
        final borclu = await repo.create(
            name: 'Ayşe Yılmaz',
            phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)]);
        await LedgerRepository(db).borcEkle(borclu, 12345);
        await repo.create(name: 'Temiz Müşteri');
      });

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: true, yetki: tamYetki));

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Temiz Müşteri'), findsOneWidget);
      // Borçlunun çipi tutarı yazar…
      expect(find.text('123,45 ₺'), findsOneWidget);
      // …bakiyesi 0 olanda çip hiç çizilmez (tasarım: temiz müşteride rozet yok).
      expect(find.text('0,00 ₺'), findsNothing);
      // SİPARİO 3.0: sıfır bakiyede çip widget'ı ağaca HİÇ girmez — boş çizmesi öndeki
      // 12'lik boşluğu hayalet bırakıyordu (CSS `.mrow { gap }` yalnız var olan çocuğa uygulanır).
      expect(find.byType(SipBakiyeCipi), findsOneWidget,
          reason: 'yalnız borçlu satırda çip var');

      await kapat(tester);
    });

    testWidgets('satırda avatar YOK (tasarımın MusteriSatir\'ı avatar çizmiyor)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CustomerRepository(db).create(
            name: 'Ayşe Yılmaz',
            phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)]);
      });

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: true, yetki: tamYetki));

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      // `.mrow-av` ölü CSS: baş harf rozeti listede yer almaz.
      expect(find.byType(SipAvatar), findsNothing);
      expect(find.text('AY'), findsNothing);

      await kapat(tester);
    });

    testWidgets('borçlunun çipi danger, alacaklınınki ok renginde', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = CustomerRepository(db);
        final borclu = await repo.create(name: 'Borçlu Kişi');
        await LedgerRepository(db).borcEkle(borclu, 5000);
        final alacakli = await repo.create(name: 'Alacaklı Kişi');
        await LedgerRepository(db).alacak(alacakli, 2500);
      });

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: true, yetki: tamYetki));

      expect(tester.widget<Text>(find.text('50,00 ₺')).style?.color, t.danger);
      expect(tester.widget<Text>(find.text('25,00 ₺')).style?.color, t.ok);

      await kapat(tester);
    });

    testWidgets('satır adresi yalnız adres metnini yazar (bölge kaldırıldı)', (tester) async {
      // 2026-07-28: Bölge alanı üründen çıktı. ESKİ kayıtlarda `region` dolu kalabilir —
      // kolon uykuda durur ama hiçbir ekranda GÖSTERİLMEZ. Bu test onu da kilitliyor:
      // dolu bir region satıra sızmamalı.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await CustomerRepository(db).create(
          name: 'Adresli Kişi',
          addresses: [
            AddressInput(
                addressText: 'Bahçe Sk. no:5', region: 'Kepez', isPrimary: true, label: 'Ev'),
          ],
        );
      });

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: true, yetki: tamYetki));
      expect(find.text('Bahçe Sk. no:5'), findsOneWidget);
      expect(find.textContaining('Kepez'), findsNothing);
      await kapat(tester);
    });

    testWidgets('salt-okunur kipte "Yeni" uyarı verir, form açılmaz', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: false, yetki: tamYetki));
      await tester.tap(find.text('Yeni'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Aboneliğiniz sona erdi — yeni kayıt eklenemiyor.'), findsOneWidget);
      // Sheet'in AÇILMADIĞINI kaydet düğmesinden anlıyoruz: "Yeni Müşteri" boş durumun eylem
      // düğmesinde de geçtiği için ayırt edici değil.
      expect(find.text('Müşteriyi Kaydet'), findsNothing, reason: 'sheet hiç açılmamalı');

      await tester.pump(const Duration(seconds: 5));
      await kapat(tester);
    });
  });

  group('Müşteri detayı (CSS .md-bakiye)', () {
    Future<String> musteriKur(WidgetTester tester, AppDatabase db, String ad, int borcKurus) async {
      late String id;
      await tester.runAsync(() async {
        id = await CustomerRepository(db).create(
            name: ad, phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)]);
        if (borcKurus > 0) await LedgerRepository(db).borcEkle(id, borcKurus);
        if (borcKurus < 0) await LedgerRepository(db).alacak(id, -borcKurus);
      });
      return id;
    }

    /// `.md-bakiye` şeridinin zemin rengi (tek `MusteriBakiyeKarti` çizildiği için tekil).
    Color? seritZemini(WidgetTester tester) {
      final kutu = tester.widget<Container>(find.descendant(
        of: find.byType(MusteriBakiyeKarti),
        matching: find.byType(Container),
      ));
      return (kutu.decoration as BoxDecoration?)?.color;
    }

    testWidgets('ince bakiye şeridi borçluda "tutar + Borç" yazar, zemini danger-soft',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Borçlu Kişi', 12345);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));

      // SİPARİO 3.0: 34 px'lik hero kart ince şeride indi (s-musteriler.jsx:113-116) — etiket
      // "Bakiye", değer tek satırda "123,45 ₺ Borç" (BÜYÜK HARF DEĞİL).
      expect(find.text('Bakiye'), findsOneWidget);
      expect(find.text('123,45 ₺ Borç'), findsOneWidget);
      expect(find.text(trBuyuk('Borç')), findsNothing, reason: '.md-bal* ölü CSS');
      expect(find.text('BAKİYE'), findsNothing);
      expect(seritZemini(tester), t.dangerSoft);

      await kapat(tester);
    });

    testWidgets('şerit alacaklıda ok-soft, temizde "Temiz" + ok-soft', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final alacakli = await musteriKur(tester, db, 'Alacaklı Kişi', -2500);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: alacakli, writable: true, yetki: tamYetki));
      expect(find.text('25,00 ₺ Alacak'), findsOneWidget);
      expect(seritZemini(tester), t.okSoft);
      await kapat(tester);

      final temiz = await musteriKur(tester, db, 'Temiz Kişi', 0);
      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: temiz, writable: true, yetki: tamYetki));
      // 0'da tutar yerine tek sözcük ve — borç/alacak ayrımı olmadığı için — YEŞİL soft zemin.
      expect(find.text('Temiz'), findsOneWidget);
      expect(find.text('0,00 ₺'), findsNothing);
      expect(seritZemini(tester), t.okSoft);
      await kapat(tester);
    });

    testWidgets('hızlı eylem ızgarası İKİ eylemli: Sipariş + Tahsilat', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'İki Eylem', 5000);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));

      expect(find.text('Sipariş'), findsOneWidget);
      expect(find.text('Tahsilat'), findsOneWidget);
      // "Düzeltme" ızgaradan çıktı (tasarım `gridTemplateColumns: '1fr 1fr'`); yeri defter
      // başlığının sağındaki bağlantı.
      expect(find.text('Düzeltme'), findsNothing);
      expect(find.text('± Bakiye Düzeltme'), findsOneWidget);
      expect(find.text('Kupon'), findsNothing);

      await kapat(tester);
    });

    testWidgets('telefonsuz müşteride "Telefon yok" metni YAZILMAZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String id;
      await tester.runAsync(() async {
        id = await CustomerRepository(db).create(name: 'Telefonsuz');
      });

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));

      // Tasarımda `.md-kart-tel` telefonsuzda BOŞ kalır (s-musteriler.jsx:106).
      expect(find.text('Telefonsuz'), findsOneWidget);
      expect(find.text('Telefon yok'), findsNothing);

      await kapat(tester);
    });

    testWidgets('tahsilat sheet\'i deftere payment yazar ve bakiye önbelleği düşer', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Tahsilatlı', 10000);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));

      await tester.tap(find.text('Tahsilat'));
      await tester.pumpAndSettle();
      expect(find.text('Tahsilat Al'), findsOneWidget);
      // Tutar açık borcun TAMAMIYLA ön-dolu gelir (tasarım: "Tamamı" varsayılan), kuruşuyla —
      // alan kuruş kabul eder (kart/havale tahsilatı kuruşlu olur); çipler tam lira yuvarlar.
      expect(find.text('Tamamı (100,00 ₺)'), findsOneWidget);
      expect(find.text(trBuyuk('Tahsil edilecek tutar (₺)')), findsOneWidget,
          reason: 'etikette para birimi var (s-musteriler.jsx:156)');
      expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, '100,00');

      await kaydetVeBekle(tester, 'Tahsilatı Kaydet');

      late List<LedgerEntry> hareketler;
      late Customer sonrasi;
      await tester.runAsync(() async {
        hareketler = await (db.select(db.ledgerEntries)
              ..where((e) => e.customerId.equals(id) & e.entryType.equals('payment')))
            .get();
        sonrasi = await (db.select(db.customers)..where((c) => c.id.equals(id))).getSingle();
      });

      expect(hareketler, hasLength(1));
      expect(hareketler.single.amountKurus, -10000, reason: 'tahsilat deftere payment(−) düşer');
      expect(hareketler.single.paymentType, 'nakit');
      // Bakiye ELLE EZİLMEZ; defterden yeniden hesaplanan önbellek 0'a iner.
      expect(sonrasi.balanceKurus, 0);

      await kapat(tester);
    });

    testWidgets('düzeltme sheet\'i correction yazar; açıklama ZORUNLU', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Düzeltmeli', 5000);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));

      // Düzeltme artık defter başlığının sağındaki bağlantıdan açılır (CSS `.md-duzelt-link`).
      await tester.tap(find.text('± Bakiye Düzeltme'));
      await tester.pumpAndSettle();
      expect(find.text('Bakiye Düzeltme'), findsOneWidget);
      expect(find.text(trBuyuk('Tutar (₺)')), findsOneWidget);

      // Sheet'in alanları: 0 = tutar, 1 = açıklama.
      await tester.enterText(find.byType(TextField).at(0), '20');
      await tester.pump();

      // Açıklama boşken kayıt DURUR (defter düzeltmesinin nedeni yazılmadan işlenmez).
      await kaydetVeBekle(tester, 'Düzeltmeyi Kaydet');
      expect(find.text('Açıklama girin — düzeltmenin nedeni deftere yazılır'), findsOneWidget);
      expect(find.text('Bakiye Düzeltme'), findsOneWidget, reason: 'sheet açık kalmalı');

      late List<LedgerEntry> erken;
      await tester.runAsync(() async {
        erken = await (db.select(db.ledgerEntries)
              ..where((e) => e.entryType.equals('correction')))
            .get();
      });
      expect(erken, isEmpty, reason: 'açıklamasız düzeltme deftere YAZILMAZ');

      await tester.enterText(find.byType(TextField).at(1), 'Eksik yazılan tutar');
      await tester.pump();
      await kaydetVeBekle(tester, 'Düzeltmeyi Kaydet');

      late List<LedgerEntry> kayitlar;
      late Customer sonrasi;
      await tester.runAsync(() async {
        kayitlar = await (db.select(db.ledgerEntries)
              ..where((e) => e.customerId.equals(id) & e.entryType.equals('correction')))
            .get();
        sonrasi = await (db.select(db.customers)..where((c) => c.id.equals(id))).getSingle();
      });

      expect(kayitlar, hasLength(1));
      expect(kayitlar.single.amountKurus, 2000, reason: '"Borç Ekle (+)" imzalı + yazar');
      expect(kayitlar.single.note, 'Eksik yazılan tutar');
      expect(sonrasi.balanceKurus, 7000, reason: 'bakiye defterden yeniden hesaplanır');

      await kapat(tester);
    });

    testWidgets('salt-okunur kipte tahsilat uyarı verir, sheet açılmaz', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Salt Okunur', 10000);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: false, yetki: tamYetki));

      await tester.tap(find.text('Tahsilat'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Aboneliğiniz sona erdi — yeni kayıt eklenemiyor.'), findsOneWidget);
      expect(find.text('Tahsilat Al'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await kapat(tester);
    });

    testWidgets('salt-okunur kipte düzeltme de engellenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Salt Okunur Düzeltme', 10000);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: false, yetki: tamYetki));

      // Bağlantı salt-okunurda da ÇİZİLİR (tasarımda koşulsuz) — kapı toast'la kendini söyler.
      await tester.tap(find.text('± Bakiye Düzeltme'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Aboneliğiniz sona erdi — yeni kayıt eklenemiyor.'), findsOneWidget);
      expect(find.text('Bakiye Düzeltme'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await kapat(tester);
    });

    testWidgets('mağaza kuralı: satın alma/abonelik dili yok', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Mağaza Kural', 4500);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true, yetki: tamYetki));

      for (final yasak in ['Abone', 'Satın al', 'Üye ol', 'Kaydol', 'Kayıt ol']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }

      await kapat(tester);
    });
  });

}
