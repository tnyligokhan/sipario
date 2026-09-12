// SAYFALI İLK SENKRON + KURTARMA — 2026-09-12 saha arızasının gerileme bekçisi.
//
// YAŞANAN: bir bayiye 9.047 müşteri aktarıldı. Yeni giriş yapan telefon `since=0` ile SNAPSHOT
// istiyor; sunucu bunu TEK PARÇA üretiyordu (ölçüldü: 15,3 MB / 8,5 sn) ve istemcinin 25
// saniyelik zaman aşımına sığmıyordu. Sonuç: panelde 9.047 müşteri ve 6 ürün, telefonda bir avuç.
//
// ⚠️ ARIZAYI KALICI KILAN ŞEY SNAPSHOT'IN BÜYÜKLÜĞÜ DEĞİL, İMLECİN ERKEN DAMGALANMASIYDI:
// `_applySnapshot` her çağrıda `lastPulledSeq`i kiracının GÜNCEL seq'ine yazıyordu. Sayfalı bir
// snapshot'ta ilk sayfada damgalamak, kalan 30.000 satırı BİR DAHA hiç istememek demektir —
// telefon "her şeyi çektim" sanır, sunucu boş delta döndürür ve veri asla gelmez.
//
// Bu dosya üç şeyi kilitler: (1) sayfalar sonuna kadar gezilir, (2) damga YALNIZ son sayfada
// vurulur, (3) sıkışmış bir cihaz `bastanIndir()` ile kurtarılabilir.

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';

import 'support/fake_sync_api.dart';

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine motor;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    motor = SyncEngine(db, api);
  });

  tearDown(() => db.close());

  Map<String, dynamic> musteri(String id, String ad) => {
        'id': id,
        'name': ad,
        'updated_occurred_at': '2026-09-12T10:00:00.000000Z',
      };

  Map<String, dynamic> urun(String id, String ad) => {
        'id': id,
        'name': ad,
        'unit_price_kurus': 0,
        'unit': 'adet',
        'is_active': true,
        'updated_occurred_at': '2026-09-12T10:00:00.000000Z',
      };

  PullResponse sayfa({
    required Map<String, List<Map<String, dynamic>>> varliklar,
    required bool devamVar,
    String? imlec,
    int cursor = 900,
  }) =>
      PullResponse(
        mode: 'snapshot',
        cursor: cursor,
        hasMore: devamVar,
        currentSeq: cursor,
        entities: varliklar,
        snapshotImleci: imlec,
      );

  Future<int> imlecOku() async => (await db.syncState()).lastPulledSeq;

  group('Sayfalı snapshot', () {
    test('bütün sayfalar gezilir ve HİÇBİR satır düşmez', () async {
      api.pullQueue.addAll([
        sayfa(varliklar: {
          'customer': [musteri('m1', 'Bir'), musteri('m2', 'İki')]
        }, devamVar: true, imlec: 'customer:m2'),
        sayfa(varliklar: {
          'customer': [musteri('m3', 'Üç')],
          'product': [urun('u1', 'Tombul Tüp')],
        }, devamVar: true, imlec: 'product:u1'),
        sayfa(varliklar: {
          'product': [urun('u2', 'Madran Su')]
        }, devamVar: false),
      ]);

      final atlanan = await motor.pull();

      expect(atlanan, 0);
      expect(await db.select(db.customers).get(), hasLength(3));
      expect(await db.select(db.products).get(), hasLength(2),
          reason: 'Ürünler müşterilerin ARDINDAN gelir; erken duran döngü onları düşürürdü.');
    });

    test('İMLEÇ YALNIZ SON SAYFADA damgalanır — arızanın çekirdeği', () async {
      api.pullQueue.addAll([
        sayfa(varliklar: {
          'customer': [musteri('m1', 'Bir')]
        }, devamVar: true, imlec: 'customer:m1', cursor: 31183),
        sayfa(varliklar: {
          'customer': [musteri('m2', 'İki')]
        }, devamVar: false, cursor: 31183),
      ]);

      await motor.pull();

      expect(await imlecOku(), 31183);
      expect(await db.select(db.customers).get(), hasLength(2));
    });

    test('yarıda kopan snapshot imleci İLERLETMEZ — sonraki tur baştan çeker', () async {
      // Ağ koparsa ikinci sayfa hiç gelmez. İmleç 0'da kalmalı ki senkron snapshot'ı BAŞTAN
      // alsın; ilerleseydi kalan satırlar bir daha HİÇ gelmezdi (sahada yaşanan tam olarak bu).
      api.pullQueue.add(sayfa(varliklar: {
        'customer': [musteri('m1', 'Bir')]
      }, devamVar: true, imlec: 'customer:m1', cursor: 31183));

      await motor.pull(maxPages: 1); // ikinci sayfaya hiç gidilmesin

      expect(await imlecOku(), 0, reason: 'Yarım snapshot TAMAMLANMIŞ sayılamaz.');
      expect(await db.select(db.customers).get(), hasLength(1),
          reason: 'Gelen satırlar yine de yazılır — tekrar çekildiğinde üstüne yazılacak.');
    });

    test('imleç sunucuya geri gönderilir ve ilk sayfada BOŞ olur', () async {
      api.pullQueue.addAll([
        sayfa(varliklar: {
          'customer': [musteri('m1', 'Bir')]
        }, devamVar: true, imlec: 'customer:m1'),
        sayfa(varliklar: const {}, devamVar: false),
      ]);

      await motor.pull();

      expect(api.pullCagrilari[0].snapshotImleci, '',
          reason: 'İlk sayfa boş imleçle istenir — yetenek bildirimi bayrakla taşınır.');
      expect(api.pullCagrilari[1].snapshotImleci, 'customer:m1');
    });

    test('delta turunda snapshot imleci GÖNDERİLMEZ', () async {
      // İmleci sıfırdan büyük bir `since` ile göndermek sunucuyu snapshot moduna sokabilirdi.
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(lastPulledSeq: Value(500)));
      api.pullQueue.add(PullResponse(
          mode: 'delta', cursor: 500, hasMore: false, currentSeq: 500, changes: const []));

      await motor.pull();

      expect(api.pullCagrilari.single.snapshotImleci, isNull);
    });

    test('ESKİ SUNUCU (tek parça snapshot) bozulmadan çalışır', () async {
      // Sunucu sayfalamayı bilmiyorsa `has_more` false gelir ve `snapshot_cursor` hiç yoktur.
      api.pullQueue.add(sayfa(varliklar: {
        'customer': [musteri('m1', 'Bir'), musteri('m2', 'İki')]
      }, devamVar: false, cursor: 42));

      await motor.pull();

      expect(await imlecOku(), 42);
      expect(await db.select(db.customers).get(), hasLength(2));
    });
  });

  group('bastanIndir — sıkışmış cihazın kurtarılması', () {
    test('imleci sıfırlar ve sonraki tur SNAPSHOT ister', () async {
      // Sahadaki durum: imleç sonda, veri yok, sunucu boş delta döndürüyor.
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        const SyncMetaCompanion(lastPulledSeq: Value(31183), snapshotDone: Value(true)),
      );

      await motor.bastanIndir();

      final meta = await db.syncState();
      expect(meta.lastPulledSeq, 0);
      expect(meta.snapshotDone, isFalse);

      api.pullQueue.add(sayfa(varliklar: {
        'customer': [musteri('m1', 'Geri Gelen')]
      }, devamVar: false, cursor: 31183));
      await motor.pull();

      expect(api.pullCagrilari.single.since, 0, reason: 'Kurtarma SNAPSHOT istemeli.');
      expect(await db.select(db.customers).get(), hasLength(1));
    });

    test('YEREL VERİYİ SİLMEZ — gönderilmemiş kayıtlar korunur', () async {
      // Silmek, henüz sunucuya gitmemiş giden-kutusu kayıtlarını yok ederdi (kırmızı çizgi #3).
      await db.into(db.outbox).insert(OutboxCompanion.insert(
            clientEventId: 'ce1',
            entityType: 'customer',
            op: 'upsert',
            payload: '{}',
            occurredAt: '2026-09-12T10:00:00.000000Z',
            createdAt: '2026-09-12T10:00:00.000000Z',
          ));

      await motor.bastanIndir();

      expect(await db.select(db.outbox).get(), hasLength(1));
    });
  });
}
