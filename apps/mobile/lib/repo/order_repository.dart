import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import 'ledger_ops.dart';

class LineInput {
  LineInput({required this.productName, required this.unitPriceKurus, required this.qty, this.productId});
  final String? productId;
  final String productName;
  final int unitPriceKurus;
  final int qty;
}

/// Sipariş yerel CRUD'u. status/total YERELDE de olaylardan türer (sunucu önbelleğinin aynası).
/// Her mutasyon: order_events'e ekleme + orders/order_lines yazımı + outbox olayı, AYNI transaction.
/// order_event yerel id'si + AYNI client_event_id ile yazılır; sunucudan geri gelen olay bu
/// client_event_id ile "yoksa ekle" mantığında eşlenir (çift kayıt olmaz).
class OrderRepository {
  OrderRepository(this.db);
  final AppDatabase db;

  Future<String> create({String? customerId, String? note, required List<LineInput> lines}) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final orderId = newId();
    final clientEventId = newId();

    final linePayloads = <Map<String, Object?>>[];

    await db.transaction(() async {
      await db.into(db.orders).insert(OrdersCompanion.insert(
            id: orderId,
            customerId: Value(customerId),
            note: Value(note),
            occurredAt: at,
            createdDeviceId: Value(device),
          ));

      for (final l in lines) {
        final lineId = newId();
        await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
              id: lineId,
              orderId: orderId,
              productId: Value(l.productId),
              productName: l.productName,
              unitPriceKurus: l.unitPriceKurus,
              qty: l.qty,
              lineTotalKurus: l.unitPriceKurus * l.qty,
            ));
        linePayloads.add({
          'id': lineId,
          'product_id': l.productId,
          'product_name': l.productName,
          'unit_price_kurus': l.unitPriceKurus,
          'qty': l.qty,
        });
      }

      final payload = {
        'order': {'id': orderId, 'customer_id': customerId, 'note': note},
        'lines': linePayloads,
      };
      await _appendEvent(orderId, 'created', clientEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: 'created', entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: clientEventId, payload: payload);
    });

    return orderId;
  }

  /// Teslimat parayı/kuponu deftere düşürür (FAZ 3), teslim olayıyla AYNI transaction'da:
  ///  - veresiye → debit(+total) (borç yazılır).
  ///  - nakit/kart/havale → debit(+total) + payment(−total, ödeme tipiyle) (net borç 0, kasa dolu).
  ///  - kupon → para hareketi YOK (peşin ödendi); coupon use(−qty). couponQty verilmezse sipariş
  ///    satırlarının adet toplamından türer.
  ///
  /// TESLİM İDEMPOTENSİ (FAZ 4, DECISIONS): teslimden türeyen TÜM olayların client_event_id'si (ve
  /// ledger/coupon id'leri) sipariş id'sinden DETERMİNİSTİK uuid5 ile üretilir. İki cihaz aynı siparişi
  /// offline teslim edince AYNI id'ler → sunucu processed_events UNIQUE ile tek defter seti bırakır.
  /// Yerel çift-dokunma zaten teslim edilmiş siparişte erken döner (UI koruması; asıl garanti uuid5).
  ///
  /// collectedByUserId nakit atfıdır (kasa devri); verilmezse oturumdaki kullanıcıdan (syncMeta) alınır.
  Future<void> deliver(String orderId,
      {required String paymentType, int? couponQty, String? collectedByUserId}) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final collector = collectedByUserId ?? meta.userId;

    final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    if (order.status == 'delivered') return; // çift-dokunma koruması (yerel no-op)

    // Deterministik client_event_id / id'ler — iki cihazda AYNI (idempotensi inşa gereği).
    final deliverEventId = deliveryEventId(orderId, 'order');

    await db.transaction(() async {
      // 1) Teslim olayı + ödeme tipi + önbellek + outbox (mevcut sipariş akışı).
      await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
          .write(OrdersCompanion(paymentType: Value(paymentType)));
      final payload = {'order_id': orderId, 'payment_type': paymentType};
      await _appendEvent(orderId, 'delivered', deliverEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: 'delivered', entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: deliverEventId, payload: payload);

      // 2) Para/kupon deftere düşer. total recompute sonrası aktif satır toplamıdır.
      final lines = await _activeLines(orderId);
      final total = lines.fold<int>(0, (s, l) => s + l.lineTotalKurus);
      final customerId = order.customerId;

      switch (paymentType) {
        case 'veresiye':
          await writeLedgerEntry(db, entryType: 'debit', amountKurus: total,
              id: deliveryEventId(orderId, 'debit'), clientEventId: deliveryEventId(orderId, 'debit'),
              customerId: customerId, relatedOrderId: orderId, occurredAt: at, deviceId: device);
        case 'nakit':
        case 'kart':
        case 'havale':
          await writeLedgerEntry(db, entryType: 'debit', amountKurus: total,
              id: deliveryEventId(orderId, 'debit'), clientEventId: deliveryEventId(orderId, 'debit'),
              customerId: customerId, relatedOrderId: orderId, occurredAt: at, deviceId: device);
          await writeLedgerEntry(db, entryType: 'payment', amountKurus: -total, paymentType: paymentType,
              id: deliveryEventId(orderId, 'payment'), clientEventId: deliveryEventId(orderId, 'payment'),
              collectedByUserId: collector,
              customerId: customerId, relatedOrderId: orderId, occurredAt: at, deviceId: device);
        case 'kupon':
          if (customerId == null) {
            throw ArgumentError('Kuponla teslimat için müşteri gerekli.');
          }
          final qty = (couponQty ?? lines.fold<int>(0, (s, l) => s + l.qty)).abs();
          await writeCouponMovement(db, op: 'use', customerId: customerId, qtyDelta: -qty,
              id: deliveryEventId(orderId, 'coupon'), clientEventId: deliveryEventId(orderId, 'coupon'),
              relatedOrderId: orderId, occurredAt: at, deviceId: device);
      }
    });
  }

  /// Siparişi bir kuryeye ata (FAZ 4, olay-kaynaklı). assigned order olayı + orders.assignedUserId
  /// önbelleği + outbox, tek transaction (_statusEvent deseni). Tek kişilik bayide UI'da hiç çağrılmaz.
  Future<void> assign(String orderId, String userId) =>
      _statusEvent(orderId, 'assigned', {'order_id': orderId, 'assigned_user_id': userId},
          assignedUserId: userId, setAssignedFlag: true);

  /// Atamayı geri al (FAZ 4). unassigned olayı + orders.assignedUserId = null.
  Future<void> unassign(String orderId) =>
      _statusEvent(orderId, 'unassigned', {'order_id': orderId},
          assignedUserId: null, setAssignedFlag: true);

  Future<void> cancel(String orderId) =>
      _statusEvent(orderId, 'cancelled', {'order_id': orderId});

  Future<void> setPayment(String orderId, String paymentType) =>
      _statusEvent(orderId, 'payment_set', {'order_id': orderId, 'payment_type': paymentType}, paymentType: paymentType);

  Future<void> setNote(String orderId, String? note) =>
      _statusEvent(orderId, 'note_set', {'order_id': orderId, 'note': note}, note: note, setNoteFlag: true);

  Future<String> addLine(String orderId, LineInput l) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final clientEventId = newId();
    final lineId = newId();

    await db.transaction(() async {
      await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
            id: lineId,
            orderId: orderId,
            productId: Value(l.productId),
            productName: l.productName,
            unitPriceKurus: l.unitPriceKurus,
            qty: l.qty,
            lineTotalKurus: l.unitPriceKurus * l.qty,
          ));
      final payload = {
        'order_id': orderId,
        'line': {
          'id': lineId,
          'product_id': l.productId,
          'product_name': l.productName,
          'unit_price_kurus': l.unitPriceKurus,
          'qty': l.qty,
        },
      };
      await _appendEvent(orderId, 'line_added', clientEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: 'line_added', entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: clientEventId, payload: payload);
    });

    return lineId;
  }

  Future<void> removeLine(String orderId, String lineId) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final clientEventId = newId();

    await db.transaction(() async {
      await (db.update(db.orderLines)..where((t) => t.id.equals(lineId)))
          .write(OrderLinesCompanion(deletedAt: Value(at)));
      final payload = {'order_id': orderId, 'line_id': lineId};
      await _appendEvent(orderId, 'line_removed', clientEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: 'line_removed', entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: clientEventId, payload: payload);
    });
  }

  Future<void> _statusEvent(
    String orderId,
    String op,
    Map<String, Object?> payload, {
    String? paymentType,
    String? note,
    bool setNoteFlag = false,
    String? assignedUserId,
    bool setAssignedFlag = false,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final clientEventId = newId();

    await db.transaction(() async {
      if (paymentType != null) {
        await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
            .write(OrdersCompanion(paymentType: Value(paymentType)));
      }
      if (setNoteFlag) {
        await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
            .write(OrdersCompanion(note: Value(note)));
      }
      if (setAssignedFlag) {
        await (db.update(db.orders)..where((t) => t.id.equals(orderId)))
            .write(OrdersCompanion(assignedUserId: Value(assignedUserId)));
      }
      await _appendEvent(orderId, op, clientEventId, payload, at, device);
      await _recompute(orderId);
      await enqueueOutbox(db,
          entityType: 'order', op: op, entityId: orderId,
          occurredAt: at, deviceId: device, clientEventId: clientEventId, payload: payload);
    });
  }

  Future<void> _appendEvent(
    String orderId,
    String type,
    String clientEventId,
    Map<String, Object?> payload,
    String at,
    String? device,
  ) {
    return db.into(db.orderEvents).insert(OrderEventsCompanion.insert(
          id: newId(),
          orderId: orderId,
          eventType: type,
          payload: Value(jsonEncode(payload)),
          clientEventId: clientEventId,
          occurredAt: at,
          deviceId: Value(device),
        ));
  }

  /// Silinmemiş sipariş satırları (total ve kupon adedi buradan türer).
  Future<List<OrderLine>> _activeLines(String orderId) =>
      (db.select(db.orderLines)..where((t) => t.orderId.equals(orderId) & t.deletedAt.isNull())).get();

  /// status/total/assignedUserId'i olaylardan + aktif satırlardan türet (sunucu recompute'unun aynası).
  Future<void> _recompute(String orderId) async {
    final events = await (db.select(db.orderEvents)..where((t) => t.orderId.equals(orderId))).get();
    final hasCancelled = events.any((e) => e.eventType == 'cancelled');
    final hasDelivered = events.any((e) => e.eventType == 'delivered');
    final status = hasCancelled ? 'cancelled' : (hasDelivered ? 'delivered' : 'open');

    final lines = await _activeLines(orderId);
    final total = lines.fold<int>(0, (s, l) => s + l.lineTotalKurus);

    await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(OrdersCompanion(
      status: Value(status),
      totalKurus: Value(total),
      assignedUserId: Value(_deriveAssignedUserId(events)),
    ));
  }

  /// assigned_user_id önbelleğini en son assigned/unassigned olayından türet (sunucu deseninin aynası).
  /// occurred_at'e göre sırala; en son assigned ise payload'daki kullanıcı, unassigned ise null.
  String? _deriveAssignedUserId(List<OrderEvent> events) {
    final assignEvents = events
        .where((e) => e.eventType == 'assigned' || e.eventType == 'unassigned')
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    if (assignEvents.isEmpty) return null;
    final last = assignEvents.last;
    if (last.eventType != 'assigned' || last.payload == null) return null;
    return (jsonDecode(last.payload!) as Map<String, dynamic>)['assigned_user_id'] as String?;
  }
}
