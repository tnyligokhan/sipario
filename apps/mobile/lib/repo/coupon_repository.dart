import '../data/app_database.dart';
import '../data/ids.dart';
import 'ledger_ops.dart';

/// Kupon yerel iş akışları (FAZ 3). Kupon ADETtir (coupon_movements), paranın parası normal defter
/// (debit+payment) ile düşer. Her metod TEK transaction (writeCouponMovement/writeLedgerEntry içinde
/// yerel yazma + önbellek recompute + outbox). Bakiye eksiye düşebilir (DECISIONS); düzeltme correction.
class CouponRepository {
  CouponRepository(this.db);
  final AppDatabase db;

  /// Kupon satışı = peşin paket satışı: grant(+qty) + defter debit(+price) & payment(−price, ödeme
  /// tipiyle). productId null = genel kupon. paymentType: nakit|kart|havale (peşin ödendi).
  /// 3 outbox olayı (1 kupon + 2 defter) üretir. Kupon hareketinin id'sini döner.
  Future<String> kuponSat({
    required String customerId,
    String? productId,
    required int qty,
    required int priceKurus,
    required String paymentType,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    late String couponId;

    await db.transaction(() async {
      couponId = await writeCouponMovement(db,
          op: 'grant', customerId: customerId, qtyDelta: qty.abs(),
          productId: productId, occurredAt: at, deviceId: device);

      // Paketin parası: peşin satış çift-satırı (borç açılıp aynı anda kapanır → net borç 0, kasa dolu).
      await writeLedgerEntry(db,
          entryType: 'debit', amountKurus: priceKurus.abs(),
          customerId: customerId, occurredAt: at, deviceId: device);
      await writeLedgerEntry(db,
          entryType: 'payment', amountKurus: -priceKurus.abs(), paymentType: paymentType,
          customerId: customerId, occurredAt: at, deviceId: device);
    });

    return couponId;
  }

  /// Kupon düzeltme (ters hareket): correction, qtyDelta İMZALI verilir. Kaynak hareket SİLİNMEZ.
  Future<String> kuponDuzelt({
    required String customerId,
    String? productId,
    required String reversesMovementId,
    required int qtyDelta,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    late String id;
    await db.transaction(() async {
      id = await writeCouponMovement(db,
          op: 'correction', customerId: customerId, qtyDelta: qtyDelta,
          productId: productId, reversesMovementId: reversesMovementId,
          occurredAt: at, deviceId: meta.deviceId);
    });
    return id;
  }
}
