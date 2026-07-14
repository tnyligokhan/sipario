import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/data/ids.dart';
import 'package:sipario/data/outbox.dart';
import 'package:sipario/repo/coupon_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/ledger_ops.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';

/// FAZ 3 defter/kupon istemci iş akışları. Para İMZALI çift-satır (DECISIONS): debit+borç,
/// payment−borç; kupon ADET (coupon_movements) + türetilen bakiye. Her yazım yerel + outbox tek
/// transaction (Faz 2 atomikliği). Gün sonu salt-okuma.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  DateTime trToday() {
    final tr = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(tr.year, tr.month, tr.day);
  }

  test('tahsilat: payment(−) yazar, bakiye önbelleği defterden azalır, outbox ledger', () async {
    final custId = await CustomerRepository(db).create(name: 'Borçlu');
    final ledger = LedgerRepository(db);

    await ledger.borcEkle(custId, 15000); // debit +15000
    await ledger.tahsilat(custId, 5000, 'nakit'); // payment -5000

    final cust = await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle();
    expect(cust.balanceKurus, 10000, reason: 'debit 15000 − tahsilat 5000 = 10000 borç');

    final entries = await db.select(db.ledgerEntries).get();
    expect(entries, hasLength(2));
    final payment = entries.firstWhere((e) => e.entryType == 'payment');
    expect(payment.amountKurus, -5000);
    expect(payment.paymentType, 'nakit');

    // Her yerel yazımın outbox ikizi var (ledger entity_type).
    final ledgerOutbox = await (db.select(db.outbox)..where((t) => t.entityType.equals('ledger'))).get();
    expect(ledgerOutbox, hasLength(2));
  });

  test('peşin teslimat çift-satır üretir: net borç 0, iki defter kaydı', () async {
    final custId = await CustomerRepository(db).create(name: 'Peşin Müşteri');
    final orders = OrderRepository(db);
    final orderId = await orders.create(customerId: custId,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: 9000, qty: 1)]);

    await orders.deliver(orderId, paymentType: 'nakit');

    final cust = await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle();
    expect(cust.balanceKurus, 0, reason: 'debit +9000 + payment −9000 = net 0');

    final entries = await db.select(db.ledgerEntries).get();
    expect(entries, hasLength(2));
    expect(entries.map((e) => e.entryType).toSet(), {'debit', 'payment'});
    expect(entries.every((e) => e.relatedOrderId == orderId), isTrue);
  });

  test('veresiye teslimat yalnız debit yazar: borç = toplam', () async {
    final custId = await CustomerRepository(db).create(name: 'Veresiye Müşteri');
    final orders = OrderRepository(db);
    final orderId = await orders.create(customerId: custId,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: 9000, qty: 2)]);

    await orders.deliver(orderId, paymentType: 'veresiye');

    final cust = await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle();
    expect(cust.balanceKurus, 18000);
    final entries = await db.select(db.ledgerEntries).get();
    expect(entries, hasLength(1));
    expect(entries.first.entryType, 'debit');
  });

  test('kupon satışı: grant(+qty) + peşin çift-satır (net borç 0), 3 outbox olayı', () async {
    final custId = await CustomerRepository(db).create(name: 'Kupon Alan');
    await CouponRepository(db).kuponSat(
        customerId: custId, qty: 5, priceKurus: 45000, paymentType: 'nakit');

    final bal = await (db.select(db.couponBalances)..where((t) => t.customerId.equals(custId))).getSingle();
    expect(bal.balanceQty, 5);
    expect(bal.productId, '', reason: 'genel kupon sentinel');

    final cust = await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle();
    expect(cust.balanceKurus, 0, reason: 'paket parası peşin: debit+payment net 0');

    // Outbox: customer(1) + coupon grant(1) + ledger debit(1) + ledger payment(1) = 4.
    final outbox = await db.select(db.outbox).get();
    final coupon = outbox.where((o) => o.entityType == 'coupon').toList();
    final ledger = outbox.where((o) => o.entityType == 'ledger').toList();
    expect(coupon, hasLength(1));
    expect(coupon.first.op, 'grant');
    expect(ledger, hasLength(2));
  });

  test('kupon ile teslimat: para hareketi yok, coupon use(−qty) bakiyeyi düşürür', () async {
    final custId = await CustomerRepository(db).create(name: 'Kupon Kullanan');
    final coupons = CouponRepository(db);
    await coupons.kuponSat(customerId: custId, qty: 5, priceKurus: 45000, paymentType: 'nakit');

    final ledgerBefore = (await db.select(db.ledgerEntries).get()).length;

    final orders = OrderRepository(db);
    final orderId = await orders.create(customerId: custId,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: 9000, qty: 1)]);
    await orders.deliver(orderId, paymentType: 'kupon');

    final bal = await (db.select(db.couponBalances)..where((t) => t.customerId.equals(custId))).getSingle();
    expect(bal.balanceQty, 4, reason: '5 alındı, 1 kullanıldı');

    // Kupon teslimatı DEFTER (para) kaydı üretmez (peşin ödendi).
    final ledgerAfter = (await db.select(db.ledgerEntries).get()).length;
    expect(ledgerAfter, ledgerBefore, reason: 'kupon teslimatı yeni para kaydı üretmemeli');

    final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    expect(order.paymentType, 'kupon');
  });

  test('kupon bakiyesi eksiye düşebilir (DECISIONS)', () async {
    final custId = await CustomerRepository(db).create(name: 'Son Kupon');
    final coupons = CouponRepository(db);
    await coupons.kuponSat(customerId: custId, qty: 1, priceKurus: 9000, paymentType: 'nakit');

    final orders = OrderRepository(db);
    // İki teslimat, her biri 1 kupon → 1 hak varken 2 kullanım → -1.
    for (var i = 0; i < 2; i++) {
      final orderId = await orders.create(customerId: custId,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 9000, qty: 1)]);
      await orders.deliver(orderId, paymentType: 'kupon');
    }

    final bal = await (db.select(db.couponBalances)..where((t) => t.customerId.equals(custId))).getSingle();
    expect(bal.balanceQty, -1, reason: 'teslim edilen mal gerçektir; bakiye eksiye düşer, correction ile kapatılır');
  });

  test('düzeltme ters kayıtla yapılır, kaynak kayıt silinmez (append-only)', () async {
    final custId = await CustomerRepository(db).create(name: 'Düzeltme');
    final ledger = LedgerRepository(db);
    final hataliId = await ledger.borcEkle(custId, 10000); // yanlışlıkla 10000 borç
    await ledger.duzeltme(hataliId, -10000, customerId: custId); // ters kayıt: correction -10000

    final cust = await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle();
    expect(cust.balanceKurus, 0, reason: 'debit +10000 + correction −10000 = 0');

    final entries = await db.select(db.ledgerEntries).get();
    expect(entries, hasLength(2), reason: 'kaynak kayıt durur, düzeltme yeni satır olarak eklenir');
    final correction = entries.firstWhere((e) => e.entryType == 'correction');
    expect(correction.reversesEntryId, hataliId);
  });

  test('yanlış tahsilat düzeltmesi kasayı DA düzeltir (correction payment_type kopyalar)', () async {
    final custId = await CustomerRepository(db).create(name: 'Yanlış Tahsilat');
    final ledger = LedgerRepository(db);

    final payId = await ledger.tahsilat(custId, 5000, 'nakit'); // payment −5000 nakit
    final today = trToday();
    var kasa = await DayEndRepository(db).kasaOzeti(today);
    expect(kasa.nakit, 5000, reason: 'tahsilat kasaya girdi');

    // Ters çevir: correction, ters çevirdiği payment'ın payment_type'ını (nakit) kopyalar.
    await ledger.duzeltme(payId, 5000, customerId: custId); // +5000 → payment −5000'i sıfırlar

    final cust = await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle();
    expect(cust.balanceKurus, 0, reason: 'payment −5000 + correction +5000 = 0');

    kasa = await DayEndRepository(db).kasaOzeti(today);
    expect(kasa.nakit, 0, reason: 'correction payment_type nakit taşıdı → kasa da düzeldi');

    final correction = await (db.select(db.ledgerEntries)..where((t) => t.entryType.equals('correction'))).getSingle();
    expect(correction.paymentType, 'nakit', reason: 'ters çevirdiği payment tipini kopyaladı');
  });

  test('gün sonu kasa: kart tahsilatı düzeltmesi yalnız kart gözünü düşürür, nakit gözü sabit kalır', () async {
    // "Kuruşu kuruşuna" (BRIEF): correction ters çevirdiği payment'ın payment_type'ını kopyaladığından
    // düzeltme YALNIZ o kasa gözünü etkilemeli — kart düzeltmesi nakit gözünü bozmamalı (göz bazında ayrı).
    final custId = await CustomerRepository(db).create(name: 'Çok Göz');
    final ledger = LedgerRepository(db);
    await ledger.tahsilat(custId, 3000, 'nakit');
    final kartPayId = await ledger.tahsilat(custId, 8000, 'kart');

    final today = trToday();
    var kasa = await DayEndRepository(db).kasaOzeti(today);
    expect(kasa.nakit, 3000);
    expect(kasa.kart, 8000);

    // Yanlış kaydedilen KART tahsilatını ters çevir → correction kart payment_type'ını kopyalar.
    await ledger.duzeltme(kartPayId, 8000, customerId: custId);
    kasa = await DayEndRepository(db).kasaOzeti(today);
    expect(kasa.kart, 0, reason: 'kart düzeltmesi yalnız kart gözünü sıfırlar');
    expect(kasa.nakit, 3000, reason: 'nakit gözü kart düzeltmesinden etkilenmez');
    expect(kasa.toplam, 3000);
  });

  test('veresiye borç düzeltmesi yalnız bakiyeyi düzeltir, kasaya DOKUNMAZ', () async {
    final custId = await CustomerRepository(db).create(name: 'Borç Düzeltme');
    final ledger = LedgerRepository(db);
    final debitId = await ledger.borcEkle(custId, 10000); // veresiye borç, payment_type YOK
    await ledger.duzeltme(debitId, -10000, customerId: custId);

    final cust = await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle();
    expect(cust.balanceKurus, 0);

    final kasa = await DayEndRepository(db).kasaOzeti(trToday());
    expect(kasa.toplam, 0, reason: 'payment_type\'sız correction kasaya dokunmaz');

    final correction = await (db.select(db.ledgerEntries)..where((t) => t.entryType.equals('correction'))).getSingle();
    expect(correction.paymentType, isNull);
  });

  test('gün sonu: kasa özeti / borç durumu / kupon durumu salt-okuma', () async {
    final orders = OrderRepository(db);

    // Peşin nakit teslimat (kasa) + veresiye teslimat (borç).
    final pesinCust = await CustomerRepository(db).create(name: 'Peşinci');
    final pesinOrder = await orders.create(customerId: pesinCust,
        lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);
    await orders.deliver(pesinOrder, paymentType: 'nakit');

    final borcluCust = await CustomerRepository(db).create(name: 'Borçlu Ali');
    final borcOrder = await orders.create(customerId: borcluCust,
        lines: [LineInput(productName: 'D', unitPriceKurus: 12000, qty: 1)]);
    await orders.deliver(borcOrder, paymentType: 'veresiye');

    // Kupon: 5 al, 1 kullan.
    final kuponCust = await CustomerRepository(db).create(name: 'Kuponcu');
    await CouponRepository(db).kuponSat(customerId: kuponCust, qty: 5, priceKurus: 45000, paymentType: 'kart');
    final kuponOrder = await orders.create(customerId: kuponCust,
        lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);
    await orders.deliver(kuponOrder, paymentType: 'kupon');

    final today = trToday();
    final dayEnd = DayEndRepository(db);

    final kasa = await dayEnd.kasaOzeti(today);
    expect(kasa.nakit, 9000, reason: 'peşin nakit teslimat');
    expect(kasa.kart, 45000, reason: 'kupon paketi kartla peşin alındı');
    expect(kasa.havale, 0);
    expect(kasa.toplam, 54000);

    final borc = await dayEnd.borcDurumu();
    expect(borc.toplamAcikBorc, 12000, reason: 'yalnız veresiye teslimat borç bırakır');
    expect(borc.borclular, hasLength(1));
    expect(borc.borclular.first.name, 'Borçlu Ali');

    final kupon = await dayEnd.kuponDurumu(today);
    expect(kupon.toplamAcikKupon, 4, reason: '5 verildi, 1 kullanıldı');
    expect(kupon.gunlukVerilen, 5);
    expect(kupon.gunlukKullanilan, 1);
    expect(kupon.eksiBakiyeliler, isEmpty);
  });

  test('ledger yazımı atomik: outbox adımı patlarsa ledger + bakiye önbelleği de geri alınır', () async {
    // FAZ 3 writeLedgerEntry TEK yazım değil ÜÇ yazımdır (ledger insert + balance UPDATE + outbox).
    // Çağıranın transaction'ı üçünü sarar; son adım (outbox) patlarsa bakiye önbelleği de dönmelidir
    // — yoksa "yazılmadı ama bakiye değişti" sınıfı sessiz tutarsızlık doğar (korku #2).
    final custId = await CustomerRepository(db).create(name: 'Atomik');
    const dup = 'CAKISAN-LEDGER-EVENT-ID';
    // Baştan bir outbox satırı; aynı client_event_id ile ikinci enqueue unique kısıtını ihlal edecek.
    await db.into(db.outbox).insert(OutboxCompanion.insert(
          clientEventId: dup,
          entityType: 'ledger',
          op: 'entry',
          payload: '{}',
          occurredAt: nowIso(),
          createdAt: nowIso(),
        ));
    final balanceBefore =
        (await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle()).balanceKurus;

    await expectLater(
      db.transaction(() async {
        // writeLedgerEntry: ledger insert + balance recompute + kendi outbox'u (başarılı).
        await writeLedgerEntry(db,
            entryType: 'debit', amountKurus: 5000, customerId: custId, occurredAt: nowIso());
        // Aynı transaction'da ÇAKIŞAN client_event_id ile outbox → patlar, hepsi geri alınır.
        await enqueueOutbox(db,
            entityType: 'ledger', op: 'entry', occurredAt: nowIso(), payload: {'x': 1}, clientEventId: dup);
      }),
      throwsA(anything),
    );

    expect(await db.select(db.ledgerEntries).get(), isEmpty, reason: 'Ledger kaydı kalıcı olmamalı.');
    final balanceAfter =
        (await (db.select(db.customers)..where((t) => t.id.equals(custId))).getSingle()).balanceKurus;
    expect(balanceAfter, balanceBefore, reason: 'Outbox patladığında bakiye önbelleği güncellenmemeli.');
    // Yalnız baştan ekilen dup ledger outbox satırı kalır; writeLedgerEntry'nin kendi outbox'u da
    // geri alındı (müşteri oluşturmanın ayrı outbox satırı bu filtreye girmez).
    final ledgerOutbox = await (db.select(db.outbox)..where((t) => t.entityType.equals('ledger'))).get();
    expect(ledgerOutbox, hasLength(1), reason: 'writeLedgerEntry outbox satırı da geri alınmalı.');
  });

  test('gün sonu kasa gün sınırı: dünkü tahsilat bugünün kasasına girmez', () async {
    final custId = await CustomerRepository(db).create(name: 'Sınır');
    final dunIso = DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String();
    final bugunIso = DateTime.now().toUtc().toIso8601String();

    // Dün nakit tahsilat −3000, bugün nakit tahsilat −5000 (payment negatif → kasaya giren pozitif).
    await writeLedgerEntry(db,
        entryType: 'payment', amountKurus: -3000, paymentType: 'nakit', customerId: custId, occurredAt: dunIso);
    await writeLedgerEntry(db,
        entryType: 'payment', amountKurus: -5000, paymentType: 'nakit', customerId: custId, occurredAt: bugunIso);

    final kasa = await DayEndRepository(db).kasaOzeti(trToday());
    expect(kasa.nakit, 5000, reason: 'Yalnız bugünün tahsilatı bugünün kasasına girer (gün sınırı +03:00).');
    expect(kasa.toplam, 5000);
  });

  test('gün sonu kupon: eksi bakiyeli müşteri kırmızı listede (eksiBakiyeliler) görünür', () async {
    final custId = await CustomerRepository(db).create(name: 'Eksi Kuponlu');
    await CouponRepository(db).kuponSat(customerId: custId, qty: 1, priceKurus: 9000, paymentType: 'nakit');

    final orders = OrderRepository(db);
    for (var i = 0; i < 2; i++) {
      final oid = await orders.create(customerId: custId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);
      await orders.deliver(oid, paymentType: 'kupon'); // 1 hak, 2 kullanım → −1
    }

    final kupon = await DayEndRepository(db).kuponDurumu(trToday());
    expect(kupon.eksiBakiyeliler, hasLength(1), reason: 'Eksi bakiyeli müşteri kırmızı listede olmalı.');
    expect(kupon.eksiBakiyeliler.first.customerId, custId);
    expect(kupon.eksiBakiyeliler.first.balanceQty, -1);
    expect(kupon.toplamAcikKupon, 0, reason: 'Eksi bakiye açık (pozitif) kupon toplamına katılmaz.');
  });
}
