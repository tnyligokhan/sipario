import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Favori ürünler — JSON çözümlemenin TEK yeri (v18)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bir müşterinin taşıyabileceği azami favori sayısı.
///
/// SINIR NEDEN VAR: favori listesi müşteri satırının İÇİNDE senkronlanır; sınırsız bir dizi,
/// tek bir müşteri kaydını her push'ta büyüyen bir yüke çevirirdi. 20 aynı zamanda ürün
/// sayfasının makul üst sınırıdır — "her zamanki ürünleri" 20'yi geçen bir müşteri, favori
/// değil kataloğun kendisini kullanıyordur.
const int kFavoriUstSinir = 20;

/// Saklanan JSON metnini id listesine çevirir. **Bu çözümlemenin BAŞKA bir kopyası olmamalı.**
///
/// ÇÖKMEZ, HİÇBİR GİRDİDE: null, boş metin, bozuk JSON, dizi olmayan JSON (nesne/sayı), dizi
/// içinde metin olmayan eleman — hepsi boş listeye ya da elemenin atlanmasına düşer. Gerekçe
/// sahadan: bu alan müşteri satırının içindedir ve müşteri satırı arayan-tanımadan sipariş
/// ekranına kadar her yerde okunur. Tek bozuk metinde atılan bir istisna, bir müşteriyi değil
/// UYGULAMANIN O EKRANINI kaybettirirdi.
///
/// SIRA KORUNUR (küme değil liste): sıra bayinin tercihidir — en çok sattığını başa alır.
List<String> favoriIdleriCoz(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  final Object? cozulen;
  try {
    cozulen = jsonDecode(json);
  } catch (_) {
    return const []; // bozuk metin: veri yok sayılır, ekran açılmaya devam eder
  }
  if (cozulen is! List) return const [];
  return [
    for (final e in cozulen)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
}

/// Id listesini saklanacak/gönderilecek NORMAL hâline getirir: kırpılır, boşlar elenir,
/// TEKRARLAR teklenir (ilk görülen sırayı korur) ve [kFavoriUstSinir] uygulanır.
///
/// Tekleme neden ilk görüleni tutar: bayi listeyi sürükleyerek düzenler; aynı ürünü ikinci kez
/// eklemek onu SONA taşımamalı, olduğu yerde bırakmalıdır.
List<String> favoriIdleriDuzelt(List<String> idler) {
  final gorulen = <String>{};
  final sonuc = <String>[];
  for (final ham in idler) {
    final id = ham.trim();
    if (id.isEmpty || !gorulen.add(id)) continue;
    sonuc.add(id);
    if (sonuc.length >= kFavoriUstSinir) break;
  }
  return sonuc;
}

/// Bir müşterinin favori id'lerini ÇÖZÜLMÜŞ ürünlere çevirir — BAYİNİN SIRASI korunur.
///
/// ÇÖZÜLEMEYEN ID SESSİZCE ELENİR (silinmiş ürün, başka bayiden kalmış id, senkron henüz
/// kataloğu getirmemiş): favori listesi müşteri satırının içinde yaşar ve ürün kataloğundan
/// BAĞIMSIZ senkronlanır — ikisinin bir an için ayrışması normaldir. Eleme yerine "bilinmeyen
/// ürün" satırı çizmek, bayiye silinmiş ürünü yeniden sipariş ettirirdi.
///
/// `isActive` FİLTRELENMEZ (bilinçli): "stokta yok" işaretli bir ürün hâlâ bu müşterinin
/// favorisidir ve LİSTEDE GÖRÜNMELİDİR — soluk/pasif çizmek ekranın kararıdır. Burada elemek,
/// bayinin "her zamanki siparişi"ni stok işareti yüzünden sessizce kaybettirirdi.
Future<List<Product>> favoriUrunleriOku(AppDatabase db, String customerId) async {
  final musteri =
      await (db.select(db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();
  final idler = favoriIdleriCoz(musteri?.favoriteProductIds);
  if (idler.isEmpty) return const [];

  final urunler = await (db.select(db.products)
        ..where((t) => t.id.isIn(idler) & t.deletedAt.isNull()))
      .get();

  // SIRA SORGUDAN DEĞİL id LİSTESİNDEN gelir: SQL `IN` sırayı garanti etmez ve bayinin
  // sürükleyerek kurduğu düzen tam da burada kaybolurdu.
  final indeks = {for (final u in urunler) u.id: u};
  return [for (final id in idler) ?indeks[id]];
}

/// [favoriUrunleriOku]'nun AKIŞI — sipariş ekranı buna abone olur. Boş liste = bölüm çizilmez.
///
/// İKİ TABLOYU BİRLİKTE İZLER (`customers` · `products`): favori listesi müşteri satırında,
/// ürünün adı/fiyatı katalogdadır. Yalnız `customers`ı izleyen bir akış, bayi ürünün fiyatını
/// değiştirdiğinde ESKİ fiyatı göstermeye devam ederdi.
///
/// `customSelect(...).watch()` bir TETİKTİR, veri kaynağı değil: `readsFrom` sayesinde iki
/// tablodan biri değişince tik atar, çözüm işini [favoriUrunleriOku] yapar. Alternatif olan
/// `asyncExpand` BOZUK olurdu — iç akış (ürün izleyicisi) hiç tamamlanmadığı için ilk olaydan
/// sonra dış akışın olayları HİÇ işlenmezdi.
Stream<List<Product>> watchFavoriUrunler(AppDatabase db, String customerId) =>
    _favoriUrunAkisi(db, customerId);

/// Akışın TEK gerçeklemesi. Ayrı ve PRIVATE bir ad taşıması zorunlu: `CustomerRepository`
/// üzerinde aynı adı taşıyan bir kolaylık metodu var ve sınıfın içinden `watchFavoriUrunler`
/// yazmak üst düzey fonksiyonu değil KENDİ METODUNU çağırırdı (sonsuz özyineleme).
Stream<List<Product>> _favoriUrunAkisi(AppDatabase db, String customerId) => db
    .customSelect('SELECT 1', readsFrom: {db.customers, db.products})
    .watch()
    .asyncMap((_) => favoriUrunleriOku(db, customerId));

/// Müşteri girdi tipleri (repo yüzeyi UI'dan bağımsız).
class PhoneInput {
  PhoneInput({required this.phoneE164, this.label, this.isPrimary = false});
  final String phoneE164;
  final String? label;
  final bool isPrimary;
}

class AddressInput {
  AddressInput({
    required this.addressText,
    this.label,
    this.region,
    this.lat,
    this.lng,
    this.isPrimary = false,
  });
  final String addressText;
  final String? label;

  /// Bölge/semt (tasarım: "Bölge"). Opsiyonel — mevcut çağrıları bozmaz.
  final String? region;
  final double? lat;
  final double? lng;
  final bool isPrimary;
}

/// Müşteri yerel CRUD'u. Her mutasyon yerel Drift yazımı + outbox olayını AYNI transaction'da yapar
/// (DECISIONS). Kimlikler istemcide UUIDv7. occurred_at düzeltilmiş sunucu saatiyle.
class CustomerRepository {
  CustomerRepository(this.db);
  final AppDatabase db;

  /// Yeni müşteri (+ opsiyonel telefon/adres). Müşteri id'sini döner.
  Future<String> create({
    required String name,
    String? note,
    List<PhoneInput> phones = const [],
    List<AddressInput> addresses = const [],
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final customerId = newId();

    await db.transaction(() async {
      await db.into(db.customers).insert(CustomersCompanion.insert(
            id: customerId,
            name: name,
            note: Value(note),
            updatedOccurredAt: at,
            updatedDeviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'customer',
          op: 'upsert',
          entityId: customerId,
          occurredAt: at,
          deviceId: device,
          payload: _payload(customerId, name, note, null, const []));

      for (final phone in phones) {
        await _insertPhone(customerId, phone, at, device);
      }
      for (final address in addresses) {
        await _insertAddress(customerId, address, at, device);
      }
    });

    return customerId;
  }

  /// Müşteri alanlarını düzenle (ad/not) — LWW meta tazelenir.
  ///
  /// KARA LİSTE DAMGASI VE FAVORİLER OKUNUP GERİ GÖNDERİLİR: sunucu `customer` upsert'ini LWW
  /// ile TAM SATIR olarak uygular, yani payload'da olmayan alan `null` yazılır. Damgayı
  /// taşımasaydık kara listedeki bir müşterinin yalnız adını düzeltmek onu SESSİZCE kara
  /// listeden çıkarırdı; favorileri taşımasaydık müşteri formu — ki favori diye bir alanı YOK —
  /// her "kaydet"te bayinin kurduğu listeyi silerdi. Aynı sınıf tuzak:
  /// `tenant_settings_repository.dart`'taki "form dışı ayar" notu.
  Future<void> rename(String customerId, {required String name, String? note}) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    await db.transaction(() async {
      final mevcut = await (db.select(db.customers)..where((t) => t.id.equals(customerId)))
          .getSingleOrNull();
      await (db.update(db.customers)..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          name: Value(name),
          note: Value(note),
          updatedOccurredAt: Value(at),
          updatedDeviceId: Value(device),
        ),
      );
      await enqueueOutbox(db,
          entityType: 'customer',
          op: 'upsert',
          entityId: customerId,
          occurredAt: at,
          deviceId: device,
          payload: _payload(customerId, name, note, mevcut?.blacklistedAt,
              favoriIdleriCoz(mevcut?.favoriteProductIds)));
    });
  }

  /// Kara listeye al / listeden çıkar. [ekle] true ise damga şimdi, false ise temizlenir.
  ///
  /// SİLME DEĞİLDİR: müşteri listede kalır, yalnız yeni sipariş açılamaz. Ayrı bir senkron op'u
  /// YOK — bu müşterinin bir ALANI ve çakışması tam da LWW'nin çözdüğü şeydir (iki cihaz ters
  /// yönde karar verirse son karar kazanır).
  Future<void> karaListe(String customerId, {required bool ekle}) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    await db.transaction(() async {
      final mevcut = await (db.select(db.customers)..where((t) => t.id.equals(customerId)))
          .getSingleOrNull();
      if (mevcut == null) return;

      final damga = ekle ? at : null;
      await (db.update(db.customers)..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          blacklistedAt: Value(damga),
          updatedOccurredAt: Value(at),
          updatedDeviceId: Value(device),
        ),
      );
      await enqueueOutbox(db,
          entityType: 'customer',
          op: 'upsert',
          entityId: customerId,
          occurredAt: at,
          deviceId: device,
          payload: _payload(customerId, mevcut.name, mevcut.note, damga,
              favoriIdleriCoz(mevcut.favoriteProductIds)));
    });
  }

  /// FAVORİ ÜRÜNLERİ yaz (v18). Verilen SIRA korunur — sıra bayinin tercihidir.
  ///
  /// Liste `favoriIdleriDuzelt`ten geçer: boşlar elenir, tekrarlar teklenir, [kFavoriUstSinir]
  /// uygulanır. Ürünün katalogda gerçekten var olduğu BURADA sorulmaz — silinmiş bir ürünün
  /// id'sini yazmayı engellemek yerine OKUMA tarafında atlıyoruz (`watchFavoriUrunler`), çünkü
  /// senkron sırası garantili değildir: başka bir cihazdan gelen favori, o ürünün pull'undan
  /// ÖNCE inebilir ve yazımda doğrulasaydık meşru bir favoriyi kalıcı olarak yutardık.
  ///
  /// Ad/not/kara liste damgası OKUNUP GERİ GÖNDERİLİR — `rename`deki tuzağın simetriği: favori
  /// ekranı müşterinin adını bilmez, payload'da eksik bıraksaydı sunucudaki adı silerdi.
  Future<void> favorileriKaydet(String customerId, List<String> productIds) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final favoriler = favoriIdleriDuzelt(productIds);

    await db.transaction(() async {
      final mevcut = await (db.select(db.customers)..where((t) => t.id.equals(customerId)))
          .getSingleOrNull();
      if (mevcut == null) return;

      await (db.update(db.customers)..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          favoriteProductIds:
              Value(favoriler.isEmpty ? null : jsonEncode(favoriler)),
          updatedOccurredAt: Value(at),
          updatedDeviceId: Value(device),
        ),
      );
      await enqueueOutbox(db,
          entityType: 'customer',
          op: 'upsert',
          entityId: customerId,
          occurredAt: at,
          deviceId: device,
          payload:
              _payload(customerId, mevcut.name, mevcut.note, mevcut.blacklistedAt, favoriler));
    });
  }

  /// Müşterinin favori ürün id'leri (tek atış). Bozuk/eski JSON'da boş liste.
  Future<List<String>> favorileriOku(String customerId) async {
    final m =
        await (db.select(db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();
    return favoriIdleriCoz(m?.favoriteProductIds);
  }

  /// [watchFavoriUrunler]'e DEVİR — gerçekleme dosyanın başındaki üst düzey çifttedir
  /// (`favoriUrunleriOku` / `watchFavoriUrunler`), burada tek satırlık bir kolaylık durur.
  ///
  /// NEDEN İKİ ÇAĞRI BİÇİMİ VAR: elinde zaten bir repo örneği olan ekran `repo.watchFavoriUrunler(id)`
  /// yazar, olmayan `watchFavoriUrunler(db, id)`. İkisi de AYNI kodu koşar — mantık kopyalanmadı,
  /// yalnız kapı iki taraftan açılıyor. Kopyalansaydı biri `deleted_at` süzgecini güncellemeyi
  /// unuttuğunda müşteri kartı ile sipariş formu aynı müşteriye farklı favori listesi gösterirdi.
  // Üst düzey `watchFavoriUrunler` sınıfın İÇİNDEN görünmez (aynı adlı metot onu gölgeler ve
  // çağrı kendine döner); bu yüzden ortak gerçekleme private `_favoriUrunAkisi`dır ve iki kapı
  // da ona iner.
  Stream<List<Product>> watchFavoriUrunler(String customerId) =>
      _favoriUrunAkisi(db, customerId);

  /// `customer` upsert payload'ının TEK üretim noktası. Sunucu tarafı bunu tam satır olarak
  /// uyguladığı için alan eklemek/unutmak sessiz veri kaybıdır — tek yerde tutulur.
  ///
  /// `favorite_product_ids` JSON DİZİ olarak gider (metin değil): alan zarfın kendisi zaten
  /// JSON'dur, diziyi metne kodlayıp göndermek sunucuda ikinci bir çözümleme adımı isterdi.
  /// Boş liste `null` yazılır — "favorisi yok" ile "boş dizi" arasında ürün açısından hiçbir
  /// fark yok ve kolonun boş hâli null'dır.
  static Map<String, Object?> _payload(
    String id,
    String name,
    String? note,
    String? blacklistedAt,
    List<String> favoriteProductIds,
  ) =>
      {
        'id': id,
        'name': name,
        'note': note,
        'blacklisted_at': blacklistedAt,
        'favorite_product_ids': favoriteProductIds.isEmpty ? null : favoriteProductIds,
      };

  /// Arşivle (tombstone). Silme fiziksel değildir; deleted_at işaretlenir + outbox delete.
  Future<void> archive(String customerId) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    await db.transaction(() async {
      await (db.update(db.customers)..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          deletedAt: Value(at),
          updatedOccurredAt: Value(at),
          updatedDeviceId: Value(device),
        ),
      );
      await enqueueOutbox(db,
          entityType: 'customer',
          op: 'delete',
          entityId: customerId,
          occurredAt: at,
          deviceId: device,
          payload: {'id': customerId});
    });
  }

  Future<String> addPhone(String customerId, PhoneInput phone) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    late String id;
    await db.transaction(() async {
      id = await _insertPhone(customerId, phone, at, device);
    });
    return id;
  }

  Future<String> addAddress(String customerId, AddressInput address) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    late String id;
    await db.transaction(() async {
      id = await _insertAddress(customerId, address, at, device);
    });
    return id;
  }

  Future<String> _insertPhone(String customerId, PhoneInput phone, String at, String? device) async {
    final id = newId();
    final last10 = phoneLast10(phone.phoneE164);
    await db.into(db.customerPhones).insert(CustomerPhonesCompanion.insert(
          id: id,
          customerId: customerId,
          phoneE164: phone.phoneE164,
          phoneLast10: last10,
          label: Value(phone.label),
          isPrimary: Value(phone.isPrimary),
          updatedOccurredAt: at,
          updatedDeviceId: Value(device),
        ));
    await enqueueOutbox(db,
        entityType: 'customer_phone',
        op: 'upsert',
        entityId: id,
        occurredAt: at,
        deviceId: device,
        payload: {
          'id': id,
          'customer_id': customerId,
          'phone_e164': phone.phoneE164,
          'phone_last10': last10,
          'label': phone.label,
          'is_primary': phone.isPrimary,
        });
    return id;
  }

  Future<String> _insertAddress(String customerId, AddressInput a, String at, String? device) async {
    final id = newId();
    await db.into(db.customerAddresses).insert(CustomerAddressesCompanion.insert(
          id: id,
          customerId: customerId,
          label: Value(a.label),
          addressText: a.addressText,
          region: Value(a.region),
          lat: Value(a.lat),
          lng: Value(a.lng),
          isPrimary: Value(a.isPrimary),
          updatedOccurredAt: at,
          updatedDeviceId: Value(device),
        ));
    await enqueueOutbox(db,
        entityType: 'customer_address',
        op: 'upsert',
        entityId: id,
        occurredAt: at,
        deviceId: device,
        payload: _addressPayload(id, customerId, a));
    return id;
  }

  /// Var olan adresi güncelle (tasarım: "Müşteriyi Düzenle" adres/bölge alanları ve "Konum Al").
  /// Tüm alanlar birlikte yazılır — LWW upsert'ün doğası budur: sunucu satırı gelen payload'la
  /// değiştirir, dolayısıyla çağıran GÜNCEL tam hâli vermelidir (AddressInput zaten tam hâldir).
  Future<void> updateAddress(String addressId, String customerId, AddressInput a) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    await db.transaction(() async {
      await (db.update(db.customerAddresses)..where((t) => t.id.equals(addressId))).write(
        CustomerAddressesCompanion(
          label: Value(a.label),
          addressText: Value(a.addressText),
          region: Value(a.region),
          lat: Value(a.lat),
          lng: Value(a.lng),
          isPrimary: Value(a.isPrimary),
          updatedOccurredAt: Value(at),
          updatedDeviceId: Value(device),
        ),
      );
      await enqueueOutbox(db,
          entityType: 'customer_address',
          op: 'upsert',
          entityId: addressId,
          occurredAt: at,
          deviceId: device,
          payload: _addressPayload(addressId, customerId, a));
    });
  }

  static Map<String, Object?> _addressPayload(String id, String customerId, AddressInput a) => {
        'id': id,
        'customer_id': customerId,
        'label': a.label,
        'address_text': a.addressText,
        'region': a.region,
        'lat': a.lat,
        'lng': a.lng,
        'is_primary': a.isPrimary,
      };
}
