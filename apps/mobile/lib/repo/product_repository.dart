import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

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
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
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
            updatedOccurredAt: at,
            updatedDeviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'product',
          op: 'upsert',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: _payload(id, name, unitPriceKurus, unit, barcode, imageUrl, true));
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
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    await db.transaction(() async {
      await (db.update(db.products)..where((t) => t.id.equals(id))).write(ProductsCompanion(
        name: Value(name),
        unitPriceKurus: Value(unitPriceKurus),
        unit: Value(unit),
        barcode: Value(barcode),
        imageUrl: Value(imageUrl),
        imageLocalPath: Value(imageLocalPath),
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
          payload: _payload(id, name, unitPriceKurus, unit, barcode, imageUrl, isActive));
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
  ) =>
      {
        'id': id,
        'name': name,
        'unit_price_kurus': unitPriceKurus,
        'unit': unit,
        'barcode': barcode,
        'image_url': imageUrl,
        'is_active': isActive,
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
          ));
    });
  }
}
