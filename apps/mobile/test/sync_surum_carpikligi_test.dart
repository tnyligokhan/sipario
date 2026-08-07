// SÜRÜM ÇARPIKLIĞI — "sunucu ilerledi, telefondaki uygulama ESKİ kaldı".
//
// Sunucu migration'ı bizim elimizde, mağaza güncellemesi bayinin. Aradaki boşluk GÜNLER sürer ve
// o boşlukta eski istemci hem yazar hem okur. Bu dosya, sunucudan gelen BEKLENMEDİK bir yükün
// senkronu KALICI olarak öldürmediğini kilitler.
//
// KÖK DESEN: `SyncEngine._applyDelta` tüm sayfayı TEK transaction'da uygular ve satır
// ayrıştırıcıları null-güvensiz cast kullanır (`m['name'] as String`). Sunucu bir kolonu
// nullable yaptığında ya da bir satırda beklenmedik bir tip gönderdiğinde TypeError transaction'ı
// düşürür → `lastPulledSeq` İLERLEMEZ → sonraki tur AYNI sayfayı çeker, AYNI yerde düşer.
// Senkron bir daha asla ilerlemez ve tek "çözüm" uygulama verisini silmek olur (kırmızı çizgi #3).
// Push yönünde bu sınıf kapatılmıştı (sunucuda savepoint, istemcide ikili arama); pull yönünde
// hiçbir koruma yoktu.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/outbox.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';
import 'package:sipario/sync/sync_service.dart';

import 'support/fake_sync_api.dart';

/// Sunucudan inen bir delta satırı zarfı.
Map<String, dynamic> _degisiklik(String tip, Map<String, dynamic> payload) => {
      'entity_type': tip,
      'entity_id': payload['id'],
      'op': 'upsert',
      'payload': payload,
      'occurred_at': '2026-08-05T10:00:00Z',
    };

Map<String, dynamic> _saglamMusteri(String id, String ad) => {
      'id': id,
      'name': ad,
      'note': null,
      'code': 7,
      'balance_kurus': 0,
      'blacklisted_at': null,
      'updated_occurred_at': '2026-08-05T10:00:00Z',
      'updated_device_id': null,
      'deleted_at': null,
    };

Future<AppDatabase> _oturumluDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
      .write(const SyncMetaCompanion(authToken: Value('test-token'), lastPulledSeq: Value(10)));
  return db;
}

void main() {
  group('pull — bozuk satır turu KALICI olarak öldürmez', () {
    test('bozuk satır atlanır, sağlam satırlar uygulanır ve cursor İLERLER', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()
        ..pullQueue.add(PullResponse(
          mode: 'delta',
          cursor: 42,
          hasMore: false,
          currentSeq: 42,
          changes: [
            _degisiklik('customer', _saglamMusteri('m-1', 'Sağlam Bir')),
            // ZEHİRLİ SATIR: sunucu bir migration'la `name`i nullable yaptı (ya da bu satırda
            // gerçekten null). Eski istemcinin ayrıştırıcısı `as String` diyor → TypeError.
            _degisiklik('customer', {..._saglamMusteri('m-2', 'x'), 'name': null}),
            _degisiklik('customer', _saglamMusteri('m-3', 'Sağlam İki')),
          ],
        ));

      final motor = SyncEngine(db, api);
      final atlanan = await motor.pull();

      expect(atlanan, 1, reason: 'yalnız bozuk satır atlanmalı');

      final musteriler = await db.select(db.customers).get();
      expect(musteriler.map((m) => m.id).toSet(), {'m-1', 'm-3'},
          reason: 'ARIZA: tek bozuk satır aynı sayfadaki SAĞLAM kayıtları da yutuyor');

      final meta = await db.syncState();
      expect(meta.lastPulledSeq, 42,
          reason: 'ARIZA: cursor ilerlemezse sonraki tur AYNI sayfada düşer — senkron kalıcı ölür');
    });

    test('ikinci tur aynı yerde takılmaz — kuyruk kilitlenmez', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()
        ..pullQueue.add(PullResponse(
          mode: 'delta',
          cursor: 42,
          hasMore: false,
          currentSeq: 42,
          changes: [_degisiklik('customer', {..._saglamMusteri('m-2', 'x'), 'name': null})],
        ))
        ..pullQueue.add(PullResponse(
          mode: 'delta',
          cursor: 43,
          hasMore: false,
          currentSeq: 43,
          changes: [_degisiklik('customer', _saglamMusteri('m-9', 'Sonraki Sayfa'))],
        ));

      final motor = SyncEngine(db, api);
      await motor.pull();
      await motor.pull();

      final musteriler = await db.select(db.customers).get();
      expect(musteriler.map((m) => m.id), contains('m-9'),
          reason: 'ARIZA: birinci sayfa kilitlenirse ikinci sayfa HİÇ inmez');
      expect((await db.syncState()).lastPulledSeq, 43);
    });

    test('snapshot da satır bazında izole edilir (ilk kurulum tek satırla ölmez)', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()
        ..pullQueue.add(PullResponse(
          mode: 'snapshot',
          cursor: 5,
          hasMore: false,
          currentSeq: 5,
          entities: {
            'customer': [
              _saglamMusteri('m-1', 'Sağlam'),
              {..._saglamMusteri('m-2', 'x'), 'name': null},
            ],
          },
        ));

      final atlanan = await SyncEngine(db, api).pull();

      expect(atlanan, 1);
      expect((await db.select(db.customers).get()).map((m) => m.id), ['m-1']);
      final meta = await db.syncState();
      expect(meta.snapshotDone, isTrue,
          reason: 'ARIZA: ilk kurulum tek bozuk satırda sonsuza dek snapshot moduna çakılır');
    });

    test('atlanan satır SESSİZ kalmaz — tur `veri` cinsinden başarısızdır', () async {
      // Kuyruğu açık tutmanın bedeli sessiz veri kaybı OLMAMALI: bant "her şey yolunda"
      // dememeli, destek cihazdan durumu görebilmeli.
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()
        ..pullQueue.add(PullResponse(
          mode: 'delta',
          cursor: 42,
          hasMore: false,
          currentSeq: 42,
          changes: [_degisiklik('customer', {..._saglamMusteri('m-2', 'x'), 'name': null})],
        ));

      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final sonuc = await sync.syncNow();
      expect(sonuc.ok, isFalse, reason: 'atlanan satır turu başarılı saydırmamalı');
      expect(sonuc.tur, SyncHataTuru.veri, reason: 'ne ağ ne oturum — sunucu yükü okunamadı');
    });
  });

  group('atlanan satırın İYİLEŞME YOLU', () {
    test('varlığın bir sonraki güncellemesi kaybı ONARIR (delta = tam durum)', () async {
      // "Atla + cursor ilerlet" kararının dayanağı budur: sunucunun delta yükü DEĞİŞEN ALANLAR
      // değil, satırın TAM DURUMUdur (`SyncPayload::change` → `attributesToArray()`). Yani
      // kaçırılan satır, o varlığa yapılan HERHANGİ bir sonraki güncellemede eksiksiz iner —
      // kayıp kalıcı değil, GECİKMELİdir.
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()
        ..pullQueue.add(PullResponse(
          mode: 'delta',
          cursor: 42,
          hasMore: false,
          currentSeq: 42,
          // Bu turda satır okunamıyor (bu build alanı bilmiyor).
          changes: [_degisiklik('customer', {..._saglamMusteri('m-7', 'x'), 'name': null})],
        ))
        ..pullQueue.add(PullResponse(
          mode: 'delta',
          cursor: 43,
          hasMore: false,
          currentSeq: 43,
          // Bayi aynı müşteriye dokundu → sunucu TAM satırı yeniden yayınladı.
          changes: [_degisiklik('customer', _saglamMusteri('m-7', 'Sonunda İndi'))],
        ));

      final motor = SyncEngine(db, api);
      expect(await motor.pull(), 1);
      expect(await motor.pull(), 0);

      final musteri = (await db.select(db.customers).get()).singleWhere((m) => m.id == 'm-7');
      expect(musteri.name, 'Sonunda İndi',
          reason: 'delta tam durum taşıdığı için kaçan satır bir sonraki dokunuşta onarılmalı');
    });

    test('atlanan satır BİR KEZ görülür — cursor ilerlediği için tekrar GELMEZ', () async {
      // Bunun sonucu önemli ve raporlanmalı: `veri` cinsinden tur hatası YALNIZ o turda yanar,
      // sonraki tur temizdir. Yani bant kalıcı bir "eksiğin var" işareti TAŞIMAZ — kaçan satırın
      // görünürlüğü tek tura hapsolur. Bu testin işi o davranışı yazılı kılmak.
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()
        ..pullQueue.add(PullResponse(
          mode: 'delta',
          cursor: 42,
          hasMore: false,
          currentSeq: 42,
          changes: [_degisiklik('customer', {..._saglamMusteri('m-8', 'x'), 'name': null})],
        ));

      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      expect((await sync.syncNow()).ok, isFalse);
      // İkinci tur: FakeSyncApi kuyruğu boş → `since=42`'den itibaren boş delta. Bozuk satır
      // BİR DAHA gelmez; tur temiz.
      expect((await sync.syncNow()).ok, isTrue,
          reason: 'cursor ilerlediği için aynı satır tekrar çekilmez');
    });
  });

  group('team bloğu — bozuk bir kullanıcı satırı TÜM turu düşürmez', () {
    test('geçersiz eleman atlanır, sağlam ekip yazılır', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()
        ..pullQueue.add(PullResponse(
          mode: 'delta',
          cursor: 11,
          hasMore: false,
          currentSeq: 11,
          team: [
            {'id': 'u-1', 'name': 'Patron', 'role': 'patron', 'status': 'active'},
            // Sunucu `role`u kaldırdı/nullable yaptı → `as String` TypeError.
            {'id': 'u-2', 'name': 'Kurye', 'role': null, 'status': 'active'},
            {'id': 'u-3', 'name': 'Operatör', 'role': 'operator', 'status': 'active'},
          ],
        ));

      await SyncEngine(db, api).pull();

      final kullanicilar = await db.select(db.users).get();
      expect(kullanicilar.map((u) => u.id).toSet(), {'u-1', 'u-3'},
          reason: 'ARIZA: tek bozuk kullanıcı ekip listesini TAMAMEN boşaltıyor ve turu düşürüyor');
    });
  });

  group('push sonucu — eksik `status` turu düşürmez', () {
    test('durumsuz sonuç satırı PENDING bırakır, diğer satırlar işlenir', () async {
      // `EventResult.status` `as String` idi: sunucu bir gün bu alanı boş yollarsa (ya da yeni bir
      // sonuç şekli eklerse) TÜM push turu TypeError ile düşerdi ve outbox'ta HİÇBİR satır
      // işlenmezdi. Beyaz liste felsefesi zaten "tanımadığın durumu beklet" diyor; ayrıştırıcının
      // da aynı kapıdan geçmesi gerekiyor.
      final db = await _oturumluDb();
      addTearDown(db.close);

      await enqueueOutbox(db,
          entityType: 'customer',
          op: 'upsert',
          entityId: 'm-1',
          occurredAt: '2026-08-05T10:00:00Z',
          deviceId: 'd-1',
          payload: {'id': 'm-1', 'name': 'Bir'});
      await enqueueOutbox(db,
          entityType: 'customer',
          op: 'upsert',
          entityId: 'm-2',
          occurredAt: '2026-08-05T10:00:01Z',
          deviceId: 'd-1',
          payload: {'id': 'm-2', 'name': 'İki'});

      final api = FakeSyncApi()
        ..pushHandler = (events) => PushResponse.fromJson({
              'results': [
                {'index': 0, 'client_event_id': events[0]['client_event_id'], 'status': null},
                {
                  'index': 1,
                  'client_event_id': events[1]['client_event_id'],
                  'status': 'applied',
                  'server_seq': 2,
                },
              ],
              'current_seq': 2,
            });

      final ozet = await SyncEngine(db, api).pushPending();

      expect(ozet.gonderildi, 1, reason: 'yalnız sağlam sonuç nihai sayılmalı');
      final satirlar = await db.select(db.outbox).get();
      final ilk = satirlar.firstWhere((r) => r.entityId == 'm-1');
      final ikinci = satirlar.firstWhere((r) => r.entityId == 'm-2');
      expect(ilk.status, 'pending', reason: 'durumu okunamayan satır SIRADA kalmalı, silinmemeli');
      expect(ikinci.status, 'acked');
    });
  });
}
