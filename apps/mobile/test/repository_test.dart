import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('müşteri oluşturma: yerel yazma + outbox aynı transaction (customer + phone)', () async {
    final repo = CustomerRepository(db);
    final id = await repo.create(
      name: 'Ahmet Yılmaz',
      note: 'Zil bozuk',
      phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)],
    );

    final customers = await db.select(db.customers).get();
    expect(customers, hasLength(1));
    expect(customers.first.name, 'Ahmet Yılmaz');

    final phones = await db.select(db.customerPhones).get();
    expect(phones, hasLength(1));
    expect(phones.first.phoneLast10, '5321112233'); // son 10 hane

    // Outbox: customer.upsert + customer_phone.upsert (yerel yazımla aynı transaction'da).
    final outbox = await db.select(db.outbox).get();
    expect(outbox, hasLength(2));
    expect(outbox.map((o) => o.entityType).toSet(), {'customer', 'customer_phone'});
    expect(outbox.every((o) => o.status == 'pending'), isTrue);
    // customer payload id ile yazılan müşteri eşleşir.
    final custEvent = outbox.firstWhere((o) => o.entityType == 'customer');
    expect(jsonDecode(custEvent.payload)['id'], id);
  });

  test('müşteri arşivleme tombstone yazar + outbox delete', () async {
    final repo = CustomerRepository(db);
    final id = await repo.create(name: 'Silinecek');
    await repo.archive(id);

    final cust = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
    expect(cust.deletedAt, isNotNull);

    final delEvent = await (db.select(db.outbox)..where((t) => t.op.equals('delete'))).getSingle();
    expect(delEvent.entityType, 'customer');
    expect(delEvent.entityId, id);
  });

  test('sipariş oluşturma: order + lines + order_event + outbox; total türetilir', () async {
    final orders = OrderRepository(db);
    final orderId = await orders.create(lines: [
      LineInput(productName: '19L Damacana', unitPriceKurus: 4500, qty: 2),
      LineInput(productName: '5L Bidon', unitPriceKurus: 6000, qty: 1),
    ]);

    final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    expect(order.status, 'open');
    expect(order.totalKurus, 15000); // 4500*2 + 6000*1

    expect(await db.select(db.orderLines).get(), hasLength(2));
    final events = await db.select(db.orderEvents).get();
    expect(events, hasLength(1));
    expect(events.first.eventType, 'created');

    // Tek outbox olayı: order.created (satırlar payload içinde).
    final outbox = await (db.select(db.outbox)..where((t) => t.entityType.equals('order'))).get();
    expect(outbox, hasLength(1));
    expect(outbox.first.op, 'created');
  });

  test('sipariş teslim: status delivered + ödeme tipi + yeni order_event', () async {
    final orders = OrderRepository(db);
    final orderId = await orders.create(lines: [LineInput(productName: 'X', unitPriceKurus: 1000, qty: 1)]);
    await orders.deliver(orderId, paymentType: 'nakit');

    final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    expect(order.status, 'delivered');
    expect(order.paymentType, 'nakit');
    expect(await db.select(db.orderEvents).get(), hasLength(2)); // created + delivered
  });

  test('sipariş satır silme total günceller', () async {
    final orders = OrderRepository(db);
    final orderId = await orders.create(lines: [LineInput(productName: 'A', unitPriceKurus: 1000, qty: 2)]);
    final lineId = await orders.addLine(orderId, LineInput(productName: 'B', unitPriceKurus: 500, qty: 4));

    var order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    expect(order.totalKurus, 2000 + 2000);

    await orders.removeLine(orderId, lineId);
    order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    expect(order.totalKurus, 2000); // B satırı tombstone → toplamdan düştü
  });

  test('ürün oluştur/pasifle outbox olayı üretir', () async {
    final products = ProductRepository(db);
    final id = await products.create(name: '19L Damacana', unitPriceKurus: 4500);
    await products.deactivate(id);

    final product = await (db.select(db.products)..where((t) => t.id.equals(id))).getSingle();
    expect(product.isActive, isFalse);
    final outbox = await (db.select(db.outbox)..where((t) => t.entityType.equals('product'))).get();
    expect(outbox, hasLength(2)); // create + deactivate (ikisi de upsert)
  });
}
