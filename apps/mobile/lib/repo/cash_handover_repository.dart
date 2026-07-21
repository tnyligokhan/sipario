import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

/// Kasa devri yerel iş akışı (FAZ 4). Kurye gün sonu kasayı patrona devreder: SAYILAN nakit + sistemin
/// BEKLEDİĞİ nakit (anlık snapshot) + fark, kalıcı append-only kayıt olur (cash_handovers) + outbox,
/// tek transaction (offline-first atomiklik). Silme/UPDATE YOK; düzeltme yeni devir kaydıyla.
///
/// Beklenen nakit = period_start'tan beri collected_by=fromUserId olan NAKİT payment'ların kasa
/// katkısı (−amount_kurus toplamı; payment(−)→giren(+), nakit correction(+)→çıkan(−)). Kart/havale
/// fiziksel kasa değildir — devir yalnız NAKİT üzerinedir. period_start = fromUserId'nin son devri
/// yoksa bugünün TR (+03:00) gün başı.
class CashHandoverRepository {
  CashHandoverRepository(this.db);
  final AppDatabase db;

  static const _trOffset = Duration(hours: 3);

  Future<String> devret({
    required String fromUserId,
    String? toUserId,
    required int countedCashKurus,
    String? note,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final id = newId();

    final on = await onizle(fromUserId);
    final periodStart = on.periodStartIso;
    final expected = on.expectedKurus;
    final diff = countedCashKurus - expected;

    await db.transaction(() async {
      await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
            id: id,
            fromUserId: fromUserId,
            toUserId: Value(toUserId),
            countedCashKurus: countedCashKurus,
            expectedCashKurus: expected,
            diffKurus: diff,
            periodStart: Value(periodStart),
            occurredAt: at,
            deviceId: Value(device),
            note: Value(note),
          ));
      await enqueueOutbox(db,
          entityType: 'cash_handover',
          op: 'handover',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: {
            'id': id,
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
            'counted_cash_kurus': countedCashKurus,
            'expected_cash_kurus': expected,
            'diff_kurus': diff,
            'period_start': periodStart,
            'note': note,
          });
    });

    return id;
  }

  /// Devir ÖNİZLEMESİ (FAZ 4b Dilim 4): ekranın gösterdiği "beklenen nakit" ile devret()'in kayda
  /// yazdığı beklenen AYNI koddan çıksın diye public. Yalnız OKUR (yazma yok). devret() submit anında
  /// bunu YENİDEN çağırır → "anlık snapshot" tanımı korunur (ekranda gösterilen ile yazılan arasında
  /// süre geçse de kayıt submit anındaki değeri tutar).
  Future<HandoverOnizleme> onizle(String fromUserId) async {
    final periodStart = await _periodStart(fromUserId);
    final expected = await _expectedCash(fromUserId, periodStart);
    return HandoverOnizleme(periodStartIso: periodStart, expectedKurus: expected);
  }

  /// fromUserId'nin son devir occurred_at'i (mutabakat sınırı); yoksa bugünün TR gün başı (UTC ISO).
  Future<String> _periodStart(String fromUserId) async {
    final last = await (db.select(db.cashHandovers)
          ..where((t) => t.fromUserId.equals(fromUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(1))
        .getSingleOrNull();
    return last?.occurredAt ?? _trDayStartUtcIso();
  }

  /// period_start'tan beri kuryenin (collected_by) topladığı NAKİT kasa katkısı.
  Future<int> _expectedCash(String fromUserId, String periodStartIso) async {
    final rows = await (db.select(db.ledgerEntries)
          ..where((t) => t.paymentType.equals('nakit') & t.collectedByUserId.equals(fromUserId)))
        .get();
    final start = DateTime.tryParse(periodStartIso);
    var sum = 0;
    for (final e in rows) {
      final t = DateTime.tryParse(e.occurredAt);
      if (start != null && t != null && t.isBefore(start)) continue;
      sum += -e.amountKurus; // payment(−)→kasaya giren(+); nakit correction(+)→çıkan(−)
    }
    return sum;
  }

  /// Bugünün TR (+03:00) gün başının UTC ISO karşılığı (occurred_at UTC ISO ile karşılaştırılır).
  static String _trDayStartUtcIso() {
    final tr = DateTime.now().toUtc().add(_trOffset);
    final trMidnight = DateTime.utc(tr.year, tr.month, tr.day); // TR 00:00 (saat değeri olarak)
    return trMidnight.subtract(_trOffset).toIso8601String(); // gerçek UTC'ye geri al
  }
}

/// Devir önizleme değeri (salt-okunur): mutabakat dönemi başı + o dönemde kuryenin topladığı
/// beklenen nakit. Ekran gösterir, devret() aynı hesabı kayda yazar.
class HandoverOnizleme {
  HandoverOnizleme({required this.periodStartIso, required this.expectedKurus});
  final String periodStartIso;
  final int expectedKurus;
}
