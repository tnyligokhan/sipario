// Senkron DAYANIKLILIĞI — 2026-07-27 saha arızasının regresyon kilidi.
//
// BİLDİRİLEN BELİRTİ: "Alakasız yerde çevrim dışı diyor, programı kapatıp açınca senkronize
// ediyor." İki belirti, TEK kök neden zinciri:
//   1. `HttpSyncApi`de zaman aşımı yoktu → yarı-açık TCP'de istek sonsuza dek asılı kalıyordu.
//   2. `SyncService` meşguliyeti `bool _running` ile tutuyordu; asılı istekte `finally` hiç
//      çalışmadığı için bayrak sonsuza dek `true` kalıyor, zamanlayıcının HER turu
//      `if (_running) return` ile sessizce yutuluyordu → senkron bir daha ilerlemiyor.
//   3. Yutulan turlar durum akışına hiçbir şey yazmıyordu → gösterge son "başarısız" değerinde
//      DONUYORDU: cihaz çevrimiçiyken ekranda "Çevrimdışı" yazıyordu.
//   4. Bayrak da gösterge de BELLEKTEYDİ → kapatıp açmak ikisini birden sıfırlıyordu.
//
// Bu dosya dört davranışı kilitler: (a) hata sonrası döngü kendini toparlar, (b) asılı tur
// sonrakileri sonsuza dek kilitlemez, (c) Error (Exception değil) yutulmaz, (d) ağ geri gelince
// gösterge kendiliğinden düzelir.

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/home_shell.dart' show bantTuru;
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/theme/components/states.dart';

/// Davranışı test başına ayarlanabilen sahte taşıma. `FakeSyncApi` yalnız mutlu yolu kurar;
/// burada arızayı taklit etmek gerekiyor (fırlat / asılı kal / düzel).
///
/// SAYAÇ `pull` ÜZERİNDE: `pushPending` bekleyen outbox satırı yoksa sunucuya HİÇ gitmeden erken
/// döner, yani push çağrısı "tur koştu mu" sorusunun güvenilir ölçüsü değildir. `pull` her turda
/// koşulsuz çağrılır — tur sayacı odur.
class _ArizaliApi implements SyncApi {
  int turSayaci = 0;

  /// Tur başına davranış: null → başarı. Fırlatılacak nesne ya da asılı kalınacak Completer.
  Object? Function(int tur)? davranis;

  @override
  Future<PushResponse> push(List<Map<String, Object?>> events) async =>
      PushResponse(results: const [], currentSeq: 0);

  @override
  Future<PullResponse> pull({required int since, int limit = 500}) {
    turSayaci++;
    PullResponse basarili() =>
        PullResponse(mode: 'delta', cursor: since, hasMore: false, currentSeq: since);

    final d = davranis?.call(turSayaci);
    if (d is Completer<void>) return d.future.then((_) => basarili());
    if (d != null) return Future<PullResponse>.error(d);
    return Future<PullResponse>.value(basarili());
  }
}

Future<AppDatabase> _oturumluDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  // Token yoksa tur "Oturum yok" ile erken döner — arızayı taklit edemeyiz.
  await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
      .write(const SyncMetaCompanion(authToken: Value('test-token')));
  return db;
}

void main() {
  group('SyncService — hata sonrası döngü KENDİNİ TOPARLAR', () {
    test('başarısız tur sonrakini engellemez; ikinci tur sunucuya gerçekten gider', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _ArizaliApi()..davranis = (n) => n == 1 ? Exception('ağ yok') : null;
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final ilk = await sync.syncNow();
      expect(ilk.ok, isFalse, reason: 'ilk tur ağ hatasıyla düştü');

      final ikinci = await sync.syncNow();
      expect(ikinci.ok, isTrue, reason: 'ARIZA: meşgul bayrağı takılı kalırsa bu tur hiç koşmazdı');
      expect(api.turSayaci, 2, reason: 'ikinci tur sunucuya GERÇEKTEN gitti');
    });

    test('ağ geri gelince gösterge kendiliğinden düzelir (akış false→true yayınlar)', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _ArizaliApi()..davranis = (n) => n == 1 ? Exception('ağ yok') : null;
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final yayinlar = <bool>[];
      final sub = sync.status.listen((o) => yayinlar.add(o.ok));

      await sync.syncNow();
      await sync.syncNow();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(yayinlar, [false, true],
          reason: 'bant `_sonSenkron.ok`tan besleniyor; ikinci yayın gelmezse çevrimiçiyken '
              '"Çevrimdışı" yazmaya devam eder');
    });
  });

  group('SyncService — ASILI tur sonrakileri sonsuza dek kilitlemez', () {
    test('asılı istek biterken eşzamanlı çağrılar tek tura bağlanır, sonrası yeni tur açar',
        () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final asili = Completer<void>();
      final api = _ArizaliApi()..davranis = (n) => n == 1 ? asili : null;
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final a = sync.syncNow();
      final b = sync.syncNow();
      // Zamanlamadan bağımsız iddia: ikinci çağrı AYNI future'a bağlanır (çift tur koşmaz).
      expect(identical(a, b), isTrue,
          reason: 'eşzamanlı çağrı ikinci turu açmamalı — çift push/pull olurdu');

      asili.complete(); // istek nihayet döndü (gerçekte: zaman aşımı ya da geç yanıt)
      final sonuclar = await Future.wait([a, b]);
      expect(sonuclar.every((o) => o.ok), isTrue,
          reason: 'eşzamanlı çağıranın İKİSİ de turun gerçek sonucunu alır; '
              'eskiden ikincisi hiç koşmadan "ok: true" yalanını alıyordu');
      expect(api.turSayaci, 1, reason: 'iki çağrı tek tur');

      final ucuncu = await sync.syncNow();
      expect(ucuncu.ok, isTrue);
      expect(api.turSayaci, 2,
          reason: 'ARIZANIN TA KENDİSİ: tur bittikten sonra meşguliyet temizlenmezse '
              'bu tur hiç koşmaz ve senkron sonsuza dek durur');
    });
  });

  group('SyncService — Error (Exception DEĞİL) yutulmaz', () {
    test('TypeError sınıfı hata yakalanır, akışa yazılır ve döngü devam eder', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      // SyncEngine'deki `as String` / `as num` dönüşümleri beklenmedik payload'da TypeError atar.
      // TypeError bir Error'dur; eski `on Exception catch` onu YAKALAMIYORDU.
      final api = _ArizaliApi()..davranis = (n) => n == 1 ? ArgumentError('tip hatası') : null;
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final yayinlar = <SyncOutcome>[];
      final sub = sync.status.listen(yayinlar.add);

      final ilk = await sync.syncNow();
      expect(ilk.ok, isFalse, reason: 'Error de başarısız TUR sayılır, sessizce kaçmaz');

      final ikinci = await sync.syncNow();
      expect(ikinci.ok, isTrue);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(yayinlar.map((o) => o.ok), [false, true],
          reason: 'Error yutulursa akışa HİÇBİR ŞEY yazılmaz ve gösterge donar');
    });

    test('oturum yokken de akışa yayın yapılır (sessiz yol kalmadı)', () async {
      final db = AppDatabase(NativeDatabase.memory()); // token YOK
      addTearDown(db.close);
      final sync = SyncService(db, api: _ArizaliApi());
      addTearDown(sync.dispose);

      final yayinlar = <SyncOutcome>[];
      final sub = sync.status.listen(yayinlar.add);
      await sync.syncNow();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(yayinlar.single.ok, isFalse);
      expect(yayinlar.single.error, 'Oturum yok');
    });
  });

  group('Ağ tetiği — kapsama alanına girer girmez tur açılır', () {
    test('tetikleyici akışı olay yayınlayınca tur koşar (2 dk beklemeden)', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _ArizaliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final tetik = StreamController<void>();
      addTearDown(tetik.close);
      sync.tetikleyiciBagla(tetik.stream);
      expect(api.turSayaci, 0, reason: 'bağlamak tek başına tur açmaz');

      tetik.add(null); // "ağ geri geldi"
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(api.turSayaci, 1, reason: 'kurye kapsama alanına girdiği ANDA sipariş gitmeli');
    });

    test('tetik kaynağı hata yayınlarsa senkron DÜŞMEZ (eklenti yoksa/testte)', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _ArizaliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final tetik = StreamController<void>();
      addTearDown(tetik.close);
      sync.tetikleyiciBagla(tetik.stream);

      tetik.addError(Exception('MissingPluginException taklidi'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      tetik.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(api.turSayaci, 1,
          reason: 'hata abonelği düşürmemeli — tetik bir iyileştirmedir, senkronun şartı değil');
    });

    test('stop() tetikleyiciyi de bırakır (durdurulmuş servis tur açmaz)', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _ArizaliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final tetik = StreamController<void>();
      addTearDown(tetik.close);
      sync.tetikleyiciBagla(tetik.stream);
      sync.stop();

      tetik.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(api.turSayaci, 0, reason: 'çıkış yapıldıktan sonra ağ olayı senkron tetiklememeli');
    });
  });

  group('Hata CİNSİ — bant doğru gerçeği anlatsın', () {
    // SÖZLEŞME DEĞİŞTİ (2026-08-05): 401/403 dışındaki HER `SyncApiException` `ag` sayılıyordu,
    // yani 422 de 500 de "Çevrimdışı · bağlanınca gönderilecek" diyordu. `SyncApiException`
    // demek "sunucuya ULAŞTIK" demektir; ulaşılan bir sunucu için çevrimdışı yazmak yalandır ve
    // kalıcı-çevrimdışı arızasının aylarca görünmemesinin sebebi tam olarak buydu.
    test('401/403 OTURUM, kalıcı 4xx VERİ, 5xx/geçici 4xx SUNUCU, soket AĞ, Error VERİ', () {
      expect(SyncService.hataTuru(SyncApiException('pull', 401, '')), SyncHataTuru.oturum);
      expect(SyncService.hataTuru(SyncApiException('push', 403, '')), SyncHataTuru.oturum);

      expect(SyncService.hataTuru(SyncApiException('push', 422, '')), SyncHataTuru.veri,
          reason: 'sunucu bize ULAŞTI ve isteği geri çevirdi — "çevrimdışı" demek yalan');
      expect(SyncService.hataTuru(SyncApiException('pull', 404, '')), SyncHataTuru.veri);
      expect(SyncService.hataTuru(SyncApiException('push', 400, '')), SyncHataTuru.veri);

      expect(SyncService.hataTuru(SyncApiException('pull', 500, '')), SyncHataTuru.sunucu,
          reason: 'sunucu arızası oturumu geçersiz kılmaz ve ağ sorunu DEĞİLDİR — '
              'beklemek çözer ama bandın "çevrimdışısın" demesi kullanıcıyı wifi kurcalamaya '
              'yollardı');
      expect(SyncService.hataTuru(SyncApiException('push', 429, '')), SyncHataTuru.sunucu,
          reason: '429 geçicidir — karantina değil, bekleme');
      expect(SyncService.hataTuru(SyncApiException('push', 408, '')), SyncHataTuru.sunucu);

      expect(SyncService.hataTuru(TimeoutException('x')), SyncHataTuru.ag,
          reason: 'sunucuya HİÇ ulaşılamadı — çevrimdışı YALNIZ burada doğru');
      expect(SyncService.hataTuru(ArgumentError('x')), SyncHataTuru.veri,
          reason: 'Error = beklenmedik payload; ne ağ ne oturum');
    });

    test('422 turu bandı VERİ cinsine düşürür — "Çevrimdışı" METNİ ÇIKMAZ', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      // pull'dan gelen 422: push'un karantina yolu devrede değil, tur düşer.
      final api = _ArizaliApi()
        ..davranis = (n) => n == 1 ? SyncApiException('pull', 422, '') : null;
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final sonuc = await sync.syncNow();
      expect(sonuc.ok, isFalse);
      expect(sonuc.tur, SyncHataTuru.veri);
      expect(bantTuru(sonuc.tur), SipBantTuru.hata);
      expect(SipCevrimdisiBant(tur: bantTuru(sonuc.tur)).metin, isNot(contains('Çevrimdışı')),
          reason: 'sunucuya ulaşıldı; "çevrimdışı" demek arızayı GİZLER');
      expect(SipCevrimdisiBant(tur: bantTuru(sonuc.tur)).metin,
          isNot(contains('bağlantı gelince gönderilecek')),
          reason: 'tutulamayacak söz verilmez — bağlantı zaten var');
    });

    test('500 turu SUNUCU bandına düşer; "çevrimdışı" da "destekle görüşün" de demez', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _ArizaliApi()
        ..davranis = (n) => n == 1 ? SyncApiException('pull', 500, '') : null;
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final sonuc = await sync.syncNow();
      expect(sonuc.tur, SyncHataTuru.sunucu);
      final metin = SipCevrimdisiBant(tur: bantTuru(sonuc.tur)).metin;
      expect(metin, isNot(contains('Çevrimdışı')));
      expect(metin, contains('yeniden denenecek'),
          reason: '5xx geçicidir — kullanıcıdan bir eylem beklenmez');
    });

    test('401 turu bandı OTURUM cinsine düşürür (yanlış "bağlanınca gönderilecek" sözü verilmez)',
        () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _ArizaliApi()
        ..davranis = (n) => n == 1 ? SyncApiException('pull', 401, '') : null;
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final sonuc = await sync.syncNow();
      expect(sonuc.ok, isFalse);
      expect(sonuc.tur, SyncHataTuru.oturum);
    });

    test('oturum yokken de tur OTURUM cinsi taşır', () async {
      final db = AppDatabase(NativeDatabase.memory()); // token YOK
      addTearDown(db.close);
      final sync = SyncService(db, api: _ArizaliApi());
      addTearDown(sync.dispose);

      expect((await sync.syncNow()).tur, SyncHataTuru.oturum);
    });
  });

  group('HttpSyncApi — zaman aşımı ZORUNLU', () {
    test('yanıtlamayan sunucu turu sonsuza dek asmaz, TimeoutException atar', () async {
      // Yarı-açık TCP taklidi: istemci soketi açık sanır, sunucudan asla yanıt gelmez.
      final asla = MockClient((_) => Completer<http.Response>().future);
      final api = HttpSyncApi(
        baseUrl: 'https://ornek.test/api/v1',
        tokenProvider: () async => 'test-token',
        client: asla,
        zamanAsimi: const Duration(milliseconds: 50),
      );

      expect(() => api.pull(since: 0), throwsA(isA<TimeoutException>()));
      expect(() => api.push(const []), throwsA(isA<TimeoutException>()));
    });

    test('zaman aşımı Exception türüdür — SyncService onu normal ağ hatası gibi işler', () {
      // TimeoutException `Exception` implement eder; tur `ok: false` döner ve BİR SONRAKİ tur
      // koşabilir. Zaman aşımı olmadan bu Future hiç tamamlanmıyordu (arızanın 1. halkası).
      expect(TimeoutException('x'), isA<Exception>());
    });
  });
}
