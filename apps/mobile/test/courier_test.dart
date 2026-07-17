import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/ids.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_ops.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';

/// FAZ 4 kurye istemci iş akışları: sipariş ATAMA (olay-kaynaklı önbellek), TESLİM İDEMPOTENSİ
/// (deterministik uuid5 client_event_id + çift-dokunma koruması), KASA DEVRİ (beklenen nakit ledger'den,
/// fark, append-only + outbox). Her yazım yerel + outbox tek transaction.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> setUser(String userId) =>
      (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(SyncMetaCompanion(userId: Value(userId)));

  group('sipariş atama', () {
    test('assign assignedUserId önbelleğini yazar + outbox assigned', () async {
      final orders = OrderRepository(db);
      final orderId = await orders.create(lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);

      await orders.assign(orderId, 'kurye-1');
      var order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
      expect(order.assignedUserId, 'kurye-1');

      final ob = await (db.select(db.outbox)..where((t) => t.op.equals('assigned'))).getSingle();
      expect(ob.entityType, 'order');
      expect(jsonDecode(ob.payload)['assigned_user_id'], 'kurye-1');

      await orders.unassign(orderId);
      order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
      expect(order.assignedUserId, isNull, reason: 'unassigned önbelleği null yapar');
    });

    test('teslim atamayı SİLMEZ (recompute geçmiş assigned olayını korur)', () async {
      final orders = OrderRepository(db);
      final custId = await CustomerRepository(db).create(name: 'Atamalı');
      final orderId = await orders.create(customerId: custId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);

      await orders.assign(orderId, 'kurye-1');
      await orders.deliver(orderId, paymentType: 'nakit');

      final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
      expect(order.status, 'delivered');
      expect(order.assignedUserId, 'kurye-1', reason: 'teslim recompute ataması geçmiş olaydan korunmalı');
    });

    test('son atama kazanır (kuryeden operatöre)', () async {
      final orders = OrderRepository(db);
      final orderId = await orders.create(lines: [LineInput(productName: 'D', unitPriceKurus: 1000, qty: 1)]);
      await orders.assign(orderId, 'kurye-1');
      await orders.assign(orderId, 'operator-1');
      final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
      expect(order.assignedUserId, 'operator-1');
    });
  });

  group('teslim idempotensi', () {
    test('deterministik uuid5: aynı orderId aynı client_event_id (tag başına ayrık)', () {
      final o = 'order-abc';
      expect(deliveryEventId(o, 'payment'), deliveryEventId(o, 'payment'), reason: 'deterministik');
      expect(deliveryEventId(o, 'payment') == deliveryEventId(o, 'debit'), isFalse, reason: 'tag ayrık');
      expect(deliveryEventId('order-x', 'payment') == deliveryEventId('order-y', 'payment'), isFalse);
    });

    test('teslim outbox olayları deterministik client_event_id taşır', () async {
      final custId = await CustomerRepository(db).create(name: 'Teslim');
      final orders = OrderRepository(db);
      final orderId = await orders.create(customerId: custId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);
      await orders.deliver(orderId, paymentType: 'nakit');

      final delivered = await (db.select(db.outbox)
            ..where((t) => t.entityType.equals('order') & t.op.equals('delivered')))
          .getSingle();
      expect(delivered.clientEventId, deliveryEventId(orderId, 'order'));

      final ledgerOutbox = await (db.select(db.outbox)..where((t) => t.entityType.equals('ledger'))).get();
      final ceids = ledgerOutbox.map((o) => o.clientEventId).toSet();
      expect(ceids, {deliveryEventId(orderId, 'debit'), deliveryEventId(orderId, 'payment')});
    });

    test('iki cihaz aynı siparişi teslim → AYNI client_event_id (sunucu tekilleştirir)', () async {
      // İki ayrı yerel DB (iki cihaz), aynı orderId. Deterministik uuid5 sayesinde ürettikleri
      // client_event_id'ler AYNIdır → sunucu processed_events ile tek defter seti bırakır.
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);

      const orderId = 'ortak-siparis-id';
      Future<Set<String>> deliverOn(AppDatabase d) async {
        await d.into(d.customers).insert(CustomersCompanion.insert(
              id: 'c1', name: 'M', updatedOccurredAt: '2026-07-15T00:00:00.000Z'));
        await d.into(d.orders).insert(OrdersCompanion.insert(
              id: orderId, customerId: const Value('c1'), occurredAt: '2026-07-15T00:00:00.000Z'));
        await d.into(d.orderLines).insert(OrderLinesCompanion.insert(
              id: 'l1', orderId: orderId, productName: 'D', unitPriceKurus: 9000, qty: 1, lineTotalKurus: 9000));
        await OrderRepository(d).deliver(orderId, paymentType: 'nakit');
        final ob = await d.select(d.outbox).get();
        return ob.map((o) => o.clientEventId).toSet();
      }

      final ce1 = await deliverOn(db);
      final ce2 = await deliverOn(db2);
      // Teslimden türeyen olayların (order/debit/payment) client_event_id'leri iki cihazda ORTAK.
      final ortak = {
        deliveryEventId(orderId, 'order'),
        deliveryEventId(orderId, 'debit'),
        deliveryEventId(orderId, 'payment'),
      };
      expect(ce1.containsAll(ortak), isTrue);
      expect(ce2.containsAll(ortak), isTrue);
    });

    test('çift teslim yerel no-op (çift-dokunma koruması)', () async {
      final custId = await CustomerRepository(db).create(name: 'Çift Dokunma');
      final orders = OrderRepository(db);
      final orderId = await orders.create(customerId: custId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);
      await orders.deliver(orderId, paymentType: 'nakit');
      final before = (await db.select(db.ledgerEntries).get()).length;

      await orders.deliver(orderId, paymentType: 'nakit'); // ikinci dokunma → erken dön
      final after = (await db.select(db.ledgerEntries).get()).length;
      expect(after, before, reason: 'teslim edilmiş sipariş yeniden teslimde yeni kayıt üretmemeli');
    });
  });

  group('kasa devri', () {
    test('beklenen nakit ledger\'den hesaplanır, fark yazılır, outbox handover', () async {
      await setUser('kurye-1');
      final custId = await CustomerRepository(db).create(name: 'Nakitçi');
      final ledger = LedgerRepository(db);
      await ledger.tahsilat(custId, 5000, 'nakit'); // collected_by=kurye-1
      await ledger.tahsilat(custId, 3000, 'kart'); // fiziksel kasa DEĞİL (devre girmez)

      // Kurye 5000 sayar → beklenen 5000 (yalnız nakit), fark 0.
      final id = await CashHandoverRepository(db).devret(
          fromUserId: 'kurye-1', toUserId: 'patron-1', countedCashKurus: 5000, note: 'gun sonu');

      final row = await (db.select(db.cashHandovers)..where((t) => t.id.equals(id))).getSingle();
      expect(row.expectedCashKurus, 5000, reason: 'yalnız nakit payment; kart sayılmaz');
      expect(row.countedCashKurus, 5000);
      expect(row.diffKurus, 0);
      expect(row.fromUserId, 'kurye-1');
      expect(row.toUserId, 'patron-1');

      final ob = await (db.select(db.outbox)..where((t) => t.entityType.equals('cash_handover'))).getSingle();
      expect(ob.op, 'handover');
      expect(jsonDecode(ob.payload)['diff_kurus'], 0);
    });

    test('eksik nakit fark olarak kanıt kalır (counted < expected)', () async {
      await setUser('kurye-1');
      final custId = await CustomerRepository(db).create(name: 'Eksik Kasa');
      await LedgerRepository(db).tahsilat(custId, 10000, 'nakit');

      final id = await CashHandoverRepository(db)
          .devret(fromUserId: 'kurye-1', countedCashKurus: 9500);
      final row = await (db.select(db.cashHandovers)..where((t) => t.id.equals(id))).getSingle();
      expect(row.diffKurus, -500, reason: '9500 sayıldı − 10000 beklendi = −500 (eksik para kanıt)');
    });

    test('ikinci devir yalnız önceki devirden BERİ olan nakiti sayar (period_start)', () async {
      // Zaman damgaları AÇIK (saatlik aralık): 1. devir "şimdi"; ondan ÖNCEKİ nakit 2. devre girmez,
      // SONRAKİ girer. Alt-milisaniye zamanlamaya bağımlı değil (sağlam).
      final custId = await CustomerRepository(db).create(name: 'İki Devir');
      final handovers = CashHandoverRepository(db);
      final oldIso = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();

      // 1. devirden ÖNCE toplanan nakit (2 saat önce).
      await writeLedgerEntry(db, entryType: 'payment', amountKurus: -4000, paymentType: 'nakit',
          collectedByUserId: 'kurye-1', customerId: custId, occurredAt: oldIso);
      await handovers.devret(fromUserId: 'kurye-1', countedCashKurus: 4000); // 1. devir "şimdi"

      // 1. devirden SONRA toplanan nakit (1 saat sonra).
      final newIso = DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
      await writeLedgerEntry(db, entryType: 'payment', amountKurus: -6000, paymentType: 'nakit',
          collectedByUserId: 'kurye-1', customerId: custId, occurredAt: newIso);
      final id2 = await handovers.devret(fromUserId: 'kurye-1', countedCashKurus: 6000);

      final row2 = await (db.select(db.cashHandovers)..where((t) => t.id.equals(id2))).getSingle();
      expect(row2.expectedCashKurus, 6000, reason: 'yalnız 1. devirden beri toplanan nakit (önceki 4000 hariç)');
      expect(row2.diffKurus, 0);
    });

    test('kasa devri kalıcı ve tekil kayıt (append)', () async {
      await setUser('kurye-1');
      final id = await CashHandoverRepository(db)
          .devret(fromUserId: 'kurye-1', countedCashKurus: 0);
      final rows = await db.select(db.cashHandovers).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, id);
    });
  });
}
