import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Faz 0 (sqflite v1) → Drift v4 ADDİTİF migration'ı doğrular (architect kabul kriteri):
/// phase0 `customers`/`customer_phones` verisi ve native sözleşmesi KORUNUR, yeni tablolar (Faz 2 +
/// Faz 3 kupon + Faz 4 kurye) oluşur. Drift açılışta şemayı doğrular → v4 hedef şeması eksiksiz kurulmuş olmalı.
void main() {
  test('v1→v4: phase0 verisi ve native sözleşmesi korunur, Faz 2/3/4 tabloları açılır', () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_mig_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // Faz 0 sqflite şemasını (v1) birebir kur + veri ekle + user_version=1.
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, address TEXT, note TEXT,
        balance_kurus INTEGER NOT NULL DEFAULT 0
      )''');
    raw.execute('''
      CREATE TABLE customer_phones (
        id TEXT PRIMARY KEY, customer_id TEXT NOT NULL REFERENCES customers(id),
        phone_e164 TEXT NOT NULL, phone_last10 TEXT NOT NULL, label TEXT,
        is_primary INTEGER NOT NULL DEFAULT 0
      )''');
    raw.execute('CREATE INDEX idx_phones_last10 ON customer_phones(phone_last10)');
    // Gerçek kayıt UUID benzeri kimlikle (spike-temizliği c1/c2/c3 ve 'c-%' kimliklerini siler —
    // aşağıda ayrıca kanıtlanır; korunma kanıtı temizlik kapsamı DIŞI kimlikle yapılmalı).
    raw.execute(
      "INSERT INTO customers (id,name,address,note,balance_kurus) "
      "VALUES ('0190f0f0-0000-7000-8000-000000000001','Faz0 Müşteri','Eski Adres',null,24000)",
    );
    raw.execute(
      "INSERT INTO customer_phones (id,customer_id,phone_e164,phone_last10,label,is_primary) "
      "VALUES ('p1','0190f0f0-0000-7000-8000-000000000001','+905321112233','5321112233','cep',1)",
    );
    // Eski Faz 0 ekranının bıraktığı SPIKE çöpleri (temizlik bunları SİLMELİ — 2026-07-22 bulgusu).
    raw.execute(
      "INSERT INTO customers (id,name,address,note,balance_kurus) VALUES ('c1','Spike Ahmet',null,null,0)",
    );
    raw.execute(
      "INSERT INTO customers (id,name,address,note,balance_kurus) VALUES ('c-1700000000','Saha Testi',null,null,0)",
    );
    raw.execute(
      "INSERT INTO customer_phones (id,customer_id,phone_e164,phone_last10,label,is_primary) "
      "VALUES ('c1-p0','c1','+905000000001','5000000001',null,0)",
    );
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    // Drift v2 ile aç → onUpgrade (additif) tetiklenir.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    // Phase0 verisi korundu (DROP edilmedi).
    final cust = await (db.select(db.customers)
          ..where((t) => t.id.equals('0190f0f0-0000-7000-8000-000000000001')))
        .getSingle();
    expect(cust.name, 'Faz0 Müşteri');
    expect(cust.balanceKurus, 24000);
    final phone = await (db.select(db.customerPhones)..where((t) => t.id.equals('p1'))).getSingle();
    expect(phone.phoneLast10, '5321112233'); // native eşleşme anahtarı korundu

    // SPIKE ÇÖPÜ TEMİZLENDİ (beforeOpen): c1/c-<zaman> müşterileri ve telefonları silindi;
    // gerçek kayıt (uuid biçimli) DURUYOR.
    expect(await (db.select(db.customers)..where((t) => t.id.isIn(['c1', 'c-1700000000']))).get(),
        isEmpty);
    expect(
        await (db.select(db.customerPhones)..where((t) => t.customerId.equals('c1'))).get(), isEmpty);

    // Eski satıra eklenen NOT NULL LWW kolonu eski varsayılan aldı (sunucu güncellemesi kazanır).
    expect(cust.updatedOccurredAt, '1970-01-01T00:00:00.000Z');

    // Yeni tablolar erişilebilir + sync_meta singleton kuruldu.
    expect(await db.select(db.products).get(), isEmpty);
    expect(await db.select(db.orders).get(), isEmpty);
    expect(await db.select(db.customerAddresses).get(), isEmpty);
    final meta = await db.syncState();
    expect(meta.id, 1);
    expect(meta.snapshotDone, isFalse);

    // FAZ 3 yüzeyleri kuruldu: kupon tabloları erişilebilir, ledger yeni kolonlarıyla yazılabilir.
    expect(await db.select(db.couponMovements).get(), isEmpty);
    expect(await db.select(db.couponBalances).get(), isEmpty);
    await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
          id: 'l1', entryType: 'payment', amountKurus: -5000,
          paymentType: const Value('nakit'), occurredAt: '2026-07-14T00:00:00.000Z', clientEventId: 'ce1',
        ));
    final entry = await (db.select(db.ledgerEntries)..where((t) => t.id.equals('l1'))).getSingle();
    expect(entry.paymentType, 'nakit');

    // FAZ 4 yüzeyleri kuruldu: cash_handovers tablosu + orders.assigned_user_id + ledger.collected_by
    // + sync_meta.user_id kolonları (ADDİTİF; native sözleşme ve mevcut veri korunur).
    expect(await db.select(db.cashHandovers).get(), isEmpty);
    await db.into(db.cashHandovers).insert(CashHandoversCompanion.insert(
          id: 'h1', fromUserId: 'u1', countedCashKurus: 5000, expectedCashKurus: 5000, diffKurus: 0,
          occurredAt: '2026-07-15T00:00:00.000Z',
        ));
    final handover = await (db.select(db.cashHandovers)..where((t) => t.id.equals('h1'))).getSingle();
    expect(handover.diffKurus, 0);
    // Yeni kolonlar yazılabilir (v3→v4 ALTER doğrulaması).
    await db.into(db.orders).insert(OrdersCompanion.insert(
          id: 'o1', assignedUserId: const Value('u1'), occurredAt: '2026-07-15T00:00:00.000Z'));
    final order = await (db.select(db.orders)..where((t) => t.id.equals('o1'))).getSingle();
    expect(order.assignedUserId, 'u1');
  });

  test(
      'SÜRÜM DAMGASI EZİLMESİ: v7 dosya user_version=1 damgalansa bile açılış KİLİTLENMEZ, '
      'veri korunur, sürüm onarılır (2026-07-22 saha bulgusu — iki cihaz sonsuz loading)', () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_stamp_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel v7 şemasıyla dosya-DB kur + gerçek veri yaz.
    final db1 = AppDatabase(NativeDatabase(file));
    await db1.into(db1.customers).insert(CustomersCompanion.insert(
        id: '0190aaaa-0000-7000-8000-000000000001',
        name: 'Gerçek Müşteri',
        updatedOccurredAt: '2026-07-22T00:00:00.000Z'));
    await db1.close();

    // 2) Harici açıcının yaptığı sabotajı taklit et: user_version'ı 1'e ez (eski phase0 sqflite
    //    version:1 davranışı — kaynak kaldırıldı ama savunma sonsuza dek kalmalı).
    final raw = sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    // 3) Yeniden aç: migration marker'ı görüp ATLAMALI; açılış tamamlanmalı; veri durmalı.
    final db2 = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db2.close();
      if (file.existsSync()) file.deleteSync();
    });
    final cust = await (db2.select(db2.customers)
          ..where((t) => t.id.equals('0190aaaa-0000-7000-8000-000000000001')))
        .getSingle();
    expect(cust.name, 'Gerçek Müşteri', reason: 'veri kaybı olmadan kendini onarmalı');
    expect(await db2.syncState().then((m) => m.id), 1, reason: 'açılış tamamlandı (spinner kilidi yok)');
  });

  test(
      'NATIVE SÖZLEŞME: CustomerLookup.kt sorgusu taze v7 şemasında çalışır; adres '
      'customer_addresses birincilinden gelir (2026-07-22: eski c.address sorgusu taze kurulumda '
      'patlıyordu — arkadaş cihazında her arama "kayıtsız" çıktı)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.customers).insert(CustomersCompanion.insert(
        id: 'm1', name: 'Ayşe Yılmaz', updatedOccurredAt: '2026-07-22T00:00:00.000Z'));
    await db.into(db.customerPhones).insert(CustomerPhonesCompanion.insert(
        id: 'm1p', customerId: 'm1', phoneE164: '+905442014305', phoneLast10: '5442014305',
        updatedOccurredAt: '2026-07-22T00:00:00.000Z'));
    await db.into(db.customerAddresses).insert(CustomerAddressesCompanion.insert(
        id: 'm1a', customerId: 'm1', addressText: 'Kışla Mah. No:3',
        isPrimary: const Value(true), updatedOccurredAt: '2026-07-22T00:00:00.000Z'));

    // CustomerLookup.kt'deki SQL'in BİREBİR kopyası — Kotlin tarafı değişirse burası da değişmeli.
    final rows = await db.customSelect(
      '''
      SELECT c.name,
             (SELECT a.address_text FROM customer_addresses a
               WHERE a.customer_id = c.id AND a.deleted_at IS NULL
               ORDER BY a.is_primary DESC LIMIT 1) AS address,
             c.balance_kurus, c.note
      FROM customer_phones p
      JOIN customers c ON c.id = p.customer_id
      WHERE p.phone_last10 = ? AND p.deleted_at IS NULL AND c.deleted_at IS NULL
      LIMIT 1
      ''',
      variables: [Variable.withString('5442014305')],
    ).get();

    expect(rows, hasLength(1));
    expect(rows.single.read<String>('name'), 'Ayşe Yılmaz');
    expect(rows.single.read<String?>('address'), 'Kışla Mah. No:3');
    expect(rows.single.read<int>('balance_kurus'), 0);
  });
}
