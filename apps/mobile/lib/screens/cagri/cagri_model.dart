// Çağrı kartı ve çağrı günlüğünün veri modeli.
// Tasarım kaynağı: tasarım s-cagri.jsx (kart) + s-veri.jsx `ARAMALAR` (günlük).
//
// Bu dosya `lib/data` / `lib/repo` katmanına BİLEREK bağlı değildir: çağrı kartı gerçek
// cihazda saf Kotlin'le çizilir, Flutter karşılığı ise hem canlı veriyle hem de Ayarlar'daki
// simülasyonla beslenir. Ekranın tek bildiği bu düz modellerdir; repo'ya çeviriyi çağıran yapar.

/// Arama yönü — s-veri.jsx `ARAMALAR[].tip`.
enum AramaTipi { gelen, cevapsiz, giden }

/// Kartın "son hareket" satırının hangi ikonla çizileceği (s-cagri.jsx: sipariş varsa kutu
/// ikonu, yoksa defter ikonu).
enum SonHareketTuru { siparis, defter }

/// Depodan gelen metni enum'a çevirir. Tanınmayan değer [AramaTipi.gelen] sayılır:
/// çağrı günlüğü bir satırı hiç göstermemektense yanlış ikonla göstermeyi tercih eder.
AramaTipi aramaTipiCoz(String? ham) => switch (ham) {
      'cevapsiz' || 'missed' => AramaTipi.cevapsiz,
      'giden' || 'out' || 'outgoing' => AramaTipi.giden,
      _ => AramaTipi.gelen,
    };

/// Çağrı günlüğü satırındaki yön sözcüğü ("Son Aramalar" listesi).
String aramaTipiSozcugu(AramaTipi tip) => switch (tip) {
      AramaTipi.gelen => 'Gelen',
      AramaTipi.giden => 'Giden',
      AramaTipi.cevapsiz => 'Cevapsız',
    };

/// Kartın üst şeridindeki yön etiketi — native `CagriYonu.etiket` aynası.
///
/// Buraya kadar gelmesi ZORUNLU: şerit "GELEN ÇAĞRI"yı sabit yazdığı sürece bayi kendi
/// aradığı müşteride de gelen çağrı görüyordu (2026-07-27 saha bulgusu).
String cagriYonEtiketi(AramaTipi tip) => switch (tip) {
      AramaTipi.gelen => 'GELEN ÇAĞRI',
      AramaTipi.giden => 'GİDEN ÇAĞRI',
      AramaTipi.cevapsiz => 'CEVAPSIZ ÇAĞRI',
    };

/// Siparişin kartta okunan durumu. `orders.status` (`open|delivered|cancelled`) + kurye
/// ataması → tek sözcük. Native karttaki `CallerCard.siparisDurumEtiketi` ile AYNI eşleme;
/// iki kart aynı siparişte aynı sözcüğü yazmalı.
///
/// "Yolda", AÇIK bir siparişin kuryeye atanmış olmasıdır (DECISIONS: `assigned_user_id` bir
/// önbellektir, kaynağı atama olaylarıdır). Liste rozetindeki kısaltmalar (Açık/Teslim/İptal)
/// kullanılmaz: kart bir cümle okur, rozet değil.
String siparisDurumEtiketi(String durum, {bool kuryede = false}) => switch (durum) {
      'delivered' => 'Teslim edildi',
      'cancelled' => 'İptal edildi',
      _ => kuryede ? 'Yolda' : 'Hazırlanıyor',
    };

/// Sipariş hâlâ bekliyor mu ("Hazırlanıyor"/"Yolda"). Kapanmış durumların dışında kalan her
/// şey açıktır — tanınmayan `status` değeri de (kart bir siparişi yok saymaktansa açık sayar).
/// Native `CallerCard.siparisAcikMi` aynası.
bool siparisAcikMi(String durum) => durum != 'delivered' && durum != 'cancelled';

/// Numaranın son 10 hanesi. Türkiye'de aynı hat +905321234567 / 05321234567 / 5321234567
/// biçimlerinde gelir; son 10 hane üçünde de aynıdır ve ülke içinde tekildir. Eşleşmenin
/// TAMAMI (müşteri arama, muaf listesi) buna dayanır — native taraftaki `phone_last10` ile
/// aynı kural (CustomerLookup.last10).
String sonOnHane(String ham) {
  final haneler = ham.replaceAll(RegExp(r'\D'), '');
  return haneler.length >= 10
      ? haneler.substring(haneler.length - 10)
      : haneler;
}

/// Numara muaf listesinde mi? Muaf numaralarda çağrı kartı HİÇ gösterilmez
/// (s-uygulama.jsx: `muaflar.some((m) => son10(m.no) === son10(cagri))`).
///
/// 10 haneden kısa girdi (gizli numara, kısa servis numarası) hiçbir zaman muaf sayılmaz —
/// aksi halde boş numara boş muaf kaydıyla eşleşip kartı susturabilirdi.
bool numaraMuafMi(String numara, Iterable<String> muafNumaralar) {
  final anahtar = sonOnHane(numara);
  if (anahtar.length < 10) return false;
  return muafNumaralar.any((m) => sonOnHane(m) == anahtar);
}

/// Çağrı saatinin liste gösterimi ("10:24" · "Dün") — ana ekrandaki "Son Arama" bento
/// kutusu bunu `s-ana.jsx:48`'de `<span className="tabular">{saat}</span>` olarak basar.
///
/// Depoda ISO8601 UTC durur; burada CİHAZ SAATİNE çevrilir — bayi "10:24"ü kendi saatiyle
/// okur. Bugün ise saat, dün ise "Dün", bu hafta ise gün adı, öncesi ise gün.ay.
/// [simdi] yalnız test içindir; verilmezse şimdiki zaman.
///
/// AÇIK siparişin satırı bunu değil [cagriSiparisZamanMetni]'ni yazar (yaş).
String cagriSaatMetni(DateTime? an, {DateTime? simdi}) {
  if (an == null) return '';
  final yerel = an.toLocal();
  final ref = (simdi ?? DateTime.now()).toLocal();
  final gun = DateTime(yerel.year, yerel.month, yerel.day);
  final bugun = DateTime(ref.year, ref.month, ref.day);
  final fark = bugun.difference(gun).inDays;

  String iki(int n) => n.toString().padLeft(2, '0');
  if (fark == 0) return '${iki(yerel.hour)}:${iki(yerel.minute)}';
  if (fark == 1) return 'Dün';
  // İleri tarihli kayıt (cihaz saati geri alınmış) saat gibi gösterilir; "-3 gün" saçmalığı
  // yerine en az yanıltıcı olan bu.
  if (fark < 0) return '${iki(yerel.hour)}:${iki(yerel.minute)}';
  if (fark < 7) return _gunAdlari[yerel.weekday - 1];
  return '${iki(yerel.day)}.${iki(yerel.month)}';
}

const List<String> _gunAdlari = [
  'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz',
];

/// Son sipariş satırının zaman parçası. AÇIK siparişte mutlak saat değil YAŞ yazar
/// ("23 dk önce"), kapanmış siparişte [cagriSaatMetni] davranışı aynen sürer.
///
/// Kullanıcı isteği (2026-07-30): kart "Son sipariş: Hazırlanıyor · 10:24" yazıyordu; bayi
/// telefonda "ne zamandır bekliyor" sorusuna cevap verirken saati zihninden çıkarmak zorunda
/// kalıyordu. Açık siparişin sorusu SÜREDİR, saat değil. Teslim/iptal edilmiş siparişte soru
/// yeniden "ne zamandı"ya döner — orada saat kalır.
///
/// Sözcükler `order_queries.gecenSure` ("12 dk" · "1 sa 5 dk") ile AYNI, sonuna " önce"
/// eklenmiştir: sipariş listesindeki bekleme süresi ile kart aynı siparişte aynı sayıyı aynı
/// sözcüklerle söyler. 1 dakikadan yeni sipariş "az önce"dir (`kuryeSonGorulme`nin sözcüğü);
/// "0 dk önce" siparişin henüz girilmediğini düşündürürdü.
///
/// 24 saati geçen açık siparişte dakika gürültüdür ve satır uzar; orada [cagriSaatMetni]
/// devralır (Dün · gün adı · gün.ay).
///
/// İLERİ tarihli damga (cihaz saati geri alınmış) "az önce" sayılır — "−3 dk önce" yazmak
/// veriye güveni sarsar; [cagriSaatMetni]'nin negatif gün farkındaki duruşunun aynısı.
///
/// Native `CallerCard.siparisZamanMetni` ile AYNI kurallar: zil anındaki Kotlin kartı ile
/// buradaki Flutter kartı aynı siparişte aynı metni yazmak ZORUNDA (biri overlay'de, öteki
/// uygulama önplandayken çizilir; farklı metin bayiye iki ayrı gerçek gösterirdi).
/// [simdi] yalnız test içindir.
String cagriSiparisZamanMetni(
  DateTime? an, {
  required bool acik,
  DateTime? simdi,
}) {
  if (an == null) return '';
  if (!acik) return cagriSaatMetni(an, simdi: simdi);

  final ref = simdi ?? DateTime.now();
  final fark = ref.toLocal().difference(an.toLocal());
  if (fark.inMinutes < 1) return 'az önce';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
  if (fark.inHours < 24) {
    final dk = fark.inMinutes % 60;
    return dk == 0 ? '${fark.inHours} sa önce' : '${fark.inHours} sa $dk dk önce';
  }
  return cagriSaatMetni(an, simdi: simdi);
}

/// Çağrı kartında gösterilen kişi. `musteriId` null ise numara kayıtsızdır ve kart
/// "Müşteri Olarak Kaydet" varyantına düşer.
class CagriKisi {
  const CagriKisi({
    required this.numara,
    this.musteriId,
    this.ad,
    this.bakiyeKurus = 0,
    this.adres,
    this.konumVar = false,
    this.not,
    this.sonHareket,
    this.sonHareketTuru = SonHareketTuru.siparis,
    this.sonSiparisDurumu,
  });

  /// Kayıtsız numara için kısayol.
  const CagriKisi.kayitsiz(this.numara)
      : musteriId = null,
        ad = null,
        bakiyeKurus = 0,
        adres = null,
        konumVar = false,
        not = null,
        sonHareket = null,
        sonHareketTuru = SonHareketTuru.siparis,
        sonSiparisDurumu = null;

  /// Ham numara (gösterim için `sipTelefon` ile biçimlenir).
  final String numara;

  final String? musteriId;
  final String? ad;

  /// Pozitif = müşterinin borcu · negatif = alacağı · 0 = temiz. Daima int kuruş.
  final int bakiyeKurus;

  final String? adres;

  /// Adresin kayıtlı konumu var mı (tasarımda adres satırındaki yeşil onay).
  final bool konumVar;

  /// Müşteri notu — kartta sarı zeminli uyarı satırında gösterilir.
  final String? not;

  /// "Son sipariş: … · 10:24" gibi hazır tek satır özet. Kartın 1 saniyelik bütçesi
  /// olduğu için burada hesap YAPILMAZ; metni çağıran hazırlar.
  final String? sonHareket;

  /// [sonHareket] satırının ikonu.
  final SonHareketTuru sonHareketTuru;

  /// Son SİPARİŞİN durumu — "Hazırlanıyor" · "Yolda" · "Teslim edildi" · "İptal edildi".
  ///
  /// NEDEN AYRI ALAN (2026-07-27 saha bulgusu): kart "Son sipariş: Damacana ×2 · 10:24" yazıyor
  /// ama siparişin ne durumda olduğunu SÖYLEMİYORDU; bayi telefonda "yolda mı, çıktı mı"
  /// sorusuna cevap veremiyordu. Durum, hareket satırının sonunda rozet olarak durur —
  /// defter hareketinde (sipariş yoksa) null'dır, orada durum diye bir şey yoktur.
  final String? sonSiparisDurumu;

  bool get kayitli => musteriId != null;

  /// Tasarımdaki müşteri kodu rozeti (s-cagri.jsx: `'M-' + id.padStart(3,'0')`).
  String? get musteriKodu {
    final id = musteriId;
    if (id == null) return null;
    final haneler = id.replaceAll(RegExp(r'\D'), '');
    return 'M-${(haneler.isEmpty ? id : haneler).padLeft(3, '0')}';
  }
}

/// Çağrı günlüğü satırı — s-veri.jsx `ARAMALAR` dizisinin birebir karşılığı.
class AramaKaydi {
  const AramaKaydi({
    required this.id,
    required this.numara,
    required this.saat,
    required this.tip,
    this.musteriId,
    this.ad,
    this.sonuc,
  });

  final String id;

  /// Ham numara.
  final String numara;

  /// Gösterime hazır zaman ("10:24", "Dün"). Depoda ISO8601 durur, biçimlemeyi çağıran yapar.
  final String saat;

  final AramaTipi tip;

  /// Kayıtlıysa müşteri kimliği; değilse null (satır "kaydet" akışına gider).
  final String? musteriId;

  /// Kayıtlıysa müşteri adı; değilse null (satırda numara baskın gösterilir).
  final String? ad;

  /// "Sipariş alındı", "Kayıtsız numara" gibi sonuç notu.
  final String? sonuc;

  bool get kayitli => musteriId != null;
}
