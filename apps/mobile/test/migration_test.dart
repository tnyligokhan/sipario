import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Faz 0 (sqflite v1) → Drift v2 ADDİTİF migration'ı doğrular (architect kabul kriteri):
/// phase0 `customers`/`customer_phones` verisi ve native sözleşmesi KORUNUR, yeni tablolar oluşur.
void main() {
  test('v1→v2: phase0 verisi ve native sözleşmesi korunur, yeni tablolar açılır', () async {
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
  });
}
