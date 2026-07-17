import 'dart:async';

import '../auth/session.dart';
import '../data/app_database.dart';
import 'sync_api.dart';
import 'sync_engine.dart';

/// Bir senkron turunun özeti (UI durum çubuğu için).
class SyncOutcome {
  const SyncOutcome({required this.ok, this.pushed = 0, this.error});
  final bool ok;
  final int pushed;
  final String? error;
}

/// Senkron servisini oturuma bağlar ve periyodik koşturur. Motor (SyncEngine) saf kalır;
/// taban adres + token sync_meta'dan OKUNARAK verilir (login sonrası yeniden kurulum gerekmez).
///
/// Hata felsefesi: senkron hatası UYGULAMAYI DURDURMAZ (kırmızı çizgi #3 — offline'da her şey
/// çalışır); hata özetlenip durum akışına yazılır, sonraki tur yeniden dener (outbox zaten bekler).
class SyncService {
  SyncService(this.db) {
    _engine = SyncEngine(
      db,
      HttpSyncApi(
        // baseUrl her istekte değil KURULUŞTA okunur; login baseUrl'i değiştirirse restart()
        // çağrılır (login ekranı zaten uygulamanın kökünü yeniden kurar).
        baseUrl: _baseUrl ?? kDefaultApiBaseUrl,
        tokenProvider: () async => (await db.syncState()).authToken,
      ),
    );
  }

  final AppDatabase db;
  late SyncEngine _engine;
  String? _baseUrl;
  Timer? _timer;
  bool _running = false;

  final _status = StreamController<SyncOutcome>.broadcast();

  /// Son senkron sonuçlarının akışı (UI dinler; başarı/hata çubuğu).
  Stream<SyncOutcome> get status => _status.stream;

  /// Taban adresi sync_meta'dan okuyup motoru kurar; login sonrası ve açılışta çağrılır.
  Future<void> configure() async {
    final meta = await db.syncState();
    _baseUrl = Session.baseUrlOf(meta);
    _engine = SyncEngine(
      db,
      HttpSyncApi(
        baseUrl: _baseUrl!,
        tokenProvider: () async => (await db.syncState()).authToken,
      ),
    );
  }

  /// Tek senkron turu: önce push (bekleyen outbox), sonra pull (snapshot/delta).
  /// Eşzamanlı çift çağrı tek tura indirgenir.
  Future<SyncOutcome> syncNow() async {
    if (_running) return const SyncOutcome(ok: true);
    _running = true;
    try {
      final token = (await db.syncState()).authToken;
      if (token == null) return const SyncOutcome(ok: false, error: 'Oturum yok');

      final pushed = await _engine.pushPending();
      await _engine.pull();
      final outcome = SyncOutcome(ok: true, pushed: pushed);
      _status.add(outcome);
      return outcome;
    } on Exception catch (e) {
      // Ağ hatası normal işleyiştir (bodrum/asansör): kısa özet, PII yok (URL/istisna tipi yeter).
      final outcome = SyncOutcome(ok: false, error: e.runtimeType.toString());
      _status.add(outcome);
      return outcome;
    } finally {
      _running = false;
    }
  }

  /// Periyodik senkronu başlatır (varsayılan 2 dk — beklenen kopukluklar kısa, BRIEF).
  void start({Duration every = const Duration(minutes: 2)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => syncNow());
    // İlk turu hemen at (login/açılış sonrası veri gecikmesin).
    unawaited(syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _status.close();
  }
}
