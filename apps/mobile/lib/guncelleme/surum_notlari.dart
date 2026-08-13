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
