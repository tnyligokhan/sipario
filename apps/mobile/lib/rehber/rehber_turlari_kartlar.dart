// KATMAN B'NİN METNİ — kart ve yönetim ekranlarının turları.
//
// Dört ana sekmenin turu `rehber_turlari_ekranlar.dart`ta, ana ekran ve kabuk turu
// `rehber_turlari.dart`ta (500 satır kuralı). Oradaki başlık yorumu bu dosya için de
// geçerlidir: sözleşme, yazım kuralı, zincirleme, etkileşimli adım sınırı.

import 'rehber_modeli.dart';

// ── MÜŞTERİ KARTI ────────────────────────────────────────────────────────────────────────
const List<RehberAdim> musteriDetayTuru = [
  RehberAdim(
    baslik: 'Müşteri kartı',
    metin: 'Bu müşteriyle ilgili her şey tek ekranda: '
        'iletişim, hesap, geçmiş siparişler ve para hareketleri',
  ),
  RehberAdim(
    hedef: 'musteridetay.kart',
    baslik: 'İletişim kartı',
    metin: 'Müşterinin telefonu ve adresi burada yazar\n\n'
        'Ara düğmesi telefonu açar, mesaj düğmesi yazışmayı, '
        'konum düğmesi ise adresin haritasını\n\n'
        'Müşterinin kapısındayken Konumu güncelle düğmesine basarsan '
        'bulunduğun nokta adrese kaydedilir ve sonraki teslimatlar tam oraya gider',
  ),
  RehberAdim(
    hedef: 'musteridetay.bakiye',
    baslik: 'Bakiye kartı',
    metin: 'Müşteriyle aranızdaki hesabın tek rakamlık özetidir\n\n'
        'Kırmızıysa müşteri sana borçlu, yeşilse sen ona borçlusun\n\n'
        'Bu rakam elle değiştirilemez: aşağıdaki defterin toplamıdır',
  ),
  RehberAdim(
    hedef: 'musteridetay.eylemler',
    baslik: 'Sipariş ve tahsilat',
    metin: 'Sipariş düğmesi bu müşteri seçili hâlde yeni sipariş formunu açar, '
        'yani müşteriyi baştan aramana gerek kalmaz\n\n'
        'Tahsilat düğmesi ödeme almanı sağlar: aldığın tutarı ve nasıl aldığını girersin, '
        'borç kendiliğinden düşer',
  ),
  RehberAdim(
    hedef: 'musteridetay.defter',
    baslik: 'Defter',
    metin: 'Bu müşteriyle aranızdaki bütün para hareketidir\n\n'
        'Her satır ya bir siparişi ya da bir ödemeyi anlatır ve HİÇBİRİ SİLİNMEZ\n\n'
        'Yanlış bir kayıt varsa düzeltme yaparsın: eski satır olduğu gibi kalır, '
        'altına ters bir kayıt düşer ve toplam kendiliğinden düzelir',
  ),
  RehberAdim(
    baslik: 'Favoriler ve tercihler',
    metin: 'Aşağıda bu müşterinin sık aldığı ürünler ve tercihleri durur\n\n'
        'Sipariş açarken oradan seçmek, listeyi baştan taramaktan hızlıdır',
  ),
  RehberAdim(
    baslik: 'Düzenleme ve silme',
    metin: 'Sağ üstteki kalem düğmesi adı, telefonları ve adresleri değiştirir\n\n'
        'Bir müşteriye ikinci telefon ya da ikinci adres eklemek de oradan yapılır',
  ),
];

// ── SİPARİŞ KARTI ────────────────────────────────────────────────────────────────────────
//
// ⚠️ BU TURUN ADIMLARININ HEPSİ BAĞSIZDIR ve bu bilinçli: sipariş kartı alttan açılan bir
// sayfadır, açılış animasyonu sürerken alınan dikdörtgen yanlış yeri işaret eder.
const List<RehberAdim> siparisDetayTuru = [
  RehberAdim(
    baslik: 'Sipariş kartı',
    metin: 'Siparişin bütün ayrıntısı burada: kalemler, tutar, adres, '
        'atandığı kurye ve o güne kadar yapılmış her işlem',
  ),
  RehberAdim(
    baslik: 'Üstteki rozetler',
    metin: 'En üstte siparişin numarası, durumu ve varsa atandığı kurye yazar\n\n'
        'Kurye çipine dokunarak siparişi başka birine verebilirsin',
  ),
  RehberAdim(
    baslik: 'Kalemler',
    metin: 'Müşterinin ne aldığı adet adet yazar\n\n'
        'Sipariş henüz açıkken Düzenle diyerek kalem ekleyip çıkarabilirsin; '
        'teslim edildikten sonra kalemler kilitlenir',
  ),
  RehberAdim(
    baslik: 'Teslim etmek',
    metin: 'Teslim edildi düğmesine bastığında parayı nasıl aldığını sorar: '
        'nakit, kart, havale ya da veresiye\n\n'
        'Seçtiğin an sipariş kapanır ve para deftere işlenir\n\n'
        'İnternet gerekmez: kayıt telefonda tutulur, bağlantı gelince kendiliğinden gider',
  ),
  RehberAdim(
    baslik: 'Veresiye seçersen',
    metin: 'Tutar müşterinin borcuna eklenir ve günün kasasına GİRMEZ\n\n'
        'Parayı sonra aldığında müşteri kartından tahsilat girersin, borç o zaman düşer',
  ),
  RehberAdim(
    baslik: 'Geçmiş',
    metin: 'Kartın altındaki liste bu siparişte ne olduğunu sırayla yazar: '
        'kim açtı, kime atandı, kim teslim etti, ne zaman\n\n'
        'Bir şey tartışmalı olduğunda bakılacak yer burasıdır',
  ),
];

// ── ÜRÜNLER ──────────────────────────────────────────────────────────────────────────────
const List<RehberAdim> urunlerTuru = [
  RehberAdim(
    baslik: 'Ürünler',
    metin: 'Sattığın kalemler ve fiyatları burada durur\n\n'
        'Sipariş girerken ürünleri bu listeden seçersin, o yüzden '
        'ilk yapılacak işlerden biri burayı doldurmaktır',
  ),
  RehberAdim(
    hedef: 'urun.ekle',
    baslik: 'Yeni ürün eklemek',
    metin: 'Bu satıra dokununca ürün formu açılır\n\n'
        'Ad ve fiyat zorunludur; birim (adet, kilo, litre), barkod ve fotoğraf '
        'istersen eklenir',
  ),
  RehberAdim(
    hedef: 'urun.satir',
    baslik: 'Bir ürün satırı',
    metin: 'Solda fotoğrafı (yoksa baş harfi), ortada adı ve birimi, sağda fiyatı yazar\n\n'
        'Satıra dokununca aynı form açılır ve fiyatı değiştirebilirsin',
  ),
  RehberAdim(
    baslik: 'Fiyat değiştirmek geçmişi bozmaz',
    metin: 'Bir ürünün fiyatını değiştirdiğinde yalnız BUNDAN SONRAKİ siparişler etkilenir\n\n'
        'Eski siparişler kendi fiyatını içinde taşır, yani geçmiş hesaplar aynı kalır',
  ),
  RehberAdim(
    baslik: 'Biten ürünü silme, stokta yok yap',
    metin: 'Ürün formundaki stok anahtarını kapatırsan ürün sipariş ekranında görünmez olur '
        'ama geçmiş siparişlerde adı durmaya devam eder\n\n'
        'Silmek ise geçmişi de bozar, o yüzden ürün silmek yerine kapatılır',
  ),
  RehberAdim(
    baslik: 'Seçenekler',
    metin: 'Bir ürünün boy, porsiyon ya da ek malzeme gibi seçenekleri varsa '
        'onları da formda tanımlarsın\n\n'
        'Sipariş girerken seçenekler karşına çıkar ve fiyata yansır',
  ),
];

// ── KURYELER ─────────────────────────────────────────────────────────────────────────────
const List<RehberAdim> kuryelerTuru = [
  RehberAdim(
    baslik: 'Kuryeler',
    metin: 'Ekibindeki kişileri buradan eklersin\n\n'
        'Tek başına çalışıyorsan buraya hiç girmen gerekmez: '
        'kurye olmadan da bütün ekranlar çalışır',
  ),
  RehberAdim(
    hedef: 'kurye.kart',
    baslik: 'Bir kurye kartı',
    metin: 'Kartta kuryenin adı, telefonu ve GİRİŞ ADI yazar\n\n'
        'Giriş adı bir sır değildir: kurye parolasını unuttuğunda '
        'ona hangi adla gireceğini buradan söylersin',
  ),
  RehberAdim(
    baslik: 'Parola vermek',
    metin: 'Karta dokunup parola belirlersin\n\n'
        'Parola bir daha OKUNAMAZ, yalnız yenisi yazılabilir; '
        'kurye unuttuğunda buradan yeni bir tane verirsin',
  ),
  RehberAdim(
    hedef: 'kurye.kart',
    baslik: 'Kişiye özel yetki',
    metin: 'Kartın üstündeki kilit düğmesi yalnız O KURYENİN yetkilerini açar\n\n'
        'Tahsilat alsın mı, iskonto yapabilsin mi, bütün müşterileri görsün mü, '
        'gider girebilsin mi gibi anahtarların hepsi kişi bazında ayarlanır',
  ),
  RehberAdim(
    hedef: 'kurye.varsayilan',
    baslik: 'Varsayılan yetkiler',
    metin: 'Buradaki anahtarlar YENİ eklenen kuryelerin başlangıç ayarıdır\n\n'
        'Kişiye özel bir ayar yapmadığın sürece her kurye buradaki değerleri kullanır, '
        'yani burayı bir kez ayarlayıp geçebilirsin',
  ),
  RehberAdim(
    baslik: 'Kuryeyi kapatmak',
    metin: 'İşten ayrılan kuryeyi silmek yerine pasife alırsın\n\n'
        'Böylece geçmiş teslimatlarında ve kasa devirlerinde adı görünmeye devam eder, '
        'ama artık giriş yapamaz ve sipariş atanamaz',
  ),
];

// ── BORÇLULAR ────────────────────────────────────────────────────────────────────────────
const List<RehberAdim> borclularTuru = [
  RehberAdim(
    baslik: 'Borçlular',
    metin: 'Yalnız sana borcu olan müşteriler, borcu büyükten küçüğe sıralı\n\n'
        'Üst başlıkta kaç kişi olduğu ve toplam borç yazar',
  ),
  RehberAdim(
    hedef: 'borclu.kart',
    baslik: 'Bir borçlu kartı',
    metin: 'Üstte müşterinin adı ve toplam borcu, altında bu borcu doğuran '
        'ÖDENMEMİŞ siparişler tek tek listelenir\n\n'
        'Yani "ne kadar borçlu" sorusunun yanında "hangi siparişten" sorusu da cevaplanır',
  ),
  RehberAdim(
    hedef: 'borclu.kart',
    baslik: 'İki rakam neden tutmayabilir',
    metin: 'Müşterinin defter bakiyesi ile siparişlerden kalanın toplamı '
        'her zaman aynı olmak zorunda değildir\n\n'
        'Sipariş dışı bir ödeme ya da düzeltme yapıldıysa fark normaldir; '
        'ikisi ayrı ayrı gösterilir ki hangisine baktığın belli olsun',
  ),
  RehberAdim(
    baslik: 'Tahsilat almak',
    metin: 'Karta dokunup müşteri kartına gidersin, tahsilatı orada girersin\n\n'
        'Borç düşer ve müşteri borcu bitince bu listeden kendiliğinden çıkar',
  ),
  RehberAdim(
    baslik: 'Hatırlatma göndermek',
    metin: 'Karttaki hatırlatma düğmesi borcu ve varsa hesap numaranı yazan '
        'hazır bir mesaj açar\n\n'
        'Göndermeden önce metni değiştirebilirsin; mesajın kalıbını '
        'Ayarlar sayfasındaki İşletme bölümünden ayarlarsın',
    kitle: RehberKitle.yonetici,
  ),
];

// ── ÇAĞRI GEÇMİŞİ ────────────────────────────────────────────────────────────────────────
const List<RehberAdim> cagriGunluguTuru = [
  RehberAdim(
    baslik: 'Çağrı geçmişi',
    metin: 'Dükkânı arayan herkes buraya düşer\n\n'
        'Bu ekran uygulamanın varlık sebebine en yakın yerdir: '
        'siparişlerin çoğu telefonla gelir ve hiçbirinin kaybolmaması gerekir',
  ),
  RehberAdim(
    hedef: 'cagri.satir',
    baslik: 'Bir çağrı satırı',
    metin: 'Soldaki ok çağrının yönünü söyler: içeri bakan ok gelen çağrı, '
        'dışarı bakan ok senin aradığın\n\n'
        'Numara kayıtlıysa müşterinin adı, kayıtsızsa yalnız numara yazar',
  ),
  RehberAdim(
    hedef: 'cagri.satir',
    baslik: 'Çağrıdan sipariş açmak',
    metin: 'Satıra dokununca kayıtlı müşteride kartı, kayıtsız numarada '
        'çağrı kartı açılır\n\n'
        'Kayıtsız numaradan tek dokunuşla yeni müşteri kaydı da açabilirsin',
  ),
  RehberAdim(
    hedef: 'cagri.suzgec',
    baslik: 'Kim karşıladı',
    metin: 'Üstteki şeritten tek bir kişiyi seçip yalnız onun karşıladığı '
        'çağrıları görebilirsin\n\n'
        'Tümü her zaman en başta durur, süzgeçten çıkış yolu girişten kolay olsun diye',
    kitle: RehberKitle.yonetici,
    dene: 'Şeritten bir isim seç',
  ),
  RehberAdim(
    baslik: 'Çağrı ekranı hiç çıkmıyorsa',
    metin: 'Telefonun pil yönetimi uygulamayı arka planda kapatıyor olabilir\n\n'
        'Ayarlar sayfasını aç, Uygulama satırına gir ve '
        'kurulum ve izinler adımını baştan çalıştır\n\n'
        'Xiaomi, Redmi ve Poco telefonlarda pil ayarı adımını atlamamak önemlidir',
  ),
  RehberAdim(
    baslik: 'Bazı numaralar için ekran çıkmasın',
    metin: 'Tedarikçin ya da kendi numaran her aradığında ekran açılmasını istemezsen '
        'menüdeki Muaf Numaralar sayfasına ekleyebilirsin',
    kitle: RehberKitle.yonetici,
  ),
];

// ── SİPARİŞ HARİTASI ─────────────────────────────────────────────────────────────────────
const List<RehberAdim> haritaTuru = [
  RehberAdim(
    baslik: 'Sipariş haritası',
    metin: 'Teslim bekleyen siparişlerin nerede olduğunu tek ekranda gösterir',
  ),
  RehberAdim(
    baslik: 'Pinler ne anlatır',
    metin: 'Her pin bir siparişi gösterir\n\n'
        'Pine dokununca o siparişin kartı açılır ve oradan teslim edebilirsin',
  ),
  RehberAdim(
    baslik: 'Numaralı pinler',
    metin: 'Oto sıralama çalıştırıldıysa pinlerin üstündeki numara teslim sırasıdır\n\n'
        'Sırayı sipariş listesinden parmağınla sürükleyerek de değiştirebilirsin',
    kitle: RehberKitle.yonetici,
  ),
  RehberAdim(
    baslik: 'Pin yanlış yerdeyse',
    metin: 'Yazılı adresten bulunan nokta sokağı gösterir, kapıyı değil\n\n'
        'Kurye müşterinin kapısındayken müşteri kartından konumu güncellerse '
        'pin tam yerine oturur ve bir daha kaymaz',
  ),
  RehberAdim(
    baslik: 'Harita yavaşsa',
    metin: 'Harita karolarını internetten indirir; bağlantı zayıfken '
        'boş kareler görebilirsin\n\n'
        'Bu siparişleri etkilemez, teslimat internetsiz de kapatılır',
  ),
];

// ── AYARLAR ──────────────────────────────────────────────────────────────────────────────
const List<RehberAdim> ayarlarTuru = [
  RehberAdim(
    baslik: 'Ayarlar',
    metin: 'Beş sayfa var ve her biri farklı bir konuya bakar',
  ),
  RehberAdim(
    hedef: 'ayarlar.kart',
    baslik: 'Beş sayfa',
    metin: 'Hesap: oturumun ve bu hesaba bağlı telefonlar\n'
        'İşletme: dükkân bilgileri, hesap numarası, hatırlatma mesajı\n'
        'Uygulama: görünüm ve arayan tanıma\n'
        'Bildirimler: hangi bildirim gelsin, gece sussun mu\n'
        'Hakkında: sürüm bilgisi ve yenilikler',
  ),
  RehberAdim(
    baslik: 'Arayan tanıma buradan açılır',
    metin: 'Uygulama sayfasındaki anahtar özelliği açıp kapatır\n\n'
        'Altındaki kurulum ve izinler adımı telefonun izinlerini baştan ayarlar; '
        'çağrı ekranı gelmiyorsa ilk bakılacak yer orasıdır',
  ),
  RehberAdim(
    baslik: 'Koyu tema',
    metin: 'Uygulama sayfasından ya da menünün altındaki anahtardan açılır\n\n'
        'İkisi aynı ayardır, birinde çevirdiğin diğerinde de değişmiş görünür',
  ),
  RehberAdim(
    baslik: 'Sürükleme tutamacı',
    metin: 'Siparişleri elle sıralarken tutunacağın yerin sağda mı solda mı '
        'duracağını seçersin\n\n'
        'Telefonu tek elle tutuyorsan başparmağının yetiştiği tarafa alman işini kolaylaştırır',
  ),
  RehberAdim(
    baslik: 'Rehberi yeniden açmak',
    metin: 'Uygulama sayfasının en altındaki rehberi baştan göster satırı '
        'bütün ekran turlarını ve ilk adımlar listesini sıfırlar\n\n'
        'Menüdeki Yardım satırı ise her zaman açıktır: '
        'ne yapmak istediğini yazınca adım adım tarifini gösterir',
  ),
];
