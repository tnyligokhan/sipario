// `isNull` hem drift'te hem matcher'da tanımlı; burada matcher'ınki isteniyor.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/islem_sahibi.dart';

import 'support/migration_yardimcilari.dart';

/// v24→v25 — TESLİMİ KİM YAPTI (`orders.delivered_by_user_id`, 2026-08-20).
///
/// `migration_v16`/`v18`/`v19`/`v20`/`v21` ile aynı aileden: sahadaki telefon `onUpgrade`
/// yolundan geçer, bellek içi veritabanı kuran testler `onCreate` yolundan.
///
/// BU ADIMDA SESSİZLİĞİN BEDELİ EN AĞIRLARDAN: kolon eksikken `OrderRepository._recompute`
/// "no such column: delivered_by_user_id" ile düşer — yani kurye siparişi HİÇ TESLİM EDEMEZ.
/// Ürünün günlük işi durur ve hata ekranda "kaydedilemedi" diye görünür; sebebi görünmez.
void main() {
  test(
      'v24→v25: orders.delivered_by_user_id sahadaki cihaza EKLENİR, eski siparişler aynen '
      'durur, atıf NULL doğar (geriye dönük UYDURULMAZ) ve okuma ATAMAYA düşer', () async {
    final db = await eskiCihaziYukselt(
      etiket: 'v24v25',
      surum: 24,
      veriYaz: (v25) async {
        await v25.into(v25.users).insert(UsersCompanion.insert(
              id: 'k1',
              name: 'Ali',
              role: 'kurye',
              status: 'active',
            ));
        await v25.into(v25.customers).insert(CustomersCompanion.insert(
              id: 'm-1',
              name: 'Ayşe Yılmaz',
              updatedOccurredAt: '2026-08-19T00:00:00.000Z',
            ));
        await v25.into(v25.orders).insert(OrdersCompanion.insert(
              id: 'sip-eski',
              customerId: const Value('m-1'),
              assignedUserId: const Value('k1'),
              status: const Value('delivered'),
              totalKurus: const Value(120000),
              paymentType: const Value('veresiye'),
              occurredAt: DayEndRepository.bugunTr()
                  .add(const Duration(hours: 12))
                  .toUtc()
                  .toIso8601String(),
            ));
      },
      geriSar: ['ALTER TABLE orders DROP COLUMN delivered_by_user_id'],
    );

    expect(await kolonlar(db, 'orders'), contains('delivered_by_user_id'));

    final eski = await (db.select(db.orders)..where((t) => t.id.equals('sip-eski'))).getSingle();

    // Eski sipariş AYNEN durur — teslim edilmiş bir sipariş bayinin defteridir.
    expect(eski.customerId, 'm-1');
    expect(eski.assignedUserId, 'k1');
    expect(eski.status, 'delivered');
    expect(eski.totalKurus, 120000);

    // ⭐ ATIF UYDURULMAZ: atama DOLU olmasına rağmen `delivered_by_user_id` NULL kalır. Kimin
    // teslim ettiği o gün hiçbir yere yazılmadı; atamayı olguya terfi ettirmek, tam da bu
    // sürümde düzeltilen hatayı geçmişe kalıcı olarak çivilemek olurdu.
    expect(eski.deliveredByUserId, isNull);

    // ⭐ AMA OKUMA SESSİZ KALMAZ: atıf boşken kural atamaya düşer, yani yükseltmeden ÖNCEKİ
    // davranış birebir korunur — geçmiş gün ekranları bir gecede boşalmaz.
    expect(
      await DayEndRepository(db).teslimatSayisi(DayEndRepository.bugunTr(), userId: 'k1'),
      1,
    );
    expect(siparisSahibi(deliveredByUserId: eski.deliveredByUserId, assignedUserId: 'k1'), 'k1');

    // Yeni teslimler alanı gerçekten yazabilmeli (özellik açılmış olmalı, kolon dekoratif değil).
    await (db.update(db.orders)..where((t) => t.id.equals('sip-eski')))
        .write(const OrdersCompanion(deliveredByUserId: Value('p1')));
    final guncel = await (db.select(db.orders)..where((t) => t.id.equals('sip-eski'))).getSingle();
    expect(guncel.deliveredByUserId, 'p1');
    expect(
      await DayEndRepository(db).teslimatSayisi(DayEndRepository.bugunTr(), userId: 'k1'),
      0,
      reason: 'atıf yazıldıktan sonra ATAMA artık okunmaz — olgu niyeti ezer',
    );

    await semaTamOlmali(db);
  });
}
