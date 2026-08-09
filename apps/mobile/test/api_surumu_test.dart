// API SÜRÜMÜ — sunucunun sözleşme sürümü telefonda GÖRÜNÜR mü?
//
// 2026-08-09'da API'ye SemVer geldi (`apps/api/config/app.php` → 1.0.0) ama sürüm HİÇBİR yanıtta
// okunmuyordu. Bu, bu depoda dört kez ödenen "tanımlı ama bağlı değil" desenidir: bir değerin
// HESAPLANMASI, SAKLANMASI ve OKUNMASI üç ayrı şeydir; ilk ikisi tamken sistem çalışıyor GÖRÜNÜR.
// Bedeli bir saha arızasında ödenir: "sunucu mu eski, telefon mu?" sorusunun cevabı yoktur.
//
// Bu dosya zincirin telefon tarafındaki üç halkasını kilitler:
//   ayrıştırıcı (api_version okunuyor mu) → motor (sync_meta'ya yazılıyor mu) → ekran (metin).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/isletme/ayarlar_ekrani.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';

import 'support/fake_sync_api.dart';

Future<AppDatabase> _oturumluDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
      .write(const SyncMetaCompanion(authToken: Value('test-token'), lastPulledSeq: Value(10)));
  return db;
}

void main() {
  group('ayrıştırıcı — api_version', () {
    test('pull ve push yanıtlarındaki api_version OKUNUR', () {
      // Zincirin ilk halkası. Sunucu göndermesine rağmen buradan okunmasaydı alan yok demekti.
      final pull = PullResponse.fromJson(const {
        'mode': 'delta',
        'cursor': 12,
        'has_more': false,
        'current_seq': 12,
        'api_version': '1.2.3',
      });
      expect(pull.apiSurum, '1.2.3');

      final push = PushResponse.fromJson(const {
        'results': <dynamic>[],
        'current_seq': 12,
        'api_version': '1.2.3',
      });
      expect(push.apiSurum, '1.2.3');
    });

    test('alan YOKSA null olur — eski sunucu senkronu düşürmez', () {
      // Kanal ayrımından sonra telefonlar günlerce eski bir sunucuyla konuşabilir; alanın
      // yokluğu bir arıza DEĞİLDİR.
      final pull = PullResponse.fromJson(const {
        'mode': 'delta',
        'cursor': 1,
        'has_more': false,
        'current_seq': 1,
      });
      expect(pull.apiSurum, isNull);
    });

    test('String OLMAYAN değer null sayılır, TypeError ATILMAZ', () {
      // `as String` yazsaydık sunucunun bir gün sayı göndermesi TÜM senkron turunu düşürürdü.
      // Bir GÖSTERİM alanının senkronu durdurmaya yetkisi yoktur (`EventResult._metin` dersi).
      for (final bozuk in <Object?>[42, <String, Object?>{}, <Object?>[], '']) {
        final pull = PullResponse.fromJson({
          'mode': 'delta',
          'cursor': 1,
          'has_more': false,
          'current_seq': 1,
          'api_version': bozuk,
        });
        expect(pull.apiSurum, isNull, reason: 'bozuk değer ($bozuk) null olmalıydı');
      }
    });
  });

  group('motor — sync_meta önbelleği', () {
    test('pull turunda görülen sürüm sync_meta\'ya YAZILIR', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()..apiSurum = '1.0.0';
      await SyncEngine(db, api).pull();

      expect((await db.syncState()).apiVersion, '1.0.0');
    });

    test('push turunda da yazılır — yalnız pull yapan cihaz yoktur, tersi de doğru', () async {
      final db = await _oturumluDb();
      addTearDown(db.close);

      await db.into(db.outbox).insert(OutboxCompanion.insert(
            clientEventId: 'ev-1',
            entityType: 'customer',
            entityId: const Value('c-1'),
            op: 'upsert',
            payload: '{"id":"c-1","name":"Ahmet"}',
            occurredAt: '2026-08-10T10:00:00.000Z',
            createdAt: '2026-08-10T10:00:00.000Z',
          ));

      final api = FakeSyncApi()..apiSurum = '2.0.0';
      await SyncEngine(db, api).pushPending();

      expect((await db.syncState()).apiVersion, '2.0.0');
    });

    test('YENİ SÜRÜM ezer ama YOKLUK EZMEZ — bilinen son sürüm silinmez', () async {
      // ASIL İDDİA. Sürüm bildirmeyen tek bir yanıt (eski sunucu, araya giren bir katman)
      // Ayarlar'daki satırı boşaltıp "bilinmiyor" yalanını söyleyemez.
      final db = await _oturumluDb();
      addTearDown(db.close);

      final api = FakeSyncApi()..apiSurum = '1.0.0';
      final engine = SyncEngine(db, api);
      await engine.pull();
      expect((await db.syncState()).apiVersion, '1.0.0');

      api.apiSurum = '1.1.0';
      await engine.pull();
      expect((await db.syncState()).apiVersion, '1.1.0', reason: 'yeni sürüm eskisini ezmeliydi');

      api.apiSurum = null;
      await engine.pull();
      expect((await db.syncState()).apiVersion, '1.1.0',
          reason: 'sürüm bildirmeyen yanıt bilinen son sürümü SİLEMEZ');
    });
  });

  group('ekran metni — Ayarlar → Hakkında → Sunucu', () {
    test('sürüm biliniyorsa "API <sürüm>" yazar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(apiVersion: Value('1.0.0')));

      expect(sunucuSurumuMetni(await db.syncState()), 'API 1.0.0');
    });

    test('hiç senkron olmamış cihazda UYDURMAZ', () {
      // Ekran metni iddia etmez: "güncel" ya da "uyumlu" demek, karşılaştırma yapmadığımız
      // hâlde yapıyormuş gibi görünmek olurdu.
      expect(sunucuSurumuMetni(null), 'Henüz bağlanılmadı');
    });
  });
}
