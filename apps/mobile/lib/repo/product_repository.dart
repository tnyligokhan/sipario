import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

/// Ürün yerel CRUD'u (oluştur/düzenle/pasifle). Yerel yazma + outbox aynı transaction'da.
class ProductRepository {
  ProductRepository(this.db);
  final AppDatabase db;

  Future<String> create({
    required String name,
    required int unitPriceKurus,
    String unit = 'adet',
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
            updatedOccurredAt: at,
            updatedDeviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'product',
          op: 'upsert',
          entityId: id,
          occurredAt: at,
          deviceId: device,
          payload: {'id': id, 'name': name, 'unit_price_kurus': unitPriceKurus, 'unit': unit, 'is_active': true});
    });

    return id;
  }

  Future<void> update(String id, {required String name, required int unitPriceKurus, String unit = 'adet', bool isActive = true}) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    await db.transaction(() async {
      await (db.update(db.products)..where((t) => t.id.equals(id))).write(ProductsCompanion(
        name: Value(name),
        unitPriceKurus: Value(unitPriceKurus),
        unit: Value(unit),
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
          payload: {'id': id, 'name': name, 'unit_price_kurus': unitPriceKurus, 'unit': unit, 'is_active': isActive});
    });
  }

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
          payload: {
            'id': id,
            'name': product.name,
            'unit_price_kurus': product.unitPriceKurus,
            'unit': product.unit,
            'is_active': false,
          });
    });
  }
}
