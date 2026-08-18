import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../data/ids.dart';
import 'auth_api.dart';

/// Varsayılan API taban adresi — DERLEME SABİTİ (`--dart-define=SIPARIO_API=...`).
///
/// NEDEN DEFINE (2026-08-09): iki kanal iki ayrı sunucuya bakmak zorunda. Saha derlemesi canlıya,
/// deneme derlemesi test sunucusuna gider. Bunu giriş ekranındaki bir alana bırakmak İKİ AÇIDAN
/// yanlış olurdu: (1) canlıya geçerken o alan bilinçli olarak kaldırıldı — mağaza incelemesinde
/// saha uygulamasında sunucu adresi kutusu istenmez, (2) adresi kullanıcıya sormak, yanlış
/// sunucuya bağlanmış bir bayi ihtimali demektir ve bu ihtimal veri karışması riskidir.
///
/// Varsayılan CANLIDIR: define geçilmezse (yerel derleme, IDE'den koşturma) davranış bugünküyle
/// aynı kalır. Deneme kanalı adresi CI'da geçirir; test sunucusu adresi değişirse yalnız iş
/// akışındaki tek satır değişir, kod değişmez.
const kDefaultApiBaseUrl = String.fromEnvironment(
  'SIPARIO_API',
  defaultValue: 'https://sipario.com.tr/api/v1',
);

/// "Beni hatırla" ile saklanan kimlik — giriş ekranı bunu ÖNDOLDURUR. Parola İÇERMEZ.
typedef HatirlananKimlik = ({String firma, String kullanici});

/// [SyncMetaData]'dan hatırlanan kimliği çözer — ekrandan ve ağdan BAĞIMSIZ, saf testle sınanır.
///
/// İKİSİ BİRDEN dolu olmak zorunda: yarım bir kayıt (yalnız firma kodu) hatırlama SAYILMAZ.
/// Aksi hâlde giriş ekranı bir alanı doldurup diğerini boş bırakır ve "hatırla" kutusunu
/// işaretli gösterirdi — kullanıcıya hatırlandığını söyleyip hatırlamamak, hiç hatırlamamaktan
/// kötüdür. Boşluk kırpılır ve boş metin YOKLUK sayılır (`''` diskte "hatırlandı" demez).
HatirlananKimlik? hatirlananKimlikCoz(SyncMetaData meta) {
  final firma = meta.savedTenantCode?.trim() ?? '';
  final kullanici = meta.savedUsername?.trim() ?? '';
  if (firma.isEmpty || kullanici.isEmpty) return null;
  return (firma: firma, kullanici: kullanici);
}

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
  ///
  /// Kimlik tasarım `s-giris.jsx`teki gibidir: **firma kodu + kullanıcı adı + parola**.
  /// İkisi de küçük harfe indirilir — klavyenin büyük harfe kaçması giriş engeli olmamalı
  /// (sunucu da aynı normalizasyonu yapar, iki taraf ayrışmasın diye burada da yapılır).
  ///
  /// Burada `trKucuk()` DEĞİL düz `toLowerCase()` kullanılır: bunlar Türkçe metin değil,
  /// `^[a-z0-9._-]{3,}$` sözleşmesine tabi ASCII kimliklerdir. Türkçe harf girilirse
  /// doğrulama zaten reddeder ve kullanıcı net bir hata görür.
  /// [beniHatirla] YALNIZ firma kodu + kullanıcı adını saklar; **parola SAKLANMAZ.**
  /// Gerekçe `SyncMeta.savedTenantCode` başlığındadır (kısaca: çıkış yapmanın tek anlamı
  /// bir sonraki girişte kimlik sormaktır). `false` verilirse önceki hatırlanan kimlik
  /// SİLİNİR — kutuyu boşaltmak bir tercihtir ve sessizce yok sayılamaz.
  Future<void> login({
    required String tenantCode,
    required String username,
    required String password,
    String? baseUrlOverride,
    bool beniHatirla = false,
  }) async {
    final meta = await db.syncState();
    final baseUrl = _normalizeBaseUrl(baseUrlOverride ?? meta.apiBaseUrl ?? kDefaultApiBaseUrl);
    final deviceId = meta.deviceId ?? newId();

    // NORMALİZASYON BİR KEZ: sunucuya giden ile diske yazılan AYNI değer olmalı. Ekranın ham
    // metnini saklasaydık bayi "Merkezbayi" yazıp girer, ertesi gün kutuda "Merkezbayi"
    // görürdü — oysa hesabı `merkezbayi`dir; hatırlanan kimlik, kabul edilmiş kimliktir.
    final firma = tenantCode.trim().toLowerCase();
    final kullanici = username.trim().toLowerCase();

    final result = await _apiFactory(baseUrl).login(
      tenantCode: firma,
      username: kullanici,
      password: password,
      deviceId: deviceId,
    );

    await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(SyncMetaCompanion(
      // YALNIZ BAŞARILI girişten sonra yazılır (bu satır `login()` çağrısının ALTINDA ve
      // bu bilinçli): yanlış yazılmış bir firma kodunu hatırlamak, bayiye her açılışta
      // çalışmayan bir kimlik sunmak demektir.
      savedTenantCode: Value(beniHatirla ? firma : null),
      savedUsername: Value(beniHatirla ? kullanici : null),
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
  ///
  /// "Beni hatırla" kimliği (`savedTenantCode`/`savedUsername`) de KALIR ve bu, özelliğin var
  /// oluş sebebidir: token zaten çıkış yapılana kadar duruyor, yani hatırlanan kimlik YALNIZ
  /// çıkıştan sonraki girişte okunuyor. Burada silinseydi hiçbir zaman okunmazdı.
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

  /// Parola sıfırlama bağlantısı ister (kullanıcı isteği 2026-08-13). Oturum GEREKTİRMEZ —
  /// zaten giriş yapamayan kullanıcı için var.
  ///
  /// Kimlik burada da `login` ile AYNI normalizasyondan geçer (kırpma + küçük harf): sunucu
  /// aramayı `lower()` ile yapıyor ve iki taraf ayrışırsa "Ozpinar" yazan bayi için istek
  /// sessizce hiçbir hesap bulamaz.
  ///
  /// Dönen metin sunucunun NÖTR cevabıdır; "gönderildi" DEĞİL "istek alındı" anlamına gelir
  /// (gerekçe `AuthApi.parolaSifirla` ve `parola_kurtarma_sheet.dart` başlıklarında).
  Future<String> parolaSifirlamaIste({
    required String tenantCode,
    required String username,
  }) async {
    final meta = await db.syncState();
    final baseUrl = _normalizeBaseUrl(meta.apiBaseUrl ?? kDefaultApiBaseUrl);
    return _apiFactory(baseUrl).parolaSifirla(
      tenantCode: tenantCode.trim().toLowerCase(),
      username: username.trim().toLowerCase(),
    );
  }

  /// YÖNETİCİ ONAYI — oturumdaki kullanıcının parolasını sunucuya doğrulatır (2026-08-18).
  ///
  /// Gerekçe ve çevrimiçi zorunluluğu `AuthApi.parolaDogrula` başlığında. Burada yalnız oturum
  /// jetonu çözülür; jeton yoksa çağrı hiç yapılmaz (ağa çıkıp 401 almak, kullanıcıya "sunucu
  /// hatası" gibi görünen bir gecikme eklemek olurdu).
  Future<bool> parolaDogrula(String password) async {
    final meta = await db.syncState();
    final token = meta.authToken;
    if (token == null) {
      throw AuthException('Oturum bulunamadı — çıkış yapıp yeniden girin.');
    }
    return _apiFactory(baseUrlOf(meta)).parolaDogrula(token: token, password: password);
  }

  /// "Beni hatırla" ile saklanmış kimlik; hatırlama kapalıysa null.
  Future<HatirlananKimlik?> hatirlananKimlik() async => hatirlananKimlikCoz(await db.syncState());

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
