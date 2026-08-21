import 'dart:convert';

import 'package:http/http.dart' as http;

/// EKİP KİMLİK BİLGİLERİ istemcisi — kuryenin giriş adı/parolası
/// (`PATCH /team/{id}/credentials`, kullanıcı isteği 2026-08-04).
///
/// NEDEN OUTBOX/SENKRON DEĞİL: parola değişimi ÇEVRİMDIŞI ANLAMSIZDIR — doğrulama sunucudadır,
/// hash'i istemci üretemez ve iki cihazın çevrimdışı yazdığı iki parolayı LWW ile "birleştirmek"
/// güvenlik açısından saçmadır. Ayrıca kimlik yüzeyini offline kuyruğa açmak yetki yükseltme
/// vektörüdür (sunucu tarafında `ProfileChangeApplier` bu yüzden parola/rol yazmaz).
///
/// Bu, uygulamadaki SAYILI çevrimiçi-zorunlu işlemden biridir; çağıran ekran bunu kullanıcıya
/// söylemekle yükümlüdür (kırmızı çizgi #3 bir İŞ KAYDININ engellenmemesiyle ilgilidir — kimlik
/// yönetimi bir iş kaydı değildir).
class TeamApi {
  TeamApi({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  /// [username] ve/veya [password] gönderir; ikisi de null ise sunucu 422 döner (çağıran
  /// zaten en az birini doldurtur). Başarıda parola değiştiyse `true` döner — çağıran ekran
  /// "kuryenin açık oturumları kapandı" diyebilsin.
  Future<bool> kimlikGuncelle(
    String userId, {
    String? username,
    String? password,
  }) async {
    final http.Response resp;
    try {
      resp = await _client
          .patch(
            Uri.parse('$baseUrl/team/$userId/credentials'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              // Yalnız DEĞİŞEN alan gider: null "dokunma" demektir, boş dize değil.
              ...?(username == null ? null : {'username': username}),
              ...?(password == null ? null : {'password': password}),
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw TeamApiException('İnternete ulaşılamadı. Giriş bilgileri yalnız çevrimiçiyken değiştirilebilir.');
    }

    final body = _decode(resp.body);
    if (resp.statusCode == 200) {
      return body['sessions_revoked'] == true;
    }

    // 422'de alan hatalarını kullanıcıya AYNEN gösteriyoruz: sunucunun mesajı ("Bu kullanıcı adı
    // bu bayide zaten kullanılıyor") kendi yazacağımız genel bir cümleden daha yardımcı.
    final alanlar = body['errors'];
    if (alanlar is Map && alanlar.isNotEmpty) {
      final ilk = alanlar.values.first;
      if (ilk is List && ilk.isNotEmpty) throw TeamApiException('${ilk.first}');
    }
    final mesaj = body['message'];
    throw TeamApiException(
      mesaj is String && mesaj.isNotEmpty
          ? mesaj
          : 'Giriş bilgileri güncellenemedi (kod ${resp.statusCode}).',
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

class TeamApiException implements Exception {
  TeamApiException(this.mesaj);
  final String mesaj;

  @override
  String toString() => mesaj;
}
