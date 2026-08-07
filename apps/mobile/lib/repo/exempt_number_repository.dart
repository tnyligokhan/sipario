import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

/// Muaf telefonlar (tasarım: "Muaf Telefonlar") — bu numaralar aradığında çağrı kartı ÇIKMAZ.
///
/// Eşleşme son 10 hane üzerindendir (DECISIONS arayan tanıma): +905321112233 / 05321112233 /
/// 5321112233 aynı numaradır. Native taraf da bu tabloya aynı anahtarla bakar.
class ExemptNumberRepository {
  ExemptNumberRepository(this.db);
  final AppDatabase db;

  Stream<List<ExemptNumber>> watchAll() => (db.select(db.exemptNumbers)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.updatedOccurredAt)]))
      .watch();

  /// Bu numara muaf mı? (Kart çizilmeden ÖNCE sorulur.)
  Future<bool> isExempt(String rawPhone) async {
    final last10 = phoneLast10(rawPhone);
    if (last10.isEmpty) return false;

    final row = await (db.select(db.exemptNumbers)
          ..where((t) => t.phoneLast10.equals(last10) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Listeye ekle. Mükerrer kayıt DB'de engellenmez (çevrimdışı çakışma reddedilmesin); çağıran
  /// ekran `isExempt` ile önden uyarır — aynı sonucu verdiği için mükerrer kayıt zararsızdır.
  Future<String> add({required String phoneE164, String? label}) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final id = newId();
    final last10 = phoneLast10(phoneE164);

    await db.transaction(() async {
      await db.into(db.exemptNumbers).insert(ExemptNumbersCompanion.insert(
            id: id,
            phoneE164: phoneE164,
            phoneLast10: last10,
            label: Value(label),
            updatedOccurredAt: at,
            updatedDeviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'exempt_number',
          op: 'upsert',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: {
            'id': id,
            'phone_e164': phoneE164,
            'phone_last10': last10,
            'label': label,
          });
    });

    return id;
  }

  /// Listeden çıkar — tombstone (fiziksel silme yok, senkronla yayılır).
  Future<void> remove(String id) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    await db.transaction(() async {
      await (db.update(db.exemptNumbers)..where((t) => t.id.equals(id))).write(
        ExemptNumbersCompanion(
          deletedAt: Value(at),
          updatedOccurredAt: Value(at),
          updatedDeviceId: Value(device),
        ),
      );
      await enqueueOutbox(db,
          entityType: 'exempt_number',
          op: 'delete',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: {'id': id});
    });
  }
}
