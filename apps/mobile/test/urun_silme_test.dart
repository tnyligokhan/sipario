// ÜRÜN SİLME (kullanıcı kararı 2026-09-26: "Yönetici ürün silebiliyor olmalı").
//
// Eskiden ürün yalnız pasifleşiyordu. Silme TOMBSTONE'dur (müşteri arşivinin aynısı): satır
// `deleted_at` alır, senkronla `op=delete` gider. Geçmiş siparişin satırı ürün adını ve tutarı
// kendi içinde taşıdığı için silme onu BOZMAZ — bu dosyanın asıl iddiası bu.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/orders/order_queries.dart' show watchKatalogUrunleri;
import 'package:sipario/screens/products/product_form_sheet.dart';
import 'package:sipario/screens/products/product_list_screen.dart' show watchProducts;

import 'support/ekran_yardimcilari.dart';
import 'support/urun_ortami.dart';

void main() {
  group('ProductRepository.delete', () {
    late UrunOrtami o;
    setUp(() => o = UrunOrtami());
    tearDown(() => o.kapat());

    test('satır tombstone olur ve senkrona op=delete gider', () async {
      final id = await o.ekle('Damacana 19 L');
      await o.repo.delete(id);

      expect((await o.oku(id)).deletedAt, isNotNull, reason: 'fiziksel silme YOK');
      final olay = await o.sonOlay(id);
      expect(olay.op, 'delete');
      expect(olay.yuk, {'id': id});
    });

    test('silinen ürün ne ürün listesinde ne sipariş kataloğunda görünür', () async {
      final kalan = await o.ekle('Pet 5 L');
      final silinen = await o.ekle('Damacana 19 L');
      await o.repo.delete(silinen);

      final liste = await watchProducts(o.db, activeOnly: false).first;
      expect(liste.map((u) => u.id), [kalan]);
      final katalog = await watchKatalogUrunleri(o.db).first;
      expect(katalog.map((u) => u.id), [kalan]);
    });

    test('geçmiş siparişin satırı ürün adını ve tutarını KORUR', () async {
      final urunId = await o.ekle('Damacana 19 L', kurus: 4500);
      final musteri = await CustomerRepository(o.db).create(name: 'AHMET');
      final siparis = await OrderRepository(o.db).create(customerId: musteri, lines: [
        LineInput(
            productId: urunId, productName: 'Damacana 19 L', unitPriceKurus: 4500, qty: 2),
      ]);

      await o.repo.delete(urunId);

      final satir = await (o.db.select(o.db.orderLines)
            ..where((t) => t.orderId.equals(siparis)))
          .getSingle();
      expect(satir.productName, 'Damacana 19 L');
      expect(satir.unitPriceKurus, 4500);
    });
  });

  group('ürün formu — silme düğmesi', () {
    Future<AppDatabase> kur() async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: 'u-1',
            name: 'Damacana 19 L',
            unitPriceKurus: 4500,
            unit: const Value('adet'),
            updatedOccurredAt: '2026-09-26T00:00:00.000Z',
          ));
      return db;
    }

    Future<Product> urun(WidgetTester tester, AppDatabase db) async =>
        (await tester.runAsync(
          () => (db.select(db.products)..where((t) => t.id.equals('u-1'))).getSingle(),
        ))!;

    testWidgets('onaydan sonra ürün silinir', (tester) async {
      final db = await kur();
      final mevcut = await urun(tester, db);
      await sheetAc(tester, (ctx) => urunFormuAc(ctx, db: db, urun: mevcut));

      await dokun(tester, find.text('Ürünü sil'));
      expect(find.text('Sil'), findsOneWidget, reason: 'silme onaysız yapılmaz');
      await dokun(tester, find.text('Sil'));

      expect((await urun(tester, db)).deletedAt, isNotNull);
      await kapat(tester);
    });

    testWidgets('vazgeçilirse ürün kalır', (tester) async {
      final db = await kur();
      final mevcut = await urun(tester, db);
      await sheetAc(tester, (ctx) => urunFormuAc(ctx, db: db, urun: mevcut));

      await dokun(tester, find.text('Ürünü sil'));
      await dokun(tester, find.text('Vazgeç'));

      expect((await urun(tester, db)).deletedAt, isNull);
      await kapat(tester);
    });

    testWidgets('yeni ürün formunda silme düğmesi yok', (tester) async {
      final db = await kur();
      await sheetAc(tester, (ctx) => urunFormuAc(ctx, db: db));

      expect(find.text('Ürünü sil'), findsNothing);
      await kapat(tester);
    });
  });
}
