// GÖÇ MERDİVENİ — v1'den bugüne her yükseltme adımı + açılış öncesi bakım.
//
// NEDEN AYRI DOSYA: `app_database.dart` 546 satıra çıkmıştı (500 satır kuralı) ve satırların
// dörtte üçü tek bir getter'dı. Ayrım anlamlı: burası ürünün EN RİSKLİ kodudur — sahadaki
// telefon offline-first çalışır ve günlerce eski şemada kalır; buradaki bir eksik ALTER,
// uygulamanın hiç açılmaması demektir (2026-08-17'de iki tanesi tam olarak böyle bulundu).
// Veritabanının geri kalanı (sorgular, akışlar) o riski taşımaz.
//
// ⚠️ KENDİNİ ONARMA KAPISI (`if (latest.isNotEmpty) return;`) BU DOSYANIN EN ÖNEMLİ SATIRIDIR:
// şema gerçekte güncelse migration atlanır. Bedeli şudur — KAPIDAN SONRA yazılan bir adım,
// kapının işaret tablosuna sahip olan cihazlarda HİÇ KOŞMAZ. Yeni adım yazarken sorulacak tek
// soru: "bu adımın koşması gereken cihazda `tenant_settings` var mı?" Varsa adım KAPIDAN ÖNCE
// yazılır. Bu kural iki kez ihlal edildi ve ikisi de sahada ölümcüldü.
//
// NEDEN `extension`: `migration` bir override'dır, extension override edemez — bu yüzden sınıf
// getter'ı burayı ÇAĞIRIR. Extension olması, gövdenin `select`/`into`/tablo adlarına önek
// olmadan erişmesini sağlar (aynı kütüphane, aynı `this`).

part of 'app_database.dart';

/// Şema göç merdiveni — `AppDatabase.migration` bunu çağırır.
extension _GocMerdiveni on AppDatabase {
  MigrationStrategy get gocStratejisi => MigrationStrategy(
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
            if (await AppDatabase._tabloVar(m, tablo)) await AppDatabase._addColumnIfMissing(m, sql);
          }

          // v12 — MÜŞTERİ KARA LİSTESİ (2026-08-01).
          //
          // v10/v11 ile AYNI SEBEPTEN kapıdan ÖNCE ve KOŞULSUZ: aşağıdaki kendini-onarma kapısı
          // `tenant_settings`i görünce erken döner, `if (from < 12)` yazsaydık adım sahadaki
          // hiçbir cihazda koşmazdı. Arıza sessiz olurdu: senkron `blacklisted_at`i yazacak
          // kolonu bulamaz, kara liste hiç görünmezdi.
          if (await AppDatabase._tabloVar(m, 'customers')) {
            await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE customers ADD COLUMN blacklisted_at TEXT');
          }

          // v13 — IBAN (2026-08-04). Borç hatırlatma mesajının içinde geçer.
          //
          // v10/v11/v12 ile AYNI SEBEPTEN kapıdan ÖNCE ve KOŞULSUZ: aşağıdaki kendini-onarma
          // kapısı `tenant_settings`i görünce erken döner, `if (from < 13)` yazsaydık adım
          // sahadaki hiçbir cihazda koşmazdı. Arıza yine SESSİZ olurdu: senkron `iban`ı yazacak
          // kolonu bulamaz, bayi Ayarlar'da IBAN'ını girer, "kaydedildi" görür ve hatırlatma
          // düğmesi ısrarla "IBAN tanımlı değil" demeye devam ederdi.
          if (await AppDatabase._tabloVar(m, 'tenant_settings')) {
            await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE tenant_settings ADD COLUMN iban TEXT');

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
              await AppDatabase._addColumnIfMissing(m, sql);
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
              await AppDatabase._addColumnIfMissing(m, sql);
            }
          }

          // ⚠️ v9 — OTO-SIRALAMA AYLIK KOTASI (`sync_meta.route_credits_monthly`).
          //
          // BURAYA TAŞINDI (2026-08-17): adım eskiden aşağıdaki `if (from < 9)` dalındaydı,
          // yani kendini-onarma kapısının ARKASINDAydı. Kapı `tenant_settings` varsa ERKEN
          // DÖNER ve o tablo tam olarak v8'de doğar — dolayısıyla **v8 damgalı bir cihazda bu
          // adım hiç koşmazdı**: kapı döner, dal görülmez. (v7 ve öncesi kurtuluyordu çünkü
          // orada `tenant_settings` kapı sorulduğu anda HENÜZ yok; v9 ve sonrasında kolon zaten
          // var.) Yani delik dar ama gerçekti ve bedeli ağır: kolon yoksa `sync_meta`ya dokunan
          // HER sorgu "no such column" ile patlar — giriş ekranı dâhil uygulama açılmaz.
          //
          // Sunucu sahipli, salt-okunur (subscription bloğundan iner). NOT NULL DEFAULT 0:
          // "kota bilinmiyor" doğru başlangıçtır, çekmece çubuğu o hâlde çizilmez.
          //
          // TABLO VARLIĞI ÖNCE SORULUR: v1 damgalı cihazda `sync_meta` henüz yoktur
          // (`from < 2` dalı kurar) ve orada kolon güncel şemadan hazır gelir.
          if (await AppDatabase._tabloVar(m, 'sync_meta')) {
            await AppDatabase._addColumnIfMissing(m,
                'ALTER TABLE sync_meta ADD COLUMN route_credits_monthly INTEGER NOT NULL DEFAULT 0');
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
          if (await AppDatabase._tabloVar(m, 'sync_meta')) {
            await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN api_version TEXT');
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
          if (await AppDatabase._tabloVar(m, 'users')) {
            // ⚠️ v13 — `users.username` (2026-08-04). BU ADIM ÜÇ AY BOYUNCA HİÇ YOKTU.
            //
            // Kolon `tables.dart`e eklendi, `schemaVersion` 13'e çıktı, ama `onUpgrade`e
            // KARŞILIĞI YAZILMADI. `users` tablosu `from < 7` dalında `createTable` ile doğar;
            // o yol tabloyu HER ZAMAN güncel şemayla kurar, bu yüzden v6 ve öncesinden gelen
            // her cihazda kolon kendiliğinden vardı ve eksiklik görünmedi. Sahadaki v7+ damgalı
            // cihazda ise `users` ZATEN VARDIR — orada kolon hiç eklenmedi.
            //
            // Bedeli sessiz değil, TAM: Drift `users`ı açık kolon listesiyle sorgular, yani
            // `no such column: users.username` ile Kuryeler ekranı, atama hedefi seçimi ve
            // senkronun `team` bloğunu uygulayan yazım komple patlardı — 2026-08-09'daki
            // `tenant_settings` arızasının birebir aynı sınıfı.
            //
            // NOT NULL DEFAULT '': Drift şemasındaki `withDefault(Constant(''))` ile birebir.
            // Boş dize "giriş adı bilinmiyor"dur ve ekran onu zaten böyle gösterir; sunucudan
            // gelen ilk `team` bloğu gerçek değeri yazar.
            await AppDatabase._addColumnIfMissing(
                m, "ALTER TABLE users ADD COLUMN username TEXT NOT NULL DEFAULT ''");

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
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE users ADD COLUMN $kolon INTEGER');
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
            if (await AppDatabase._tabloVar(m, tablo)) await AppDatabase._addColumnIfMissing(m, sql);
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
          if (await AppDatabase._tabloVar(m, 'sync_meta')) {
            for (final sql in [
              'ALTER TABLE sync_meta ADD COLUMN saved_tenant_code TEXT',
              'ALTER TABLE sync_meta ADD COLUMN saved_username TEXT',
            ]) {
              await AppDatabase._addColumnIfMissing(m, sql);
            }
          }

          // v20 — ARA TAHSİLAT İPTAL KAYDI (2026-08-13). `cash_handovers.reverses_handover_id`.
          //
          // v10..v19 ile AYNI SEBEPTEN kapıdan ÖNCE ve `from < 20` KOŞULU OLMADAN: aşağıdaki
          // kendini-onarma kapısı `tenant_settings`i görünce ERKEN DÖNER ve sahadaki her cihazda
          // o tablo zaten vardır. Bedeli burada v16/v19'unkiyle aynı sınıftan ve AĞIRDIR —
          // kolon yoksa `cash_handovers`a dokunan HER sorgu "no such column" ile patlar; o tablo
          // gün özetinin (kasa devri, ara tahsilat, kapanış önizlemesi) tam ortasındadır, yani
          // patron gün sonu ekranını hiç açamaz hâle gelirdi.
          //
          // NULLABLE, varsayılansız: eski satırların hiçbiri iptal kaydı DEĞİLDİR ve `null` tam
          // olarak bunu söyler. Yükseltme öncesi davranışla birebir aynı.
          if (await AppDatabase._tabloVar(m, 'cash_handovers')) {
            await AppDatabase._addColumnIfMissing(
                m, 'ALTER TABLE cash_handovers ADD COLUMN reverses_handover_id TEXT');
          }

          // v21 — ÇAĞRIYI KİM KARŞILADI (2026-08-13). `call_logs.user_id`.
          //
          // Aynı yerleşim gerekçesi (kapıdan ÖNCE, koşulsuz): kolon yoksa çağrı günlüğüne
          // dokunan her sorgu "no such column" ile patlar ve arayan tanıma kartının yazdığı
          // kayıt da düşer — yani telefon çalarken ürünün çekirdek özelliği ölür.
          //
          // NULLABLE ve GERİYE DÖNÜK DOLDURULMAZ: yükseltmeden önceki satırların atfı
          // bilinmiyor. `device_id`den kişiye eşleme yapmak "o gün o cihazı kim kullandı"
          // varsayımıdır; yanlış bir isim, bir kuryeyi yapmadığı aramadan sorumlu tutar.
          if (await AppDatabase._tabloVar(m, 'call_logs')) {
            await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE call_logs ADD COLUMN user_id TEXT');
          }

          // v22 — KAPANIŞI GERİ ALMA (2026-08-18). `day_closings.reverses_closing_id`.
          //
          // Yerleşim gerekçesi v20/v21 ile AYNI (kapıdan ÖNCE, koşulsuz): kendini-onarma kapısı
          // `tenant_settings`i görünce erken döner ve sahadaki her cihazda o tablo zaten vardır.
          // Bedeli burada da AĞIR — kolon yoksa `day_closings`e dokunan her sorgu "no such
          // column" ile patlar ve gün özeti ekranı hiç açılmaz (kapanmışlık sorgusu, arşiv,
          // kapanış önizlemesi hepsi o tablodan geçiyor).
          //
          // NULLABLE, varsayılansız: yükseltmeden önceki satırların hiçbiri geri alma kaydı
          // DEĞİLDİR ve `null` tam olarak bunu söyler.
          if (await AppDatabase._tabloVar(m, 'day_closings')) {
            await AppDatabase._addColumnIfMissing(
                m, 'ALTER TABLE day_closings ADD COLUMN reverses_closing_id TEXT');
          }

          // v23 — ÜRÜN SEÇENEKLERİ (2026-08-18). Üç tabloya birer JSON kolonu.
          //
          // Yerleşim gerekçesi v18..v22 ile AYNI (kapıdan ÖNCE, koşulsuz) ve bedeli burada EN
          // AĞIRLARDAN: üçü de ürünün çekirdek tablolarıdır. `products` ya da `order_lines`
          // kolonu eksik kalırsa sipariş açma, katalog ve sipariş listesi topluca "no such
          // column" ile düşer — yani uygulama günlük işini hiç yapamaz.
          //
          // HEPSİ NULLABLE: yükseltmeden önceki hiçbir ürünün seçeneği, hiçbir satırın seçimi
          // ve hiçbir müşterinin tercihi YOKTUR; `null` tam olarak bunu söyler ve yükseltme
          // öncesi davranışla birebir aynıdır.
          for (final (tablo, sql) in const [
            ('products', 'ALTER TABLE products ADD COLUMN options_json TEXT'),
            ('order_lines', 'ALTER TABLE order_lines ADD COLUMN options_json TEXT'),
            ('customers', 'ALTER TABLE customers ADD COLUMN product_options_json TEXT'),
            // v24 — HAZIRLANAN ÜRÜN YETENEĞİ (2026-08-18). Ürün seçenekleri özelliğinin
            // kiracı düzeyindeki anahtarı; gerekçesi `TenantSettings.preparedProducts`ta.
            //
            // NOT NULL DEFAULT 0 (kapalı): sahadaki her bayi yükseltmeden sonra bugünkü
            // davranışı görür — su bayisi ürün formunda hiçbir değişiklik fark etmez, özelliği
            // isteyen açar. Varsayılanı 1 yapmak, azınlığın ihtiyacını çoğunluğa dayatmak olurdu.
            ('tenant_settings',
                'ALTER TABLE tenant_settings ADD COLUMN prepared_products INTEGER NOT NULL DEFAULT 0'),
            // v25 — TESLİMİ KİM YAPTI (2026-08-20). Yerleşim gerekçesi v11..v24 ile AYNI
            // (kapıdan ÖNCE, koşulsuz): sahadaki her cihazda `tenant_settings` zaten var, yani
            // `if (from < 25)` yazsaydık adım hiçbir telefonda koşmazdı.
            //
            // BEDELİ AĞIR OLURDU: kolon eksikken teslim akışı `_recompute`ta "no such column:
            // delivered_by_user_id" ile düşer — yani kurye siparişi HİÇ teslim edemez. NULLABLE:
            // yükseltmeden önceki teslimlerin kim tarafından yapıldığı kayıtlı değildir.
            ('orders', 'ALTER TABLE orders ADD COLUMN delivered_by_user_id TEXT'),
          ]) {
            if (await AppDatabase._tabloVar(m, tablo)) {
              await AppDatabase._addColumnIfMissing(m, sql);
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
              await AppDatabase._addColumnIfMissing(
                m,
                "ALTER TABLE $table ADD COLUMN updated_occurred_at TEXT NOT NULL "
                "DEFAULT '1970-01-01T00:00:00.000Z'");
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE $table ADD COLUMN updated_device_id TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE $table ADD COLUMN deleted_at TEXT');
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
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE ledger_entries ADD COLUMN payment_type TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE ledger_entries ADD COLUMN reverses_entry_id TEXT');
            }
          }
          if (from < 4) {
            // FAZ 4 kurye: ADDİTİF (native sözleşme + mevcut veri korunur). orders'a atama, ledger'a
            // nakit atfı kolonu, sync_meta'ya oturum kullanıcısı; yeni cash_handovers tablosu. from<2
            // yolu bu tabloları zaten v4 şemasıyla (yeni kolonlar dahil) oluşturur; ALTER'lar yalnız
            // daha eski bir Drift kurulumunu (v2/v3) yükseltirken gerekli → koşullu ekle.
            if (from >= 2) {
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE orders ADD COLUMN assigned_user_id TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE ledger_entries ADD COLUMN collected_by_user_id TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN user_id TEXT');
            }
            await m.createTable(cashHandovers);
          }
          if (from < 5) {
            // FAZ 5a abonelik önbelleği: sync_meta'ya kilit alanları. from<2 yolu sync_meta'yı zaten
            // v5 şemasıyla (bu kolonlar dahil) oluşturur; ALTER yalnız v2/v3/v4 yükseltmesinde gerekli.
            if (from >= 2) {
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN locked_at_iso TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN subscription_status TEXT');
            }
          }
          if (from < 6) {
            // DİLİM 1 oturum: sync_meta'ya login alanları. from<2 yolu tabloyu zaten v6 şemasıyla
            // oluşturur; ALTER yalnız v2..v5 yükseltmesinde gerekli.
            if (from >= 2) {
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN auth_token TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN user_name TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN user_role TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN tenant_name TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN api_base_url TEXT');
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
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE customer_addresses ADD COLUMN region TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE products ADD COLUMN barcode TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE products ADD COLUMN image_url TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE products ADD COLUMN image_local_path TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE orders ADD COLUMN sort_index INTEGER');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE order_lines ADD COLUMN unit TEXT');
              await AppDatabase._addColumnIfMissing(
                  m, 'ALTER TABLE order_lines ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN tenant_code TEXT');
              await AppDatabase._addColumnIfMissing(
                  m, 'ALTER TABLE sync_meta ADD COLUMN route_credits INTEGER NOT NULL DEFAULT 0');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN setup_completed_at TEXT');
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE sync_meta ADD COLUMN theme_mode TEXT');
            }
            if (from >= 7) {
              // users v7'de oluştu; telefon v8 eklentisi (from<7 yolu tabloyu v8 şemasıyla kurar).
              await AppDatabase._addColumnIfMissing(m, 'ALTER TABLE users ADD COLUMN phone TEXT');
            }
            await m.createTable(tenantSettings);
            await m.createTable(exemptNumbers);
            await m.createTable(callLogs);
            await m.createTable(dayClosings);
            await m.createIndex(idxProductsBarcode);
            await m.createIndex(idxExemptLast10);
            await m.createIndex(idxCallLogsOccurred);
          }
          // v9 ADIMI BURADAN KALDIRILDI — kapının ARKASINDA olduğu için v8 damgalı cihazda hiç
          // koşmuyordu; kapıdan ÖNCEye taşındı (yukarıdaki `route_credits_monthly` bloğu).
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
}
