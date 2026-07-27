import 'dart:convert';

import 'package:http/http.dart' as http;

/// Senkron sunucu yüzeyi (tek yazma push, tek okuma pull). Arayüz enjekte edilir → sync motoru
/// gerçek ağ olmadan test edilebilir (sahte SyncApi).
abstract interface class SyncApi {
  /// POST /api/v1/sync/push
  Future<PushResponse> push(List<Map<String, Object?>> events);

  /// GET /api/v1/sync/pull?since=&limit=
  Future<PullResponse> pull({required int since, int limit});
}

class EventResult {
  EventResult({required this.clientEventId, required this.status, this.entityId, this.serverSeq});
  final String clientEventId;
  final String status; // applied|duplicate|stale|noop|rejected
  final String? entityId;
  final int? serverSeq;

  factory EventResult.fromJson(Map<String, dynamic> j) => EventResult(
        clientEventId: j['client_event_id'] as String,
        status: j['status'] as String,
        entityId: j['entity_id'] as String?,
        serverSeq: (j['server_seq'] as num?)?.toInt(),
      );
}

/// Abonelik durumu yayını (FAZ 5a — DECISIONS: tek doğru kaynak sunucu). Push VE pull yanıtında gelir;
/// istemci sync_meta'ya önbellekler ve ileri-sadece saatle kilit/grace kararını verir.
class SubscriptionInfo {
  SubscriptionInfo({
    this.status,
    this.validUntil,
    this.lockedAt,
    this.serverTime,
    this.tenantCode,
    this.routeCredits,
    this.routeCreditsMonthly,
  });
  final String? status; // trial|active|locked|suspended
  final String? validUntil; // ISO8601
  final String? lockedAt; // ISO8601
  final String? serverTime; // ISO8601

  /// SUNUCU SAHİPLİ, istemcinin yazamayacağı alanlar (modules ile aynı kanal): tasarımdaki
  /// "Firma Kodu" (tenants.slug, değiştirilemez) ve "Oto Sırala · N hak" sayacı.
  final String? tenantCode;

  /// Kalan hak ve AYLIK KOTA — çekmecedeki ilerleme çubuğu bu ikisinin oranıdır.
  final int? routeCredits;
  final int? routeCreditsMonthly;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
        status: j['status'] as String?,
        validUntil: j['valid_until'] as String?,
        lockedAt: j['locked_at'] as String?,
        serverTime: j['server_time'] as String?,
        tenantCode: j['tenant_code'] as String?,
        routeCredits: (j['route_credits'] as num?)?.toInt(),
        routeCreditsMonthly: (j['route_credits_monthly'] as num?)?.toInt(),
      );
}

/// Ekip listesi (FAZ 4b Dilim 4). NULLABLE: eski sunucu `team` göndermezse null → istemci yerel
/// önbelleği KORUR (silmez). Anahtar List DEĞİLSE null (savunmacı). Eleman: {id,name,role,status}.
List<Map<String, dynamic>>? _parseTeam(dynamic v) =>
    v is List ? v.map((e) => (e as Map).cast<String, dynamic>()).toList() : null;

class PushResponse {
  PushResponse(
      {required this.results, required this.currentSeq, this.serverTime, this.subscription, this.team});
  final List<EventResult> results;
  final int currentSeq;
  final String? serverTime;
  final SubscriptionInfo? subscription;
  final List<Map<String, dynamic>>? team;

  factory PushResponse.fromJson(Map<String, dynamic> j) => PushResponse(
        results: ((j['results'] as List?) ?? [])
            .map((e) => EventResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentSeq: (j['current_seq'] as num?)?.toInt() ?? 0,
        serverTime: j['server_time'] as String?,
        subscription: j['subscription'] is Map
            ? SubscriptionInfo.fromJson((j['subscription'] as Map).cast<String, dynamic>())
            : null,
        team: _parseTeam(j['team']),
      );
}

class PullResponse {
  PullResponse({
    required this.mode,
    required this.cursor,
    required this.hasMore,
    required this.currentSeq,
    this.serverTime,
    this.subscription,
    this.team,
    this.changes = const [],
    this.entities = const {},
  });
  final String mode; // snapshot|delta
  final int cursor;
  final bool hasMore;
  final int currentSeq;
  final String? serverTime;
  final SubscriptionInfo? subscription;
  final List<Map<String, dynamic>>? team;
  final List<Map<String, dynamic>> changes; // delta
  final Map<String, List<Map<String, dynamic>>> entities; // snapshot

  factory PullResponse.fromJson(Map<String, dynamic> j) {
    final rawEntities = (j['entities'] as Map<String, dynamic>?) ?? const {};
    return PullResponse(
      mode: j['mode'] as String,
      cursor: (j['cursor'] as num?)?.toInt() ?? 0,
      hasMore: (j['has_more'] as bool?) ?? false,
      currentSeq: (j['current_seq'] as num?)?.toInt() ?? 0,
      serverTime: j['server_time'] as String?,
      subscription: j['subscription'] is Map
          ? SubscriptionInfo.fromJson((j['subscription'] as Map).cast<String, dynamic>())
          : null,
      team: _parseTeam(j['team']),
      changes: ((j['changes'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      entities: rawEntities.map((k, v) => MapEntry(
            k,
            ((v as List?) ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList(),
          )),
    );
  }
}

/// HTTP taşıması. baseUrl ör. https://api.sipario.com.tr/api/v1 ; token sağlayıcı Sanctum bearer'ı.
///
/// ZAMAN AŞIMI ZORUNLUDUR (2026-07-27 saha arızası). `package:http`in varsayılanı SONSUZ bekler.
/// Mobilde yarı-açık TCP olağandır: wifi→mobil veri geçişi, otel/AVM captive portal'ı, operatör
/// NAT'ının bağlantıyı sessizce düşürmesi. Bu hâllerde soket ne kapanır ne veri gelir; istek
/// dakikalarca (pratikte sonsuza dek) asılı kalır. Asılı istek yalnız o turu değil, `SyncService`
/// meşgul bayrağını da kilitliyordu → senkron bir daha hiç ilerlemiyordu.
class HttpSyncApi implements SyncApi {
  HttpSyncApi({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
    this.zamanAsimi = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() tokenProvider;
  final http.Client _client;

  /// Tek isteğin üst sınırı. 25 sn: zayıf şebekede büyük snapshot sayfası inebilsin ama bayi
  /// "takıldı" hissetmeden önce tur bitsin (zamanlayıcı periyodu 2 dk, üst üste binmez).
  final Duration zamanAsimi;

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<PushResponse> push(List<Map<String, Object?>> events) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/sync/push'),
          headers: await _headers(),
          body: jsonEncode({'events': events}),
        )
        .timeout(zamanAsimi);
    if (res.statusCode != 200) {
      throw SyncApiException('push', res.statusCode, res.body);
    }
    return PushResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<PullResponse> pull({required int since, int limit = 500}) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/sync/pull?since=$since&limit=$limit'),
          headers: await _headers(),
        )
        .timeout(zamanAsimi);
    if (res.statusCode != 200) {
      throw SyncApiException('pull', res.statusCode, res.body);
    }
    return PullResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class SyncApiException implements Exception {
  SyncApiException(this.op, this.statusCode, this.body);
  final String op;
  final int statusCode;
  final String body;

  @override
  String toString() => 'SyncApiException($op: HTTP $statusCode)';
}
