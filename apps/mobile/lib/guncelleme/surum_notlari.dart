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
      'Ayarlar kategorilere ayrıldı: Hesap · İşletme · Uygulama · Bildirimler · Hakkında. '
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
      'Üstteki adım rozetlerine (Müşteri · Kalemler · Özet) dokunarak geçtiğiniz bir adıma '
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
