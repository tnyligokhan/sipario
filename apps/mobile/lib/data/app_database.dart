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
    CashHandovers,
    Users,
    TenantSettings,
    ExemptNumbers,
    CallLogs,
    DayClosings,
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
  int get schemaVersion => 10; // v1 Faz0 · v2 Faz2 · v3 Faz3 · v4 Faz4 kurye · v5 Faz5a abonelik · v6 Dilim1 oturum · v7 Dilim4 ekip(users) · v8 tasarım boşluğu · v9 oto-sıralama kotası · v10 kupon kaldırıldı

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v10 — KUPON KALDIRILDI (2026-07-26 tasarım kararı): özellik üründen çıktı, Drift tablo
          // sınıfları silindi. Eski kurulumlardaki tablolar burada düşürülür.
          //
          // NEDEN `if (from < 10)` DEĞİL VE NEDEN AŞAĞIDAKİ KAPIDAN ÖNCE: kendini-onarma kapısı
          // `tenant_settings` varsa "şema güncel" sayıp ERKEN DÖNER. v9 damgalı bir cihazda o tablo
          // ZATEN vardır → kapı v10 adımını da atlardı ve kupon tabloları sonsuza dek kalırdı.
          // v10 bir tablo EKLEMEDİĞİ için kapının işaretini de güncelleyemiyoruz (işaret "en son
          // eklenen tablo" desenidir). Çözüm: düşürmeyi kapıdan ÖNCE ve koşulsuz koşmak — iki ifade
          // de `IF EXISTS`, tekrar koşmak bedelsiz ve hatasızdır.
          await m.database.customStatement('DROP TABLE IF EXISTS coupon_movements');
          await m.database.customStatement('DROP TABLE IF EXISTS coupon_balances');

          // KENDİNİ ONARMA (2026-07-22 SAHA BULGUSU — iki gerçek cihazda yaşandı): Faz 0 ölçüm
          // ekranı sipario.db'yi sqflite `version: 1` ile açınca user_version damgası 1'e
          // eziliyordu; Drift sonraki açılışta migration'ı YENİDEN koşup "duplicate column" ile
          // açılışı sonsuz spinner'a kilitliyordu. Kaynak kaldırıldı (phase0 artık AppDatabase
          // kullanır) ama savunma kalır: şema gerçekte güncelse (SON sürümün işaret tablosu varsa)
          // migration atlanır; Drift kapanışta user_version'ı doğru sürüme yeniden damgalar.
          //
          // DİKKAT: bu işaret HER şema sürümünde EN SON eklenen tabloya güncellenmelidir. v7'de
          // `users`'tı; v8'de `tenant_settings`. Güncellenmezse v7 damgalı bir cihaz "zaten güncel"
          // sanılıp v8 adımı ATLANIR ve eksik tabloyla açılır.
          final latest = await m.database
              .customSelect("SELECT 1 FROM sqlite_master WHERE type='table' AND name='tenant_settings'")
              .get();
          if (latest.isNotEmpty) return;

          if (from < 2) {
            // ADDİTİF migration (architect kabul kriteri): Faz 0 `customers`/`customer_phones`
            // DROP EDİLMEZ — native sözleşme (tablo/kolon adları, phone_last10 indeksi, balance_kurus)
            // ve mevcut veri korunur. Yalnız yeni kolonlar eklenir + yeni tablolar kurulur.
            // Faz 0'ın `customers.address` kolonu orphan kalır (nullable, zararsız; adres artık
            // customer_addresses'e yazılır). NOT NULL `updated_occurred_at` mevcut satırlara eski
            // varsayılanla eklenir → herhangi bir sunucu güncellemesi LWW'de kazanır (doğru davranış).
            for (final table in ['customers', 'customer_phones']) {
              await _addColumnIfMissing(
                m,
                "ALTER TABLE $table ADD COLUMN updated_occurred_at TEXT NOT NULL "
                "DEFAULT '1970-01-01T00:00:00.000Z'");
              await _addColumnIfMissing(m, 'ALTER TABLE $table ADD COLUMN updated_device_id TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE $table ADD COLUMN deleted_at TEXT');
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
            // akışı kolonları eklenir. from<2 yolu ledgerEntries'i zaten v3 şemasıyla oluşturur
            // (yeni kolonlar dahil); bu ALTER'lar yalnız v2→v3 için gerekli, v1→v3'te kolonlar
            // zaten var → koşullu ekle (tekrar eklemede hata olmasın).
            //
            // v3'ün kupon tabloları (coupon_movements/coupon_balances) BURADAN KALDIRILDI: kupon
            // özelliği v10'da üründen çıktı, Drift tablo sınıfları artık yok. Eski kurulumlarda
            // duran tablolar aşağıdaki from<10 bloğunda düşürülür.
            if (from == 2) {
              await _addColumnIfMissing(m, 'ALTER TABLE ledger_entries ADD COLUMN payment_type TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE ledger_entries ADD COLUMN reverses_entry_id TEXT');
            }
          }
          if (from < 4) {
            // FAZ 4 kurye: ADDİTİF (native sözleşme + mevcut veri korunur). orders'a atama, ledger'a
            // nakit atfı kolonu, sync_meta'ya oturum kullanıcısı; yeni cash_handovers tablosu. from<2
            // yolu bu tabloları zaten v4 şemasıyla (yeni kolonlar dahil) oluşturur; ALTER'lar yalnız
            // daha eski bir Drift kurulumunu (v2/v3) yükseltirken gerekli → koşullu ekle.
            if (from >= 2) {
              await _addColumnIfMissing(m, 'ALTER TABLE orders ADD COLUMN assigned_user_id TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE ledger_entries ADD COLUMN collected_by_user_id TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN user_id TEXT');
            }
            await m.createTable(cashHandovers);
          }
          if (from < 5) {
            // FAZ 5a abonelik önbelleği: sync_meta'ya kilit alanları. from<2 yolu sync_meta'yı zaten
            // v5 şemasıyla (bu kolonlar dahil) oluşturur; ALTER yalnız v2/v3/v4 yükseltmesinde gerekli.
            if (from >= 2) {
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN locked_at_iso TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN subscription_status TEXT');
            }
          }
          if (from < 6) {
            // DİLİM 1 oturum: sync_meta'ya login alanları. from<2 yolu tabloyu zaten v6 şemasıyla
            // oluşturur; ALTER yalnız v2..v5 yükseltmesinde gerekli.
            if (from >= 2) {
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN auth_token TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN user_name TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN user_role TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN tenant_name TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN api_base_url TEXT');
            }
          }
          if (from < 7) {
            // DİLİM 4 ekip: yeni `users` aynası (team bloğu önbelleği). ADDİTİF — native sözleşme +
            // mevcut veri korunur. from<2 yolu tabloyu zaten v7 şemasıyla oluşturur.
            await m.createTable(users);
          }
          if (from < 8) {
            // TASARIM BOŞLUĞU (Claude Design handoff v2): işletme profili, muaf numaralar, çağrı
            // günlüğü, gün sonu arşivi + mevcut tablolara yeni alanlar. ADDİTİF — native sözleşme
            // (customers/customer_phones/phone_last10/balance_kurus) DOKUNULMAZ, DROP yok.
            //
            // from<2 yolu bu tabloları zaten v8 şemasıyla oluşturur; ALTER'lar yalnız v2..v7
            // yükseltmesinde gerekli → koşullu ekle (duplicate-column'a toleranslı).
            if (from >= 2) {
              await _addColumnIfMissing(m, 'ALTER TABLE customer_addresses ADD COLUMN region TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE products ADD COLUMN barcode TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE products ADD COLUMN image_url TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE products ADD COLUMN image_local_path TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE orders ADD COLUMN sort_index INTEGER');
              await _addColumnIfMissing(m, 'ALTER TABLE order_lines ADD COLUMN unit TEXT');
              await _addColumnIfMissing(
                  m, 'ALTER TABLE order_lines ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN tenant_code TEXT');
              await _addColumnIfMissing(
                  m, 'ALTER TABLE sync_meta ADD COLUMN route_credits INTEGER NOT NULL DEFAULT 0');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN setup_completed_at TEXT');
              await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN theme_mode TEXT');
            }
            if (from >= 7) {
              // users v7'de oluştu; telefon v8 eklentisi (from<7 yolu tabloyu v8 şemasıyla kurar).
              await _addColumnIfMissing(m, 'ALTER TABLE users ADD COLUMN phone TEXT');
            }
            await m.createTable(tenantSettings);
            await m.createTable(exemptNumbers);
            await m.createTable(callLogs);
            await m.createTable(dayClosings);
            await m.createIndex(idxProductsBarcode);
            await m.createIndex(idxExemptLast10);
            await m.createIndex(idxCallLogsOccurred);
          }
          if (from < 9) {
            // v9: oto-sıralama AYLIK KOTASI. Kalan hak (route_credits) v8'de gelmişti; çekmece
            // kartındaki ilerleme çubuğu kalan/kota oranını istiyor, kota alanı eksikti.
            // Sunucu sahipli, salt-okunur — subscription bloğundan iner.
            await _addColumnIfMissing(m,
                'ALTER TABLE sync_meta ADD COLUMN route_credits_monthly INTEGER NOT NULL DEFAULT 0');
          }
        },
        beforeOpen: (details) async {
          // Senkron durumu tek satırdır (id=1); yoksa oluştur.
          final meta = await (select(syncMeta)..where((t) => t.id.equals(1))).getSingleOrNull();
          if (meta == null) {
            await into(syncMeta).insert(const SyncMetaCompanion(id: Value(1)));
          }
          // TEK SEFERLİK TEMİZLİK (2026-07-22 saha bulgusu): eski Faz 0 ekranı üretim DB'sine
          // outbox'sız SAHTE spike müşterileri yazmıştı (id c1/c2/c3 ve 'c-<zaman>'). Bunlar
          // sunucuya hiç gitmez, listede hayalet olarak durur. Kimlik biçimleri UUIDv7 ile
          // ASLA çakışmaz (uuid 'c-' ile başlayamaz; 'c1' 2 karakterdir) — silmek güvenli.
          await customStatement(
              "DELETE FROM customer_phones WHERE customer_id IN ('c1','c2','c3') OR customer_id LIKE 'c-%'");
          await customStatement(
              "DELETE FROM customers WHERE id IN ('c1','c2','c3') OR id LIKE 'c-%'");
        },
      );

  /// Senkron meta tek satırını döner (garanti var — beforeOpen kurar).
  Future<SyncMetaData> syncState() =>
      (select(syncMeta)..where((t) => t.id.equals(1))).getSingle();

  /// Senkron meta tek satırının AKIŞI. Sunucu sahipli alanlar (abonelik, firma kodu, rota
  /// kontörü) senkron tamamlanınca yazılır — ekran açılışında tek atış okuma YAPMAK YETMEZ,
  /// değer o an henüz gelmemiş olabilir (cihazda yaşandı: "Oto Sırala · 0 hak" yazıyordu,
  /// sunucuda 34 vardı; giriş yanıtı kontörü taşımıyor, ilk senkron taşıyor).
  Stream<SyncMetaData> watchSyncState() =>
      (select(syncMeta)..where((t) => t.id.equals(1))).watchSingle();

  /// ALTER'ı "duplicate column"a TOLERANSLI koşar (savunma derinliği — sürüm damgası harici
  /// bir açıcı tarafından ezilirse migration yeniden koşabilir; var olan kolon hata değildir).
  static Future<void> _addColumnIfMissing(Migrator m, String sql) async {
    try {
      await m.database.customStatement(sql);
    } on Exception catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
  }
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
