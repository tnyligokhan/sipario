import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// CİHAZ LİSTESİ istemcisi — `GET /devices`.
///
/// NEDEN VAR (kullanıcı eleştirisi 2026-08-13): "Hesabım sayfasının varlık amacı ne, hiçbir şeye
/// yaramıyor." Haklıydı — sayfa kullanıcının adını ve rolünü yazıp duruyordu, yani çekmecenin
/// başlığında zaten yazan şeyi. Bir hesap sayfasının cevapladığı asıl soru şudur ve ürün bunu
/// hiçbir yerde cevaplamıyordu: **hesabım hangi telefonlarda açık?**
///
/// NEDEN SENKRONA GİRMEZ: cihaz listesi bir İŞ KAYDI DEĞİLDİR, sunucunun anlık gerçeğidir.
/// Outbox'a alıp çevrimdışı önbelleklemek, "eski telefonum listede yok" gibi YANLIŞ bir güvenlik
/// izlenimi üretirdi — güvenlik ekranı bayat veriyle konuşamaz. Bu yüzden liste çevrimiçi
/// okunur ve ağ yoksa ekran bunu AÇIKÇA söyler (boş liste göstermez).
class CihazApi {
  CihazApi({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  /// Bayinin kayıtlı cihazları — sunucu `last_seen_at` azalan sırada döner (RLS zorlar:
  /// başka bayinin cihazı bu listeye ASLA giremez).
  Future<List<Cihaz>> listele() async {
    final http.Response resp;
    try {
      resp = await _client.get(
        Uri.parse('$baseUrl/devices'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));
    } on Exception {
      throw CihazApiException('İnternete ulaşılamadı — cihaz listesi çevrimiçi okunur.');
    }

    if (resp.statusCode != 200) {
      throw CihazApiException('Cihaz listesi alınamadı (HTTP ${resp.statusCode}).');
    }

    final govde = jsonDecode(resp.body);
    // Laravel Resource koleksiyonu `{"data": [...]}` sarar; sarmalayıcısız gövde de kabul
    // edilir — sunucu biçimi değişirse ekran boş kalmasın, veri neredeyse oradan okunsun.
    final liste = govde is Map ? govde['data'] : govde;
    if (liste is! List) return const [];
    return liste.whereType<Map>().map((m) => Cihaz.jsondan(m.cast<String, dynamic>())).toList();
  }

  /// PUSH JETONUNU SUNUCUYA BİLDİRİR (`POST /devices`, idempotent upsert).
  ///
  /// NEDEN GİRİŞTEKİ CİHAZ BLOĞU YETMEZ: FCM jetonu girişten SONRA gelir (Play Services'ten
  /// asenkron) ve ömrü boyunca YENİLENİR — uygulama verisi temizlenince, cihaz geri
  /// yüklenince, Google jetonu döndürünce. Yalnız girişte gönderseydik, jeton yenilendiği
  /// gün bildirimler sessizce kesilir ve kimse sebebini bilemezdi.
  ///
  /// SESSİZ BAŞARISIZLIK BİLİNÇLİ (`bool` döner, atmaz): jeton bildirimi bir iş akışı
  /// değildir. Ağ yoksa bildirilemez; sonraki açılışta yeniden denenir. Bu yüzden çağıran
  /// tarafın hata göstermesi GEREKMEZ — göstermesi, esnafa anlamı olmayan bir uyarı olurdu.
  Future<bool> jetonBildir({
    required String cihazId,
    required String platform,
    required String jeton,
  }) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/devices'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'device_id': cihazId,
              'platform': platform,
              'push_token': jeton,
            }),
          )
          .timeout(const Duration(seconds: 20));

      return resp.statusCode == 200 || resp.statusCode == 201;
    } on Exception catch (e) {
      // Jeton DEĞERİ loglanmaz: cihazın bildirim adresidir, sızarsa üçüncü taraf o telefona
      // bildirim gönderebilir.
      debugPrint('Push jetonu bildirilemedi: ${e.runtimeType}');
      return false;
    }
  }
}

/// Sunucudan gelen tek cihaz kaydı.
class Cihaz {
  const Cihaz({
    required this.id,
    required this.platform,
    required this.model,
    required this.uygulamaSurumu,
    required this.sonGorulme,
  });

  factory Cihaz.jsondan(Map<String, dynamic> m) => Cihaz(
        id: '${m['id'] ?? ''}',
        platform: _metin(m['platform']),
        model: _metin(m['model']),
        uygulamaSurumu: _metin(m['app_version']),
        sonGorulme: DateTime.tryParse('${m['last_seen_at'] ?? ''}')?.toLocal(),
      );

  final String id;
  final String? platform;
  final String? model;
  final String? uygulamaSurumu;
  final DateTime? sonGorulme;

  /// Ekranda okunan ad: model varsa model, yoksa platform, o da yoksa dürüst bir yer tutucu.
  /// KİMLİK UYDURULMAZ — "Cihaz" diye bir başlık, bayiye tanımadığı bir telefonu tanıdık gösterir.
  String get ad => model ?? platform ?? 'Model bilinmiyor';

  static String? _metin(Object? v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }
}

class CihazApiException implements Exception {
  CihazApiException(this.mesaj);
  final String mesaj;

  @override
  String toString() => mesaj;
}
