// API HATA METNİ — sunucudan dönen başarısız yanıtın KULLANICI CÜMLESİNE tek çevirisi
// (kullanıcı isteği 2026-09-29: "uygulamalarda sunucu bilgisi hiçbir koşulda geçmemeli").
//
// ══ NEDEN VAR ═══════════════════════════════════════════════════════════════════════════════
// Her API istemcisi kendi hata cümlesini kuruyordu ve üç ayrı sızıntı yolu vardı:
//   • "(kod 502)" gibi HTTP durum kodları metnin sonuna ekleniyordu,
//   • sunucunun `message` alanı SÜZÜLMEDEN taşınıyordu — 5xx, 429 ve 401'de bu alan Laravel'in
//     İngilizce varsayılanıdır ("Server Error", "Too Many Attempts.", "Unauthenticated."),
//   • bağlantı hatası "Sunucuya ulaşılamadı" diye anlatılıyordu; bayi için sunucu diye bir şey
//     yoktur, internet vardır ya da yoktur.
//
// ══ SÖZLEŞME ════════════════════════════════════════════════════════════════════════════════
// Sunucunun kendi cümlesi YALNIZ çağıranın güvendiği durum kodlarında ([guvenilen]) ve yalnız
// Türkçe yazılmışsa kullanılır. Geri kalan her durumda metni bu sınıf kurar: önce ne
// yapılamadığı ([eylem]), sonra kullanıcının ne yapacağı. Kod, adres, teknik terim GEÇMEZ.

/// Başarısız bir API yanıtını kullanıcıya gösterilecek metne çevirir.
class ApiHataMetni {
  const ApiHataMetni(this.eylem, {this.guvenilen = const {409, 422}});

  /// Yapılamayan işin kısa adı, noktasız: "Adres araması yapılamadı".
  final String eylem;

  /// Sunucunun `message` alanının aynen gösterilebileceği durum kodları. Bu kodlarda yanıtı
  /// bizim denetleyicilerimiz yazar ve metin Türkçedir; diğerlerinde çerçeve yazar.
  final Set<int> guvenilen;

  /// Bağlantı kurulamadığında (zaman aşımı, DNS, uçak modu) gösterilecek metin.
  static const baglantiYok =
      'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edip tekrar deneyin.';

  /// Oturum jetonu geçersiz (401).
  static const oturumBitti = 'Oturumunuzun süresi doldu. Çıkış yapıp yeniden giriş yapın.';

  /// Hız sınırı (429).
  static const cokFazlaDeneme = 'Çok fazla deneme yapıldı. Bir dakika bekleyip tekrar deneyin.';

  /// [durum] kodlu yanıtın metni. [govde] çözülmüş JSON gövdesidir (çözülemediyse boş harita).
  String yanit(int durum, Map<String, dynamic> govde) {
    if (guvenilen.contains(durum)) {
      final sunucu = _sunucuCumlesi(govde);
      if (sunucu != null) return sunucu;
    }
    if (durum == 401) return oturumBitti;
    if (durum == 429) return cokFazlaDeneme;
    if (durum == 403) return '$eylem. Bu işlem için yetkiniz yok.';
    if (durum >= 500) {
      return '$eylem. Geçici bir aksaklık var, birkaç dakika sonra tekrar deneyin.';
    }
    return '$eylem. Birkaç dakika sonra tekrar deneyin.';
  }

  /// Gövdedeki gösterilebilir cümle: önce doğrulama hatalarının ilki, sonra `message`.
  static String? _sunucuCumlesi(Map<String, dynamic> govde) {
    final hatalar = govde['errors'];
    if (hatalar is Map && hatalar.isNotEmpty) {
      final ilk = hatalar.values.first;
      if (ilk is List && ilk.isNotEmpty && gosterilebilirMi('${ilk.first}')) {
        return _tekCumleNoktasiz('${ilk.first}'.trim());
      }
    }
    final mesaj = govde['message'];
    return mesaj is String && gosterilebilirMi(mesaj) ? _tekCumleNoktasiz(mesaj.trim()) : null;
  }

  /// Uygulamanın yazım kuralı: tek cümlelik kısa metin nokta ALMAZ. Sunucu cümlesi noktayla
  /// biter ("Parola hatalı."); iki cümleliyse noktalama olduğu gibi kalır.
  static String _tekCumleNoktasiz(String m) {
    if (!m.endsWith('.')) return m;
    final govde = m.substring(0, m.length - 1);
    return govde.contains('. ') ? m : govde;
  }

  /// Sunucu cümlesi kullanıcıya gösterilebilir mi? Boş değil, Türkçe (en az bir Türkçe harf
  /// taşıyor — çerçevenin İngilizce varsayılanları taşımaz) ve adres ya da yol içermiyor.
  static bool gosterilebilirMi(String metin) {
    final m = metin.trim();
    if (m.isEmpty) return false;
    if (m.contains('://') || m.contains('/api') || m.contains('SQLSTATE')) return false;
    return RegExp('[çğıöşüÇĞİÖŞÜ]').hasMatch(m);
  }
}
