// İŞLETME ve ALTYAPI TABLOLARI — ekip · bayi ayarları · muaf numaralar · çağrı günlüğü ·
// gün kapanışları · outbox · senkron durumu.
//
// NEDEN AYRI DOSYA: `tables.dart` 566 satıra çıkmıştı (500 satır kuralı). Ayrım şu soruyla
// yapıldı: "bu tablo bayinin GÜNLÜK İŞİNİ mi tutuyor, yoksa işletmenin AYARINI/ALTYAPISINI mı?"
// `tables.dart`ta müşteri · adres · ürün · sipariş · defter · kasa devri kaldı; burada ekip,
// ayarlar ve senkron makinesi var.
//
// ⚠️ `part` KULLANILDI, AYRI KÜTÜPHANE DEĞİL: Drift'in ürettiği `app_database.g.dart` bu
// tabloların TEK bir kütüphanede yaşadığını varsayar. `part` olduğu sürece üretilmiş dosya
// hiç değişmez — bölme codegen gerektirmez. Ayrı kütüphane yapmak 19 bin satırlık üretilmiş
// dosyayı yeniden üretmeyi ve o çıktıyı incelemeyi gerektirirdi.

part of 'tables.dart';
/// Sunucu `users` aynası (FAZ 4b Dilim 4 — team bloğu). PII ASGARİ: yalnız id/name/role/status;
/// email/parola/telefon YOK (sunucu da göndermez). LWW/tombstone YOK — bu tablo salt sunucu-kaynaklı
/// önbellektir: her `team` bloğunda TOPTAN değiştirilir (delete-all + insert).
/// Kullanıcı istemciden ASLA push edilmez; atama hedefi ve atanan kurye adı çözümü için tutulur.
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get role => text()(); // patron|operator|kurye
  TextColumn get status => text()(); // active|disabled

  /// Kullanıcının GİRİŞ ADI (kullanıcı isteği 2026-08-04 — Kuryeler ekranı gösterir ve düzenler).
  /// Sır değildir: patron kuryeye zaten kendisi söyler, unuttuğunda soracağı yer burasıdır.
  /// PAROLA BURADA YOK ve hiç olmayacak — parola yalnız YAZILIR (`/team/{id}/credentials`),
  /// hiçbir yönde okunmaz. Eski sunucu alanı göndermezse boş kalır.
  TextColumn get username => text().withDefault(const Constant(''))();

  /// Kurye telefonu (tasarım: Kuryeler ekranı gösterir/düzenler). Bayinin KENDİ personel iletişim
  /// bilgisidir; e-posta/parola hâlâ sunucuda kalır ve team bloğuna hiç girmez.
  TextColumn get phone => text().nullable()();

  // ---- KİŞİYE ÖZEL KURYE YETKİLERİ (kullanıcı kararı 2026-08-10) ----
  //
  // ÜÇ DURUMLU ve bu yüzden `nullable()`: `null` = "bayi varsayılanını DEVRAL", true/false =
  // bu kuryeye özel ezme. Aynı 13 anahtar `tenant_settings`te de durur ve orada anlamı
  // değişti — artık "bayi varsayılanı / yeni kurye şablonu"dur. Etkin yetki tek yerde
  // çözülür: `screens/team.dart::kuryeIzinleriCoz` (kisisel ?? varsayilan).
  //
  // NEDEN `withDefault` YOK: varsayılan koymak üçüncü durumu (devralma) YOK EDERDİ — sahadaki
  // her kurye, bayi ayarını sonradan değiştirse bile kurulum anındaki değere çakılı kalırdı.
  // Eski sunucu bu alanları göndermezse de null kalır ve davranış bugünküyle birebir aynıdır.
  BoolColumn get courierCanCustomers => boolean().nullable()();
  BoolColumn get courierCanOrders => boolean().nullable()();
  BoolColumn get courierCanCollect => boolean().nullable()();
  BoolColumn get courierCanDiscount => boolean().nullable()();
  BoolColumn get courierCanDayEnd => boolean().nullable()();
  BoolColumn get courierCanSeeAllOrders => boolean().nullable()();
  BoolColumn get courierCanViewHistory => boolean().nullable()();
  BoolColumn get courierCanExpense => boolean().nullable()();
  BoolColumn get courierPhoneMask => boolean().nullable()();
  BoolColumn get courierCanCustomerLedger => boolean().nullable()();
  BoolColumn get courierCanDebtReminder => boolean().nullable()();
  BoolColumn get courierCanToggleStock => boolean().nullable()();
  BoolColumn get courierCanCallLog => boolean().nullable()();

  /// v27 (2026-08-22) — kurye TÜM müşterileri görebilir mi. `null` = bayi varsayılanını devral.
  /// Gerekçe [TenantSettings.courierCanSeeAllCustomers] üzerinde.
  BoolColumn get courierCanSeeAllCustomers => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// İşletme profili (tasarım: "İşletme Profili") — cihazda TEK SATIR (id=1, sync_meta deseni).
/// Sunucuda anahtar tenant_id'dir; istemci tek kiracı olduğu için tenant_id BURADA YOK (DECISIONS).
/// Push payload'ında id GÖNDERİLMEZ — sunucu oturumdaki tenant'ı anahtar olarak kullanır, böylece
/// iki cihazın çevrimdışı yazımı aynı satırda LWW ile birleşir (çakışıp reddedilemez).
class TenantSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get businessName => text().nullable()();
  TextColumn get ownerName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get whatsapp => text().nullable()();
  TextColumn get addressText => text().nullable()();
  TextColumn get taxOffice => text().nullable()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get opensAt => text().nullable()();  // 'SS:DD'
  TextColumn get closesAt => text().nullable()();
  TextColumn get receiptNote => text().nullable()();

  /// Bayinin KENDİ IBAN'ı (kullanıcı isteği 2026-08-04) — borçluya gönderilen WhatsApp
  /// hatırlatmasında geçer. Boşluksuz ve BÜYÜK harf saklanır (sunucu da normalleştirir);
  /// null = tanımlı değil, hatırlatma düğmesi o zaman nedenini söyleyip durur.
  TextColumn get iban => text().nullable()();

  /// IBAN ALICI ADI (kullanıcı isteği 2026-08-06) — hesap sahibinin AD SOYADI.
  ///
  /// NEDEN AYRI ALAN: hesap sahibi çoğu zaman ŞAHIS adıdır ("Mehmet Yılmaz"), işletme adıyla
  /// ("Merkez Su Bayii") aynı değildir; banka uygulaması havale ekranında ad soyad ister ve
  /// işletme adını yazan müşteri işlemi tamamlayamaz. Boşsa mesajda işletme adına DÜŞÜLÜR —
  /// güncelleme öncesi davranış budur, hiçbir bayi "Alıcı" satırını bu sürümle kaybetmemeli.
  TextColumn get ibanOwnerName => text().nullable()();

  /// BORÇ HATIRLATMA ŞABLONU (kullanıcı isteği 2026-08-06) — bayinin kendi mesaj metni.
  ///
  /// null/boş = VARSAYILAN metin (`borc_hatirlatma.dart`). Varsayılanı buraya kopyalamak,
  /// metni ileride iyileştirdiğimizde şablona hiç dokunmamış bayilerde eski metni dondururdu.
  /// Yer tutucular (`*musteriadi*`, `*siparistutar*`, `*ibanodemebilgileri*` …) gönderim anında
  /// çözülür; IBAN ve alıcı adı SABİT bloktur, metnin içinde düzenlenemez.
  TextColumn get reminderTemplate => text().nullable()();

  /// KURYE VE ROL YETKİ MATRİSİ — bayinin açıp kapatabildiği dinamik yetkiler.
  /// KİRACI düzeyindedir (kurye başına değil): 1–3 kişilik bayide kişi bazlı yetki, her yeni
  /// kuryede unutulan bir kurulum adımı doğururdu. Varsayılanlar sunucudakiyle AYNI olmalı —
  /// senkron gelmeden önce ekran bir kare boyunca bu değerleri gösterir.
  BoolColumn get courierCanCustomers => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanOrders => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanCollect => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanDiscount => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanDayEnd => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanSeeAllOrders => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanViewHistory => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanExpense => boolean().withDefault(const Constant(false))();
  BoolColumn get courierPhoneMask => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanCustomerLedger => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanDebtReminder => boolean().withDefault(const Constant(false))();
  BoolColumn get courierCanToggleStock => boolean().withDefault(const Constant(true))();
  BoolColumn get courierCanCallLog => boolean().withDefault(const Constant(false))();

  /// KURYE TÜM MÜŞTERİLERİ GÖREBİLİR Mİ (kullanıcı kararı 2026-08-22).
  ///
  /// KAPALIYKEN müşteri listesi kuryenin KENDİ siparişlerinin müşterileriyle sınırlanır.
  /// `courierCanCustomers`tan AYRI BİR SORUDUR ve karıştırılmamalı: o "ekleyip düzenleyebilir
  /// mi", bu "kimleri görebilir". Bugüne kadar ikincisinin cevabı sorulmadan "hepsi"ydi.
  ///
  /// ⚠️ VARSAYILAN KAPALI ve bu bir DAVRANIŞ DEĞİŞİKLİĞİDİR — isteğin kendisi kısıtlamadır.
  /// Gerekçenin tamamı sunucu migration'ında (`..._add_courier_can_see_all_customers.php`).
  ///
  /// KISITLAMA EKRANDA UYGULANIR, SENKRONDA DEĞİL: müşteriler telefona inmeye devam eder
  /// (offline-first). Sunucuda süzmek, kuryeye ATANAN siparişin müşterisi henüz inmemişse
  /// kapıda adressiz bırakırdı — kırmızı çizgi #3.
  BoolColumn get courierCanSeeAllCustomers => boolean().withDefault(const Constant(false))();

  /// İŞLETMEDE HAZIRLANAN ÜRÜN VAR MI? (kullanıcı kararı 2026-08-18) — ürün seçenekleri
  /// ("içinde şu olsun olmasın") özelliğinin KİRACI DÜZEYİNDEKİ anahtarı.
  ///
  /// ══ NEDEN GEREKLİ ═══════════════════════════════════════════════════════════════════════
  /// Bu uygulamayı ÇOK FARKLI işletmeler kullanır: su bayii, tüp bayii, market, dönerci,
  /// tostçu. Su bayisinde "içindekiler" diye bir kavram YOKTUR ve ürün formunda o bölümü her
  /// ürün için çizmek, 12 üründe 12 kez cevapsız bir soru sormaktır.
  ///
  /// ══ NEDEN "İŞLETME TÜRÜ" DEĞİL, YETENEK ═══════════════════════════════════════════════
  /// Tek bir tür etiketi ("market" / "dönerci") bu ürünü tarif EDEMEZ: kullanıcının verdiği
  /// örnek tam da bunu gösteriyor — küçük bir bakkal hem paketli ürün satar HEM tost yapar.
  /// Tür bir etikettir; davranışı belirleyen şey YETENEKTİR. İleride gelecek kurulum sihirbazı
  /// "işletmen ne?" diye sorup bu yeteneği AYARLAYACAK; ekranlar türü değil yeteneği okur.
  ///
  /// ⚠️ VARSAYILAN KAPALI ve bu bilinçli: bu üründeki bayilerin çoğunluğu (BRIEF) su/tüp
  /// bayisidir; azınlık için herkese gürültü eklemek yanlış yöndür. Açan bayi Ayarlar →
  /// İşletme → "Ürün içerikleri" satırından açar; sihirbaz geldiğinde ilk kurulumda sorulacak.
  ///
  /// KAPALI OLMASI VERİYİ SİLMEZ: ürünlerin kayıtlı malzeme listeleri yerinde kalır, yalnız
  /// düzenleyici gizlenir. Yeniden açıldığında hepsi geri gelir.
  BoolColumn get preparedProducts => boolean().withDefault(const Constant(false))();

  /// Sipariş SATIRINDA hangi kod görünsün: `musteri` (varsayılan) | `siparis`.
  /// Bayi tercihidir ve KİRACI düzeyindedir — cihaz-yerel olsaydı iki telefonlu bayi aynı
  /// listede iki farklı numara görürdü. Sipariş kodu her hâlükârda DETAYDA görünür.
  TextColumn get orderCodeDisplay =>
      text().withDefault(const Constant('musteri'))();

  TextColumn get updatedOccurredAt => text().nullable()();
  TextColumn get updatedDeviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Muaf telefonlar (tasarım: "Muaf Telefonlar") — bu numaralar aradığında çağrı kartı ÇIKMAZ.
/// `phone_last10` indeksi customer_phones ile aynı sözleşmedir: native taraf kartı çizmeden ÖNCE
/// bu tabloyu salt-okunur sorgular, bu yüzden tablo cihazda BULUNMAK ZORUNDA.
@TableIndex(name: 'idx_exempt_last10', columns: {#phoneLast10})
class ExemptNumbers extends Table {
  TextColumn get id => text()();
  TextColumn get phoneE164 => text()();
  TextColumn get phoneLast10 => text()();
  TextColumn get label => text().nullable()();
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Çağrı günlüğü (tasarım: "Son Aramalar"). direction: incoming|missed|outgoing.
/// APPEND-ONLY DEĞİL: `outcome`/`customerId` çağrıdan sonra zenginleşir (karttan sipariş açılınca);
/// para kaydı olmadığından kırmızı çizgi #2 kapsamı dışında — standart LWW + tombstone.
@TableIndex(name: 'idx_call_logs_occurred', columns: {#occurredAt})
class CallLogs extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().nullable()(); // kayıtsız numarada null
  TextColumn get phoneE164 => text()();
  TextColumn get phoneLast10 => text()();
  TextColumn get direction => text()();
  TextColumn get outcome => text().nullable()();
  TextColumn get relatedOrderId => text().nullable()();

  /// Çağrıyı KİM karşıladı / kim yaptı (`users.id`) — kullanıcı isteği 2026-08-13.
  ///
  /// NEDEN `device_id` YETMEDİ: cihaz kimliği zaten vardı ama bir CİHAZI anlatır, kişiyi değil.
  /// Aynı telefonu iki kişi kullanabilir (patron sabah, operatör akşam) ve bir kurye telefon
  /// değiştirdiğinde geçmişi kopar. Patronun sorduğu soru "hangi TELEFONDAN arandı" değil,
  /// "kim aradı".
  ///
  /// NULLABLE ve öyle KALMALI: bu alan eklenmeden ÖNCE yazılmış kayıtlarda atıf YOKTUR ve
  /// uydurulamaz — `device_id`den kişiye geriye dönük eşleme yapmak, o cihazı o gün kimin
  /// kullandığını VARSAYMAK olurdu. Eski satırlar ekranda "bilinmiyor" der; yanlış bir isim
  /// yazmaktansa boş bırakmak dürüsttür (bu, bir kuryenin yapmadığı aramadan sorumlu
  /// tutulmasını da engeller).
  TextColumn get userId => text().nullable()();

  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get updatedOccurredAt => text()();
  TextColumn get updatedDeviceId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Gün sonu kapanış arşivi (tasarım: "Gün Sonu → Hesabı Kapat" + "Arşiv") — APPEND-ONLY ayna.
/// scope: day (günün tamamı, userId null) | courier (kurye hesabı, userId dolu). Özet tutarlar
/// kapatıldığı ANDAKİ gerçeği taşır; geç senkron arşivi değiştirmez. diffKurus fark KANITIdır.
class DayClosings extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get userId => text().nullable()();

  /// GERİ ALMA KAYDI (kullanıcı kararı 2026-08-18): dolu ise bu satır bir kapanışı GERİ ALIR ve
  /// geri aldığı kapanışın id'sini taşır. `cash_handovers.reversesHandoverId` deseninin aynısı.
  ///
  /// NEDEN KOLON, NEDEN SİLME/GÜNCELLEME DEĞİL: BRIEF kırmızı çizgi #2 — para kayıtları
  /// silinmez/ezilmez. Yanlış sayılmış bir kapanış gerçekten OLMUŞ bir olaydır; satırı yok etmek
  /// defterin "ne olduğunu" değil "ne olduğunu sandığımızı" anlatır hâle getirirdi. Geri alma
  /// İKİNCİ bir satırdır: orijinal kanıt olarak yerinde durur, gün yeniden açılır.
  ///
  /// ⚠️ BU KOLON DOLU OLAN SATIR BİR KAPANIŞ DEĞİLDİR. Kapanmışlık sorgusu
  /// (`DayClosingRepository.kapaliMi`) hem geri alma satırlarını hem de geri alınmış kapanışları
  /// elemek zorundadır; elemezse gün "iki kez kapalı" görünür ve yeniden kapatma engellenir.
  TextColumn get reversesClosingId => text().nullable()();

  TextColumn get periodStart => text().nullable()();
  IntColumn get deliveryCount => integer().withDefault(const Constant(0))();
  IntColumn get totalCollectedKurus => integer().withDefault(const Constant(0))();
  IntColumn get cashNakitKurus => integer().withDefault(const Constant(0))();
  IntColumn get cashKartKurus => integer().withDefault(const Constant(0))();
  IntColumn get cashHavaleKurus => integer().withDefault(const Constant(0))();
  IntColumn get openCreditKurus => integer().withDefault(const Constant(0))();
  IntColumn get expectedCashKurus => integer().withDefault(const Constant(0))();
  IntColumn get countedCashKurus => integer().nullable()();
  IntColumn get diffKurus => integer().withDefault(const Constant(0))();
  TextColumn get cashHandoverId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Giden kutusu (DECISIONS: yazma yolu outbox üzerinden). Yerel yazma + outbox AYNI transaction'da.
/// client_event_id tenant-içi tekil idempotency anahtarı; retry her zaman güvenli.
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientEventId => text()();
  TextColumn get entityType => text()();
  TextColumn get op => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get payload => text()(); // json
  TextColumn get occurredAt => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending|acked|failed
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {clientEventId},
      ];
}

/// Senkron durumu (tek satır, id=1). Delta imleci + saat offset + ileri-sadece saat çıpası (Faz 5).
class SyncMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get lastPulledSeq => integer().withDefault(const Constant(0))();
  TextColumn get lastServerTimeIso => text().nullable()();
  IntColumn get serverTimeOffsetMs => integer().withDefault(const Constant(0))();
  IntColumn get elapsedAnchorMs => integer().nullable()();
  BoolColumn get snapshotDone => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text().nullable()();

  /// Oturumdaki kullanıcı (FAZ 4): teslim/tahsilatta collected_by_user_id ve kasa devrinde from_user_id
  /// kaynağı. Login akışı doldurur (Faz 5); yoksa null → nakit atfı boş, kasa devri opsiyonel.
  TextColumn get userId => text().nullable()();

  /// Abonelik durumu ÖNBELLEĞİ (FAZ 5a — DECISIONS: tek doğru kaynak sunucu, istemci önbellekler).
  /// Sunucunun her push/pull yanıtındaki `subscription` bloğundan yazılır. İstemci ileri-sadece saatle
  /// (lastServerTimeIso + elapsedAnchorMs) kilit/grace kararını bu değerlerden verir.
  TextColumn get validUntilIso => text().nullable()();
  TextColumn get lockedAtIso => text().nullable()();
  TextColumn get subscriptionStatus => text().nullable()(); // trial|active|locked|suspended

  /// Oturum (DİLİM 1 — Saha UI). Sanctum bearer token'ı uygulama-özel sandbox'taki bu DB'de durur;
  /// cihaz bayinindir, DB dosyasına başka uygulama erişemez (Android app-private). Token NULL = çıkış.
  /// Çıkışta yalnız token silinir — yerel iş verisi KALIR (offline-first; veri kaybettirme yok).
  TextColumn get authToken => text().nullable()();
  TextColumn get userName => text().nullable()();
  TextColumn get userRole => text().nullable()(); // patron|operator|kurye
  TextColumn get tenantName => text().nullable()();

  /// API taban adresi (varsayılan üretim; geliştirmede login ekranından değiştirilebilir).
  TextColumn get apiBaseUrl => text().nullable()();

  /// SUNUCUNUN SÖZLEŞME SÜRÜMÜ (`api_version`, SemVer) — son senkron turunda görülen değer.
  ///
  /// NEDEN SAKLANIYOR, anlık okunmuyor: uygulama offline-first çalışır ve bayi Ayarlar'ı çoğu
  /// zaman ağ yokken açar. Değeri saklamayan bir gösterim, tam da "sunucuya ulaşamıyorum"
  /// anında — yani sürümün en çok merak edildiği anda — boş kalırdı.
  ///
  /// null = "bu cihaz sunucuyla hiç konuşmadı ya da sunucu sürümünü henüz bildirmiyor".
  /// Eski değer YENİSİYLE EZİLİR ama YOKLUKLA EZİLMEZ (bkz. SyncEngine): sürüm bildirmeyen bir
  /// yanıt, bilinen son sürümü silmek için gerekçe değildir.
  TextColumn get apiVersion => text().nullable()();

  /// SUNUCU SAHİPLİ, salt-okunur önbellek (subscription bloğundan): tasarımdaki "Firma Kodu"
  /// (değiştirilemez) ve "Oto Sırala (rota) · N hak" sayacı. İstemci bunları YAZAMAZ.
  TextColumn get tenantCode => text().nullable()();
  IntColumn get routeCredits => integer().withDefault(const Constant(0))();

  /// Aylık oto-sıralama kotası (çekmecedeki "Aylık 50"). Kalan/kota oranı ilerleme çubuğunu
  /// çizer; kota bilinmezse çubuk çizilemez, o yüzden ayrı alan olarak saklanır.
  IntColumn get routeCreditsMonthly => integer().withDefault(const Constant(0))();

  /// CİHAZ-YEREL tercihler (senkronlanmaz): izin sihirbazının tamamlanma damgası ve tema seçimi.
  /// İzinler cihaza özgüdür — başka cihaza taşınmaları yanlış olurdu.
  TextColumn get setupCompletedAt => text().nullable()();
  TextColumn get themeMode => text().nullable()(); // koyu|acik

  /// "Beni hatırla" — giriş ekranının ÖNDOLDURDUĞU kimlik. CİHAZ-YEREL, senkronlanmaz.
  ///
  /// ⚠️ PAROLA BURADA YOK VE OLMAYACAK. Saklanan tek şey, kullanıcının zaten ekranda gördüğü
  /// iki genel bilgidir: firma kodu (İşletme Profili onu "değiştirilemez" diye yayınlıyor) ve
  /// kullanıcı adı. Parolayı da saklamak, oturum açma kapısını "cihazı eline geçiren herkes
  /// girebilir"e indirirdi — oysa çıkış yapmanın TEK anlamı budur. Kolaylık zaten büyük kısmı
  /// karşılanıyor: `authToken` çıkış yapılana kadar durur, yani bu iki alan yalnız BİLİNÇLİ
  /// çıkıştan sonraki girişte okunur.
  ///
  /// [savedTenantCode] SUNUCU SAHİPLİ [tenantCode]'dan AYRI bir alandır ve bilerek öyledir:
  /// o, senkronun yazdığı bir önbellektir (istemci yazamaz) ve oturum yokken doğruluğu
  /// garanti değildir; bu ise kullanıcının kendi yazdığı, kendi kapatabildiği bir tercihtir.
  /// Tek kolona bindirmek, "hatırlama"yı kapatan bayinin ekranında sunucudan gelen kodun
  /// yine belirmesi demek olurdu.
  ///
  /// İkisi de null = hatırlama KAPALI (varsayılan).
  TextColumn get savedTenantCode => text().nullable()();
  TextColumn get savedUsername => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// BİLDİRİM KUTUSU (v26, 2026-08-21) — "ana sayfada okunmamış bildirimler görünsün".
///
/// ══ CİHAZ-YEREL, SENKRONLANMAZ ══════════════════════════════════════════════════════════════
/// Bir bildirim, BU CİHAZA teslim edilmiş bir olaydır: yerel kural bu telefonun verisinden
/// üretir, push bu telefona düşer. "Okundu" da cihaz düzeyinde bir olgudur — patron kendi
/// telefonunda okuduğu bir uyarıyı kuryenin telefonunda da okumuş SAYILMAZ, çünkü o telefona
/// zaten hiç gelmemiştir. Senkronlamak, olmayan bir ortaklık uydurmak olurdu. `outbox`a HİÇ
/// girmez; sunucu bu tablodan habersizdir.
///
/// ══ KİMLİK = BİLDİRİMİN KİMLİĞİ ═════════════════════════════════════════════════════════════
/// Birincil anahtar `BildirimTaslagi.kimlik`tir, yani sistemdeki bildirimle AYNI tekillik
/// kuralı: aynı kimlik ikinci kez gösterilince YENİ SATIR AÇILMAZ, mevcut satır tazelenir.
///
/// ⚠️ TAZELEME `okundu_at`i VE `occurred_at`i KORUR. Kurallar gün damgalı kimlikler üretir ve
/// AÇILIŞTA yeniden koşar (`BildirimTetikleyici.anlik`); okunma damgası her açılışta silinseydi
/// bayi aynı uyarıyı bir daha asla kapatamazdı. `occurred_at` korunmasa da liste her açılışta
/// yeniden sıralanır ve okunmuş satırlar durmadan yukarı zıplardı.
class Bildirimler extends Table {
  /// `BildirimTaslagi.kimlik` — kategori önekli tekil anahtar.
  TextColumn get id => text()();

  /// `BildirimKategori.name`. Metin olarak saklanır: enum'a yeni değer eklenip eskisi
  /// kaldırıldığında eski satır okunamaz hâle gelmesin (liste bir ARŞİVDİR).
  TextColumn get kategori => text()();

  TextColumn get baslik => text()();
  TextColumn get govde => text()();

  /// Genişletilmiş metin; yoksa null (liste satırı yalnız gövdeyi yazar).
  TextColumn get detay => text().nullable()();

  /// Dokununca gidilecek ekran (`gunsonu` · `siparisler` · `musteri/<id>` …); yoksa null.
  TextColumn get yol => text().nullable()();

  /// Bildirimin DOĞDUĞU an (UTC ISO). Sıralama bundan.
  TextColumn get occurredAt => text()();

  /// Okunma anı (UTC ISO); null = OKUNMAMIŞ. Rozet bu alanı sayar.
  TextColumn get okunduAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
