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
    raw.execute(
      "INSERT INTO customers (id,name,address,note,balance_kurus) "
      "VALUES ('c1','Faz0 Müşteri','Eski Adres',null,24000)",
    );
    raw.execute(
      "INSERT INTO customer_phones (id,customer_id,phone_e164,phone_last10,label,is_primary) "
      "VALUES ('p1','c1','+905321112233','5321112233','cep',1)",
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
    final cust = await (db.select(db.customers)..where((t) => t.id.equals('c1'))).getSingle();
    expect(cust.name, 'Faz0 Müşteri');
    expect(cust.balanceKurus, 24000);
    final phone = await (db.select(db.customerPhones)..where((t) => t.id.equals('p1'))).getSingle();
    expect(phone.phoneLast10, '5321112233'); // native eşleşme anahtarı korundu

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
}
