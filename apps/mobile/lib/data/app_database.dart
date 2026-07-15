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
    CouponMovements,
    CouponBalances,
    CashHandovers,
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
  int get schemaVersion => 4; // v1 = Faz 0 spike, v2 = Faz 2 çekirdek, v3 = Faz 3 defter, v4 = Faz 4 kurye

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
          if (from < 3) {
            // FAZ 3 defter: ADDİTİF (native sözleşme + mevcut veri korunur). ledger_entries'e para
            // akışı kolonları eklenir, kupon tabloları kurulur. from<2 yolu ledgerEntries'i zaten
            // v3 şemasıyla oluşturur (yeni kolonlar dahil); bu ALTER'lar yalnız v2→v3 için gerekli,
            // v1→v3'te kolonlar zaten var → koşullu ekle (tekrar eklemede hata olmasın).
            if (from == 2) {
              await m.database.customStatement('ALTER TABLE ledger_entries ADD COLUMN payment_type TEXT');
              await m.database.customStatement('ALTER TABLE ledger_entries ADD COLUMN reverses_entry_id TEXT');
            }
            await m.createTable(couponMovements);
            await m.createTable(couponBalances);
          }
          if (from < 4) {
            // FAZ 4 kurye: ADDİTİF (native sözleşme + mevcut veri korunur). orders'a atama, ledger'a
            // nakit atfı kolonu, sync_meta'ya oturum kullanıcısı; yeni cash_handovers tablosu. from<2
            // yolu bu tabloları zaten v4 şemasıyla (yeni kolonlar dahil) oluşturur; ALTER'lar yalnız
            // daha eski bir Drift kurulumunu (v2/v3) yükseltirken gerekli → koşullu ekle.
            if (from >= 2) {
              await m.database.customStatement('ALTER TABLE orders ADD COLUMN assigned_user_id TEXT');
              await m.database.customStatement('ALTER TABLE ledger_entries ADD COLUMN collected_by_user_id TEXT');
              await m.database.customStatement('ALTER TABLE sync_meta ADD COLUMN user_id TEXT');
            }
            await m.createTable(cashHandovers);
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
