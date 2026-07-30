// CANLI KURYE KONUMU istemcisi — iki uç: kalp atışı (yaz) ve canlı liste (oku).
//
// NEDEN SENKRONDAN AYRI (`route_api.dart` ile aynı gerekçe): konum bir KAYIT DEĞİLDİR. Outbox'a
// girmez, LWW ile birleşmez, çevrimdışı kuyruklanmaz — kaçırılan bir tur sonsuza kadar kaybolur
// ve bu DOĞRU davranıştır: 30 sn önceki konumu geç bildirmek, haritaya yalan söylemektir.
//
// KVKK: bu dosyada koordinat LOGLANMAZ. Hata mesajları da koordinat taşımaz — bir crash
// raporunda kuryenin evinin önündeki noktayı bulmak kimsenin işi değil.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sunucunun bildirdiği tek bir canlı konum (GET /locations/live öğesi).
class CanliKonum {
  const CanliKonum({
    required this.userId,
    required this.ad,
    required this.rol,
    required this.lat,
    required this.lng,
    required this.dogrulukM,
    required this.bildirilenIso,
    required this.taze,
  });

  final String userId;
  final String ad;

  /// 'kurye' · 'patron' · 'operator' — ekranda etikete çevrilir, karşılaştırma ham değerle yapılır.
  final String rol;

  final double lat;
  final double lng;

  /// Yatay doğruluk (metre) — cihaz bilmiyorsa `null` (sunucu `accuracy_m`i nullable döner).
  /// Özet sayfasında "±12 m" olarak yazar: 800 m'lik bir pin, kuryenin nerede OLMADIĞINI söyler
  /// ve bunu gizlemek haritaya sahte bir kesinlik katardı. NULL 0'A ÇEVRİLMEZ: "±0 m" kusursuz
  /// bir ölçüm İDDİASIDIR, yani "bilmiyorum"u gizlemekten daha yanıltıcıdır.
  final double? dogrulukM;

  /// Sunucunun damgası (ISO8601, ofsetli). CİHAZ SAATİ İLE ÜRETİLMEZ — "3 dk önce" hesabı
  /// yerelde yapılsa da damganın kendisi sunucunun gerçeğidir.
  final String bildirilenIso;

  /// Konum TAZE mi? Kararı SUNUCU verir; eşiği istemci yeniden tanımlamaz — iki taraf ayrı
  /// pencere kullanırsa aynı pin bir ekranda canlı, diğerinde bayat görünürdü.
  final bool taze;

  /// Sözleşme dışı/eksik alanlı öğe `null` döner ve ÇAĞIRAN TARAFINDAN DÜŞÜLÜR: tek bozuk
  /// satır yüzünden bütün listeyi (ve haritayı) kaybetmek, sunucunun küçük bir hatasını
  /// kullanıcının ekranında büyük bir arızaya çevirirdi.
  static CanliKonum? fromJson(Map<String, dynamic> j) {
    final userId = j['user_id'];
    final lat = j['lat'];
    final lng = j['lng'];
    if (userId is! String || userId.isEmpty || lat is! num || lng is! num) return null;
    // Enlem/boylam aralık dışıysa öğe atılır: (0,0) ya da 999 gibi bir değer haritayı
    // Gine Körfezi'ne ışınlar ve kadrajı bütün pinler için bozar.
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return CanliKonum(
      userId: userId,
      ad: j['name'] is String && (j['name'] as String).trim().isNotEmpty
          ? (j['name'] as String).trim()
          // Adsız kullanıcı beklenmez ama pin ADSIZ kalmamalı: boş etiketli bir daire
          // haritada "bu da ne" sorusundan başka bir şey üretmez.
          : 'Kullanıcı',
      rol: j['role'] is String ? j['role'] as String : '',
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      // `is num` ile bakılır, ham `as num?` ile DEĞİL: sayı olmayan bir değer (bozuk sunucu,
      // araya giren vekil) dönüşümde TypeError fırlatır — o hata bu öğeyi düşürmekle kalmaz,
      // Exception olmadığı için çağıranın yakalayıcısını da aşıp bütün listeyi götürürdü.
      dogrulukM: j['accuracy_m'] is num ? (j['accuracy_m'] as num).toDouble() : null,
      bildirilenIso: j['reported_at'] is String ? j['reported_at'] as String : '',
      // Alan hiç gelmezse TAZE sayılır: sunucu tazeliği bildirmiyorsa pinleri toptan soluk
      // çizmek, çalışan bir özelliği bozukmuş gibi gösterirdi.
      taze: j['is_fresh'] is bool ? j['is_fresh'] as bool : true,
    );
  }
}

/// Konum uçlarının istemcisi. Hatalar `KonumApiHatasi` ile çıkar; ÇAĞIRAN onları YUTAR —
/// bu özelliğin kullanıcıya dönük tek bir hata mesajı yoktur (bkz. `konum_bildirici.dart`).
class KonumApi {
  KonumApi({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  Map<String, String> get _basliklar => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// POST /locations/heartbeat → 204. Zaman aşımı KISADIR (8 sn): bir tur kaçmak zararsız,
  /// 30 sn'lik turun üstüne binen uzun bir istek ise sıraya girip pil yakar.
  Future<void> kalpAtisiGonder({
    required double lat,
    required double lng,
    required double dogrulukM,
  }) async {
    final http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('$baseUrl/locations/heartbeat'),
            headers: _basliklar,
            body: jsonEncode({'lat': lat, 'lng': lng, 'accuracy_m': dogrulukM}),
          )
          .timeout(const Duration(seconds: 8));
    } on Exception {
      throw const KonumApiHatasi('Konum bildirilemedi');
    }
    if (resp.statusCode < 200 || resp.statusCode > 299) {
      throw KonumApiHatasi('Konum bildirilemedi (HTTP ${resp.statusCode})');
    }
  }

  /// GET /locations/live → `{"locations":[…]}`. Tanınmayan/eksik öğeler sessizce düşer.
  Future<List<CanliKonum>> canliKonumlar() async {
    final http.Response resp;
    try {
      resp = await _client
          .get(Uri.parse('$baseUrl/locations/live'), headers: _basliklar)
          .timeout(const Duration(seconds: 10));
    } on Exception {
      throw const KonumApiHatasi('Canlı konumlar alınamadı');
    }
    if (resp.statusCode != 200) {
      throw KonumApiHatasi('Canlı konumlar alınamadı (HTTP ${resp.statusCode})');
    }

    final Object? govde;
    try {
      govde = jsonDecode(resp.body);
    } on FormatException {
      throw const KonumApiHatasi('Canlı konumlar okunamadı');
    }
    if (govde is! Map) return const [];
    final ham = govde['locations'];
    if (ham is! List) return const [];

    return [
      for (final e in ham)
        if (e is Map<String, dynamic>) ?CanliKonum.fromJson(e),
    ];
  }
}

/// İç hata türü — kullanıcıya GÖSTERİLMEZ. Mesaj yalnız geliştiricinin okuduğu bir iz;
/// bu yüzden koordinat ya da kullanıcı adı taşımaz.
class KonumApiHatasi implements Exception {
  const KonumApiHatasi(this.mesaj);
  final String mesaj;

  @override
  String toString() => mesaj;
}

/// Konum istemcisinin TEK dikişi (`rotaApiUret` deseninin aynısı). Widget ve birim testleri
/// bunu sahtesiyle değiştirir; test ağa ASLA çıkmaz.
KonumApi Function(String baseUrl, String token) konumApiUret =
    (baseUrl, token) => KonumApi(baseUrl: baseUrl, token: token);
