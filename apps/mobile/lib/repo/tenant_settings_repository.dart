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

  /// Profili kaydet — KISMİ GÜNCELLEME. Yalnız VERİLEN alanlar değişir, verilmeyen her alan
  /// cihazdaki mevcut değerinden taşınır.
  ///
  /// ══ NEDEN `Value<>` SENTİNELİ, NEDEN DÜZ `String?` DEĞİL (2026-08-13) ═══════════════════
  /// Bu yazım bir LWW UPSERT'tir: sunucu satırı gelen payload'la DEĞİŞTİRİR. İmza düz `String?`
  /// olduğu sürece "alan verilmedi" ile "alan boşaltılsın" AYNI ŞEYE (null) benziyordu, yani
  /// her çağıran TÜM alanları göndermek zorundaydı. Bedeli koda yazılmıştı: `kuryeIzinleriKaydet`
  /// ve `siparisKoduTercihiKaydet` metotlarının her biri 14 alanı ELLE taşıyan birer kopyaydı
  /// ve doc'ta "aynı disiplin ileride eklenecek her form dışı ayar için de geçerlidir" yazıyordu
  /// — yani her yeni ayar ekranı ÜÇÜNCÜ, DÖRDÜNCÜ kopyayı doğuracaktı. Bir alanı listeye
  /// eklemeyi unutmanın cezası sessizdi: bayi sipariş kodunu değiştirince IBAN'ı silinirdi.
  ///
  /// `Value.absent()` bu iki hâli AYIRIR: `Value(null)` "boşalt" demektir ve çalışır,
  /// `Value.absent()` "dokunma" demektir. Böylece ayarların ekranlara bölünmesi güvenli hâle
  /// gelir — her ekran YALNIZ kendi alanlarını gönderir ve diğerlerini bilmesi GEREKMEZ.
  Future<void> save({
    Value<String?> businessName = const Value.absent(),
    Value<String?> ownerName = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> whatsapp = const Value.absent(),
    Value<String?> addressText = const Value.absent(),
    Value<String?> taxOffice = const Value.absent(),
    Value<String?> taxNumber = const Value.absent(),
    Value<String?> opensAt = const Value.absent(),
    Value<String?> closesAt = const Value.absent(),
    Value<String?> receiptNote = const Value.absent(),
    Value<String?> iban = const Value.absent(),
    Value<String?> ibanOwnerName = const Value.absent(),
    Value<String?> reminderTemplate = const Value.absent(),
    Value<String> orderCodeDisplay = const Value.absent(),
    Value<bool> preparedProducts = const Value.absent(),
    KuryeIzinleri? kuryeIzin,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    final mevcut = await get();

    /// Verilmeyen alan MEVCUT değerinden taşınır; `Value(null)` ise gerçekten boşaltılır.
    String? al(Value<String?> v, String? simdiki) => v.present ? v.value : simdiki;

    final ad = al(businessName, mevcut?.businessName);
    final sahip = al(ownerName, mevcut?.ownerName);
    final tel = al(phone, mevcut?.phone);
    final wa = al(whatsapp, mevcut?.whatsapp);
    final adres = al(addressText, mevcut?.addressText);
    final vDaire = al(taxOffice, mevcut?.taxOffice);
    final vNo = al(taxNumber, mevcut?.taxNumber);
    final acilis = al(opensAt, mevcut?.opensAt);
    final kapanis = al(closesAt, mevcut?.closesAt);
    final fisNotu = al(receiptNote, mevcut?.receiptNote);
    final ibanNo = al(iban, mevcut?.iban);
    final ibanAd = al(ibanOwnerName, mevcut?.ibanOwnerName);
    final sablon = al(reminderTemplate, mevcut?.reminderTemplate);
    final kodTercihi = orderCodeDisplay.present
        ? orderCodeDisplay.value
        : (mevcut?.orderCodeDisplay ?? 'musteri');
    // HAZIRLANAN ÜRÜN YETENEĞİ (2026-08-18) de aynı kuralla taşınır: bu anahtarı yalnız kendi
    // ayar satırı bilir; başka bir ekranın kaydı onu sessizce VARSAYILANA (kapalı) çekerse
    // dönercinin malzeme listeleri bir gün ortadan kaybolmuş gibi görünürdü.
    final hazirlanan = preparedProducts.present
        ? preparedProducts.value
        : (mevcut?.preparedProducts ?? false);
    // Kurye yetkileri de aynı kuralla taşınır (2026-08-04): yetki ekranı dışındaki hiçbir
    // çağıran bu 13 anahtarı bilmez; eksik gönderilirse sunucu onları VARSAYILANA çeker ve
    // bayi adresini düzeltince kapattığı iskonto yetkisi sessizce geri açılırdı.
    final izin = kuryeIzin ?? kuryeIzinleriOku(mevcut);

    final payload = <String, Object?>{
      'business_name': ad,
      'owner_name': sahip,
      'phone': tel,
      'whatsapp': wa,
      'address_text': adres,
      'tax_office': vDaire,
      'tax_number': vNo,
      'opens_at': acilis,
      'closes_at': kapanis,
      'receipt_note': fisNotu,
      'iban': ibanNo,
      'iban_owner_name': ibanAd,
      'reminder_template': sablon,
      'courier_can_customers': izin.musteri,
      'courier_can_orders': izin.siparis,
      'courier_can_collect': izin.tahsilat,
      'courier_can_discount': izin.iskonto,
      'courier_can_day_end': izin.gunSonu,
      'courier_can_see_all_orders': izin.tumSiparisler,
      'courier_can_view_history': izin.gecmisTeslimatlar,
      'courier_can_expense': izin.sahaGideri,
      'courier_phone_mask': izin.telefonMaskeleme,
      'courier_can_customer_ledger': izin.musteriGecmisDefteri,
      'courier_can_debt_reminder': izin.borcHatirlatma,
      'courier_can_toggle_stock': izin.stokPasifleme,
      'courier_can_call_log': izin.cagriGunlugu,
      'courier_can_see_all_customers': izin.tumMusteriler,
      'order_code_display': kodTercihi,
      'prepared_products': hazirlanan,
    };

    await db.transaction(() async {
      await db.into(db.tenantSettings).insertOnConflictUpdate(TenantSettingsCompanion(
            id: const Value(1),
            businessName: Value(ad),
            ownerName: Value(sahip),
            phone: Value(tel),
            whatsapp: Value(wa),
            addressText: Value(adres),
            taxOffice: Value(vDaire),
            taxNumber: Value(vNo),
            opensAt: Value(acilis),
            closesAt: Value(kapanis),
            receiptNote: Value(fisNotu),
            iban: Value(ibanNo),
            ibanOwnerName: Value(ibanAd),
            reminderTemplate: Value(sablon),
            courierCanCustomers: Value(izin.musteri),
            courierCanOrders: Value(izin.siparis),
            courierCanCollect: Value(izin.tahsilat),
            courierCanDiscount: Value(izin.iskonto),
            courierCanDayEnd: Value(izin.gunSonu),
            courierCanSeeAllOrders: Value(izin.tumSiparisler),
            courierCanViewHistory: Value(izin.gecmisTeslimatlar),
            courierCanExpense: Value(izin.sahaGideri),
            courierPhoneMask: Value(izin.telefonMaskeleme),
            courierCanCustomerLedger: Value(izin.musteriGecmisDefteri),
            courierCanDebtReminder: Value(izin.borcHatirlatma),
            courierCanToggleStock: Value(izin.stokPasifleme),
            courierCanCallLog: Value(izin.cagriGunlugu),
            courierCanSeeAllCustomers: Value(izin.tumMusteriler),
            orderCodeDisplay: Value(kodTercihi),
            preparedProducts: Value(hazirlanan),
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

  /// Yalnız KURYE YETKİLERİNİ değiştirir; profilin geri kalanına DOKUNMAZ.
  ///
  /// ESKİDEN 14 ALANI ELLE TAŞIYAN BİR KOPYAYDI (kardeşi [siparisKoduTercihiKaydet] ile birlikte
  /// İKİ kopya). `save` kısmi güncellemeye geçince (2026-08-13) ikisi de tek satıra indi ve asıl
  /// kazanç satır sayısı DEĞİL: yeni bir ayar ekranı artık üçüncü bir kopya doğurmuyor, yani
  /// "listeye bir alan eklemeyi unutunca bayinin IBAN'ını silme" hatası yapısal olarak kalktı.
  Future<void> kuryeIzinleriKaydet(KuryeIzinleri izin) => save(kuryeIzin: izin);

  /// Yalnız sipariş kodu tercihini değiştirir; profilin geri kalanına DOKUNMAZ.
  Future<void> siparisKoduTercihiKaydet(String tercih) =>
      save(orderCodeDisplay: Value(tercih));

  /// Yalnız "hazırlanan ürün" yeteneğini değiştirir (2026-08-18).
  Future<void> hazirlananUrunKaydet(bool acik) => save(preparedProducts: Value(acik));
}

/// "Bu işletmede hazırlanan ürün var mı?" — ekranların okuduğu AKIŞ.
///
/// Akış, tek atış DEĞİL: ayar başka bir cihazdan değiştirilebilir ve senkronla iner. Tek atış
/// okuyan bir ürün formu, patron ayarı telefonundan açtıktan sonra kuryenin ekranında hâlâ
/// kapalı görünürdü (`watchSiparisKoduTercihi` ile aynı gerekçe).
///
/// Kayıt hiç yoksa `false`: yetenek varsayılan olarak KAPALIDIR (gerekçe şemada).
Stream<bool> watchHazirlananUrun(AppDatabase db) => db
    .select(db.tenantSettings)
    .watchSingleOrNull()
    .map((s) => s?.preparedProducts ?? false);
