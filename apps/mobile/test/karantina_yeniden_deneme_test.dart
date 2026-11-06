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
  });
}
