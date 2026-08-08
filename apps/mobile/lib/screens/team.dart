import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// FAZ 4b Dilim 4 — ekip (yerel `users` aynası) sorguları + rol bazlı yetki. Ekrandan bağımsız,
/// saf test edilebilir (money.dart deseni). `users` team bloğuyla toptan tazelenen önbellektir;
/// istemciden ASLA push edilmez. Yetki mantığı TEK saf fonksiyonda (K2) → regresyon testi kolay.

/// Tüm ekip (ada göre). status disabled DAHİL — atanan kuryenin adı eski atamalarda gösterilsin.
Stream<List<User>> watchTeam(AppDatabase db) =>
    (db.select(db.users)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

/// Atama hedefi olarak sunulacaklar: yalnız AKTİF kuryeler (ada göre).
Stream<List<User>> watchAktifKuryeler(AppDatabase db) => (db.select(db.users)
      ..where((t) => t.role.equals('kurye'))
      ..where((t) => t.status.equals('active'))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
    .watch();

/// Devralan seçici için: bayinin patron/operator kullanıcıları (aktif, ada göre).
Stream<List<User>> watchYoneticiler(AppDatabase db) => (db.select(db.users)
      ..where((t) => t.status.equals('active'))
      ..where((t) => t.role.equals('patron') | t.role.equals('operator'))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
    .watch();

/// Kullanıcı adını id'den çöz (bulunamazsa null → UI 'Kurye' gibi bir yedeğe düşer). Pasif
/// kullanıcı da çözülür (adı team'de kalır).
String? kullaniciAdi(List<User> team, String? id) {
  if (id == null) return null;
  for (final u in team) {
    if (u.id == id) return u.name;
  }
  return null;
}

/// Rol bazlı görünüm yetkileri (Sipario Genel Yetki Matrisi).
class RolYetkileri {
  const RolYetkileri({
    required this.urunYonetimi,
    required this.stokPasifleme,
    required this.gunSonu,
    required this.gunuKapatma,
    required this.defterDuzeltme,
    required this.gecmisHesapArsivi,
    required this.tahsilat,
    required this.iskonto,
    required this.musteriBorcSilme,
    required this.sahaGideri,
    required this.toplamBorclulariGorme,
    required this.atama,
    required this.rotaCalistir,
    required this.siparisIptal,
    required this.siparisAcma,
    required this.tumSiparisleriGorme,
    required this.gecmisTeslimatlariGorme,
    required this.musteriYonetimi,
    required this.musteriDuzenleme,
    required this.telefonMaskeleme,
    required this.musteriGecmisDefteri,
    required this.borcHatirlatma,
    required this.cagriGunlugu,
    required this.muafTelefonYonetimi,
    required this.isletmeAbonelikAyarlari,
    this.cihazAyarlari = true,
  });

  // 1. Sipariş & Teslimat Yönetimi
  final bool tumSiparisleriGorme; // Sipariş Listesi: Tüm Siparişler vs Sadece Kendi Siparişleri
  final bool siparisAcma; // Yeni Sipariş Oluşturma
  final bool siparisIptal; // Sipariş İptal Etme / Silme (Yalnızca Yönetici)
  final bool gecmisTeslimatlariGorme; // Geçmiş Gün Teslimatlarını Görme
  final bool rotaCalistir; // Oto-Sıralama (Rota) Çalıştırma (Yalnızca Yönetici)
  final bool atama; // Sipariş Kurye Atamasını Değiştirme (Yalnızca Yönetici)

  // 2. Kasa & Tahsilat Yönetimi
  final bool tahsilat; // Kapıda Tahsilat Alma (Nakit/POS)
  final bool iskonto; // Kapıda İskonto / Fiyat Kırma
  final bool musteriBorcSilme; // Müşteri Borç İskontosu / Silme (Yalnızca Yönetici)
  final bool sahaGideri; // Saha Gideri Girme (Benzin vb.)
  final bool toplamBorclulariGorme; // Toplam Borçlular Listesini Görme (Yalnızca Yönetici)

  // 3. Gün Sonu & Kasa Devri
  final bool gunSonu; // Gün Sonu Özeti Görünürlüğü (Yönetici: Tüm dükkan, Kurye: Kendi devri / ayara bağlı)
  final bool gunuKapatma; // Günü Kapatma / Devir İşlemi (Yalnızca Yönetici)
  final bool gecmisHesapArsivi; // Geçmiş Gün Hesap Arşivini Görme (Yalnızca Yönetici)
  final bool defterDuzeltme; // Defter Düzeltme / Ters Kayıt (Yalnızca Yönetici)

  // 4. Müşteri & KVKK / İletişim
  final bool musteriDuzenleme; // Müşteri Ekleme / Düzenleme
  final bool musteriYonetimi; // Müşteri Silme / Kara Listeye Alma (Yalnızca Yönetici)
  final bool telefonMaskeleme; // Müşteri Telefon Maskeleme (0532***12)
  final bool musteriGecmisDefteri; // Müşteri Geçmiş Defterini Görme
  final bool borcHatirlatma; // Müşteriye Borç Hatırlatma (SMS/WA)

  // 5. Ürün & Stok
  final bool urunYonetimi; // Ürün Ekleme / Düzenleme / Fiyat (Yalnızca Yönetici)
  final bool stokPasifleme; // "Stokta Yok" İşaretleme

  // 6. Çağrı & Ayarlar
  final bool cagriGunlugu; // Dükkan Çağrı Günlüğünü Görme
  final bool muafTelefonYonetimi; // Muaf Telefon Numarası Ekleme (Yalnızca Yönetici)
  final bool isletmeAbonelikAyarlari; // İşletme / Abonelik Ayarları (Yalnızca Patron)
  final bool cihazAyarlari; // Kurye Cihaz Ayarları (Arayan T. vb) (Herkes)

  /// Tam yetkili (test ve varsayılan yönetici görünümü).
  static const tumu = RolYetkileri(
    urunYonetimi: true,
    stokPasifleme: true,
    gunSonu: true,
    gunuKapatma: true,
    defterDuzeltme: true,
    gecmisHesapArsivi: true,
    tahsilat: true,
    iskonto: true,
    musteriBorcSilme: true,
    sahaGideri: true,
    toplamBorclulariGorme: true,
    atama: true,
    rotaCalistir: true,
    siparisIptal: true,
    siparisAcma: true,
    tumSiparisleriGorme: true,
    gecmisTeslimatlariGorme: true,
    musteriYonetimi: true,
    musteriDuzenleme: true,
    telefonMaskeleme: false,
    musteriGecmisDefteri: true,
    borcHatirlatma: true,
    cagriGunlugu: true,
    muafTelefonYonetimi: true,
    isletmeAbonelikAyarlari: true,
    cihazAyarlari: true,
  );
}

/// Bayinin açıp kapattığı dinamik KURYE yetkileri (Sipario Genel Yetki Matrisi).
class KuryeIzinleri {
  const KuryeIzinleri({
    this.musteri = true,
    this.siparis = true,
    this.tahsilat = true,
    this.iskonto = false,
    this.gunSonu = false,
    this.tumSiparisler = false,
    this.gecmisTeslimatlar = false,
    this.sahaGideri = false,
    this.telefonMaskeleme = true,
    this.musteriGecmisDefteri = false,
    this.borcHatirlatma = false,
    this.stokPasifleme = true,
    this.cagriGunlugu = false,
  });

  final bool musteri; // courier_can_customers (Varsayılan: Aktif)
  final bool siparis; // courier_can_orders (Varsayılan: Aktif)
  final bool tahsilat; // courier_can_collect (Varsayılan: Aktif)
  final bool iskonto; // courier_can_discount (Varsayılan: Pasif)
  final bool gunSonu; // courier_can_day_end (Varsayılan: Pasif - Kendi tahsilatları)
  final bool tumSiparisler; // courier_can_see_all_orders (Varsayılan: Pasif - Sadece kendi siparişleri)
  final bool gecmisTeslimatlar; // courier_can_view_history (Varsayılan: Pasif)
  final bool sahaGideri; // courier_can_expense (Varsayılan: Pasif)
  final bool telefonMaskeleme; // courier_phone_mask (Varsayılan: Aktif - 0532***12)
  final bool musteriGecmisDefteri; // courier_can_customer_ledger (Varsayılan: Pasif)
  final bool borcHatirlatma; // courier_can_debt_reminder (Varsayılan: Pasif)
  final bool stokPasifleme; // courier_can_toggle_stock (Varsayılan: Aktif)
  final bool cagriGunlugu; // courier_can_call_log (Varsayılan: Pasif)

  static const varsayilan = KuryeIzinleri();
}

/// Genel Yetki Matrisi kurallarını çözen saf fonksiyon.
/// Patron: Tam yetkili (kısıtlamasız).
/// Operatör: Patron yetkili (işletme/abonelik ayarları hariç tam yetkili).
/// Kurye: Varsayılan kısıtlar + Patronun açıp kapattığı dinamik yetkiler.
RolYetkileri yetkiler({
  required String? rol,
  required bool kuryeVar,
  KuryeIzinleri? izin,
}) {
  final patron = rol == 'patron';
  final yonetici = patron || rol == 'operator';
  final k = izin ?? KuryeIzinleri.varsayilan;

  return RolYetkileri(
    // 1. Sipariş & Teslimat
    tumSiparisleriGorme: yonetici || k.tumSiparisler,
    siparisAcma: yonetici || k.siparis,
    siparisIptal: yonetici,
    gecmisTeslimatlariGorme: yonetici || k.gecmisTeslimatlar,
    rotaCalistir: yonetici,
    atama: yonetici && kuryeVar,

    // 2. Kasa & Tahsilat
    tahsilat: yonetici || k.tahsilat,
    iskonto: yonetici || k.iskonto,
    musteriBorcSilme: yonetici,
    sahaGideri: yonetici || k.sahaGideri,
    toplamBorclulariGorme: yonetici,

    // 3. Gün Sonu & Kasa Devri
    gunSonu: yonetici || k.gunSonu,
    gunuKapatma: yonetici,
    gecmisHesapArsivi: yonetici,
    defterDuzeltme: yonetici,

    // 4. Müşteri & KVKK / İletişim
    musteriDuzenleme: yonetici || k.musteri,
    musteriYonetimi: yonetici,
    telefonMaskeleme: !yonetici && k.telefonMaskeleme,
    musteriGecmisDefteri: yonetici || k.musteriGecmisDefteri,
    borcHatirlatma: yonetici || k.borcHatirlatma,

    // 5. Ürün & Stok
    urunYonetimi: yonetici,
    stokPasifleme: yonetici || k.stokPasifleme,

    // 6. Çağrı & Ayarlar
    cagriGunlugu: yonetici || k.cagriGunlugu,
    muafTelefonYonetimi: yonetici,
    isletmeAbonelikAyarlari: patron,
    cihazAyarlari: true,
  );
}

/// Kurye için telefon numarası maskeleme (ör. 0532***12).
String telefonMaskele(String? phoneE164) {
  if (phoneE164 == null || phoneE164.isEmpty) return '';
  final temiz = phoneE164.replaceAll(RegExp(r'\s+'), '');
  if (temiz.length >= 7) {
    final bas = temiz.substring(0, (temiz.length - 4).clamp(0, 5));
    final son = temiz.substring(temiz.length - 2);
    return '$bas***$son';
  }
  return temiz;
}

/// `tenant_settings` satırından kurye izinlerini okur. Satır yoksa varsayılan.
KuryeIzinleri kuryeIzinleriOku(TenantSetting? ayar) => ayar == null
    ? KuryeIzinleri.varsayilan
    : KuryeIzinleri(
        musteri: ayar.courierCanCustomers,
        siparis: ayar.courierCanOrders,
        tahsilat: ayar.courierCanCollect,
        iskonto: ayar.courierCanDiscount,
        gunSonu: ayar.courierCanDayEnd,
        tumSiparisler: ayar.courierCanSeeAllOrders,
        gecmisTeslimatlar: ayar.courierCanViewHistory,
        sahaGideri: ayar.courierCanExpense,
        telefonMaskeleme: ayar.courierPhoneMask,
        musteriGecmisDefteri: ayar.courierCanCustomerLedger,
        borcHatirlatma: ayar.courierCanDebtReminder,
        stokPasifleme: ayar.courierCanToggleStock,
        cagriGunlugu: ayar.courierCanCallLog,
      );

/// Kurye izinleri akışı — kabuk buna abone olur.
Stream<KuryeIzinleri> watchKuryeIzinleri(AppDatabase db) =>
    (db.select(db.tenantSettings)..where((t) => t.id.equals(1)))
        .watchSingleOrNull()
        .map(kuryeIzinleriOku);

/// Bu cihazdaki oturumun yetkileri — TEK ATIŞ.
Future<RolYetkileri> oturumYetkileri(AppDatabase db) async {
  final meta = await db.syncState();
  final ayar =
      await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingleOrNull();

  return yetkiler(
    rol: meta.userRole,
    kuryeVar: false,
    izin: kuryeIzinleriOku(ayar),
  );
}
