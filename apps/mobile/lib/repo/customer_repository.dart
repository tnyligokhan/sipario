import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

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
          payload: _payload(customerId, name, note, null));

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
  /// KARA LİSTE DAMGASI OKUNUP GERİ GÖNDERİLİR: sunucu `customer` upsert'ini LWW ile TAM SATIR
  /// olarak uygular, yani payload'da olmayan alan `null` yazılır. Damgayı taşımasaydık kara
  /// listedeki bir müşterinin yalnız adını düzeltmek onu SESSİZCE kara listeden çıkarırdı.
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
          payload: _payload(customerId, name, note, mevcut?.blacklistedAt));
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
          payload: _payload(customerId, mevcut.name, mevcut.note, damga));
    });
  }

  /// `customer` upsert payload'ının TEK üretim noktası. Sunucu tarafı bunu tam satır olarak
  /// uyguladığı için alan eklemek/unutmak sessiz veri kaybıdır — tek yerde tutulur.
  static Map<String, Object?> _payload(
    String id,
    String name,
    String? note,
    String? blacklistedAt,
  ) =>
      {'id': id, 'name': name, 'note': note, 'blacklisted_at': blacklistedAt};

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
