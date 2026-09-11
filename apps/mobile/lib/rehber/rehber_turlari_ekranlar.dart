// KATMAN B'NİN METNİ — ana ekran DIŞINDAKİ ekranların turları.
//
// Ana ekran ve kabuk turu `rehber_turlari.dart`ta; oradaki başlık yorumu bu dosya için de
// geçerlidir (sözleşme, yazım kuralı, zincirleme, etkileşimli adım sınırı).

import 'rehber_modeli.dart';

// ── MÜŞTERİLER ───────────────────────────────────────────────────────────────────────────
const List<RehberAdim> musterilerTuru = [
  RehberAdim(
    baslik: 'Müşteriler',
    metin: 'Burası telefon defterin\n\n'
        'Arayan tanıma da bu kayıtlardan çalışır: bir müşteriyi kaydettiğin an, '
        'o numaradan gelen çağrıda adı ekrana gelir',
  ),
  RehberAdim(
    hedef: 'musteri.arama',
    baslik: 'Aramak yazmaktan hızlıdır',
    metin: 'Ada, telefon numarasına ya da bölgeye göre süzebilirsin\n\n'
        'Numaranın son dört hanesini yazmak çoğu zaman yeter, '
        'başındaki sıfırı yazmana gerek yok',
    dene: 'Arama kutusuna dokun ve bir şeyler yaz',
  ),
  RehberAdim(
    hedef: 'musteri.satir',
    baslik: 'Bir müşteri satırı',
    metin: 'Solda baş harfi, ortada adı, telefonu ve adresi yazar\n\n'
        'Adresin yanındaki iğne YEŞİLSE o müşterinin haritada işaretli bir noktası var '
        'demektir; griyse yalnız yazılı adres var',
  ),
  RehberAdim(
    hedef: 'musteri.satir',
    baslik: 'Sağdaki rakam ne anlatır',
    metin: 'Satırın sağındaki renkli rakam o müşteriyle aranızdaki hesaptır\n\n'
        'Kırmızı: müşteri sana borçlu\n'
        'Yeşil: sen müşteriye borçlusun (fazla ödeme yapmış)\n'
        'Rakam hiç yoksa hesap kapalı demektir',
  ),
  RehberAdim(
    baslik: 'Müşteri kartını açmak',
    metin: 'Satıra dokununca müşterinin kartı açılır\n\n'
        'Orada geçmiş siparişleri, adresleri, para hareketleri ve '
        'ara, mesaj at, yol tarifi al gibi düğmeler bulunur',
  ),
  RehberAdim(
    baslik: 'Yeni müşteri eklemek',
    metin: 'Sağ üstteki Yeni düğmesi ya da alttaki artı düğmesi yeni müşteri açar\n\n'
        'Yazmakla uğraşmak istemezsen alanların yanındaki mikrofon işaretine basıp '
        'adı ve adresi söyleyebilirsin',
  ),
  RehberAdim(
    hedef: 'nav.siparis',
    baslik: 'Şimdi siparişlere bakalım',
    metin: 'Sipariş sekmesine bas, gezmeye oradan devam edelim',
    dene: 'Sipariş sekmesine bas',
  ),
];

// ── SİPARİŞLER ───────────────────────────────────────────────────────────────────────────
const List<RehberAdim> siparislerTuru = [
  RehberAdim(
    baslik: 'Siparişler',
    metin: 'Açık, yolda ve teslim edilmiş bütün siparişler bu ekranda toplanır',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    baslik: 'Sana atanan işler',
    metin: 'Bu listede yalnız sana verilen siparişler görünür\n\n'
        'Patron sana yeni bir sipariş atadığında liste kendiliğinden güncellenir, '
        'ekranı yenilemen gerekmez',
    kitle: RehberKitle.kurye,
  ),
  RehberAdim(
    hedef: 'siparis.filtre',
    baslik: 'Durum süzgeci',
    metin: 'Açık, Teslim, Borçlu ve Tümü arasında geçiş yapar\n\n'
        'Gün boyunca en çok bakacağın yer Açık sekmesidir: teslim edilmeyi bekleyen işler\n\n'
        'Teslim sekmesine geçtiğinde ayrıca hangi güne baktığını seçebilirsin',
    dene: 'Bir sekmeye dokunup listeyi değiştir',
  ),
  RehberAdim(
    hedef: 'siparis.liste',
    baslik: 'Sipariş satırı nasıl okunur',
    metin: 'Her satırda sipariş numarası, müşterinin adı, adresi ve tutarı yazar\n\n'
        'Sağdaki renkli rozet siparişin durumudur; altındaki küçük yazı '
        'siparişin üstünden ne kadar zaman geçtiğini söyler',
  ),
  RehberAdim(
    hedef: 'siparis.liste',
    baslik: 'Siparişi açmak ve teslim etmek',
    metin: 'Satıra dokununca sipariş kartı alttan açılır\n\n'
        'Teslim etme, tahsilat alma ve iptal işlemlerinin hepsi orada yapılır',
  ),
  RehberAdim(
    hedef: 'siparis.arac',
    baslik: 'Harita ve kurye süzgeci',
    metin: 'Harita düğmesi açık siparişlerin nerede olduğunu tek ekranda gösterir\n\n'
        'Yanındaki kurye düğmesi listeyi tek bir kuryeye daraltır; '
        'kime baktığını üst başlıkta da yazar',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    hedef: 'siparis.sirala',
    baslik: 'Sıralama ve elle dizme',
    metin: 'Sırala düğmesi listeyi saate, tutara ya da adrese göre dizer\n\n'
        'İçindeki elle sıralama kipinde satırları parmağınla sürükleyip '
        'teslim sırasını kendin belirlersin; sıra kaydedilir ve kuryenin telefonunda da '
        'aynı sırayla görünür',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    hedef: 'nav.gunSonu',
    baslik: 'Şimdi akşam hesabına bakalım',
    metin: 'Gün Özeti sekmesine bas, gezmeye oradan devam edelim',
    dene: 'Gün Özeti sekmesine bas',
  ),
];

// ── GÜN SONU ─────────────────────────────────────────────────────────────────────────────
//
// AYNI EKRAN İKİ ROLE FARKLI ŞEY ANLATIR — `RehberKitle` filtresinin gerçekten gerektiği yer
// burasıdır: kartlar ikisinde de çizilir, anlamı değişir.
const List<RehberAdim> gunSonuTuru = [
  RehberAdim(
    baslik: 'Gün Özeti',
    metin: 'Akşam hesabını burada yaparsın\n\n'
        'Günün cirosu, eline geçen para, veresiyeye yazılanlar ve giderler tek ekranda',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    baslik: 'Kasa devri',
    metin: 'Gün boyunca topladığın parayı buradan patrona devredersin\n\n'
        'Ekran sana ne kadar para beklendiğini söyler, sen de elindeki parayı sayıp yazarsın',
    kitle: RehberKitle.kurye,
  ),
  RehberAdim(
    hedef: 'gunsonu.ozet',
    baslik: 'Rakamlar nereden geliyor',
    metin: 'Buradaki hiçbir rakam elle yazılmaz\n\n'
        'Hepsi senin girdiğin siparişlerden, aldığın tahsilatlardan ve '
        'yazdığın giderlerden türetilir\n\n'
        'Bir sayı defterinle tutmuyorsa sebebi hesapta değil, kaydın kendisindedir: '
        'o günün siparişlerine bak',
  ),
  RehberAdim(
    hedef: 'gunsonu.gun',
    baslik: 'Geçmiş günlere bakmak',
    metin: 'Oklarla bir gün geri ya da ileri gidersin\n\n'
        'Yanındaki takvim düğmesi uzağa atlamanı sağlar ve her günün altında '
        'o günün kapatılıp kapatılmadığını nokta olarak gösterir',
    kitle: RehberKitle.yonetici,
    dene: 'Sol oka basıp düne bak',
  ),
  RehberAdim(
    hedef: 'gunsonu.kapsam',
    baslik: 'Kimin hesabına bakıyorsun',
    metin: 'Tümü seçiliyken dükkânın tamamını görürsün\n\n'
        'Bir kuryenin adını seçersen yalnız onun teslimatları ve topladığı para görünür; '
        'akşam kasayı devralırken kullanacağın yer burasıdır',
    kitle: RehberKitle.yonetici,
    dene: 'Bir kapsam seçip rakamların değiştiğini gör',
  ),
  RehberAdim(
    hedef: 'gunsonu.altCubuk',
    baslik: 'Günü kapatmak',
    metin: 'Alttaki çubuk günün toplamını ve kapatma düğmesini taşır\n\n'
        'Günü kapattığında o günün hesabı arşive geçer ve bir daha değişmez\n\n'
        'Yanlışlık olursa kapanış geri alınabilir: kayıt silinmez, ters bir kayıtla '
        'dengelenir, yani akşam gerçekte ne olduğu defterde görünür kalır',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    hedef: 'gunsonu.altCubuk',
    baslik: 'Kasayı devretmek',
    metin: 'Alttaki çubuktan devri başlatırsın\n\n'
        'Elindeki parayı say ve saydığın tutarı yaz; beklenenden farklıysa fark '
        'kayıtta görünür ve düzeltilmez\n\n'
        'Eksik para bir suçlama değil bir kanıttır: görünür kalması, akşam neyin '
        'olduğunu sonradan konuşabilmeni sağlar',
    kitle: RehberKitle.kurye,
  ),
  RehberAdim(
    baslik: 'Gider girmek',
    metin: 'Benzin, köprü, tamir gibi gün içinde yaptığın harcamaları '
        'Giderler bölümünden eklersin\n\n'
        'Gider günün kasa hesabından düşülür, yani akşam elindeki paranın '
        'neden az olduğunu açıklar',
  ),
];

