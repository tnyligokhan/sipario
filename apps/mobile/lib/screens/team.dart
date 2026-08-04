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

/// Rol bazlı görünüm yetkileri (K2 — BRIEF'ten türetilmiş v1 asgarisi).
class RolYetkileri {
  const RolYetkileri({
    required this.urunYonetimi,
    required this.gunSonu,
    required this.defterDuzeltme,
    required this.tahsilat,
    required this.atama,
    required this.musteriYonetimi,
    this.musteriDuzenleme = true,
    this.siparisAcma = true,
    this.iskonto = true,
  });

  final bool urunYonetimi; // ürün ekle/düzenle/pasifle
  final bool gunSonu; // gün sonu özeti
  final bool defterDuzeltme; // ters kayıtla düzelt
  final bool tahsilat; // tahsilat al
  final bool atama; // siparişi kuryeye ata

  /// müşteriyi sil / kara listeye al-çıkar (geri dönüşü zor, bayi kararı)
  final bool musteriYonetimi;

  /// Müşteri EKLE/DÜZENLE (silme değil — o `musteriYonetimi`). Kurye için bayi ayarına tabi.
  final bool musteriDuzenleme;

  /// Yeni sipariş oluştur. Kurye için bayi ayarına tabi.
  final bool siparisAcma;

  /// Kapıda iskonto — PARA KIRMA yetkisi. Kurye için varsayılanı KAPALI.
  final bool iskonto;

  /// Tam yetkili (test/varsayılan yardımcısı; rol bilinmeden ekran açıldığında permissive değil,
  /// gerçek karar yetkiler() ile verilir).
  static const tumu = RolYetkileri(
    urunYonetimi: true,
    gunSonu: true,
    defterDuzeltme: true,
    tahsilat: true,
    atama: true,
    musteriYonetimi: true,
  );
}

/// Bayinin açıp kapattığı KURYE yetkileri (kullanıcı isteği 2026-08-04) — `tenant_settings`
/// satırının beş anahtarının ekran katmanındaki karşılığı.
///
/// AYRI BİR TİP çünkü [RolYetkileri] bir SONUÇTUR (rol + ayar + ekip durumu hesaplanmış hâli),
/// bu ise GİRDİ. İkisini tek tipte toplamak, "ayarı mı okuyorum yoksa kararı mı" sorusunu her
/// çağrı yerinde yeniden sordururdu.
class KuryeIzinleri {
  const KuryeIzinleri({
    this.musteri = true,
    this.siparis = true,
    this.tahsilat = true,
    this.iskonto = false,
    this.gunSonu = false,
  });

  final bool musteri;
  final bool siparis;
  final bool tahsilat;
  final bool iskonto;
  final bool gunSonu;

  /// Ayar satırı henüz senkronla gelmediyse kullanılan varsayılan — sunucu migration'ıyla
  /// (004002) ve Drift kolon varsayılanlarıyla BİREBİR aynı olmak zorunda.
  static const varsayilan = KuryeIzinleri();
}

/// K2 matrisi (tek doğruluk kaynağı). yonetici = patron|operator. kuryeVar = yerelde aktif kurye var.
/// - ürün/gün-sonu/defter-düzeltme: yalnız yönetici (patron işi).
/// - tahsilat: HERKES (kurye sahada/ay sonu tahsilat yapar; collected_by atfı zaten ondan).
/// - atama: yönetici VE kuryeVar (tek kişilikte atama yok).
/// - müşteri yönetimi (sil / kara liste): yalnız yönetici. Kurye sahada müşterinin kaydını
///   kaldıramaz ya da ona sipariş açılmasını engelleyemez — bu bayinin ticari kararıdır ve
///   telefonu elinde tutan kişi verir. Kurye kapıya gider, müşteriyi kayıttan düşürmez.
///
/// `kasaDevri` bayrağı KALDIRILDI (2026-07-26): tasarımda ayrı bir kasa devri ekranı yok, devir
/// Gün Sonu'nun "Hesabı Kapat · Kasa Devri" sheet'inin içindedir (`s-gunsonu.jsx:110`) ve kurye
/// kapanışı zaten devri yazar (`DayClosingRepository.kapat(alsoHandover:)`).
/// [izin]: bayinin Ayarlar'dan açıp kapattığı KURYE anahtarları (2026-08-04). YALNIZ kurye
/// rolünü etkiler — yöneticinin yetkisi bir ayara tabi olsaydı bayi kendini kendi
/// uygulamasından kilitleyebilirdi ve geri açacak ekran da o ekranın arkasında kalırdı.
///
/// `null` geçilirse [KuryeIzinleri.varsayilan] kullanılır: ayar satırı henüz senkronla
/// gelmemiş olabilir ve o karede kuryeyi işinden etmek yanlış olur.
RolYetkileri yetkiler({
  required String? rol,
  required bool kuryeVar,
  KuryeIzinleri? izin,
}) {
  final yonetici = rol == 'patron' || rol == 'operator';
  final k = izin ?? KuryeIzinleri.varsayilan;
  return RolYetkileri(
    urunYonetimi: yonetici,
    gunSonu: yonetici || k.gunSonu,
    defterDuzeltme: yonetici,
    // Tahsilat artık koşulsuz DEĞİL: kurye tarafı bayi ayarına bağlı (yönetici her zaman alır).
    // Eski kural "tahsilat: true" idi ve gerekçesi "kurye sahada tahsilat yapar" — o gerekçe
    // hâlâ geçerli, bu yüzden ayarın VARSAYILANI açık. Değişen şey, bayinin hayır diyebilmesi.
    tahsilat: yonetici || k.tahsilat,
    atama: yonetici && kuryeVar,
    musteriYonetimi: yonetici,
    musteriDuzenleme: yonetici || k.musteri,
    siparisAcma: yonetici || k.siparis,
    iskonto: yonetici || k.iskonto,
  );
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
      );

/// Kurye izinleri akışı — kabuk buna abone olur (tek atış okuma bayat kalırdı: bayi ayarı
/// değiştirdiğinde kuryenin ekranı bir sonraki açılışa kadar eski yetkiyle çalışırdı).
Stream<KuryeIzinleri> watchKuryeIzinleri(AppDatabase db) =>
    (db.select(db.tenantSettings)..where((t) => t.id.equals(1)))
        .watchSingleOrNull()
        .map(kuryeIzinleriOku);

/// Bu cihazdaki oturumun yetkileri — TEK ATIŞ. Kabuk yetkileri akıştan tutar ve alt ekranlara
/// geçirir; ama sheet gibi kabuktan bağımsız açılan yüzeyler onu taşımaz. Orada, eylemin TAM
/// ÖNCESİNDE okumak doğrudur: karar anındaki değer geçerli olan değerdir.
///
/// `kuryeVar: false` geçilir — bu fonksiyonun tükettiği yetkiler (iskonto vb.) ekip mevcudiyetine
/// bağlı değildir; atama kararı için kabuğun kendi hesabı kullanılır.
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
