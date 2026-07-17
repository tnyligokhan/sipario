import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import 'auth_api.dart';

/// Varsayılan API taban adresi. Geliştirmede login ekranındaki "gelişmiş" alanından değiştirilir
/// (emülatör: http://10.0.2.2:8000/api/v1 — Android emülatöründe host makine 10.0.2.2'dir).
const kDefaultApiBaseUrl = 'https://api.sipario.com.tr/api/v1';

/// Oturum yöneticisi. Kaynak sync_meta tek satırıdır (id=1): token, kullanıcı, cihaz kimliği.
/// deviceId İLK login denemesinde üretilir ve kalıcıdır — outbox/LWW'deki device_id ile aynı değer
/// (Faz 2'den beri şemada bekleyen alan bu akışla dolar).
class Session {
  Session(this.db, {AuthApi Function(String baseUrl)? apiFactory})
      : _apiFactory = apiFactory ?? ((base) => AuthApi(baseUrl: base));

  final AppDatabase db;
  final AuthApi Function(String baseUrl) _apiFactory;

  Future<SyncMetaData> state() => db.syncState();

  /// Oturum açık mı? (token varlığı — sunucu doğrulaması ilk sync'te yapılır; offline-first gereği
  /// açılışta ağ BEKLENMEZ.)
  Future<bool> isLoggedIn() async => (await db.syncState()).authToken != null;

  /// Girişi yapar ve oturumu kalıcılar. Başarısızlıkta AuthException fırlatır (mesaj kullanıcıya).
  Future<void> login({required String email, required String password, String? baseUrlOverride}) async {
    final meta = await db.syncState();
    final baseUrl = _normalizeBaseUrl(baseUrlOverride ?? meta.apiBaseUrl ?? kDefaultApiBaseUrl);
    final deviceId = meta.deviceId ?? newId();

    final result = await _apiFactory(baseUrl).login(
      email: email.trim(),
      password: password,
      deviceId: deviceId,
    );

    await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(SyncMetaCompanion(
      authToken: Value(result.token),
      userId: Value(result.userId),
      userName: Value(result.userName),
      userRole: Value(result.userRole),
      tenantName: Value(result.tenantName),
      deviceId: Value(deviceId),
      apiBaseUrl: Value(baseUrl),
      // Login yanıtındaki abonelik bilgisi önbelleğe — ilk sync gelene kadar da doğru karar verilsin.
      validUntilIso: Value(result.validUntilIso),
      subscriptionStatus: Value(result.tenantStatus),
    ));
  }

  /// Çıkış: sunucu token'ı iptal edilir (başarısızlık yutulur), yerelde YALNIZ oturum alanları
  /// silinir — iş verisi, outbox ve sync imleci KALIR (offline-first: veri kaybettirme yok; aynı
  /// bayi tekrar girince kaldığı yerden devam eder).
  Future<void> logout() async {
    final meta = await db.syncState();
    final token = meta.authToken;
    if (token != null) {
      final baseUrl = _normalizeBaseUrl(meta.apiBaseUrl ?? kDefaultApiBaseUrl);
      await _apiFactory(baseUrl).logout(token);
    }
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(const SyncMetaCompanion(
      authToken: Value(null),
      userName: Value(null),
      userRole: Value(null),
    ));
  }

  /// Meta satırından etkin taban adres (yoksa varsayılan üretim adresi).
  static String baseUrlOf(SyncMetaData meta) => _normalizeBaseUrl(meta.apiBaseUrl ?? kDefaultApiBaseUrl);

  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
