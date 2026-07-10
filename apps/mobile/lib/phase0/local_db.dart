import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Faz 0'ın veri tarafı.
///
/// Bu şema, native `CustomerLookup` tarafından salt-okunur açılır. Dosya adı,
/// tablo adları ve `phone_last10` indeksi native tarafla yapılan sözleşmedir;
/// Faz 2'de Drift devraldığında bu sözleşme aynen korunacak.
class LocalDb {
  static const dbName = 'sipario.db';

  /// Türkiye'de aynı numara +905321234567 / 05321234567 / 5321234567 biçimlerinde gelir.
  /// Son 10 hane üçünde de aynıdır ve ülke içinde tekildir — eşleştirme buna dayanır.
  static String last10(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  static Future<Database> open() async {
    final path = p.join(await getDatabasesPath(), dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE customers (
            id            TEXT PRIMARY KEY,
            name          TEXT NOT NULL,
            address       TEXT,
            note          TEXT,
            balance_kurus INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Bir müşterinin birden çok numarası olur (ev, cep). Ayrı tablo — 1NF.
        await db.execute('''
          CREATE TABLE customer_phones (
            id           TEXT PRIMARY KEY,
            customer_id  TEXT NOT NULL REFERENCES customers(id),
            phone_e164   TEXT NOT NULL,
            phone_last10 TEXT NOT NULL,
            label        TEXT,
            is_primary   INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Arayan tanımanın 1 saniyelik bütçesi bu indeksin üzerinde duruyor.
        await db.execute(
          'CREATE INDEX idx_phones_last10 ON customer_phones(phone_last10)',
        );
      },
    );
  }

  /// Spike için gerçekçi bir rehber. Bakiye kuruş cinsinden tam sayıdır —
  /// para hiçbir yerde kayan noktalı sayı olarak tutulmaz.
  static Future<int> seed(Database db) async {
    const rows = <Map<String, Object?>>[
      {
        'id': 'c1',
        'name': 'Ahmet Yılmaz',
        'address': 'Kışla Mah. 45. Sk. No:3 D:7',
        'note': 'Kapıyı çalma, zil bozuk',
        'balance_kurus': 24000,
        'phones': ['+905321112233', '02422223344'],
      },
      {
        'id': 'c2',
        'name': 'Zeynep Kaya',
        'address': 'Meltem Mah. Barınaklar Blv. No:112',
        'note': null,
        'balance_kurus': 0,
        'phones': ['+905445556677'],
      },
      {
        'id': 'c3',
        'name': 'Bahar Market',
        'address': 'Şirinyalı Mah. 1487. Sk. No:2',
        'note': 'Fatura kesilecek',
        'balance_kurus': -15000,
        'phones': ['+905337778899'],
      },
    ];

    final batch = db.batch();
    for (final row in rows) {
      final phones = row['phones']! as List<String>;
      batch.insert(
        'customers',
        {
          'id': row['id'],
          'name': row['name'],
          'address': row['address'],
          'note': row['note'],
          'balance_kurus': row['balance_kurus'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var i = 0; i < phones.length; i++) {
        batch.insert(
          'customer_phones',
          {
            'id': '${row['id']}-p$i',
            'customer_id': row['id'],
            'phone_e164': phones[i],
            'phone_last10': last10(phones[i]),
            'label': i == 0 ? 'cep' : 'ev',
            'is_primary': i == 0 ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM customer_phones'),
    );
    return count ?? 0;
  }

  static Future<List<Map<String, Object?>>> allPhones(Database db) => db.rawQuery('''
        SELECT c.name, p.phone_e164, p.phone_last10
        FROM customer_phones p JOIN customers c ON c.id = p.customer_id
        ORDER BY c.name
      ''');

  /// Saha ölçümü için: test aramasını yapacak telefonu rehbere ekler.
  /// Aynı numara ikinci kez eklenirse eski kayıt güncellenir, çift kart çıkmaz.
  static Future<void> addCustomer(
    Database db, {
    required String name,
    required String phone,
    int balanceKurus = 12500,
  }) async {
    final key = last10(phone);
    final existing = await db.query(
      'customer_phones',
      where: 'phone_last10 = ?',
      whereArgs: [key],
      limit: 1,
    );

    final customerId = existing.isNotEmpty
        ? existing.first['customer_id']! as String
        : 'c-${DateTime.now().microsecondsSinceEpoch}';

    await db.insert(
      'customers',
      {
        'id': customerId,
        'name': name,
        'address': 'Saha testi kaydı',
        'note': null,
        'balance_kurus': balanceKurus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'customer_phones',
      {
        'id': existing.isNotEmpty ? existing.first['id'] : '$customerId-p0',
        'customer_id': customerId,
        'phone_e164': phone,
        'phone_last10': key,
        'label': 'cep',
        'is_primary': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
