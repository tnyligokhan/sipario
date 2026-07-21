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

  /// ÖNBELLEK — kaynak assigned/unassigned order_events (FAZ 4). Hangi kuryeye atandığı; en son
  /// atama olayından türer. Tek kişilik bayide UI'da hiç görünmez (BRIEF), sunucu her zaman destekler.
  TextColumn get assignedUserId => text().nullable()();

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
/// FAZ 3: entry_type debit(+borç)|credit|payment(−borç)|correction. amount_kurus İMZALI (çift-satır).
/// paymentType yalnız payment'ta (nakit|kart|havale) — kasa gruplaması. reversesEntryId ters kayıt.
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get entryType => text()();
  IntColumn get amountKurus => integer()();
  TextColumn get paymentType => text().nullable()();

  /// FAZ 4: tahsilatı KİM aldı (kasa devri mutabakatının dayanağı). Nullable + geriye null; kasa
  /// özeti etkilenmez (hâlâ payment_type bazlı). Kuryenin beklenen nakiti bu alandan hesaplanır.
  TextColumn get collectedByUserId => text().nullable()();

  TextColumn get relatedOrderId => text().nullable()();
  TextColumn get reversesEntryId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get clientEventId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kupon hareketi aynası (APPEND-ONLY). Kupon PARA değil ADET; qtyDelta İMZALI (grant +N, use −qty,
/// correction imzalı). Bakiye coupon_balances'ten türer; eksiye düşebilir (DECISIONS). client_event_id
/// ile tekil — sunucudan geri gelen hareketi "yoksa ekle" ile uygular (çift eklemez).
@TableIndex(name: 'idx_coupon_moves_customer', columns: {#customerId})
class CouponMovements extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get movementType => text()();
  IntColumn get qtyDelta => integer()();
  TextColumn get relatedOrderId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get reversesMovementId => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get clientEventId => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {clientEventId},
      ];
}

/// Kupon bakiyesi ÖNBELLEĞİ (customers.balance_kurus ikizi). balanceQty = SUM(qtyDelta). İş anahtarı
/// (customerId, productId); genel kupon (ürün ayrımsız) için productId SENTINEL boş string '' — Drift
/// PK'sinde NULL sorunlu olduğundan '' kullanılır. Sunucu payload'ındaki null product_id → ''.
class CouponBalances extends Table {
  TextColumn get customerId => text()();
  TextColumn get productId => text().withDefault(const Constant(''))(); // '' = genel kupon
  IntColumn get balanceQty => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {customerId, productId};
}

/// Kasa devri (FAZ 4) — APPEND-ONLY kalıcı mutabakat aynası. Kurye gün sonu kasayı patrona devreder.
/// counted (sayılan) − expected (beklenen, anlık snapshot) = diff (kanıt olarak durur). Silme/güncelleme
/// YOK; düzeltme yeni devir kaydıyla. id ile tekil — sunucudan geri gelen kaydı "yoksa ekle" ile uygular.
class CashHandovers extends Table {
  TextColumn get id => text()();
  TextColumn get fromUserId => text()();          // kurye (kasayı devreden)
  TextColumn get toUserId => text().nullable()();  // patron (kasayı alan)
  IntColumn get countedCashKurus => integer()();
  IntColumn get expectedCashKurus => integer()();
  IntColumn get diffKurus => integer()();
  TextColumn get periodStart => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sunucu `users` aynası (FAZ 4b Dilim 4 — team bloğu). PII ASGARİ: yalnız id/name/role/status;
/// email/parola/telefon YOK (sunucu da göndermez). LWW/tombstone YOK — bu tablo salt sunucu-kaynaklı
/// önbellektir (coupon_balances sınıfı): her `team` bloğunda TOPTAN değiştirilir (delete-all + insert).
/// Kullanıcı istemciden ASLA push edilmez; atama hedefi ve atanan kurye adı çözümü için tutulur.
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get role => text()(); // patron|operator|kurye
  TextColumn get status => text()(); // active|disabled

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

  /// Oturumdaki kullanıcı (FAZ 4): teslim/tahsilatta collected_by_user_id ve kasa devrinde from_user_id
  /// kaynağı. Login akışı doldurur (Faz 5); yoksa null → nakit atfı boş, kasa devri opsiyonel.
  TextColumn get userId => text().nullable()();

  /// Abonelik durumu ÖNBELLEĞİ (FAZ 5a — DECISIONS: tek doğru kaynak sunucu, istemci önbellekler).
  /// Sunucunun her push/pull yanıtındaki `subscription` bloğundan yazılır. İstemci ileri-sadece saatle
  /// (lastServerTimeIso + elapsedAnchorMs) kilit/grace kararını bu değerlerden verir.
  TextColumn get validUntilIso => text().nullable()();
  TextColumn get lockedAtIso => text().nullable()();
  TextColumn get subscriptionStatus => text().nullable()(); // trial|active|locked|suspended

  /// Oturum (DİLİM 1 — Saha UI). Sanctum bearer token'ı uygulama-özel sandbox'taki bu DB'de durur;
  /// cihaz bayinindir, DB dosyasına başka uygulama erişemez (Android app-private). Token NULL = çıkış.
  /// Çıkışta yalnız token silinir — yerel iş verisi KALIR (offline-first; veri kaybettirme yok).
  TextColumn get authToken => text().nullable()();
  TextColumn get userName => text().nullable()();
  TextColumn get userRole => text().nullable()(); // patron|operator|kurye
  TextColumn get tenantName => text().nullable()();

  /// API taban adresi (varsayılan üretim; geliştirmede login ekranından değiştirilebilir).
  TextColumn get apiBaseUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
