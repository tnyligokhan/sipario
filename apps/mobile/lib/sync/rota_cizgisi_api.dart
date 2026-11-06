// YOL ÇİZGİSİ istemcisi — `POST /rota/cizgi` (2026-09-29).
//
// Haritadaki durakları GERÇEK YOLLARDAN bağlayan çizgiyi sunucudan ister. Sunucu Google'a
// yalnız koordinat gönderir, sonucu önbelleğe alır; telefonda anahtar YOKTUR.
//
// ASLA FIRLATMAZ: her arıza (ağ yok, 503 = servis kapalı, bozuk gövde) `null` döner ve harita
// kuş uçuşu kesikli çizgiye düşer. Yol çizgisi bir kolaylıktır; yokluğu haritayı kırmamalı.
//
// KVKK: bu dosyada koordinat LOGLANMAZ.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../screens/orders/harita_icerigi.dart';

/// Sunucunun döndürdüğü çizgi + çizginin dayandığı durak koordinatları.
class RotaCizgisi {
  const RotaCizgisi({required this.noktalar, required this.duraklar});

  /// Yolun noktaları, sırasıyla.
  final List<HaritaNoktasi> noktalar;

  /// Sunucunun çizgiyi kurduğu durak koordinatları (istenen sırayla, konumsuzlar hariç).
  /// İstemci bunları kendi pinleriyle karşılaştırır: senkronlanmamış bir konum değişikliği
  /// varsa çizgi YANLIŞ kapıya gider — o durumda çizgi kullanılmaz.
  final List<HaritaNoktasi> duraklar;

  /// Gövdeyi çözer; sözleşme dışı gövde `null` (düz çizgiye düşülür).
  static RotaCizgisi? fromJson(Object? j) {
    if (j is! Map) return null;
    final noktalar = _noktalar(j['noktalar']);
    final duraklar = _noktalar(j['duraklar']);
    if (noktalar == null || duraklar == null) return null;
    return RotaCizgisi(noktalar: noktalar, duraklar: duraklar);
  }

  static List<HaritaNoktasi>? _noktalar(Object? ham) {
    if (ham is! List) return null;
    final sonuc = <HaritaNoktasi>[];
    for (final n in ham) {
      if (n is! List || n.length != 2 || n[0] is! num || n[1] is! num) return null;
      final lat = (n[0] as num).toDouble(), lng = (n[1] as num).toDouble();
      // Aralık dışı tek nokta bütün çizgiyi şüpheli kılar — kısmen doğru bir yol çizmek,
      // hiç çizmemekten kötüdür.
      if (lat.abs() > 90 || lng.abs() > 180) return null;
      sonuc.add(HaritaNoktasi(lat, lng));
    }
    return sonuc;
  }
}

class RotaCizgisiApi {
  RotaCizgisiApi({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  /// Sipariş kimlikleri GÖRÜNEN SIRAYLA. Arızada `null`.
  Future<RotaCizgisi?> cizgi(List<String> siparisIdleri) async {
    if (siparisIdleri.length < 2) return null;
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/rota/cizgi'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'order_ids': siparisIdleri}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      return RotaCizgisi.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
    } on Object {
      return null;
    }
  }
}

/// İstemcinin TEK dikişi (`konumApiUret` deseni). Testler sahtesiyle değiştirir; ağa çıkmaz.
RotaCizgisiApi Function(String baseUrl, String token) rotaCizgisiApiUret =
    (baseUrl, token) => RotaCizgisiApi(baseUrl: baseUrl, token: token);
