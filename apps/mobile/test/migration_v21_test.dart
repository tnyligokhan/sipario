// `isNull` hem drift'te hem matcher'da tanımlı; burada matcher'ınki isteniyor.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';

import 'support/migration_yardimcilari.dart';

/// v20→v21 — ÇAĞRIYI KİM KARŞILADI (`call_logs.user_id`, 2026-08-13).
///
/// `migration_v16`/`v18`/`v19`/`v20` ile aynı aileden: sahadaki telefon `onUpgrade` yolundan
/// geçer, bellek içi veritabanı kuran testler `onCreate` yolundan.
///
/// BU ADIMDA SESSİZLİĞİN BEDELİ: kolon yoksa çağrı günlüğüne dokunan her sorgu patlar — ve
/// arayan tanıma kartının YAZDIĞI kayıt da düşer. Yani telefon çalarken ürünün çekirdek
/// özelliği ölür; native taraf kartı çizer, uygulama tarafı onu kaydedemez.
void main() {
  test(
      'v20→v21: call_logs.user_id sahadaki cihaza EKLENİR, eski çağrı kayıtları aynen durur, '
      'atıf NULL doğar (geriye dönük UYDURULMAZ) ve yeni çağrılar kişiyle yazılabilir', () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v20v21',
      surum: 20,
      veriYaz: (v21) async {
        await v21.into(v21.customers).insert(CustomersCompanion.insert(
              id: 'm-1',
              name: 'Kadir Doğan',
              updatedOccurredAt: '2026-08-13T00:00:00.000Z',
            ));
        await v21.into(v21.callLogs).insert(CallLogsCompanion.insert(
              id: 'cl-eski',
              customerId: const Value('m-1'),
              phoneE164: '+905324152290',
              phoneLast10: '5324152290',
              direction: 'incoming',
              outcome: const Value('siparis'),
              deviceId: const Value('cihaz-A'),
              occurredAt: '2026-08-12T18:30:00.000Z',
              updatedOccurredAt: '2026-08-12T18:30:00.000Z',
            ));
      },
      geriSar: ['ALTER TABLE call_logs DROP COLUMN user_id'],
    );

    expect(await kolonlar(db, 'call_logs'), contains('user_id'));

    // ⭐ ASIL İDDİA: çağrı günlüğünü çeken sorgunun kendisi ("Son Aramalar" listesi).
    final eski = await (db.select(db.callLogs)..where((t) => t.id.equals('cl-eski'))).getSingle();

    // Eski kayıt AYNEN durur — çağrı geçmişi bayinin iş hafızasıdır, yükseltme onu kesemez.
    expect(eski.phoneLast10, '5324152290');
    expect(eski.customerId, 'm-1');
    expect(eski.outcome, 'siparis');
    expect(eski.deviceId, 'cihaz-A');

    // ⭐ ATIF UYDURULMAZ: `device_id` DOLU olmasına rağmen `user_id` NULL kalır. Cihazdan kişiye
    // geriye dönük eşleme "o gün o telefonu kim kullandı" VARSAYIMIdır; yanlış bir isim, bir
    // kuryeyi yapmadığı aramadan sorumlu tutar. Ekran "bilinmiyor" demeli.
    expect(eski.userId, isNull);

    // Yeni çağrılar kişiyle yazılabilir (özellik gerçekten açılmış olmalı).
    await db.into(db.callLogs).insert(CallLogsCompanion.insert(
          id: 'cl-yeni',
          phoneE164: '+905441112233',
          phoneLast10: '5441112233',
          direction: 'incoming',
          userId: const Value('u-operator'),
          occurredAt: '2026-08-14T09:00:00.000Z',
          updatedOccurredAt: '2026-08-14T09:00:00.000Z',
        ));
    final yeni = await (db.select(db.callLogs)..where((t) => t.id.equals('cl-yeni'))).getSingle();
    expect(yeni.userId, 'u-operator');

    await semaTamOlmali(db, gerekce: 'v20 damgalı cihaz bugüne yükseltildi.');
  });
}
