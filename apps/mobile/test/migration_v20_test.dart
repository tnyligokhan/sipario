// `isNull` hem drift'te hem matcher'da tanımlı; burada matcher'ınki isteniyor.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';

import 'support/migration_yardimcilari.dart';

/// v19→v20 — ARA TAHSİLAT İPTAL KAYDI (`cash_handovers.reverses_handover_id`, 2026-08-13).
///
/// `migration_v16`/`v18`/`v19` ile aynı aileden: sahadaki telefon `onUpgrade` yolundan geçer,
/// bellek içi veritabanı kuran testler `onCreate` yolundan — ve orada şema hep tamdır.
///
/// BU ADIMDA SESSİZLİĞİN BEDELİ İKİ KATLIDIR: (1) kolon yoksa `cash_handovers`a dokunan HER
/// sorgu `no such column` ile patlar ve o tablo gün özetinin (kasa devri · ara tahsilat ·
/// kapanış önizlemesi) tam ortasındadır — patron gün sonu ekranını hiç açamaz; (2) tablo
/// APPEND-ONLY PARA kaydıdır (BRIEF kırmızı çizgi #2), yani yükseltmenin satırları ezmemesi
/// pazarlık konusu değildir: iptal ters işaretli İKİNCİ bir satırdır, orijinal kanıt yerinde kalır.
void main() {
  test(
      'v19→v20: cash_handovers.reverses_handover_id sahadaki cihaza EKLENİR, eski devir '
      'satırının PARASI aynen durur, kolon NULL doğar ("bu satır iptal değil") ve iptal kaydı '
      'yazılabilir hâle gelir', () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v19v20',
      surum: 19,
      veriYaz: (v20) async {
        await v20.into(v20.cashHandovers).insert(CashHandoversCompanion.insert(
              id: 'devir-1',
              fromUserId: 'kurye-1',
              toUserId: const Value('patron-1'),
              countedCashKurus: 145000,
              expectedCashKurus: 150000,
              diffKurus: -5000,
              occurredAt: '2026-08-12T19:00:00.000Z',
              note: const Value('akşam devri'),
            ));
      },
      geriSar: ['ALTER TABLE cash_handovers DROP COLUMN reverses_handover_id'],
    );

    expect(await kolonlar(db, 'cash_handovers'), contains('reverses_handover_id'));

    // ⭐ ASIL İDDİA: tabloyu okuyan sorgunun kendisi. Kolon eksikken bu satır
    // `no such column: cash_handovers.reverses_handover_id` ile kırmızı yanardı.
    final devir =
        await (db.select(db.cashHandovers)..where((t) => t.id.equals('devir-1'))).getSingle();

    // PARA AYNEN durur — sayılan, beklenen ve FARK (kanıt) ezilmez.
    expect(devir.countedCashKurus, 145000);
    expect(devir.expectedCashKurus, 150000);
    expect(devir.diffKurus, -5000);
    expect(devir.fromUserId, 'kurye-1');
    expect(devir.note, 'akşam devri');

    // Eski satırların HİÇBİRİ iptal kaydı değildir ve `null` tam olarak bunu söyler. Buraya
    // varsayılan bir kimlik yazmak, olmamış bir geri almayı defterde OLMUŞ gibi gösterirdi.
    expect(devir.reversesHandoverId, isNull);

    // Ve özellik gerçekten çalışır hâle gelir: iptal, orijinali SİLMEZ — ters işaretli ikinci
    // satırdır ve ilkine işaret eder.
    await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
          id: 'devir-1-iptal',
          fromUserId: 'kurye-1',
          toUserId: const Value('patron-1'),
          countedCashKurus: -145000,
          expectedCashKurus: -150000,
          diffKurus: 5000,
          reversesHandoverId: const Value('devir-1'),
          occurredAt: '2026-08-13T09:00:00.000Z',
        ));

    final hepsi = await db.select(db.cashHandovers).get();
    expect(hepsi, hasLength(2), reason: 'orijinal kayıt kanıt olarak YERİNDE durur');
    expect(hepsi.map((h) => h.countedCashKurus).reduce((a, b) => a + b), 0,
        reason: 'toplam kendiliğinden sıfırlanır — satır ezilerek değil');

    await semaTamOlmali(db, gerekce: 'v19 damgalı cihaz bugüne yükseltildi.');
  });
}
