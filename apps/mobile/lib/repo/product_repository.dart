import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import '../data/urun_secenekleri.dart';

/// Ürün yerel CRUD'u (oluştur/düzenle/pasifle). Yerel yazma + outbox aynı transaction'da.
class ProductRepository {
  ProductRepository(this.db);
  final AppDatabase db;

  /// Yeni ürün. barcode/imageUrl/imageLocalPath OPSİYONELDİR — mevcut çağrılar aynen çalışır.
  /// imageLocalPath senkronlanmaz (cihaz-yerel dosya yolu); imageUrl sunucudaki işaretçidir.
  Future<String> create({
    required String name,
    required int unitPriceKurus,
    String unit = 'adet',
    String? barcode,
    String? imageUrl,
    String? imageLocalPath,
    List<UrunSecenegi> secenekler = const [],
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final secenekMetni = secenekleriYaz(secenekler);
    final id = newId();

    await db.transaction(() async {
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: id,
            name: name,
            unitPriceKurus: unitPriceKurus,
            unit: Value(unit),
            barcode: Value(barcode),
            imageUrl: Value(imageUrl),
            imageLocalPath: Value(imageLocalPath),
            optionsJson: Value(secenekMetni),
            updatedOccurredAt: at,
            updatedDeviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'product',
          op: 'upsert',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: _payload(id, name, unitPriceKurus, unit, barcode, imageUrl, true, secenekMetni));
    });

    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    required int unitPriceKurus,
    String unit = 'adet',
    bool isActive = true,
    String? barcode,
    String? imageUrl,
    String? imageLocalPath,
    List<UrunSecenegi> secenekler = const [],
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final secenekMetni = secenekleriYaz(secenekler);

    await db.transaction(() async {
      await (db.update(db.products)..where((t) => t.id.equals(id))).write(ProductsCompanion(
        name: Value(name),
        unitPriceKurus: Value(unitPriceKurus),
        unit: Value(unit),
        barcode: Value(barcode),
        imageUrl: Value(imageUrl),
        imageLocalPath: Value(imageLocalPath),
        optionsJson: Value(secenekMetni),
        isActive: Value(isActive),
        updatedOccurredAt: Value(at),
        updatedDeviceId: Value(device),
      ));
      await enqueueOutbox(db,
          entityType: 'product',
          op: 'upsert',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: _payload(id, name, unitPriceKurus, unit, barcode, imageUrl, isActive, secenekMetni));
    });
  }

  /// Barkodla aktif ürün bul (tasarım: POS'ta okutarak sepete ekleme). Barkod tekil OLMADIĞINDAN
  /// (çevrimdışı çakışma reddedilmesin diye) en son güncellenen eşleşme döner; yoksa null.
  Future<Product?> findByBarcode(String barcode) {
    final normalized = barcode.replaceAll(RegExp(r'\D'), '');
    if (normalized.isEmpty) return Future.value(null);

    return (db.select(db.products)
          ..where((t) => t.barcode.equals(normalized) & t.isActive.equals(true) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedOccurredAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  static Map<String, Object?> _payload(
    String id,
    String name,
    int unitPriceKurus,
    String unit,
    String? barcode,
    String? imageUrl,
    bool isActive,
    String? optionsJson,
  ) =>
      {
        'id': id,
        'name': name,
        'unit_price_kurus': unitPriceKurus,
        'unit': unit,
        'barcode': barcode,
        'image_url': imageUrl,
        'is_active': isActive,
        // SEÇENEK LİSTESİ JSON DİZİ olarak gider (metin olarak değil): alanın kendisi zaten
        // JSON'dur ve metne sarmak sunucuda ikinci bir çözümleme dalı açardı — favori ürünlerde
        // (2026-08-11) verilen kararın aynısı, gerekçesi `FavoriUrunler` başlığında.
        'options': optionsJson == null ? null : jsonDecode(optionsJson),
      };

  /// Pasifle (silme yerine — geçmiş siparişler satırda fiyat/adı taşıdığından bozulmaz).
  Future<void> deactivate(String id) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final product = await (db.select(db.products)..where((t) => t.id.equals(id))).getSingle();

    await db.transaction(() async {
      await (db.update(db.products)..where((t) => t.id.equals(id))).write(ProductsCompanion(
        isActive: const Value(false),
        updatedOccurredAt: Value(at),
        updatedDeviceId: Value(device),
      ));
      await enqueueOutbox(db,
          entityType: 'product',
          op: 'upsert',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: _payload(
            id,
            product.name,
            product.unitPriceKurus,
            product.unit,
            product.barcode,
            product.imageUrl,
            false,
            // PASİFLEMEDE SEÇENEK LİSTESİ KORUNUR: ürün silinmiyor, rafa kaldırılıyor. Buraya
            // `null` geçmek, sunucudaki listeyi sessizce siler ve ürün yeniden aktifleştiğinde
            // bayi malzemelerini baştan yazmak zorunda kalırdı.
            product.optionsJson,
          ));
    });
  }
}
