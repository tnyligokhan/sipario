// YETKİ MATRİSİ — roller, kurye izinleri ve devralma kuralı.
//
// NEDEN AYRI DOSYA: `team.dart` 524 satıra çıkmıştı (depo sınırı 500). Ayrım KONUYA göre:
// yukarısı EKİP SORGULARI (`users` aynasından kim var, kim atanabilir, adı ne), burası
// "bu kişi neyi yapabilir" sorusunun tamamı — üç rol, iki çizgi, üç durumlu devralma.
//
// NEDEN `part` (ayrı kütüphane değil): `RolYetkileri`, `KuryeIzinleri`, `yetkiler()` ve
// `oturumYetkileri()` bu depoda ONLARCA ekranın `team.dart`tan import ettiği ADLARDIR. Ayrı
// kütüphane yapmak ya her çağrı yerini değiştirmeyi ya da bir `export` köprüsü kurmayı
// gerektirirdi; `part` ile hiçbir çağrı yeri DEĞİŞMEZ.

part of 'team.dart';

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
    required this.tumMusterileriGorme,
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

  /// Müşteri Listesi: TÜM müşteriler vs YALNIZ kendi siparişlerinin müşterileri.
  ///
  /// `musteriDuzenleme` İLE KARIŞTIRILMAMALI: o "ekleyip düzenleyebilir mi", bu "kimleri
  /// görebilir". `tumSiparisleriGorme`nin müşteri tarafındaki ikizidir ve aynı biçimde
  /// çalışır — kapsam ekranda daralır, veri telefondan silinmez.
  final bool tumMusterileriGorme;

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
    tumMusterileriGorme: true,
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
    this.tumMusteriler = false,
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

  /// courier_can_see_all_customers (Varsayılan: PASİF — kurye yalnız kendi siparişlerinin
  /// müşterilerini görür). Kullanıcı kararı 2026-08-22.
  final bool tumMusteriler;

  static const varsayilan = KuryeIzinleri();
}

/// TEK BİR KURYEYE özel yetki ezmeleri (kullanıcı kararı 2026-08-10) — DEVRALMALI, üç durumlu.
///
/// Her alan `bool?`: `null` = "bayi varsayılanını DEVRAL", true/false = bu kuryeye özel karar.
/// [KuryeIzinleri] ile alan adları BİREBİR aynıdır; ayrışırlarsa [kuryeIzinleriCoz] içindeki
/// eşleme okunamaz hâle gelir. Etkin yetki hiçbir yerde elle hesaplanmaz — tek kapı o fonksiyondur.
///
/// NEDEN AYRI BİR TİP: `KuryeIzinleri`yi nullable yapmak, onu tüketen her ekranı üç durumu
/// düşünmeye zorlardı — oysa ekranların %95'i "bu kurye şunu yapabilir mi?" diye sorar ve
/// cevabı ÇÖZÜLMÜŞ (non-null) olmalıdır. Üç durum yalnız YAZIM ve DÜZENLEME yüzeyinde yaşar.
class KuryeIzinEzmeleri {
  const KuryeIzinEzmeleri({
    this.musteri,
    this.siparis,
    this.tahsilat,
    this.iskonto,
    this.gunSonu,
    this.tumSiparisler,
    this.gecmisTeslimatlar,
    this.sahaGideri,
    this.telefonMaskeleme,
    this.musteriGecmisDefteri,
    this.borcHatirlatma,
    this.stokPasifleme,
    this.cagriGunlugu,
    this.tumMusteriler,
  });

  final bool? musteri; // courier_can_customers
  final bool? siparis; // courier_can_orders
  final bool? tahsilat; // courier_can_collect
  final bool? iskonto; // courier_can_discount
  final bool? gunSonu; // courier_can_day_end
  final bool? tumSiparisler; // courier_can_see_all_orders
  final bool? gecmisTeslimatlar; // courier_can_view_history
  final bool? sahaGideri; // courier_can_expense
  final bool? telefonMaskeleme; // courier_phone_mask
  final bool? musteriGecmisDefteri; // courier_can_customer_ledger
  final bool? borcHatirlatma; // courier_can_debt_reminder
  final bool? stokPasifleme; // courier_can_toggle_stock
  final bool? cagriGunlugu; // courier_can_call_log
  final bool? tumMusteriler; // courier_can_see_all_customers

  /// Hiçbir ezme yok — her yetki bayi varsayılanından devralınır. "Hepsini varsayılana döndür"
  /// düğmesinin yazacağı değer de budur.
  static const bos = KuryeIzinEzmeleri();

  /// Bu kuryenin hiç kişisel ezmesi var mı? (UI "özelleştirilmiş" rozeti için.)
  bool get hepsiDevralindi =>
      musteri == null &&
      siparis == null &&
      tahsilat == null &&
      iskonto == null &&
      gunSonu == null &&
      tumSiparisler == null &&
      gecmisTeslimatlar == null &&
      sahaGideri == null &&
      telefonMaskeleme == null &&
      musteriGecmisDefteri == null &&
      borcHatirlatma == null &&
      stokPasifleme == null &&
      cagriGunlugu == null &&
      tumMusteriler == null;
}

/// Genel Yetki Matrisi kurallarını çözen saf fonksiyon — ÜÇ ROL, İKİ ÇİZGİ.
///
/// ```
///   PATRON  → tam yetki (kısıtlamasız)
///   TEZGÂH  → dükkânı çevirir; PARA KONTROLÜNE ve KATALOĞA dokunamaz
///   KURYE   → varsayılan kısıtlar + bayinin/patronun açtığı dinamik yetkiler
/// ```
///
/// ══ TEZGÂH ROLÜ 2026-08-20'DE YENİDEN TANIMLANDI ═════════════════════════════════════════
/// `operator` rolü vardı ama "işletme ayarları hariç patron" demekti — yani bir kasiyer günü
/// kapatabiliyor, defteri ters kayıtla düzeltebiliyor, müşterinin borcunu silebiliyor, ürün
/// fiyatı değiştirebiliyordu. Kullanıcı isteği ("patron tüm yetki, kasiyer telefona bakan
/// farklı, kurye farklı") bu rolü gerçek bir role çevirdi.
///
/// GERİYE DÖNÜK RİSK YOK ve bu ölçüldü: üretimde `operator` hesabı AÇAN hiçbir yol yoktu
/// (`Provisioning::createCourier` yalnız kurye üretiyor, web Ekip yalnız onu çağırıyordu);
/// rol yalnız demo seeder'da ve fabrikada geçiyordu. Yani kimsenin elindeki yetki daralmadı,
/// bugüne kadar boş duran bir rol doldurulmuş oldu.
///
/// ══ İKİ ÇİZGİ ════════════════════════════════════════════════════════════════════════════
/// [_ofis] — dükkânın günlük işini çeviren (patron + tezgâh): sipariş açar, atar, iptal eder,
/// tahsilat alır, borçluları görür. Telefona bakan kişinin yapamadığı iş, telefonu her çaldığında
/// patronu çağırmak demektir; rolün varlık sebebi tam olarak budur.
///
/// [_paraKontrolu] — YALNIZ PATRON: günü/hesabı kapatma, geçmiş hesap arşivi, defter düzeltme
/// (ters kayıt), müşteri borcu silme, ürün/fiyat yönetimi, müşteri silme-kara liste, muaf numara.
/// Ortak yanları şu: hepsi ya PARANIN kendisini ya da onu üreten TANIMLARI değiştirir ve
/// hiçbirinin geri dönüşü bir günlük işle sınırlı değildir. Bu çizgi bir tercih değildir —
/// bayinin kasiyerine güvenip güvenmemesinden bağımsız olarak, defterin sahibi tektir.
///
/// [atamaHedefiVar]: atanabilecek BAŞKA aktif personel var mı (eskiden `kuryeVar`). Adı 2026-08-20'de
/// değişti çünkü anlamı değişti: atama hedefi artık kuryelerle sınırlı değil, siparişi oluşturan
/// kişinin kendisi de dahil. Tek kişilik bayide yine `false` olur ve atama yüzeyi hiç çizilmez
/// (BRIEF: "'kuryeye ata' gibi adımlar tek kişilik işletmede hiç görünmemelidir").
RolYetkileri yetkiler({
  required String? rol,
  required bool atamaHedefiVar,
  KuryeIzinleri? izin,
}) {
  final patron = rol == 'patron';
  final tezgah = rol == 'operator';

  /// Dükkânı çeviren: patron + tezgâh.
  final ofis = patron || tezgah;

  /// Defterin ve katalogun sahibi: yalnız patron.
  final paraKontrolu = patron;

  final k = izin ?? KuryeIzinleri.varsayilan;

  return RolYetkileri(
    // 1. Sipariş & Teslimat
    tumSiparisleriGorme: ofis || k.tumSiparisler,
    siparisAcma: ofis || k.siparis,
    siparisIptal: ofis,
    gecmisTeslimatlariGorme: ofis || k.gecmisTeslimatlar,
    rotaCalistir: ofis,
    atama: ofis && atamaHedefiVar,

    // 2. Kasa & Tahsilat
    tahsilat: ofis || k.tahsilat,
    iskonto: ofis || k.iskonto,
    musteriBorcSilme: paraKontrolu,
    sahaGideri: ofis || k.sahaGideri,
    toplamBorclulariGorme: ofis,

    // 3. Gün Sonu & Kasa Devri
    gunSonu: ofis || k.gunSonu,
    gunuKapatma: paraKontrolu,
    gecmisHesapArsivi: paraKontrolu,
    defterDuzeltme: paraKontrolu,

    // 4. Müşteri & KVKK / İletişim
    tumMusterileriGorme: ofis || k.tumMusteriler,
    musteriDuzenleme: ofis || k.musteri,
    musteriYonetimi: paraKontrolu,
    telefonMaskeleme: !ofis && k.telefonMaskeleme,
    musteriGecmisDefteri: ofis || k.musteriGecmisDefteri,
    borcHatirlatma: ofis || k.borcHatirlatma,

    // 5. Ürün & Stok
    urunYonetimi: paraKontrolu,
    stokPasifleme: ofis || k.stokPasifleme,

    // 6. Çağrı & Ayarlar
    cagriGunlugu: ofis || k.cagriGunlugu,
    muafTelefonYonetimi: paraKontrolu,
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
        tumMusteriler: ayar.courierCanSeeAllCustomers,
      );

/// `users` satırından KİŞİYE ÖZEL ezmeleri okur. Satır yoksa (oturum kullanıcısı henüz team
/// bloğuyla inmediyse, ya da id çözülemediyse) ezme YOKTUR → her şey devralınır.
KuryeIzinEzmeleri kuryeEzmeleriOku(User? u) => u == null
    ? KuryeIzinEzmeleri.bos
    : KuryeIzinEzmeleri(
        musteri: u.courierCanCustomers,
        siparis: u.courierCanOrders,
        tahsilat: u.courierCanCollect,
        iskonto: u.courierCanDiscount,
        gunSonu: u.courierCanDayEnd,
        tumSiparisler: u.courierCanSeeAllOrders,
        gecmisTeslimatlar: u.courierCanViewHistory,
        sahaGideri: u.courierCanExpense,
        telefonMaskeleme: u.courierPhoneMask,
        musteriGecmisDefteri: u.courierCanCustomerLedger,
        borcHatirlatma: u.courierCanDebtReminder,
        stokPasifleme: u.courierCanToggleStock,
        cagriGunlugu: u.courierCanCallLog,
        tumMusteriler: u.courierCanSeeAllCustomers,
      );

/// DEVRALMAYI ÇÖZEN SAF FONKSİYON — kişiye özel yetki tasarımının tamamı bu tek satırlık
/// kuralda özetlenir: `etkin = kisisel ?? varsayilan`.
///
/// SAF ve alan alan, bilinçli: "hiç ezme yoksa varsayılanı olduğu gibi döndür" gibi bir kısayol
/// yazmak cazip ama YANLIŞ olurdu — tek bir alanın ezilmesi bile geri kalanın devralınmasını
/// bozmamalı ve bu ancak alan alan çözümle garanti edilir. Etkin yetkiyi hesaplayan BAŞKA bir
/// yer OLMAMALIDIR; ikinci bir kopya, iki ekranın aynı kurye için farklı cevap vermesi demektir.
KuryeIzinleri kuryeIzinleriCoz(KuryeIzinleri varsayilan, KuryeIzinEzmeleri? ezme) {
  if (ezme == null) return varsayilan;

  return KuryeIzinleri(
    musteri: ezme.musteri ?? varsayilan.musteri,
    siparis: ezme.siparis ?? varsayilan.siparis,
    tahsilat: ezme.tahsilat ?? varsayilan.tahsilat,
    iskonto: ezme.iskonto ?? varsayilan.iskonto,
    gunSonu: ezme.gunSonu ?? varsayilan.gunSonu,
    tumSiparisler: ezme.tumSiparisler ?? varsayilan.tumSiparisler,
    gecmisTeslimatlar: ezme.gecmisTeslimatlar ?? varsayilan.gecmisTeslimatlar,
    sahaGideri: ezme.sahaGideri ?? varsayilan.sahaGideri,
    telefonMaskeleme: ezme.telefonMaskeleme ?? varsayilan.telefonMaskeleme,
    musteriGecmisDefteri: ezme.musteriGecmisDefteri ?? varsayilan.musteriGecmisDefteri,
    borcHatirlatma: ezme.borcHatirlatma ?? varsayilan.borcHatirlatma,
    stokPasifleme: ezme.stokPasifleme ?? varsayilan.stokPasifleme,
    cagriGunlugu: ezme.cagriGunlugu ?? varsayilan.cagriGunlugu,
    tumMusteriler: ezme.tumMusteriler ?? varsayilan.tumMusteriler,
  );
}

/// BAYİ VARSAYILANI akışı (kişiselleştirme öncesi hâl) — "yeni kurye şablonu" ekranı buna
/// abone olur. Adı ve anlamı KORUNDU: burası artık "şablonu" izler, oturumun ETKİN yetkisini
/// değil. Etkin yetki için [watchOturumKuryeIzinleri].
Stream<KuryeIzinleri> watchKuryeIzinleri(AppDatabase db) =>
    (db.select(db.tenantSettings)..where((t) => t.id.equals(1)))
        .watchSingleOrNull()
        .map(kuryeIzinleriOku);

/// TEK BİR KURYENİN ezmeleri (düzenleme ekranı buna abone olur).
Stream<KuryeIzinEzmeleri> watchKuryeEzmeleri(AppDatabase db, String userId) =>
    (db.select(db.users)..where((t) => t.id.equals(userId)))
        .watchSingleOrNull()
        .map(kuryeEzmeleriOku);

/// BU OTURUMUN ETKİN kurye izinleri — kabuk buna abone olur.
///
/// ÜÇ TABLOYU BİRLİKTE İZLER (`sync_meta` · `tenant_settings` · `users`) ve üçünden herhangi
/// biri değişince yeniden yayınlar. Tek sorguda join olmasının sebebi budur: ayrı akışları elle
/// birleştirmek, "hangisi önce geldi" sırasına bağlı bir ara kare üretirdi.
///
/// AKIŞ, TEK ATIŞ DEĞİL (ölçülmüş ders): sunucu sahipli alanlar ekran açılışında henüz gelmemiş
/// olabilir — `initState`te tek atış okuyan her yer bayat kalır ve testler bunu göremez.
/// Kişisel yetki tam olarak böyle bir alandır: patron paneli değiştirir, kuryenin telefonuna
/// bir sonraki senkron turuyla iner ve ekranın O AN yeniden çizilmesi gerekir.
///
/// `sync_meta.user_id` de izlenir çünkü oturum DEĞİŞEBİLİR (çıkış → başka kullanıcı girişi);
/// yalnız `users`ı izleyen bir akış, önceki kullanıcının satırına kilitli kalırdı.
Stream<KuryeIzinleri> watchOturumKuryeIzinleri(AppDatabase db) {
  final q = db.select(db.syncMeta).join([
    leftOuterJoin(db.tenantSettings, db.tenantSettings.id.equals(1)),
    leftOuterJoin(db.users, db.users.id.equalsExp(db.syncMeta.userId)),
  ])
    ..where(db.syncMeta.id.equals(1));

  return q.watchSingleOrNull().map((satir) => satir == null
      ? KuryeIzinleri.varsayilan
      : kuryeIzinleriCoz(
          kuryeIzinleriOku(satir.readTableOrNull(db.tenantSettings)),
          kuryeEzmeleriOku(satir.readTableOrNull(db.users)),
        ));
}

/// Bu cihazdaki oturumun yetkileri — TEK ATIŞ.
///
/// Kişisel ezmeler de çözülür: `sync_meta.user_id` ile `users` satırı çekilir. Satır yoksa
/// (henüz team bloğu inmediyse) ezme yok sayılır ve bayi varsayılanı geçerlidir — yani en kötü
/// durumda davranış bu özellik gelmeden önceki hâline döner, hiçbir yetki uydurulmaz.
Future<RolYetkileri> oturumYetkileri(AppDatabase db) async {
  final meta = await db.syncState();
  final ayar =
      await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingleOrNull();
  final kullanici = meta.userId == null
      ? null
      : await (db.select(db.users)..where((t) => t.id.equals(meta.userId!))).getSingleOrNull();

  return yetkiler(
    rol: meta.userRole,
    atamaHedefiVar: false,
    izin: kuryeIzinleriCoz(kuryeIzinleriOku(ayar), kuryeEzmeleriOku(kullanici)),
  );
}
