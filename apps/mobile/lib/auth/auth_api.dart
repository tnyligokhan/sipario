import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../sync/api_hata_metni.dart';

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
  AuthApi({
    required this.baseUrl,
    http.Client? client,
    List<Duration> yenidenDeneme = const [Duration(seconds: 2), Duration(seconds: 4)],
  })  : _client = client ?? http.Client(),
        _yenidenDeneme = yenidenDeneme;

  final String baseUrl;
  final http.Client _client;

  /// Girişte GEÇİCİ arızadan sonra beklenecek süreler; her eleman bir yeniden deneme demektir.
  ///
  /// NEDEN (saha şikâyeti 2026-09-29: "bazen tüm bilgiler doğru olmasına rağmen giriş
  /// yapamıyorum"): sunucu her dağıtımda 40-60 saniye kapanıyor ve mobil ağ zayıf anlarda
  /// bağlantıyı düşürüyor. İkisi de birkaç saniyede geçer ama bayi "bilgilerim yanlış" sanıp
  /// vazgeçiyordu. Yalnız bağlantı hatası ve 502/503/504 yeniden denenir: 401/403/422 bir karar
  /// cevabıdır ve tekrar sormak hız sınırını boşuna tüketir.
  final List<Duration> _yenidenDeneme;

  /// 401 ve 403 bu uçta OTURUM değil KİMLİK cevabıdır; metnini sunucu yazar (nötr cümle).
  static const _girisHatasi =
      ApiHataMetni('Giriş yapılamadı', guvenilen: {401, 403, 409, 422});

  static bool _geciciMi(int durum) => durum == 502 || durum == 503 || durum == 504;

  /// Tasarım `s-giris.jsx`: giriş **firma kodu + kullanıcı adı + parola** ile yapılır.
  /// [tenantCode] tasarımdaki "Firma Kodu" (sunucuda `tenants.slug`), [username] ise
  /// kullanıcı adı — tenant içinde tekildir, e-posta DEĞİLDİR.
  Future<LoginResult> login({
    required String tenantCode,
    required String username,
    required String password,
    required String deviceId,
  }) async {
    final istek = jsonEncode({
      'tenant_code': tenantCode,
      'username': username,
      'password': password,
      'device': {
        'device_id': deviceId,
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
    });

    http.Response? resp;
    for (var deneme = 0;; deneme++) {
      resp = null;
      var zamanAsimi = false;
      try {
        resp = await _client
            .post(
              Uri.parse('$baseUrl/auth/login'),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: istek,
            )
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        // 20 saniye zaten beklendi; yeniden denemek bayiyi bir dakika ekranda tutardı.
        zamanAsimi = true;
      } on Exception {
        // Ağ/DNS — hepsi kullanıcı için tek anlama gelir. Detay loglanmaz (alışkanlık
        // disiplini: taşıma hataları kullanıcı verisi taşıyabilir).
      }
      if (zamanAsimi) break;
      final gecici = resp == null || _geciciMi(resp.statusCode);
      if (!gecici || deneme >= _yenidenDeneme.length) break;
      await Future<void>.delayed(_yenidenDeneme[deneme]);
    }

    if (resp == null) throw AuthException(ApiHataMetni.baglantiYok);
    final body = _decode(resp.body);
    if (resp.statusCode != 200) {
      throw AuthException(_girisHatasi.yanit(resp.statusCode, body));
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

  /// YÖNETİCİ ONAYI — oturumdaki kullanıcının parolasını sunucuya doğrulatır (2026-08-18).
  ///
  /// Bazı işlemler "giriş yapmış olmak"tan fazlasını ister: kapatılmış bir gün hesabını geri
  /// almak gibi. Telefon çoğu zaman tezgâhın üstünde açık durur; oturumun patrona ait olması, o
  /// an ekrana dokunanın patron olduğunu kanıtlamaz.
  ///
  /// ⚠️ ÇEVRİMİÇİ ZORUNLU ve bu bilinçli bir bedeldir. Depoda yazılı kural: parola SAKLANMAZ ve
  /// hash'i istemci üretemez (`Session.giris` "beniHatirla" notu, `TeamApi` başlığı). Yerel bir
  /// parola aynası koymak, ürünün en hassas sırrını her telefona kopyalamak olurdu. Çağıran
  /// ekran ağ yokken gerekçesini YAZMAK zorundadır — sessizce başarısız olmak, kullanıcıya
  /// "parolam yanlış" dedirtir.
  ///
  /// Kullanıcı adı GÖNDERİLMEZ: sunucu her zaman TOKEN'IN sahibini doğrular. Gönderilseydi
  /// kuryenin telefonundaki bir oturumdan patronun parolası denenebilirdi.
  ///
  /// `true` = parola doğru. `false` = parola yanlış (422). Ağ/sunucu arızasında [AuthException]
  /// atar — "yanlış parola" ile "sunucuya ulaşılamadı" AYRI sonuçlardır ve ekran ikisini aynı
  /// cümleyle gösteremez.
  Future<bool> parolaDogrula({required String token, required String password}) async {
    final http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('$baseUrl/auth/parola-dogrula'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'password': password}),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw AuthException('İnternet bağlantısı kurulamadı. Yönetici onayı için internet gerekli.');
    }

    if (resp.statusCode == 200) return true;
    if (resp.statusCode == 422) return false;
    throw AuthException(
      const ApiHataMetni('Onay alınamadı', guvenilen: {})
          .yanit(resp.statusCode, _decode(resp.body)),
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
      throw AuthException(ApiHataMetni.baglantiYok);
    }

    final body = _decode(resp.body);
    // 429 (hız sınırı) AYRI ELE ALINIR: "çok fazla istek" bilgisi hesabın varlığını sızdırmaz
    // ama sessizce "gönderdik" demek yalan olurdu — kullanıcı bekler, bağlantı hiç gelmez.
    if (resp.statusCode != 200) {
      throw AuthException(const ApiHataMetni('İstek gönderilemedi').yanit(resp.statusCode, body));
    }

    final msg = body['message'];
    return msg is String && ApiHataMetni.gosterilebilirMi(msg)
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
