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
import 'package:sipario/sync/sync_engine.dart';
import 'package:sipario/sync/sync_api.dart';

import 'support/fake_sync_api.dart';

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine motor;

  /// Sunucudan inen tek bir `call_log` değişikliğini GERÇEK pull yolundan uygular.
  ///
  /// Zarfı elle kurmak bilinçli: sınanan şey tam olarak "sunucunun gönderdiği anahtar kümesi"
  /// — `user_id`nin VAR ya da YOK olması. Repo üzerinden yazsaydık o ayrımı hiç kuramazdık.
  /// ⚠️ DAMGA GERÇEKTEN YENİ OLMALI: pull yolu LWW uygular ve geride kalan bir zarf sessizce
  /// 'stale' sayılır. İlk yazımda sabit bir geçmiş damga kullanmıştım; koruma testi YEŞİL
  /// geçiyordu ama YANLIŞ SEBEPLE — alan korunduğu için değil, zarfın tamamı reddedildiği için.
  /// Karşı test (sunucu değeri kazanır) bunu ortaya çıkardı.
  String yeniDamga() =>
      DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String();

  Future<void> uygulaCallLog(Map<String, Object?> payload) async {
    payload = {'updated_occurred_at': yeniDamga(), ...payload};
    api.pullQueue.add(PullResponse(
      mode: 'delta',
      cursor: 11,
      hasMore: false,
      currentSeq: 11,
      changes: [
        {
          'seq': 11,
          'entity_type': 'call_log',
          'entity_id': payload['id'],
          'op': 'upsert',
          'occurred_at': payload['updated_occurred_at'],
          'payload': payload,
        },
      ],
    ));
    await motor.pull();
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    motor = SyncEngine(db, api);
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

  test('SUNUCU alanı BİLMİYORSA cihazdaki atıf EZİLMEZ', () async {
    // GERÇEK CİHAZDA YAKALANDI (2026-08-13). Telefon atfı doğru yazdı, ama uygulama alanı
    // henüz bilmeyen CANLI sunucuya bağlıydı: sunucu `user_id`yi düşürdü, pull o satırı geri
    // getirdi ve istemci EKSİK anahtarı "null" sayıp kendi doğru verisini EZDİ. Belirti
    // sinsiydi — kayıt görünüyor, atıf birkaç saniye sonra kayboluyor, süzgeç hiçbir şey
    // bulamıyordu.
    //
    // Kural: GELMEYEN ALAN, "BOŞ" DEMEK DEĞİLDİR. Sunucu tarafında karşılığı
    // `SyncPayload::gonderilenler`, istemci pull yolunda `SyncEngine._korunan`.
    final id = await CallLogRepository(db).log(
      phoneE164: '+905324152290',
      direction: CallDirection.incoming,
    );

    // Eski sunucunun döndüğü zarf: `user_id` anahtarı HİÇ YOK.
    await uygulaCallLog({
      'id': id,
      'phone_e164': '+905324152290',
      'phone_last10': '5324152290',
      'direction': 'incoming',
      'occurred_at': '2026-08-13T09:15:00Z',
    });

    final satir = await (db.select(db.callLogs)..where((t) => t.id.equals(id))).getSingle();
    expect(satir.userId, 'u-emre',
        reason: 'sunucu alanı bilmiyorsa cihazdaki atıf KORUNUR, null ile ezilmez');
  });

  test('SUNUCU alanı BİLİYORSA gönderdiği değer yazılır (null dahil)', () async {
    // Korumanın diğer yarısı: anahtar VARSA sunucu kazanır. Aksi hâlde bir kullanıcı
    // sunucudan silindiğinde ya da atıf bilinçli olarak boşaltıldığında cihaz eski değeri
    // sonsuza dek tutardı.
    final id = await CallLogRepository(db).log(
      phoneE164: '+905324152290',
      direction: CallDirection.incoming,
    );

    await uygulaCallLog({
      'id': id,
      'phone_e164': '+905324152290',
      'phone_last10': '5324152290',
      'direction': 'incoming',
      'user_id': 'u-selin',
      'occurred_at': '2026-08-13T09:15:00Z',
    });

    final satir = await (db.select(db.callLogs)..where((t) => t.id.equals(id))).getSingle();
    expect(satir.userId, 'u-selin');
  });
}
