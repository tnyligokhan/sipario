import 'package:uuid/uuid.dart';

/// İstemci kimlik ve saat yardımcıları (offline-first).
///
/// Kimlikler UUIDv7 ve İSTEMCİDE üretilir (DECISIONS): offline oluşan kaydın id'si sunucuya çıkınca
/// değişmez, referanslar kırılmaz, senkron sırası önemsizleşir. UUIDv7 zaman-sıralıdır (index dostu).
const _uuid = Uuid();

String newId() => _uuid.v7();

/// Düzeltilmiş sunucu saati (DECISIONS: sunucu her yanıtta saatini döner, istemci offset tutar;
/// occurred_at bu düzeltilmiş saatle yazılır — esnafın telefon saati yanlış olabilir).
String correctedNowIso(int serverOffsetMs) =>
    DateTime.now().toUtc().add(Duration(milliseconds: serverOffsetMs)).toIso8601String();

String nowIso() => DateTime.now().toUtc().toIso8601String();
