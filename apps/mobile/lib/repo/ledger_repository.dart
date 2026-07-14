import '../data/app_database.dart';
import '../data/ids.dart';
import 'ledger_ops.dart';

/// Defter yerel iş akışları (FAZ 3). Para İMZALI çift-satır modeli (DECISIONS): borç debit(+),
/// tahsilat payment(−, ödeme tipiyle), manuel alacak credit(−), düzeltme correction (ters kayıt).
/// Her metod TEK transaction: ledger_entries append + customers.balance_kurus recompute + outbox
/// (writeLedgerEntry içinde). Silme/UPDATE YOK — append-only; düzeltme yalnız ters kayıtla.
class LedgerRepository {
  LedgerRepository(this.db);
  final AppDatabase db;

  /// Tahsilat: müşteriden para girişi. amountKurus POZİTİF verilir, deftere payment(−) olarak düşer.
  /// paymentType: nakit|kart|havale (kasa gruplaması buna bağlı).
  Future<String> tahsilat(String customerId, int amountKurus, String paymentType) {
    return _write(customerId, entryType: 'payment', amountKurus: -amountKurus.abs(), paymentType: paymentType);
  }

  /// Manuel borç ekleme (veresiye satış dışı): debit(+). amountKurus POZİTİF.
  Future<String> borcEkle(String customerId, int amountKurus, {String? note}) {
    return _write(customerId, entryType: 'debit', amountKurus: amountKurus.abs(), note: note);
  }

  /// Manuel alacak/indirim: credit(−) borcu azaltır. amountKurus POZİTİF verilir.
  Future<String> alacak(String customerId, int amountKurus, {String? note}) {
    return _write(customerId, entryType: 'credit', amountKurus: -amountKurus.abs(), note: note);
  }

  /// Düzeltme (ters kayıt): bir defter kaydını correction ile düzeltir; amountKurus İMZALI verilir
  /// (düzeltilen kaydın etkisini sıfırlamak için ters işaret). Kaynak kayıt SİLİNMEZ (append-only).
  ///
  /// Ters çevirdiği kaydın payment_type'ını KOPYALAR: yanlış kayıt hangi kasa gözünden çıktıysa
  /// düzeltme de oradan düşsün (bakiye VE kasa birlikte düzelir). Ters çevrilen kayıt payment_type
  /// taşımıyorsa (ör. veresiye debit) correction da taşımaz → yalnız bakiye düzelir, kasaya dokunmaz.
  Future<String> duzeltme(String reversesEntryId, int amountKurus, {String? customerId, String? note}) async {
    final reversed = await (db.select(db.ledgerEntries)
          ..where((t) => t.id.equals(reversesEntryId)))
        .getSingleOrNull();
    return _write(customerId, entryType: 'correction', amountKurus: amountKurus,
        paymentType: reversed?.paymentType, reversesEntryId: reversesEntryId, note: note);
  }

  Future<String> _write(
    String? customerId, {
    required String entryType,
    required int amountKurus,
    String? paymentType,
    String? reversesEntryId,
    String? note,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    late String id;
    await db.transaction(() async {
      id = await writeLedgerEntry(db,
          entryType: entryType,
          amountKurus: amountKurus,
          customerId: customerId,
          paymentType: paymentType,
          reversesEntryId: reversesEntryId,
          note: note,
          occurredAt: at,
          deviceId: meta.deviceId);
    });
    return id;
  }
}
