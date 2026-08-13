// ÇAĞRI ATFI — "kim aradı / kim karşıladı" (kullanıcı isteği 2026-08-13).
//
// NEDEN GEREKTİ: patron ve izin verdiği kullanıcılar diğer kullanıcıların arama geçmişini
// görebilmeli. Çağrı kayıtları ZATEN senkronlanıyordu ve ekran bayinin tüm çağrılarını
// gösteriyordu — eksik olan tek şey ATIFTI. Tabloda yalnız `device_id` vardı ve o bir CİHAZI
// anlatır, kişiyi değil: aynı telefonu iki kişi kullanabilir, kurye telefon değiştirince
// geçmiş kopar.
//
// KİLİTLENEN ÜÇ ŞEY:
//   ① yazılan çağrı oturumdaki kullanıcıyı taşır ve sunucuya giden yükte de geçer;
//   ② ekran modeli adı `users` aynasından çözer, ham kimlik BASILMAZ;
//   ③ süzgeç SORGUDA çalışır — `limit` ile birleştiğinde Dart tarafında elemek sessizce
//      yanlış olurdu (son 50 kaydın içinden 3 satır gösterip "kuryem hiç aramamış" dedirtir).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/call_log_repository.dart';
import 'package:sipario/screens/cagri/cagri_gunlugu.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(const SyncMetaCompanion(userId: Value('u-emre'), deviceId: Value('cihaz-1')));
    for (final (id, ad) in [('u-emre', 'Emre'), ('u-selin', 'Selin')]) {
      await db.into(db.users).insertOnConflictUpdate(UsersCompanion.insert(
            id: id,
            name: ad,
            role: 'kurye',
            status: 'active',
          ));
    }
  });

  test('yazılan çağrı OTURUMDAKİ kullanıcıyı taşır ve yüke geçer', () async {
    final id = await CallLogRepository(db).log(
      phoneE164: '+905324152290',
      direction: CallDirection.incoming,
    );

    final satir = await (db.select(db.callLogs)..where((t) => t.id.equals(id))).getSingle();
    expect(satir.userId, 'u-emre', reason: 'atıf yazılmazsa "kim aradı" sorulamaz');

    // Sunucuya giden zarf: alan taşınmazsa özellik tek cihazlık kalır (patron kuryenin
    // çağrısını kendi telefonunda atıfsız görür).
    final olay = await (db.select(db.outbox)..where((t) => t.entityId.equals(id))).getSingle();
    expect(olay.payload, contains('"user_id":"u-emre"'));
  });

  test('SONUÇ sonradan yazılınca atıf DEĞİŞMEZ', () async {
    // Çağrıyı karşılayan kişi ile sonucu işaretleyen kişi aynı olmak zorunda değil: patron
    // akşam "sipariş alındı" yazabilir. Atfı üzerine yazmak, çağrıyı yapmamış birini yapmış
    // gibi gösterirdi.
    final id = await CallLogRepository(db).log(
      phoneE164: '+905324152290',
      direction: CallDirection.incoming,
    );
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(const SyncMetaCompanion(userId: Value('u-selin')));

    await CallLogRepository(db).setOutcome(id, outcome: 'Sipariş alındı');

    final satir = await (db.select(db.callLogs)..where((t) => t.id.equals(id))).getSingle();
    expect(satir.userId, 'u-emre');
  });

  test('ekran modeli adı AYNADAN çözer; kimlik varsa ham UUID basılmaz', () async {
    await CallLogRepository(db).log(
      phoneE164: '+905324152290',
      direction: CallDirection.incoming,
    );

    final liste = await aramaKayitlariAkisi(db).first;
    expect(liste, hasLength(1));
    expect(liste.first.kullaniciId, 'u-emre');
    expect(liste.first.kullaniciAdi, 'Emre');
  });

  test('AYNADA OLMAYAN kullanıcıda ad null kalır — atıf uydurulmaz', () async {
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(const SyncMetaCompanion(userId: Value('u-silinmis')));
    await CallLogRepository(db).log(
      phoneE164: '+905331112233',
      direction: CallDirection.outgoing,
    );

    final liste = await aramaKayitlariAkisi(db).first;
    expect(liste.first.kullaniciId, 'u-silinmis');
    expect(liste.first.kullaniciAdi, isNull,
        reason: 'ad çözülemiyorsa boş kalır; ekran ham kimlik göstermez');
  });

  test('SÜZGEÇ sorguda çalışır — limitle birlikte de doğru', () async {
    // Emre 1, Selin 2 çağrı. limit: 2 ile Selin süzgeci Emre'nin kaydını değil, SELİN'İN İKİ
    // kaydını döndürmeli. Süzgeç Dart tarafında olsaydı: sorgu son 2 kaydı (Selin+Selin ya da
    // Selin+Emre) çeker, sonra elerdi — bayi eksik liste görürdü.
    final repo = CallLogRepository(db);
    await repo.log(phoneE164: '+905324152290', direction: CallDirection.incoming);
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(const SyncMetaCompanion(userId: Value('u-selin')));
    await repo.log(phoneE164: '+905331112233', direction: CallDirection.outgoing);
    await repo.log(phoneE164: '+905339998877', direction: CallDirection.incoming);

    final selin = await aramaKayitlariAkisi(db, limit: 2, kullaniciId: 'u-selin').first;
    expect(selin, hasLength(2));
    expect(selin.every((a) => a.kullaniciAdi == 'Selin'), isTrue);

    final emre = await aramaKayitlariAkisi(db, kullaniciId: 'u-emre').first;
    expect(emre, hasLength(1));
  });
}
