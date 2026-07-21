import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/coupon_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/customers/customer_ledger.dart';
import 'package:sipario/screens/day_end_screen.dart';

/// Dilim 3 UI testleri: defter (hareket listesi/tahsilat/düzeltme/kupon) + gün sonu read-model.
/// Sorgu ve özet mantığı ekrandan bağımsız fonksiyonlarda tutulur ve saf async sınanır
/// (widget-test sahte zamanı drift akışlarında güvenilmez — Dilim 1/2 dersi).
void main() {
  group('imzaliTutarText (para — işaretli gösterim)', () {
    test('+borç, −ödeme; formatKurus negatifi U+2212 ile yazar', () {
      expect(imzaliTutarText(1000), '+10,00 ₺');
      expect(imzaliTutarText(-500), '−5,00 ₺');
      expect(imzaliTutarText(0), '0,00 ₺');
    });
  });

  group('bugunTr (gün sınırı sabit +03:00 TR)', () {
    test('UTC gece yarısı sonrası TR günü ileri kayar', () {
      // 21:00 UTC = 00:00 TR (ertesi gün); 22:00 UTC = 01:00 TR
      expect(bugunTr(now: DateTime.utc(2026, 7, 21, 22)), DateTime(2026, 7, 22));
      expect(bugunTr(now: DateTime.utc(2026, 7, 21, 10)), DateTime(2026, 7, 21));
    });
  });

  group('watchLedger (defter hareketleri — en yeni önce)', () {
    late AppDatabase db;
    late String cid;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      cid = await CustomerRepository(db).create(name: 'Ali Veli');
      final ledger = LedgerRepository(db);
      await ledger.borcEkle(cid, 1000);
      // uuid7 aynı ms'de monoton değil → occurred_at ayrışsın diye bekle (sıralamanın dayanağı).
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await ledger.tahsilat(cid, 500, 'kart');
    });

    tearDown(() => db.close());

    test('en yeni hareket başta gelir', () async {
      final list = await watchLedger(db, cid).first;
      expect(list.length, 2);
      expect(list.first.entryType, 'payment', reason: 'en son tahsilat en üstte');
      expect(list.last.entryType, 'debit');
    });

    test('yalnız o müşterinin hareketleri döner', () async {
      final other = await CustomerRepository(db).create(name: 'Başka');
      final list = await watchLedger(db, other).first;
      expect(list, isEmpty);
    });
  });

  group('tahsilat bakiyeyi düşürür', () {
    test('borç 8000 → tahsilat 3000 → bakiye 5000', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Borçlu');
      final ledger = LedgerRepository(db);
      await ledger.borcEkle(cid, 8000);
      expect((await _musteri(db, cid)).balanceKurus, 8000);
      await ledger.tahsilat(cid, 3000, 'nakit');
      expect((await _musteri(db, cid)).balanceKurus, 5000);
    });
  });

  group('düzeltme ters kayıt üretir (orijinal DEĞİŞMEZ) ve kasayı telafi eder', () {
    test('yanlış nakit tahsilatı düzeltince bakiye geri gelir, kasa sıfırlanır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Düzeltilecek');
      final ledger = LedgerRepository(db);
      await ledger.borcEkle(cid, 10000);
      final payId = await ledger.tahsilat(cid, 10000, 'nakit'); // payment −10000, bakiye 0
      expect((await _musteri(db, cid)).balanceKurus, 0);
      final kasaOnce = await DayEndRepository(db).kasaOzeti(bugunTr());
      expect(kasaOnce.nakit, 10000);

      // Yanlış tahsilat → ters kayıtla düzelt (UI: -e.amountKurus = +10000).
      await ledger.duzeltme(payId, 10000, customerId: cid);

      // Orijinal payment kaydı SİLİNMEDİ/DEĞİŞMEDİ (append-only, kanıt olarak durur).
      final orig = await (db.select(db.ledgerEntries)..where((t) => t.id.equals(payId))).getSingle();
      expect(orig.entryType, 'payment');
      expect(orig.amountKurus, -10000);

      // Correction: ters işaret + reversesEntryId + payment_type KOPYALANDI.
      final corr = await (db.select(db.ledgerEntries)
            ..where((t) => t.entryType.equals('correction')))
          .getSingle();
      expect(corr.amountKurus, 10000);
      expect(corr.reversesEntryId, payId);
      expect(corr.paymentType, 'nakit', reason: 'kasa da düzelsin diye tip kopyalanır');

      // Bakiye borca döndü, kasa nakit sıfırlandı (bakiye + kasa birlikte telafi).
      expect((await _musteri(db, cid)).balanceKurus, 10000);
      final kasaSonra = await DayEndRepository(db).kasaOzeti(bugunTr());
      expect(kasaSonra.nakit, 0);
    });
  });

  group('watchCouponBalance', () {
    test('kupon satışı bakiyeyi artırır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Kuponlu');
      expect(await watchCouponBalance(db, cid).first, 0);
      await CouponRepository(db).kuponSat(customerId: cid, qty: 5, priceKurus: 5000, paymentType: 'nakit');
      expect(await watchCouponBalance(db, cid).first, 5);
    });
  });

  group('gün sonu rakamları defterle tutarlıdır', () {
    test('kasa/borç/kupon defterden türer ve tutar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Gün Sonu');
      final orders = OrderRepository(db);

      // Nakit teslim: debit +9000, payment −9000 (nakit).
      final o1 = await orders.create(
          customerId: cid, lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2)]);
      await orders.deliver(o1, paymentType: 'nakit');

      // Veresiye teslim: debit +4500 (kasaya girmez).
      final o2 = await orders.create(
          customerId: cid, lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1)]);
      await orders.deliver(o2, paymentType: 'veresiye');

      // Kupon satışı: grant +10, debit +10000 & payment −10000 (nakit).
      await CouponRepository(db)
          .kuponSat(customerId: cid, qty: 10, priceKurus: 10000, paymentType: 'nakit');

      final ozet = await gunSonuOzeti(db, bugunTr());

      // Kasa nakit = o1 tahsilatı (9000) + kupon peşin ödemesi (10000).
      expect(ozet.kasa.nakit, 19000);
      expect(ozet.kasa.kart, 0);
      expect(ozet.kasa.havale, 0);
      expect(ozet.kasa.toplam, 19000);

      // Açık borç = yalnız veresiye teslimin borcu (nakit/kupon net 0).
      expect(ozet.borc.toplamAcikBorc, 4500);
      expect(ozet.borc.borclular.single.customerId, cid);

      // Kupon: +10 açık, bugün verilen 10.
      expect(ozet.kupon.toplamAcikKupon, 10);
      expect(ozet.kupon.gunlukVerilen, 10);
    });
  });

  group('defterHareketEtiketi (Türkçe etiket — DB değeri değişmez)', () {
    test('debit/payment/correction ve sipariş borcu doğru etiketlenir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Etiket');
      final ledger = LedgerRepository(db);
      await ledger.borcEkle(cid, 1000); // manuel borç
      await ledger.tahsilat(cid, 500, 'havale');

      // Sipariş borcu (relatedOrderId dolu) — veresiye teslim.
      final oid = await OrderRepository(db)
          .create(customerId: cid, lines: [LineInput(productName: 'D', unitPriceKurus: 4500, qty: 1)]);
      await OrderRepository(db).deliver(oid, paymentType: 'veresiye');

      final rows = await watchLedger(db, cid).first;
      final etiketler = rows.map(defterHareketEtiketi).toSet();
      expect(etiketler.contains('Borç'), isTrue);
      expect(etiketler.contains('Tahsilat · Havale'), isTrue);
      expect(etiketler.contains('Sipariş borcu'), isTrue,
          reason: 'relatedOrderId dolu debit sipariş borcudur');
    });
  });

  group('DayEndScreen (widget — salt-okunur özet)', () {
    testWidgets('kasa/borç/kupon kartlarını çizer', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Ayşe');
        final orders = OrderRepository(db);
        final o = await orders.create(
            customerId: cid, lines: [LineInput(productName: 'D', unitPriceKurus: 4500, qty: 2)]);
        await orders.deliver(o, paymentType: 'nakit');
      });

      await tester.pumpWidget(MaterialApp(home: DayEndScreen(db: db)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Kasa (bugün)'), findsOneWidget);
      expect(find.text('Veresiye (açık borç)'), findsOneWidget);
      expect(find.text('Kupon'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('mağaza-kuralı ihlali yok (satın alma/abonelik metni)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(MaterialApp(home: DayEndScreen(db: db)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      for (final yasak in ['Abone', 'Satın al', 'Üye ol', 'Kaydol', 'Ödeme yap']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('CustomerLedgerSection (widget — salt-okunur kapısı)', () {
    testWidgets('salt-okunur kipte tahsilat SnackBar ile engellenir', (tester) async {
      // Akış-abonelikli drift db'si widget-testte KAPATILMAZ (Dilim 1 dersi: asılı kalıyor).
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomerLedgerSection(db: db, customerId: 'yok', writable: false),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      await tester.tap(find.text('Tahsilat al'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('salt-okunur kipte kupon satışı DA SnackBar ile engellenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomerLedgerSection(db: db, customerId: 'yok', writable: false),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      await tester.tap(find.text('Kupon sat'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing, reason: 'salt-okunurda dialog hiç açılmamalı');

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('salt-okunur kipte var olan hareketin "Ters kayıtla düzelt" menüsü GÖRÜNMEZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Salt Okunur Defter');
        await LedgerRepository(db).borcEkle(cid, 4500);
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CustomerLedgerSection(db: db, customerId: cid, writable: false)),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Borç'), findsOneWidget, reason: 'hareket listelenir');
      expect(find.byType(PopupMenuButton<String>), findsNothing,
          reason: 'salt-okunurda düzeltme menüsü hiç eklenmemeli (onDuzelt null)');

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('yazılabilir kipte aynı hareketin düzeltme menüsü GÖRÜNÜR (kontrast)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Yazılabilir Defter');
        await LedgerRepository(db).borcEkle(cid, 4500);
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CustomerLedgerSection(db: db, customerId: cid, writable: true)),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('CustomerLedgerSection mağaza-kuralı (day_end deseniyle simetri)', () {
    testWidgets('mağaza-kuralı ihlali yok (satın alma/abonelik metni)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Mağaza Kural');
        await LedgerRepository(db).borcEkle(cid, 4500);
        await CouponRepository(db)
            .kuponSat(customerId: cid, qty: 2, priceKurus: 9000, paymentType: 'nakit');
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CustomerLedgerSection(db: db, customerId: cid, writable: true)),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      for (final yasak in ['Abone', 'Satın al', 'Üye ol', 'Kaydol', 'Ödeme yap']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('ekran-repo tutarlılığı: defterde gösterilen tutar repo\'nun yazdığıyla birebir aynı', () {
    testWidgets('küsuratlı bir borç repo\'da ne yazdıysa ekranda AYNI metinle çıkar', (tester) async {
      // Dilim 2'deki kuponAdedi testiyle aynı ilke: ekran ile repo aynı kaynağı konuşmalı.
      // 12345 kuruş bilerek küsuratlı seçildi (yuvarlama/kesme hatası varsa yakalasın).
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Küsuratlı');
        await LedgerRepository(db).borcEkle(cid, 12345);
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CustomerLedgerSection(db: db, customerId: cid, writable: false)),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      // Repo'nun yazdığı gerçek satırdan (DB'den okunarak) beklenen metni kur — ekrandaki sabit
      // bir string'i tahmin etmiyoruz, repo'nun ürettiği değeri imzaliTutarText'e sokup karşılaştırıyoruz.
      // NOT (Dilim 1 dersi — genişletildi): drift sorgusu watch() akışı OLMASA bile gerçek async'tir;
      // widget-test sahte zaman diliminde runAsync DIŞINDA await edilirse asılı kalır.
      late LedgerEntry yazilan;
      await tester.runAsync(() async {
        yazilan = await (db.select(db.ledgerEntries)..where((t) => t.customerId.equals(cid))).getSingle();
      });
      expect(find.text(imzaliTutarText(yazilan.amountKurus)), findsOneWidget);
      expect(find.text('+123,45 ₺'), findsOneWidget, reason: 'küsurat kaybolmadan 12345 kuruş göründü');

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('kupon bakiyesi repo\'daki adetle (watchCouponBalance) birebir aynı gösterilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Kupon Ekran');
        await CouponRepository(db)
            .kuponSat(customerId: cid, qty: 7, priceKurus: 63000, paymentType: 'kart');
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CustomerLedgerSection(db: db, customerId: cid, writable: false)),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      // watch() akışı da gerçek async'tir — runAsync DIŞINDA .first beklemek asılı kalır (Dilim 1 dersi).
      late int gercekBakiye;
      await tester.runAsync(() async {
        gercekBakiye = await watchCouponBalance(db, cid).first;
      });
      expect(gercekBakiye, 7);
      expect(find.text('$gercekBakiye adet'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('tahsilat: bakiye ve kasa AYNI tutarda birlikte değişir', () {
    test('borç 8000 → havale tahsilat 3000 → bakiye 5000 düşer VE kasa havale gözü 3000 artar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Havaleci');
      final ledger = LedgerRepository(db);

      await ledger.borcEkle(cid, 8000);
      final kasaOnce = await DayEndRepository(db).kasaOzeti(bugunTr());
      expect(kasaOnce.havale, 0, reason: 'yalnız borç yazıldı, kasaya henüz para girmedi');

      await ledger.tahsilat(cid, 3000, 'havale');

      expect((await _musteri(db, cid)).balanceKurus, 5000, reason: '8000 borç − 3000 tahsilat');
      final kasaSonra = await DayEndRepository(db).kasaOzeti(bugunTr());
      expect(kasaSonra.havale, 3000, reason: 'bakiyeden düşen tutarla kasaya giren tutar AYNI (3000)');
      expect(kasaSonra.nakit, 0);
      expect(kasaSonra.kart, 0);
    });
  });

  group('düzeltme append-only kanıt: kayıt sayısı artar, orijinal satır hiçbir alanıyla değişmez', () {
    test('correction eklenince satır SAYISI +1 olur; orijinal satır (tüm alanlarıyla) AYNEN durur', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Kanıt');
      final ledger = LedgerRepository(db);
      final payId = await ledger.tahsilat(cid, 7500, 'kart');

      final oncekiSatirlar = await db.select(db.ledgerEntries).get();
      expect(oncekiSatirlar, hasLength(1));
      final orijinalOnce = oncekiSatirlar.single;

      await ledger.duzeltme(payId, 7500, customerId: cid);

      final sonrakiSatirlar = await db.select(db.ledgerEntries).get();
      expect(sonrakiSatirlar, hasLength(2), reason: 'düzeltme YENİ satırdır, mevcut satır yerine geçmez');

      // Orijinal satır UPDATE edilmediyse drift veri sınıfı (tüm alanlar) hâlâ birebir eşit olmalı.
      final orijinalSonra = sonrakiSatirlar.firstWhere((e) => e.id == payId);
      expect(orijinalSonra, equals(orijinalOnce),
          reason: 'append-only: kaynak satırın TEK bir alanı bile değişmemiş olmalı');
    });
  });

  group('kupon zinciri: satış artırır, kuponlu teslim düşürür, eksiye düşebilir (watchCouponBalance)', () {
    test('3 kupon satılır → teslimle 1\'i kullanılır → sonra 3 daha kullanılınca eksiye düşer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Kupon Zinciri');

      await CouponRepository(db).kuponSat(customerId: cid, qty: 3, priceKurus: 27000, paymentType: 'nakit');
      expect(await watchCouponBalance(db, cid).first, 3, reason: 'satış ekran fonksiyonunda artış olarak görünür');

      final orders = OrderRepository(db);
      final o1 = await orders.create(customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 9000, qty: 1)]);
      await orders.deliver(o1, paymentType: 'kupon');
      expect(await watchCouponBalance(db, cid).first, 2, reason: 'kuponlu teslim ekran fonksiyonunda düşüş olarak görünür');

      final o2 = await orders.create(customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 9000, qty: 3)]);
      await orders.deliver(o2, paymentType: 'kupon');
      expect(await watchCouponBalance(db, cid).first, -1,
          reason: 'hakkı aşan teslim reddedilmez; ekran fonksiyonu da eksiyi olduğu gibi gösterir');
    });
  });

  group("gün sonu: kasa/borç/kupon rakamları BAĞIMSIZ hesapla doğrulanır", () {
    test('çok müşterili/çok ödeme tipli karışık senaryoda elle kurulan beklenti repository çıktısıyla eşleşir',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final orders = OrderRepository(db);
      final ledger = LedgerRepository(db);
      final coupons = CouponRepository(db);

      // Ayşe: nakit peşin teslim → debit+payment nakit, net borç 0, kasa nakit +4500.
      final ayseId = await CustomerRepository(db).create(name: 'Ayşe');
      final o1 = await orders.create(customerId: ayseId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 4500, qty: 1)]);
      await orders.deliver(o1, paymentType: 'nakit');

      // Bora: kart peşin teslim → kasa kart +9000; sonra 4 kupon alır kartla → kasa kart +8000 daha.
      final boraId = await CustomerRepository(db).create(name: 'Bora');
      final o2 = await orders.create(customerId: boraId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);
      await orders.deliver(o2, paymentType: 'kart');
      await coupons.kuponSat(customerId: boraId, qty: 4, priceKurus: 8000, paymentType: 'kart');
      // Bora 2 kupon kullanır (teslim) → kupon bakiyesi 4−2=2, kasaya para hareketi YOK (peşin ödendi).
      final o2b = await orders.create(customerId: boraId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 2)]);
      await orders.deliver(o2b, paymentType: 'kupon');

      // Cem: 5000 borcu var, 2000 havale tahsilat yapılır → kalan borç 3000, kasa havale +2000.
      final cemId = await CustomerRepository(db).create(name: 'Cem');
      await ledger.borcEkle(cemId, 5000);
      await ledger.tahsilat(cemId, 2000, 'havale');

      // Derya: veresiye teslim → borç 12000, kasaya HİÇ dokunmaz.
      final deryaId = await CustomerRepository(db).create(name: 'Derya');
      final o3 = await orders.create(customerId: deryaId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 12000, qty: 1)]);
      await orders.deliver(o3, paymentType: 'veresiye');

      final ozet = await gunSonuOzeti(db, bugunTr());

      // --- Aşağıdaki beklenti rakamları girdilerden ELLE çıkarıldı (repository kodunu tekrar
      // ETMİYORUZ) — DayEndRepository'nin ürettiğiyle karşılaştırıyoruz. ---
      expect(ozet.kasa.nakit, 4500, reason: 'yalnız Ayşe\'nin peşin nakit teslimi');
      expect(ozet.kasa.kart, 9000 + 8000, reason: 'Bora\'nın peşin teslimi + kupon paketi kartla');
      expect(ozet.kasa.havale, 2000, reason: 'Cem\'in tahsilatı');
      expect(ozet.kasa.toplam, 4500 + 17000 + 2000);

      expect(ozet.borc.toplamAcikBorc, 3000 + 12000, reason: 'Cem 3000 + Derya 12000; peşin/kupon müşterileri borçsuz');
      expect(ozet.borc.borclular.map((b) => b.name).toSet(), {'Cem', 'Derya'});

      expect(ozet.kupon.gunlukVerilen, 4, reason: 'Bora\'ya verilen kupon');
      expect(ozet.kupon.gunlukKullanilan, 2, reason: 'Bora\'nın kullandığı kupon');
      expect(ozet.kupon.toplamAcikKupon, 2, reason: '4 verildi 2 kullanıldı → 2 açık (eksi yok)');
      expect(ozet.kupon.eksiBakiyeliler, isEmpty);
    });
  });
}

Future<Customer> _musteri(AppDatabase db, String id) =>
    (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
