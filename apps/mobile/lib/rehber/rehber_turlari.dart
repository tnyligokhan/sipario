// KATMAN B'NİN METNİ — ekran başına tur adımları.
//
// ⚠️ BU DOSYA SÖZLEŞMEDİR. Başlıklar ve cümleler testlerle kilitli; kopyayı "iyileştirmek"
// testi kırar (bu depoda ekran metnini iyileştirmek birden çok kez kırmızıya sebep oldu).
// Yazım kuralı: tek cümle nokta almaz, süsleme işareti yok, İngilizce terim yok.
//
// ── SPOT NEREYE KONUR (kural) ────────────────────────────────────────────────────────────
// Bir adım ancak KÜÇÜK ve ekran açılır açılmaz GÖRÜNEN bir kutuya bağlanır. Bütün bir liste
// alanına delik açmak ekranın neredeyse tamamını aydınlatır — balonun sığacağı yer kalmaz ve
// spot hiçbir şeyi işaret etmemiş olur. Büyük alanları anlatan adım BAĞSIZ yazılır (ekranın
// ortasında kart). Bağsız adım zayıf bir çözüm değil: bağlam yine doğrudur, çünkü kullanıcı
// o ekranda durmaktadır.
//
// ── HEDEF ADLARI ─────────────────────────────────────────────────────────────────────────
// Kalıp `<ekran>.<parça>`. Karşılıkları (`RehberHedef` sarmalayıcıları):
//   ana.bento    → screens/ana_ekran.dart          (özet ızgarası)
//   ana.cta      → screens/ana_ekran.dart          (birincil eylem: çağrı geçmişi)
//   ana.gorev    → rehber/gorev_karti.dart         (ilk adımlar listesi)
//   ana.menu     → screens/ana_ekran_parcalari.dart(hero'daki menü düğmesi)
//   ana.altnav   → screens/home_shell.dart         (alt gezinme + artı)
//   musteri.arama→ screens/customers/customer_list_screen.dart
//   siparis.filtre→screens/orders/order_list_screen.dart (durum segmenti)
//
// Hedefi ağaçta olmayan adım sessizce atlanır — rol ve özellik filtresi böyle çalışır.

import 'rehber_modeli.dart';

/// Bir yüzeyin tur adımları; turu olmayan yüzey boş liste döner.
List<RehberAdim> rehberTuru(RehberYuzey y) => switch (y) {
      RehberYuzey.ana => _ana,
      RehberYuzey.musteriler => _musteriler,
      RehberYuzey.siparisler => _siparisler,
      RehberYuzey.gunSonu => _gunSonu,
      RehberYuzey.musteriDetay => _musteriDetay,
      RehberYuzey.siparisDetay => _siparisDetay,
      RehberYuzey.urunler => _urunler,
      RehberYuzey.kuryeler => _kuryeler,
      RehberYuzey.borclular => _borclular,
      RehberYuzey.cagriGunlugu => _cagriGunlugu,
      RehberYuzey.harita => _harita,
      RehberYuzey.ayarlar => _ayarlar,
    };

// ── ANA EKRAN ────────────────────────────────────────────────────────────────────────────
//
// İLK ADIM BAĞSIZDIR ve her turda öyledir: kullanıcı turun ne olduğunu ve nasıl kapatılacağını
// bir kutuya bakmadan önce öğrenmeli. Ayrıca bu, hedeflerin hiçbiri monte olmasa bile turun
// boş kalmamasını garanti eder (`?` düğmesi her koşulda bir şey göstermeli).
const List<RehberAdim> _ana = [
  RehberAdim(
    baslik: 'Sipario kullanmaya başlıyorsun',
    metin: 'Bu kısa tur ekranda neyin ne işe yaradığını gösterir; canın istemezse '
        'Rehberi kapat düğmesine bas, hepsi kapanır ve Ayarlar sayfasından geri açılır',
  ),
  RehberAdim(
    hedef: 'ana.gorev',
    baslik: 'İlk adımlar listesi',
    metin: 'Buradaki maddeleri sen işaretlemezsin, yaptıkça kendiliğinden dolar; '
        'hepsi bitince liste ekrandan kalkar',
  ),
  RehberAdim(
    hedef: 'ana.bento',
    baslik: 'Günün özeti',
    metin: 'Açık sipariş sayısı, bugünkü ciro, borçlular ve son gelen arama tek bakışta '
        'burada; her kutuya dokununca ilgili ekran açılır',
  ),
  RehberAdim(
    hedef: 'ana.cta',
    baslik: 'Dükkânı kim aradı',
    metin: 'Telefonla gelen her çağrı buraya düşer, kimin karşıladığı da yazar; '
        'kayıtsız numaradan gelen çağrıdan tek dokunuşla müşteri kaydı açabilirsin',
  ),
  RehberAdim(
    hedef: 'ana.menu',
    baslik: 'Menü',
    metin: 'Ürünler, kuryeler, borçlular, sipariş haritası ve ayarlar bu düğmenin altında',
  ),
  RehberAdim(
    hedef: 'ana.altnav',
    baslik: 'Alt menü ve artı düğmesi',
    metin: 'Dört ana ekran arasında buradan geçersin; ortadaki artı yeni sipariş, '
        'yeni müşteri ve tahsilat girişini açar',
  ),
];

// ── MÜŞTERİLER ───────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _musteriler = [
  RehberAdim(
    baslik: 'Müşteriler',
    metin: 'Telefon defterin burası; arayan tanıma da bu kayıtlardan çalışır, '
        'yani müşteriyi kaydettiğin an telefon çaldığında adı ekrana gelir',
  ),
  RehberAdim(
    hedef: 'musteri.arama',
    baslik: 'Aramak yazmaktan hızlıdır',
    metin: 'Ada, telefon numarasına ya da bölgeye göre süzebilirsin; '
        'numaranın son dört hanesini yazmak çoğu zaman yeter',
  ),
  RehberAdim(
    baslik: 'Bakiye rengi ne anlatır',
    metin: 'Kırmızı rakam müşterinin sana borcu, yeşil rakam senin ona borcun demek; '
        'sıfırsa hesap kapalıdır',
  ),
  RehberAdim(
    baslik: 'Müşteri kartını aç',
    metin: 'Satıra dokununca geçmiş siparişleri, adresleri, defteri ve '
        'ara, yol tarifi al gibi düğmeler çıkar',
  ),
];

// ── SİPARİŞLER ───────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _siparisler = [
  RehberAdim(
    baslik: 'Siparişler',
    metin: 'Açık, yolda ve teslim edilmiş bütün siparişler bu ekranda toplanır',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    baslik: 'Sana atanan işler',
    metin: 'Bu listede yalnız sana verilen siparişler görünür; '
        'sırayı patron değiştirirse liste kendiliğinden güncellenir',
    kitle: RehberKitle.kurye,
  ),
  RehberAdim(
    hedef: 'siparis.filtre',
    baslik: 'Durum süzgeci',
    metin: 'Açık, yolda ve teslim edildi arasında geçiş yapar; '
        'gün boyunca en çok bakacağın yer açık siparişlerdir',
  ),
  RehberAdim(
    baslik: 'Siparişi teslim etmek',
    metin: 'Satıra dokun, açılan kartta teslim edildi işaretle ve tahsilatı gir; '
        'internet yoksa da çalışır, bağlantı gelince kendiliğinden gönderilir',
  ),
  RehberAdim(
    baslik: 'Sırayı elle değiştirmek',
    metin: 'Satırdaki tutamacı basılı tutup sürükleyerek teslim sırasını değiştirebilirsin; '
        'tutamacın sağda mı solda mı duracağını Ayarlar sayfasından seçersin',
    kitle: RehberKitle.yonetici,
  ),
];

// ── GÜN SONU ─────────────────────────────────────────────────────────────────────────────
//
// AYNI EKRAN İKİ ROLE FARKLI ŞEY ANLATIR — burası `RehberKitle` filtresinin gerçekten
// gerektiği yerdir: kart ikisinde de çizilir, anlamı değişir.
const List<RehberAdim> _gunSonu = [
  RehberAdim(
    baslik: 'Gün sonu',
    metin: 'Günün cirosu, tahsilatı, veresiyesi ve giderleri burada toplanır',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    baslik: 'Kasa devri',
    metin: 'Gün boyunca topladığın parayı buradan patrona devredersin; '
        'saydığın tutarı girersin, fark varsa kayıtta görünür',
    kitle: RehberKitle.kurye,
  ),
  RehberAdim(
    baslik: 'Rakamlar nereden geliyor',
    metin: 'Hiçbir rakam elle yazılmaz, hepsi girdiğin siparişlerden ve tahsilatlardan '
        'türetilir; tutmayan bir sayı görürsen kaydın kendisine bak',
  ),
  RehberAdim(
    baslik: 'Günü kapatmak',
    metin: 'Gün kapandığında o günün hesabı arşive geçer; yanlışlık olursa kapanış '
        'geri alınabilir, kayıtlar silinmez',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    baslik: 'Yanlış devir olursa',
    metin: 'Yapılmış bir devir silinmez, ters kayıtla geri alınır; '
        'böylece akşam ne olduğu defterde görünür kalır',
    kitle: RehberKitle.kurye,
  ),
];

// ── MÜŞTERİ KARTI ────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _musteriDetay = [
  RehberAdim(
    baslik: 'Müşteri kartı',
    metin: 'Bu müşterinin bütün geçmişi tek ekranda: siparişler, ödemeler, '
        'adresler ve borç durumu',
  ),
  RehberAdim(
    baslik: 'Üstteki düğmeler',
    metin: 'Ara düğmesi telefonu açar, mesaj düğmesi yazışmayı, '
        'konum düğmesi ise adresin haritasını açar',
  ),
  RehberAdim(
    baslik: 'Defter ne demek',
    metin: 'Defter, bu müşteriyle aranızdaki bütün para hareketidir; '
        'her satır bir sipariş ya da bir ödemedir ve silinmez',
  ),
  RehberAdim(
    baslik: 'Konumu düzeltmek',
    metin: 'Kuryeyken müşterinin kapısındaysan Konumu güncelle düğmesine bas, '
        'adresin gerçek noktası kaydedilsin; sonraki teslimatlar oraya gider',
  ),
];

// ── SİPARİŞ KARTI ────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _siparisDetay = [
  RehberAdim(
    baslik: 'Sipariş kartı',
    metin: 'Siparişin kalemleri, tutarı, adresi ve durumu burada; '
        'yapılan her işlem kartın altına kayıt olarak düşer',
  ),
  RehberAdim(
    baslik: 'Teslim etmek',
    metin: 'Teslim edildi düğmesine bastığında ödeme tipini sorar: '
        'nakit, kart, havale ya da veresiye',
  ),
  RehberAdim(
    baslik: 'Veresiye yazmak',
    metin: 'Veresiye seçersen tutar müşterinin borcuna eklenir; '
        'sonra tahsil ettiğinde müşteri kartından ödeme girersin',
  ),
  RehberAdim(
    baslik: 'İnternet yokken',
    metin: 'Bodrumda ya da sinyalsiz yerde de her şey çalışır; '
        'kayıt telefonda durur ve bağlantı gelince kendiliğinden gider',
  ),
];

// ── ÜRÜNLER ──────────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _urunler = [
  RehberAdim(
    baslik: 'Ürünler',
    metin: 'Sattığın kalemler ve fiyatları burada durur; '
        'sipariş girerken bu listeden seçersin',
  ),
  RehberAdim(
    baslik: 'Stokta yok demek',
    metin: 'Biten bir ürünü silmek yerine stokta yok işaretle; '
        'sipariş ekranında görünmez olur ama geçmiş siparişlerde adı kalır',
  ),
  RehberAdim(
    baslik: 'Seçenekler',
    metin: 'Bir ürünün boy, porsiyon ya da ek malzeme gibi seçenekleri varsa '
        'onları da burada tanımlarsın',
  ),
];

// ── KURYELER ─────────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _kuryeler = [
  RehberAdim(
    baslik: 'Kuryeler',
    metin: 'Ekibindeki kişileri buradan eklersin; her birine kendi giriş adı '
        've parolası verilir',
  ),
  RehberAdim(
    baslik: 'Kim neyi görebilir',
    metin: 'Her kurye için ayrı ayrı yetki verebilirsin: tahsilat alsın mı, '
        'iskonto yapabilsin mi, bütün müşterileri görsün mü',
  ),
  RehberAdim(
    baslik: 'Tek başına çalışıyorsan',
    metin: 'Kurye eklemek zorunda değilsin; ekip olmadan da bütün ekranlar çalışır',
  ),
];

// ── BORÇLULAR ────────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _borclular = [
  RehberAdim(
    baslik: 'Borçlular',
    metin: 'Sana borcu olan müşteriler, borcu büyükten küçüğe sıralı',
  ),
  RehberAdim(
    baslik: 'Tahsilat girmek',
    metin: 'Satıra dokunup müşteri kartına gir, ödeme aldığında oradan kaydet; '
        'borç kendiliğinden düşer',
  ),
  RehberAdim(
    baslik: 'Hatırlatma göndermek',
    metin: 'Müşteri kartındaki hatırlatma düğmesi borcu yazan hazır bir mesaj açar; '
        'göndermeden önce metni değiştirebilirsin',
  ),
];

// ── ÇAĞRI GEÇMİŞİ ────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _cagriGunlugu = [
  RehberAdim(
    baslik: 'Çağrı geçmişi',
    metin: 'Dükkânı arayan herkes buraya düşer; kayıtlı müşteriyse adı, '
        'değilse yalnız numarası yazar',
  ),
  RehberAdim(
    baslik: 'Kim karşıladı',
    metin: 'Bir çağrıdan sipariş açıldıysa satırda görünür; '
        'böylece hangi çağrının işe döndüğü belli olur',
  ),
  RehberAdim(
    baslik: 'Çağrı ekranda çıkmıyorsa',
    metin: 'Telefonun pil ayarları uygulamayı arka planda kapatıyor olabilir; '
        'Ayarlar sayfasındaki kurulum ve izinler adımını yeniden çalıştır',
  ),
];

// ── SİPARİŞ HARİTASI ─────────────────────────────────────────────────────────────────────
const List<RehberAdim> _harita = [
  RehberAdim(
    baslik: 'Sipariş haritası',
    metin: 'Açık siparişlerin nerede olduğunu tek ekranda gösterir',
  ),
  RehberAdim(
    baslik: 'Numaralar ne demek',
    metin: 'Oto sıralama çalıştırıldıysa pinlerdeki numara teslim sırasıdır; '
        'sırayı sipariş listesinden elle de değiştirebilirsin',
  ),
  RehberAdim(
    baslik: 'Pin yanlış yerdeyse',
    metin: 'Adresten bulunan nokta sokağı gösterir, kapıyı değil; '
        'kurye oradayken müşteri kartından konumu güncellerse pin düzelir',
  ),
];

// ── AYARLAR ──────────────────────────────────────────────────────────────────────────────
const List<RehberAdim> _ayarlar = [
  RehberAdim(
    baslik: 'Ayarlar',
    metin: 'Beş sayfa var: hesabın, işletmen, uygulama tercihleri, '
        'bildirimler ve sürüm bilgisi',
  ),
  RehberAdim(
    baslik: 'Arayan tanıma buradan açılır',
    metin: 'Uygulama sayfasındaki kurulum ve izinler adımı telefonun izinlerini '
        'baştan ayarlar; çağrı ekranı gelmiyorsa ilk bakılacak yer orasıdır',
  ),
  RehberAdim(
    baslik: 'Rehberi yeniden açmak',
    metin: 'Uygulama sayfasının en altındaki rehberi baştan göster satırı '
        'bütün turları sıfırlar',
  ),
];
