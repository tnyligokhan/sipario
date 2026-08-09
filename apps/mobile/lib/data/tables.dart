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

  /// MÜŞTERİ KODU (100, 101, 102…) — kiracı içinde sıralı, SUNUCU atar (v11, 2026-07-29).
  ///
  /// Nullable ve istemci tarafından ÜRETİLMEZ: sıra numarası tek bir dağıtıcı ister. İki cihaz
  /// çevrimdışıyken kendi numarasını üretseydi ikisi de aynı sayıyı alır, senkronda biri
  /// değiştirilmek zorunda kalırdı — bayinin kâğıda yazdığı numara ertesi gün başka bir müşteriye
  /// ait olurdu. Bu yüzden kod, senkron cevabıyla GELİR; henüz senkronlanmamış müşteride `null`
  /// durur ve arayüz yerine nötr bir işaret çizer (uydurma numara YAZILMAZ).
  IntColumn get code => integer().nullable()();

  /// OKUMA-MODELİ ÖNBELLEĞİ (DECISIONS: kaynak defterdir). Native arayan-tanıma bunu tek satır okur.
  IntColumn get balanceKurus => integer().withDefault(const Constant(0))();

  /// KARA LİSTE damgası (null = kara listede değil) — v12.
  ///
  /// `deletedAt` İLE KARIŞTIRILMAMALI, ikisi ayrı karardır: silinen müşteri listeden DÜŞER,
  /// kara listedeki müşteri listede KALIR ve rozetiyle görünür. Bayi ödemeyen müşteriyi gözden
  /// kaybetmek istemez — tam tersine görünsün ki borcunu takip etsin; kısıtlanan tek şey ona
  /// YENİ SİPARİŞ açmaktır.
  TextColumn get blacklistedAt => text().nullable()();

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

  /// Bölge/semt (tasarım: "Bölge" — Kepez/Muratpaşa/Lara). Adres satırının yanında gösterilir.
  TextColumn get region => text().nullable()();

  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_products_barcode', columns: {#barcode})
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get unitPriceKurus => integer()();
  TextColumn get unit => text().withDefault(const Constant('adet'))();

  /// Barkod (tasarım: POS'ta okutarak ekleme). TEKİL DEĞİL — çevrimdışı iki cihaz aynı barkodu
  /// girerse kayıt reddedilip kaybolurdu; UI uyarır, veri kabul edilir (sunucuda da aynı çizgi).
  TextColumn get barcode => text().nullable()();

  /// Sunucudan gelen görsel İŞARETÇİSİ (blob değil). Yükleme boru hattı (nesne deposu) AÇIK iş.
  TextColumn get imageUrl => text().nullable()();

  /// YALNIZ CİHAZ-YEREL: kullanıcının bu cihazda seçtiği görselin dosya yolu. Senkronlanmaz
  /// (sunucu payload'ında karşılığı yok) — imageUrl gelene kadar POS karosunu doldurur.
  TextColumn get imageLocalPath => text().nullable()();

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

  /// SİPARİŞ KODU (#248) — kiracı içinde sıralı, SUNUCU atar (v11, 2026-07-29).
  /// Gerekçe ve null davranışı `Customers.code` ile birebir aynıdır.
  IntColumn get code => integer().nullable()();

  /// ÖNBELLEK — kaynak assigned/unassigned order_events (FAZ 4). Hangi kuryeye atandığı; en son
  /// atama olayından türer. Tek kişilik bayide UI'da hiç görünmez (BRIEF), sunucu her zaman destekler.
  TextColumn get assignedUserId => text().nullable()();

  /// ÖNBELLEK — kaynak order_events (DECISIONS). status: open|delivered|cancelled.
  TextColumn get status => text().withDefault(const Constant('open'))();
  IntColumn get totalKurus => integer().withDefault(const Constant(0))();
  TextColumn get paymentType => text().nullable()();
  TextColumn get note => text().nullable()();

  /// ÖNBELLEK — kaynak `sort_set` order_events. Elle sıralama (sürükle-bırak rota sırası);
  /// assigned_user_id ile birebir aynı türetme deseni, iki cihaz aynı sırayı bulur.
  IntColumn get sortIndex => integer().nullable()();

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

  /// Birim de satırda saklanır (fiyat/ad ile aynı gerekçe: o anki gerçek).
  TextColumn get unit => text().nullable()();

  /// "Serbest satır" (katalogda olmayan tek seferlik iş). AÇIK bayrak: productId'nin null olması
  /// yeterli ayırt edici değildir (silinmiş ürünün satırı da null olabilir).
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

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
/// önbellektir: her `team` bloğunda TOPTAN değiştirilir (delete-all + insert).
/// Kullanıcı istemciden ASLA push edilmez; atama hedefi ve atanan kurye adı çözümü için tutulur.
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get role => text()(); // patron|operator|kurye
  TextColumn get status => text()(); // active|disabled

  /// Kullanıcının GİRİŞ ADI (kullanıcı isteği 2026-08-04 — Kuryeler ekranı gösterir ve düzenler).
  /// Sır değildir: patron kuryeye zaten kendisi söyler, unuttuğunda soracağı yer burasıdır.
  /// PAROLA BURADA YOK ve hiç olmayacak — parola yalnız YAZILIR (`/team/{id}/credentials`),
  /// hiçbir yönde okunmaz. Eski sunucu alanı göndermezse boş kalır.
  TextColumn get username => text().withDefault(const Constant(''))();

  /// Kurye telefonu (tasarım: Kuryeler ekranı gösterir/düzenler). Bayinin KENDİ personel iletişim
  /// bilgisidir; e-posta/parola hâlâ sunucuda kalır ve team bloğuna hiç girmez.
  TextColumn get phone => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// İşletme profili (tasarım: "İşletme Profili") — cihazda TEK SATIR (id=1, sync_meta deseni).
/// Sunucuda anahtar tenant_id'dir; istemci tek kiracı olduğu için tenant_id BURADA YOK (DECISIONS).
/// Push payload'ında id GÖNDERİLMEZ — sunucu oturumdaki tenant'ı anahtar olarak kullanır, böylece
/// iki cihazın çevrimdışı yazımı aynı satırda LWW ile birleşir (çakışıp reddedilemez).
class TenantSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get businessName => text().nullable()();
  TextColumn get ownerName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get whatsapp => text().nullable()();
  TextColumn get addressText => text().nullable()();
  TextColumn get taxOffice => text().nullable()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get opensAt => text().nullable()();  // 'SS:DD'
  TextColumn get closesAt => text().nullable()();
  TextColumn get receiptNote => text().nullable()();

  /// Bayinin KENDİ IBAN'ı (kullanıcı isteği 2026-08-04) — borçluya gönderilen WhatsApp
  /// hatırlatmasında geçer. Boşluksuz ve BÜYÜK harf saklanır (sunucu da normalleştirir);
  /// null = tanımlı değil, hatırlatma düğmesi o zaman nedenini söyleyip durur.
  TextColumn get iban => text().nullable()();

  /// IBAN ALICI ADI (kullanıcı isteği 2026-08-06) — hesap sahibinin AD SOYADI.
  ///
  /// NEDEN AYRI ALAN: hesap sahibi çoğu zaman ŞAHIS adıdır ("Mehmet Yılmaz"), işletme adıyla
  /// ("Merkez Su Bayii") aynı değildir; banka uygulaması havale ekranında ad soyad ister ve
  /// işletme adını yazan müşteri işlemi tamamlayamaz. Boşsa mesajda işletme adına DÜŞÜLÜR —
  /// güncelleme öncesi davranış budur, hiçbir bayi "Alıcı" satırını bu sürümle kaybetmemeli.
  TextColumn get ibanOwnerName => text().nullable()();

  /// BORÇ HATIRLATMA ŞABLONU (kullanıcı isteği 2026-08-06) — bayinin kendi mesaj metni.
  ///
  /// null/boş = VARSAYILAN metin (`borc_hatirlatma.dart`). Varsayılanı buraya kopyalamak,
  /// metni ileride iyileştirdiğimizde şablona hiç dokunmamış bayilerde eski metni dondururdu.
  /// Yer tutucular (`*musteriadi*`, `*siparistutar*`, `*ibanodemebilgileri*` …) gönderim anında
  /// çözülür; IBAN ve alıcı adı SABİT bloktur, metnin içinde düzenlenemez.
  TextColumn get reminderTemplate => text().nullable()();

  /// KURYE VE ROL YETKİ MATRİSİ — bayinin açıp kapatabildiği dinamik yetkiler.
  /// KİRACI düzeyindedir (kurye başına değil): 1–3 kişilik bayide kişi bazlı yetki, her yeni
  /// kuryede unutulan bir kurulum adımı doğururdu. Varsayılanlar sunucudakiyle AYNI olmalı —
  /// senkron gelmeden önce ekran bir kare boyunca bu değerleri gösterir.
  BoolColumn get courierCanCustomers => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanOrders => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanCollect => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanDiscount => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanDayEnd => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanSeeAllOrders => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanViewHistory => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanExpense => boolean().withDefault(const Constant(false))();
  BoolColumn get courierPhoneMask => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanCustomerLedger => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanDebtReminder => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanToggleStock => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanCallLog => boolean().withDefault(const Constant(false))();

  /// Sipariş SATIRINDA hangi kod görünsün: `musteri` (varsayılan) | `siparis`.
  /// Bayi tercihidir ve KİRACI düzeyindedir — cihaz-yerel olsaydı iki telefonlu bayi aynı
  /// listede iki farklı numara görürdü. Sipariş kodu her hâlükârda DETAYDA görünür.
  TextColumn get orderCodeDisplay =>
      text().withDefault(const Constant('musteri'))();

  TextColumn get updatedOccurredAt => text().nullable()();
  TextColumn get updatedDeviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Muaf telefonlar (tasarım: "Muaf Telefonlar") — bu numaralar aradığında çağrı kartı ÇIKMAZ.
/// `phone_last10` indeksi customer_phones ile aynı sözleşmedir: native taraf kartı çizmeden ÖNCE
/// bu tabloyu salt-okunur sorgular, bu yüzden tablo cihazda BULUNMAK ZORUNDA.
@TableIndex(name: 'idx_exempt_last10', columns: {#phoneLast10})
class ExemptNumbers extends Table {
  TextColumn get id => text()();
  TextColumn get phoneE164 => text()();
  TextColumn get phoneLast10 => text()();
  TextColumn get label => text().nullable()();
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Çağrı günlüğü (tasarım: "Son Aramalar"). direction: incoming|missed|outgoing.
/// APPEND-ONLY DEĞİL: `outcome`/`customerId` çağrıdan sonra zenginleşir (karttan sipariş açılınca);
/// para kaydı olmadığından kırmızı çizgi #2 kapsamı dışında — standart LWW + tombstone.
@TableIndex(name: 'idx_call_logs_occurred', columns: {#occurredAt})
class CallLogs extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().nullable()(); // kayıtsız numarada null
  TextColumn get phoneE164 => text()();
  TextColumn get phoneLast10 => text()();
  TextColumn get direction => text()();
  TextColumn get outcome => text().nullable()();
  TextColumn get relatedOrderId => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Gün sonu kapanış arşivi (tasarım: "Gün Sonu → Hesabı Kapat" + "Arşiv") — APPEND-ONLY ayna.
/// scope: day (günün tamamı, userId null) | courier (kurye hesabı, userId dolu). Özet tutarlar
/// kapatıldığı ANDAKİ gerçeği taşır; geç senkron arşivi değiştirmez. diffKurus fark KANITIdır.
class DayClosings extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get periodStart => text().nullable()();
  IntColumn get deliveryCount => integer().withDefault(const Constant(0))();
  IntColumn get totalCollectedKurus => integer().withDefault(const Constant(0))();
  IntColumn get cashNakitKurus => integer().withDefault(const Constant(0))();
  IntColumn get cashKartKurus => integer().withDefault(const Constant(0))();
  IntColumn get cashHavaleKurus => integer().withDefault(const Constant(0))();
  IntColumn get openCreditKurus => integer().withDefault(const Constant(0))();
  IntColumn get expectedCashKurus => integer().withDefault(const Constant(0))();
  IntColumn get countedCashKurus => integer().nullable()();
  IntColumn get diffKurus => integer().withDefault(const Constant(0))();
  TextColumn get cashHandoverId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();

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

  /// SUNUCUNUN SÖZLEŞME SÜRÜMÜ (`api_version`, SemVer) — son senkron turunda görülen değer.
  ///
  /// NEDEN SAKLANIYOR, anlık okunmuyor: uygulama offline-first çalışır ve bayi Ayarlar'ı çoğu
  /// zaman ağ yokken açar. Değeri saklamayan bir gösterim, tam da "sunucuya ulaşamıyorum"
  /// anında — yani sürümün en çok merak edildiği anda — boş kalırdı.
  ///
  /// null = "bu cihaz sunucuyla hiç konuşmadı ya da sunucu sürümünü henüz bildirmiyor".
  /// Eski değer YENİSİYLE EZİLİR ama YOKLUKLA EZİLMEZ (bkz. SyncEngine): sürüm bildirmeyen bir
  /// yanıt, bilinen son sürümü silmek için gerekçe değildir.
  TextColumn get apiVersion => text().nullable()();

  /// SUNUCU SAHİPLİ, salt-okunur önbellek (subscription bloğundan): tasarımdaki "Firma Kodu"
  /// (değiştirilemez) ve "Oto Sırala (rota) · N hak" sayacı. İstemci bunları YAZAMAZ.
  TextColumn get tenantCode => text().nullable()();
  IntColumn get routeCredits => integer().withDefault(const Constant(0))();

  /// Aylık oto-sıralama kotası (çekmecedeki "Aylık 50"). Kalan/kota oranı ilerleme çubuğunu
  /// çizer; kota bilinmezse çubuk çizilemez, o yüzden ayrı alan olarak saklanır.
  IntColumn get routeCreditsMonthly => integer().withDefault(const Constant(0))();

  /// CİHAZ-YEREL tercihler (senkronlanmaz): izin sihirbazının tamamlanma damgası ve tema seçimi.
  /// İzinler cihaza özgüdür — başka cihaza taşınmaları yanlış olurdu.
  TextColumn get setupCompletedAt => text().nullable()();
  TextColumn get themeMode => text().nullable()(); // koyu|acik

  @override
  Set<Column> get primaryKey => {id};
}
