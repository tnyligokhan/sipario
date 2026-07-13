import 'package:drift/drift.dart';

/// Yerel Drift şeması — sunucu tablolarının istemci aynası. İstemci TEK KİRACIDIR (cihazda tek
/// bayi oturur), bu yüzden tablolarda tenant_id YOKtur; izolasyon sunucuda RLS ile, istemcide
/// oturumla sağlanır.
///
/// SÖZLEŞME (DECISIONS Faz 0 — native arayan-tanıma tarafı bu dosyayı SALT-OKUNUR açar):
///  - dosya adı: sipario.db
///  - tablo `customers` (id, name, note, balance_kurus) ve `customer_phones`
///    (id, customer_id, phone_e164, phone_last10, label, is_primary)
///  - `phone_last10` üzerinde indeks (1 sn arayan-tanıma bütçesinin dayanağı)
/// Bu üçü DEĞİŞTİRİLEMEZ; native taraf aynı kalır.
///
/// Para her yerde int kuruş. Zaman alanları ISO8601 metin (sunucudan düzeltilmiş occurred_at
/// olduğu gibi saklanır; LWW karşılaştırması metin/tarih üzerinden yapılır). Tombstone: deleted_at.

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get note => text().nullable()();

  /// OKUMA-MODELİ ÖNBELLEĞİ (DECISIONS: kaynak defterdir). Native arayan-tanıma bunu tek satır okur.
  IntColumn get balanceKurus => integer().withDefault(const Constant(0))();

  // LWW meta + tombstone
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_phones_last10', columns: {#phoneLast10})
class CustomerPhones extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get phoneE164 => text()();
  TextColumn get phoneLast10 => text()();
  TextColumn get label => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomerAddresses extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get label => text().nullable()();
  TextColumn get addressText => text()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get unitPriceKurus => integer()();
  TextColumn get unit => text().withDefault(const Constant('adet'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().nullable()();

  /// ÖNBELLEK — kaynak order_events (DECISIONS). status: open|delivered|cancelled.
  TextColumn get status => text().withDefault(const Constant('open'))();
  IntColumn get totalKurus => integer().withDefault(const Constant(0))();
  TextColumn get paymentType => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get createdDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class OrderLines extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get productId => text().nullable()();

  /// SATIRDA saklanır (DECISIONS: siparişin çekildiği andaki gerçek).
  TextColumn get productName => text()();
  IntColumn get unitPriceKurus => integer()();
  IntColumn get qty => integer()();
  IntColumn get lineTotalKurus => integer()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sipariş olay aynası (APPEND). client_event_id ile tekil — sunucudan geri gelen kendi olayımızı
/// veya başka cihazın olayını "yoksa ekle" mantığıyla uygular (çift eklemez).
class OrderEvents extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get eventType => text()();
  TextColumn get payload => text().nullable()(); // json
  TextColumn get clientEventId => text()();
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {clientEventId},
      ];
}

/// Defter aynası (APPEND-ONLY — kırmızı çizgi #2). Bakiye buradan türer; istemci ezmez.
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get entryType => text()();
  IntColumn get amountKurus => integer()();
  TextColumn get relatedOrderId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get clientEventId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Giden kutusu (DECISIONS: yazma yolu outbox üzerinden). Yerel yazma + outbox AYNI transaction'da.
/// client_event_id tenant-içi tekil idempotency anahtarı; retry her zaman güvenli.
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientEventId => text()();
  TextColumn get entityType => text()();
  TextColumn get op => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get payload => text()(); // json
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending|acked|failed
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {clientEventId},
      ];
}

/// Senkron durumu (tek satır, id=1). Delta imleci + saat offset + ileri-sadece saat çıpası (Faz 5).
class SyncMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get lastPulledSeq => integer().withDefault(const Constant(0))();
  TextColumn get lastServerTimeIso => text().nullable()();
  IntColumn get serverTimeOffsetMs => integer().withDefault(const Constant(0))();
  IntColumn get elapsedAnchorMs => integer().nullable()();
  BoolColumn get snapshotDone => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text().nullable()();
  TextColumn get validUntilIso => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
