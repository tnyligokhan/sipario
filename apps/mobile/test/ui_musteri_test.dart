import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/screens/customers/customer_detail_cards.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/customers/customer_form_ops.dart';
import 'package:sipario/screens/customers/customer_form_screen.dart';
import 'package:sipario/screens/customers/customer_list_screen.dart';
import 'package:sipario/screens/customers/customer_widgets.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/tokens.dart';

/// SİPARİO 3.0 müşteri ekranları — liste satırı, bakiye kartı, tahsilat, düzeltme, çoklu telefon,
/// adres bölgesi ve salt-okunur kapısı.
///
/// Widget-test sahte zamanında HER gerçek drift çağrısı `tester.runAsync` içinde beklenir
/// (Dilim 1-3 dersi: düz Future sorgular da asılır). Akışa abone db widget-testte KAPATILMAZ —
/// bellek-içi db süreç sonunda gider. Dar ekranda taşma olmasın diye viewport büyütülür.
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

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: true));

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

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: true));

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

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: true));

      expect(tester.widget<Text>(find.text('50,00 ₺')).style?.color, t.danger);
      expect(tester.widget<Text>(find.text('25,00 ₺')).style?.color, t.ok);

      await kapat(tester);
    });

    testWidgets('satır adresi "metin — bölge" olarak yazar', (tester) async {
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

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: true));
      expect(find.text('Bahçe Sk. no:5 — Kepez'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('salt-okunur kipte "Yeni" uyarı verir, form açılmaz', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, CustomerListScreen(db: db, writable: false));
      await tester.tap(find.text('Yeni'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
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

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));

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

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: alacakli, writable: true));
      expect(find.text('25,00 ₺ Alacak'), findsOneWidget);
      expect(seritZemini(tester), t.okSoft);
      await kapat(tester);

      final temiz = await musteriKur(tester, db, 'Temiz Kişi', 0);
      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: temiz, writable: true));
      // 0'da tutar yerine tek sözcük ve — borç/alacak ayrımı olmadığı için — YEŞİL soft zemin.
      expect(find.text('Temiz'), findsOneWidget);
      expect(find.text('0,00 ₺'), findsNothing);
      expect(seritZemini(tester), t.okSoft);
      await kapat(tester);
    });

    testWidgets('hızlı eylem ızgarası İKİ eylemli: Sipariş + Tahsilat', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'İki Eylem', 5000);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));

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

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));

      // Tasarımda `.md-kart-tel` telefonsuzda BOŞ kalır (s-musteriler.jsx:106).
      expect(find.text('Telefonsuz'), findsOneWidget);
      expect(find.text('Telefon yok'), findsNothing);

      await kapat(tester);
    });

    testWidgets('tahsilat sheet\'i deftere payment yazar ve bakiye önbelleği düşer', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Tahsilatlı', 10000);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));

      await tester.tap(find.text('Tahsilat'));
      await tester.pumpAndSettle();
      expect(find.text('Tahsilat Al'), findsOneWidget);
      // Tutar açık borçla ön-dolu gelir (tasarım: "Tamamı" varsayılan) ama TAM LİRA olarak:
      // alan `\D` süzdüğü için kuruş yazılamaz (s-musteriler.jsx:88,157).
      expect(find.text('Tamamı · 100,00 ₺'), findsOneWidget);
      expect(find.text(trBuyuk('Tahsil edilecek tutar (₺)')), findsOneWidget,
          reason: 'etikette para birimi var (s-musteriler.jsx:156)');
      expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, '100');

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

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));

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

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: false));

      await tester.tap(find.text('Tahsilat'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      expect(find.text('Tahsilat Al'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await kapat(tester);
    });

    testWidgets('salt-okunur kipte düzeltme de engellenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Salt Okunur Düzeltme', 10000);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: false));

      // Bağlantı salt-okunurda da ÇİZİLİR (tasarımda koşulsuz) — kapı toast'la kendini söyler.
      await tester.tap(find.text('± Bakiye Düzeltme'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      expect(find.text('Bakiye Düzeltme'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await kapat(tester);
    });

    testWidgets('mağaza kuralı: satın alma/abonelik dili yok', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final id = await musteriKur(tester, db, 'Mağaza Kural', 4500);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));

      for (final yasak in ['Abone', 'Satın al', 'Üye ol', 'Kaydol', 'Kayıt ol']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }

      await kapat(tester);
    });
  });

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

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));

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

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));

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

  group('Tahsilat çipleri (tam lira — s-musteriler.jsx:88,160-161)', () {
    testWidgets('"Yarısı" TAM LİRAYA yuvarlar: 85,50 ₺ borçta 43', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String id;
      await tester.runAsync(() async {
        id = await CustomerRepository(db).create(name: 'Küsuratlı Borç');
        await LedgerRepository(db).borcEkle(id, 8550);
      });

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: id, writable: true));
      await tester.tap(find.text('Tahsilat'));
      await tester.pumpAndSettle();

      final alan = find.byType(TextField).first;
      // Ön dolgu: 85,50 ₺ borçta "85" — yuvarlama açık borcu AŞAMAZ, aşarsa form
      // gönderilemez olurdu ("açık borçtan fazla olamaz").
      expect(tester.widget<TextField>(alan).controller?.text, '85');

      await tester.tap(find.text('Yarısı'));
      await tester.pump();
      expect(tester.widget<TextField>(alan).controller?.text, '43',
          reason: 'Math.round(8550/200) = 43 — 42,75 değil');

      // Kuruş YAZILAMAZ: virgül/nokta süzülür.
      await tester.enterText(alan, '12,34');
      await tester.pump();
      expect(tester.widget<TextField>(alan).controller?.text, '1234');

      await kapat(tester);
    });
  });

  group('Müşteri formu (CSS .ym-*)', () {
    testWidgets('telefon alanı eklenip silinebilir (en çok 3)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await formuAc(tester, db);

      // Açılışta: ad · telefon · adres · bölge · not
      expect(find.byType(TextField), findsNWidgets(5));
      expect(find.text('+ Telefon ekle (1/3)'), findsOneWidget);

      await tester.tap(find.text('+ Telefon ekle (1/3)'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text(trBuyuk('Telefon 2')), findsOneWidget);
      expect(find.text('+ Telefon ekle (2/3)'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Telefonu sil'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(5));
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

      await tester.tap(find.text('+ Telefon ekle (1/3)'));
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

    testWidgets('düzenleme sheet\'inde Konum Al ve aday listesi YOK', (tester) async {
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
      // Tasarımın `MusteriDuzenle`si düz "Adres" etiketi + input gösterir (s-musteriler.jsx:353).
      expect(find.text(trBuyuk('Adres')), findsOneWidget);
      expect(find.text('Konum Al'), findsNothing);

      await kapat(tester);
    });

    testWidgets('yeni müşteri sheet\'inde Konum Al DURUYOR (kontrast)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await formuAc(tester, db);

      expect(find.text('Konum Al'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('bölge AYRI kolona (CustomerAddresses.region) yazılır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(0), 'Adresli Kişi');
      await tester.enterText(find.byType(TextField).at(1), '0532 999 88 77');
      await tester.enterText(find.byType(TextField).at(2), 'Bahçe Sk. no:5');
      await tester.enterText(find.byType(TextField).at(3), 'Kepez');
      await tester.pump();
      await kaydetVeBekle(tester, 'Müşteriyi Kaydet');

      late CustomerAddressesData adres;
      await tester.runAsync(() async {
        adres = await db.select(db.customerAddresses).getSingle();
      });

      expect(adres.region, 'Kepez');
      expect(adres.addressText, 'Bahçe Sk. no:5',
          reason: 'bölge artık adres metnine gömülmez — kendi kolonunda durur');

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

    test('adresGosterimi adres ile bölgeyi tasarımdaki gibi birleştirir', () {
      expect(adresGosterimi('Bahçe Sk. no:5', 'Kepez'), 'Bahçe Sk. no:5 — Kepez');
      expect(adresGosterimi('Bahçe Sk. no:5', null), 'Bahçe Sk. no:5');
      expect(adresGosterimi('Bahçe Sk. no:5', '  '), 'Bahçe Sk. no:5');
      expect(adresGosterimi('', 'Kepez'), 'Kepez');
      expect(adresGosterimi(null, null), isNull);
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
