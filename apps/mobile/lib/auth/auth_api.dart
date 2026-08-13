import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Login yanıtının istemci modeli (sunucu: AuthController@login → {token, user, tenant}).
class LoginResult {
  LoginResult({
    required this.token,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.tenantName,
    this.validUntilIso,
    this.tenantStatus,
  });

  final String token;
  final String userId;
  final String userName;
  final String userRole; // patron|operator|kurye
  final String tenantName;
  final String? validUntilIso;
  final String? tenantStatus;
}

/// Kullanıcıya gösterilebilir auth hatası. Sunucunun nötr `message` alanı aynen taşınır
/// (401 "Firma kodu, kullanıcı adı veya parola hatalı", 403 "Hesabınız kullanıma kapalı",
/// 429 hız sınırı). İstemci bu metni ZENGİNLEŞTİRMEZ: hangi alanın yanlış olduğunu
/// söylemek geçerli firma kodlarının numaralandırılmasına kapı açardı.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// POST /auth/login ve /auth/logout istemcisi. Taban adres HttpSyncApi ile aynı biçimdedir
/// (ör. https://api.sipario.com.tr/api/v1). http.Client enjekte edilebilir (test).
class AuthApi {
  AuthApi({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Tasarım `s-giris.jsx`: giriş **firma kodu + kullanıcı adı + parola** ile yapılır.
  /// [tenantCode] tasarımdaki "Firma Kodu" (sunucuda `tenants.slug`), [username] ise
  /// kullanıcı adı — tenant içinde tekildir, e-posta DEĞİLDİR.
  Future<LoginResult> login({
    required String tenantCode,
    required String username,
    required String password,
    required String deviceId,
  }) async {
    final http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'tenant_code': tenantCode,
              'username': username,
              'password': password,
              'device': {
                'device_id': deviceId,
                'platform': Platform.isIOS ? 'ios' : 'android',
              },
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      // Ağ/timeout/DNS — hepsi kullanıcı için tek anlama gelir. Detay loglanmaz (KVKK: PII riski yok
      // ama alışkanlık disiplini: taşıma hataları kullanıcı verisi taşıyabilir).
      throw AuthException('Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.');
    }

    final body = _decode(resp.body);
    if (resp.statusCode != 200) {
      final msg = body['message'];
      throw AuthException(
        msg is String && msg.isNotEmpty ? msg : 'Giriş başarısız (HTTP ${resp.statusCode}).',
      );
    }

    final user = (body['user'] as Map).cast<String, dynamic>();
    final tenant = (body['tenant'] as Map).cast<String, dynamic>();
    return LoginResult(
      token: body['token'] as String,
      userId: user['id'] as String,
      userName: (user['name'] as String?) ?? '',
      userRole: (user['role'] as String?) ?? 'patron',
      tenantName: (tenant['name'] as String?) ?? '',
      validUntilIso: tenant['valid_until'] as String?,
      tenantStatus: tenant['status'] as String?,
    );
  }

  /// Parola sıfırlama bağlantısı ister (kullanıcı isteği 2026-08-13).
  ///
  /// SUNUCU HER KOŞULDA AYNI ŞEYİ DÖNER ve bu bilinçlidir: hesap var/yok, patron/kurye ayrımı
  /// yapılmaz — yoksa geçerli firma kodu + kullanıcı adı çiftleri tek tek numaralandırılırdı.
  /// Yani bu çağrının dönüşü "gönderildi" DEMEK DEĞİLDİR, "istek alındı" demektir; ekran metni
  /// de öyle kurulmalıdır.
  ///
  /// Yalnız AĞ hatası fırlatır: taşıma çalıştıysa sonuç ne olursa olsun başarıdır.
  Future<String> parolaSifirla({
    required String tenantCode,
    required String username,
  }) async {
    final http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('$baseUrl/auth/parola-sifirla'),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'tenant_code': tenantCode, 'username': username}),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw AuthException('Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.');
    }

    final body = _decode(resp.body);
    // 429 (hız sınırı) AYRI ELE ALINIR: "çok fazla istek" bilgisi hesabın varlığını sızdırmaz
    // ama sessizce "gönderdik" demek yalan olurdu — kullanıcı bekler, bağlantı hiç gelmez.
    if (resp.statusCode == 429) {
      throw AuthException('Çok fazla istek gönderildi. Birkaç dakika sonra tekrar deneyin.');
    }
    if (resp.statusCode != 200) {
      final msg = body['message'];
      throw AuthException(
        msg is String && msg.isNotEmpty ? msg : 'İstek gönderilemedi (HTTP ${resp.statusCode}).',
      );
    }

    final msg = body['message'];
    return msg is String && msg.isNotEmpty
        ? msg
        : 'İsteğiniz alındı. Kayıtlı bir e-posta adresi varsa bağlantı gönderildi.';
  }

  /// Sunucudaki token'ı iptal eder. Başarısızlık yutulur — yerel çıkış her koşulda tamamlanır
  /// (offline'da da çıkış yapılabilmeli); token zaten yerelden silinecek.
  Future<void> logout(String token) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
    } on Exception {
      // sessiz — yerel çıkış devam eder
    }
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
