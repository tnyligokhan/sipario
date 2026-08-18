import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/auth_api.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';

/// Sahte AuthApi: ağa çıkmadan kayıtlı senaryoyu oynar (Dilim 1 — oturum kalıcılığı testleri).
class _FakeAuthApi implements AuthApi {
  _FakeAuthApi(this.baseUrl, {this.failWith});

  @override
  final String baseUrl;
  final AuthException? failWith;
  String? lastDeviceId;
  String? loggedOutToken;
  String? lastTenantCode;
  String? lastUsername;

  @override
  Future<LoginResult> login({
    required String tenantCode,
    required String username,
    required String password,
    required String deviceId,
  }) async {
    if (failWith != null) throw failWith!;
    lastDeviceId = deviceId;
    lastTenantCode = tenantCode;
    lastUsername = username;
    return LoginResult(
      token: 'sipario_test_token',
      userId: 'user-1',
      userName: 'Test Patron',
      userRole: 'patron',
      tenantName: 'Test Bayi',
      validUntilIso: '2099-01-01T00:00:00+00:00',
      tenantStatus: 'active',
    );
  }

  @override
  Future<void> logout(String token) async => loggedOutToken = token;

  /// Bu testlerin konusu değil; yalnız sözleşmeyi tamamlar (`implements AuthApi`).
  @override
  Future<bool> parolaDogrula({required String token, required String password}) async => true;

  @override
  Future<String> parolaSifirla({
    required String tenantCode,
    required String username,
  }) async =>
      'ok';
}

void main() {
  late AppDatabase db;
  late _FakeAuthApi api;
  late Session session;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _FakeAuthApi(kDefaultApiBaseUrl);
    session = Session(db, apiFactory: (base) => api);
  });

  tearDown(() => db.close());

  test('login oturumu sync_meta\'ya kalıcılar; deviceId üretilir ve outbox ile aynı kaynaktan gelir',
      () async {
    expect(await session.isLoggedIn(), isFalse);

    await session.login(tenantCode: '  MerkezBayi ', username: ' Mehmet.Usta ', password: 'sifre');

    final meta = await db.syncState();
    expect(meta.authToken, 'sipario_test_token');
    expect(meta.userId, 'user-1');
    expect(meta.userName, 'Test Patron');
    expect(meta.userRole, 'patron');
    expect(meta.tenantName, 'Test Bayi');
    expect(meta.deviceId, isNotNull);
    expect(meta.deviceId, api.lastDeviceId, reason: 'sunucuya bildirilen cihaz = yerelde saklanan');
    expect(meta.validUntilIso, '2099-01-01T00:00:00+00:00');
    expect(await session.isLoggedIn(), isTrue);

    // Kimlik alanları KIRPILIP KÜÇÜK HARFE indirilerek gider: klavyenin büyük harfe kaçması
    // ya da başa/sona boşluk düşmesi girişi engellememeli (sunucu da aynı normalizasyonu yapar).
    expect(api.lastTenantCode, 'merkezbayi');
    expect(api.lastUsername, 'mehmet.usta');
  });

  test('ikinci login AYNI deviceId ile gider (cihaz kimliği kalıcı — LWW/outbox tutarlılığı)',
      () async {
    await session.login(tenantCode: 'bayi', username: 'patron', password: 'sifre');
    final first = (await db.syncState()).deviceId;

    await session.logout();
    await session.login(tenantCode: 'bayi', username: 'patron', password: 'sifre');

    expect((await db.syncState()).deviceId, first);
  });

  test('logout token\'ı siler ama İŞ VERİSİNİ ve sync imlecini KORUR (offline-first)', () async {
    await session.login(tenantCode: 'bayi', username: 'patron', password: 'sifre');
    final customerId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');

    await session.logout();

    final meta = await db.syncState();
    expect(meta.authToken, isNull);
    expect(meta.userName, isNull);
    expect(api.loggedOutToken, 'sipario_test_token', reason: 'sunucu token iptali çağrılır');
    final customer = await (db.select(db.customers)
          ..where((t) => t.id.equals(customerId)))
        .getSingleOrNull();
    expect(customer, isNotNull, reason: 'çıkış veri silmez');
    expect(meta.deviceId, isNotNull, reason: 'cihaz kimliği kalır');
  });

  test('başarısız login oturum yazmaz', () async {
    final failing = Session(
      db,
      apiFactory: (base) => _FakeAuthApi(base, failWith: AuthException('Firma kodu, kullanıcı adı veya parola hatalı.')),
    );
    await expectLater(
      failing.login(tenantCode: 'bayi', username: 'patron', password: 'yanlis'),
      throwsA(isA<AuthException>()),
    );
    expect((await db.syncState()).authToken, isNull);
  });

  test('baseUrl normalize edilir (sondaki / atılır) ve kalıcılanır', () async {
    await session.login(tenantCode: 'bayi', username: 'patron', password: 'sifre', baseUrlOverride: 'http://10.0.2.2:8000/api/v1/');
    expect((await db.syncState()).apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
  });
}
