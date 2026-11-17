import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';

/// 13.11.2026 sunucu yedek dönüşü kurtarma penceresi.
///
/// Sunucu 17.11.2026'da 13.11.2026 tarihli yedeğe döndüğünde, 13–17 Kasım arasında telefonlarda
/// üretilip eski sunucu tarafından onaylanmış (`status = 'acked'`) kayıtlar sunucudan silindi;
/// ancak telefonların `outbox` ve yerel tablolarında eksiksiz duruyor. Saat farkı ve yedek kesim
/// saati için pencere 12 Kasım 00:00 UTC'den başlatılır.
const String kYedekKaybiBaslangic = '2026-11-12T00:00:00';
const String kYedekKaybiBitis = '2026-11-18T00:00:00';

/// Karantina yeniden denemesinde (sürüm/API anahtarı değiştiğinde) yedek dönüşü kaybını onarır:
///  1. Pencere içindeki `acked` outbox olaylarını ve tüm `rejected` olayları `pending`e çevirir.
///  2. Başka cihazdan/panelden `pull` ile inmiş (bu cihazın `outbox`ında olmayan) ama bekleyen
///     olayların referans verdiği ya da pencere içinde oluşmuş yerel ebeveyn varlıkları
///     (`customer`, `product`, `customer_phone`, `customer_address`, `order:created`) negatif
///     sıra kimliğiyle kuyruğun başına ekler.
Future<int> yedekKaybiniKurtar(AppDatabase db) async {
  final geriAlinan = await (db.update(db.outbox)
        ..where((t) =>
            t.status.equals('rejected') |
            (t.status.equals('acked') &
                t.occurredAt.isBiggerOrEqualValue(kYedekKaybiBaslangic) &
                t.occurredAt.isSmallerThanValue(kYedekKaybiBitis))))
      .write(const OutboxCompanion(status: Value('pending'), attempts: Value(0)));

  final sentetik = await _eksikEbeveynleriEkle(db);
  return geriAlinan + sentetik;
}

Future<int> _eksikEbeveynleriEkle(AppDatabase db) async {
  final tumOutbox = await db.select(db.outbox).get();
  final bekleyenler = tumOutbox.where((r) => r.status == 'pending').toList();

  final varOlanEbeveyn = <String>{};
  final mevcutOlayKimlikleri = <String>{for (final r in tumOutbox) r.clientEventId};
  final arananMusteriler = <String>{};
  final arananUrunler = <String>{};
  final arananSiparisler = <String>{};

  for (final r in bekleyenler) {
    final p = _sozlukCoz(r.payload);
    final id = r.entityId ?? _metin(p['id']);
    if (r.entityType != 'order' && r.op == 'upsert' && id != null) {
      varOlanEbeveyn.add('${r.entityType}:$id');
    } else if (r.entityType == 'order' && r.op == 'created') {
      final oid = id ?? _metin(_sozluk(p['order'])['id']);
      if (oid != null) varOlanEbeveyn.add('order:$oid');
    }

    _ekleMetin(arananMusteriler, p['customer_id']);
    _ekleMetin(arananMusteriler, _sozluk(p['order'])['customer_id']);
    _ekleMetin(arananSiparisler, p['order_id']);
    _ekleMetin(arananSiparisler, p['related_order_id']);
    _ekleMetin(arananUrunler, p['product_id']);
    _ekleMetin(arananUrunler, _sozluk(p['line'])['product_id']);
    final satirlar = p['lines'];
    if (satirlar is List) {
      for (final s in satirlar) {
        if (s is Map) _ekleMetin(arananUrunler, s['product_id']);
      }
    }
  }

  // Pencere içinde oluşmuş veya bekleyen olayların işaret ettiği yerel siparişler.
  final siparisler = await (db.select(db.orders)
        ..where((t) =>
            t.deletedAt.isNull() &
            ((t.occurredAt.isBiggerOrEqualValue(kYedekKaybiBaslangic) &
                    t.occurredAt.isSmallerThanValue(kYedekKaybiBitis)) |
                t.id.isIn(arananSiparisler.toList()))))
      .get();

  final eksikSiparisler = <Order>[];
  final siparisSatirlari = <String, List<OrderLine>>{};
  for (final o in siparisler) {
    if (varOlanEbeveyn.contains('order:${o.id}')) continue;
    eksikSiparisler.add(o);
    if (o.customerId != null) arananMusteriler.add(o.customerId!);
    final satirlar = await (db.select(db.orderLines)
          ..where((t) => t.orderId.equals(o.id) & t.deletedAt.isNull()))
        .get();
    siparisSatirlari[o.id] = satirlar;
    for (final l in satirlar) {
      if (l.productId != null) arananUrunler.add(l.productId!);
    }
  }

  // Pencere içinde güncellenmiş telefon ve adresler (ebeveyn müşterilerini de arananlara ekler).
  final telefonlar = await (db.select(db.customerPhones)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.updatedOccurredAt.isBiggerOrEqualValue(kYedekKaybiBaslangic) &
            t.updatedOccurredAt.isSmallerThanValue(kYedekKaybiBitis)))
      .get();
  final eksikTelefonlar = [
    for (final ph in telefonlar)
      if (!varOlanEbeveyn.contains('customer_phone:${ph.id}')) ph,
  ];
  for (final ph in eksikTelefonlar) {
    arananMusteriler.add(ph.customerId);
  }

  final adresler = await (db.select(db.customerAddresses)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.updatedOccurredAt.isBiggerOrEqualValue(kYedekKaybiBaslangic) &
            t.updatedOccurredAt.isSmallerThanValue(kYedekKaybiBitis)))
      .get();
  final eksikAdresler = [
    for (final ad in adresler)
      if (!varOlanEbeveyn.contains('customer_address:${ad.id}')) ad,
  ];
  for (final ad in eksikAdresler) {
    arananMusteriler.add(ad.customerId);
  }

  final musteriler = await (db.select(db.customers)
        ..where((t) =>
            t.deletedAt.isNull() &
            ((t.updatedOccurredAt.isBiggerOrEqualValue(kYedekKaybiBaslangic) &
                    t.updatedOccurredAt.isSmallerThanValue(kYedekKaybiBitis)) |
                t.id.isIn(arananMusteriler.toList()))))
      .get();
  final eksikMusteriler = [
    for (final c in musteriler)
      if (!varOlanEbeveyn.contains('customer:${c.id}')) c,
  ];

  final urunler = await (db.select(db.products)
        ..where((t) =>
            t.deletedAt.isNull() &
            ((t.updatedOccurredAt.isBiggerOrEqualValue(kYedekKaybiBaslangic) &
                    t.updatedOccurredAt.isSmallerThanValue(kYedekKaybiBitis)) |
                t.id.isIn(arananUrunler.toList()))))
      .get();
  final eksikUrunler = [
    for (final p in urunler)
      if (!varOlanEbeveyn.contains('product:${p.id}')) p,
  ];

  final taslaklar = <({
    String clientEventId,
    String entityType,
    String op,
    String entityId,
    Map<String, Object?> payload,
    String occurredAt,
    String? deviceId,
  })>[];

  void ekleTaslak({
    required String entityType,
    required String op,
    required String entityId,
    required Map<String, Object?> payload,
    required String occurredAt,
    required String? deviceId,
  }) {
    final cid = deliveryEventId(entityId, 'kurtarma-$entityType-$op');
    if (!mevcutOlayKimlikleri.add(cid)) return;
    taslaklar.add((
      clientEventId: cid,
      entityType: entityType,
      op: op,
      entityId: entityId,
      payload: payload,
      occurredAt: occurredAt,
      deviceId: deviceId,
    ));
  }

  for (final c in eksikMusteriler) {
    ekleTaslak(
      entityType: 'customer',
      op: 'upsert',
      entityId: c.id,
      occurredAt: c.updatedOccurredAt,
      deviceId: c.updatedDeviceId,
      payload: {
        'id': c.id,
        'name': c.name,
        'note': c.note,
        'blacklisted_at': c.blacklistedAt,
        'favorite_product_ids': _jsonCoz(c.favoriteProductIds),
        'product_options': _jsonCoz(c.productOptionsJson),
        'product_prices': _jsonCoz(c.productPricesJson),
      },
    );
  }

  for (final p in eksikUrunler) {
    ekleTaslak(
      entityType: 'product',
      op: 'upsert',
      entityId: p.id,
      occurredAt: p.updatedOccurredAt,
      deviceId: p.updatedDeviceId,
      payload: {
        'id': p.id,
        'name': p.name,
        'unit_price_kurus': p.unitPriceKurus,
        'unit': p.unit,
        'barcode': p.barcode,
        'image_url': p.imageUrl,
        'is_active': p.isActive,
        'options': _jsonCoz(p.optionsJson),
      },
    );
  }

  for (final ph in eksikTelefonlar) {
    ekleTaslak(
      entityType: 'customer_phone',
      op: 'upsert',
      entityId: ph.id,
      occurredAt: ph.updatedOccurredAt,
      deviceId: ph.updatedDeviceId,
      payload: {
        'id': ph.id,
        'customer_id': ph.customerId,
        'phone_e164': ph.phoneE164,
        'phone_last10': ph.phoneLast10,
        'label': ph.label,
        'is_primary': ph.isPrimary,
      },
    );
  }

  for (final ad in eksikAdresler) {
    ekleTaslak(
      entityType: 'customer_address',
      op: 'upsert',
      entityId: ad.id,
      occurredAt: ad.updatedOccurredAt,
      deviceId: ad.updatedDeviceId,
      payload: {
        'id': ad.id,
        'customer_id': ad.customerId,
        'label': ad.label,
        'address_text': ad.addressText,
        'region': ad.region,
        'lat': ad.lat,
        'lng': ad.lng,
        'is_primary': ad.isPrimary,
      },
    );
  }

  for (final o in eksikSiparisler) {
    final satirlar = siparisSatirlari[o.id] ?? const <OrderLine>[];
    ekleTaslak(
      entityType: 'order',
      op: 'created',
      entityId: o.id,
      occurredAt: o.occurredAt,
      deviceId: o.createdDeviceId,
      payload: {
        'order': {
          'id': o.id,
          'customer_id': o.customerId,
          'payment_type': o.paymentType,
          'note': o.note,
        },
        'lines': [
          for (final l in satirlar)
            {
              'id': l.id,
              'product_id': l.productId,
              'product_name': l.productName,
              'unit_price_kurus': l.unitPriceKurus,
              'unit': l.unit,
              'note': l.note,
              'is_custom': l.isCustom,
              'qty': l.qty,
              'discount_kurus': l.discountKurus,
              'options': _jsonCoz(l.optionsJson),
            },
        ],
      },
    );
  }

  if (taslaklar.isEmpty) return 0;

  var enKucukId = 0;
  for (final r in tumOutbox) {
    if (r.id < enKucukId) enKucukId = r.id;
  }
  var siradakiId = enKucukId - taslaklar.length;
  final simdi = nowIso();

  for (final t in taslaklar) {
    await db.into(db.outbox).insert(
          OutboxCompanion.insert(
            id: Value(siradakiId++),
            clientEventId: t.clientEventId,
            entityType: t.entityType,
            op: t.op,
            entityId: Value(t.entityId),
            payload: jsonEncode(t.payload),
            occurredAt: t.occurredAt,
            deviceId: Value(t.deviceId),
            createdAt: simdi,
          ),
        );
  }

  return taslaklar.length;
}

Map<String, Object?> _sozlukCoz(String ham) {
  try {
    final c = jsonDecode(ham);
    if (c is Map) return c.cast<String, Object?>();
  } catch (_) {}
  return const {};
}

Map<String, Object?> _sozluk(Object? deger) =>
    deger is Map ? deger.cast<String, Object?>() : const {};

String? _metin(Object? deger) => deger is String && deger.isNotEmpty ? deger : null;

void _ekleMetin(Set<String> kume, Object? deger) {
  if (deger is String && deger.isNotEmpty) kume.add(deger);
}

Object? _jsonCoz(String? ham) {
  if (ham == null || ham.trim().isEmpty) return null;
  try {
    return jsonDecode(ham);
  } catch (_) {
    return null;
  }
}
