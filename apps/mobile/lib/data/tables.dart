import 'package:drift/drift.dart';

// TABLOLAR İKİYE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 566 satırdı): işletme/altyapı
// tabloları ayrı parçada. `part` seçildi ki üretilmiş `.g.dart` hiç değişmesin.
part 'tables_isletme.dart';

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

  /// FAVORİ ÜRÜNLER — bu müşterinin "her zamanki" ürünleri (kullanıcı isteği 2026-08-11).
  /// İçerik JSON DİZİDİR: `["urun-1","urun-2"]`. null/boş = favori yok.
  ///
  /// NEDEN AYRI TABLO DEĞİL (karar verildi): müşteri satırı zaten LWW ile senkronlanıyor ve
  /// favori listesi tam olarak "bu müşterinin bir alanı"dır — iki cihaz farklı liste yazarsa
  /// çözüm LWW'nin kendisidir. Ayrı bir senkron varlığı (yeni entity_type, yeni tombstone,
  /// yeni çakışma kuralı, yeni pull dalı) bu bayi ölçeğinde taşınmayacak bir maliyettir.
  ///
  /// SIRA BAYİNİN TERCİHİDİR ve korunur (küme değil, DİZİ): bayi en çok sattığını başa alır.
  /// Çözümleme TEK yerdedir (`customer_repository.dart::favoriIdleriCoz`) ve bozuk/eski metinde
  /// çökmez, boş listeye düşer — sahadaki bir cihazda elle bozulmuş bir alan, müşteri ekranının
  /// tamamını açılmaz yapamaz.
  TextColumn get favoriteProductIds => text().nullable()();

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

  /// SATIR NOTU (kullanıcı isteği 2026-08-11) — "buzlu olsun", "kapıya bırak", "faturalı".
  ///
  /// `Orders.note` İLE KARIŞTIRILMAMALI: o siparişin tamamına ait tek nottur ("zili çalma"),
  /// bu ise TEK KALEME aittir. İkisini aynı alana yazmak, üç kalemlik bir siparişte hangi
  /// kalemin notlu olduğunu kaybettirirdi — kurye kapıda yanlış ürünü teslim eder.
  /// Satırda saklanır (ad/fiyat/birim ile aynı gerekçe: siparişin çekildiği andaki gerçek).
  TextColumn get note => text().nullable()();

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

  /// İPTAL KAYDI (kullanıcı kararı 2026-08-13): dolu ise bu satır bir devri GERİ ALIR ve iptal
  /// edilen devrin id'sini taşır. `ledger_entries.reversesEntryId` deseninin birebir aynısı.
  ///
  /// NEDEN KOLON, NEDEN SİLME DEĞİL: BRIEF kırmızı çizgi #2 — para kayıtları silinmez/ezilmez.
  /// Yanlış alınmış bir ara tahsilat gerçekten OLMUŞ bir olaydır (patron kuryeden para aldı,
  /// sonra iade etti); satırı yok etmek defterin "ne olduğunu" değil "ne olduğunu sandığımızı"
  /// anlatır hâle getirirdi. İptal, ters işaretli İKİNCİ bir satırdır: orijinal kanıt olarak
  /// yerinde durur, toplam kendiliğinden düzelir.
  ///
  /// NEDEN `day_closings.cash_handover_id` gibi İLİŞKİDEN türetilemedi: orada ilişkinin sahibi
  /// KARŞI TARAFTIR (kapanış deviri işaret eder) ve o yüzden kolon gereksizdi. Burada geri alan
  /// da alınan da aynı tablodadır; ilişkiyi taşıyacak başka bir yer yok.
  TextColumn get reversesHandoverId => text().nullable()();

  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

