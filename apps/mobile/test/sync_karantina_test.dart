// KARANTİNA — "kalıcı çevrimdışı" arızasının istemci tarafındaki regresyon kilidi (2026-08-05).
//
// SAHADA YAŞANAN: bayinin telefonu kalıcı çevrimdışı kalıyordu ve destek ekibinin verebileceği
// TEK tavsiye "uygulama verisini temizle"ydi — ki bu outbox'ı da siler, yani gönderilmemiş
// sipariş/tahsilat KAYBOLUR (BRIEF kırmızı çizgi #3 ihlali).
//
// ZİNCİR: outbox'ta sunucunun kabul etmediği bir olay var → sunucu TÜM partiyi 422 yapıyor →
// `api.push` fırlatıyor → işaretleme kodu hiç çalışmıyor → hiçbir olay acked/rejected olmuyor →
// bant "Çevrimdışı" diyor → sonraki tur AYNI partiyi yolluyor → sonsuz döngü.
//
// Sunucu tarafı ayrıca düzeltiliyor (per-olay doğrulama). Bu dosya İSTEMCİNİN kendi başına
// dayanıklı olduğunu kilitler: yarın başka bir sebeple parti düzeyinde 4xx gelirse kilit
// tekrarlanmamalı. Dört sözleşme:
//   (a) kalıcı 4xx kuyruğu kilitlemez — masum olaylar AYNI turda akar,
//   (b) suçlu eşikten sonra karantinaya alınır ve bir daha yollanmaz,
//   (c) karantina SİLME DEĞİLDİR — kayıt, payload'ı ve kimliğiyle yerinde durur,
//   (d) 5xx / geçici 4xx / oturum / ağ hataları karantinaya ALINMAZ, yeniden denenir.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/outbox.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/states.dart';

import 'support/fake_sync_api.dart';

/// Zehirli hap taklidi: partide [zehirli] kimliklerden BİRİ varsa sunucu TÜM partiyi reddeder.
/// Gerçek arızanın davranışı tam olarak buydu — tek bozuk olay bütün partiyi düşürüyordu.
class _ZehirliApi implements SyncApi {
  _ZehirliApi({this.zehirli = const {}, this.durum = 422});

  final Set<String> zehirli;

  /// Reddin HTTP durumu. 422/400/404 kalıcı; 500/503/429/408 geçici; 401/403 oturum.
  final int durum;

  /// Sunucuya giden her partinin client_event_id listesi (kaç istek atıldığının kanıtı).
  final List<List<String>> partiler = [];

  @override
  Future<PushResponse> push(List<Map<String, Object?>> events) async {
    final ids = [for (final e in events) e['client_event_id'] as String];
    partiler.add(ids);
    if (ids.any(zehirli.contains)) {
      throw SyncApiException('push', durum, 'olay kabul edilmedi: sema hatasi');
    }
    return PushResponse(
      results: [for (final id in ids) EventResult(clientEventId: id, status: 'applied')],
      currentSeq: ids.length,
    );
  }

  @override
  Future<PullResponse> pull({required int since, int limit = 500}) async =>
      PullResponse(mode: 'delta', cursor: since, hasMore: false, currentSeq: since);
}

/// Ağ katmanı hiç yanıt veremeden düşerse (soket/zaman aşımı) — `SyncApiException` DEĞİL.
class _AgsizApi implements SyncApi {
  int denemeler = 0;

  @override
  Future<PushResponse> push(List<Map<String, Object?>> events) async {
    denemeler++;
    throw const SocketException('ağ yok');
  }

  @override
  Future<PullResponse> pull({required int since, int limit = 500}) async =>
      PullResponse(mode: 'delta', cursor: since, hasMore: false, currentSeq: since);
}

Future<void> _olayEkle(AppDatabase db, String id) => enqueueOutbox(
      db,
      entityType: 'customer',
      op: 'upsert',
      entityId: id,
      clientEventId: id,
      payload: {'id': id, 'name': 'Müşteri $id'},
      occurredAt: '2026-08-05T10:00:00.000Z',
      deviceId: 'cihaz-1',
    );

Future<OutboxData> _satir(AppDatabase db, String clientEventId) =>
    (db.select(db.outbox)..where((t) => t.clientEventId.equals(clientEventId))).getSingle();

Future<Map<String, String>> _durumlar(AppDatabase db) async {
  final rows = await db.select(db.outbox).get();
  return {for (final r in rows) r.clientEventId: r.status};
}

Widget _sar(Widget child) => MaterialApp(theme: SipTheme.acik(), home: Scaffold(body: child));

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('Parti düzeyinde KALICI 4xx — kuyruk kilitlenmez', () {
    test('masum olaylar AYNI turda akar, yalnız suçlu geride kalır', () async {
      await _olayEkle(db, 'iyi-1');
      await _olayEkle(db, 'zehir');
      await _olayEkle(db, 'iyi-2');
      final api = _ZehirliApi(zehirli: {'zehir'});

      final ozet = await SyncEngine(db, api).pushPending();

      expect(await _durumlar(db), {
        'iyi-1': 'acked',
        'zehir': 'pending',
        'iyi-2': 'acked',
      }, reason: 'ARIZANIN TA KENDİSİ: eskiden parti fırlıyor ve HİÇBİRİ işaretlenmiyordu');
      expect(ozet.kaliciRed, isTrue,
          reason: 'tur "başarılı" görünemez — sunucu bir kaydı geri çevirdi');
      expect(ozet.karantina, 0,
          reason: 'İLK redde karantina YOK: zarf hatası masum bir kaydı yakmamalı');
      expect((await _satir(db, 'zehir')).attempts, 1);
    });

    test('sonraki tur ilerler: kuyruğa giren yeni olay suçluya rağmen gider', () async {
      await _olayEkle(db, 'zehir');
      final api = _ZehirliApi(zehirli: {'zehir'});
      final engine = SyncEngine(db, api);

      await engine.pushPending();
      await _olayEkle(db, 'yeni-siparis');
      await engine.pushPending();

      expect((await _durumlar(db))['yeni-siparis'], 'acked',
          reason: 'tek bozuk olay bütün kuyruğu REHİN ALAMAZ');
    });

    test('eşikte karantina: olay artık HİÇ gönderilmez (sonsuz döngü kırıldı)', () async {
      await _olayEkle(db, 'zehir');
      final api = _ZehirliApi(zehirli: {'zehir'});
      final engine = SyncEngine(db, api);

      for (var tur = 0; tur < SyncEngine.karantinaEsigi; tur++) {
        await engine.pushPending();
      }

      final satir = await _satir(db, 'zehir');
      expect(satir.status, 'rejected');
      expect(satir.attempts, SyncEngine.karantinaEsigi);

      final oncekiIstek = api.partiler.length;
      final ozet = await engine.pushPending();
      expect(api.partiler.length, oncekiIstek,
          reason: 'karantinadaki olay bir daha YOLLANMAZ — sonsuz tekrar burada biter');
      expect(ozet.kaliciRed, isFalse, reason: 'gönderilecek bir şey kalmadı, tur temiz');
    });

    test('500 olayda tek suçluyu ikili arama makul sayıda istekte bulur', () async {
      for (var i = 0; i < 60; i++) {
        await _olayEkle(db, 'olay-${i.toString().padLeft(3, '0')}');
      }
      await _olayEkle(db, 'zehir');
      final api = _ZehirliApi(zehirli: {'zehir'});

      await SyncEngine(db, api).pushPending();

      final durumlar = await _durumlar(db);
      expect(durumlar.values.where((s) => s == 'acked'), hasLength(60),
          reason: '60 masum olayın hepsi AYNI turda teslim edildi');
      expect(durumlar['zehir'], 'pending');
      expect(api.partiler.length, lessThanOrEqualTo(25),
          reason: 'tek tek gönderseydik 61 istek olurdu; bölme ~2·log₂n eder');
    });
  });

  group('VERİ KAYBI YOK — karantina silme değildir', () {
    test('karantinadaki kayıt payload/kimlik/zamanıyla yerinde durur', () async {
      await _olayEkle(db, 'zehir');
      final once = await _satir(db, 'zehir');
      final engine = SyncEngine(db, _ZehirliApi(zehirli: {'zehir'}));

      for (var tur = 0; tur < SyncEngine.karantinaEsigi; tur++) {
        await engine.pushPending();
      }

      expect(await db.select(db.outbox).get(), hasLength(1),
          reason: 'satır SİLİNMEDİ — kırmızı çizgi #3');
      final sonra = await _satir(db, 'zehir');
      expect(sonra.id, once.id);
      expect(sonra.payload, once.payload, reason: 'payload dokunulmadı, elle kurtarılabilir');
      expect(jsonDecode(sonra.payload), {'id': 'zehir', 'name': 'Müşteri zehir'});
      expect(sonra.clientEventId, once.clientEventId);
      expect(sonra.occurredAt, once.occurredAt);
      expect(sonra.entityType, once.entityType);
      expect(sonra.lastError, isNotNull, reason: 'destek NEDEN reddedildiğini görebilmeli');
      expect(sonra.lastError, contains('422'));
    });

    test('karantina sayısı AKIŞTAN okunur (uyarı tur bitince kaybolmaz)', () async {
      await _olayEkle(db, 'zehir');
      final engine = SyncEngine(db, _ZehirliApi(zehirli: {'zehir'}));
      expect(await db.watchKarantinaSayisi().first, 0);

      for (var tur = 0; tur < SyncEngine.karantinaEsigi; tur++) {
        await engine.pushPending();
      }

      expect(await db.watchKarantinaSayisi().first, 1,
          reason: 'kayıt cihazda durduğu SÜRECE bant durmalı');
    });
  });

  group('GEÇİCİ hatalar karantinaya ALINMAZ', () {
    for (final durum in [500, 503, 429, 408]) {
      test('HTTP $durum: fırlatır, olay pending kalır, deneme sayısı ARTMAZ', () async {
        await _olayEkle(db, 'olay');
        final api = _ZehirliApi(zehirli: {'olay'}, durum: durum);
        final engine = SyncEngine(db, api);

        await expectLater(engine.pushPending(), throwsA(isA<SyncApiException>()),
            reason: 'geçici hata TURU düşürmeli — bant gerçeği söylesin, motor susmasın');

        final satir = await _satir(db, 'olay');
        expect(satir.status, 'pending');
        expect(satir.attempts, 0, reason: 'sunucu "bu kayıt bozuk" demedi, "şu an olmaz" dedi');
        expect(api.partiler, hasLength(1), reason: 'geçicide BÖLME yapılmaz — boşuna istek');
      });
    }

    test('geçici hata kaç tur sürerse sürsün karantina AÇILMAZ', () async {
      await _olayEkle(db, 'olay');
      final engine = SyncEngine(db, _ZehirliApi(zehirli: {'olay'}, durum: 503));

      for (var tur = 0; tur < 10; tur++) {
        await expectLater(engine.pushPending(), throwsA(isA<SyncApiException>()));
      }

      expect((await _satir(db, 'olay')).status, 'pending',
          reason: 'sunucu arızası saatlerce sürebilir; kayıt düzelince gitmeli');
      expect(await db.watchKarantinaSayisi().first, 0);
    });

    for (final durum in [401, 403]) {
      test('HTTP $durum (oturum): karantina YOK — kayıt bozuk değil, oturum bozuk', () async {
        await _olayEkle(db, 'olay');
        final engine = SyncEngine(db, _ZehirliApi(zehirli: {'olay'}, durum: durum));

        await expectLater(engine.pushPending(), throwsA(isA<SyncApiException>()));
        final satir = await _satir(db, 'olay');
        expect(satir.status, 'pending');
        expect(satir.attempts, 0);
      });
    }

    test('ağ hatası (soket): karantina YOK, sonraki tur yeniden dener', () async {
      await _olayEkle(db, 'olay');
      final api = _AgsizApi();
      final engine = SyncEngine(db, api);

      await expectLater(engine.pushPending(), throwsA(isA<SocketException>()));
      await expectLater(engine.pushPending(), throwsA(isA<SocketException>()));

      expect(api.denemeler, 2, reason: 'ağ geri gelince gitmeli — kayıt vazgeçilmiş değil');
      expect((await _satir(db, 'olay')).status, 'pending');
    });
  });

  group('REGRESYON — sunucunun per-olay sözleşmesi', () {
    test('tek olay rejected dönerse diğerleri acked olur ve kuyruk boşalır', () async {
      await _olayEkle(db, 'iyi-1');
      await _olayEkle(db, 'kotu');
      await _olayEkle(db, 'iyi-2');
      // Sunucunun düzeltilmiş davranışı: parti 200 geçer, bozuk olay `rejected` gelir.
      final api = FakeSyncApi()
        ..pushHandler = (events) => PushResponse(
              currentSeq: events.length,
              results: [
                for (final e in events)
                  EventResult(
                    clientEventId: e['client_event_id'] as String,
                    status: e['client_event_id'] == 'kotu' ? 'rejected' : 'applied',
                    reason: e['client_event_id'] == 'kotu' ? 'payload.name bos olamaz' : null,
                  ),
              ],
            );

      final ozet = await SyncEngine(db, api).pushPending();

      expect(await _durumlar(db), {
        'iyi-1': 'acked',
        'kotu': 'rejected',
        'iyi-2': 'acked',
      });
      expect(ozet.gonderildi, 3);
      expect(ozet.karantina, 1);
      expect(ozet.kaliciRed, isTrue, reason: 'reddedilen kayıt sunucuya ULAŞMADI — bant sussa '
          'o sipariş sessizce cihazda kalırdı');
      expect(api.pushedBatches, hasLength(1), reason: 'parti 200 geçtiği için BÖLME gerekmez');
    });

    test('sunucunun sebep alanı outbox.last_error\'a yazılır (yoksa genel metin)', () async {
      await _olayEkle(db, 'sebepli');
      await _olayEkle(db, 'sebepsiz');
      final api = FakeSyncApi()
        ..pushHandler = (events) => PushResponse(
              currentSeq: events.length,
              results: [
                for (final e in events)
                  EventResult(
                    clientEventId: e['client_event_id'] as String,
                    status: 'rejected',
                    reason: e['client_event_id'] == 'sebepli' ? 'entity_type bilinmiyor' : null,
                  ),
              ],
            );

      await SyncEngine(db, api).pushPending();

      expect((await _satir(db, 'sebepli')).lastError, 'entity_type bilinmiyor');
      expect((await _satir(db, 'sebepsiz')).lastError, 'sunucu reddetti');
    });

    test('sebep alanı String değilse senkron DÜŞMEZ (adı henüz kesinleşmedi)', () {
      // Sunucu `reason`ı nesne olarak gönderirse `as String?` TypeError atar ve TÜM tur düşerdi.
      // Sebep bir KOLAYLIKTIR; senkronu düşürmeye yetkisi yok.
      final res = EventResult.fromJson({
        'client_event_id': 'x',
        'status': 'rejected',
        'reason': {'kod': 42},
        'message': 'okunabilir sebep',
      });
      expect(res.reason, 'okunabilir sebep');
      expect(res.status, 'rejected');
    });
  });

  group('BANT — neye ulaşamadığını söylesin', () {
    test('bantAdresi ana bilgisayarı verir, tam URL\'i değil', () {
      expect(bantAdresi('https://api.sipario.com.tr/api/v1'), 'api.sipario.com.tr');
      expect(bantAdresi('https://tunel-3f2a.trycloudflare.com/api/v1'),
          'tunel-3f2a.trycloudflare.com');
      expect(bantAdresi('http://192.168.1.5:8000/api/v1'), '192.168.1.5:8000',
          reason: 'yerel/tünel kurulumunda PORT da ayırt edici');
      expect(bantAdresi(null), isNull);
      expect(bantAdresi('  '), isNull);
      expect(bantAdresi('bozuk adres'), 'bozuk adres',
          reason: 'çözülemeyen adresin kendisi zaten aranan kanıttır');
    });

    testWidgets('bant hangi sunucuya ulaşmaya çalıştığını YAZAR', (tester) async {
      await tester.pumpWidget(_sar(
        const SipCevrimdisiBant(adres: 'tunel-3f2a.trycloudflare.com'),
      ));
      expect(find.textContaining('tunel-3f2a.trycloudflare.com'), findsOneWidget,
          reason: 'adres her açılışta değişen bir tünel; bant yazmazsa bayi yanlış adresle '
              'kalır ve arıza ancak telefonu inceleyen biriyle bulunur');
    });

    testWidgets('adres verilmezse satır hiç çizilmez', (tester) async {
      await tester.pumpWidget(_sar(const SipCevrimdisiBant()));
      expect(find.textContaining('sunucu:'), findsNothing);
    });

    testWidgets('veri hatası bandında "çevrimdışı" METNİ ÇIKMAZ', (tester) async {
      await tester.pumpWidget(_sar(const SipCevrimdisiBant(tur: SipBantTuru.hata)));
      expect(find.textContaining('Çevrimdışı'), findsNothing);
      expect(find.textContaining('bağlanınca gönderilecek'), findsNothing,
          reason: 'sunucuya ULAŞILDI — tutulamayacak bir söz vermek arızayı gizler');
      expect(find.textContaining('cihazda güvende'), findsOneWidget);
    });

    testWidgets('karantina bandı kaydın cihazda DURDUĞUNU söyler, kayıp demez', (tester) async {
      await tester.pumpWidget(_sar(const SipCevrimdisiBant(tur: SipBantTuru.karantina)));
      expect(find.textContaining('Çevrimdışı'), findsNothing);
      expect(find.textContaining('cihazda duruyor'), findsOneWidget);
      expect(find.textContaining('destekle görüşün'), findsOneWidget);
    });

    testWidgets('sunucu bandı geçici olduğunu söyler, kullanıcıdan eylem beklemez',
        (tester) async {
      await tester.pumpWidget(_sar(const SipCevrimdisiBant(tur: SipBantTuru.sunucu)));
      expect(find.textContaining('Çevrimdışı'), findsNothing);
      expect(find.textContaining('otomatik yeniden denenecek'), findsOneWidget);
    });

    // KABUĞA BAĞLI MI: bandı doğru kurmak yetmez, birinin onu ÇİZMESİ gerekir. Güncelleme
    // bandı aylarca ağaca hiç bağlanmamıştı ve hiçbir saf-fonksiyon testi bunu göremezdi.
    testWidgets('KABUK: karantinadaki kayıt varken bant çizilir ve sunucuyu yazar',
        (tester) async {
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        const SyncMetaCompanion(
          apiBaseUrl: Value('https://tunel-3f2a.trycloudflare.com/api/v1'),
        ),
      );
      await _olayEkle(db, 'zehir');
      final engine = SyncEngine(db, _ZehirliApi(zehirli: {'zehir'}));
      for (var tur = 0; tur < SyncEngine.karantinaEsigi; tur++) {
        await engine.pushPending();
      }

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: SipTheme.acik(),
        home: HomeShell(
          db: db,
          session: Session(db),
          sync: SyncService(db), // start() çağrılmaz: ağ/timer yok
          onLoggedOut: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SipCevrimdisiBant), findsOneWidget,
          reason: 'senkron turu hiç düşmese bile karantina uyarısı ekranda DURMALI — '
              'kayıt cihazda, sunucuda yok');
      expect(find.textContaining('cihazda duruyor'), findsOneWidget);
      expect(find.textContaining('tunel-3f2a.trycloudflare.com'), findsOneWidget,
          reason: 'bayi hangi sunucuya gönderemediğini görmeli');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
