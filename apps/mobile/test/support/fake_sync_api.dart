import 'package:sipario/sync/sync_api.dart';

/// Ağsız test için sahte SyncApi. Gönderilen partileri yakalar; push/pull yanıtları yapılandırılır.
class FakeSyncApi implements SyncApi {
  final List<List<Map<String, Object?>>> pushedBatches = [];
  final List<PullResponse> pullQueue = [];
  String? serverTime;

  /// Özel push yanıtı; null ise varsayılan olarak tüm olaylar 'applied' + artan seq.
  PushResponse Function(List<Map<String, Object?>> events)? pushHandler;

  @override
  Future<PushResponse> push(List<Map<String, Object?>> events) async {
    pushedBatches.add(events);
    if (pushHandler != null) return pushHandler!(events);

    var seq = 0;
    final results = events
        .map((e) => EventResult(
              clientEventId: e['client_event_id'] as String,
              status: 'applied',
              serverSeq: ++seq,
            ))
        .toList();
    return PushResponse(results: results, currentSeq: seq, serverTime: serverTime);
  }

  @override
  Future<PullResponse> pull({required int since, int limit = 500}) async {
    if (pullQueue.isEmpty) {
      return PullResponse(mode: 'delta', cursor: since, hasMore: false, currentSeq: since);
    }
    return pullQueue.removeAt(0);
  }
}
