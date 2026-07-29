import 'dart:convert';

import 'package:http/http.dart' as http;

/// "Oto Sırala (rota)" istemcisi — tasarım `s-siparisler.jsx` sıralama sayfasındaki
/// kontörlü eylem (`POST /orders/auto-route`).
///
/// NEDEN SENKRONDAN AYRI: bu çağrı bir SIRA ÖNERİSİ ister, kayıt yazmaz. Dönen sırayı
/// siparişlere yazma işini yine `OrderRepository` + outbox (`sort_set` olayı) yapar; tek
/// yazma yüzeyi kuralı korunur. Kontör sunucu sahiplidir, istemci düşüremez.
///
/// ÇEVRİMDIŞI: bu tek çevrimİÇİ eylemdir. Ağ yoksa kullanıcıya söylenir ve mevcut sıra
/// korunur — elle sıralama her koşulda çevrimdışı çalışmaya devam eder.
class RouteApi {
  RouteApi({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  /// [baslangic] verilirse rota KURYENİN BULUNDUĞU noktadan başlar (`start`). Verilmezse gövdeye
  /// hiç yazılmaz ve sunucu eski davranışını sürdürür (ilk duraktan sıralar) — alan opsiyoneldir,
  /// çünkü konum her zaman alınamaz ve alınamadığında sıralamayı hiç yapmamak daha kötüdür.
  Future<AutoRouteResult> autoRoute(
    List<String> orderIds, {
    ({double lat, double lng})? baslangic,
  }) async {
    final http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('$baseUrl/orders/auto-route'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'order_ids': orderIds,
              if (baslangic != null)
                'start': {'lat': baslangic.lat, 'lng': baslangic.lng},
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw RouteException('Sunucuya ulaşılamadı — sıra değişmedi.');
    }

    final body = _decode(resp.body);
    if (resp.statusCode != 200) {
      final mesaj = body['message'];
      throw RouteException(
        mesaj is String && mesaj.isNotEmpty
            ? mesaj
            : 'Oto sıralama yapılamadı (HTTP ${resp.statusCode}).',
        // 409 = hak bitti; çağıran bunu ayırt edip kalan hakkı sıfırlayabilsin.
        kalanHak: (body['route_credits'] as num?)?.toInt(),
      );
    }

    // Sunucu ayrıca hangi motorun sıraladığını (`engine`) bildirebilir; İSTEMCİ BUNU OKUMAZ.
    // Sözleşmeye almak, alanı göndermeyen eski sunucuya karşı gereksiz bir dallanma üretirdi ve
    // kullanıcıya söylenecek bir şey değil (rota rotadır, motoru onun işi değil).
    return AutoRouteResult(
      sira: ((body['order'] as List?) ?? const []).cast<String>(),
      konumsuz: (body['without_location'] as num?)?.toInt() ?? 0,
      kalanHak: (body['route_credits'] as num?)?.toInt() ?? 0,
    );
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

/// Ekranların rota istemcisini kurduğu TEK dikiş (`adresAdaylariGetir` deseninin aynısı).
/// Widget testleri bunu sahtesiyle değiştirir — `http.Client` ekranın içine gömülmez ve test
/// ağa ASLA çıkmaz.
RouteApi Function(String baseUrl, String token) rotaApiUret =
    (baseUrl, token) => RouteApi(baseUrl: baseUrl, token: token);

class AutoRouteResult {
  AutoRouteResult({required this.sira, required this.konumsuz, required this.kalanHak});

  /// Sipariş kimlikleri, rota sırasında. Koordinatı olmayanlar SONDA (göreli sıraları korunur).
  final List<String> sira;

  /// Koordinatı olmadığı için rotaya giremeyen sipariş sayısı — kullanıcıya söylenir,
  /// çünkü "sıraladım" deyip bazılarını sona atmak sessiz bir yalan olurdu.
  final int konumsuz;

  final int kalanHak;
}

/// Kullanıcıya gösterilebilir rota hatası. Sunucunun nötr `message` alanı aynen taşınır.
class RouteException implements Exception {
  RouteException(this.message, {this.kalanHak});
  final String message;

  /// Sunucu bildirdiyse güncel hak (409'da 0). Bilinmiyorsa null.
  final int? kalanHak;

  @override
  String toString() => message;
}
