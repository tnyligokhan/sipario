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
  });
}

Future<Customer> _musteri(AppDatabase db, String id) =>
    (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
