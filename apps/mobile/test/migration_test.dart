import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Faz 0 (sqflite v1) → Drift v8 ADDİTİF migration'ı doğrular (architect kabul kriteri):
/// phase0 `customers`/`customer_phones` verisi ve native sözleşmesi KORUNUR, yeni tablolar (Faz 2 +
/// Faz 3 defter + Faz 4 kurye + v8 tasarım boşluğu) oluşur. Drift açılışta şemayı doğrular → hedef
/// şema eksiksiz kurulmuş olmalı.
///
/// Migration ADDİTİF olma kuralının TEK istisnası v10'dur: kupon özelliği üründen çıktı, iki tablosu
/// düşürülür. Para tablolarına dokunulmaz (kırmızı çizgi #2 — defter append-only).
void main() {
  test('v1→v8: phase0 verisi ve native sözleşmesi korunur, Faz 2/3/4 + v8 tabloları açılır', () async {
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

    // FAZ 3 yüzeyi kuruldu: ledger yeni kolonlarıyla yazılabilir. KUPON tabloları TAZE kurulumda
    // HİÇ oluşmaz (v10'da özellik kaldırıldı; eski v3 bloğundaki createTable çağrıları silindi).
    expect(await _tablolar(db), isNot(anyElement(startsWith('coupon_'))));
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

    // v8 TASARIM BOŞLUĞU yüzeyleri kuruldu: yeni tablolar + mevcut tablolara eklenen alanlar.
    expect(await db.select(db.tenantSettings).get(), isEmpty);
    expect(await db.select(db.exemptNumbers).get(), isEmpty);
    expect(await db.select(db.callLogs).get(), isEmpty);
    expect(await db.select(db.dayClosings).get(), isEmpty);

    await db.into(db.products).insert(ProductsCompanion.insert(
        id: 'pr1', name: 'Damacana', unitPriceKurus: 4500,
        barcode: const Value('8690521000117'), updatedOccurredAt: '2026-07-25T00:00:00.000Z'));
    expect((await (db.select(db.products)..where((t) => t.id.equals('pr1'))).getSingle()).barcode,
        '8690521000117');

    await db.into(db.customerAddresses).insert(CustomerAddressesCompanion.insert(
        id: 'a1', customerId: '0190f0f0-0000-7000-8000-000000000001', addressText: 'Yeni Adres',
        region: const Value('Kepez'), updatedOccurredAt: '2026-07-25T00:00:00.000Z'));
    expect((await (db.select(db.customerAddresses)..where((t) => t.id.equals('a1'))).getSingle()).region,
        'Kepez');

    await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
        id: 'ol1', orderId: 'o1', productName: 'Merdiven çıkışı', unitPriceKurus: 2000,
        unit: const Value('adet'), isCustom: const Value(true), qty: 1, lineTotalKurus: 2000));
    expect((await (db.select(db.orderLines)..where((t) => t.id.equals('ol1'))).getSingle()).isCustom,
        isTrue);
  });

  test(
      'v7→v8: SAHADAKİ cihazın yükseltme adımı — veri korunur, tasarım boşluğu tabloları ve '
      'ALTER kolonları eklenir (v1→v8 yolu bu dalı HİÇ koşmaz: orada tablolar createTable ile '
      'doğrudan v8 şemasında kurulur, ALTER\'lar `from >= 2` / `from >= 7` koşullarıyla atlanır)',
      () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_v7v8_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel şemayla kur, GERÇEK veri yaz (yükseltmenin korumak zorunda olduğu şey budur).
    final v8 = AppDatabase(NativeDatabase(file));
    await v8.into(v8.customers).insert(CustomersCompanion.insert(
        id: 'v7-c1', name: 'Saha Müşterisi', balanceKurus: const Value(31500),
        updatedOccurredAt: '2026-07-24T00:00:00.000Z'));
    await v8.into(v8.customerPhones).insert(CustomerPhonesCompanion.insert(
        id: 'v7-p1', customerId: 'v7-c1', phoneE164: '+905324152290', phoneLast10: '5324152290',
        updatedOccurredAt: '2026-07-24T00:00:00.000Z'));
    await v8.into(v8.customerAddresses).insert(CustomerAddressesCompanion.insert(
        id: 'v7-a1', customerId: 'v7-c1', addressText: 'Kışla Mah. No:7',
        isPrimary: const Value(true), updatedOccurredAt: '2026-07-24T00:00:00.000Z'));
    await v8.into(v8.products).insert(ProductsCompanion.insert(
        id: 'v7-pr1', name: '19L Damacana', unitPriceKurus: 4500,
        updatedOccurredAt: '2026-07-24T00:00:00.000Z'));
    await v8.into(v8.orders).insert(OrdersCompanion.insert(
        id: 'v7-o1', occurredAt: '2026-07-24T00:00:00.000Z'));
    await v8.into(v8.orderLines).insert(OrderLinesCompanion.insert(
        id: 'v7-ol1', orderId: 'v7-o1', productName: '19L Damacana',
        unitPriceKurus: 4500, qty: 2, lineTotalKurus: 9000));
    await v8.into(v8.users).insert(UsersCompanion.insert(
        id: 'v7-u1', name: 'Mehmet Kurye', role: 'kurye', status: 'active'));
    await v8.close();

    // 2) Dosyayı v7'ye GERİ SAR: v8'de eklenen tablolar/indeksler/kolonlar kaldırılır, damga 7 olur.
    //    (Gerçek bir v7 cihazının diskteki hâli budur; veri satırları YERİNDE kalır.)
    final raw = sqlite3.open(file.path);
    for (final ix in ['idx_products_barcode', 'idx_exempt_last10', 'idx_call_logs_occurred']) {
      raw.execute('DROP INDEX IF EXISTS $ix');
    }
    for (final t in ['tenant_settings', 'exempt_numbers', 'call_logs', 'day_closings']) {
      raw.execute('DROP TABLE IF EXISTS $t');
    }
    const v8Kolonlari = {
      'customer_addresses': ['region'],
      'products': ['barcode', 'image_url', 'image_local_path'],
      'orders': ['sort_index'],
      'order_lines': ['unit', 'is_custom'],
      'sync_meta': ['tenant_code', 'route_credits', 'setup_completed_at', 'theme_mode'],
      'users': ['phone'],
    };
    v8Kolonlari.forEach((tablo, kolonlar) {
      for (final k in kolonlar) {
        raw.execute('ALTER TABLE $tablo DROP COLUMN $k');
      }
    });
    raw.execute('PRAGMA user_version = 7');
    raw.close();

    // 3) Yeniden aç → onUpgrade(from: 7, to: 8). Kendini-onarma işareti `tenant_settings`e bakar;
    //    v7 cihazda o tablo YOK, dolayısıyla adım ATLANMAMALI (işaret v7'deki `users` olarak
    //    kalsaydı burası sessizce atlanır ve cihaz eksik tabloyla açılırdı — bu test o regresyonu tutar).
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    // Mevcut veri KORUNDU (native sözleşme dahil).
    final cust = await (db.select(db.customers)..where((t) => t.id.equals('v7-c1'))).getSingle();
    expect(cust.name, 'Saha Müşterisi');
    expect(cust.balanceKurus, 31500);
    expect(
        (await (db.select(db.customerPhones)..where((t) => t.id.equals('v7-p1'))).getSingle())
            .phoneLast10,
        '5324152290');
    expect((await (db.select(db.orderLines)..where((t) => t.id.equals('v7-ol1'))).getSingle())
        .lineTotalKurus, 9000);

    // Yeni tablolar kuruldu.
    expect(await db.select(db.tenantSettings).get(), isEmpty);
    expect(await db.select(db.exemptNumbers).get(), isEmpty);
    expect(await db.select(db.callLogs).get(), isEmpty);
    expect(await db.select(db.dayClosings).get(), isEmpty);

    // ALTER ile eklenen kolonlar MEVCUT satırlarda okunabilir/yazılabilir.
    expect((await (db.select(db.orderLines)..where((t) => t.id.equals('v7-ol1'))).getSingle())
        .isCustom, isFalse, reason: 'NOT NULL DEFAULT 0 eski satıra uygulanmalı');
    await (db.update(db.products)..where((t) => t.id.equals('v7-pr1')))
        .write(const ProductsCompanion(barcode: Value('8690521000117')));
    expect((await (db.select(db.products)..where((t) => t.id.equals('v7-pr1'))).getSingle()).barcode,
        '8690521000117');
    await (db.update(db.customerAddresses)..where((t) => t.id.equals('v7-a1')))
        .write(const CustomerAddressesCompanion(region: Value('Muratpaşa')));
    expect(
        (await (db.select(db.customerAddresses)..where((t) => t.id.equals('v7-a1'))).getSingle())
            .region,
        'Muratpaşa');
    await (db.update(db.orders)..where((t) => t.id.equals('v7-o1')))
        .write(const OrdersCompanion(sortIndex: Value(2)));
    expect((await (db.select(db.orders)..where((t) => t.id.equals('v7-o1'))).getSingle()).sortIndex, 2);

    // v7'de var olan `users` tablosuna v8'in `phone` kolonu eklendi (from >= 7 dalı) ve satır durdu.
    final kurye = await (db.select(db.users)..where((t) => t.id.equals('v7-u1'))).getSingle();
    expect(kurye.name, 'Mehmet Kurye');
    // `isNull` matcher'ı drift'in aynı adlı ifadesiyle çakışır (courier_test dersi) — düz null.
    expect(kurye.phone, null);
    await (db.update(db.users)..where((t) => t.id.equals('v7-u1')))
        .write(const UsersCompanion(phone: Value('+905331234567')));
    expect((await (db.select(db.users)..where((t) => t.id.equals('v7-u1'))).getSingle()).phone,
        '+905331234567');

    // sync_meta tek satırı korundu ve v8 alanları varsayılanlarıyla geldi.
    final meta = await db.syncState();
    expect(meta.id, 1);
    expect(meta.routeCredits, 0);
    expect(meta.tenantCode, null);
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

  test(
      'v9→v10 KUPON KALDIRMA: sahadaki cihazın kupon tabloları düşürülür, defter/müşteri verisi '
      'AYNEN durur. Düşürme kendini-onarma kapısından ÖNCE koşar — kapı `tenant_settings` varsa '
      'erken döner ve v9 damgalı bir cihazda o tablo ZATEN vardır (koşul içine alınsaydı adım '
      'sessizce atlanır, tablolar sonsuza dek kalırdı).', () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_v9v10_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel şemayla kur + korunması gereken PARA verisini yaz.
    final v10 = AppDatabase(NativeDatabase(file));
    await v10.into(v10.customers).insert(CustomersCompanion.insert(
        id: 'v9-c1', name: 'Kupon Müşterisi', balanceKurus: const Value(18000),
        updatedOccurredAt: '2026-07-26T00:00:00.000Z'));
    await v10.into(v10.ledgerEntries).insert(LedgerEntriesCompanion.insert(
          id: 'v9-l1', customerId: const Value('v9-c1'), entryType: 'debit', amountKurus: 18000,
          occurredAt: '2026-07-26T00:00:00.000Z', clientEventId: 'v9-ce1',
        ));
    await v10.close();

    // 2) Dosyayı v9'a GERİ SAR: kupon tablolarını (v3 şemalarıyla) yeniden kur, damgayı 9 yap.
    //    Gerçek bir v9 cihazının diskteki hâli budur — içinde kupon hareketi de durur.
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE coupon_movements (
        id TEXT NOT NULL PRIMARY KEY, customer_id TEXT NOT NULL, product_id TEXT,
        movement_type TEXT NOT NULL, qty_delta INTEGER NOT NULL, related_order_id TEXT,
        note TEXT, reverses_movement_id TEXT, occurred_at TEXT NOT NULL, device_id TEXT,
        client_event_id TEXT NOT NULL UNIQUE
      )''');
    raw.execute('CREATE INDEX idx_coupon_moves_customer ON coupon_movements(customer_id)');
    raw.execute('''
      CREATE TABLE coupon_balances (
        customer_id TEXT NOT NULL, product_id TEXT NOT NULL DEFAULT '',
        balance_qty INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (customer_id, product_id)
      )''');
    raw.execute(
      "INSERT INTO coupon_movements (id,customer_id,movement_type,qty_delta,occurred_at,client_event_id) "
      "VALUES ('v9-k1','v9-c1','grant',10,'2026-07-26T00:00:00.000Z','v9-kce1')",
    );
    raw.execute("INSERT INTO coupon_balances (customer_id,product_id,balance_qty) VALUES ('v9-c1','',10)");
    raw.execute('PRAGMA user_version = 9');
    raw.close();

    // 3) Yeniden aç → onUpgrade(from: 9, to: 10).
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    // Kupon tabloları (ve indeksleri onlarla birlikte) GİTTİ.
    final tablolar = await _tablolar(db);
    expect(tablolar, isNot(contains('coupon_movements')));
    expect(tablolar, isNot(contains('coupon_balances')));

    // PARA verisi AYNEN durur — kırmızı çizgi #2: defter satırı silinmez, bakiye ezilmez.
    final cust = await (db.select(db.customers)..where((t) => t.id.equals('v9-c1'))).getSingle();
    expect(cust.balanceKurus, 18000);
    final entry = await (db.select(db.ledgerEntries)..where((t) => t.id.equals('v9-l1'))).getSingle();
    expect(entry.amountKurus, 18000);
  });

  test(
      'v10→v11 SIRA KODLARI: sahadaki cihaza müşteri/sipariş kodu ve kod tercihi kolonları '
      'eklenir, veri AYNEN durur. Adım kendini-onarma kapısından ÖNCE koşar — kapı '
      '`tenant_settings` varsa erken döner ve v10 damgalı bir cihazda o tablo ZATEN vardır '
      '(koşul içine alınsaydı kolonlar sonsuza dek eksik kalır, senkronla gelen kod yazılacak '
      'yer bulamazdı).', () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_v10v11_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel şemayla kur + korunması gereken veriyi yaz.
    final v11 = AppDatabase(NativeDatabase(file));
    await v11.into(v11.customers).insert(CustomersCompanion.insert(
        id: 'v10-c1', name: 'Kodsuz Müşteri', balanceKurus: const Value(7500),
        updatedOccurredAt: '2026-07-29T00:00:00.000Z'));
    await v11.into(v11.orders).insert(OrdersCompanion.insert(
        id: 'v10-o1', customerId: const Value('v10-c1'),
        totalKurus: const Value(4500), occurredAt: '2026-07-29T00:00:00.000Z'));
    await v11.close();

    // 2) Dosyayı v10'a GERİ SAR: üç kolonu düşür, damgayı 10 yap. Gerçek bir v10 cihazının
    //    diskteki hâli budur.
    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE customers DROP COLUMN code');
    raw.execute('ALTER TABLE orders DROP COLUMN code');
    raw.execute('ALTER TABLE tenant_settings DROP COLUMN order_code_display');
    raw.execute('PRAGMA user_version = 10');
    raw.close();

    // 3) Yeniden aç → onUpgrade(from: 10, to: 11).
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    // Kolonlar geri geldi ve YAZILABİLİR (senkron kodu buraya yazacak).
    await (db.update(db.customers)..where((t) => t.id.equals('v10-c1')))
        .write(const CustomersCompanion(code: Value(102)));
    await (db.update(db.orders)..where((t) => t.id.equals('v10-o1')))
        .write(const OrdersCompanion(code: Value(248)));

    final cust = await (db.select(db.customers)..where((t) => t.id.equals('v10-c1'))).getSingle();
    expect(cust.code, 102);
    expect(cust.balanceKurus, 7500, reason: 'para verisi ezilmedi');
    final order = await (db.select(db.orders)..where((t) => t.id.equals('v10-o1'))).getSingle();
    expect(order.code, 248);
    expect(order.totalKurus, 4500);

    // Ayar kolonu VARSAYILANLA gelir: NOT NULL bir kolonu değersiz eklemek eski satırları
    // okunamaz yapardı.
    await db.into(db.tenantSettings).insertOnConflictUpdate(
        const TenantSettingsCompanion(id: Value(1), businessName: Value('Öz Pınar')));
    final ayar = await (db.select(db.tenantSettings)..where((t) => t.id.equals(1))).getSingle();
    expect(ayar.orderCodeDisplay, 'musteri');
  });
}

/// Dosyadaki gerçek tablo adları (sqlite_master). Kupon tablolarının YOKLUĞUNU kanıtlamak için
/// Drift getter'ı kullanılamaz — sınıflar silindi, `db.couponMovements` artık derlenmez.
Future<List<String>> _tablolar(AppDatabase db) async {
  final rows = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
  return rows.map((r) => r.read<String>('name')).toList();
}
