import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/money.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/orders/order_form_screen.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/products/product_list_screen.dart';

/// Dilim 2 UI testleri: para ayrıştırma, sipariş/ürün sorguları, teslim ödeme kuralları.
/// Sorgu ve kural mantığı ekrandan bağımsız fonksiyonlarda tutulur ve saf async sınanır
/// (widget-test sahte zamanı drift akışlarında güvenilmez — Dilim 1 dersi).
void main() {
  group('parseKurus (para sınırı — sessiz yuvarlama YOK)', () {
    test('TR yazımları kuruşa çevrilir', () {
      expect(parseKurus('12'), 1200);
      expect(parseKurus('12,5'), 1250);
      expect(parseKurus('12,50'), 1250);
      expect(parseKurus('1.234,56'), 123456);
      expect(parseKurus('12.50'), 1250); // nokta ondalık yazımı da kabul
      expect(parseKurus(' 75 ₺ '), 7500);
      expect(parseKurus('0,05'), 5);
    });

    test('nokta+3 hane TR binlik sayılır (1.234 = 1234 TL, 12,34 TL DEĞİL)', () {
      expect(parseKurus('1.234'), 123400);
      expect(parseKurus('1.234.567'), 123456700);
    });

    test('geçersiz/riskli yazımlar reddedilir', () {
      expect(parseKurus(''), isNull);
      expect(parseKurus('abc'), isNull);
      expect(parseKurus('-5'), isNull, reason: 'negatif fiyat yok');
      expect(parseKurus('12,345'), isNull, reason: 'kuruş 2 haneden uzun — yuvarlamayı biz yapmayız');
      expect(parseKurus('12,'), 1200);
    });

    test('formatKurus ↔ parseKurus gidiş-dönüş bozulmaz', () {
      for (final k in [0, 5, 150, 1250, 123456, 100000000]) {
        expect(parseKurus(formatKurus(k)), k, reason: '$k kuruş');
      }
    });
  });

  group('toplamKurus (sipariş taslağı)', () {
    test('adet × birim fiyat toplamı int kuruş', () {
      final lines = [
        LineDraft(name: '19 L damacana', unitPriceKurus: 4500, qty: 3),
        LineDraft(name: '5 L su', unitPriceKurus: 1250, qty: 2),
      ];
      expect(toplamKurus(lines), 3 * 4500 + 2 * 1250);
      expect(toplamKurus([]), 0);
    });
  });

  group('teslimOdemeTipleri (defter tutarlılığı)', () {
    test('müşterisiz siparişte veresiye ve kupon SUNULMAZ', () {
      final tipler = teslimOdemeTipleri(musteriVar: false);
      expect(tipler, ['nakit', 'kart', 'havale']);
      expect(tipler.contains('veresiye'), isFalse,
          reason: 'müşterisiz veresiye = kimseye ait olmayan borç kaydı');
      expect(tipler.contains('kupon'), isFalse);
    });

    test('müşterili siparişte beş tip de sunulur', () {
      expect(teslimOdemeTipleri(musteriVar: true),
          ['nakit', 'kart', 'havale', 'veresiye', 'kupon']);
    });
  });

  group('saatBicimi', () {
    test('bugünse yalnız saat, değilse gün.ay saat', () {
      final now = DateTime(2026, 7, 21, 15, 0);
      final bugun = DateTime(2026, 7, 21, 9, 5);
      final dun = DateTime(2026, 7, 20, 18, 30);
      expect(saatBicimi(bugun.toIso8601String(), simdi: now), '09:05');
      expect(saatBicimi(dun.toIso8601String(), simdi: now), '20.07 18:30');
    });

    test('ayrıştırılamayan değer olduğu gibi gösterilir (veri değiştirilmez)', () {
      expect(saatBicimi('bozuk-tarih'), 'bozuk-tarih');
    });
  });

  group('watchProducts', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final repo = ProductRepository(db);
      await repo.create(name: 'Damacana 19 L', unitPriceKurus: 4500);
      final eski = await repo.create(name: 'Bardak su', unitPriceKurus: 500);
      await repo.deactivate(eski);
    });

    tearDown(() => db.close());

    test('varsayılan yalnız aktif ürünleri ada göre döner', () async {
      final list = await watchProducts(db).first;
      expect(list.map((p) => p.name), ['Damacana 19 L']);
    });

    test('activeOnly=false pasifleri de gösterir (yönetim ekranı)', () async {
      final list = await watchProducts(db, activeOnly: false).first;
      expect(list.map((p) => p.name), ['Bardak su', 'Damacana 19 L']);
    });
  });

  group('watchOrders', () {
    late AppDatabase db;
    late OrderRepository orders;
    late String acikId;
    late String teslimId;
    late String iptalId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      orders = OrderRepository(db);
      final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');

      // Aralara kısa bekleme: occurred_at'ler AYRIŞSIN. uuid7 aynı milisaniye içinde monoton
      // değildir; sıralama testinin tek dayanağı occurred_at olmalı (id yalnız eşitlik bozucu).
      teslimId = await orders.create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2),
      ]);
      await orders.deliver(teslimId, paymentType: 'nakit');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      iptalId = await orders.create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      await orders.cancel(iptalId);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      acikId = await orders.create(lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 3),
      ]);
    });

    tearDown(() => db.close());

    test('"Açık" filtresi yalnız açık siparişleri döner (iptal/teslim yok)', () async {
      final list = await watchOrders(db, OrderFilter.acik).first;
      expect(list.map((i) => i.order.id), [acikId]);
      expect(list.single.order.totalKurus, 3 * 4500);
    });

    test('"Teslim" filtresi teslim edilenleri döner, ödeme tipiyle', () async {
      final list = await watchOrders(db, OrderFilter.teslim).first;
      expect(list.map((i) => i.order.id), [teslimId]);
      expect(list.single.order.paymentType, 'nakit');
    });

    test('"Tümü" iptal dahil hepsini, en yeni önce döner', () async {
      final list = await watchOrders(db, OrderFilter.tumu).first;
      expect(list.map((i) => i.order.id), [acikId, iptalId, teslimId]);
    });

    test('müşteri adı listede gelir; müşterisiz sipariş null döner', () async {
      final list = await watchOrders(db, OrderFilter.tumu).first;
      expect(list.firstWhere((i) => i.order.id == teslimId).customerName, 'Ayşe Yılmaz');
      expect(list.firstWhere((i) => i.order.id == acikId).customerName, isNull);
    });
  });

  group('kuponAdedi ekranla defteri aynı sayıda tutar', () {
    test('ekranda gösterilen adet, deliver\'ın kupon defterine düşürdüğü adettir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final musteriId = await CustomerRepository(db).create(name: 'Mehmet Demir');
      final orders = OrderRepository(db);
      final orderId = await orders.create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2),
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 3),
      ]);

      final lines = await (db.select(db.orderLines)
            ..where((t) => t.orderId.equals(orderId))
            ..where((t) => t.deletedAt.isNull()))
          .get();
      final ekranAdedi = kuponAdedi(lines);
      expect(ekranAdedi, 5);

      await orders.deliver(orderId, paymentType: 'kupon');

      final hareket = await (db.select(db.couponMovements)
            ..where((t) => t.relatedOrderId.equals(orderId)))
          .getSingle();
      expect(hareket.qtyDelta, -ekranAdedi, reason: 'ekran ile defter aynı adedi konuşmalı');

      // Kupon bakiyesi yoktu → eksiye düştü (BRIEF: teslim edilmiş mal gerçektir, reddedilmez).
      final bakiye = await (db.select(db.couponBalances)
            ..where((t) => t.customerId.equals(musteriId)))
          .getSingle();
      expect(bakiye.balanceQty, -5);
    });
  });

  group('OrderListScreen (widget — yalnız ilk çizim; akış zamanlaması için Dilim 1 notuna bak)', () {
    testWidgets('açık sipariş listede müşteri adı ve tutarla görünür', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        await OrderRepository(db).create(customerId: musteriId, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2),
        ]);
      });

      await tester.pumpWidget(MaterialApp(home: OrderListScreen(db: db, writable: true)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('90,00 ₺'), findsOneWidget);

      // Ağacı boşalt + sahte saati ilerlet (bekleyen zamanlayıcılar sönsün). db BİLEREK kapatılmaz:
      // akış abonelikli drift db'sini widget-test zonunda kapatmak asılı kalıyor (Dilim 1 dersi).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('salt-okunur kipte sipariş girişi engellenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: OrderListScreen(db: db, writable: false)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      expect(find.byType(OrderFormScreen), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('ProductListScreen (widget)', () {
    testWidgets('salt-okunur kipte ürün eklenemez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: ProductListScreen(db: db, writable: false)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('sipariş ekranlarında mağaza kuralı ihlali yok (regresyon)', () {
    testWidgets('yeni sipariş ekranında kayıt/abonelik/satın alma çağrısı YOKTUR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: OrderFormScreen(db: db)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      for (final yasak in ['Abone', 'Satın al', 'Üye ol', 'Kaydol', 'Ödeme yap']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
