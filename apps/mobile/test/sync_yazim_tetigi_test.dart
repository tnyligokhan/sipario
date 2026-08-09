// YEREL YAZIM TETİĞİ — 2026-08-09 saha arızasının regresyon kilidi.
//
// BİLDİRİLEN BELİRTİ: "Patron siparişi kuryeye atıyor, kurye yenilese bile GÖREMİYOR; patron
// uygulamayı alta alıp öne getirince görüyor."
//
// KÖK NEDEN: atama outbox'a düzgün düşüyordu — eksik olan, kaydın sunucuya GİDECEĞİ ANIN
// tetiklenmesiydi. Tur yalnız DÖRT DIŞ olayla açılıyordu (2 dk zamanlayıcı · ağ değişimi · öne
// gelme · aşağı çekerek yenileme); "alta alıp açınca gidiyor" gözlemi tam olarak `resumed`
// turudur. Tutarlılık değil GECİKME arızası — durağan durumu ölçen teşhisler bu yüzden kaçırdı.
//
// Bu dosya düzeltmenin DOKUZ davranışını kilitler. En kritik olanı ikincisidir: tetik yalnız
// ARTIŞTA açılmalı. Düşüşe de açılsaydı (push kayıtları `acked` yapınca bekleyen sayısı DÜŞER ve
// akış yine yayın yapar) her tur bir sonrakini doğurur, kendi kendini besleyen sonsuz tur döngüsü
// olurdu — pil ve kota yanar.
//
// TUR SAYACI `pull` ÜZERİNDEDİR (`sync_dayaniklilik_test.dart` ile aynı gerekçe): `pushPending`
// bekleyen satır yoksa sunucuya HİÇ gitmeden erken döner, yani push çağrısı "tur koştu mu"
// sorusunun güvenilir ölçüsü değildir. `pull` her turda koşulsuz çağrılır.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/ids.dart';
import 'package:sipario/data/outbox.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_service.dart';

/// Sahte taşıma: turları SAYAR ve push edilen olay zarflarını SAKLAR (uçtan uca testte atamanın
/// sunucuya gerçekten gittiğini kanıtlamak için). Davranış tur başına ayarlanabilir:
/// null → başarı · `Completer` → asılı kal · başka nesne → fırlat.
class _KayitliApi implements SyncApi {
  int pullSayaci = 0;
  int pushSayaci = 0;

  /// Sunucuya GERÇEKTEN gönderilen olay zarfları (tüm turların birikimi).
  final gonderilenler = <Map<String, Object?>>[];

  Object? Function(int cagri)? pushDavranis;
  Object? Function(int tur)? pullDavranis;

  @override
  Future<PushResponse> push(List<Map<String, Object?>> events) async {
    pushSayaci++;
    gonderilenler.addAll(events);
    final d = pushDavranis?.call(pushSayaci);
    if (d is Completer<void>) {
      await d.future;
    } else if (d != null) {
      throw d;
    }
    return PushResponse(
      results: [
        for (final e in events)
          EventResult(clientEventId: e['client_event_id'] as String?, status: 'applied'),
      ],
      currentSeq: 0,
    );
  }

  @override
  Future<PullResponse> pull({required int since, int limit = 500}) async {
    pullSayaci++;
    final d = pullDavranis?.call(pullSayaci);
    if (d is Completer<void>) {
      await d.future;
    } else if (d != null) {
      throw d;
    }
    return PullResponse(mode: 'delta', cursor: since, hasMore: false, currentSeq: since);
  }
}

Future<AppDatabase> _oturumluDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  // Token yoksa tur "Oturum yok" ile erken döner ve push'a hiç gelinmez.
  await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
    const SyncMetaCompanion(authToken: Value('test-token'), deviceId: Value('test-cihaz')),
  );
  return db;
}

/// Outbox'a doğrudan bir `pending` satır koyar (repo katmanından geçmeden — sahte akışla koşan
/// testlerde tetiği akış kontrol eder, DB yalnız push'a yem verir).
Future<String> _bekleyenSatir(AppDatabase db) async {
  final id = newId();
  await db.into(db.outbox).insert(OutboxCompanion.insert(
        clientEventId: id,
        entityType: 'order',
        op: 'assigned',
        payload: jsonEncode({'order_id': id, 'assigned_user_id': 'kurye-7'}),
        occurredAt: nowIso(),
        createdAt: nowIso(),
      ));
  return id;
}

Future<void> _bekle(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('Yazım tetiği — ARTIŞTA gerçek bir push turu koşar', () {
    test('bekleyen sayısı artınca gecikme içinde SUNUCUYA gidilir', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      await _bekleyenSatir(db); // patronun attığı sipariş outbox'ta bekliyor
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final akis = StreamController<int>();
      addTearDown(akis.close);
      sync.yazimTetigiBagla(
          bekleyenSayisi: akis.stream, gecikme: const Duration(milliseconds: 50));

      akis.add(0); // taban
      await _bekle(80);
      expect(api.pullSayaci, 0, reason: 'taban kurulumu tur açmaz');

      akis.add(1); // yazım düştü
      await _bekle(250);

      expect(api.pullSayaci, 1, reason: 'ARIZANIN TA KENDİSİ: yazım turu açmazsa kayıt bir '
          'sonraki periyodik tura kalır — kurye o siparişi 2 dakika görmez');
      expect(api.pushSayaci, 1,
          reason: 'tur AÇILMASI yetmez, bekleyen kayıt GERÇEKTEN push edilmeli');
      expect(api.gonderilenler, hasLength(1));
    });
  });

  group('Yazım tetiği — DÜŞÜŞTE tetiklenmez (sonsuz tur döngüsü kapısı)', () {
    test('ack sonrası sayı düşünce tur AÇILMAZ', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final akis = StreamController<int>();
      addTearDown(akis.close);
      sync.yazimTetigiBagla(
          bekleyenSayisi: akis.stream, gecikme: const Duration(milliseconds: 50));

      akis.add(3); // taban: üç kayıt bekliyor
      await _bekle(80);
      akis.add(1); // tur koştu, iki kayıt ack'lendi → DÜŞÜŞ
      await _bekle(250);

      expect(api.pullSayaci, 0,
          reason: 'düşüşe de tur açılsaydı her tur bir sonrakini doğururdu: '
              'push → ack → sayı düşer → yeni tur → … sonsuz döngü (pil + kota)');

      akis.add(0); // sıfıra inen sayı da bir düşüştür
      await _bekle(150);
      expect(api.pullSayaci, 0, reason: 'kuyruk boşalması da bir olaydır ama tur SEBEBİ değildir');
    });
  });

  group('Yazım tetiği — İLK yayın yalnız taban kurar', () {
    test('bağlanma anındaki bekleyen kayıtlar sahte "artış" sayılmaz', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final akis = StreamController<int>();
      addTearDown(akis.close);
      sync.yazimTetigiBagla(
          bekleyenSayisi: akis.stream, gecikme: const Duration(milliseconds: 50));

      akis.add(5); // açılışta zaten 5 kayıt bekliyor
      await _bekle(250);
      expect(api.pullSayaci, 0,
          reason: 'açılışta bekleyen kayıtları `start()` zaten gönderiyor; '
              'burada da tur açmak her açılışta ÇİFT tur demekti');

      // Abonelik ÖLMEDİ, yalnız taban kuruldu: sonraki artış turu açmalı.
      akis.add(6);
      await _bekle(250);
      expect(api.pullSayaci, 1, reason: 'taban kurulduktan sonra artış normal işler');
    });
  });

  group('Yazım tetiği — pencere içindeki N artış TEK tur eder', () {
    test('gecikme penceresi YENİDEN BAŞLAMAZ; ilk artış pencereyi açar', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final akis = StreamController<int>();
      addTearDown(akis.close);
      // 500 ms pencere: art arda yazımlar 250 ms arayla gelecek. Klasik debounce (her olayda
      // sayacı sıfırlayan) turu 750 ms'ye erteler; buradaki tasarım 500 ms'de koşar.
      sync.yazimTetigiBagla(
          bekleyenSayisi: akis.stream, gecikme: const Duration(milliseconds: 500));

      akis.add(0); // taban
      await _bekle(60);
      akis.add(1); // t≈0 — pencere AÇILIR
      await _bekle(250);
      akis.add(2); // t≈250 — pencere İÇİNDE, aynı tura biner
      await _bekle(400); // t≈650

      expect(api.pullSayaci, 1,
          reason: 'tur EN GEÇ ilk artıştan 500 ms sonra koşar; pencere her yazımda yeniden '
              'başlasaydı (klasik debounce) gün kapanışı gibi toplu yazımlarda tur sürekli '
              'ertelenirdi — 650 ms\'de henüz koşmamış olurdu');

      await _bekle(400); // t≈1050 — geciktirilmiş bir tur varsa burada görünürdü
      expect(api.pullSayaci, 1, reason: 'art arda İKİ yazım TEK tur eder, iki değil');
    });
  });

  group('Yazım tetiği — SÜREN tura binmez, taze tur açar', () {
    test('tur sürerken gelen yazım, o tur bitince YENİ bir tur açar', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final asili = Completer<void>();
      final api = _KayitliApi()..pullDavranis = (n) => n == 1 ? asili : null;
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final akis = StreamController<int>();
      addTearDown(akis.close);
      sync.yazimTetigiBagla(
          bekleyenSayisi: akis.stream, gecikme: const Duration(milliseconds: 50));

      unawaited(sync.syncNow()); // 1. tur başladı ve pull'da ASILI
      await _bekle(60);
      expect(api.pullSayaci, 1);

      // Yazım TAM O SIRADA düştü. Süren turun `pushPending` seçkisi bu kayıttan ÖNCE alınmıştı.
      akis.add(0);
      await _bekle(60);
      akis.add(1);
      await _bekle(200);
      expect(api.pullSayaci, 1, reason: 'süren tur beklenir — çift tur koşmaz');

      asili.complete(); // 1. tur nihayet döndü
      await _bekle(200);

      expect(api.pullSayaci, 2,
          reason: 'süren tura BAĞLANMAK yetmez: o turun seçkisi bu kaydı görmemişti. '
              'Taze tur açılmazsa kayıt bir sonraki ARALIĞA kalır — düzeltmek istediğimiz '
              'arızanın ta kendisi');
    });
  });

  group('Yazım tetiği — yazma yolu ağa ASLA bağlanmaz (BRIEF kırmızı çizgi #3)', () {
    test('push asılıyken yazım çağrısı BEKLEMEZ, kayıt outbox\'ta pending kalır', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi()..pushDavranis = (_) => Completer<void>(); // asla dönmez
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      // GERÇEK DB akışı: tetiğin üretim kaynağı da sınanıyor (watchBekleyenSayisi).
      sync.yazimTetigiBagla(gecikme: const Duration(milliseconds: 50));
      await _bekle(150); // taban (0) geldi

      final sure = Stopwatch()..start();
      await enqueueOutbox(db,
          entityType: 'order',
          op: 'assigned',
          entityId: 'siparis-1',
          occurredAt: nowIso(),
          payload: {'order_id': 'siparis-1', 'assigned_user_id': 'kurye-7'});
      sure.stop();

      expect(sure.elapsedMilliseconds, lessThan(1000),
          reason: 'yazım ağ turunu BEKLEMEZ; beklese kapıdaki patron asılı bir istek yüzünden '
              'sipariş atayamazdı');

      await _bekle(300);
      expect(api.pushSayaci, 1, reason: 'tur açıldı ve ağda asılı kaldı — yazımdan BAĞIMSIZ');
      final satir = await (db.select(db.outbox)
            ..where((t) => t.entityId.equals('siparis-1')))
          .getSingle();
      expect(satir.status, 'pending', reason: 'ağ dönmediyse kayıt SIRADA bekler, kaybolmaz');
    });

    test('çevrimdışıyken tur düşer ama kayıt pending kalır (kaybolmaz, karantinaya girmez)',
        () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi()..pushDavranis = (_) => Exception('ağ yok');
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final sonuclar = <SyncOutcome>[];
      final sub = sync.status.listen(sonuclar.add);
      addTearDown(sub.cancel);

      sync.yazimTetigiBagla(gecikme: const Duration(milliseconds: 50));
      await _bekle(150);

      await enqueueOutbox(db,
          entityType: 'order',
          op: 'assigned',
          entityId: 'siparis-2',
          occurredAt: nowIso(),
          payload: {'order_id': 'siparis-2', 'assigned_user_id': 'kurye-7'});
      await _bekle(300);

      expect(sonuclar, isNotEmpty, reason: 'tetik turu AÇTI (çevrimdışı olsa bile)');
      expect(sonuclar.last.ok, isFalse);
      expect(sonuclar.last.tur, SyncHataTuru.ag);
      final satir = await (db.select(db.outbox)
            ..where((t) => t.entityId.equals('siparis-2')))
          .getSingle();
      expect(satir.status, 'pending',
          reason: 'ağ hatası bir REDDİYE değildir — kayıt sırada bekler, bağlanınca gider');
    });
  });

  group('Yazım tetiği — stop() her şeyi bırakır', () {
    test('durdurulmuş serviste yazım olayı tur AÇMAZ', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final akis = StreamController<int>();
      addTearDown(akis.close);
      sync.yazimTetigiBagla(
          bekleyenSayisi: akis.stream, gecikme: const Duration(milliseconds: 50));
      akis.add(0);
      await _bekle(80);
      sync.stop();

      akis.add(9);
      await _bekle(250);
      expect(api.pullSayaci, 0,
          reason: 'çıkış yapıldıktan sonra düşen bir yazım oturumsuz tur açmamalı');
    });

    test('pencere AÇIKKEN gelen stop() bekleyen turu iptal eder', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final akis = StreamController<int>();
      addTearDown(akis.close);
      sync.yazimTetigiBagla(
          bekleyenSayisi: akis.stream, gecikme: const Duration(milliseconds: 300));
      akis.add(0);
      await _bekle(60);
      akis.add(1); // pencere açıldı: tur 300 ms sonra koşacaktı
      await _bekle(60);
      sync.stop(); // pencere DOLMADAN çıkış

      await _bekle(400);
      expect(api.pullSayaci, 0,
          reason: 'bekleyen gecikme timer\'ı iptal edilmezse çıkıştan sonra oturumsuz bir tur '
              'koşar (ve widget testinde "Timer is still pending" ile test düşerdi)');
    });

    test('yeniden bağlanınca ilk yayın YİNE taban kurar (sahte artış üretmez)', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      final ilk = StreamController<int>();
      addTearDown(ilk.close);
      sync.yazimTetigiBagla(
          bekleyenSayisi: ilk.stream, gecikme: const Duration(milliseconds: 50));
      ilk.add(0); // taban 0
      await _bekle(80);
      sync.stop(); // çıkış

      // Giriş: yeni bağlanma, kuyrukta 4 kayıt duruyor.
      final ikinci = StreamController<int>();
      addTearDown(ikinci.close);
      sync.yazimTetigiBagla(
          bekleyenSayisi: ikinci.stream, gecikme: const Duration(milliseconds: 50));
      ikinci.add(4);
      await _bekle(250);

      expect(api.pullSayaci, 0,
          reason: 'stop() `_sonBekleyen`i sıfırlamazsa eski taban (0) korunur ve çıkış/giriş '
              'sonrası bekleyen kayıtlar 0→4 sahte ARTIŞI gibi görünürdü');
    });
  });

  group('aralikDegistir — ön plan ⇄ arka plan', () {
    test('AYNI değerde yeniden kurulum YOK (sayaç baştan başlamaz)', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      sync.start(every: const Duration(milliseconds: 400)); // t=0: 1. tur hemen
      await _bekle(250);
      expect(api.pullSayaci, 1);

      sync.aralikDegistir(const Duration(milliseconds: 400)); // t≈250: AYNI değer
      await _bekle(270); // t≈520

      expect(api.pullSayaci, 2,
          reason: 'zamanlayıcı yeniden kurulsaydı geri sayım t≈250\'de sıfırlanır ve tik '
              't≈650\'ye kayardı: her yaşam döngüsü olayı senkronu bir aralık daha geciktirirdi');
    });

    test('DURDURULMUŞ servisi diriltmez', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      sync.start(every: const Duration(milliseconds: 200));
      sync.stop();
      sync.aralikDegistir(const Duration(milliseconds: 100)); // çıkıştan sonra "öne geldi"

      await _bekle(500);
      expect(api.pullSayaci, 1,
          reason: 'yalnız `start()`ın attığı ilk tur sayılır — çıkış yapıldıktan sonra gelen bir '
              'yaşam döngüsü olayı senkronu YENİDEN BAŞLATMAMALI');
    });

    test('tur ATMAZ (öne gelişte çift istek olmasın)', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      sync.start(every: const Duration(seconds: 5));
      await _bekle(100);
      expect(api.pullSayaci, 1, reason: 'start() ilk turu atar');

      sync.aralikDegistir(SyncService.onPlanAralik); // 30 sn — tik testte hiç gelmez
      await _bekle(200);
      expect(api.pullSayaci, 1,
          reason: 'aralık değişimi tur ATMAZ: bunu çağıran `resumed` dalı zaten kendi turunu '
              'açıyor, buradan bir tur daha atmak her öne gelişte ÇİFT istek demekti');
    });
  });

  group('UÇTAN UCA — patron atar, atama sunucuya gider', () {
    test('assign() → outbox → tetik → sahte sunucunun payload\'ında atama görünür', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);
      final repo = OrderRepository(db);
      final orderId = await repo.create(
          lines: [LineInput(productName: 'Tüp', unitPriceKurus: 30000, qty: 1)]);

      final api = _KayitliApi();
      final sync = SyncService(db, api: api);
      addTearDown(sync.dispose);

      // Üretimdeki kaynağın kendisi (`db.watchBekleyenSayisi()`) — sahte akış YOK.
      sync.yazimTetigiBagla(gecikme: const Duration(milliseconds: 50));
      await _bekle(200); // taban: `created` kaydı zaten bekliyor
      expect(api.pullSayaci, 0, reason: 'bağlanmak tek başına tur açmaz');

      await repo.assign(orderId, 'kurye-7'); // PATRON SİPARİŞİ KURYEYE ATIYOR
      await _bekle(400);

      expect(api.pushSayaci, greaterThanOrEqualTo(1),
          reason: 'atama outbox\'a düştü ama turu kimse açmazsa kurye yenilese bile göremez '
              '(sahadan bildirilen belirtinin ta kendisi)');
      final atama = api.gonderilenler.firstWhere((e) => e['op'] == 'assigned',
          orElse: () => <String, Object?>{});
      expect(atama['entity_type'], 'order', reason: 'atama olayı sunucuya GERÇEKTEN gitti');
      expect((atama['payload'] as Map?)?['assigned_user_id'], 'kurye-7',
          reason: 'kuryenin kimliği zarfta taşınmalı — sunucu atamayı buradan uygular');

      final satir = await (db.select(db.outbox)..where((t) => t.op.equals('assigned')))
          .getSingle();
      expect(satir.status, 'acked', reason: 'sunucu onayladı, kayıt kuyruktan düştü');
    });
  });
}
