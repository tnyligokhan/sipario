import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';

import 'support/fake_sync_api.dart';

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    engine = SyncEngine(db, api);
  });
  tearDown(() => db.close());

  test('pushPending outbox olaylarını gönderir ve acked işaretler', () async {
    final repo = CustomerRepository(db);
    await repo.create(name: 'Ahmet', phones: [PhoneInput(phoneE164: '+905321112233')]);

    final pushed = await engine.pushPending();
    expect(pushed, 2); // customer + phone

    // Sunucuya iki olay gitti.
    expect(api.pushedBatches.single, hasLength(2));

    // Tüm outbox acked.
    final outbox = await db.select(db.outbox).get();
    expect(outbox.every((o) => o.status == 'acked'), isTrue);

    // İkinci pushPending gönderecek bir şey bulamaz.
    expect(await engine.pushPending(), 0);
  });

  test('pushPending server_time offset yazar', () async {
    final repo = CustomerRepository(db);
    await repo.create(name: 'X');
    api.serverTime = DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();

    await engine.pushPending();

    final meta = await db.syncState();
    // ~1 saat (3600000 ms) civarı offset (çalışma süresi toleransı).
    expect(meta.serverTimeOffsetMs, greaterThan(3500000));
    expect(meta.lastServerTimeIso, isNotNull);
  });

  test('pull snapshot canlı satırları yerele uygular ve snapshot_done işaretler', () async {
    api.pullQueue.add(PullResponse(
      mode: 'snapshot',
      cursor: 5,
      hasMore: false,
      currentSeq: 5,
      entities: {
        'customer': [
          {
            'id': 'cust-1',
            'name': 'Zeynep',
            'note': null,
            'balance_kurus': 24000,
            'updated_occurred_at': '2026-07-13T10:00:00.000Z',
            'updated_device_id': null,
            'deleted_at': null,
          },
        ],
        'product': [
          {
            'id': 'prod-1',
            'name': '19L',
            'unit_price_kurus': 4500,
            'unit': 'adet',
            'is_active': true,
            'updated_occurred_at': '2026-07-13T10:00:00.000Z',
            'updated_device_id': null,
            'deleted_at': null,
          },
        ],
      },
    ));

    await engine.pull();

    final cust = await (db.select(db.customers)..where((t) => t.id.equals('cust-1'))).getSingle();
    expect(cust.name, 'Zeynep');
    expect(cust.balanceKurus, 24000);
    expect((await db.select(db.products).get()).single.name, '19L');

    final meta = await db.syncState();
    expect(meta.lastPulledSeq, 5);
    expect(meta.snapshotDone, isTrue);
  });

  test('pull delta değişiklikleri uygular ve cursor ilerletir', () async {
    api.pullQueue.add(PullResponse(
      mode: 'delta',
      cursor: 7,
      hasMore: false,
      currentSeq: 7,
      changes: [
        {
          'seq': 7,
          'entity_type': 'customer',
          'entity_id': 'c9',
          'op': 'upsert',
          'occurred_at': '2026-07-13T11:00:00.000Z',
          'payload': {
            'id': 'c9',
            'name': 'Yeni Müşteri',
            'note': null,
            'balance_kurus': 0,
            'updated_occurred_at': '2026-07-13T11:00:00.000Z',
            'updated_device_id': null,
            'deleted_at': null,
          },
        },
      ],
    ));

    await engine.pull();

    final cust = await (db.select(db.customers)..where((t) => t.id.equals('c9'))).getSingle();
    expect(cust.name, 'Yeni Müşteri');
    expect((await db.syncState()).lastPulledSeq, 7);
  });

  test('çakışma: yerelde daha yeni pending düzenleme varsa sunucu değişikliği uygulanmaz', () async {
    // Yerelde müşteri oluştur (outbox pending, occurred_at ~ şimdi).
    final repo = CustomerRepository(db);
    final id = await repo.create(name: 'Yerel İsim');

    // Sunucudan AYNI müşteri için DAHA ESKİ occurred_at'li bir değişiklik gelir.
    api.pullQueue.add(PullResponse(
      mode: 'delta',
      cursor: 3,
      hasMore: false,
      currentSeq: 3,
      changes: [
        {
          'seq': 3,
          'entity_type': 'customer',
          'entity_id': id,
          'op': 'upsert',
          'occurred_at': '2020-01-01T00:00:00.000Z', // çok eski
          'payload': {
            'id': id,
            'name': 'Sunucu İsmi (eski)',
            'note': null,
            'balance_kurus': 0,
            'updated_occurred_at': '2020-01-01T00:00:00.000Z',
            'updated_device_id': null,
            'deleted_at': null,
          },
        },
      ],
    ));

    await engine.pull();

    // Yerel isim korunur (gönderilmemiş daha yeni düzenleme kazanacak).
    final cust = await (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
    expect(cust.name, 'Yerel İsim');
  });

  test('append idempotency: aynı order_event iki kez pull edilirse tek satır', () async {
    PullResponse eventDelta(int seq) => PullResponse(
          mode: 'delta',
          cursor: seq,
          hasMore: false,
          currentSeq: seq,
          changes: [
            {
              'seq': seq,
              'entity_type': 'order_event',
              'entity_id': 'evt-server-id',
              'op': 'upsert',
              'occurred_at': '2026-07-13T10:00:00.000Z',
              'payload': {
                'id': 'evt-server-id',
                'order_id': 'o1',
                'event_type': 'created',
                'payload': {'foo': 'bar'},
                'client_event_id': 'CE-1',
                'occurred_at': '2026-07-13T10:00:00.000Z',
                'device_id': null,
              },
            },
          ],
        );

    api.pullQueue.add(eventDelta(4));
    await engine.pull();
    api.pullQueue.add(eventDelta(4));
    await engine.pull();

    // client_event_id 'CE-1' ile yalnız tek order_event (yoksa-ekle).
    final events = await db.select(db.orderEvents).get();
    expect(events, hasLength(1));
    expect(events.single.clientEventId, 'CE-1');
  });
}
