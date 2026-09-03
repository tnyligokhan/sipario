// SÜRÜM NOTLARI — "bu güncellemede ne değişti?" sorusunun BAYİ DİLİNDEKİ cevabı.
//
// ══ NEDEN UYGULAMANIN İÇİNDE, SUNUCUDAN DEĞİL ══════════════════════════════════════════════
// Metinler burada, derlemenin İÇİNDE sabittir; `surum.json`dan ya da bir uç noktadan
// ÇEKİLMEZ. Üç sebep, üçü de bu depoda ödenmiş derslerden:
//   1. Ürün offline-first çalışır. "Ne değişti?" sorusu çoğu zaman güncelleme İNDİKTEN ve
//      uygulama YENİDEN AÇILDIKTAN sonra, yani ağın hiç garanti olmadığı anda sorulur.
//      Ağdan çekilen bir liste, tam da okunmak istendiği anda boş kalırdı.
//   2. Bu metinler CI'ın üretebileceği bir şey değildir. Commit başlıkları ("otomatik(dev):
//      16 dosya, hizli kapi yesil") bayiye hiçbir şey anlatmaz; sürüm notu bir ÇEVİRİDİR ve
//      çevirmeni insandır.
//   3. Mağaza (`magaza`) derlemesinde güncelleme yolu tamamen kapalıdır (bkz.
//      `guncelleme_sozlesmesi.dart`) — sunucudan besleseydik bu ekran orada hiç çalışmazdı,
//      oysa "ne değişti" sorusu mağaza sürümünde de sorulur.
//
// ══ YAZIM KURALI (pazarlıksız) ═════════════════════════════════════════════════════════════
// Bu liste bir DEĞİŞİKLİK GÜNLÜĞÜ DEĞİLDİR. Okuru bir bayi ya da kuryedir; şema sürümü,
// migration numarası, sınıf adı, "refactor", "LWW", "endpoint" gibi hiçbir sözcük GEÇMEZ.
// Her madde şu testi geçmeli: **bayi bu cümleyi okuyup ekranda ne yapacağını biliyor mu?**
// Geçmeyen madde yazılmaz — teknik ama görünmeyen iş (altyapı, test, güvenlik sıkılaştırması)
// buraya "İyileştirmeler ve hata düzeltmeleri" diye tek satırda girer ya da hiç girmez.
//
// MAĞAZA KURALI (BRIEF): fiyat · abonelik · satın alma · üyelik sözcüğü ASLA. Test tarar.

/// Tek bir sürümün notu.
class SurumNotu {
  const SurumNotu({
    required this.surum,
    required this.tarih,
    required this.maddeler,
  });

  /// SemVer sürüm adı — `pubspec.yaml`daki `version:` ile BİREBİR aynı yazılır ("0.14.0").
  /// Eşleşme metin karşılaştırmasıyla yapılıyor (bkz. [surumNotuBul]); "v0.14.0" yazmak
  /// ya da boşluk bırakmak "şu an kullandığınız sürüm" işaretini sessizce kaybettirir.
  final String surum;

  /// Bayiye gösterilen tarih ("11 Ağustos 2026"). Biçimlendirme değil DÜZ METİN: liste elle
  /// yazılıyor ve tarih bir yayın kararıdır — `DateTime`e çevirip biçimlendirmek, bu ekranın
  /// hiç ihtiyaç duymadığı bir yerelleştirme katmanı eklerdi.
  final String tarih;

  /// Kullanıcı dilinde maddeler. Boş bırakılmaz.
  final List<String> maddeler;
}

/// Sürüm notları — EN YENİSİ EN ÜSTTE. Yeni sürüm çıkaran herkes buraya bir kayıt ekler.
///
/// Sıra listenin kendi sırasıdır, çalışma anında sıralanmaz: SemVer'i doğru sıralamak
/// (0.9.0 < 0.10.0) metin karşılaştırmasıyla yapılamaz ve bu ekran için üç parçalı bir
/// sürüm karşılaştırıcısı yazmak, elle korunan 6 satırlık bir liste için fazlasıyla ağırdır.
const List<SurumNotu> kSurumNotlari = [
  SurumNotu(
    surum: '1.1.0',
    tarih: '3 Eylül 2026',
    maddeler: [
      'Uygulamaya rehber geldi. Ana ekranda ilk adımlar listesi var; yaptıkça kendiliğinden '
          'işaretlenir ve hepsi bitince kaybolur.',
      'Bir ekranı ilk kez açtığınızda kısa bir tanıtım çıkıyor. Canınız istemezse '
          'Rehberi kapat düğmesiyle hepsini kapatabilirsiniz.',
      'Menüye Yardım eklendi. Aradığınız işi yazın, adım adım nasıl yapıldığını gösterir.',
      'Ekranların üstündeki soru işareti o ekranın tanıtımını yeniden açar.',
      'Kuryeler kendi işine göre ayrı bir rehber görür.',
      'Ayarlar sayfasındaki Rehberi baştan göster satırı her şeyi ilk günkü hâline döndürür.',
    ],
  ),
  SurumNotu(
    surum: '1.0.2',
    tarih: '1 Eylül 2026',
    maddeler: [
      'Bildirimlerin simgesi düzeldi. Üstteki durum çubuğunda artık Sipario\'nun işareti '
          'görünüyor; eskiden orada yalnız içi dolu bir kare çıkıyordu.',
      'Gelen arama bildiriminde de aynı işaret var, telefonun kendi simgesi değil.',
    ],
  ),
  SurumNotu(
    surum: '1.0.1',
    tarih: '1 Eylül 2026',
    maddeler: [
      'Uygulamanın simgesi yenilendi. Telefonun ana ekranında artık Sipario\'nun kendi '
          'işareti duruyor.',
      'Telefonunuz simgeleri duvar kâğıdının rengine boyuyorsa Sipario da o renge uyuyor.',
    ],
  ),
  SurumNotu(
    surum: '1.0.0',
    tarih: '25 Ağustos 2026',
    maddeler: [
      'Sipario 1.0 yayında. Sipariş, veresiye defteri, kurye takibi, gün özeti ve kasa '
          'devri; hepsi internet olmadan da çalışıyor, bağlantı gelince kendiliğinden '
          'eşitleniyor.',
      'Yeni bir sürüm çıktığında artık bildirim geliyor. Uygulamayı açmadan da haberiniz '
          'olur; dokununca uygulama açılır ve en üstteki şeritten kurabilirsiniz.',
      'Üstteki güncelleme şeridinde artık belirgin bir "Güncelle" düğmesi var. Eskiden orada '
          'yalnız sürüm numarası yazıyordu ve nereye dokunulacağı belli olmuyordu.',
    ],
  ),
  SurumNotu(
    surum: '0.49.0',
    tarih: '25 Ağustos 2026',
    maddeler: [
      'Gün Özeti\'ne "Gider Ekle" geldi. Benzin, tamir, yemek gibi kasadan çıkan masrafları '
          'yazarsınız; akşam sayacağınız nakit o kadar azalır ve kasa artık boşuna eksik '
          'görünmez.',
      'Bir kuryenin yolda yaptığı masrafı da yazabilirsiniz: üstteki kapsamı o kişiye çevirip '
          'gideri girin, tutar onun hesabından düşülür.',
      'Yanlış yazdığınız bir gideri iptal edebilirsiniz. Kayıt silinmez; üstü çizili olarak '
          'yerinde kalır ve o para yine kasada sayılır.',
      'Kuryelerin gider girebilmesi Kurye Yetkileri ekranından açılır, başlangıçta kapalıdır.',
    ],
  ),
  SurumNotu(
    surum: '0.48.0',
    tarih: '25 Ağustos 2026',
    maddeler: [
      'Gün Özeti baştan sona yenilendi. En üstte artık tek bir iri rakam var: kasada olması '
          'gereken nakit. Eskiden bunu kendiniz hesaplamak zorundaydınız.',
      'Geçmiş günler için ayrı bir ekrana gitmek gerekmiyor. Sayfanın üstündeki oklarla gün gün '
          'geriye gider, takvim düğmesiyle istediğiniz güne tek dokunuşla atlarsınız.',
      'Takvimde her günün altında bir nokta var: yeşil o günün hesabı kapatıldı, sarı '
          'kapatılmadı. Atladığınız günü aramak yerine görüyorsunuz.',
      'Satılan ürün dökümü artık bugün için de açılıyor; eskiden yalnız geçmiş günlerde vardı.',
      'Teslimat sayısı, o günün veresiyesi ve gün hesabının durumu üstteki üç kutuda '
          'özetleniyor.',
    ],
  ),
  SurumNotu(
    surum: '0.47.0',
    tarih: '22 Ağustos 2026',
    maddeler: [
      'Bildirim ayarlarına "Bildirimi dene" düğmesi eklendi. Örnek bir bildirim gönderir; '
          'sesini duyup ekranın üstünde belirip belirmediğini kendiniz görebilirsiniz.',
      'Bir bildirimin ekranın üstünde belirmesi telefonunuzun ayarından kapatılmışsa '
          'uygulama bunu artık söylüyor ve düzelteceğiniz ekranı tek dokunuşla açıyor.',
    ],
  ),
  SurumNotu(
    surum: '0.46.0',
    tarih: '22 Ağustos 2026',
    maddeler: [
      'Kurye artık bir siparişin iptalini isteyebiliyor. Sipariş o anda iptal olmaz; '
          'yöneticiye onaya gider ve müşterinin kapısında beklenirken karar verilebilir.',
      'Yöneticiye gelen bildirimin içinde "Onayla" ve "Reddet" düğmeleri var. Sipariş '
          'ekranında da aynı karar, talebi kimin ve neden açtığıyla birlikte görünüyor.',
      'Talep reddedilirse kurye bunu bildirimle öğrenir ve sipariş açık kalmaya devam eder.',
    ],
  ),
  SurumNotu(
    surum: '0.45.0',
    tarih: '22 Ağustos 2026',
    maddeler: [
      'Ana ekrandaki büyük düğme artık "Ekip Çağrıları" sayfasını açıyor: dükkâna kim '
          'aradı, kim karşıladı tek dokunuşla görünüyor.',
      'Sipariş oluşturma kaybolmadı; alttaki artı düğmesinden "Sipariş Ekle" ile ve gelen '
          'çağrı kartındaki "Sipariş Oluştur" ile aynı şekilde devam ediyor.',
    ],
  ),
  SurumNotu(
    surum: '0.44.0',
    tarih: '22 Ağustos 2026',
    maddeler: [
      'Kuryenin müşteri listesi artık bir yetkiye bağlı. Yetki kapalıyken kurye yalnız '
          'kendi siparişlerinin ve kendi teslim ettiği işlerin müşterilerini görür.',
      'Yetki Ayarlar › Kurye Yetkileri altındaki "Tüm müşterileri görebilir" satırından '
          'açılır; her kurye için ayrı ayrı da ayarlanabilir.',
      'Liste daraldığında ekran bunu yazıyor, sessizce eksik göstermiyor.',
    ],
  ),
  SurumNotu(
    surum: '0.43.0',
    tarih: '22 Ağustos 2026',
    maddeler: [
      'Katalogdan ürün eklemek hızlandı: ürün kartına dokunmak bir adedi doğrudan sepete '
          'koyuyor, ayrıca bir adet ekranı açılmıyor.',
      'Kartın altındaki artı ve eksi düğmeleriyle adet sepetten çıkmadan değiştirilebiliyor.',
      'İçindekileri seçilebilen ürünlerde eski akış duruyor: karta dokunmak malzeme ve adet '
          'ekranını açar.',
    ],
  ),
  SurumNotu(
    surum: '0.42.0',
    tarih: '22 Ağustos 2026',
    maddeler: [
      'Bir hesap artık aynı anda tek bir telefonda açık kalıyor. Aynı kullanıcı adıyla başka '
          'bir telefondan girildiğinde önceki telefon giriş ekranına döner ve sebebini yazar.',
      'Giriş ekranına kendiliğinden dönen telefonda hiçbir kayıt silinmez: gönderilmemiş '
          'siparişler ve tahsilatlar cihazda bekler, aynı kişi tekrar girdiğinde gönderilir.',
      'Oturumu kapanan telefon o işletmenin bildirimlerini artık almaz.',
    ],
  ),
  SurumNotu(
    surum: '0.41.1',
    tarih: '21 Ağustos 2026',
    maddeler: [
      'Akşam saat 21:00 ile gece yarısı arasında kapatılmış bir kurye hesabı, gün hesabı '
          'kapalı olmasına rağmen geri alınabiliyordu. Artık doğru sırayı bekliyor: önce gün, '
          'sonra kurye.',
    ],
  ),
  SurumNotu(
    surum: '0.41.0',
    tarih: '21 Ağustos 2026',
    maddeler: [
      'Uygulamadaki bütün yazılar baştan sona gözden geçirildi. Başlıklar, düğmeler, '
          'uyarılar ve bildirimler artık aynı dili konuşuyor; gereksiz noktalama ve '
          'süsleme işaretleri kaldırıldı.',
      'Aynı şeyi anlatan farklı adlar tekleştirildi: "Arayan tanıma" her yerde aynı '
          'yazıyor, menüdeki "Muaf Telefonlar" artık "Muaf Numaralar".',
      'Teknik terimler günlük dile çevrildi. İzin sihirbazındaki "Üste çizim izni" artık '
          'telefonun kendi ayarındaki adıyla "Diğer uygulamaların üzerinde göster".',
      'Bir şey yapılamadığında sebebi tek cümleyle yazılıyor ve ne yapılacağı söyleniyor. '
          'Kapalı ekranlarda aynı cümleyi iki kez okumuyorsunuz.',
      'Bildirim başlıkları kısaldı: ayarlarda "Sipariş ataması", "Sipariş iptali" ve '
          '"Teslimat" olarak görünüyor.',
      'Gün kapatma düğmesi ne yaptığını yazıyor: "Kapat ve Arşivle".',
    ],
  ),
  SurumNotu(
    surum: '0.40.0',
    tarih: '21 Ağustos 2026',
    maddeler: [
      'Ana ekranda BİLDİRİM ZİLİ var. Okunmamış bildirim sayısı zilin üstünde görünüyor; '
          'dokununca hepsini bir arada okuyabiliyorsunuz.',
      'Telefonun bildirim rafını silseniz bile uyarılar burada duruyor. Gece geldiği için '
          'sabaha ertelenen ya da günlük sınıra takılan uyarılar da listede.',
      'Bir bildirime dokunmak sizi ilgili ekrana götürüyor; okundu olarak işaretleniyor.',
    ],
  ),
  SurumNotu(
    surum: '0.39.0',
    tarih: '21 Ağustos 2026',
    maddeler: [
      'Kapatmadığınız günler artık Gün Özeti\'nin tepesinde uyarı olarak duruyor: '
          '"Kapatmadığınız 3 gün var". Dokununca hangi günler olduğunu, o günün teslimat ve '
          'kasa rakamlarıyla birlikte görüyorsunuz.',
      'Geçmiş bir günü artık KAPATABİLİYORSUNUZ. Listeden güne dokunun, açılan ekranın '
          'altındaki "Günü Kapat" ile defterde o günü kapatın.',
      'Geçmiş gün kapatılırken kasa SAYIMI istenmiyor — o günün kasası bugün sayılamaz. '
          'Kayıt "sayım yapılmadı" olarak geçer ve uydurma bir fark yazılmaz.',
      'O günden kalan açık sipariş varsa gün kapatılamaz; uyarı hangi günde kaç açık sipariş '
          'olduğunu söylüyor.',
      'Kuryeden beklenen nakit bu işlemden ETKİLENMEZ: kuryenin cebindeki para gerçektir ve '
          'gün kapatmak onu silmez. Kurye hesabı her zaman güncel günde kapatılır.',
    ],
  ),
  SurumNotu(
    surum: '0.38.0',
    tarih: '20 Ağustos 2026',
    maddeler: [
      'Gün Özeti\'nde kapsam artık açılır liste: Tümü, Kendi işlemlerim, Elemanlar ve tek tek '
          'her personel. Kendi yaptığınız işleri ekibinizinkinden ayrı görebiliyorsunuz.',
      '"Elemanlar" kapsamı sizin dışınızdaki herkesin o günkü kasasını, teslimatını ve '
          'veresiyesini tek ekranda toplar.',
    ],
  ),
  SurumNotu(
    surum: '0.37.0',
    tarih: '20 Ağustos 2026',
    maddeler: [
      'Yeni personel türü: TEZGÂH. Telefona bakan, sipariş açan ve tahsilat alan kişi artık '
          'kendi hesabıyla girer — kurye hesabı vermek zorunda değilsiniz.',
      'Tezgâh siparişi açar, görevli atar, iptal eder ve tahsilat alır; ama günü kapatamaz, '
          'defteri düzeltemez, müşteri silemez ve ürün kartlarına dokunamaz. Bunlar sizde kalır.',
      'Tezgâh hesabını web sitesindeki Ekip bölümünden açarsınız; personel hakkınızdan düşer.',
    ],
  ),
  SurumNotu(
    surum: '0.36.0',
    tarih: '20 Ağustos 2026',
    maddeler: [
      'Görevli seçiminde artık KENDİNİZ de varsınız. Siparişi kendiniz götürecekseniz onu '
          'kendi üstünüze alabiliyorsunuz — listede "(siz)" diye işaretli.',
      'Görevli listesi yalnız kuryeleri değil, çalışan tüm ekibi gösteriyor ve her satırda '
          'kişinin görevi yazıyor.',
    ],
  ),
  SurumNotu(
    surum: '0.35.0',
    tarih: '20 Ağustos 2026',
    maddeler: [
      'Teslimat ve veresiye artık işi FİİLEN YAPAN kişinin hesabına yazılıyor. Siparişi Ali\'ye '
          'atayıp kendiniz teslim ederseniz, teslimat da veresiye de sizin hesabınızda görünür.',
      'Önceden bu kayıtlar atanan kuryenin hesabına düşüyordu; parası sizde, borcu onda '
          'görünüyordu. Gün sonu artık iki yarısını da aynı kişiye yazıyor.',
      'Geçmiş günler değişmedi: eski kayıtlarda teslimi kimin yaptığı yazılı olmadığı için '
          'atanan kişi gösterilmeye devam eder.',
    ],
  ),
  SurumNotu(
    surum: '0.34.0',
    tarih: '19 Ağustos 2026',
    maddeler: [
      'Koyu tema gözü daha az yoruyor. Mor vurgu koyu ekranda açıldı; artık hem daha rahat '
          'okunuyor hem de gözde titreme yapmıyor.',
      'Koyu temada gri yüzeylerdeki mor sis kaldırıldı — mor artık yalnız düğme, bağlantı ve '
          'üst bloklarda görünüyor.',
      'Borç, alacak ve uyarı renkleri koyu temada yumuşadı; küçük yazılar daha net okunuyor.',
      'Koyu temada beyaz yazının parlaklığı bir tık kısıldı — uzun listelerde göz daha az yoruluyor.',
    ],
  ),
  SurumNotu(
    surum: '0.33.0',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Ayarlar sadeleşti: her satırda kısa bir başlık ve tek satırlık açıklama var. '
          'İşletme sayfasındaki bölümler ikiye indi, gereksiz başlıklar kaldırıldı.',
      'Açılıp kapanan ayarlar artık anahtarla gösteriliyor — "Ürün içerikleri" satırında da '
          'anahtar var. Anahtarın yanındaki yazı durumu değil, ayarın ne işe yaradığını söylüyor.',
      'Ayarlar → Uygulama sayfasındaki "Gelen çağrıyı dene" kaldırıldı.',
    ],
  ),
  SurumNotu(
    surum: '0.32.0',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Ürün içerikleri artık isteğe bağlı: Ayarlar → İşletme → "Ürün içerikleri". Su ya da tüp '
          'bayisiyseniz kapalı kalır ve ürün formunda hiç görünmez; dönerci, tostçu, gözlemeci '
          'gibi hazırlanan ürün satıyorsanız açarsınız.',
      'Açıkken bile her üründe liste çıkmaz: paketli ürünlerde tek satırlık "İçindekiler ekle" '
          'bağlantısı durur. Bakkal gibi hem paketli ürün satıp hem tost yapan işletmeler '
          'yalnız gerçekten hazırladıkları ürüne malzeme girer.',
      'Kapatmak hiçbir listeyi silmez — yeniden açtığınızda hepsi yerinde durur.',
    ],
  ),
  SurumNotu(
    surum: '0.31.0',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Ürünlere "içindekiler" listesi eklendi. Ürünü düzenlerken malzemeleri yazın; sipariş '
          'alırken tek dokunuşla "soğansız" diyebilir ya da ekstra malzeme ekleyebilirsiniz. '
          'Dürümcü, gözlemeci, tostçu gibi işletmeler için hazır malzeme listeleri de var.',
      'Bir müşterinin seçimi hatırlanabiliyor: "Bu müşteri için hatırla" derseniz aynı ürünü '
          'bir daha eklediğinizde seçim kendiliğinden uygulanır — her seferinde sormanız '
          'gerekmez. Kayıtlı tercihleri müşteri kartından görebilir ve kaldırabilirsiniz.',
      'Seçim, sipariş kaleminin altında ve kuryenin ekranında yazılı çıkar; ekstra malzemenin '
          'farkı kalem tutarına eklenir.',
    ],
  ),
  SurumNotu(
    surum: '0.30.0',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Yanlış kapatılan hesap geri alınabiliyor. Gün Özeti → kapanış kaydına dokunun → '
          '"Hesabı Geri Al". İşlem yönetici parolası ister ve internet gerektirir.',
      'Geri alınan kapanış silinmez: arşivde "geri alındı" olarak görünmeye devam eder ve '
          'düzeltip yeniden kapatabilirsiniz. Kurye kapanışıyla alınan kasa devri de birlikte '
          'geri alınır.',
    ],
  ),
  SurumNotu(
    surum: '0.29.0',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Gün Özetine "Günün Veresiyeleri" bölümü eklendi: bugün ne kadar borç yazdığınızı ve '
          'hangi müşteriye yazıldığını tek bakışta görüyorsunuz. Bu rakam "Açık Veresiye" '
          'toplamından ayrıdır — o, aylardır birikmiş borcun tamamıdır.',
      'Tahsilat dökümünde her satır nereden geldiğini söylüyor: "Geçmiş sipariş", '
          '"Borç tahsilatı" ya da düzeltme. Kasa özetinde ayrıca "Eski borç tahsilatı" satırı '
          'çıkıyor — para toplama dahildir, yalnız bugünkü satıştan gelmediği belirtilir.',
    ],
  ),
  SurumNotu(
    surum: '0.28.0',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Sipariş kartındaki Ara / WhatsApp / Konum düğmelerinin yanına "Teslim Et" eklendi. '
          'Artık siparişi açmadan, listenin üzerinden teslim edip tahsilatı işleyebilirsiniz.',
      'Müşterisiz (tezgâh) siparişlerde de kartın altında "Teslim Et" düğmesi çıkıyor.',
    ],
  ),
  SurumNotu(
    surum: '0.27.0',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Her bildirim türünün artık kendine özel bir sesi var: size sipariş atandığında, sipariş '
          'iptal edildiğinde, teslim yapıldığında, kasa devredildiğinde ve gün özeti hazır '
          'olduğunda telefonunuz farklı çalıyor. Ekrana bakmadan hangi haberin geldiğini '
          'anlayabilirsiniz.',
      'Sesler daha belirgin hâle getirildi — motor sesinde ve tezgâh gürültüsünde duyulmak için.',
      'Bu değişiklik yüzünden telefonunuzun bildirim ayarlarında bu başlıklara daha önce elle '
          'yaptığınız kısmalar sıfırlanmış olabilir. Uygulama içindeki Bildirim ayarlarınız '
          'olduğu gibi korunur.',
    ],
  ),
  SurumNotu(
    surum: '0.26.2',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Sipariş eklerken açılan ürün kataloğunda kartlar küçültüldü: bir satıra iki yerine üç '
          'ürün sığıyor, aynı ekranda daha fazla ürün görüyorsunuz.',
    ],
  ),
  SurumNotu(
    surum: '0.26.1',
    tarih: '18 Ağustos 2026',
    maddeler: [
      'Patron ve operatör hesaplarında Kuryeler ve Muaf Telefonlar sayfalarının "Bu ekran '
          'yöneticilere açık" uyarısıyla açılmaması giderildi. Yetkiniz varsa sayfalar '
          'yeniden normal açılıyor.',
    ],
  ),
  SurumNotu(
    surum: '0.26.0',
    tarih: '17 Ağustos 2026',
    maddeler: [
      'Yönetim ekranları (Ürünler, Kuryeler, Muaf telefonlar) artık yalnız yetkisi kesin olarak '
          'bilinen hesaplara açılıyor. Uygulama yeni açıldığında bilgiler sunucudan inene kadar '
          'bu sayfalar kısa süre kapalı görünebilir; bilgiler indiğinde kendiliğinden açılır.',
      'İyileştirmeler ve hata düzeltmeleri.',
    ],
  ),
  SurumNotu(
    surum: '0.25.1',
    tarih: '17 Ağustos 2026',
    maddeler: [
      'Uzun süredir güncellenmemiş telefonlarda uygulamanın güncelleme sonrası açılmaması ya da '
          'Kuryeler ekranının boş gelmesi sorunu giderildi. Kayıtlı verileriniz yerinde kalır.',
      'İyileştirmeler ve hata düzeltmeleri.',
    ],
  ),
  SurumNotu(
    surum: '0.25.0',
    tarih: '14 Ağustos 2026',
    maddeler: [
      'Ayarlar → Bildirimler sayfasına "Anlık bildirimler" satırı eklendi. Telefonunuzun '
          'bildirim sistemine kayıtlı olup olmadığını buradan görebilirsiniz.',
      'Bazı kurulumlarda anlık bildirimlerin hiç kurulamadığı bir durum düzeltildi.',
    ],
  ),
  SurumNotu(
    surum: '0.24.0',
    tarih: '14 Ağustos 2026',
    maddeler: [
      'Size sipariş atandığında ve atanan sipariş iptal edildiğinde bildirim artık ekranın '
          'üstünde beliriyor ve kendi sesiyle geliyor. Yeni iş ile iptalin sesi farklı — '
          'telefona bakmadan ayırt edebilirsiniz.',
      'Sipariş iptal edildiğinde ya da sizden alındığında haber veriliyor; boşuna yola '
          'çıkmıyorsunuz.',
      'Hesabınız yeni bir telefonda açıldığında bildirim geliyor. Bildirime dokununca bağlı '
          'telefonların listesi açılıyor.',
      'Akşam kurye kasayı devretmediyse ve sabah dünün kasası kapatılmadıysa hatırlatılıyor.',
      'Oto-sıralama hakkınız azaldığında haber veriliyor.',
      'İki gündür sunucuya bağlanılamıyorsa uyarı geliyor — kayıtlarınız telefonda güvende, '
          'bağlantı gelince kendiliğinden gönderiliyor.',
      'Uzun bildirimler artık aşağı çekilince tamamı okunabiliyor.',
    ],
  ),
  SurumNotu(
    surum: '0.23.0',
    tarih: '14 Ağustos 2026',
    maddeler: [
      'Dört bildirim kaldırıldı: borç eşiği, vadesi geçen borç, müşteri gecikti ve rutin '
          'teslim günü. Bildirim listesi artık yalnız gerçekten işinize yarayanları içeriyor.',
      'Ayarlar → Bildirimler sayfası sadeleşti; borç eşiği alanı kalktı.',
    ],
  ),
  SurumNotu(
    surum: '0.22.0',
    tarih: '14 Ağustos 2026',
    maddeler: [
      'Sipariş kuryeye atandığında kuryenin telefonu artık anında haber veriyor. '
          'Uygulamayı açıp beklemeye gerek yok.',
      'Bir sipariş teslim edildiğinde ve kurye kasayı devrettiğinde yöneticiye bildirim '
          'geliyor.',
      'Bu bildirimlerin her biri Ayarlar → Bildirimler bölümünden tek tek kapatılabiliyor; '
          'sessiz saatleriniz bunlarda da geçerli.',
    ],
  ),
  SurumNotu(
    surum: '0.21.0',
    tarih: '13 Ağustos 2026',
    maddeler: [
      'İşletme ayarları konularına ayrıldı. Kimlik, Tahsilat, Mesajlar ve Sipariş artık ayrı '
          'sayfalar; eskiden hepsi tek bir uzun formdu.',
      'IBAN ve alıcı adı Tahsilat sayfasına taşındı. Ayarlar listesinde IBAN\'ınız görünüyor, '
          'girilmemişse bunu içeri girmeden fark ediyorsunuz.',
      'Hatırlatma metni artık Mesajlar sayfasında ve sayfa birden çok metni taşıyacak şekilde '
          'kuruldu — ileride eklenecek metinler aynı yerde toplanacak.',
      'Fiş alt notu Tahsilat sayfasına geçti; İşletme Kimliği ile ilgisi yoktu. Alan hâlâ '
          '"Çok yakında".',
      'Bir sayfayı kaydetmek diğer sayfaların bilgisine artık dokunmuyor. Önceden yan sayfadaki '
          'bir alanın sessizce boşalması mümkündü.',
      'Hesap sayfasına Cihazlar eklendi: hesabınızın hangi telefonlarda açık olduğunu, her '
          'birinin en son ne zaman görüldüğünü görüyorsunuz.',
    ],
  ),
  SurumNotu(
    surum: '0.20.1',
    tarih: '13 Ağustos 2026',
    maddeler: [
      'Düzeltme: giriş ekranındaki "Parolamı unuttum" bağlantısı kocaman beyaz bir kutu olarak '
          'çiziliyor ve giriş düğmesiyle yarışıyordu; artık sade bir bağlantı.',
      'Giriş ekranına "Parolamı unuttum" eklendi. Daha önce parolasını unutan kullanıcının '
          'uygulamada yapabileceği hiçbir şey yoktu.',
      'Ekran iki durumu da baştan söylüyor: yöneticiyseniz kayıtlı e-posta adresinize '
          'sıfırlama bağlantısı gelir; kurye ya da operatörseniz parolanızı bayi yöneticiniz '
          'belirler ve ona başvurmanız gerekir.',
      'Firma kodu ve kullanıcı adı giriş ekranından devralınıyor, yeniden yazmanız gerekmiyor.',
    ],
  ),
  SurumNotu(
    surum: '0.19.1',
    tarih: '13 Ağustos 2026',
    maddeler: [
      'Düzeltme: bir arama yapıldıktan sonra kaydın listeye düşmesi gecikiyordu; artık uygulamaya '
          'her dönüşte yazılıyor.',
      'Düzeltme: gelen ve giden çağrı ikonları birbirinden ayırt edilemiyordu — ikisi de aynı '
          'ahizeydi. Artık yön oku ve renk taşıyorlar.',
      'Düzeltme: aramayı kimin yaptığı bilgisi kaydediliyor ama kısa süre sonra kayboluyordu.',
      'Çağrı geçmişinde artık her aramanın yanında onu kimin karşıladığı yazıyor. Gelen ve '
          'giden çağrılar için de geçerli.',
      'Kullanıcıya göre süzme geldi: listenin üstündeki şeritten bir kişi seçip yalnız onun '
          'aramalarını görebiliyorsunuz.',
      'Bu bilgi telefonlar arasında da paylaşılıyor — kuryenin telefonundan yapılan arama, '
          'yöneticinin telefonuna kimin yaptığıyla birlikte iniyor.',
      'Bu güncellemeden ÖNCEKİ aramalarda kişi bilgisi yok ve sonradan tahmin edilmiyor; o '
          'satırlarda kimse yazmıyor.',
    ],
  ),
  SurumNotu(
    surum: '0.18.0',
    tarih: '13 Ağustos 2026',
    maddeler: [
      'Menü baştan tasarlandı ve üç bölgeye ayrıldı: en üstte kim olduğunuz ve verinizin '
          'durumu, ortada gidebileceğiniz ekranlar, altta sık çevirdiğiniz anahtarlar.',
      'Menünün tepesine durum şeridi geldi: son senkron saati görünüyor, sunucuya '
          'gönderilemeyen kayıt varsa kırmızıyla ve sayısıyla yazıyor.',
      '"Borçlular" satırı artık borçlu müşteri sayısını rozet olarak gösteriyor — menüyü '
          'açtığınızda bakmanız gerekip gerekmediğini görüyorsunuz.',
      'Lisans ve oto sıralama bilgisi büyük kartlardan ince bir şeride indi; menüde daha az '
          'yer kaplıyor, aynı bilgiyi veriyor.',
      'Sağ üstteki "×" kaldırıldı (menü zaten boşluğa dokununca kapanıyor); o köşe artık '
          'Çıkış Yap düğmesinin.',
      // ⚠️ "abone" SÖZCÜĞÜ KULLANILAMAZ (mağaza kuralı; `surum_notlari_test.dart` tarar).
      // İlk yazımda "Abonelik bittiğinde…" denmişti ve test haklı olarak kırdı: sürüm notları
      // da uygulamanın İÇİNDE gösterilen bir yüzeydir, kural orada da geçerlidir.
      'Erişim süresi dolduğunda görünen ekran yeniden yazıldı: tek uzun paragraf yerine '
          'neyin açık, neyin kapalı olduğu ayrı ayrı yazıyor ve "Kayıtları Görüntüle" öne çıktı.',
    ],
  ),
  SurumNotu(
    surum: '0.17.0',
    tarih: '13 Ağustos 2026',
    maddeler: [
      'Menü baştan düzenlendi. Alt bardaki dört sekmeyi tekrarlayan satırlar kaldırıldı; '
          'yerlerine menüden daha önce ulaşılamayan ekranlar geldi: Borçlular, Çağrı Geçmişi '
          've Sipariş Haritası.',
      'Koyu Tema ve Arayan Tanıma anahtarları menüye taşındı — günde birçok kez çevrilen '
          'tercihler artık tek dokunuş uzakta.',
      'Ayarlar kategorilere ayrıldı: Hesap, İşletme, Uygulama, Bildirimler ve Hakkında. '
          'Her biri kendi sayfasında.',
      'Yeni "Hesap" sayfası: hangi kullanıcıyla, hangi rolde ve hangi firmaya bağlı '
          'girdiğinizi buradan görüyorsunuz.',
      'Çağrı Geçmişi artık Ayarlar\'ın içinde değil, menüde. Orası bir iş kaydıdır, ayar değil.',
      'Sessiz saatler ayarlanabilir oldu. Daha önce 22:00 – 08:00 sabitti; artık kendi '
          'çalışma saatlerinize göre seçiyorsunuz.',
      'Sürükleme tutamacının tarafı (sağ/sol el) Ayarlar → Uygulama altına eklendi.',
      'Güvenlik düzeltmesi: çağrı geçmişinden açılan müşteri kartında kurye yetkileri '
          'uygulanmıyordu. Bu yoldan giren kurye, normalde yalnız yöneticiye açık olan müşteri '
          'silme, kara listeye alma ve maskesiz telefon bilgilerine erişebiliyordu. Kapatıldı.',
      'Fiş alt notu alanı "Çok yakında" olarak işaretlendi: teslim fişi özelliği henüz yok ve '
          'yazılan not hiçbir yerde görünmüyordu.',
    ],
  ),
  SurumNotu(
    surum: '0.16.0',
    tarih: '13 Ağustos 2026',
    maddeler: [
      'Gün içinde kuryeden nakit alma yetkisi artık yalnız yöneticide. Kurye kendi gün '
          'özetini ve teslimat dökümünü görmeye devam ediyor, ama "Ara Tahsilat" düğmesi '
          'onun ekranında görünmüyor.',
      'Yanlış alınmış bir ara tahsilat artık iptal edilebiliyor: Gün Özeti\'ndeki "Ara '
          'Tahsilatlar" listesinde o satıra dokunup onaylıyorsunuz. Tutar toplamdan düşüyor '
          've o nakit kuryede sayılmaya geri dönüyor.',
      'İptal edilen kayıt silinmiyor: kimden, saat kaçta ve ne kadar alındığı listede üstü '
          'çizili olarak görünmeye devam ediyor.',
    ],
  ),
  SurumNotu(
    surum: '0.15.0',
    tarih: '13 Ağustos 2026',
    maddeler: [
      'Sipariş artık kurye seçilmeden kaydedilmiyor. Kuryesi olan işletmelerde "Siparişi '
          'Kaydet" yanındaki alandan kimin götüreceğini seçmeniz gerekiyor; seçmeden '
          'kaydetmeye çalışırsanız ekran sebebini yazıyor. Kuryesi olmayan işletmede bu '
          'alan hiç görünmüyor ve sipariş eskisi gibi kaydediliyor.',
      'Yeni sipariş ekranı sadeleşti. Ürün ekleme yollarının üçü de (her zamanki ürünler, '
          'katalog, serbest satır) artık üst üste duruyor; eklediğiniz kalemler hemen '
          'altlarında kendi başlığı ve sayacıyla listeleniyor.',
      'Sepetteki her kalemin altında duran "Not ekle" yazısı küçüldü ve birim bilgisinin '
          'yanına geçti — not eklemek yine tek dokunuş, ama liste daha kısa ve okunaklı.',
      'Özet adımında toplam tek bir yerde, en altta kendi satırında yazıyor.',
      'Kuryeyi seçtiğiniz alan "Siparişi Kaydet" düğmesinin yanına taşındı: kime gittiğini '
          've kaydetmeyi tek bakışta görüyorsunuz.',
      'Üstteki adım rozetlerine (Müşteri, Kalemler, Özet) dokunarak geçtiğiniz bir adıma '
          'geri dönebilirsiniz.',
      'Müşteri arama alanı ekran açılır açılmaz hazır geliyor: telefon elinizdeyken '
          'doğrudan yazmaya başlayabilirsiniz.',
    ],
  ),
  // 0.14.1 KAYDI BİLEREK YOK. O numara `test` kanalına İKİ KEZ, İKİ FARKLI İÇERİKLE çıktı
  // (21:52 ve 22:38 koşumları) — yani "0.14.1'de ne vardı?" sorusunun tek bir cevabı yok.
  // Uydurma bir kayıt yazmak, listeyi olmayan bir kesinlikle doldurmak olurdu; içeriği bu
  // sürümde toplandı.
  SurumNotu(
    surum: '0.14.0',
    tarih: '11 Ağustos 2026',
    maddeler: [
      'Giriş ekranında parolanın yanındaki göz simgesine dokunarak yazdığınızı '
          'görebilirsiniz.',
      '"Beni hatırla" eklendi: işaretlerseniz firma kodunuz ve kullanıcı adınız bir '
          'sonraki girişte hazır gelir. Parolanız kaydedilmez, onu her seferinde siz '
          'yazarsınız.',
      'Yeni sürüm bildirimi sadeleşti — artık sadece sürüm numarasını gösteriyor.',
      'Bu ekran eklendi: Ayarlar → Hakkında → Yenilikler. Her güncellemede neyin '
          'değiştiğini buradan okuyabilirsiniz.',
    ],
  ),
  SurumNotu(
    surum: '0.13.0',
    tarih: '11 Ağustos 2026',
    maddeler: [
      'Kurye gün özetinde artık yalnız kendi teslimat ve tahsilatlarını görüyor; '
          'dükkânın geneli yalnız yöneticide.',
      'Gün özetindeki Nakit / Kart / Havale satırlarına dokununca o günün dökümü açılıyor.',
      '"Günün Teslimatları" listesi eklendi: müşteri, adres, saat ve tutar bir arada.',
      'Gün hesabını yalnız işletme sahibi kapatıyor. Kurye gün içinde nakit teslim etmeye '
          '(ara tahsilat) devam ediyor.',
    ],
  ),
  SurumNotu(
    surum: '0.12.0',
    tarih: '11 Ağustos 2026',
    maddeler: [
      'Müşterinin favori ürünlerini işaretleyebiliyorsunuz; sipariş açarken tek dokunuşla '
          'ekleniyorlar.',
      'Sipariş satırına not yazılabiliyor ("buzlu olsun" gibi) — kurye kapıda görüyor.',
      'Ürün birimi artık listeden seçiliyor. Elle yazdığınız eski birimler olduğu gibi '
          'korunur.',
      'Açık siparişi olan müşteriye yeni sipariş açarken uyarı çıkıyor; isterseniz devam '
          'edebilirsiniz.',
      'Müşteri kartındaki geçmiş son 3 siparişi gösteriyor, tamamı ayrı ekranda.',
    ],
  ),
  SurumNotu(
    surum: '0.11.0',
    tarih: '10 Ağustos 2026',
    maddeler: [
      'Kurye yetkileri artık kişiye özel: her kuryeye ayrı ayrı izin verebiliyorsunuz.',
      'Dokunmadığınız yetkiler işletme ayarınızı izlemeye devam eder — yeni kurye eklerken '
          'tek tek ayar yapmanız gerekmez.',
      'Ayarlar → Hakkında bölümünde sunucu sürümü görünüyor.',
    ],
  ),
  SurumNotu(
    surum: '0.10.0',
    tarih: '9 Ağustos 2026',
    maddeler: [
      'Uygulama artık kendi sürüm numarasını taşıyor; Ayarlar → Sürüm satırından '
          'görebilirsiniz.',
      'Güncellemeler yalnız yayınlanmış sürümlerden geliyor. Denenmemiş test derlemeleri '
          'artık telefonunuza inmiyor.',
    ],
  ),
  SurumNotu(
    surum: '0.9.0',
    tarih: '28 Temmuz 2026',
    maddeler: [
      'Uygulama içi güncelleme: yeni sürüm çıktığında ekranın üstünde bir bant beliriyor, '
          'dokununca kuruluyor.',
      'İşinizi bölmüyor — hazır olduğunuzda dokunursunuz.',
    ],
  ),
];

/// [surum] için not kaydı; yoksa null. Ekrandan BAĞIMSIZ (saf testle sınanır).
///
/// [surum] cihazdan `package_info_plus` ile okunur ve orada yapı numarası ("0.14.0 (412)")
/// ya da boşluk bulunabilir — bu yüzden kırpılır ve İLK BOŞLUKTAN önceki parça alınır.
/// Eşleşmezse null döner ve ekran hiçbir kaydı "şu anki" diye işaretlemez: yanlış sürümü
/// işaretlemektense hiçbirini işaretlememek doğrudur.
SurumNotu? surumNotuBul(String? surum) {
  final s = (surum ?? '').trim().split(' ').first;
  if (s.isEmpty) return null;
  for (final n in kSurumNotlari) {
    if (n.surum == s) return n;
  }
  return null;
}
