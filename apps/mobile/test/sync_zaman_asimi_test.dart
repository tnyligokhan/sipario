// ZAMAN AŞIMI — taşımanın 25 sn'lik kapısı devreye girdiğinde ne olur?
//
// NEDEN BU DOSYA VAR (2026-08-05, `koken-avci` teşhisi): sahadaki "kalıcı çevrimdışı" olayının
// EN OLASI sebebi zehirli hap değil, YARI-AÇIK BAĞLANTIdır — telefon WiFi'ye bağlı görünürken
// o ağ internet vermiyor, soket ne kapanıyor ne veri geliyor. `HttpSyncApi` bunu 25 sn'lik
// `.timeout()` ile kesiyor ve `TimeoutException` fırlatıyor.
//
// O istisna `SyncApiException` DEĞİLDİR, yani `_partiGonder`in `on SyncApiException` bloğuna
// GİRMEZ: tur düşer, kayıtlar `pending` kalır, sonraki tur yeniden dener. Bu DOĞRU davranıştır
// (timeout geçicidir; "bu kayıt bozuk" demek değildir) ama hiçbir test onu kilitlemiyordu —
// yani bir gün `on Exception` yazan biri, zaman aşımını sessizce karantina yoluna sokabilirdi:
// ağı kötü olan bayinin siparişleri, hiçbir şeyi bozuk olmadığı hâlde `rejected` olurdu.
//
// Kilitlenen dört şey: (a) cins `ag`dır (bant "çevrimdışı" der ve bu SEFER doğrudur),
// (b) `attempts` ARTMAZ (karantina eşiğine yaklaştırmaz), (c) BÖLME TETİKLENMEZ (kararsız
// şebekede istek fırtınası olmaz), (d) bölme ORTASINDA gelen zaman aşımı, o ana kadar teslim
// edilmiş yarıyı geri almaz.

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/outbox.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';
import 'package:sipario/sync/sync_service.dart';

/// Push davranışı ÇAĞRI SIRASINA göre ayarlanabilen sahte taşıma: bölme sırasında hangi alt
/// partinin düşeceğini kurmak için gerekiyor (FakeSyncApi tek davranış tutar).
class _SiraliApi implements SyncApi {
  _SiraliApi(this.davranis);

  /// Çağrı sırası (1'den) + gönderilen olaylar → fırlatılacak nesne; null ise hepsi 'applied'.
  final Object? Function(int sira, List<Map<String, Object?>> events) davranis;

  int cagriSayisi = 0;
  final List<List<Map<String, Object?>>> partiler = [];

  @override
  Future<PushResponse> push(List<Map<String, Object?>> events) async {
    cagriSayisi++;
    partiler.add(events);
    final d = davranis(cagriSayisi, events);
    if (d != null) throw d;

    var seq = 0;
    return PushResponse(
      results: [
        for (final e in events)
          EventResult(
            clientEventId: e['client_event_id'] as String?,
            status: 'applied',
            serverSeq: ++seq,
          ),
      ],
      currentSeq: seq,
    );
  }

  @override
  Future<PullResponse> pull({required int since, int limit = 500}) async =>
      PullResponse(mode: 'delta', cursor: since, hasMore: false, currentSeq: since);
}

Future<AppDatabase> _oturumluDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
      .write(const SyncMetaCompanion(authToken: Value('test-token')));
  return db;
}

Future<void> _kuyrugaEkle(AppDatabase db, String entityId, String saat) => enqueueOutbox(
      db,
      entityType: 'customer',
      op: 'upsert',
      entityId: entityId,
      occurredAt: '2026-08-05T10:00:$saat',
      deviceId: 'd-1',
      payload: {'id': entityId, 'name': 'Müşteri $entityId'},
    );

void main() {
  group('push zaman aşımı — geçici hatadır, karantina DEĞİL', () {
    test('tur `ag` ile düşer; kayıtlar pending kalır ve attempts ARTMAZ', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      await _kuyrugaEkle(db, 'm-1', '01');
      await _kuyrugaEkle(db, 'm-2', '02');

      final api = _SiraliApi((_, _) => TimeoutException('yarı-açık bağlantı'));
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final sonuc = await sync.syncNow();

      expect(sonuc.ok, isFalse);
      expect(sonuc.tur, SyncHataTuru.ag,
          reason: 'sunucuya HİÇ ulaşılamadı — "çevrimdışı" demek burada doğrudur');
      expect(sonuc.karantina, 0, reason: 'zaman aşımı "bu kayıt bozuk" demek DEĞİLDİR');

      final satirlar = await db.select(db.outbox).get();
      expect(satirlar.map((r) => r.status).toSet(), {'pending'},
          reason: 'kayıtlar SIRADA kalmalı — kaybolmuş da değil, reddedilmiş de değil');
      expect(satirlar.map((r) => r.attempts).toSet(), {0},
          reason: 'ARIZA: attempts artarsa ağı kötü olan bayi 3 turda karantinaya sürüklenir');
    });

    test('BÖLME TETİKLENMEZ — kararsız şebekede istek fırtınası olmaz', () async {
      // Bölme yalnız KALICI 4xx'te doğru: "sunucu bu partiyi kabul etmiyor, suçluyu bulalım".
      // Zaman aşımında bölmek, ulaşılamayan bir sunucuya log₂n kat daha fazla istek atmak olurdu.
      final db = await _oturumluDb();
      addTearDown(db.close);
      for (var i = 1; i <= 8; i++) {
        await _kuyrugaEkle(db, 'm-$i', i.toString().padLeft(2, '0'));
      }

      final api = _SiraliApi((_, _) => TimeoutException('yarı-açık bağlantı'));

      await expectLater(
        SyncEngine(db, api).pushPending(),
        throwsA(isA<TimeoutException>()),
        reason: 'zaman aşımı motordan YUKARI fırlar; servis onu `ag` cinsine çevirir',
      );
      expect(api.cagriSayisi, 1, reason: 'ARIZA: bölme tetiklenirse 8 olay için istek sayısı patlar');
    });

    test('kalıcı 4xx bölmeyi TETİKLER — ayrımın kendisi kilitleniyor', () async {
      // Yukarıdaki testin karşı kutbu: bölme YOK OLMADI, yalnız doğru cinse bağlı.
      final db = await _oturumluDb();
      addTearDown(db.close);
      await _kuyrugaEkle(db, 'm-1', '01');
      await _kuyrugaEkle(db, 'm-2', '02');

      final api = _SiraliApi((sira, _) => sira == 1 ? SyncApiException('push', 422, '{}') : null);
      final ozet = await SyncEngine(db, api).pushPending();

      expect(api.cagriSayisi, 3, reason: 'tam parti + iki yarı');
      expect(ozet.gonderildi, 2, reason: 'her iki masum olay AYNI turda teslim edildi');
    });
  });

  group('bölme ORTASINDA zaman aşımı', () {
    test('teslim edilmiş yarı KORUNUR, kalanlar pending; sonraki tur yalnız kalanı yollar',
        () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      await _kuyrugaEkle(db, 'm-1', '01');
      await _kuyrugaEkle(db, 'm-2', '02');

      // 1: tam parti → 422 (bölme başlar) · 2: ilk yarı → başarılı · 3: ikinci yarı → timeout
      final api = _SiraliApi((sira, _) => switch (sira) {
            1 => SyncApiException('push', 422, '{}'),
            3 => TimeoutException('bölmenin ortasında bağlantı düştü'),
            _ => null,
          });

      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final sonuc = await sync.syncNow();
      expect(sonuc.ok, isFalse);
      expect(sonuc.tur, SyncHataTuru.ag);

      final satirlar = await db.select(db.outbox).get();
      final ilk = satirlar.firstWhere((r) => r.entityId == 'm-1');
      final ikinci = satirlar.firstWhere((r) => r.entityId == 'm-2');
      expect(ilk.status, 'acked',
          reason: 'TESLİM EDİLMİŞ yarı geri alınmamalı — outbox yazımı zaten commit oldu');
      expect(ikinci.status, 'pending', reason: 'ulaşamadığımız yarı SIRADA kalmalı');

      // Sonraki tur: `pushPending` yalnız `pending` seçer, yani acked olan m-1 BİR DAHA
      // gönderilmez. Yeniden gönderilse de zararsız olurdu (idempotency `client_event_id`de)
      // ama boşuna trafik de doğmuyor.
      final ikinciTur = await sync.syncNow();
      expect(ikinciTur.ok, isTrue);
      expect(api.partiler.last.map((e) => (e['payload']! as Map)['id']), ['m-2'],
          reason: 'ARIZA: teslim edilmiş kayıt yeniden yollanıyorsa tur boşa gidiyor demektir');
    });
  });
}
