import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'tables.dart';

part 'app_database.g.dart';

/// Ürünün yerel veritabanı (Drift). Faz 0 sqflite spike'ının yerini alır; sipario.db dosya adı ve
/// customers/customer_phones/phone_last10 sözleşmesi native arayan-tanıma için KORUNUR.
@DriftDatabase(
  tables: [
    Customers,
    CustomerPhones,
    CustomerAddresses,
    Products,
    Orders,
    OrderLines,
    OrderEvents,
    LedgerEntries,
    Outbox,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Test/enjeksiyon için: verilen executor (ör. NativeDatabase.memory()).
  AppDatabase(super.e);

  /// Cihazda: sipario.db'yi Faz 0 ile AYNI dizinde açar (native aynı dosyayı okur).
  AppDatabase.file() : super(_openOnDevice());

  @override
  int get schemaVersion => 2; // v1 = Faz 0 sqflite spike şeması

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // ADDİTİF migration (architect kabul kriteri): Faz 0 `customers`/`customer_phones`
            // DROP EDİLMEZ — native sözleşme (tablo/kolon adları, phone_last10 indeksi, balance_kurus)
            // ve mevcut veri korunur. Yalnız yeni kolonlar eklenir + yeni tablolar kurulur.
            // Faz 0'ın `customers.address` kolonu orphan kalır (nullable, zararsız; adres artık
            // customer_addresses'e yazılır). NOT NULL `updated_occurred_at` mevcut satırlara eski
            // varsayılanla eklenir → herhangi bir sunucu güncellemesi LWW'de kazanır (doğru davranış).
            for (final table in ['customers', 'customer_phones']) {
              await m.database.customStatement(
                "ALTER TABLE $table ADD COLUMN updated_occurred_at TEXT NOT NULL "
                "DEFAULT '1970-01-01T00:00:00.000Z'");
              await m.database.customStatement('ALTER TABLE $table ADD COLUMN updated_device_id TEXT');
              await m.database.customStatement('ALTER TABLE $table ADD COLUMN deleted_at TEXT');
            }
            await m.createTable(customerAddresses);
            await m.createTable(products);
            await m.createTable(orders);
            await m.createTable(orderLines);
            await m.createTable(orderEvents);
            await m.createTable(ledgerEntries);
            await m.createTable(outbox);
            await m.createTable(syncMeta);
          }
        },
        beforeOpen: (details) async {
          // Senkron durumu tek satırdır (id=1); yoksa oluştur.
          final meta = await (select(syncMeta)..where((t) => t.id.equals(1))).getSingleOrNull();
          if (meta == null) {
            await into(syncMeta).insert(const SyncMetaCompanion(id: Value(1)));
          }
        },
      );

  /// Senkron meta tek satırını döner (garanti var — beforeOpen kurar).
  Future<SyncMetaData> syncState() =>
      (select(syncMeta)..where((t) => t.id.equals(1))).getSingle();
}

/// Native taraf sipario.db'yi salt-okunur açtığından WAL yerine rollback-journal kullanılır
/// (WAL'de -wal/-shm dosyaları salt-okunur açıcıyı bozabilir — DECISIONS Faz 2 riski, gerçek
/// cihazda doğrulanacak). Dosya Faz 0 ile AYNI dizinde (sqflite getDatabasesPath).
LazyDatabase _openOnDevice() {
  return LazyDatabase(() async {
    final dir = await getDatabasesPath();
    final file = File(p.join(dir, 'sipario.db'));

    return NativeDatabase.createInBackground(
      file,
      setup: (raw) => raw.execute('PRAGMA journal_mode = TRUNCATE'),
    );
  });
}
