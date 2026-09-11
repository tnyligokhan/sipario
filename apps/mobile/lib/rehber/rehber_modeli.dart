// REHBER — ortak veri tipleri (yüzey · kitle · adım · nasıl yapılır · görev).
//
// ÜÇ KATMANIN ORTAK SÖZLÜĞÜ burada yaşar; metnin kendisi `rehber_turlari.dart` ve
// `rehber_nasil.dart` içindedir. Ayrım bilinçli: tip dosyası ekran eklendikçe büyümez,
// metin dosyası ise sürekli büyür ve 500 satır sınırına ilk o çarpar.
//
// KATMANLAR (kullanıcı kararı 2026-09-03: A + B + C, kurye dahil, yalnız mobil):
//  • A — ana ekrandaki GÖREV KARTI (`gorev_karti.dart`): "ilk 10 dakika" listesi. Maddeleri
//    kullanıcı işaretlemez, VERİDEN okunur (`gorev_ilerlemesi.dart`).
//  • B — ekran başına İLK GİRİŞ TURU (`rehber_sahne.dart`): gerçek widget'ın üstünde spot.
//  • C — kalıcı YARDIM (`nasil_yapilir_ekrani.dart`): aranabilir görev tarifleri.
//
// ⚠️ METİN SÖZLEŞMEDİR: buradaki başlıklar/adımlar testlerle kilitlenir. Yazım kuralı
// (proje geneli): tek cümle nokta almaz, süsleme işareti yok, İngilizce terim yok.

/// Turu olan ekranlar. [anahtar] diske yazılan kimliktir — DEĞİŞTİRİLMEZ, yoksa sahadaki
/// telefonlarda görülmüş turlar yeniden başa döner.
enum RehberYuzey {
  ana('ana'),
  musteriler('musteriler'),
  siparisler('siparisler'),
  gunSonu('gun_sonu'),
  musteriDetay('musteri_detay'),
  siparisDetay('siparis_detay'),
  urunler('urunler'),
  kuryeler('kuryeler'),
  borclular('borclular'),
  cagriGunlugu('cagri_gunlugu'),
  harita('harita'),
  ayarlar('ayarlar');

  const RehberYuzey(this.anahtar);

  /// Diskteki kimlik (`sipario_rehber.txt` → `gorulen=...`).
  final String anahtar;

  static RehberYuzey? anahtardan(String a) {
    for (final y in RehberYuzey.values) {
      if (y.anahtar == a) return y;
    }
    return null;
  }
}

/// Bir rehber parçası kime gösterilir.
///
/// NEDEN AYRI BİR ÖLÇÜT VAR — spot zaten monte olmayan hedefi atlıyor: çoğu durumda kitle
/// filtresi GEREKSİZDİR ve bilinçli olarak kullanılmaz (bkz. `rehber_sahne.dart` başlığı).
/// Yalnız aynı widget'ın iki role FARKLI şey anlattığı yerde gerekir — gün sonu ekranı
/// patrona "günü kapat", kuryeye "kasanı devret" der ve ikisi de aynı kartın üstündedir.
enum RehberKitle {
  hepsi,
  yonetici,
  kurye;

  bool kapsar({required bool kuryeMi}) => switch (this) {
        RehberKitle.hepsi => true,
        RehberKitle.yonetici => !kuryeMi,
        RehberKitle.kurye => kuryeMi,
      };
}

/// KATMAN B — turun tek adımı.
class RehberAdim {
  const RehberAdim({
    required this.baslik,
    required this.metin,
    this.hedef = '',
    this.kitle = RehberKitle.hepsi,
    this.dene = '',
  });

  /// İşaret edilecek [RehberHedef] kimliği. BOŞSA adım bir hedefe bağlanmaz ve ekranın
  /// ortasında kart olarak çıkar — ekranı tanıtan giriş adımı için.
  ///
  /// Hedef o an ağaçta DEĞİLSE adım sessizce atlanır. Rol ve özellik görünürlüğü sorunu
  /// böyle çözülür: kuryede çizilmeyen kutuyu anlatan adım kendiliğinden düşer.
  final String hedef;

  final String baslik;
  final String metin;
  final RehberKitle kitle;

  /// DOLUYSA ADIM ETKİLEŞİMLİDİR: karartmanın deliği gerçekten dokunulabilir kalır, kullanıcı
  /// hedefe kendi eliyle dokunur ve tur o dokunuşla ilerler. Metin çağrının kendisidir
  /// ("Artı düğmesine bas").
  ///
  /// NEDEN İZLEMEK YERİNE YAPTIRIYORUZ: anlatılan adım unutulur, yapılan adım kalır. Bu üründe
  /// hedef kitle teknoloji toleransı düşük bir esnaf (BRIEF) — "şuraya basılır" cümlesi ile
  /// "şuraya bas" çağrısı arasındaki fark, turun izlenmesi ile öğrenilmesi arasındaki farktır.
  ///
  /// ⚠️ EKRAN DEĞİŞTİREN EYLEME KONMAZ: tur katmanı rotaların ÜSTÜNDE yaşıyor, dokunuş yeni bir
  /// sayfa ya da alt sayfa açarsa tur onun üstünde asılı kalır. Bu yüzden `dene` yalnız aynı
  /// ekranda kalan eylemlerde kullanılır (sekme değiştirmek, süzgeç çevirmek, arama kutusuna
  /// dokunmak); bir şey AÇAN adımlar düz anlatı olarak yazılır.
  final String dene;

  bool get bagsiz => hedef.isEmpty;

  /// Kullanıcının kendi eliyle yapması beklenen adım mı.
  bool get etkilesimli => dene.isNotEmpty && hedef.isNotEmpty;
}

/// KATMAN C — tek bir görev tarifi ("nasıl yapılır" listesinin bir maddesi).
class NasilYapilir {
  const NasilYapilir({
    required this.baslik,
    required this.adimlar,
    this.kitle = RehberKitle.hepsi,
    this.etiketler = const [],
  });

  final String baslik;
  final List<String> adimlar;
  final RehberKitle kitle;

  /// Aramada eşleşsin diye eklenen EŞ ANLAMLILAR — başlıkta geçmeyen ama esnafın kullandığı
  /// kelimeler ("borç" araması "veresiye" maddesini bulmalı).
  final List<String> etiketler;

  /// Arama kutusuna yazılanla eşleşiyor mu. Başlık + adımlar + etiketler taranır.
  bool eslesirMi(String arama) {
    final a = _sadelestir(arama);
    if (a.isEmpty) return true;
    if (_sadelestir(baslik).contains(a)) return true;
    for (final e in etiketler) {
      if (_sadelestir(e).contains(a)) return true;
    }
    for (final s in adimlar) {
      if (_sadelestir(s).contains(a)) return true;
    }
    return false;
  }
}

/// KATMAN A — görev kartındaki tek madde.
///
/// Sıra ENUM SIRASIDIR ve kartta da öyle çizilir: arayan tanıma en başta, çünkü ürünün varlık
/// sebebi odur (BRIEF: "kurulumdan sonra ~10 dakika içinde 'telefon çaldı, ekranda müşteri
/// çıktı' anını yaşamazsa uygulamayı bırakır").
enum RehberGorev {
  // ── Yönetici (patron/operatör) ───────────────────────────────────────────────────────
  arayanTanima(
    baslik: 'Arayan tanımayı aç',
    altBaslik: 'Telefon çaldığında müşteri ekranda çıksın',
    kitle: RehberKitle.yonetici,
  ),
  urun(
    baslik: 'Ürünlerini ekle',
    altBaslik: 'Sattığın kalemler ve fiyatları',
    kitle: RehberKitle.yonetici,
  ),
  musteri(
    baslik: 'İlk müşterini kaydet',
    altBaslik: 'Adı, telefonu ve adresi',
    kitle: RehberKitle.yonetici,
  ),
  siparis(
    baslik: 'İlk siparişini gir',
    altBaslik: 'Müşteri seç, ürün ekle, kaydet',
    kitle: RehberKitle.yonetici,
  ),
  kurye(
    baslik: 'Kuryeni ekle',
    altBaslik: 'Tek başına çalışıyorsan gerekmez',
    kitle: RehberKitle.yonetici,
    istegeBagli: true,
  ),

  // ── Kurye ────────────────────────────────────────────────────────────────────────────
  //
  // Kuryenin maddeleri kurulum değil İŞ adımlarıdır: kurye hesabını patron açar, kurye
  // yalnız kullanır. Bu yüzden "ilk 10 dakika" değil "ilk gün" listesidir ve öyle de
  // davranır — bir gün açık kalması normaldir.
  teslimat(
    baslik: 'İlk teslimatını kapat',
    altBaslik: 'Siparişi aç, teslim edildi işaretle',
    kitle: RehberKitle.kurye,
  ),
  tahsilat(
    baslik: 'Kapıda tahsilat al',
    altBaslik: 'Nakit, kart veya veresiye yaz',
    kitle: RehberKitle.kurye,
  ),
  kasaDevri(
    baslik: 'Kasanı devret',
    altBaslik: 'Gün sonunda patrona teslim',
    kitle: RehberKitle.kurye,
  );

  const RehberGorev({
    required this.baslik,
    required this.altBaslik,
    required this.kitle,
    this.istegeBagli = false,
  });

  final String baslik;
  final String altBaslik;
  final RehberKitle kitle;

  /// İsteğe bağlı madde kartın "bitti" sayılmasını ENGELLEMEZ. BRIEF: "tek kişilik bayi
  /// çoktur; kuryeye ata gibi adımlar tek kişilik işletmede hiç görünmemelidir" — burada
  /// satır büsbütün gizlenmiyor (kurye eklemek gerçekten mümkün), ama bitmesi beklenmiyor.
  final bool istegeBagli;

  /// Bu role gösterilen maddeler, enum sırasıyla.
  static List<RehberGorev> kitleIcin({required bool kuryeMi}) =>
      RehberGorev.values.where((g) => g.kitle.kapsar(kuryeMi: kuryeMi)).toList();
}

/// Türkçe arama için sadeleştirme: küçük harf + aksan/şapka eşleme.
///
/// `toLowerCase()` TEK BAŞINA YETMEZ: bayi klavyede "i" yazıp "İzmir"i, "urun" yazıp "ürün"ü
/// aramak ister. Aksanı düşürmek aramayı bağışlayıcı yapar; metnin kendisi bozulmaz (yalnız
/// karşılaştırma anahtarı üretilir).
String _sadelestir(String s) {
  const esle = {
    'ı': 'i', 'İ': 'i', 'I': 'i', 'i': 'i',
    'ğ': 'g', 'Ğ': 'g',
    'ü': 'u', 'Ü': 'u',
    'ş': 's', 'Ş': 's',
    'ö': 'o', 'Ö': 'o',
    'ç': 'c', 'Ç': 'c',
  };
  final b = StringBuffer();
  for (final ch in s.trim().split('')) {
    b.write(esle[ch] ?? ch.toLowerCase());
  }
  return b.toString();
}
