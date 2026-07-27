import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

/// Defter düşük seviye yazımları (FAZ 3). Bu fonksiyonlar TRANSACTION AÇMAZ — çağıran tek
/// transaction'a sarar (Faz 2 outbox atomikliği: yerel yazma + bakiye önbelleği + outbox AYNI
/// transaction'da). Böylece teslimat gibi çoklu-yazımlı akışlar (order_event + ledger) tek atomik
/// birim olur. Repo'lar (LedgerRepository/OrderRepository) bunları çağırır.
///
/// Para İMZALI (DECISIONS Faz 3 çift-satır): debit +borç, payment/credit −borç.

/// Bir defter kaydını ekler + customers.balance_kurus önbelleğini defterden yeniden kurar + outbox.
/// Kayıt id'sini döner. Kaydın client_event_id'si outbox olayıyla AYNIdır (sunucudan geri gelen kayıt
/// id ile "yoksa ekle" mantığında eşlenir — çift eklenmez).
/// id / clientEventId verilmezse UUIDv7 türetilir (rastgele, elle tahsilat/correction için). Teslim
/// akışında çağıran DETERMİNİSTİK uuid5 geçer (FAZ 4 teslim idempotensi) — iki cihaz aynı siparişi
/// teslim edince sunucu processed_events ile tekilleştirir. collectedByUserId nakit atfıdır (kasa devri).
Future<String> writeLedgerEntry(
  AppDatabase db, {
  required String entryType,
  required int amountKurus,
  required String occurredAt,
  String? id,
  String? clientEventId,
  String? customerId,
  String? paymentType,
  String? collectedByUserId,
  String? relatedOrderId,
  String? reversesEntryId,
  String? note,
  String? deviceId,
}) async {
  final entryId = id ?? newId();
  final ceid = clientEventId ?? newId();

  await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
        id: entryId,
        customerId: Value(customerId),
        entryType: entryType,
        amountKurus: amountKurus,
        paymentType: Value(paymentType),
        collectedByUserId: Value(collectedByUserId),
        relatedOrderId: Value(relatedOrderId),
        reversesEntryId: Value(reversesEntryId),
        note: Value(note),
        occurredAt: occurredAt,
        deviceId: Value(deviceId),
        clientEventId: ceid,
      ));

  if (customerId != null) {
    await recomputeCustomerBalance(db, customerId);
  }

  await enqueueOutbox(db,
      entityType: 'ledger',
      op: 'entry',
      entityId: entryId,
      occurredAt: occurredAt,
      deviceId: deviceId,
      clientEventId: ceid,
      payload: {
        'id': entryId,
        'customer_id': customerId,
        'entry_type': entryType,
        'amount_kurus': amountKurus,
        'payment_type': paymentType,
        'collected_by_user_id': collectedByUserId,
        'related_order_id': relatedOrderId,
        'reverses_entry_id': reversesEntryId,
        'note': note,
      });

  return entryId;
}

/// customers.balance_kurus = SUM(amount_kurus) — sunucu recompute'unun yerel aynası (DECISIONS:
/// bakiyenin kaynağı defterdir, balance_kurus önbellek; tüm entry_type'lar imzalı borç-deltasıdır).
Future<void> recomputeCustomerBalance(AppDatabase db, String customerId) async {
  final rows = await (db.select(db.ledgerEntries)..where((t) => t.customerId.equals(customerId))).get();
  final sum = rows.fold<int>(0, (s, r) => s + r.amountKurus);
  await (db.update(db.customers)..where((t) => t.id.equals(customerId)))
      .write(CustomersCompanion(balanceKurus: Value(sum)));
}
