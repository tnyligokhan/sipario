import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

/// Çağrı yönü (tasarım: gelen | cevapsiz | giden).
enum CallDirection {
  incoming('incoming'),
  missed('missed'),
  outgoing('outgoing');

  const CallDirection(this.wire);
  final String wire;

  static CallDirection parse(String v) =>
      CallDirection.values.firstWhere((d) => d.wire == v, orElse: () => CallDirection.incoming);
}

/// Çağrı günlüğü (tasarım: "Son Aramalar"). Çağrı kaydedilir, sonradan sonucu ("Sipariş alındı")
/// ve doğan sipariş bağlanır — bu yüzden append-only DEĞİL, LWW varlığıdır.
///
/// Eşleşen müşteri son 10 hane ile bulunur (arayan tanımanın aynı anahtarı); bulunamazsa
/// customerId null kalır ve ekran "Kayıtsız numara" gösterir.
class CallLogRepository {
  CallLogRepository(this.db);
  final AppDatabase db;

  /// Son çağrılar (yeni üstte). Varsayılan 20 — "Son Aramalar" listesi kısa tutulur.
  Stream<List<CallLog>> watchRecent({int limit = 20}) => (db.select(db.callLogs)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
        ..limit(limit))
      .watch();

  /// Çağrıyı kaydet. customerId verilmezse numaradan (son 10 hane) OTOMATİK çözülür.
  ///
  /// [id] verilirse kayıt ÜZERİNE YAZILIR (upsert). Native çağrı kuyruğu bunu kullanır: bir
  /// çağrı kuyruğa iki kez düşebilir — zil anında "gelen", yanıtlanmadan biterse "cevapsız".
  /// İkincisi yeni bir çağrı değil, aynı çağrının son hâlidir; deterministik id olmasa günlükte
  /// tek çağrı iki satır olarak görünürdü. `call_logs` zaten LWW varlığıdır (append-only
  /// DEĞİL — sonuç ve doğan sipariş de sonradan yazılır), üzerine yazmak sözleşmeye uygundur.
  Future<String> log({
    required String phoneE164,
    required CallDirection direction,
    String? id,
    String? customerId,
    String? outcome,
    String? relatedOrderId,
    String? occurredAtIso,
  }) async {
    final meta = await db.syncState();
    final at = occurredAtIso ?? correctedNowIso(meta.serverTimeOffsetMs);
    final lww = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final kayitId = id ?? newId();
    final last10 = phoneLast10(phoneE164);
    final resolved = customerId ?? await _resolveCustomer(last10);

    await db.transaction(() async {
      await db.into(db.callLogs).insertOnConflictUpdate(CallLogsCompanion.insert(
            id: kayitId,
            customerId: Value(resolved),
            phoneE164: phoneE164,
            phoneLast10: last10,
            direction: direction.wire,
            outcome: Value(outcome),
            relatedOrderId: Value(relatedOrderId),
            occurredAt: at,
            deviceId: Value(device),
            // ÇAĞRIYI KİM KARŞILADI (2026-08-13): oturumdaki kullanıcı. `device_id` zaten
            // vardı ama CİHAZI anlatır, kişiyi değil — aynı telefonu iki kişi kullanabilir.
            // Oturum kurulmadan yazılan kayıtta null kalır ve atıf UYDURULMAZ.
            userId: Value(meta.userId),
            updatedOccurredAt: lww,
            updatedDeviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'call_log',
          op: 'upsert',
          entityId: kayitId,
          occurredAt: lww,
          deviceId: device,
          payload: _payload(
            id: kayitId,
            customerId: resolved,
            phoneE164: phoneE164,
            last10: last10,
            direction: direction.wire,
            outcome: outcome,
            relatedOrderId: relatedOrderId,
            userId: meta.userId,
            occurredAt: at,
          ));
    });

    return kayitId;
  }

  /// Çağrının sonucunu (ve varsa doğan siparişi) sonradan yaz — tasarımdaki "Sipariş alındı" satırı.
  /// Çağrı saati (`occurredAt`) DEĞİŞMEZ; yalnız LWW damgası ilerler.
  Future<void> setOutcome(String id, {String? outcome, String? relatedOrderId}) async {
    final meta = await db.syncState();
    final lww = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final row = await (db.select(db.callLogs)..where((t) => t.id.equals(id))).getSingle();

    await db.transaction(() async {
      await (db.update(db.callLogs)..where((t) => t.id.equals(id))).write(CallLogsCompanion(
        outcome: Value(outcome),
        relatedOrderId: Value(relatedOrderId ?? row.relatedOrderId),
        updatedOccurredAt: Value(lww),
        updatedDeviceId: Value(device),
      ));
      await enqueueOutbox(db,
          entityType: 'call_log',
          op: 'upsert',
          entityId: id,
          occurredAt: lww,
          deviceId: device,
          // ATIF DEĞİŞMEZ: sonucu sonradan yazan kişi çağrıyı karşılayan kişi olmak zorunda
          // değil (patron akşam "sipariş alındı" işaretleyebilir). Satırdaki `userId` olduğu
          // gibi taşınır — üzerine yazmak, çağrıyı yapmamış birini yapmış gibi gösterirdi.
          payload: _payload(
            id: id,
            customerId: row.customerId,
            phoneE164: row.phoneE164,
            last10: row.phoneLast10,
            direction: row.direction,
            outcome: outcome,
            relatedOrderId: relatedOrderId ?? row.relatedOrderId,
            userId: row.userId,
            occurredAt: row.occurredAt,
          ));
    });
  }

  Future<String?> _resolveCustomer(String last10) async {
    if (last10.isEmpty) return null;
    final phone = await (db.select(db.customerPhones)
          ..where((t) => t.phoneLast10.equals(last10) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    return phone?.customerId;
  }

  /// Sunucuya giden zarf. ADLANDIRILMIŞ PARAMETRE (2026-08-13): `user_id` eklenince liste
  /// dokuz sıralı argümana çıkıyordu ve iki çağrı yerinde `String?` tipli üç alan (outcome,
  /// relatedOrderId, userId) yan yana geliyordu — sırayı karıştırmak derlemeyi KIRMAZ, yalnız
  /// yanlış alanı gönderirdi.
  static Map<String, Object?> _payload({
    required String id,
    required String? customerId,
    required String phoneE164,
    required String last10,
    required String direction,
    required String? outcome,
    required String? relatedOrderId,
    required String? userId,
    required String occurredAt,
  }) =>
      {
        'id': id,
        'customer_id': customerId,
        'phone_e164': phoneE164,
        'phone_last10': last10,
        'direction': direction,
        'outcome': outcome,
        'related_order_id': relatedOrderId,
        'user_id': userId,
        'occurred_at': occurredAt,
      };
}
