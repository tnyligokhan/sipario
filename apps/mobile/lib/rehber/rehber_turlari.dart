// KATMAN B'NİN METNİ — ANA EKRAN VE KABUK turları.
//
// Diğer ekranların turları `rehber_turlari_ekranlar.dart`ta (500 satır kuralı).
//
// ⚠️ BU DOSYA SÖZLEŞMEDİR. Başlıklar ve cümleler testlerle kilitli; kopyayı "iyileştirmek"
// testi kırar. Yazım kuralı: tek cümle nokta almaz, süsleme işareti yok, İngilizce terim yok.
//
// ══ 2026-09-04'TE BAŞTAN YAZILDI ═══════════════════════════════════════════════════════════
// Kullanıcı: *"Turlar rezalet, çok yüzeysel kalmış, sayfalara girdiğimde bir şeyleri
// işaretleyerek gösteriyor olmalıydı, mala anlatır gibi anlatmamız lazım."* Eleştiri
// doğruydu ve sebebi ölçülebilir: on iki yüzeyin YALNIZ YEDİSİNDE gerçek bir kutu işaret
// ediliyordu, geri kalanı ekranın ortasında duran karttı. Yani tur değil, özet geçiyordu.
//
// ÜÇ ŞEY DEĞİŞTİ:
//  1. **Çapa sayısı 7 → 35.** Bento tek parça yerine kutu kutu, alt gezinme tek parça yerine
//     sekme sekme işaret ediliyor. Bir ekranda kaç ayrı SORU cevaplanıyorsa o kadar adım var.
//  2. **Adım sayısı ~40 → ~85.** "Şurada rakamlar var" değil, "bu rakam nereden geliyor,
//     dokununca ne olur, tutmadığında nereye bakılır".
//  3. **Adımlar ETKİLEŞİMLİ olabiliyor** (`RehberAdim.dene`): delik gerçekten dokunulabilir
//     kalıyor ve kullanıcı hedefe kendi eliyle bastığında tur ilerliyor.
//
// ══ TURLAR BİRBİRİNE BAĞLANIR ══════════════════════════════════════════════════════════════
// Ana turun SON adımı "Müşteri sekmesine bas"tır ve etkileşimlidir: kullanıcı bastığında ana
// turu biter (görüldü yazılır), sekme değişir ve müşteriler turu kendiliğinden başlar. Aynı
// zincir müşteriler → siparişler → gün sonu diye sürer. Böylece rehber ekran ekran kopuk
// parçalar değil, tek bir gezinti oluyor.
//
// ⚠️ ETKİLEŞİMLİ ADIM YALNIZ SON ADIMDA EKRAN DEĞİŞTİREBİLİR. Ortada bir yerde ekran
// değiştiren bir `dene` konursa tur, yeni ekranın üstünde eski ekranın adımlarını anlatmaya
// devam eder (tur katmanı rotaların ÜSTÜNDE yaşıyor). Ekran içinde kalan eylemler —
// süzgeç çevirmek, gün değiştirmek, arama kutusuna dokunmak — her yerde kullanılabilir.

import 'rehber_modeli.dart';
import 'rehber_turlari_ekranlar.dart';
import 'rehber_turlari_kartlar.dart';

/// Bir yüzeyin tur adımları; turu olmayan yüzey boş liste döner.
List<RehberAdim> rehberTuru(RehberYuzey y) => switch (y) {
      RehberYuzey.ana => _ana,
      RehberYuzey.musteriler => musterilerTuru,
      RehberYuzey.siparisler => siparislerTuru,
      RehberYuzey.gunSonu => gunSonuTuru,
      RehberYuzey.musteriDetay => musteriDetayTuru,
      RehberYuzey.siparisDetay => siparisDetayTuru,
      RehberYuzey.urunler => urunlerTuru,
      RehberYuzey.kuryeler => kuryelerTuru,
      RehberYuzey.borclular => borclularTuru,
      RehberYuzey.cagriGunlugu => cagriGunluguTuru,
      RehberYuzey.harita => haritaTuru,
      RehberYuzey.ayarlar => ayarlarTuru,
    };

// ── ANA EKRAN ────────────────────────────────────────────────────────────────────────────
//
// İLK ADIM BAĞSIZDIR ve her turda öyledir: kullanıcı turun ne olduğunu ve nasıl kapatılacağını
// bir kutuya bakmadan önce öğrenmeli. Ayrıca bu, hedeflerin hiçbiri monte olmasa bile turun
// boş kalmamasını garanti eder (`?` düğmesi her koşulda bir şey göstermeli).
const List<RehberAdim> _ana = [
  RehberAdim(
    baslik: 'Sipario kullanmaya başlıyorsun',
    metin: 'Şimdi ekranı birlikte gezeceğiz ve her düğmenin ne işe yaradığını tek tek '
        'göstereceğim; işaretlenen yere bakman yeterli\n\n'
        'Canın istemezse Rehberi kapat düğmesine bas, hepsi kapanır ve '
        'Ayarlar sayfasından istediğin an geri açılır',
  ),

  // ── İlk adımlar kartı ──────────────────────────────────────────────────────────────────
  RehberAdim(
    hedef: 'ana.gorev',
    baslik: 'İlk adımlar listesi',
    metin: 'Uygulamayı kurar kurmaz yapman gereken işler burada sırayla yazıyor\n\n'
        'Bu maddeleri sen işaretlemezsin: ürünü eklediğin an ürün satırı, '
        'ilk müşteriyi kaydettiğin an müşteri satırı kendiliğinden çizilir '
        've hepsi bitince liste ekrandan tamamen kalkar',
  ),

  // ── Bento ızgarası — önce bütün, sonra kutu kutu ───────────────────────────────────────
  RehberAdim(
    hedef: 'ana.bento',
    baslik: 'Günün dört rakamı',
    metin: 'Şu dört kutu dükkânın o anki hâlini gösterir\n\n'
        'Dördü de canlıdır: bir sipariş girdiğinde ya da para aldığında '
        'rakamlar kendiliğinden değişir, yenilemen gerekmez\n\n'
        'Şimdi dördünü tek tek anlatacağım',
  ),
  RehberAdim(
    hedef: 'ana.acikSiparis',
    baslik: 'Açık Sipariş',
    metin: 'Henüz teslim edilmemiş sipariş sayısıdır\n\n'
        'Bu rakam gün içinde bakacağın en önemli sayıdır: sıfırsa elinde iş kalmamış demektir\n\n'
        'Kutuya dokununca sipariş listesi açılır',
  ),
  RehberAdim(
    hedef: 'ana.kasa',
    baslik: 'Bugün Kasa',
    metin: 'Bugün eline geçen paradır: nakit, kart ve havale toplamı\n\n'
        'Veresiye BU RAKAMA GİRMEZ, çünkü henüz para almadın; '
        'veresiye yandaki Borçlular kutusunda sayılır\n\n'
        'Altındaki küçük yazı bugün kaç teslimat yaptığını söyler',
  ),
  RehberAdim(
    hedef: 'ana.borclular',
    baslik: 'Borçlular',
    metin: 'Müşterilerin sana olan toplam borcudur\n\n'
        'Rakam her zaman kırmızıdır ve bu bir uyarı değildir: kırmızı burada '
        '"tahsil edilmemiş para" anlamına gelen bir renktir\n\n'
        'Dokununca yalnız borcu olan müşterileri gösteren liste açılır',
  ),
  RehberAdim(
    hedef: 'ana.sonArama',
    baslik: 'Son Arama',
    metin: 'Dükkânı en son kim aradıysa burada yazar\n\n'
        'Numara kayıtlıysa müşterinin adı görünür ve dokununca kartı açılır; '
        'kayıtsızsa yalnız numara yazar ve dokununca oradan yeni müşteri açabilirsin',
  ),

  // ── Birincil eylem ve aktivite ─────────────────────────────────────────────────────────
  RehberAdim(
    hedef: 'ana.cta',
    baslik: 'Dükkânı kim aradı',
    metin: 'Telefonla gelen bütün çağrılar bu düğmenin altında toplanır\n\n'
        'Bu ekranın en çok kullanacağın yeridir: siparişlerin çoğu telefonla gelir ve '
        'kimin aradığını, kimin karşıladığını buradan görürsün',
  ),
  RehberAdim(
    hedef: 'ana.aktivite',
    baslik: 'Son aktivite',
    metin: 'Bugün teslim ettiğin siparişler en yeniden eskiye doğru sıralanır\n\n'
        'Her satırda müşterinin adı, ne aldığı, nasıl ödediği ve tutarı yazar; '
        'satıra dokununca siparişin kendisi açılır\n\n'
        'Bugün hiç teslimat yoksa burası boş görünür ve bu bir hata değildir',
  ),

  // ── Hero yüzeyi ────────────────────────────────────────────────────────────────────────
  RehberAdim(
    hedef: 'ana.zil',
    baslik: 'Bildirimler',
    metin: 'Zilin üstündeki kırmızı rakam kaç okunmamış bildirimin olduğunu söyler\n\n'
        'Buraya kurye teslimatı, kasa devri ve borç uyarıları düşer; '
        'rakam yoksa okunmamış bildirim yok demektir',
  ),
  RehberAdim(
    hedef: 'ana.senkron',
    baslik: 'Senkron ve sürüm',
    metin: 'Soldaki çip telefonun sunucuyla en son ne zaman konuştuğunu söyler\n\n'
        'İnternet yokken uygulama TAM ÇALIŞIR, kayıtların telefonda birikir ve '
        'bağlantı gelince kendiliğinden gider; o yüzden burada eski bir saat görmek '
        'panik sebebi değildir\n\n'
        'Sağdaki çip kullandığın sürümü gösterir',
  ),
  RehberAdim(
    hedef: 'ana.menu',
    baslik: 'Menü',
    metin: 'Ürünler, kuryeler, borçlular, sipariş haritası, çağrı geçmişi, '
        'ayarlar ve yardım bu düğmenin altında\n\n'
        'Ana ekranda olmayan her şeyi buradan bulursun',
  ),

  // ── Alt gezinme ────────────────────────────────────────────────────────────────────────
  RehberAdim(
    hedef: 'nav.fab',
    baslik: 'Artı düğmesi',
    metin: 'Yeni bir şey eklemenin ana yolu budur\n\n'
        'Basınca iki satır çıkar: Müşteri Ekle ve Sipariş Ekle\n\n'
        'Hangi ekranda olursan ol bu düğme hep aynı yerde durur',
  ),
  RehberAdim(
    hedef: 'nav.siparis',
    baslik: 'Sipariş sekmesi',
    metin: 'Bütün siparişler burada: teslim bekleyenler, yolda olanlar ve bitenler',
  ),
  RehberAdim(
    hedef: 'nav.gunSonu',
    baslik: 'Gün Özeti sekmesi',
    metin: 'Akşam hesabını buradan yaparsın: günün cirosu, tahsilatı, veresiyesi ve gideri',
  ),
  // SON ADIM ETKİLEŞİMLİ VE ZİNCİRİN HALKASI: kullanıcı sekmeye bastığında bu tur biter,
  // ekran değişir ve müşteriler turu kendiliğinden başlar.
  RehberAdim(
    hedef: 'nav.musteri',
    baslik: 'Şimdi müşterilere bakalım',
    metin: 'Alt menüdeki dört sekme uygulamanın dört ana ekranıdır\n\n'
        'Müşteri sekmesine bas, gezmeye oradan devam edelim',
    dene: 'Müşteri sekmesine bas',
  ),
];
