import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';

/// İşletme profili (tasarım: "İşletme Profili"). Cihazda TEK SATIR (id=1); sunucuda anahtar
/// tenant_id'dir ve payload'a id KONMAZ — iki cihazın çevrimdışı yazımı aynı satırda LWW ile
/// birleşir, çakışıp reddedilemez.
///
/// Firma kodu (`tenantCode`) ve rota hakkı (`routeCredits`) BURADAN YAZILAMAZ: sunucu sahiplidir,
/// senkron yanıtının subscription bloğuyla iner ve sync_meta'da önbelleklenir — `readOnly*` ile okunur.
class TenantSettingsRepository {
  TenantSettingsRepository(this.db);
  final AppDatabase db;

  Stream<TenantSetting?> watch() =>
      (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).watchSingleOrNull();

  Future<TenantSetting?> get() =>
      (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingleOrNull();

  /// Sunucu sahipli, salt-okunur alanlar: (firma kodu, kalan rota hakkı).
  Future<({String? tenantCode, int routeCredits})> readOnlyServerFields() async {
    final meta = await db.syncState();
    return (tenantCode: meta.tenantCode, routeCredits: meta.routeCredits);
  }

  /// Profili kaydet. TÜM alanlar birlikte yazılır (LWW upsert doğası: sunucu satırı gelen payload'la
  /// değiştirir) — çağıran formun güncel tam hâlini verir.
  Future<void> save({
    String? businessName,
    String? ownerName,
    String? phone,
    String? whatsapp,
    String? addressText,
    String? taxOffice,
    String? taxNumber,
    String? opensAt,
    String? closesAt,
    String? receiptNote,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    final payload = <String, Object?>{
      'business_name': businessName,
      'owner_name': ownerName,
      'phone': phone,
      'whatsapp': whatsapp,
      'address_text': addressText,
      'tax_office': taxOffice,
      'tax_number': taxNumber,
      'opens_at': opensAt,
      'closes_at': closesAt,
      'receipt_note': receiptNote,
    };

    await db.transaction(() async {
      await db.into(db.tenantSettings).insertOnConflictUpdate(TenantSettingsCompanion(
            id: const Value(1),
            businessName: Value(businessName),
            ownerName: Value(ownerName),
            phone: Value(phone),
            whatsapp: Value(whatsapp),
            addressText: Value(addressText),
            taxOffice: Value(taxOffice),
            taxNumber: Value(taxNumber),
            opensAt: Value(opensAt),
            closesAt: Value(closesAt),
            receiptNote: Value(receiptNote),
            updatedOccurredAt: Value(at),
            updatedDeviceId: Value(device),
          ));
      await enqueueOutbox(db,
          entityType: 'tenant_settings',
          op: 'upsert',
          // entityId sabit 'settings': outbox çakışma kontrolü (_newerPending) bu varlık için
          // kararlı bir anahtar bekler; sunucudaki gerçek anahtar (tenant_id) istemcide bilinmez.
          entityId: 'settings',
          occurredAt: at,
          deviceId: device,
          payload: payload);
    });
  }
}
