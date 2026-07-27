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

/// Çağrı kartında gösterilen kişi. `musteriId` null ise numara kayıtsızdır ve kart
/// "Müşteri Olarak Kaydet" varyantına düşer.
class CagriKisi {
  const CagriKisi({
    required this.numara,
    this.musteriId,
    this.ad,
    this.bakiyeKurus = 0,
    this.adres,
    this.bolge,
    this.konumVar = false,
    this.not,
    this.sonHareket,
    this.sonHareketTuru = SonHareketTuru.siparis,
  });

  /// Kayıtsız numara için kısayol.
  const CagriKisi.kayitsiz(this.numara)
      : musteriId = null,
        ad = null,
        bakiyeKurus = 0,
        adres = null,
        bolge = null,
        konumVar = false,
        not = null,
        sonHareket = null,
        sonHareketTuru = SonHareketTuru.siparis;

  /// Ham numara (gösterim için `sipTelefon` ile biçimlenir).
  final String numara;

  final String? musteriId;
  final String? ad;

  /// Pozitif = müşterinin borcu · negatif = alacağı · 0 = temiz. Daima int kuruş.
  final int bakiyeKurus;

  final String? adres;
  final String? bolge;

  /// Adresin kayıtlı konumu var mı (tasarımda adres satırındaki yeşil onay).
  final bool konumVar;

  /// Müşteri notu — kartta sarı zeminli uyarı satırında gösterilir.
  final String? not;

  /// "Son sipariş: … · 10:24" gibi hazır tek satır özet. Kartın 1 saniyelik bütçesi
  /// olduğu için burada hesap YAPILMAZ; metni çağıran hazırlar.
  final String? sonHareket;

  /// [sonHareket] satırının ikonu.
  final SonHareketTuru sonHareketTuru;

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
