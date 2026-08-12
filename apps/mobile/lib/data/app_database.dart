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

  /// ⚠️ KOLON EKLEYEN HERKES BU SAYIYI ARTIRMAK ZORUNDA — 2026-08-09'da sahada ödendi.
  ///
  /// Yetki Matrisi (2026-08-08) `tenant_settings`e 13 kolon ekledi, aşağıdaki `onUpgrade`
  /// içine ALTER TABLE'larını da yazdı, **ama bu sayı 14'te bırakıldı.** Drift `onUpgrade`'i
  /// YALNIZ sürüm değiştiğinde çağırır; sahadaki cihazlar zaten v14 damgalı olduğu için o
  /// ALTER TABLE'lar HİÇ KOŞMADI. Sonuç: `no such column: tenant_settings.courier_can_see_all_orders`
  /// ve `tenant_settings`e dokunan her sorgunun patlaması (harita ekranı bu yüzden açılmıyordu).
  ///
  /// **Testler bunu göremez** — her test `NativeDatabase.memory()` ile TAZE veritabanı kurar,
  /// yani `onCreate` yolundan geçer ve şema her zaman tamdır. 1109 yeşil testin hiçbiri
  /// YÜKSELTME yolundan geçmiyordu. Kusur yalnız "önceki sürümü kurulu olan cihazda" görünür.
  @override
  int get schemaVersion => 20; // v1 Faz0 · v2 Faz2 · v3 Faz3 · v4 Faz4 kurye · v5 Faz5a abonelik · v6 Dilim1 oturum · v7 Dilim4 ekip(users) · v8 tasarım boşluğu · v9 oto-sıralama kotası · v10 kupon kaldırıldı · v11 sıra kodları (müşteri/sipariş) · v12 müşteri kara listesi · v13 IBAN · v14 IBAN alıcı adı + hatırlatma şablonu · v15 kurye yetki matrisi 13 kolonu (SÜRÜM ARTIŞI UNUTULMUŞTU) · v16 sync_meta.api_version (sunucu sözleşme sürümü önbelleği) · v17 users'a kişiye özel kurye yetkileri (13 NULLABLE kolon — null = bayi varsayılanını devral) · v18 order_lines.note (satır notu) + customers.favorite_product_ids (JSON dizi) · v19 sync_meta "beni hatırla" (saved_tenant_code + saved_username) · v20 cash_handovers.reverses_handover_id (ara tahsilat iptal kaydı)

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

          // v11 — SIRA KODLARI (müşteri 102 · sipariş #248, 2026-07-29).
          //
          // KAPIDAN ÖNCE ve KOŞULSUZ, tam olarak v10'un gerekçesiyle: aşağıdaki kendini-onarma
          // kapısı `tenant_settings` tablosunu görünce "şema güncel" sayıp ERKEN DÖNER. Sahadaki
          // her cihazda o tablo zaten var (v8'den beri), yani `if (from < 11)` yazsaydık adım
          // HİÇ koşmazdı ve kolonlar sonsuza dek eksik kalırdı — üstelik hata vermeden: senkron
          // gelen `code` alanını yazacak kolonu bulamaz, kod hiç görünmezdi.
          // Üçü de `_addColumnIfMissing`: tekrar koşmak bedelsiz.
          //
          // TABLO VARLIĞI ÖNCE SORULUR: bu adım koşulsuz olduğu için ÇOK ESKİ yollarda da
          // koşar — v1 damgalı bir cihazda `orders`, v7'de `tenant_settings` HENÜZ YOKTUR
          // (aşağıdaki `from < N` dallarında kurulurlar). O tablolar zaten GÜNCEL şemadan
          // (`createTable`) doğacağı için kolon onlarda hazır gelir; burada atlamak doğru
          // davranıştır. Hatayı yutmak yerine SORMAK: "no such table"ı da yutan bir yardımcı,
          // adı yanlış yazılmış bir tabloyu sessizce görmezden gelirdi.
          for (final (tablo, sql) in [
            ('customers', 'ALTER TABLE customers ADD COLUMN code INTEGER'),
            ('orders', 'ALTER TABLE orders ADD COLUMN code INTEGER'),
            (
              'tenant_settings',
              "ALTER TABLE tenant_settings ADD COLUMN order_code_display TEXT NOT NULL "
                  "DEFAULT 'musteri'"
            ),
          ]) {
            if (await _tabloVar(m, tablo)) await _addColumnIfMissing(m, sql);
          }

          // v12 — MÜŞTERİ KARA LİSTESİ (2026-08-01).
          //
          // v10/v11 ile AYNI SEBEPTEN kapıdan ÖNCE ve KOŞULSUZ: aşağıdaki kendini-onarma kapısı
          // `tenant_settings`i görünce erken döner, `if (from < 12)` yazsaydık adım sahadaki
          // hiçbir cihazda koşmazdı. Arıza sessiz olurdu: senkron `blacklisted_at`i yazacak
          // kolonu bulamaz, kara liste hiç görünmezdi.
          if (await _tabloVar(m, 'customers')) {
            await _addColumnIfMissing(m, 'ALTER TABLE customers ADD COLUMN blacklisted_at TEXT');
          }

          // v13 — IBAN (2026-08-04). Borç hatırlatma mesajının içinde geçer.
          //
          // v10/v11/v12 ile AYNI SEBEPTEN kapıdan ÖNCE ve KOŞULSUZ: aşağıdaki kendini-onarma
          // kapısı `tenant_settings`i görünce erken döner, `if (from < 13)` yazsaydık adım
          // sahadaki hiçbir cihazda koşmazdı. Arıza yine SESSİZ olurdu: senkron `iban`ı yazacak
          // kolonu bulamaz, bayi Ayarlar'da IBAN'ını girer, "kaydedildi" görür ve hatırlatma
          // düğmesi ısrarla "IBAN tanımlı değil" demeye devam ederdi.
          if (await _tabloVar(m, 'tenant_settings')) {
            await _addColumnIfMissing(m, 'ALTER TABLE tenant_settings ADD COLUMN iban TEXT');

            // v13 — KURYE YETKİLERİ (aynı sürüm, aynı kapı). Varsayılanlar sunucudaki
            // migration 004002 ile birebir aynıdır; ayrışırlarsa senkron gelene kadar geçen
            // ilk karede ekran YANLIŞ yetkiyi gösterir (ve kurye kapalı sanılan bir düğmeye
            // basabilir).
            for (final sql in [
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_customers INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_orders INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_collect INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_discount INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_day_end INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_see_all_orders INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_view_history INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_expense INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE tenant_settings ADD COLUMN courier_phone_mask INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_customer_ledger INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_debt_reminder INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_toggle_stock INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE tenant_settings ADD COLUMN courier_can_call_log INTEGER NOT NULL DEFAULT 0',
            ]) {
              await _addColumnIfMissing(m, sql);
            }

            // v14 — IBAN ALICI ADI + HATIRLATMA ŞABLONU (2026-08-06). İkisi de nullable metin:
            // null = "tanımlı değil" ve mesaj kurulumu o hâlde ESKİ davranışına düşer (alıcı
            // satırına işletme adı yazılır, şablon varsayılandır). Bu yüzden mevcut satırlara
            // değer TAŞINMAZ; boş gelmeleri doğru başlangıçtır.
            //
            // v10..v13 ile AYNI SEBEPTEN aynı kapının içinde ve `from < 14` KOŞULU OLMADAN:
            // aşağıdaki kendini-onarma kapısı `tenant_settings`i görünce erken döner ve sahadaki
            // her cihazda o tablo zaten vardır. Arıza yine sessiz olurdu: bayi alıcı adını yazar,
            // "kaydedildi" görür, mesajda hiç görünmezdi.
            for (final sql in [
              'ALTER TABLE tenant_settings ADD COLUMN iban_owner_name TEXT',
              'ALTER TABLE tenant_settings ADD COLUMN reminder_template TEXT',
            ]) {
              await _addColumnIfMissing(m, sql);
            }
          }

          // v16 — SUNUCU SÖZLEŞME SÜRÜMÜ ÖNBELLEĞİ (2026-08-10). `sync_meta.api_version`.
          //
          // v10..v14 ile AYNI SEBEPTEN kapıdan ÖNCE ve `from < 16` KOŞULU OLMADAN: aşağıdaki
          // kendini-onarma kapısı `tenant_settings`i görünce ERKEN DÖNER ve sahadaki her cihazda
          // o tablo zaten vardır. Arıza yine SESSİZ olurdu — ama bu kez sessizliğin bedeli
          // daha ağır: alan yazılamayınca `sync_meta`ya dokunan HER sorgu "no such column" ile
          // patlar; 2026-08-09'da harita ekranının açılmamasının sebebi tam olarak buydu ve o
          // gün ödenen ders bu dosyanın `schemaVersion` başlığında yazılıdır.
          //
          // TABLO VARLIĞI ÖNCE SORULUR: v1 damgalı çok eski bir cihazda `sync_meta` HENÜZ YOKTUR
          // (aşağıdaki `from < 2` dalı kurar) ve orada kolon güncel şemadan hazır gelir.
          if (await _tabloVar(m, 'sync_meta')) {
            await _addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN api_version TEXT');
          }

          // v17 — KİŞİYE ÖZEL KURYE YETKİLERİ (2026-08-10). `users`a aynı 13 anahtar.
          //
          // v10..v16 ile AYNI SEBEPTEN kapıdan ÖNCE ve `from < 17` KOŞULU OLMADAN: aşağıdaki
          // kendini-onarma kapısı `tenant_settings`i görünce ERKEN DÖNER ve sahadaki her cihazda
          // o tablo zaten vardır. Arıza yine SESSİZ olurdu: senkron `team` bloğundaki kişisel
          // yetkiyi yazacak kolonu bulamaz, patron kuryeye özel iskonto yetkisi verir,
          // "kaydedildi" görür ve o telefonda hiçbir şey değişmezdi.
          //
          // NOT NULL + DEFAULT YAZILMAZ (bilinçli): `null` üçüncü bir durumdur — "bayi
          // varsayılanını devral". Varsayılan koysaydık yükseltme anında sahadaki HER kurye
          // o günkü değere çakılırdı ve bayi ayarını sonradan değiştirmesi hiçbirine işlemezdi.
          // Boş gelmeleri doğru başlangıçtır: davranış yükseltmeden önceki hâliyle birebir aynı.
          if (await _tabloVar(m, 'users')) {
            for (final kolon in [
              'courier_can_customers',
              'courier_can_orders',
              'courier_can_collect',
              'courier_can_discount',
              'courier_can_day_end',
              'courier_can_see_all_orders',
              'courier_can_view_history',
              'courier_can_expense',
              'courier_phone_mask',
              'courier_can_customer_ledger',
              'courier_can_debt_reminder',
              'courier_can_toggle_stock',
              'courier_can_call_log',
            ]) {
              await _addColumnIfMissing(m, 'ALTER TABLE users ADD COLUMN $kolon INTEGER');
            }
          }

          // v18 — SATIR NOTU + MÜŞTERİ FAVORİLERİ (2026-08-11).
          //
          // v10..v17 ile AYNI SEBEPTEN kapıdan ÖNCE ve `from < 18` KOŞULU OLMADAN: aşağıdaki
          // kendini-onarma kapısı `tenant_settings`i görünce ERKEN DÖNER ve sahadaki her cihazda
          // o tablo zaten vardır. Arıza yine SESSİZ olurdu ve iki ayrı biçimde ödenirdi:
          //  • `order_lines.note` yoksa senkron gelen satır notunu yazacak kolonu bulamaz —
          //    kurye kapıda "buzlu olsun" notunu HİÇ görmez, üstelik bayi onu yazdığını sanır;
          //  • `customers.favorite_product_ids` yoksa `customers`e dokunan HER sorgu
          //    "no such column" ile patlar (müşteri listesi, arayan tanıma, sipariş ekranı) —
          //    2026-08-09'da harita ekranını açılmaz yapan arıza sınıfının aynısı.
          //
          // İkisi de NULLABLE, varsayılansız: eski satırlarda "not yok" / "favori yok" doğru
          // başlangıçtır ve yükseltme öncesi davranışla birebir aynıdır.
          //
          // TABLO VARLIĞI ÖNCE SORULUR: v1 damgalı çok eski bir cihazda `order_lines` HENÜZ
          // YOKTUR (`from < 2` dalı kurar) ve orada kolon güncel şemadan hazır gelir.
          for (final (tablo, sql) in [
            ('order_lines', 'ALTER TABLE order_lines ADD COLUMN note TEXT'),
            ('customers', 'ALTER TABLE customers ADD COLUMN favorite_product_ids TEXT'),
          ]) {
            if (await _tabloVar(m, tablo)) await _addColumnIfMissing(m, sql);
          }

          // v19 — "BENİ HATIRLA" (2026-08-11). `sync_meta`ya iki cihaz-yerel kolon.
          //
          // v10..v18 ile AYNI SEBEPTEN kapıdan ÖNCE ve `from < 19` KOŞULU OLMADAN: aşağıdaki
          // kendini-onarma kapısı `tenant_settings`i görünce ERKEN DÖNER ve sahadaki her
          // cihazda o tablo zaten vardır. Bedeli v16'nınkiyle aynı sınıftan ve ağır olurdu —
          // `sync_meta`ya dokunan HER sorgu "no such column" ile patlar, yani giriş ekranı
          // dâhil uygulamanın tamamı açılmaz hâle gelirdi (2026-08-09 harita arızası).
          //
          // İkisi de NULLABLE, varsayılansız: "hatırlama kapalı" doğru başlangıçtır ve
          // yükseltme öncesi davranışla birebir aynıdır.
          if (await _tabloVar(m, 'sync_meta')) {
            for (final sql in [
              'ALTER TABLE sync_meta ADD COLUMN saved_tenant_code TEXT',
              'ALTER TABLE sync_meta ADD COLUMN saved_username TEXT',
            ]) {
              await _addColumnIfMissing(m, sql);
            }
          }

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

  /// KARANTİNADAKİ giden-kutusu kayıtlarının sayısı (akış).
  ///
  /// Sunucunun kalıcı olarak kabul etmediği olaylar SİLİNMEZ (BRIEF kırmızı çizgi #3) — ama
  /// sessizce durmaları da kabul edilemez: o sipariş/tahsilat bu telefonda VAR, sunucuda YOK.
  /// Bandın karantina satırı bu akıştan beslenir; sayı sıfırlanana kadar (destek kaydı elden
  /// geçirene kadar) bant durur. TUR BAŞINA bir sayaç yetmezdi: karantinaya alınan olay bir
  /// daha gönderilmediği için sonraki turlar temiz geçer ve uyarı ilk turda kaybolurdu.
  Stream<int> watchKarantinaSayisi() {
    final sayac = outbox.id.count();
    return (selectOnly(outbox)
          ..addColumns([sayac])
          ..where(outbox.status.equals('rejected')))
        .watchSingle()
        .map((r) => r.read(sayac) ?? 0);
  }

  /// GÖNDERİLMEYİ BEKLEYEN giden-kutusu kayıtlarının sayısı (akış) — senkronun YAZIM TETİĞİ.
  ///
  /// NEDEN VAR (2026-08-09 saha arızası): patron siparişi kuryeye atıyor, kurye yenilese bile
  /// göremiyordu; patron uygulamayı alta alıp öne getirince görünüyordu. Atama outbox'a düzgün
  /// düşüyordu — eksik olan, kaydın sunucuya GİDECEĞİ ANIN tetiklenmesiydi: tur yalnız dört DIŞ
  /// olayla açılıyordu (2 dk zamanlayıcı · ağ değişimi · öne gelme · aşağı çekerek yenileme) ve
  /// "alta alıp açınca gidiyor" gözlemi tam olarak `AppLifecycleState.resumed` turudur. Bu bir
  /// tutarlılık değil GECİKME arızasıydı; durağan durumu ölçen teşhislerin kaçırdığı da buydu.
  ///
  /// NEDEN AKIŞ, NEDEN `enqueueOutbox` İÇİNDEN ÇAĞRI DEĞİL: her yazım bir `db.transaction`
  /// İÇİNDEDİR (yerel satır + outbox aynı transaction'da — DECISIONS). Oradan tetiklenen bir tur
  /// commit'ten ÖNCE koşar ve ya kaydı göremez ya da yazma kilidine girer. Drift'in tablo
  /// bildirimi COMMIT sonrası düşer; [watchKarantinaSayisi] karantina bandını yıllardır bu
  /// desenle besliyor. Ayrıca outbox'a yazan 30 nokta (sipariş · defter · kasa devri · gün
  /// kapanışı · müşteri · ürün · kurye · çağrı günlüğü · muaf numara · işletme ayarları) tek
  /// tetiği paylaşır: repo katmanı senkrondan habersiz kalır, yarın eklenecek yazım unutulmaz.
  ///
  /// ⚠️ DİNLEYEN TARAF YALNIZ ARTIŞA TETİKLENMELİ: push kayıtları `acked` yapınca bu sayı düşer
  /// ve akış YİNE yayın yapar — düşüşe de tur açan bir dinleyici kendi kendini besleyen sonsuz
  /// tur döngüsü kurardı (bkz. `sync_service.dart::yazimTetigiBagla`).
  Stream<int> watchBekleyenSayisi() {
    final sayac = outbox.id.count();
    return (selectOnly(outbox)
          ..addColumns([sayac])
          ..where(outbox.status.equals('pending')))
        .watchSingle()
        .map((r) => r.read(sayac) ?? 0);
  }

  /// ALTER'ı "duplicate column"a TOLERANSLI koşar (savunma derinliği — sürüm damgası harici
  /// bir açıcı tarafından ezilirse migration yeniden koşabilir; var olan kolon hata değildir).
  /// Tablo bu veritabanında var mı? Migration adımları eski şemalarda da koştuğu için, henüz
  /// doğmamış bir tabloya ALTER atmadan önce sorulur.
  static Future<bool> _tabloVar(Migrator m, String ad) async {
    final r = await m.database
        .customSelect("SELECT 1 FROM sqlite_master WHERE type='table' AND name='$ad'")
        .get();
    return r.isNotEmpty;
  }

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
