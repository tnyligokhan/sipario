import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import '../screens/team.dart' show KuryeIzinleri, kuryeIzinleriOku;

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
    String? iban,
    String? orderCodeDisplay,
    KuryeIzinleri? kuryeIzin,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    // TUZAK (2026-07-29): bu yazım LWW upsert'tir — sunucu satırı gelen payload'la DEĞİŞTİRİR.
    // Sipariş kodu tercihi işletme profili formuna ait DEĞİL (ayrı bir ekranda yaşıyor), ama
    // payload'da eksik kalırsa sunucu onu varsayılana çeker: bayi adresini düzeltince kod
    // tercihi sessizce geri dönerdi. Bu yüzden alan, açıkça verilmediyse MEVCUT değerden
    // taşınır. Aynı disiplin ileride eklenecek her "form dışı" ayar için de geçerlidir.
    final mevcut = await get();
    final kodTercihi = orderCodeDisplay ?? mevcut?.orderCodeDisplay ?? 'musteri';
    // Kurye yetkileri de "form dışı ayar"dır (2026-08-04) ve yukarıdaki TUZAĞIN aynısına tabidir:
    // işletme profili formu bu anahtarları bilmez; payload'da eksik kalırsa sunucu onları
    // VARSAYILANA çeker ve bayi adresini düzeltince kapattığı iskonto yetkisi sessizce geri açılır.
    final izin = kuryeIzin ?? kuryeIzinleriOku(mevcut);

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
      'iban': iban,
      'courier_can_customers': izin.musteri,
      'courier_can_orders': izin.siparis,
      'courier_can_collect': izin.tahsilat,
      'courier_can_discount': izin.iskonto,
      'courier_can_day_end': izin.gunSonu,
      'order_code_display': kodTercihi,
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
            iban: Value(iban),
            courierCanCustomers: Value(izin.musteri),
            courierCanOrders: Value(izin.siparis),
            courierCanCollect: Value(izin.tahsilat),
            courierCanDiscount: Value(izin.iskonto),
            courierCanDayEnd: Value(izin.gunSonu),
            orderCodeDisplay: Value(kodTercihi),
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

  /// Yalnız KURYE YETKİLERİNİ değiştirir; profilin geri kalanı olduğu gibi taşınır
  /// (kullanıcı isteği 2026-08-04). Gerekçe `siparisKoduTercihiKaydet` ile birebir aynı:
  /// yetki ekranı işletme profilinin alanlarını (unvan, vergi no, IBAN…) bilmez ve bilseydi
  /// onları eksik gönderip sunucudaki profili boşaltma riski doğardı.
  Future<void> kuryeIzinleriKaydet(KuryeIzinleri izin) async {
    final m = await get();
    await save(
      businessName: m?.businessName,
      ownerName: m?.ownerName,
      phone: m?.phone,
      whatsapp: m?.whatsapp,
      addressText: m?.addressText,
      taxOffice: m?.taxOffice,
      taxNumber: m?.taxNumber,
      opensAt: m?.opensAt,
      closesAt: m?.closesAt,
      receiptNote: m?.receiptNote,
      iban: m?.iban,
      orderCodeDisplay: m?.orderCodeDisplay,
      kuryeIzin: izin,
    );
  }

  /// Yalnız sipariş kodu tercihini değiştirir; profilin geri kalanı OLDUĞU GİBİ taşınır.
  ///
  /// Ayrı bir metot çünkü tercih ayrı bir ekranda yaşıyor ve o ekran işletme profilinin
  /// alanlarını (unvan, vergi no…) bilmez — bilseydi, o alanları eksik gönderip sunucudaki
  /// profili boşaltma riski doğardı (LWW upsert satırı payload'la değiştirir).
  Future<void> siparisKoduTercihiKaydet(String tercih) async {
    final m = await get();
    await save(
      businessName: m?.businessName,
      ownerName: m?.ownerName,
      phone: m?.phone,
      whatsapp: m?.whatsapp,
      addressText: m?.addressText,
      taxOffice: m?.taxOffice,
      taxNumber: m?.taxNumber,
      opensAt: m?.opensAt,
      closesAt: m?.closesAt,
      receiptNote: m?.receiptNote,
      iban: m?.iban,
      orderCodeDisplay: tercih,
    );
  }
}
