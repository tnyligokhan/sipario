// BİLDİRİM SÖZLEŞMESİ — Faz 1.
//
// Bu dosya bildirim altyapısının TEK arayüzüdür. Kaynak ne olursa olsun — telefonun kendi
// verisinden üreten yerel kurallar (gün sonu özeti) ya da sunucudan gelen dürtüler
// (`bildirim/push/`) — üretilen şey bir [BildirimTaslagi]dır; ne zaman gösterileceğine,
// gösterilip gösterilmeyeceğine ve nasıl çizileceğine altyapı karar verir.
//
// SAF: bu dosya platform kanalına, veritabanına, `flutter_local_notifications`a BAĞLI DEĞİLDİR.
// Kural fonksiyonları buna bakarak yazılır ve [SahteBildirimServisi] ile test edilir; gerçek
// servis (`bildirim_servisi.dart`) yalnız uygulamada devreye girer.
//
// KAPSAM SINIRI (Faz 1): ABONELİK/ödeme ile ilgili bildirim YOKTUR — mağaza kuralı riski
// (BRIEF: mobilde fiyat, satın alma, yönlendirme bulunamaz). `sistem` kategorisi bu iş için
// KULLANILAMAZ.

import 'package:flutter/foundation.dart';
export 'sessiz_saatler.dart';

/// Bildirim türleri. Her biri sistemde AYRI bir kanaldır: bayi tek tek kısabilmeli
/// (ör. "gün sonu özeti kalsın, gecikme uyarısı sussun").
enum BildirimKategori {
  /// Akşam kasayı devrederken: bugün kaç teslim, ne kadar tahsilat, ne kadar açık borç.
  gunSonuOzeti,

  // ⚠️ KALDIRILDI (kullanıcı kararı 2026-08-14): `borcEsigi` · `vadesiGecenBorc` ·
  // `musteriGecikti` · `rutinTeslimGunu`. Dördü de çalışıyordu (FIFO alacak yaşlandırması
  // dahil) ama ürünün istemediği bildirimlerdi. Kod bayrak arkasına ALINMADI, SİLİNDİ.
  //
  // ⚠️ SAHADAKİ TELEFONLARDA KANALLARI KALIR ve bu Android'in kuralıdır: bir kanal, onu
  // oluşturan uygulama tarafından silinmedikçe sistem ayarlarında durur. Yeniden
  // oluşturulmadıkları için ARTIK BİLDİRİM ÜRETMEZLER; yalnız telefonun bildirim ayarları
  // listesinde boş birer satır olarak görünürler ve kullanıcı onları elle temizleyebilir.
  // Kanalları KODLA silmek de mümkündü, YAPILMADI: `deleteNotificationChannel` çağrısı,
  // aynı `wire` değeri bir gün geri gelirse (ör. borç eşiği yeniden istenirse) kullanıcının
  // o kanalda yaptığı ayarı da yok eder. Boş bir satır, kaybolan bir tercihten ucuzdur.

  /// Gün kapanışı EKSİK KALDI: dün gün kapatılmadı ya da kurye kasayı devretmedi.
  ///
  /// İKİSİ TEK KATEGORİDE, bilinçli: ayrı olsalardı ayarlar listesi bir satır daha uzardı ve
  /// bayi aralarındaki farkı düşünmek zorunda kalırdı. İkisi de aynı ailedendir — "gün
  /// kapanışı tamamlanmadı" — ve ikisini de yönetici görür.
  gunKapanisHatirlatma,

  /// Kullanım hakkı azaldı/bitti (oto-sıralama kontörü).
  ///
  /// ⚠️ NÖTR KALMAK ZORUNDA: fiyat, paket adı, "satın al" çağrısı ya da siteye yönlendirme
  /// İÇEREMEZ (BRIEF mağaza kuralı). Yalnız özelliğin neden çalışmadığını söyler.
  kullanimHakki,

  /// Uygulamanın kendi durumu (senkron uzun süredir yapılamadı gibi).
  /// ABONELİK/ÖDEME İÇİN KULLANILMAZ — mağaza kuralı.
  sistem,

  // ── SUNUCUDAN İTİLENLER (push) ────────────────────────────────────────────────────────
  //
  // Yukarıdakilerden FARKI kaynaktır, biçimi değil: bunları telefon kendi verisinden
  // TÜRETEMEZ, çünkü olay BAŞKA BİR CİHAZDA olur. Patron siparişi kendi telefonundan
  // kuryeye atar; kuryenin telefonunda o an hiçbir şey yoktur. Yerel kural motoru bu
  // boşluğu kapatamaz — dürtünün sunucudan gelmesi gerekir (`bildirim/push/`).
  //
  // Kurallar (sessiz saatler · günlük bütçe · kategori kısma) BUNLARA DA UYGULANIR: push
  // yalnız tetikleyicidir, bildirimi yine bu altyapı çizer.

  /// Bir sipariş BU kullanıcıya atandı. Push'un bu üründeki asıl varlık sebebi: kurye
  /// bugün siparişi ancak uygulamayı açıp senkronu bekleyerek görüyor.
  siparisAtandi,

  /// Sipariş İPTAL edildi ya da kuryeden geri alındı. Alıcı: o ana kadar ATANMIŞ olan kurye.
  ///
  /// NEDEN ATAMA KADAR ÖNEMLİ: kurye yola çıkmış olabilir. Bugün iptali görmesinin tek yolu
  /// uygulamayı açmak; görmezse boşa yol gider ve müşterinin kapısında mahcup olur.
  siparisIptal,

  /// Bir sipariş teslim edildi. Alıcı: yöneticiler (kurye kendi teslimini bilir).
  siparisTeslim,

  /// Kurye kasayı devretti. Alıcı: yöneticiler.
  kasaDevri,

  /// Hesap YENİ BİR CİHAZDA açıldı. Alıcı: yöneticiler.
  ///
  /// Bankacılık standardı ve bu üründe karşılığı hazır: Hesap → Cihazlar ekranı (0.21.0)
  /// "hesabım hangi telefonlarda açık" sorusunu zaten cevaplıyor; bildirim onu ZAMANINDA
  /// sorulur hâle getiriyor. Bugün bir kurye parolasını başkasına verse patronun haberi olmaz.
  yeniCihaz;

  /// Kalıcı kimlik: bildirim kanalı adı, ayar dosyası anahtarı ve [BildirimTaslagi.kimlik]
  /// öneki bundan türer. **MAĞAZADA DEĞİŞMEZ** — değişirse kullanıcının sistemden kıstığı
  /// kanal yeni bir kanal olarak geri açılır ve bayi kapattığı bildirimi yeniden almaya başlar.
  String get wire => switch (this) {
        BildirimKategori.gunSonuOzeti => 'gun_sonu_ozeti',
        BildirimKategori.gunKapanisHatirlatma => 'gun_kapanis_hatirlatma',
        BildirimKategori.kullanimHakki => 'kullanim_hakki',
        BildirimKategori.sistem => 'sistem',
        // Aşağıdaki beş değer SUNUCUYLA PAYLAŞILAN SÖZLEŞMEDİR (`app/Bildirim/PushOlayi.php`):
        // FCM yükünde `kategori` alanı olarak taşınır. Değiştirmek yalnız bayinin kıstığı
        // kanalı öksüz bırakmaz — sahadaki eski istemcinin gelen dürtüyü TANIMAMASINA yol açar.
        BildirimKategori.siparisAtandi => 'siparis_atandi',
        BildirimKategori.siparisIptal => 'siparis_iptal',
        BildirimKategori.siparisTeslim => 'siparis_teslim',
        BildirimKategori.kasaDevri => 'kasa_devri',
        BildirimKategori.yeniCihaz => 'yeni_cihaz',
      };

  /// Sistem bildirim ayarlarında ve uygulamanın Ayarlar ekranında görünen ad.
  ///
  /// ETİKET SERBESTTİR, [wire] DEĞİL: Android kanalın ADINI kimlik sabit kaldığı sürece
  /// günceller (`AndroidNotificationChannel(k.wire, k.ad)` — ilk argüman kimlik). Bu yüzden
  /// "Gün sonu özeti" → "Gün özeti" adlandırması (kullanıcı kararı 2026-08-06) bayinin sistemden
  /// kıstığı kanalı öksüz BIRAKMAZ. `wire` değerine aynı gerekçeyle DOKUNULMADI.
  String get ad => switch (this) {
        BildirimKategori.gunSonuOzeti => 'Gün özeti',
        BildirimKategori.gunKapanisHatirlatma => 'Kapanış hatırlatması',
        BildirimKategori.kullanimHakki => 'Kullanım hakkı',
        BildirimKategori.sistem => 'Uygulama durumu',
        BildirimKategori.siparisAtandi => 'Size sipariş atandı',
        BildirimKategori.siparisIptal => 'Sipariş iptal edildi',
        BildirimKategori.siparisTeslim => 'Teslim edildi',
        BildirimKategori.kasaDevri => 'Kasa devri',
        BildirimKategori.yeniCihaz => 'Yeni cihaz girişi',
      };

  /// Ayarlar ekranındaki tek satırlık açıklama — bayi neyi kapattığını bilmeli.
  String get aciklama => switch (this) {
        BildirimKategori.gunSonuOzeti => 'Akşam kasa ve teslim özeti',
        BildirimKategori.gunKapanisHatirlatma => 'Gün kapatılmadığında ya da kasa devredilmediğinde',
        BildirimKategori.kullanimHakki => 'Oto-sıralama hakkınız azaldığında',
        BildirimKategori.sistem => 'Senkron ve uygulama uyarıları',
        BildirimKategori.siparisAtandi => 'Bir sipariş size atandığında',
        BildirimKategori.siparisIptal => 'Size atanan sipariş iptal edildiğinde',
        BildirimKategori.siparisTeslim => 'Kurye bir siparişi teslim ettiğinde',
        BildirimKategori.kasaDevri => 'Kurye kasayı devrettiğinde',
        BildirimKategori.yeniCihaz => 'Hesabınız yeni bir telefonda açıldığında',
      };

  /// Yalnız YÖNETİCİYE (patron/operatör) anlamlı mı?
  ///
  /// Ayar ekranı bu bayrakla süzülür. Süzülmeseydi kurye, hiçbir zaman ALMAYACAĞI bir
  /// bildirimin anahtarını görürdü (sunucu "teslim edildi" ve "kasa devri" olaylarını
  /// yalnız yöneticilere gönderir — `PushGondericisi::yoneticiIdleri`). Kapatınca hiçbir
  /// şey değişmeyen bir anahtar, ayarların tamamına olan güveni bozar.
  bool get yalnizYonetici => switch (this) {
        BildirimKategori.siparisTeslim ||
        BildirimKategori.kasaDevri ||
        BildirimKategori.yeniCihaz ||
        BildirimKategori.gunKapanisHatirlatma ||
        BildirimKategori.kullanimHakki =>
          true,
        _ => false,
      };

  /// EKRANIN ÜSTÜNDE BELİRSİN Mİ (heads-up)?
  ///
  /// ⚠️ BU AYAR KANALIN DOĞUŞUNDA DONAR. Android, bir kanalın önem derecesini uygulamanın
  /// sonradan değiştirmesine İZİN VERMEZ (yalnız kullanıcı değiştirebilir) — bilinçli bir
  /// kural: uygulamanın, kullanıcının kıstığı bildirimi arkadan dolanıp geri açmasını
  /// engelliyor. Yani bir kategoriyi sonradan heads-up yapmak YENİ KANAL KİMLİĞİ gerektirir
  /// ve o da bayinin eski kanalda yaptığı kısmaları sıfırlar. Bu yüzden yeni bir kategori
  /// eklerken bu değer İLK SEFERDE doğru verilmelidir.
  ///
  /// CÖMERT DEĞİL CİMRİ DAĞITILIR: heads-up işi böler. Esnaf tezgâhta, kurye direksiyonda;
  /// her bildirim ekranın üstünde belirirse bayi bir hafta içinde HEPSİNİ kapatır ve o andan
  /// sonra önemli olanı da kaçırır (`GunlukSinir` ile aynı gerekçe). Üçü seçildi: ikisi
  /// kuryenin YOLUNU değiştiren olaylar, biri güvenlik.
  bool get headsUp => switch (this) {
        BildirimKategori.siparisAtandi ||
        BildirimKategori.siparisIptal ||
        BildirimKategori.yeniCihaz =>
          true,
        _ => false,
      };

  /// `res/raw` altındaki özel ses dosyasının adı; `null` = sistem varsayılanı.
  ///
  /// ⚠️ SES DE KANALIN DOĞUŞUNDA DONAR ([headsUp] ile aynı kısıt).
  ///
  /// İKİ AYRI TON, ÇÜNKÜ SESİN VAR OLMA SEBEBİ BİLDİRİMİ GÖREMEMEK: kurye direksiyondayken
  /// ekrana bakmaz. Tek ses kullansaydık iptal sesini "yeni sipariş" sanıp yola devam ederdi.
  /// `yeni_is` yükselen, `iptal` alçalan iki notadır (`scripts/bildirim_sesi_uret.dart`).
  ///
  /// Diğer kategorilerde ses YOK demek SESSİZ demek DEĞİLDİR — sistem varsayılanı çalar;
  /// yalnız ayırt edici bir tonu hak etmezler.
  String? get ses => switch (this) {
        BildirimKategori.siparisAtandi => 'yeni_is',
        BildirimKategori.siparisIptal => 'iptal',
        _ => null,
      };

  static BildirimKategori? wiredan(String? w) =>
      values.where((k) => k.wire == w).firstOrNull;
}

/// PUSH KAYDININ DURUMU — saha teşhisi (2026-08-14).
///
/// NEDEN VAR: "bildirim gelmiyor" şikâyetinde iki taraf da sessizdi. Sunucu "gönderecek cihaz
/// bulamadım" diyordu; telefonun jetonu NEDEN göndermediği hiçbir yerde durmuyordu. Bu durum
/// Ayarlar → Bildirimler ekranında bir satır olarak görünür, yani bayi/destek tek bakışta
/// söyleyebilir — log toplamaya, cihazı elden geçirmeye gerek kalmaz.
enum PushDurumu {
  /// Oturum yok (jetonun yazılacağı cihaz kaydı bir bayiye aittir).
  oturumYok,

  /// Firebase kurulamadı — Play Services yok (Huawei) ya da yapılandırma eksik.
  kurulamadi,

  /// Firebase kuruldu ama jeton alınamadı.
  jetonAlinamadi,

  /// Jeton alındı, sunucuya bildirilemedi (ağ yok / sunucu reddetti). Sonraki açılışta yeniden denenir.
  bildirilemedi,

  /// Jeton alındı ve sunucuya bildirildi. Push çalışır durumda.
  hazir;

  String get wire => switch (this) {
        PushDurumu.oturumYok => 'oturum-yok',
        PushDurumu.kurulamadi => 'kurulamadi',
        PushDurumu.jetonAlinamadi => 'jeton-alinamadi',
        PushDurumu.bildirilemedi => 'bildirilemedi',
        PushDurumu.hazir => 'hazir',
      };

  /// Ayarlar ekranında görünen açıklama. NE YAPILACAĞINI da söyler: yalnız arızayı bildiren
  /// bir satır, bayiyi destek aramaya zorlar.
  String get aciklama => switch (this) {
        PushDurumu.oturumYok => 'Oturum açılınca kurulacak',
        PushDurumu.kurulamadi =>
          'Bu telefonda kurulamadı — Google Play Hizmetleri gerekiyor. Uygulama normal çalışır, '
              'bildirimler gecikmeli gelir.',
        PushDurumu.jetonAlinamadi => 'Telefon kaydı alınamadı; uygulamayı yeniden açmayı deneyin',
        PushDurumu.bildirilemedi => 'Sunucuya bildirilemedi; internet gelince yeniden denenecek',
        PushDurumu.hazir => 'Kurulu — anlık bildirimler açık',
      };

  static PushDurumu? wiredan(String? w) =>
      values.where((d) => d.wire == w).firstOrNull;
}

/// Kural fonksiyonlarının ÜRETTİĞİ şey. Yan etkisi yok, eşitliği tanımlı, test edilebilir.
@immutable
class BildirimTaslagi {
  const BildirimTaslagi({
    required this.kategori,
    required this.baslik,
    required this.govde,
    required this.kimlik,
    this.yol,
    this.detay,
  });

  final BildirimKategori kategori;
  final String baslik;

  /// Gövde metni: müşteri adı ve borç tutarı BURAYA yazılır, başlık nötr tutulur.
  ///
  /// DÜZELTME (2026-07-27): önce "başlık kilit ekranında görünür, gövde gizlenir" yazıyordu;
  /// mekanizma öyle DEĞİL. `flutter_local_notifications` `publicVersion` alanını açmıyor, yani
  /// `VISIBILITY_PRIVATE` bildirimin TAMAMINI (başlık dahil) gizler. Kural yine de geçerli:
  /// kilidi açtıktan sonra bildirim rafında bir bakışta okunan şey başlıktır ve telefon
  /// uzatıldığında yanındaki onu görür. Ayrıntı gövdede kalsın.
  final String govde;

  /// Dokununca gidilecek ekran. Sözlük: `gunsonu` · `siparisler` · `cihazlar` · `musteri/<id>`.
  /// Boş bırakılırsa uygulama ana ekranda açılır.
  final String? yol;

  /// GENİŞLETİLMİŞ bildirimin metni — bayi bildirimi aşağı çekince görünen tam hâli.
  /// `null` = bu bildirim genişlemez (tek satır yeter).
  ///
  /// [govde] İLE İLİŞKİSİ: `govde` daraltılmış hâlde TEK SATIRDIR ve Android onu keser;
  /// `detay` ise çok satırlı olabilir. Bu yüzden detay, gövdenin uzun karşılığıdır — gövdede
  /// olmayan bir bilgiyi detaya koymak, bildirimi açmayan bayiden o bilgiyi saklamak olur.
  ///
  /// NEREDE DEĞERLİ: karar verilecek bildirimlerde (gün özeti: üç rakam; sipariş atandı:
  /// müşteri + adres). NEREDE GEREKSİZ: olan biteni haber verenlerde ("teslim edildi") —
  /// oraya detay koymak, açılacak bir şey varmış gibi göstermektir.
  ///
  /// ⚠️ KİLİT EKRANI KURALI DETAYA DA GEÇERLİ: müşteri adı/adresi burada da GÖVDE tarafındadır,
  /// başlıkta değil.
  final String? detay;

  /// AYNI KİMLİK = AYNI BİLDİRİM: ikinci gösterim yeni satır açmaz, üzerine yazar
  /// (çağrı günlüğündeki `insertOnConflictUpdate` mantığının bildirim karşılığı) ve günlük
  /// bildirim bütçesinden İKİNCİ KEZ düşmez.
  ///
  /// [bildirimKimligi] ile üretin — elle string birleştirmeyin, kategori öneki zorunludur.
  final String kimlik;

  BildirimTaslagi kopyala({String? baslik, String? govde, String? yol, String? detay}) =>
      BildirimTaslagi(
        kategori: kategori,
        baslik: baslik ?? this.baslik,
        govde: govde ?? this.govde,
        kimlik: kimlik,
        yol: yol ?? this.yol,
        detay: detay ?? this.detay,
      );

  @override
  bool operator ==(Object other) =>
      other is BildirimTaslagi &&
      other.kategori == kategori &&
      other.baslik == baslik &&
      other.govde == govde &&
      other.yol == yol &&
      other.detay == detay &&
      other.kimlik == kimlik;

  @override
  int get hashCode => Object.hash(kategori, baslik, govde, yol, detay, kimlik);

  @override
  String toString() => 'BildirimTaslagi(${kategori.wire}, $kimlik, "$baslik")';
}

/// Bildirim kimliği üretir: `<kategori>:<ayırt edici>`.
///
/// [ayirtEdici] AYNI ŞEYİ gösteren iki bildirimde AYNI olmalıdır — müşteri kimliği, gün
/// (`2026-07-27`) gibi. Rastgele değer vermeyin: her çağrıda yeni bildirim doğar, bayi
/// bildirim yağmuruna tutulur ve hepsini kapatır.
String bildirimKimligi(BildirimKategori kategori, String ayirtEdici) =>
    '${kategori.wire}:$ayirtEdici';

/// Gün bazlı bildirimler için ayırt edici: `2026-07-27`.
String bildirimGunAnahtari(DateTime an) {
  final y = an.year.toString().padLeft(4, '0');
  final a = an.month.toString().padLeft(2, '0');
  final g = an.day.toString().padLeft(2, '0');
  return '$y-$a-$g';
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// `yol` sözlüğü — bildirime dokunulunca nereye gidilir
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// [BildirimTaslagi.yol] değerinin çözümü. Faz 1 sözlüğü: `gunsonu` · `musteri/<id>`.
///
/// TANINMAYAN YOL `null` DÖNER, İSTİSNA ATMAZ: sözlük büyüyecek (çok-müşterili liste rotası
/// Faz 2'de gelecek) ve zamanlanmış eski bir bildirim, güncellenmiş uygulamada ya da tersi
/// durumda bilinmeyen bir yol taşıyabilir. Bilinmeyen hedef bir hata değildir; çağıran
/// kullanıcıyı bulunduğu yerde bırakır.
///
/// SAF ve burada duruyor çünkü sözlük SÖZLEŞMENİN parçası: taslağı üreten kural ile onu
/// tüketen kabuk aynı tanıma bakmalı, iki yerde iki ayrı `split('/')` olmamalı.
({String tur, String? id})? bildirimYoluCoz(String? yol) {
  final ham = yol?.trim();
  if (ham == null || ham.isEmpty) return null;
  if (ham == 'gunsonu') return (tur: 'gunsonu', id: null);
  /*
   * `siparisler` — sipariş LİSTESİ, kimliksiz. Push bildirimleri (atandı · teslim edildi)
   * buraya götürür.
   *
   * NEDEN `siparis/<id>` DEĞİL: tüketecek bir sipariş detay ekranı YOK. `OrderDetailScreen`
   * bu depoda hiç örneklenmiyor (PLAN: ölü kod temizliği borcu). Kimliği taşıyıp hiçbir yerde
   * kullanmamak, "taşınan ama tüketilmeyen bilgi"nin ta kendisidir — bu kabuk zaten bir kez
   * o hatayı ödedi (`yol` alanı aylarca yükte durdu, dokunuş ana ekranı açtı). Detay ekranı
   * geldiği gün buraya `siparis/<id>` eklenir; o zamana kadar liste dürüst hedeftir.
   */
  if (ham == 'siparisler') return (tur: 'siparisler', id: null);
  // `cihazlar` — Hesap → Cihazlar ekranı. "Yeni cihaz girişi" bildiriminin hedefi: bayi
  // uyarıyı görür görmez hangi telefonların bağlı olduğunu görebilmeli, aramak zorunda kalmamalı.
  if (ham == 'cihazlar') return (tur: 'cihazlar', id: null);
  final musteri = RegExp(r'^musteri/(.+)$').firstMatch(ham);
  if (musteri != null) return (tur: 'musteri', id: musteri.group(1));
  return null;
}

/// Bildirim altyapısının dış yüzü. Kural yazan taraf YALNIZ bunu görür.
///
/// [goster] ve [zamanla] SESSİZCE ATLAYABİLİR: kategori kapalıysa, izin yoksa, günlük sınır
/// dolduysa bildirim çizilmez. Bu bilinçlidir — kural fonksiyonu "gösterildi mi" diye
/// dallanmamalı, yalnız doğru taslağı üretmelidir.
abstract class BildirimServisi {
  Future<bool> izinDurumu();
  Future<bool> izinIste();
  Future<void> goster(BildirimTaslagi t);
  Future<void> zamanla(BildirimTaslagi t, DateTime neZaman);
  Future<void> iptal(String kimlik);
  Future<bool> kategoriAcikMi(BildirimKategori k);
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Günlük sınır — bildirim yorgunluğuna karşı
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Günde 30 sipariş giren bir bayi bildirim yağmuru görürse HEPSİNİ kapatır, sonra önemlisini
/// de kaçırır. Sayılar Faz 1 varsayılanıdır, sahadan gelen geri bildirimle ayarlanır.
///
/// AYNI KİMLİĞİN GÜNCELLENMESİ BÜTÇE YEMEZ: bir borç bildirimi gün içinde üç kez tazelense
/// bile tek bildirimdir — sayaç ayrı KİMLİK sayar, gösterim değil.
@immutable
class GunlukSinir {
  const GunlukSinir({this.toplam = 6, this.kategoriBasina = 2});

  /// Bir günde çizilebilecek toplam FARKLI bildirim.
  final int toplam;

  /// Tek bir kategorinin bütçeyi tek başına tüketmesini engeller.
  final int kategoriBasina;

  /// [gunlukKimlikler] o güne ait, kategori bazında gösterilmiş KİMLİK kümeleridir.
  bool yerVarMi(BildirimKategori k, Map<BildirimKategori, Set<String>> gunlukKimlikler, String kimlik) {
    final kategorininki = gunlukKimlikler[k] ?? const <String>{};
    // Zaten gösterilmiş kimliğin tazelenmesi her zaman serbesttir.
    if (kategorininki.contains(kimlik)) return true;
    if (kategorininki.length >= kategoriBasina) return false;
    final toplamSayi = gunlukKimlikler.values.fold<int>(0, (t, s) => t + s.length);
    return toplamSayi < toplam;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Test ikizi — kural yazan taraflar bunu kullanır
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Gerçek servisin yerine geçen, hiçbir platform çağrısı yapmayan kayıt tutucu.
/// Kural testleri "şu taslak üretildi mi" sorusunu buna sorar.
class SahteBildirimServisi implements BildirimServisi {
  SahteBildirimServisi({
    bool izinVar = true,
    Set<BildirimKategori>? kapaliKategoriler,
  })  : _izin = izinVar,
        _kapali = kapaliKategoriler ?? <BildirimKategori>{};

  bool _izin;
  final Set<BildirimKategori> _kapali;

  /// Gösterilen taslaklar, sırayla.
  final List<BildirimTaslagi> gosterilenler = [];

  /// Zamanlananlar: (taslak, an).
  final List<(BildirimTaslagi, DateTime)> zamanlananlar = [];

  /// İptal edilen kimlikler.
  final List<String> iptaller = [];

  @override
  Future<bool> izinDurumu() async => _izin;

  @override
  Future<bool> izinIste() async => _izin = true;

  @override
  Future<void> goster(BildirimTaslagi t) async {
    if (!_izin || _kapali.contains(t.kategori)) return;
    // Aynı kimlik ÜZERİNE YAZAR — gerçek servisin davranışının aynısı.
    gosterilenler.removeWhere((x) => x.kimlik == t.kimlik);
    gosterilenler.add(t);
  }

  @override
  Future<void> zamanla(BildirimTaslagi t, DateTime neZaman) async {
    if (!_izin || _kapali.contains(t.kategori)) return;
    zamanlananlar.removeWhere((x) => x.$1.kimlik == t.kimlik);
    zamanlananlar.add((t, neZaman));
  }

  @override
  Future<void> iptal(String kimlik) async {
    iptaller.add(kimlik);
    gosterilenler.removeWhere((x) => x.kimlik == kimlik);
    zamanlananlar.removeWhere((x) => x.$1.kimlik == kimlik);
  }

  @override
  Future<bool> kategoriAcikMi(BildirimKategori k) async => !_kapali.contains(k);
}
