import 'dart:convert';

import 'package:http/http.dart' as http;

/// "Adresten Konum Al" istemcisi — serbest adres metnini ADAY koordinatlara çevirir
/// (`POST /geocode`).
///
/// NEDEN SUNUCUDAN GEÇER (doğrudan Yandex/Google'a gidilmiyor): sağlayıcı anahtarı APK'ya
/// gömülseydi ilk kurulumda çıkarılır ve kotamız yakılırdı. Sunucu ayrıca aynı adresi ikinci kez
/// sormaz (önbellek) ve sağlayıcı değişimi bir env satırı olur — uygulama güncellemesi değil.
///
/// ÇEVRİMDIŞI: bu tek çevrimİÇİ KOLAYLIKTIR. Ağ yoksa müşteri konumsuz kaydedilir ve kayıt akışı
/// hiç engellenmez (kırmızı çizgi #3); konum sonradan eklenir.
class GeocodeApi {
  GeocodeApi({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  /// [adres] serbest metin, [bolge] varsa ipucu. Bulunamadıysa BOŞ LİSTE döner (istisna değil) —
  /// "bu adres bulunamadı" normal bir sonuçtur ve kullanıcı metnini düzeltip tekrar dener.
  Future<List<GeoAday>> ara(String adres, {String? bolge}) async {
    final http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('$baseUrl/geocode'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'query': adres,
              if (bolge != null && bolge.trim().isNotEmpty) 'region': bolge.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw GeocodeException('İnternete ulaşılamadı. Konumu sonra alabilirsiniz.');
    }

    final body = _decode(resp.body);
    if (resp.statusCode != 200) {
      final mesaj = body['message'];
      throw GeocodeException(
        mesaj is String && mesaj.isNotEmpty
            ? mesaj
            : 'Adres araması yapılamadı (kod ${resp.statusCode}).',
      );
    }

    return [
      for (final ham in (body['results'] as List?) ?? const []) ?GeoAday.ayristir(ham),
    ];
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final v = jsonDecode(body);
      return v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }
}

/// Sunucudan gelen tek aday. Sağlayıcıdan bağımsız biçim — Yandex de Google da buna çevrilir,
/// bu yüzden sağlayıcı değişince bu dosya değişmez.
class GeoAday {
  const GeoAday({
    required this.metin,
    required this.lat,
    required this.lng,
    required this.kesinlik,
    this.kaynak = '',
  });

  final String metin;
  final double lat;
  final double lng;

  /// 'bina' | 'sokak' | 'semt'. Kurye için fark yaratır: sokak kesinliği "kapıyı bulamayabilir"
  /// demektir, kullanıcı adayı seçerken bunu görmeli.
  final String kesinlik;

  /// Adayı hangi sağlayıcının bulduğu: 'yandex' | 'google' | ''. Kademeli sunucu sürücüsü
  /// her adayı kendi sağlayıcı etiketiyle gönderir; kullanıcı "Google şunu, Yandex bunu buldu"
  /// diye görüp doğrusunu seçer. Eski sunucular bu alanı hiç göndermez; o yüzden boş varsayılan
  /// ve alan YOKSA satır sessizce eski gibi çizilir.
  final String kaynak;

  /// Tek kaydı çözer; alanı eksik/bozuksa null döner. Tek bozuk kayıt yüzünden bütün listeyi
  /// düşürmek kullanıcıyı boş yere adressiz bırakırdı.
  static GeoAday? ayristir(Object? ham) {
    if (ham is! Map) return null;
    final metin = ham['text'];
    final lat = ham['lat'];
    final lng = ham['lng'];
    if (metin is! String || metin.isEmpty || lat is! num || lng is! num) return null;
    final kesinlik = ham['precision'];
    final kaynak = ham['source'];
    return GeoAday(
      metin: metin,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      kesinlik: kesinlik is String ? kesinlik : 'semt',
      kaynak: kaynak is String ? kaynak : '',
    );
  }
}

/// Kullanıcıya gösterilebilir adres arama hatası. Sunucunun nötr `message` alanı aynen taşınır.
class GeocodeException implements Exception {
  GeocodeException(this.message);

  final String message;

  @override
  String toString() => message;
}
