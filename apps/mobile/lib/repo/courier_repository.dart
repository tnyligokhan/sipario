import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import '../data/outbox.dart';
import '../screens/team.dart' show KuryeIzinEzmeleri;

/// Kurye/kullanıcı profili (tasarım: "Kuryeler" ekranı — ad, telefon, aktif/pasif).
///
/// SINIR (bilinçli): buradan kullanıcı OLUŞTURULAMAZ ve rol/e-posta/parola DEĞİŞTİRİLEMEZ. Yeni
/// kullanıcı kimlik bilgisi (e-posta+parola) üretmeyi gerektirir; kimlik yüzeyini senkron yolundan
/// açmak yetki yükseltme vektörü olurdu. Kullanıcı açma panel/owner tarafındadır — AÇIK madde.
///
/// Yerel `users` tablosu sunucu `team` bloğunun TOPTAN tazelenen önbelleğidir. Burada iyimser
/// (optimistic) yazarız ki ekran anında güncellensin; bir sonraki senkronda sunucunun listesi
/// zaten üzerine yazar (tek doğru kaynak sunucu).
class CourierRepository {
  CourierRepository(this.db);
  final AppDatabase db;

  /// Tüm ekip (pasifler dahil — tasarım pasif kuryeyi soluk gösterir).
  Stream<List<User>> watchAll() =>
      (db.select(db.users)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  /// Yalnız aktif kuryeler (atama hedefi + gün sonu sekmeleri).
  Stream<List<User>> watchAktifKuryeler() => (db.select(db.users)
        ..where((t) => t.role.equals('kurye') & t.status.equals('active'))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  /// Profili güncelle. [isActive] pasifleştirmeyi kapsar (silme YOK — geçmiş atamalarda adı gerekir).
  Future<void> updateProfile(
    String userId, {
    required String name,
    String? phone,
    bool isActive = true,
  }) async {
    final meta = await db.syncState();
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;
    final status = isActive ? 'active' : 'disabled';

    await db.transaction(() async {
      await (db.update(db.users)..where((t) => t.id.equals(userId))).write(UsersCompanion(
        name: Value(name),
        phone: Value(phone),
        status: Value(status),
      ));
      await enqueueOutbox(db,
          entityType: 'user_profile',
          op: 'upsert',
          entityId: userId,
          occurredAt: at,
          deviceId: device,
          payload: {'id': userId, 'name': name, 'phone': phone, 'status': status});
    });
  }

  /// Bir kuryenin KİŞİYE ÖZEL yetki ezmelerini kaydeder (kullanıcı kararı 2026-08-10).
  ///
  /// ÜÇ DURUM PAYLOAD'DA DA YAŞAR ve bu, sözleşmenin can alıcı noktasıdır:
  ///   • `true`/`false` → anahtar doğrudan bool ile gider (bu kuryeye özel karar).
  ///   • "bayi varsayılanına dön" → anahtar payload'a AÇIKÇA `null` DEĞERİYLE konur.
  ///     Anahtarı ÇIKARMAK bunu ifade EDEMEZ; sunucu için eksik anahtar "dokunma" demektir,
  ///     yani ezme kaldırılmaz ve kurye sonsuza dek eski değerine çakılı kalırdı.
  ///
  /// AD/TELEFON/DURUM ANAHTARLARI PAYLOAD'A GİRMEZ (bilinçli) — `tenant_settings_repository`
  /// içindeki "form dışı ayar" TUZAĞININ bu varlıktaki karşılığı: yetki ekranı kuryenin adını
  /// ve telefonunu düzenlemez, bilmediği alanları göndermeye kalkarsa sunucudaki değerlerini
  /// eskimiş bir kopyayla ezer. Eksik anahtar sunucuda mevcut değeri KORUR; bu yüzden burada
  /// yalnız 13 yetki anahtarı + kimlik gönderilir. Aynı sebeple [updateProfile] de yetki
  /// anahtarlarına HİÇ dokunmaz — iki metot aynı varlığın ayrık alan kümelerini yazar.
  ///
  /// Yerel satır iyimser yazılır ki ekran anında güncellensin; bir sonraki senkronda sunucunun
  /// `team` listesi zaten üzerine yazar (tek doğru kaynak sunucu).
  Future<void> kuryeIzinEzmeleriKaydet(String userId, KuryeIzinEzmeleri ezmeler) async {
    final meta = await db.syncState();
    // Damga + cihaz ZORUNLU: cihazsız/damgasız yazım LWW'de sessizce bayat kalır (ölçüldü).
    final at = correctedNowIso(meta.serverTimeOffsetMs);
    final device = meta.deviceId;

    // Value(null) ile Value.absent() FARKI: burada hepsi `Value(...)` — `null` yazmak
    // "ezmeyi kaldır, devral" demektir ve yerel satırda da öyle görünmelidir.
    final satir = UsersCompanion(
      courierCanCustomers: Value(ezmeler.musteri),
      courierCanOrders: Value(ezmeler.siparis),
      courierCanCollect: Value(ezmeler.tahsilat),
      courierCanDiscount: Value(ezmeler.iskonto),
      courierCanDayEnd: Value(ezmeler.gunSonu),
      courierCanSeeAllOrders: Value(ezmeler.tumSiparisler),
      courierCanViewHistory: Value(ezmeler.gecmisTeslimatlar),
      courierCanExpense: Value(ezmeler.sahaGideri),
      courierPhoneMask: Value(ezmeler.telefonMaskeleme),
      courierCanCustomerLedger: Value(ezmeler.musteriGecmisDefteri),
      courierCanDebtReminder: Value(ezmeler.borcHatirlatma),
      courierCanToggleStock: Value(ezmeler.stokPasifleme),
      courierCanCallLog: Value(ezmeler.cagriGunlugu),
      courierCanSeeAllCustomers: Value(ezmeler.tumMusteriler),
    );

    final payload = <String, Object?>{
      'id': userId,
      'courier_can_customers': ezmeler.musteri,
      'courier_can_orders': ezmeler.siparis,
      'courier_can_collect': ezmeler.tahsilat,
      'courier_can_discount': ezmeler.iskonto,
      'courier_can_day_end': ezmeler.gunSonu,
      'courier_can_see_all_orders': ezmeler.tumSiparisler,
      'courier_can_view_history': ezmeler.gecmisTeslimatlar,
      'courier_can_expense': ezmeler.sahaGideri,
      'courier_phone_mask': ezmeler.telefonMaskeleme,
      'courier_can_customer_ledger': ezmeler.musteriGecmisDefteri,
      'courier_can_debt_reminder': ezmeler.borcHatirlatma,
      'courier_can_toggle_stock': ezmeler.stokPasifleme,
      'courier_can_call_log': ezmeler.cagriGunlugu,
      'courier_can_see_all_customers': ezmeler.tumMusteriler,
    };

    await db.transaction(() async {
      await (db.update(db.users)..where((t) => t.id.equals(userId))).write(satir);
      await enqueueOutbox(db,
          entityType: 'user_profile',
          op: 'upsert',
          entityId: userId,
          occurredAt: at,
          deviceId: device,
          payload: payload);
    });
  }
}
