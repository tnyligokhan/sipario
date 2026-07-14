import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

/// Defter/kupon düşük seviye yazımları (FAZ 3). Bu fonksiyonlar TRANSACTION AÇMAZ — çağıran tek
/// transaction'a sarar (Faz 2 outbox atomikliği: yerel yazma + bakiye önbelleği + outbox AYNI
/// transaction'da). Böylece teslimat gibi çoklu-yazımlı akışlar (order_event + ledger + kupon)
/// tek atomik birim olur. Repo'lar (LedgerRepository/OrderRepository/CouponRepository) bunları çağırır.
///
/// Para İMZALI (DECISIONS Faz 3 çift-satır): debit +borç, payment/credit −borç. Kupon qtyDelta imzalı.

/// Bir defter kaydını ekler + customers.balance_kurus önbelleğini defterden yeniden kurar + outbox.
/// Kayıt id'sini döner. Kaydın client_event_id'si outbox olayıyla AYNIdır (sunucudan geri gelen kayıt
/// id ile "yoksa ekle" mantığında eşlenir — çift eklenmez).
Future<String> writeLedgerEntry(
  AppDatabase db, {
  required String entryType,
  required int amountKurus,
  required String occurredAt,
  String? customerId,
  String? paymentType,
  String? relatedOrderId,
  String? reversesEntryId,
  String? note,
  String? deviceId,
}) async {
  final id = newId();
  final clientEventId = newId();

  await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
        id: id,
        customerId: Value(customerId),
        entryType: entryType,
        amountKurus: amountKurus,
        paymentType: Value(paymentType),
        relatedOrderId: Value(relatedOrderId),
        reversesEntryId: Value(reversesEntryId),
        note: Value(note),
        occurredAt: occurredAt,
        deviceId: Value(deviceId),
        clientEventId: clientEventId,
      ));

  if (customerId != null) {
    await recomputeCustomerBalance(db, customerId);
  }

  await enqueueOutbox(db,
      entityType: 'ledger',
      op: 'entry',
      entityId: id,
      occurredAt: occurredAt,
      deviceId: deviceId,
      clientEventId: clientEventId,
      payload: {
        'id': id,
        'customer_id': customerId,
        'entry_type': entryType,
        'amount_kurus': amountKurus,
        'payment_type': paymentType,
        'related_order_id': relatedOrderId,
        'reverses_entry_id': reversesEntryId,
        'note': note,
      });

  return id;
}

/// Bir kupon hareketini ekler + coupon_balances önbelleğini hareketlerden yeniden kurar + outbox.
/// op = grant|use|correction. qtyDelta İMZALI. NEGATİF BAKİYE KABUL (hiçbir kontrol yok).
Future<String> writeCouponMovement(
  AppDatabase db, {
  required String op,
  required String customerId,
  required int qtyDelta,
  required String occurredAt,
  String? productId,
  String? relatedOrderId,
  String? reversesMovementId,
  String? note,
  String? deviceId,
}) async {
  final id = newId();
  final clientEventId = newId();

  await db.into(db.couponMovements).insert(CouponMovementsCompanion.insert(
        id: id,
        customerId: customerId,
        productId: Value(productId),
        movementType: op,
        qtyDelta: qtyDelta,
        relatedOrderId: Value(relatedOrderId),
        reversesMovementId: Value(reversesMovementId),
        note: Value(note),
        occurredAt: occurredAt,
        deviceId: Value(deviceId),
        clientEventId: clientEventId,
      ));

  await recomputeCouponBalance(db, customerId, productId);

  await enqueueOutbox(db,
      entityType: 'coupon',
      op: op,
      entityId: id,
      occurredAt: occurredAt,
      deviceId: deviceId,
      clientEventId: clientEventId,
      payload: {
        'id': id,
        'customer_id': customerId,
        'product_id': productId,
        'qty_delta': qtyDelta,
        'related_order_id': relatedOrderId,
        'reverses_movement_id': reversesMovementId,
        'note': note,
      });

  return id;
}

/// customers.balance_kurus = SUM(amount_kurus) — sunucu recompute'unun yerel aynası (DECISIONS:
/// bakiyenin kaynağı defterdir, balance_kurus önbellek; tüm entry_type'lar imzalı borç-deltasıdır).
Future<void> recomputeCustomerBalance(AppDatabase db, String customerId) async {
  final rows = await (db.select(db.ledgerEntries)..where((t) => t.customerId.equals(customerId))).get();
  final sum = rows.fold<int>(0, (s, r) => s + r.amountKurus);
  await (db.update(db.customers)..where((t) => t.id.equals(customerId)))
      .write(CustomersCompanion(balanceKurus: Value(sum)));
}

/// coupon_balances.balance_qty = SUM(qty_delta) — (customerId, productId) bazında. productId NULL
/// (genel kupon) SENTINEL '' ile saklanır (Drift PK'sinde NULL sorunlu). Eksiye düşebilir (KABUL).
Future<void> recomputeCouponBalance(AppDatabase db, String customerId, String? productId) async {
  final rows = await (db.select(db.couponMovements)
        ..where((t) =>
            t.customerId.equals(customerId) &
            (productId == null ? t.productId.isNull() : t.productId.equals(productId))))
      .get();
  final sum = rows.fold<int>(0, (s, r) => s + r.qtyDelta);
  await db.into(db.couponBalances).insertOnConflictUpdate(CouponBalancesCompanion(
        customerId: Value(customerId),
        productId: Value(productId ?? ''),
        balanceQty: Value(sum),
      ));
}
