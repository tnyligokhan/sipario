import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/theme/components/overlays.dart';
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

  group('ödeme tipleri (defter tutarlılığı ↔ tasarım görünürlüğü)', () {
    test('müşterisiz siparişte veresiye SEÇİLEMEZ (tezgâh satışı kilidi)', () {
      final tipler = teslimOdemeTipleri(musteriVar: false);
      expect(tipler, ['nakit', 'kart', 'havale']);
      expect(tipler.contains('veresiye'), isFalse,
          reason: 'müşterisiz veresiye = kimseye ait olmayan borç kaydı');
    });

    test('müşterili siparişte dört tip seçilebilir; KUPON hiçbir kipte YOK', () {
      final tipler = teslimOdemeTipleri(musteriVar: true);
      expect(tipler, ['nakit', 'kart', 'havale', 'veresiye']);
      // Kupon 2026-07-26'da üründen kaldırıldı — tasarımdaki ODEME_TIPLERI dört tiptir.
      expect(tipler.contains('kupon'), isFalse);
      expect(teslimOdemeTipleri(musteriVar: false).contains('kupon'), isFalse);
    });

    test('ÇİZİLEN karolar her zaman dörttür — kilit gizleme değil pasifleştirmedir', () {
      // Tasarım veresiyeyi müşterisiz siparişte `disabled` + `opacity .45` çiziyor
      // (s-siparisler.jsx:620): listeden düşürmek kullanıcıya seçeneğin var olduğunu ve neden
      // kapalı olduğunu göstermiyordu. GÖRÜNÜRLÜK ile SEÇİLEBİLİRLİK ayrı iki kuraldır.
      expect(odemeTipleri, ['nakit', 'kart', 'havale', 'veresiye']);
      expect(odemeTipiSecilebilir('veresiye', musteriVar: false), isFalse);
      expect(odemeTipiSecilebilir('veresiye', musteriVar: true), isTrue);
      for (final tip in ['nakit', 'kart', 'havale']) {
        expect(odemeTipiSecilebilir(tip, musteriVar: false), isTrue,
            reason: '$tip müşteri gerektirmez');
      }
      // İki liste TEK kuraldan türer — biri elle güncellenip diğeri unutulamaz.
      expect(teslimOdemeTipleri(musteriVar: true), odemeTipleri);
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

    testWidgets('salt-okunur kipte sipariş KAYDEDİLEMEZ (form okunur kalır)', (tester) async {
      // SİPARİO 3.0'da yeni sipariş girişi bu ekrandan ÇIKTI: FAB artık alt navigasyonun
      // ortasında ve kabuğa ait. Dolayısıyla salt-okunur kapısı listede değil, formun
      // kendisinde. Bu testi o yüzden forma taşıdım.
      //
      // NOT — bu test bir GERİLEMEYİ yakaladı: `OrderFormScreen.writable` varsayılanı `true`
      // olduğu için kabuktaki üç giriş noktası da bayrağı geçmiyordu ve abonelik kilidi
      // açıkken sipariş girilebiliyordu. Çağrı yerleri düzeltildi; parametrenin zorunlu
      // yapılması istendi ki bir daha sessizce geri gelmesin.
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: OrderFormScreen(db: db, writable: false)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsWidgets,
          reason: 'kullanıcı neden kaydedemediğini görmeli');

      await tester.pump(const Duration(seconds: 5));
      SipToast.temizle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('ProductListScreen (widget)', () {
    testWidgets('salt-okunur kipte ürün eklenemez', (tester) async {
      // Ekleme yolu FAB'dan listenin başındaki kesikli "Yeni ürün ekle" satırına taşındı
      // (CSS `.ys-ekle`); uyarı da SnackBar yerine `SipToast`. Kural aynı.
      final db = AppDatabase(NativeDatabase.memory());
      // `rol` AÇIKÇA VERİLİR (2026-08-17): yönetici kapısı artık tanınmayan/eksik rolde kapanıyor;
      // rolsüz kurulan bir ekran testi kapının kapalı hâlini ölçerdi, ekranın içeriğini değil.

      await tester.pumpWidget(MaterialApp(home: ProductListScreen(db: db, writable: false, rol: 'patron')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.tap(find.text('Yeni ürün ekle'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      expect(find.text('Ürün kaydedildi'), findsNothing, reason: 'form hiç açılmamalı');

      await tester.pump(const Duration(seconds: 5));
      SipToast.temizle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('yeniden tasarım (Ekran 5): sayaç + fiyat + pasif çipi çizilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = ProductRepository(db);
        await repo.create(name: 'Damacana 19 L', unitPriceKurus: 4500);
        final eski = await repo.create(name: 'Bardak su', unitPriceKurus: 500);
        await repo.deactivate(eski);
      });

      await tester.pumpWidget(MaterialApp(home: ProductListScreen(db: db, writable: true, rol: 'patron')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('1 aktif · 2 toplam'), findsOneWidget,
          reason: 'başlık altı canlı sayaç aktif/toplam ayrımını gösterir');
      expect(find.text(formatKurus(4500)), findsOneWidget, reason: 'fiyat kartın sağında (amount)');
      expect(find.text('PASİF'), findsOneWidget,
          reason: 'pasif ürün BÜYÜK HARF çip taşır (CSS .urow-pasif text-transform: uppercase)');
      expect(find.text(formatKurus(500)), findsOneWidget,
          reason: 'pasif üründe fiyat kaybolmaz, soluklaşır');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    testWidgets('yeniden tasarım (Ekran 5): boş durum ortak bileşenle', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: ProductListScreen(db: db, writable: true, rol: 'patron')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Henüz ürün yok'), findsOneWidget);
      expect(find.text('Yukarıdan ekleyin — sipariş satırları buradan seçilir.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });
  });

  group('sipariş ekranlarında mağaza kuralı ihlali yok (regresyon)', () {
    testWidgets('yeni sipariş ekranında kayıt/abonelik/satın alma çağrısı YOKTUR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: OrderFormScreen(db: db, writable: true)));
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
