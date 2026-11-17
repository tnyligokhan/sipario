// "BAZI KAYITLAR GÖNDERİLEMEDİ" GÜNCELLEMEDEN SONRA KALICI OLMAMALI (kullanıcı şikâyeti 2026-11-06).
//
// İKİ KÖK NEDEN, İKİ GRUP:
//   1. Vekilin dağıtım sırasındaki 404'ü kalıcı red sayılıp masum kaydı karantinaya düşürüyordu.
//   2. Karantinadan çıkış yolu yoktu: sebep sürümse bile kayıt bir daha denenmiyordu.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/outbox.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';

import 'support/fake_sync_api.dart';

/// Karantinada kayıtları olan telefon.
///
/// FİKSTÜR SINIFI (depo kuralı 2026-08-17): kurulum durumu ve onun üzerinde işleyen davranış tek
/// nesnede kapsüllenir.
class KarantinaTezgahi {
  KarantinaTezgahi() : db = AppDatabase(NativeDatabase.memory()) {
    motor = SyncEngine(db, api);
  }

  final AppDatabase db;
  final FakeSyncApi api = FakeSyncApi();
  late final SyncEngine motor;

  Future<void> reddedilmisEkle(String id) async {
    await enqueueOutbox(
      db,
      entityType: 'customer',
      op: 'upsert',
      entityId: id,
      clientEventId: id,
      payload: {'id': id, 'name': 'Müşteri $id'},
      occurredAt: '2026-11-06T10:00:00.000Z',
      deviceId: 'cihaz-1',
    );
    await (db.update(db.outbox)..where((t) => t.clientEventId.equals(id))).write(
      const OutboxCompanion(
        status: Value('rejected'),
        attempts: Value(3),
        lastError: Value('Olay içeriği geçersiz. (invalid_payload)'),
      ),
    );
  }

  /// Sunucu her olayı yine reddeder.
  void sunucuReddetsin() {
    api.pushHandler = (olaylar) => PushResponse(
          results: [
            for (final o in olaylar)
              EventResult(clientEventId: o['client_event_id'] as String, status: 'rejected'),
          ],
          currentSeq: 0,
        );
  }

  Future<void> sunucuSurumuYaz(String surum) =>
      (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(SyncMetaCompanion(apiVersion: Value(surum)));

  Future<int> karantinaSayisi() => db.watchKarantinaSayisi().first;

  Future<OutboxData> satir(String id) =>
      (db.select(db.outbox)..where((t) => t.clientEventId.equals(id))).getSingle();
}

void main() {
  group('Vekilin 404 yanıtı', () {
    test('düz metin 404 geçicidir, kalıcı red sayılmaz', () {
      final e = SyncApiException('push', 404, '404 page not found\n');
      expect(e.gecici, isTrue);
      expect(e.kaliciRed, isFalse);
    });

    test('HTML 404 de geçicidir', () {
      expect(SyncApiException('push', 404, '<html>Not Found</html>').gecici, isTrue);
    });

    test('uygulamanın JSON 404 yanıtı kalıcı red olarak kalır', () {
      final e = SyncApiException('push', 404, '{"message":"Not Found."}');
      expect(e.gecici, isFalse);
      expect(e.kaliciRed, isTrue);
    });

    test('404 dışındaki 4xx değişmez', () {
      expect(SyncApiException('push', 422, 'düz metin').kaliciRed, isTrue);
      expect(SyncApiException('push', 413, '<html>too large</html>').kaliciRed, isTrue);
    });
  });

  group('Sürüm değişince yeniden deneme', () {
    late KarantinaTezgahi t;
    setUp(() => t = KarantinaTezgahi());
    tearDown(() => t.db.close());

    test('bu sürüme ilk geçişte karantina temizlenir ve kayıt sunucuya gider', () async {
      await t.reddedilmisEkle('a');

      await t.motor.pushPending();

      expect(t.api.pushedBatches, hasLength(1));
      expect((await t.satir('a')).status, 'acked');
      expect(await t.karantinaSayisi(), 0);
    });

    test('sunucu yine reddederse kayıt silinmez, karantinaya geri döner', () async {
      await t.reddedilmisEkle('a');
      t.sunucuReddetsin();

      await t.motor.pushPending();

      final s = await t.satir('a');
      expect(s.status, 'rejected');
      expect(s.payload, contains('Müşteri a'));
      expect(await t.karantinaSayisi(), 1);
    });

    test('aynı sürümde ikinci kez denenmez, kuyruk dönmez', () async {
      await t.reddedilmisEkle('a');
      t.sunucuReddetsin();

      await t.motor.pushPending();
      await t.motor.pushPending();
      await t.motor.pushPending();

      expect(t.api.pushedBatches, hasLength(1));
    });

    test('uygulama güncellenince yeniden denenir', () async {
      await t.reddedilmisEkle('a');

      expect(await t.motor.karantinayiYenidenDene(yapim: 618), 1);
      await t.reddedilmisEkle('b');
      expect(await t.motor.karantinayiYenidenDene(yapim: 618), 0);
      expect(await t.motor.karantinayiYenidenDene(yapim: 630), 1);
    });

    test('sunucu güncellenince yeniden denenir', () async {
      await t.sunucuSurumuYaz('1.30.0');
      await t.reddedilmisEkle('a');
      await t.motor.karantinayiYenidenDene(yapim: 630);
      await (t.db.update(t.db.outbox)..where((o) => o.clientEventId.equals('a')))
          .write(const OutboxCompanion(status: Value('rejected')));

      await t.sunucuSurumuYaz('1.31.0');

      expect(await t.motor.karantinayiYenidenDene(yapim: 630), 1);
    });

    test('yeniden denenen kaydın deneme sayacı sıfırlanır, eşiğe hemen takılmaz', () async {
      await t.reddedilmisEkle('a');

      await t.motor.karantinayiYenidenDene(yapim: 630);

      final s = await t.satir('a');
      expect(s.status, 'pending');
      expect(s.attempts, 0);
    });

    test('karantina boşken anahtar yine yazılır, sonraki turda iş yapmaz', () async {
      expect(await t.motor.karantinayiYenidenDene(yapim: 630), 0);
      expect((await t.db.syncState()).karantinaAnahtari, '630|');
    });

    test('13.11.2026 yedek kaybı penceresindeki acked olaylar da yeniden kuyruğa alınır', () async {
      // 12 Kasım öncesi acked kayıt: yedekte zaten var, dokunulmamalı.
      await enqueueOutbox(
        t.db,
        entityType: 'customer',
        op: 'upsert',
        entityId: 'eski-musteri',
        clientEventId: '00000000-0000-7000-8000-000000000001',
        payload: {'id': 'eski-musteri', 'name': 'Eski Müşteri'},
        occurredAt: '2026-11-01T10:00:00.000Z',
      );
      // 14 Kasım acked müşteri: eski sunucu onayladı ama 13.11 yedeğinde yok.
      await enqueueOutbox(
        t.db,
        entityType: 'customer',
        op: 'upsert',
        entityId: 'kayip-musteri',
        clientEventId: '00000000-0000-7000-8000-000000000002',
        payload: {'id': 'kayip-musteri', 'name': '14 Kasım Müşterisi'},
        occurredAt: '2026-11-14T12:00:00.000Z',
      );
      await (t.db.update(t.db.outbox)).write(const OutboxCompanion(status: Value('acked')));

      // 17 Kasım'da bu müşteriye açılan sipariş sunucuda ebeveyn olmadığı için rejected olmuş.
      await enqueueOutbox(
        t.db,
        entityType: 'order',
        op: 'created',
        entityId: 'yeni-siparis',
        clientEventId: '00000000-0000-7000-8000-000000000003',
        payload: {
          'order': {'id': 'yeni-siparis', 'customer_id': 'kayip-musteri'},
          'lines': const [],
        },
        occurredAt: '2026-11-17T09:00:00.000Z',
      );
      await (t.db.update(t.db.outbox)
            ..where((o) => o.clientEventId.equals('00000000-0000-7000-8000-000000000003')))
          .write(const OutboxCompanion(status: Value('rejected'), attempts: Value(1)));

      await t.motor.pushPending();

      expect(t.api.pushedBatches, hasLength(1));
      final gonderilenKimlikler = [
        for (final o in t.api.pushedBatches.single) o['client_event_id'] as String,
      ];
      // Önce 14 Kasım müşterisi, hemen arkasından 17 Kasım siparişi gitmeli; 1 Kasım gitmemeli.
      expect(gonderilenKimlikler, [
        '00000000-0000-7000-8000-000000000002',
        '00000000-0000-7000-8000-000000000003',
      ]);
      expect(await t.karantinaSayisi(), 0);
    });

    test('başka cihazdan inmiş yerel müşteri ve sipariş ebeveynlerini sentetik olarak başa ekler',
        () async {
      // Patronun 15 Kasım'da açtığı müşteri ve sipariş bu kurye telefonuna pull ile inmiş
      // (bu telefonun outbox'ında yok), kurye 17 Kasım'da teslim etmiş ve 'Sipariş bulunamadı'
      // ile rejected almış.
      await t.db.into(t.db.customers).insert(CustomersCompanion.insert(
            id: 'patron-musteri',
            name: 'Patronun Açtığı Müşteri',
            updatedOccurredAt: '2026-11-15T10:00:00.000Z',
          ));
      await t.db.into(t.db.orders).insert(OrdersCompanion.insert(
            id: 'patron-siparis',
            customerId: const Value('patron-musteri'),
            occurredAt: '2026-11-15T10:05:00.000Z',
          ));
      await t.db.into(t.db.orderLines).insert(OrderLinesCompanion.insert(
            id: 'satir-1',
            orderId: 'patron-siparis',
            productName: '19L Damacana',
            unitPriceKurus: 9000,
            qty: 2,
            lineTotalKurus: 18000,
          ));

      await enqueueOutbox(
        t.db,
        entityType: 'order',
        op: 'delivered',
        entityId: 'patron-siparis',
        clientEventId: '00000000-0000-7000-8000-000000000010',
        payload: {'order_id': 'patron-siparis', 'payment_type': 'nakit'},
        occurredAt: '2026-11-17T11:00:00.000Z',
      );
      await (t.db.update(t.db.outbox)
            ..where((o) => o.clientEventId.equals('00000000-0000-7000-8000-000000000010')))
          .write(const OutboxCompanion(status: Value('rejected'), attempts: Value(1)));

      await t.motor.pushPending();

      expect(t.api.pushedBatches, hasLength(1));
      final parti = t.api.pushedBatches.single;
      // Sıra: 1) müşteri upsert, 2) sipariş created (satırıyla), 3) sipariş delivered.
      expect(
        parti.map((e) => '${e['entity_type']}:${e['op']}').toList(),
        ['customer:upsert', 'order:created', 'order:delivered'],
      );
      expect(await t.karantinaSayisi(), 0);
    });
  });
}
