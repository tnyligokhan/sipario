import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'ids.dart';

/// Bir yerel yazımın outbox olayını ekler (DECISIONS: yazma yolu outbox üzerinden; yerel yazma +
/// outbox AYNI transaction'da). Payload sunucu ChangeApplier'ın beklediği şekle serialize edilir.
Future<void> enqueueOutbox(
  AppDatabase db, {
  required String entityType,
  required String op,
  String? entityId,
  required Map<String, Object?> payload,
  required String occurredAt,
  String? deviceId,
  String? clientEventId,
}) {
  return db.into(db.outbox).insert(
        OutboxCompanion.insert(
          clientEventId: clientEventId ?? newId(),
          entityType: entityType,
          op: op,
          entityId: Value(entityId),
          payload: jsonEncode(payload),
          occurredAt: occurredAt,
          deviceId: Value(deviceId),
          createdAt: nowIso(),
        ),
      );
}

/// Son 10 hane — arayan tanımanın eşleşme anahtarı (Türkiye'de aynı numaranın üç yazımı da aynı).
String phoneLast10(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
}
