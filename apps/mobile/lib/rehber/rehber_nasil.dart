// KATMAN C'NİN METNİ — "nasıl yapılır" tarifleri.
//
// BU KATMAN, TURUN ATLANABİLİR OLMASININ BEDELİNİ ÖDER. Bir tur en iyi ihtimalle bir kez
// izlenir ve unutulur; kullanıcının aylar sonra "veresiyeyi nasıl tahsil ediyordum" diye
// soracağı yer burasıdır. Bu yüzden tarifler GÖREV bazlıdır, ekran bazlı değil: kullanıcı
// hangi ekranda olduğunu değil, ne yapmak istediğini bilir.
//
// ⚠️ METİN SÖZLEŞMEDİR (testler kilitler). Yazım kuralı: tek cümle nokta almaz, süsleme
// işareti yok, İngilizce terim yok.
//
// [NasilYapilir.etiketler] esnafın kullandığı EŞ ANLAMLILARDIR: "borç" araması "veresiye"
// maddesini bulmalı, "eleman" araması "kurye"yi. Arama aksana bakmaz (`rehber_modeli.dart`).

import 'rehber_modeli.dart';

/// Bütün tarifler, kartta çizilecek sırayla. Sıra keyfi değil KULLANIM SIKLIĞIDIR: günde
/// onlarca kez yapılan iş (sipariş girmek) en üstte, yılda bir yapılan (kurye eklemek) altta.
const List<NasilYapilir> kNasilYapilir = [
  // ── Günlük iş ──────────────────────────────────────────────────────────────────────────
  NasilYapilir(
    baslik: 'Yeni sipariş girmek',
    etiketler: ['sipariş ekle', 'satış', 'kayıt'],
    adimlar: [
      'Alt menüdeki artı düğmesine bas',
      'Sipariş Ekle satırını seç',
      'Müşteriyi ara ve seç, kayıtlı değilse yeni müşteri aç',
      'Ürünleri ve adetlerini gir',
      'Kaydet düğmesine bas, sipariş açık listesine düşer',
    ],
  ),
  NasilYapilir(
    baslik: 'Telefonla gelen çağrıdan sipariş açmak',
    etiketler: ['arayan', 'telefon', 'çağrı'],
    adimlar: [
      'Telefon çaldığında ekranda müşteri kartı çıkar',
      'Kartın üzerindeki sipariş oluştur düğmesine bas',
      'Müşteri kendiliğinden seçili gelir, ürünleri girmen yeter',
      'Numara kayıtlı değilse aynı karttan yeni müşteri açabilirsin',
    ],
  ),
  NasilYapilir(
    baslik: 'Siparişi teslim etmek',
    etiketler: ['teslimat', 'kapattım', 'bitir'],
    adimlar: [
      'Siparişler ekranından satıra dokun',
      'Teslim edildi düğmesine bas',
      'Parayı nasıl aldığını seç: nakit, kart, havale ya da veresiye',
      'İnternet yoksa da kaydedilir, bağlantı gelince kendiliğinden gönderilir',
    ],
  ),
  NasilYapilir(
    baslik: 'Veresiye yazmak',
    etiketler: ['borç', 'defter', 'sonra alırım'],
    adimlar: [
      'Siparişi teslim ederken ödeme tipinde veresiye seç',
      'Tutar müşterinin borcuna eklenir',
      'Borcu müşteri kartından ve Borçlular ekranından takip edersin',
    ],
  ),
  NasilYapilir(
    baslik: 'Veresiye tahsil etmek',
    etiketler: ['borç aldım', 'ödeme aldım', 'kapattı'],
    adimlar: [
      'Müşteri kartını aç',
      'Tahsilat düğmesine bas',
      'Aldığın tutarı ve nasıl aldığını gir',
      'Borç kendiliğinden düşer, kayıt deftere yazılır',
    ],
  ),
  NasilYapilir(
    baslik: 'Kapıda iskonto yapmak',
    etiketler: ['indirim', 'fiyat kırma', 'yuvarlama'],
    adimlar: [
      'Sipariş kartını aç',
      'İskonto satırına dokun ve düşülecek tutarı gir',
      'İskonto kayıt olarak durur, sonradan kimin yaptığı görünür',
    ],
  ),

  // ── Müşteri ────────────────────────────────────────────────────────────────────────────
  NasilYapilir(
    baslik: 'Yeni müşteri kaydetmek',
    etiketler: ['müşteri ekle', 'telefon defteri', 'kayıt aç'],
    adimlar: [
      'Alt menüdeki artı düğmesine bas ve Müşteri Ekle satırını seç',
      'Ad, telefon ve adres gir',
      'Yazmak istemiyorsan alanların yanındaki mikrofon işaretine basıp söyleyebilirsin',
      'Kaydettiğin an arayan tanıma bu numarayı bilir',
    ],
  ),
  NasilYapilir(
    baslik: 'Bir müşteriye ikinci telefon ya da adres eklemek',
    etiketler: ['ev iş', 'ikinci numara', 'şube'],
    adimlar: [
      'Müşteri kartını aç',
      'Düzenle düğmesine bas',
      'Telefon ya da adres bölümündeki ekle satırını kullan',
      'Hangisinin birincil olduğunu işaretleyebilirsin',
    ],
  ),
  NasilYapilir(
    baslik: 'Müşterinin konumunu düzeltmek',
    etiketler: ['harita', 'pin', 'adres yanlış'],
    adimlar: [
      'Müşterinin kapısındayken müşteri kartını aç',
      'Konumu güncelle düğmesine bas',
      'Bulunduğun nokta adrese kaydedilir, sonraki teslimatlar oraya gider',
      'Konum alınamazsa teslimat yine de engellenmez',
    ],
  ),
  NasilYapilir(
    baslik: 'Borç hatırlatma mesajı göndermek',
    etiketler: ['sms', 'yazışma', 'borcunu iste'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Müşteri kartını aç',
      'Hatırlatma düğmesine bas',
      'Borcu yazan hazır mesaj açılır, göndermeden önce değiştirebilirsin',
    ],
  ),
  NasilYapilir(
    baslik: 'Müşteriyi kara listeye almak',
    etiketler: ['engelle', 'sipariş almak istemiyorum'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Müşteri kartını aç',
      'Düzenle düğmesine bas ve kara liste anahtarını çevir',
      'Numara aradığında ekranda uyarı çıkar, kayıtları silinmez',
    ],
  ),

  // ── Ürün ───────────────────────────────────────────────────────────────────────────────
  NasilYapilir(
    baslik: 'Ürün eklemek ya da fiyatını değiştirmek',
    etiketler: ['zam', 'katalog', 'ürün listesi'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Menüden Ürünler sayfasını aç',
      'Yeni ürün için üstteki ekle düğmesine bas',
      'Var olan ürünün fiyatını değiştirmek için satıra dokun',
      'Değişiklik yalnız bundan sonraki siparişleri etkiler, eski siparişler olduğu gibi kalır',
    ],
  ),
  NasilYapilir(
    baslik: 'Biten ürünü listeden kaldırmak',
    etiketler: ['stok', 'tükendi', 'yok'],
    adimlar: [
      'Ürünler sayfasını aç',
      'Ürünün stokta yok anahtarını çevir',
      'Sipariş ekranında görünmez olur, geçmiş siparişlerde adı kalır',
      'Ürünü silme, silinen ürün geçmiş siparişlerden de kaybolur',
    ],
  ),

  // ── Ekip ve teslimat ───────────────────────────────────────────────────────────────────
  NasilYapilir(
    baslik: 'Siparişi kuryeye vermek',
    etiketler: ['atama', 'dağıt', 'ver'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Sipariş kartını aç',
      'Kurye satırına dokun ve kişiyi seç',
      'Kuryenin telefonuna bildirim gider ve sipariş onun listesine düşer',
    ],
  ),
  NasilYapilir(
    baslik: 'Teslim sırasını değiştirmek',
    etiketler: ['rota', 'sıralama', 'yol'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Siparişler ekranında satırdaki tutamacı basılı tut ve sürükle',
      'Oto sıralama düğmesi adreslere göre kendiliğinden bir sıra önerir',
      'Tutamacın sağda mı solda mı duracağını Ayarlar sayfasından seçersin',
    ],
  ),
  NasilYapilir(
    baslik: 'Kurye eklemek ve parola vermek',
    etiketler: ['eleman', 'personel', 'giriş bilgisi'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Menüden Kuryeler sayfasını aç',
      'Ekle düğmesine basıp adını ve telefonunu gir',
      'Giriş adı kendiliğinden üretilir, parolayı sen belirlersin',
      'Parola bir daha okunamaz, unutulursa yenisini yazarsın',
    ],
  ),
  NasilYapilir(
    baslik: 'Kuryenin yetkilerini değiştirmek',
    etiketler: ['izin', 'kısıt', 'görebilsin mi'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Kuryeler sayfasından kişiye dokun',
      'Yetkiler bölümünü aç',
      'Her anahtar tek bir şeyi açar: tahsilat, iskonto, bütün müşterileri görme gibi',
      'Boş bıraktığın anahtar işletme varsayılanını kullanır',
    ],
  ),

  // ── Kasa ───────────────────────────────────────────────────────────────────────────────
  NasilYapilir(
    baslik: 'Kasayı devretmek',
    etiketler: ['gün sonu', 'para teslim', 'devir'],
    kitle: RehberKitle.kurye,
    adimlar: [
      'Gün Sonu ekranını aç',
      'Kasa devri bölümüne gir',
      'Elindeki parayı say ve sayılan tutarı yaz',
      'Beklenen tutarla farkı varsa kayıtta görünür, düzeltilmez',
    ],
  ),
  NasilYapilir(
    baslik: 'Günü kapatmak',
    etiketler: ['kapanış', 'akşam hesabı', 'gün sonu'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Gün Sonu ekranını aç',
      'Rakamları kontrol et: ciro, tahsilat, veresiye, gider',
      'Günü kapat düğmesine bas',
      'Kapanan gün arşive geçer ve geçmiş hesaplarda durur',
    ],
  ),
  NasilYapilir(
    baslik: 'Yanlış kapanışı ya da devri geri almak',
    etiketler: ['hata', 'düzeltme', 'iptal'],
    adimlar: [
      'Gün Sonu ekranından ilgili kaydı aç',
      'Geri al düğmesine bas',
      'Kayıt silinmez, ters bir kayıtla dengelenir',
      'Böylece akşam gerçekte ne olduğu defterde görünür kalır',
    ],
  ),
  NasilYapilir(
    baslik: 'Saha gideri girmek',
    etiketler: ['benzin', 'masraf', 'harcama'],
    adimlar: [
      'Gün Sonu ekranını aç',
      'Gider ekle satırını kullan',
      'Tutarı ve ne için harcandığını yaz',
      'Gider günün kasa hesabından düşülür',
    ],
  ),

  // ── Kurulum ve sorun ───────────────────────────────────────────────────────────────────
  NasilYapilir(
    baslik: 'Telefon çaldığında müşteri ekranda çıkmıyor',
    etiketler: ['arayan tanıma', 'çalışmıyor', 'izin', 'pil'],
    adimlar: [
      'Ayarlar sayfasını aç ve Uygulama satırına gir',
      'Arayan tanıma anahtarının açık olduğundan emin ol',
      'Kurulum ve izinler satırına basıp sihirbazı baştan çalıştır',
      'Pil ayarı adımını atlama, telefonun pil yönetimi uygulamayı arka planda kapatıyor olabilir',
    ],
  ),
  NasilYapilir(
    baslik: 'Bazı numaralar için ekran çıkmasın',
    etiketler: ['muaf', 'tedarikçi', 'kendi numaram'],
    kitle: RehberKitle.yonetici,
    adimlar: [
      'Menüden Muaf Numaralar sayfasını aç',
      'Numarayı ekle',
      'O numara aradığında çağrı ekranı gösterilmez',
    ],
  ),
  NasilYapilir(
    baslik: 'İnternet yokken çalışmak',
    etiketler: ['bağlantı', 'çevrimdışı', 'sinyal yok'],
    adimlar: [
      'Hiçbir şey yapman gerekmez, uygulama internetsiz de tam çalışır',
      'Girdiğin kayıtlar telefonda bekler',
      'Bağlantı gelince kendiliğinden gönderilir, ekranın üstündeki şerit kaybolur',
      'Şerit uzun süre kalıyorsa ekranı aşağı çekip yenile',
    ],
  ),
  NasilYapilir(
    baslik: 'Koyu temayı açmak',
    etiketler: ['gece', 'karanlık', 'görünüm'],
    adimlar: [
      'Menüyü aç, alttaki koyu tema anahtarını çevir',
      'Aynı anahtar Ayarlar sayfasının Uygulama bölümünde de var',
    ],
  ),
  NasilYapilir(
    baslik: 'Rehberi baştan göstermek',
    etiketler: ['tur', 'yardım', 'sıfırla'],
    adimlar: [
      'Ayarlar sayfasını aç ve Uygulama satırına gir',
      'Rehberi baştan göster satırına bas',
      'Bütün ekran turları ve ilk adımlar listesi geri gelir',
    ],
  ),
];

/// Role göre süzülmüş ve aramaya uydurulmuş liste.
List<NasilYapilir> nasilYapilirListesi({required bool kuryeMi, String arama = ''}) => [
      for (final n in kNasilYapilir)
        if (n.kitle.kapsar(kuryeMi: kuryeMi) && n.eslesirMi(arama)) n,
    ];
