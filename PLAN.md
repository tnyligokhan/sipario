# PLAN.md — Yol Haritası ve Devir Durumu

> **Nasıl kullanılır:** Her oturuma başlarken Claude'a bu dosyayı, `BRIEF.md`'yi ve
> `DECISIONS.md`'yi okut. Vardiyanı bitirirken Claude'a "PLAN.md'nin güncel durum
> bölümünü güncelle" de — sonraki kişi kaldığın yerden devam eder. Sohbet geçmişi
> paylaşılmaz; **bu üç dosya + git geçmişi projenin tek ortak hafızasıdır.**
>
> ## ▶ VARDİYAYA BAŞLIYORSAN
> Doğruca **`## Güncel durum` → `🔻 VARDİYA DEVİR NOTU`** bölümüne git (bu dosyada, aşağıda).
> Orada ne yapıldığı, ne yapılmadığı ve **sıradaki işler adım adım** yazılıdır. Aşağıdaki
> ilerleme panosu ve faz tabloları ARKA PLANDIR; günlük iş o bölümdedir.
> `YAPILACAKLAR.md` ile çelişirse **devir notu doğrudur** (o dosya bayat).

## İlerleme panosu (SABİT — her vardiya sonunda güncellenir)

> **Genel proje: ~%78** (2026-07-17 DÜZELTME tabanı: eski %79 yalnız sunucu+veri katmanını sayıyordu —
> UI eforu "4b · Saha UI" satırıyla panoya eklendi.)
> **Faz 4: ~%92** · **Faz 5: ~%93** · **Faz 6: ~%22** · **4b UI: ✅ KAPANDI (Dilim 1+2+3+4)**
> _(2026-07-21/3: **UI Dilim 4 BİTTİ — 4b TAMAMEN KAPANDI: kurye listesi sunucudan team bloğuyla,
> Drift v7 users aynası, K2 rol-yetki matrisi, atama UI, kasa devri ekranı, tek-kişilik gizleme;
> mobil 159/159 · API 174/174 · inceleme YEŞİL · APK derlendi · guzzle güvenlik yükseltmesi (4
> Dependabot uyarısı kapandı)**. KODLA YAPILABİLİR İŞ BİTTİ — kalan her şey dışsal/insan:
> YAPILACAKLAR.md + PR #11 merge + gerçek cihaz + pilot.)_

| Faz | Ağırlık | Durum | Katkı |
|-----|---------|-------|-------|
| 0 · Arayan tanıma kanıtı | %7 | ✅ kapandı | 7 |
| 1 · Temel (API/Postgres+RLS/auth) | %10 | ✅ kapandı | 10 |
| 2 · Offline çekirdek (Drift/outbox/sync) | %13 | ✅ kapandı | 13 |
| 3 · Defter (veresiye/kasa/kupon/gün sonu) | %10 | ✅ kapandı | 10 |
| 4 · Kurye (atama/teslim/kasa devri/+iOS) | %11 | 🔄 ~%92 (API✅ inceleme✅ mobil test✅; iOS açık) | ~10 |
| **4b · Saha UI (bayi+kurye ekranları)** | **%15** | ✅ **KAPANDI** (D1 giriş+kabuk+müşteri · D2 sipariş+teslim+ürün · D3 defter+tahsilat+gün-sonu · D4 kurye+kasa devri) | 15 |
| 5 · Para (site/iyzico/abonelik/panel) | %17 | 🔄 ~%93 KOD TAM (dışsal: anahtar/hukuk) | ~16 |
| 6 · Mağaza + hukuk (Play/KVKK/mesafeli) | %10 | 🔄 ~%22 (demo hesap ✅ + metin paketi ✅ + hesap-silme ✅; kalan dışsal) | ~2 |
| 7 · Antalya pilotu (2–3 bayi) | %7 | ⬜ bekliyor (saha/insan) | 0 |
| **Toplam** | **%100** | | **~%78** |

> Ağırlıklar EFOR tahminidir (fazlar eşit büyüklükte değil); genel yüzde bu ağırlıklara göre hesaplanır.
> Bir faz kapandığında Katkı = tam Ağırlık olur ve genel yüzde artar. Mevcut faz yüzdesi kaba göstergedir:
> mimari/kod/test/inceleme dört kapısına göre biçilir. **2026-07-17 ağırlık düzeltmesi:** eski tablo
> UI eforunu hiç içermiyordu; her faz "UI sonraki iş" deyip devretmiş, iş sahipsiz kalmıştı. Eski
> satırlar ×0,85 küçültüldü, %15'lik "4b · Saha UI" eklendi — genel yüzdedeki düşüş (%79→%68) gerileme
> değil, ölçeğin dürüstleşmesidir.

## İnsan gerektiren işler (SENİN SIRAN — otonom modda bunlara takılmam, listeye yazıp devam ederim)

> Kullanıcı kararı (2026-07-15): "bana sormadan ajanlarla limit bitene kadar devam et." Dışsal/insan
> gerektiren şeyleri buraya biriktiriyorum; teknik her kararı kendim verip ilerliyorum.

- **[Faz 4]** Mobil doğrulama: partnerin **Flutter'lı makinesinde** `.g.dart` codegen + `flutter analyze` + `flutter test` (bu makinede Flutter yok). Yeşilse Faz 4 kapanır.
- **[Faz 4]** `dev→main` PR (#11) merge kararı insanda.
- **[Faz 5]** iyzico **üretim** hesabı + API anahtarları (geliştirme sandbox anahtarlarıyla yürür); site domain TLS; e-arşiv fatura sağlayıcı entegrasyon bilgileri. **⚠️ GÜVENLİK:** anahtar entegre edilirken `IyzicoPaymentGateway::verify()` MUTLAKA iyzico'ya sunucu-sunucu geri-sorgu + IYZWSv2 imza doğrulaması yapmalı (kod fail-closed kuruldu; smoke-test YETMEZ — gövde-güven = bedava abonelik açığı). Sandbox'ta forged-body reddi + gerçek retrieve sınanmalı.
- **[Faz 5c ortam]** `sipario_panel` DB rolü küme düzeyinde ELLE kuruldu (mevcut container); **CI/yeni makinede rol SQL'i elle koşulmalı** (Faz 1 sipario_app deseni). `.env`/`.env.example`'a `DB_PANEL_USERNAME=sipario_panel` + `DB_PANEL_PASSWORD=...` eklenmeli (config default'u var, testler yeşil; araç `.env*`'i koruyor).
- **[GÜNCELLEME — TEK SEFERLİK ELLE KURULUM GEREKİYOR]** Güncelleme bandı bağlanmamıştı (2026-07-28 bulgusu, düzeltildi). Ama düzeltme KENDİNİ TAŞIYAMAZ: telefondaki mevcut uygulamada bant kodu ağaçta olmadığı için hiçbir release ona bant gösteremez. **Bir kez elle** yeni CI APK'sını (`saha` release'indeki `saha-arm64.apk`) kurmak gerekiyor; ondan sonrası kendiliğinden yürür. Not: imza uyuşmazlığı çıkarsa (cihazdaki uygulama elle/debug imzalı kurulduysa) tek seferlik sil + kur — veri sunucudan geri gelir.
- **[KONUM — anahtar SENDE]** Yandex Geocoder anahtarı alındı (2026-07-28). Sunucuda `.env`'e eklenmeli: `GEOCODING_DRIVER=yandex` + `YANDEX_GEOCODER_KEY=<anahtar>`. Araç `.env*`'i koruduğu için ben yazamadım; `config/geocoding.php` varsayılanları hazır, anahtarsız kurulumda `NullGeocoder` bağlanır ve uç nokta dürüst bir "bu kurulumda tanımlı değil" der (dış çağrı YAPMAZ, testler yeşil). Google anahtarı gelince tek satır: `GEOCODING_DRIVER=google` + `GOOGLE_GEOCODER_KEY=...` — kod değişmez, mobil güncelleme gerekmez. İsteğe bağlı ayarlar: `GEOCODING_DAILY_LIMIT` (kiracı başına gün, vars. 300), `GEOCODING_CACHE_DAYS` (vars. 30), `YANDEX_GEOCODER_URL` (eski anahtarlar `.../1.x/` isteyebilir; varsayılan `/v1/`).
- **[KONUM — KVKK]** Adres metni artık sınır dışına (Yandex) çıkıyor. Ad/telefon/müşteri kimliği ÇIKMIYOR (uç nokta kabul etmiyor, testle kilitli) ama **KVKK aydınlatma metnine "adres bilgisi coğrafi kodlama amacıyla yurt dışı sağlayıcıya aktarılır" satırı eklenmeli** — zaten bekleyen avukat işinin kapsamına giriyor.
- **[Faz 6 · GERİ ALINACAK BORÇ]** **Demo hesabın giriş bilgileri GEÇİCİ olarak kısaltıldı** (2026-07-29, kullanıcı isteği: saha testinde giriş kolaylaşsın): `demo/demo/demo1234` → **`111/111/1111`**. Mağaza başvurusundan ÖNCE güçlü bir değere döndürülmeli — depo public, pilot sunucusu tünelle dışarı açık ve `1111` parolalı bir hesap incelemeden geçse bile üçüncü kişilere kapı bırakır. Değiştirme noktası TEK yerdedir: `DemoSeeder::DEMO_TENANT_CODE / DEMO_USERNAME / DEMO_PASSWORD`; `docs/magaza/inceleme-notlari.md` ve `scripts/saha-sunucu.ps1` oradan güncellenir. NOT: `1/1/1` YAPILAMADI — sunucu ve mobil doğrulaması firma kodu/kullanıcı adı için en az 3, parola için en az 4 karakter istiyor; kuralı gevşetmek kimlik kurallarında kalıcı bir delik açardı.
- **[Faz 6]** Apple + Google Play geliştirici hesapları + mağaza başvurusu; `USE_FULL_SCREEN_INTENT` "çekirdek işlev" beyanı; KVKK aydınlatma + mesafeli satış/ön bilgilendirme metinlerinin **hukukça onayı**.
- **[Faz 7]** Antalya'da 2–3 gerçek bayi + gerçek Android cihazlar (pilot).

## Fazlar

| Faz | Kapsam | Durum |
|-----|--------|-------|
| 0 | Arayan tanıma kanıtı (gerçek cihazlarda go/no-go) | ✅ **KAPANDI — GO (şartlı)**, 2026-07-10 |
| 1 | Temel: Laravel API, Postgres+RLS, auth, izolasyon test matrisi | ✅ **KAPANDI** (güvenlik denetimi dahil, 2026-07-13) |
| 2 | Offline çekirdek: SQLite/Drift, outbox, senkron motoru, müşteri+sipariş | ✅ **ÇEKİRDEK KAPANDI — test + inceleme yeşil** (2026-07-13) |
| 3 | Defter: veresiye, kasa, ödeme tipleri, kupon, gün sonu | ✅ **KAPANDI — test + inceleme yeşil** (2026-07-14) |
| 4 | Kurye: atama, teslim kapatma, kasa devri (+iOS başlangıcı) | 🔄 **~%92** (API ✅ inceleme ✅ mobil test ✅ 2026-07-17; iOS/gerçek-cihaz açık) |
| 5 | Para: site, iyzico, abonelik kilidi, yönetim paneli | 🔄 **KOD TAM** (sunucu ✅ inceleme ✅ güvenlik ✅ 163/163); dışsal: iyzico anahtar/hukuk prose/mobil |
| 6 | Mağaza+hukuk: Play beyanları, demo hesap, KVKK/mesafeli satış | bekliyor |
| 7 | Antalya pilotu: 2–3 gerçek bayi | bekliyor |

## Güncel durum (son güncelleme: 2026-07-28 — **KONUM ALTYAPISI KURULDU**: adresten koordinat (Yandex Geocoder, sağlayıcı soyut — Google tek env satırı) + cihaz konumuyla "Konum Güncelle"; yer tutucu `adresAdaylari()` kaldırıldı. Öncesinde: tam otomatik saha dağıtımı yayında (GitHub Actions her dev push'unda APK derleyip `saha` release'ini günceller, uygulama kendini günceller), çağrı kartı+bildirim, otomatik versiyonlama 0.9.0+git sayacı. Ölçüm: `flutter analyze` 0 · `flutter test` **653/653** · `php artisan test` **237/237** · phpstan L6 **0** · release APK (saha+magaza) derlendi, izin denetimi temiz)

### Konum özelliği — ne kuruldu (2026-07-28)

**İki ayrı yol, karıştırılmamalı:**

| Eylem | Nereden | Ne yapar |
|-------|---------|----------|
| **"Konum Al"** (konum yokken) | `POST /api/v1/geocode` → Yandex | Adres metninden ADAY listesi; doğrusunu KULLANICI seçer, otomatik atanmaz |
| **"Konum Güncelle"** (konum varken çipe dokun) | cihaz GPS'i (`geolocator`) | Bulunulan noktayı yazar; adres metni/bölge/etiket DEĞİŞMEZ |

- **Anahtar yalnız sunucuda.** İstemci sağlayıcıya hiç gitmez; APK'ya gömülen anahtar ilk kurulumda çıkarılır ve kota yakılırdı.
- **Sağlayıcı soyut** (`App\Support\Geocoding\Geocoder`): `YandexGeocoder` · `GoogleGeocoder` · `NullGeocoder`. Geçiş = bir env satırı, uygulama güncellemesi değil.
- **Önbellek global, 30 gün**: aynı mahalle ikinci kez sorulmaz; bir bayinin sorgusu diğerine bedava gelir (dönen veri kamuya açık coğrafi veridir, kiracı verisi değil).
- **Kota kiracı başına**: dakikada 20, günde 300 (env). Bozuk bir istemci döngüsü yalnız kendi bayisini etkiler.
- **Dikişler test edilebilir**: `adresAdaylariGetir` (ağ) ve `cihazKonumuOku` (GPS) — widget testleri platform kanalına/ağa hiç uzanmaz.
- **Açık iş**: rota/sıralama için ayrı bir API kullanılacak (kullanıcı kararı); şu an `RouteOrderer` kendi en-yakın-komşusuyla çalışıyor ve dokunulmadı.

### ⚡ SAHA DAĞITIMI — YENİ ÇALIŞMA BİÇİMİ (2026-07-28)
- **APK artık ELLE DAĞITILMAZ.** dev'e push → CI derler → `saha` release'i güncellenir →
  bayinin uygulaması açılışta görür, kendini günceller. Kalıcı indirme adresi:
  `https://github.com/tnyligokhan/sipario/releases/download/saha/saha-arm64.apk`
- **İlk kurulum CI APK'sıyla yapılmalı** (imza değişti — elle derlenen debug APK'ların üstüne
  CI güncellemesi kurulamaz; cihazdaki eski kurulum BİR KEZ silinip bu adresten kurulur).
- **Derleme komutlarına HER ZAMAN `--flavor saha` ya da `--flavor magaza` verilir** —
  flavor'sız `flutter build apk` içeriği belirsiz APK üretir (ayrıntı DECISIONS'ta).
- İmza anahtarı: `~/.sipario-anahtar/` (depo DIŞI — depo public) + GitHub secrets.
- Play Store'a çıkarken: `magaza` flavor'ı kullanılır, güncelleme kodu orada zaten ölü,
  `check_permissions.sh` kurulum izninin magaza APK'sına sızmasını kırmızıyla engeller.

---

# 🔻 VARDİYA DEVİR NOTU — ÖNCE BUNU OKU (2026-07-27 kapandı)

**Bir cümlede:** Bayinin saha testinden **iki tur geri bildirim** geldi, **10 maddenin tamamı
kapatıldı**; en kritiği kozmetik sanılan ama veri güvenilirliğini vuran **senkron kilidiydi**
(uygulama çevrimiçiyken "çevrim dışı" diyor, yalnız kapatıp açınca senkronize oluyordu). Ayrıca
**testlerin yıllardır şansla gizlediği bir ürün hatası** (UUIDv7 monotonluğu) ve **üç gizli
yerleşim taşması** bulundu. Kritik yol hâlâ kodda değil, **proje sahibinin elindeki dışsal
girdilerde** (anahtar, hesap, avukat, saha) — önceki vardiyanın 🔴 işleri aynen duruyor,
üzerine **KVKK aydınlatma metni** borcu eklendi (sesli giriş).

**Ölçüm (2026-07-27 kapanışı):** `flutter analyze` **0** · `flutter test` **500/500**
(vardiya başında 455) · release APK derlendi · Kotlin `:app:compileDebugKotlin` BUILD SUCCESSFUL.
**HİÇBİRİ CİHAZDA DENENMEDİ** — saha kontrol listesi aşağıda.
**API bu vardiyada HİÇ DEĞİŞMEDİ** ve değişmesi de gerekmedi — kısmi ödeme sunucu tarafında
zaten geçerli: `ChangeApplier::validateLedgerEntry` yalnız işaret + `payment_type` enum'u
denetliyor, bakiye filtresiz `SUM(amount_kurus)`. Son yeşil API koşumu 2026-07-26/3.

## Bu vardiyada NE YAPILDI

Bayi geri bildirimi, üç paralel ajanla (çağrı · liste · ödeme) kapatıldı. Gerekçeler
`DECISIONS.md`'nin sonundaki 13 satırda.

1. **Giden çağrılar gelen görünüyordu** — yön DOĞRU tespit ediliyordu ama hiçbir yüzeye
   ulaşmıyordu: kart üst şeridi `"GELEN ÇAĞRI"`yı SABİT yazıyordu, yeniden gösterim yolları
   yönü `"in"`e çiviliyordu. Yön tek tiple (`CagriYonu`) karta+bildirime+ölçüme+günlüğe taşındı;
   cevapsız çağrı kavramı eklendi (yeni satır değil, aynı çağrının güncellenmesi).
2. **CallerId'de son sipariş durumu yoktu** — `CustomerLookup` sipariş bilgisini hiç çekmiyordu.
   Tek satırlık sorgu eklendi; kartta "Son sipariş: Yolda · 10:24". Kalem dökümü bilerek yok
   (indeks yok, 1 sn bütçesi kaldırmaz).
3. **Ara/WhatsApp/Konum düğmeleri işlevsizdi** — bozuk değil, HİÇ BAĞLANMAMIŞTI (üçü de yalnız
   toast basıyordu). `url_launcher` ile gerçekten açılıyor; numara `+90`'a çevriliyor
   (`wa.me/0532…` sessizce boş sayfa açıyordu).
4. **Sürükleme tutamağı sola sabitti** — varsayılan SAĞ oldu, sol el için anahtar bandın içine
   kondu, tercih cihaz-yerel dosyada KALICI (şema değişikliği yok).
5. **Borçlu sekmesi teslim edilmemiş siparişi gösteriyordu** — sorgunun tek şartı bakiyeydi,
   sipariş durumuna hiç bakmıyordu. Ölçüt artık teslim + defter (ödeme TİPİNE bakılmaz).
   Ayrıca **borç tahsilatı eklendi**: `borcTahsilatiAc` + sipariş detayında "Tahsilat Al".
6. **Kurye süzgeci yoktu** — iki katmanlı eksikti: `watchOrders`'ın `assignedTo` parametresi
   gövdede HİÇ KULLANILMIYORDU ve ekran ona kullanıcı kimliği geçip süzdüğünü SANIYORDU.
   Süzgeç yalnız patrona görünür; patron listede ada göre, ayrıcalıksız durur.
7. **Teslimde kısmi ödeme yapılamıyordu** — tutar düzenlenebilir oldu; kalan fark AYRI KAYIT
   DEĞİL, ödenmemiş `debit`in kendisi. Yeni `entry_type`/olay/migration gerekmedi, uuid5 teslim
   idempotensi korundu. Fazla tahsilat KABUL edilir (kasa devri tutsun diye).
8. **(Plan dışı, bulundu) `newId()` aynı ms içinde MONOTON DEĞİLDİ** — `uuid` paketi zaman
   damgasından sonraki 74 biti tamamen rastgele dolduruyor; ölçüldü: aynı ms'e düşen çiftlerin
   **%50,5'i ters**. Sipariş kalemleri iki cihazda farklı sırada çizilebiliyordu. RFC 9562
   "monotonic random" ile düzeltildi; 100.000 id'de 0 bozulma.
9. **Para alanları kuruşa açıldı** — teslim tahsilatı · borç tahsilatı · bakiye düzeltme ·
   serbest satır (2 yer). "Yarısı" çipi tam lira yuvarlar (kısayol), "Tamamı" çipi kuruşuyla
   doldurur (kesinlik iddiası). `digitsOnly` kalan tek yer barkod alanları — doğru kullanım.

### FAZ 1 YEREL BİLDİRİMLER (aynı gün, kullanıcı onayıyla)

**Push/Firebase YOK** — beş bildirimin hepsi cihazdaki veriden hesaplanıyor, offline-first çizgisiyle
uyumlu ve KVKK açısından sessiz (bildirim cihazdan çıkmıyor). Mimari üç katman: **saf kural**
(veri→taslak, DB yok saat yok) · **üretici** (defteri okur) · **servis** (gösterir/zamanlar).
Kararların tamamı DECISIONS.md'nin sonundaki 12 satırda.

- **Gün sonu özeti** (20:00) — kasaya giren para · teslimat · bugün yazılan veresiye. İlk iki rakam
  gün sonu EKRANIYLA aynı fonksiyonlardan; iki yüzey farklı sayı konuşamaz.
- **Borç eşiği** — VARSAYILAN KAPALI, bayi kendi eşiğini girince açılır (cirosu 2.000 ₺ olanla
  200.000 ₺ olan aynı sınırı kullanamaz). Eşik GEÇİŞİNE bakar, seviyeye değil.
- **Vadesi geçen borçlar** (Pazartesi 10:00) — **FIFO alacak yaşlandırma**: ödemeler en eski borcu
  kapatır. İki basit alternatif de yanlış müşteriyi işaretliyordu.
- **Gecikmiş müşteri** — ritim ORTANCA ile ölçülür (ortalama, tek tatilde kuralı sonsuza dek
  köreltiyor), eşik müşterinin KENDİ değişkenliğine göre, 30 gün tavanlı.
- **Rutin teslim günü** — aynı ritim analizinden; gecikmişle kesişmesi tanım gereği imkânsız.

**Altyapı:** `flutter_local_notifications` + `timezone`; kategori başına kanal; sessiz saat
22:00–08:00 (bildirim ATILMAZ, sabaha ERTELENİR); günlük bütçe (toplam 6 · kategori 2) ve bütçeye
takılan bildirim İZ BIRAKIR; kilit ekranında bildirimler TAMAMEN gizli (ciro dahil — tezgâhta duran
telefonda ciro hedefleme bilgisidir). Kurallar her açılışta anlık koşar (Xiaomi zamanlanmışı
öldürürse yedek); kimlikler gün damgalı olduğu için tekrar güvenli.

**Bu iş üç ayrı doğrulama kapısının birbirinin yerine geçmediğini gösterdi:** `analyze` import
hatasını, `flutter test` bir çalışma-zamanı çökmesini (platform eklentisi yokken ayarlar ekranının
tamamı düşüyordu — iOS'ta da düşerdi), `build apk --release` ise **desugaring eksiğini** yakaladı.
622 test yeşilken release derlemesi düşüyordu; APK her tur derlenmeseydi Faz 1 "bitti" sanılacaktı.

**Sürpriz kazanç:** APK derlenebildiği için DECISIONS'ta "tam mobil CI ile gelecek" diye askıda
duran **birleştirilmiş manifest izin denetimi ilk kez koşuldu** — izinler kaynaktan değil
`aapt2 dump badging` ile DERLENMİŞ APK'dan okundu. Kırmızı çizgi #6 üründe kanıtlandı: yasaklı
SMS/Call Log grubundan tek izin yok, `SCHEDULE_EXACT_ALARM` da yok.

### İkinci tur geri bildirim (aynı gün, bayi 3 madde daha bildirdi)

10. 🔴 **SENKRON KİLİDİ — bu turun en kritik bulgusu.** Bayi: *"alakasız yerde çevrim dışı diyor,
    kapatıp açınca senkronize ediyor, bu bize büyük sorun yaratır."* Haklıydı. Tek zincir:
    istekte **zaman aşımı yoktu** (`package:http` sonsuz bekler; mobilde yarı-açık TCP olağan) →
    asılı `await`te `finally` hiç çalışmadı → `bool _running` sonsuza dek `true` → 2 dk'lık her
    tur sessizce yutuldu ve **yalan "başarılı"** döndü → gösterge son "başarısız"ta dondu →
    ikisi de bellekte olduğu için yalnız uygulamayı öldürmek kurtardı. Düzeltme: 25 sn zaman
    aşımı + bayrak yerine **turun kendisiyle birleştirme**. İKİNCİ ve bağımsız kilit yolu:
    `on Exception` yakalaması `TypeError`ı (bir `Error`) yutuyordu — bu yol yeniden başlatmayla
    DÜZELMEZ, sunucuya nullable kolon eklendiği gün kalıcı kilit üretirdi. Ayrıca senkron artık
    **üç tetikleyiciyle** açılıyor (zamanlayıcı · öne gelme · ağın geri gelmesi); `connectivity_plus`
    pubspec'te kayıtlıydı ama `lib/` içinde HİÇ kullanılmamıştı. Bant metni de üçe ayrıldı:
    401/403'te artık "çevrimdışı" demiyor, **"oturum doğrulanmadı, yeniden girin"** diyor.
11. **Sesli giriş eklendi** (`speech_to_text`) — ad · adres · bölge · not alanlarında mikrofon.
    **TELEFONDA YOK, bilinçli:** Türkçe tanıma rakamları tutarsız döndürür, tek hane kayması
    yanlış numara kaydeder ve o numara **arayan tanımayı kör eder**. Dil daima `tr`; cihazda
    Türkçe yoksa mikrofon pasif + gerekçe. Tanınan metin alanın SONUNA eklenir, ezmez.
12. **Arayan kartına yan boşluk** — kart kendi kenar payını veriyordu ama iki host da onu sessizce
    çöpe atıyordu (`WindowManager.addView` params'ı değiştirir, `setContentView` `MATCH_PARENT`
    dayatır). Boşluk artık PENCEREDEN veriliyor. Daralma **üç gizli taşmayı** açığa çıkardı:
    üst şerit (31px), **bakiye şeridi (106px — 12.345,67 ₺ gibi olağan bir veresiyede tutar
    yarım okunuyordu)** ve kart gövdesi (193px dikey — bayi "Sipariş Oluştur"u hiç göremiyordu).
    Üçü de düzeltildi; "kim feda edilir" kuralı koda yazıldı (saat ikonu gider, yön sözcüğü kalır;
    bakiye etiketi kısalır, tutar tam kalır).

## Bu vardiyada NE YAPILMADI (bilerek ya da bloklu)

- 🔴 **KVKK AYDINLATMA METNİ GÜNCELLENMELİ (proje sahibinde, avukat işi).** Sesli giriş, Android'in
  `SpeechRecognizer`ını kullanır ve cihaza göre tanımayı BULUTTA yapabilir — yani dikte edilen
  müşteri adı/adresi üçüncü tarafın sunucusundan geçebilir. Kırmızı çizgi #4 verinin nerede
  SAKLANDIĞIYLA ilgilidir ve bu bir saklama değildir (Gboard'un sesle yazması zaten aynı yolu
  kullanır, her bayide açıktır) — bu yüzden özellik engellenmedi. Ama metne *"sesli giriş
  kullanıldığında ses verisi cihazın ses tanıma servisine gönderilir"* satırı eklenmeli ve
  **Play Console "Veri güvenliği" formuna ses verisi satırı** girilmeli. `onDevice: true` ile
  zorlamak denenmedi: Türkçe çevrimdışı modeli olmayan telefonlarda özellik hiç çalışmazdı.
- **CİHAZDA HİÇ DENENMEDİ — SAHA KONTROL LİSTESİ.** Hepsi test+derleme düzeyinde doğrulandı.
  Bayinin gözle bakması gerekenler:
  1. **Senkron:** uçak modunu aç→kapat, bant ANINDA kalkmalı (ağ tetiği). Asıl senaryo: wifi↔mobil
     veri geçişinde ya da captive portal'lı AVM wifi'sinde tur ortasını yakala — eskiden kalıcı
     kilitleniyordu, şimdi 25 sn'de toparlamalı. Token'ı iptal et → bant "çevrimdışı" DEĞİL
     "oturum doğrulanmadı" demeli.
  2. **Çağrı kartı:** giden/cevapsız çağrıda başlık doğru mu (OEM'in `callDirection`'ı yanlışsa
     logcat'te `onScreenCall: yon=<ham sayı>` tek çağrıda kanıtlar, düzeltme tek satır);
     iki yanında boşluk var mı (kilitli VE kilitsiz); yan boşluğa dokununca kart KAPANMAMALI;
     dört haneli borçlu müşteride (12.345,67 ₺) tutar tam okunuyor mu; yazı tipi "en büyük"te
     üst şeritte önce saat ikonu kaybolmalı, yön sözcüğü tam kalmalı.
  3. **Sesli giriş:** izin diyaloğu çıkıyor mu, reddedilince mikrofon soluk mu; `tr` yereli
     cihazda var mı; uçak modunda "internet gerekiyor" mu diyor yoksa cihaz-içi model mi devrede.
     **En olası saha hatası:** `<queries>` beyanı işe yaramazsa Android 11+'ta özellik sessizce
     kapanır ve "cihazda ses tanıma yok" der.
  4. **Önceki turdan:** WhatsApp/harita açılışı (MIUI gibi katmanlarda), borçlu sekmesinin
     doğru listelemesi, tutamaç tercihinin uygulama kapanıp açılınca korunması.
- **`orders.customer_id` indeksi eklenmedi** — hem native hem Dart son-sipariş sorgusu tam tablo
  taraması. Yılda ~18k satırda birkaç ms, ama sınırsız büyür. Şema sürümü + migration gerektirdiği
  için saha testi sürerken alınmadı. `order_lines.order_id` indeksi de eklenirse native kart
  kalem dökümünü taşıyabilir.
- **Kotlin birim test altyapısı yok** (`build.gradle.kts`'te test kaynak kümesi + JUnit yok).
  `cagriYonuBelirle` ve kart yardımcıları saf fonksiyon olarak ayrıldı ama testleri yazılamadı.
  **Bunun bedeli bu vardiyada görüldü:** kart kenar boşluğunun asıl bozuk olduğu iki yüzey
  (overlay + kilit ekranı Activity'si) NATIVE olduğu için testle kilitlenemedi; yalnız üçüncü
  yüzey (Flutter kartı) kilitlendi.
- **Native arayan kartında DİKEY KAYDIRMA yok** — Flutter kartına eklendi, native'e bilerek
  eklenmedi: `ScrollView` kartın "dokununca kapan" listener'ı ve pencere boyutlandırmasıyla
  etkileşiyor, cihazsız doğrulanamaz. Risk aynen duruyor: çok uzun adres + uzun notta native
  kartın eylem düğmeleri ekran dışında kalabilir. Sahada görülürse öncelik kazanır.
- **`letterSpacing` em/px karışıklığı — TİPOGRAFİ DENETİMİ gerekiyor.** `SipText.cagriCanli`
  `0.12` alıyor ama tasarım `.12em` diyor; Flutter'da bu alan **em değil logical pixel**, yani
  1,32px olması gereken aralık 0,12px çiziliyor ve etiket tasarımdakinden dar duruyor. Aynı hata
  `typography.dart`taki başka `ls:` değerlerinde de olabilir — tek satırlık düzeltme değil,
  baştan sona kontrol işi. Şimdi düzeltmek kart taşmaları için açılan payı geri kapatır.
- **`SipIcons.mic` yok** — mikrofon path'i geçici olarak `customer_widgets.dart` içinde
  `kMikrofonIkonu` sabiti. `theme/icons.dart`a taşınmalı.
- **FAZ 1 BİLDİRİM BORÇLARI** (hiçbiri Faz 1'i bloklamıyor):
  · **Ana ekran, gecikmiş müşteri / rutin teslim listesini bildirimden BAĞIMSIZ göstermeli** —
    Xiaomi zamanlanmışı öldürürse bilgi yine görünsün. `gecikmisMusteriler()` ve
    `rutinGunuGelenler()` bunun için public bırakıldı; ana ekran bağlantısı yazılmadı.
  · **Çok-müşterili bildirimlerde `yol` null** — gecikmiş/borçlu liste rotası Faz 1 sözlüğünde yok,
    uydurulmadı. Rota eklenince tek satır değişir (Faz 2).
  · **Desugaring + `androidx.window` cihazda DOĞRULANMADI.** `androidx.window` savunma amaçlı açıkça
    eklendi ama ölçüldü: Flutter zaten 1.2.0'ı getiriyormuş, APK **0 bayt** büyümedi. Yani bu bir
    sigorta DEĞİL, örtük bağımlılığın açık hâle getirilmesi. Cihazda açılışta çökme olursa sebep
    başka yerde aranmalı.
  · **Bildirim üreticileri her açılışta ayrı sorgu koşar** (paylaşılan önbellek YOK — bilinçli:
    önbellek arka plandan dönüşte bayat kalır ve "zaten sipariş vermiş müşteriye gecikti demek"
    kuralın tek kırmızı çizgisine çarpar). Ölçülebilir maliyet çıkarsa tek turluk paylaşım ~10 satır.
  · **Eşik sabitleri SAHA VERİSİYLE DOĞRULANMADI** (4 teslimat · 0,4 taban · 30 gün tavan · MAD
    yarısı). Hepsi tek yerde adlandırılmış sabitler. **Pilotun ilk haftasında "bu bildirim doğru
    muydu" geri bildirimi toplanmalı.**
  · Defterin tarih/aggregate süzgeci SQL'e taşınmalı — `gunSonuBildirimVerisi` ve
    `bugunEsigiAsanlar` tüm defteri okuyup Dart'ta süzüyor (mevcut `kasaOzeti` deseni). Yıllara
    yayılınca yavaşlar.
- **Arayan kartı için `max-width` TASARIMDA TANIMSIZ** — tablet/yatay ekranda kart ekran − 32dp
  olacak, yani çok geniş. Ölçü kaynaktan çıkarılamadığı için uydurulmadı (depo kuralı); tasarım
  güncellenince ÜÇ yüzeye birden konmalı.
- **`home_shell.dart` 581 satır** (500 sınırı). Sınırı bu vardiyadan ÖNCE aşmıştı (HEAD'de 560);
  saha testi sürerken kabuk dosyasını parçalamak karşılıksız gerileme riski olduğu için ertelendi.
- **Emanet/boş damacana takibi KARARI HÂLÂ BEKLİYOR** — üç seçenek sunuldu, cevap gelmedi.
  Karar verilmeden koda dokunma. Ayrıntı: iş #6.
- **`YAPILACAKLAR.md` bayat** (2026-07-16). **Çelişki halinde BU BÖLÜM doğrudur.**
- **`test/ui_dilim3_test.dart` 608 satır** — depo kuralı 500. Ortak alan, sahibi belirsiz.
- **Tasarım tarafında 3 sınıfın CSS kuralı yok** (`balrozet*`, `mrow-tag`, `ara-ic`).
- **APK:** release fat APK **73,7 MB**, bayinin kuracağı arm64 sürümü **27,9 MB**.

---

# SIRADAKİ İŞLER — önem sırasına göre, adım adım

> **Okuma kılavuzu:** Her iş için **NEDEN** (neyi bloklar), **KİMDE** (sen mi Claude mı),
> **ADIMLAR**, **BİTTİ SAYILIR** ve **KANIT** (koddaki yeri) var. 🔴 = bu olmadan ürün satılamaz.
>
> **Acı gerçek:** 🔴 işlerin 4'ü de proje sahibinde. Claude'un tek başına ilerletebileceği en
> değerli iş **#5 (mobil CI)** ve **#4'ün kod ayağı**. Sıradaki vardiya boş kalmasın diye
> önce onlara bak.

## 🔴 1. iyzico sandbox anahtarı → ödeme akışını canlıya bağla

**NEDEN:** Faz 5'in kodu TAM ama **gerçek iyzico ile hiç konuşmadı**. Anahtar olmadan tek kuruş
tahsilat yapılamaz; abonelik iş modelinin tamamı buna bağlı. Bu, tüm listenin en pahalı beklemesi.

**KİMDE:** Anahtar üretimi **sende**; entegrasyon ve güvenlik testi **Claude'da**.

**ADIMLAR:**
1. iyzico'da **sandbox** hesabı aç (üretim değil — önce sandbox).
2. `IYZICO_API_KEY` + `IYZICO_SECRET_KEY`'i Claude'a ver → `.env`'e girer.
3. Claude sandbox'ta ödeme akışını uçtan uca koşar.
4. **⚠️ PAZARLIKSIZ GÜVENLİK TESTİ** — smoke-test YETMEZ, üçü de ayrı ayrı sınanmalı:
   - **(a) forged-body reddi:** sahte `paymentStatus: success` gövdesi gönderildiğinde abonelik
     AÇILMAMALI. Açılırsa bedava abonelik açığı demektir.
   - **(b) gerçek `retrieve` geri-sorgusu:** karar iyzico'ya sunucu-sunucu sorulup verilmeli.
   - **(c) IYZWSv2 imza doğrulaması.**
5. Sandbox yeşilse **üretim** anahtarlarını al, aynı üç testi üretimde tekrarla.

**BİTTİ SAYILIR:** Sandbox'ta sahte gövde reddedildi + gerçek ödeme aboneliği açtı + üretim
anahtarları `.env`'de.

**KANIT:** `apps/api/config/subscription.php:38-40` · `apps/api/app/Payment/IyzicoPaymentGateway.php`

## 🔴 2. Android release imza anahtarı (keystore)

**NEDEN:** `release` derleme **hâlâ debug anahtarıyla imzalanıyor**. Debug imzalı paket Play'e
**yüklenemez** — mağaza başvurusu bu satır yüzünden ilk adımda durur. Yapılması yarım saat,
yapılmaması her şeyi bloklar. **Ucuz ve kritik: sıradaki vardiyada ilk bunu iste.**

**KİMDE:** Anahtar üretimi ve saklanması **sende** (Claude anahtar üretemez/saklayamaz);
gradle'a bağlama **Claude'da**.

**ADIMLAR:**
1. Play Console'da **Play App Signing**'e kaydol.
2. `keytool -genkeypair -v -keystore sipario-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
3. **Parolayı ve .jks dosyasını güvenli sakla.** Kaybolursa uygulama bir daha GÜNCELLENEMEZ —
   yeni paket adıyla sıfırdan yayımlamak gerekir, mevcut kullanıcılar güncelleme alamaz.
4. `key.properties` dosyasını Claude'a tarif et (yolu + alias) → gradle'a bağlar.
   **`.jks` ve parolalar ASLA depoya girmez** (kırmızı çizgi: sır commit edilmez).
5. `flutter build appbundle --release` ile imzanın gerçekten değiştiğini doğrula.

**BİTTİ SAYILIR:** `build.gradle.kts:35`'teki `signingConfigs.getByName("debug")` gitti,
release AAB kendi anahtarıyla imzalı.

**KANIT:** `apps/mobile/android/app/build.gradle.kts:32-36` (`// TODO: Faz 6'da kendi imza anahtarımız`)

## 🔴 3. Apple D-U-N-S + mağaza geliştirici hesapları

**NEDEN:** Mağaza başvurusunun ön koşulu. **Apple kurumsal hesap D-U-N-S numarası ister ve
D-U-N-S başvurusu HAFTALAR sürebilir.** Bu yüzden listede yukarıda: yapacak bir şey yokken bile
saat işliyor. Bugün başlatılmazsa iOS çıkışı haftalarca gecikir.

**KİMDE:** Tamamen **sende** (tüzel kişilik gerektirir).

**ADIMLAR:**
1. **D-U-N-S başvurusunu BUGÜN yap** — ücretsiz, sonucu beklerken diğer işler yürür.
2. Google Play Console kurumsal hesabı aç (tek seferlik ücret).
3. Apple Developer Program kaydı (D-U-N-S gelince).
4. Hesaplar açılınca `docs/magaza/` altındaki başvuru paketi Claude tarafından doldurulur.

**BİTTİ SAYILIR:** İki konsola da giriş yapılabiliyor.

## 🔴 4. Arayan tanıma 20/20 ölçümü — ve önündeki `kDebugMode` KAPISI

**NEDEN:** BRIEF'in **1 numaralı korkusu** ve Faz 0 "**şartlı** GO" ile kapandı — şart tam olarak
buydu: *20/20 aramada ≤1 sn*. Bu ölçüm hâlâ yapılmadı. Ürünün varlık sebebi doğrulanmamış durumda.

**KİMDE:** Ölçüm **sende** (gerçek cihaz, gerçek arama); önündeki kod engelini kaldırmak **Claude'da**.

**⚠️ SIRADAKİ CLAUDE'A NOT — bu tuzağı kimse fark etmemiş:**
Ölçüm ekranına giden Ayarlar satırı `kDebugMode` ile sarılı
(`ayarlar_ekrani.dart:266`). Yani **release derlemede o satır hiç çizilmez** ve pilottaki bayi
ölçümü başlatamaz. Pilottan ÖNCE bir karar gerekli:
- (a) pilota debug/profile derleme ver (en kolay, ama pilot gerçek dağıtımı temsil etmez), ya da
- (b) satırı gizli bir kapıya bağla (ör. Ayarlar'da sürüm numarasına 7 kez dokunma — Android'in
  kendi deseni), böylece esnafın menüsü temiz kalır ama ölçüm sahada erişilebilir olur.
**Öneri: (b).** Kararı verip uygula, DECISIONS'a yaz.

**ADIMLAR:**
1. Yukarıdaki kapı kararını uygula (Claude).
2. Pilot bayiye kurulum yap; **Xiaomi'li bayide MIUI izinlerini BİRLİKTE kur** — programla
   verilemiyor, uzaktan tarif etmek işe yaramıyor.
3. İlk hafta **20 gerçek arama** boyunca ölçüm ekranını çalıştır.
4. Sonuç ≤1 sn / 20 arama ise Faz 0'ın şartı düşer ve **GO kesinleşir**; değilse durup nedenini
   ara (pil yönetimi mi, tam ekran niyet izni mi, OEM kabuğu mu).

**BİTTİ SAYILIR:** 20 ölçüm kaydı + karar (`DECISIONS.md`'ye tek satır).

**KANIT:** `lib/phase0/phase0_screen.dart` · `lib/screens/isletme/ayarlar_ekrani.dart:266` ·
`lib/screens/home_shell.dart:252`

## 🟡 5. Mobil CI — Claude'un TEK BAŞINA yapabileceği en değerli iş

**NEDEN:** Ürünün ağırlık merkezi artık mobil (378 test), ama CI'da **yalnız API ve manifest
denetimi** koşuyor. `flutter test` / `dart analyze` **sadece geliştiricinin makinesinde** çalışıyor —
yani iki geliştirici nöbetleşe çalışırken hiçbir otomatik bekçi yok. Ayrıca kırmızı çizgi #6'nın
(Play izin yasağı) son katmanı olan **birleştirilmiş manifest denetimi** gradle build istediği
için hâlâ kurulamadı; mobil CI gelince o da bağlanır.

**KİMDE:** Tamamen **Claude'da** — dışsal girdi istemez.

**ADIMLAR:**
1. `.github/workflows/mobile-ci.yml` ekle: `subosito/flutter-action` + `flutter pub get` +
   `dart analyze --fatal-infos` + `flutter test`.
2. `dart run build_runner build --force-jit` adımını ekle — `.g.dart` bayatlarsa CI yakalasın
   (**`--force-jit` şart**: düz `build` "dart compile does not support build hooks" ile düşer).
3. `scripts/check_permissions.sh`'i **birleştirilmiş** manifest üzerinde koştur (gradle
   `assembleDebug` sonrası) → kırmızı çizgi #6 tam otomatik korunur.
4. PR'larda zorunlu kıl.

**BİTTİ SAYILIR:** Bir PR açıldığında mobil testler yeşil/kırmızı raporluyor.

**KANIT:** `.github/workflows/` (yalnız `api-ci.yml`, `manifest-lint.yml`) ·
`scripts/check_permissions.sh`

## 🟡 6. Emanet / boş damacana takibi — KARAR BEKLİYOR, kod yazma

**NEDEN:** BRIEF'in maddesi. Sunucuda `tenants.modules` bayrağı var, panelde düğmesi var,
senkron yanıtına konuyor (`SyncService.php:342`) — **ama mobil istemci o alanı okumuyor bile**
(`sync_api.dart`'ta `modules` alanı YOK) ve açılacak bir özellik yok. **Düğme boşluğa basıyor.**

**NE DEMEK:** Bayinin iki defteri olur — biri **para** (veresiye, ✅ var), biri **adet** (müşterinin
üstündeki boş kap, ❌ yok). "Ayşe Hanım'ın 3 boş damacanası var" cümlesi para defterine yazılamaz.

**KİMDE:** **Karar sende.** Bayiye üç seçenek sunuldu, cevap gelmedi:
- **(a) Tam yap:** yeni tablo + senkron tipi + teslimde "kaç boş alındı" alanı + müşteri kartında
  "Emanet: N kap" satırı + gün sonunda kurye sayımı. Append-only kuralı burada da geçerli.
- **(b) Basit sayaç:** yalnız müşteri kartında elle düzeltilebilen bir sayı; teslim akışına dokunma.
- **(c) v1'den çıkar:** `BRIEF.md`'ye kupon gibi "KALDIRILDI" notu düş, pilotta bayilere sor.

**Claude'un önerisi (c) idi** — hangi bayinin gerçekten istediği bilinmiyor; pilotta sorup öğrenmek
tahminle yazmaktan ucuz. **Karar gelmeden koda dokunma.**

## 🟡 7. Hukuk metinlerinin avukat onayı

**KİMDE:** **Sende.** 4 belge + hesap-silme sayfası TASLAK.
**Doldurulacak:** şirket unvanı, açık adres, MERSİS no, telefon, e-posta, KEP, KDV oranı, yetkili
mahkeme, iade/iptal süreleri, saklama süreleri, alt-yüklenici aktarım listesi.
**Avukatın KARARA BAĞLAMASI gerekenler** (her belgede `<!-- HUKUK NOTU -->` olarak işaretli):
B2B/tacir muhatapta cayma hakkı istisnası (m.15/1-ğ) ve 30 gün deneme ilişkisi; pazarlama açık
rızasının gerekip gerekmediği.
**KANIT:** `apps/api/resources/views/legal/docs/*.blade.php`

## 🟢 8–12. Kalanlar (kısa)

- **e-arşiv fatura:** BRIEF yasal gereklilik sayıyor, kodda **sıfır**. Entegratör seçimi sende,
  bağlama Claude'da. (`mesafeli-satis.blade.php:22` "fatura elektronik iletilir" diyor.)
- **iOS:** `apps/mobile/ios/` iskeleti hiç derlenmedi. **Mac + Xcode gerekli** — ekipte kimde
  olduğu belirsiz, netleştir.
- **Mağaza görselleri + arayan-tanıma tanıtım videosu:** BRIEF mağaza incelemesi için zorunlu
  sayıyor, hiç üretilmedi. Video demo hesapla çekilecek (kilitli + kilitsiz ekran).
- **Transactional e-posta:** `MAIL_MAILER=log`. Panel şifre sıfırlamada yeni şifreyi ekranda
  gösteriyor, kimseye göndermiyor.
- **Prod ortam:** TR VPS + Docker + `sipario.com.tr` TLS + `CORS_ALLOWED_ORIGINS` (boşsa tarayıcı
  reddedilir) + `sipario_panel` DB rolünün elle kurulması (docker init yalnız ilk initdb'de çalışır).
- **Küçükler:** PR #11 merge · VERBİS değerlendirmesi · marka başvurusu takibi ·
  Drift `journal_mode=TRUNCATE` gerçek cihazda doğrulanmadı · stok Android hiç denenmedi ·
  `ui_dilim3_test.dart` 608 satır (sınır 500).

---

### VARDİYA 2026-07-26/4 — EK: BARKOD OKUYUCU (kamera)

**İstek (kullanıcı):** "Yeni Ürün Ekle ve POS tarafındaki barkod ikonuna tıklandığı gibi barkod
okuyucu açılsın ve okuduğu barkodu direkt inputa yazsın! İkinci bir alanın açılmasına gerek yok."

**Önceki hâl:** iki yerde de kamera YOKTU. İkon, kesik çerçeveli bir kutu + elle giriş alanı +
kayıtlı barkod listesi içeren bir ara sheet açıyordu (`barkod_okut_sheet.dart`,
`barcode_sheet.dart`). Yani "barkod okuyucu" aslında bir yazma formuydu.

**Yapılanlar:**
- `mobile_scanner ^7.4.0` eklendi; `CAMERA` izni + `uses-feature required="false"` manifeste
  girdi. ML Kit modeli pakete gömülü — çalışma anı indirmesi yok, offline-first korundu.
- `lib/screens/barkod/barkod_kamera.dart` (YENİ): iki çağıranın ortak yüzeyi. Tam ekran sheet,
  canlı kamera + nişan çizgisi; kod okunduğunda sayfa kapanır ve kod DÖNER.
- Ürün formu: okunan kod barkod alanına yazılır. POS: okunan kod arama alanına yazılır ve
  süzgeç (`katalogSuz`, ekrandan bağımsız) artık adın yanında BARKODU da tarar — ürün karo
  olarak kalır, dokunuş adet sheet'ini açar.
- Kabul kapısı `barkodKabulEt`: yalnız rakam, en az 8 hane; harfli kodun rakamları AYIKLANMAZ.
  Yalnız perakende biçimleri dinlenir (EAN/UPC/Code128/Code39).
- Kamera yoksa/izin verilmezse okuyucunun İÇİNDE elle giriş çıkar — mutlu yola adım eklemez,
  eski yeteneği de kaybettirmez.
- Eski iki sheet SİLİNDİ. `test/isletme_kurallari_test.dart`e 7 test eklendi (kabul kapısı +
  katalog süzgeci).

**Ölçüm:** `dart analyze` 0 · `flutter test` **377/377** · APK derlendi ve cihaza kuruldu.

### VARDİYA 2026-07-26/4 — ÇAĞRI KARTI EYLEMLERİ (cihaz geri bildirimi)

**Bulgu (bayi, cihazda):** kart düğmeleri hiçbir yere gitmiyor, kayıtsız numarada "Müşteri
Olarak Kaydet" hiçbir şey yapmıyor, native kart eylemden sonra ekranda asılı kalıyor.

**Kök sebep İKİ ayrı yerdeydi — kart kendisi sağlamdı:**
1. **Flutter kartı** — `home_shell._cagriKartiAc` kartı açıp DÖNEN EYLEMİ ATIYORDU. Kartın kendi
   testi ("eylemler doğru geri çağrıyı tetikler") yeşildi; kırık olan tüketen uçtu. Ana ekranın
   "Son Arama" kutusu ve Ayarlar'ın çağrı simülasyonu bu yoldan geçtiği için üç düğme de ölüydü.
2. **Native kart** — `CallerCardViews.eylemiAc` niyet ekstralarını koyuyordu ama `MainActivity`
   onları HİÇ OKUMUYORDU (ölü ekstra), ve kartı kapatan hiçbir çağrı yoktu.

**Yapılanlar:**
- `home_shell`: `_cagriEylemiUygula` — tek gezinme noktası. `siparis` → sekme + `OrderFormScreen`
  (müşteri önceden geçer, seçim adımı sorulmaz) · `defter` → sekme + `CustomerDetailScreen` ·
  `kaydet` → yeni müşteri sheet'i (numara dolu) ve kayıttan sonra YENİ müşterinin defteri
  (tasarım `s-uygulama.jsx:116`). Salt-okunur kipte yazma eylemleri gerekçeli toast'a düşer.
- Ölü uç yok: `defter` isteği kayıtsız numaraya düşerse (kart çizildikten sonra müşteri silinmiş)
  sessiz kalmak yerine kart gösterilir — bayi oradan kaydetmeye geçebilir.
- `lib/screens/cagri/cagri_eylem_kanali.dart` (YENİ): native köprüsünün Dart ucu. Ayrı kanal
  (`sipario/cagri`), ÇEKME modeli, bilinmeyen eylem sessizce düşer, köprü Android dışında kapalı.
- `MainActivity`: `bekleyen` alanı + `bekleyen` metodu + önplan dürtüsü; niyet ekstrası okununca
  hem alandan hem niyetten silinir (Activity yeniden kurulunca eylem tekrarlanmaz).
- `CallerOverlay.kapat` (YENİ): overlay penceresi + kilit ekranı Activity'si + bildirim birlikte
  kaldırılır, `lastPhone` temizlenir (çağrı yanıtlanınca kart geri gelip ekranı örtmesin).
- `ayarlar_ekrani`: Çağrı Geçmişi'nden kaydetme de yeni müşterinin defterine gider.
- `test/ui_cagri_eylem_test.dart` (YENİ, 11 test): üç eylemin hedefi, ölü uç dalı, köprünün
  çözme/tüketme davranışı ve "köprü kapalıyken kanala dokunulmaz" kapısı.

**Ölçüm:** `dart analyze` 0 · `flutter test` **370/370** · APK derlendi ve cihaza kuruldu (SM-S721B).

**Ders:** bir geri-çağrı sözleşmesinin yalnız ÜRETEN ucunu test etmek sözleşmeyi test etmek
değildir. Ayrıca: platform kanalına dokunan kod kanalın olmadığı yerde çağrılmamalı —
`flutter_test` sahtelenmemiş kanala ne yanıt ne hata döner, test 10 dk asılı kaldı.

### VARDİYA 2026-07-26/3 — BÖLÜM A: TASARIM DENETİMİ (11 ajanlı hat: 5 denetim + 6 düzeltme)

**TETİKLEYİCİ:** Kullanıcı "UI'da hâlâ yanlışlıklar ve eksikler var; mesela KUPON yok, o kalktı"
dedi, `Sipario-tek-dosya.html`ı yerel klasöre koydu, "input alanlarının yükseklik sorunu"nu bildirdi
ve işin ajanlarla yürütülmesini istedi.

**KAYNAK:** Tek dosya `get_file`da 256 KB'de KESİLİYOR (gzip+base64 paket). Kullanıcının yerel
kopyası (1,5 MB) `zlib` ile açıldı → **`design_handoff_sipario/_cozulmus/`** (16 JSX + `_sayfa.html`
= tüm CSS). Dosya boyutları `kaynak/` ile birebir aynı: **tasarım DEĞİŞMEMİŞTİ.**

**KÖK BULGU — HATA ANALİZ ÖLÇÜTÜNDEYDİ.** Kupon farkı bir önceki turda GÖRÜLMÜŞ ama "uygulamanın
ekstrası, BRIEF'te kupon var" denip geçilmişti. Doğru ölçüt: **CSS'te sınıf tanımlı ama hiçbir
`s-*.jsx` onu çizmiyorsa özellik KALDIRILMIŞTIR.** Bu ölçütle bulunanlar: `.gs-kupon`, `.md-kupon`,
`.fabpop*`, `.md-bal*`, `.xiaomi-toggle`, `.siz-not`, `.mrow-av`, `.cagri-av`. Denetim üç başlık
verir: EKSİK · **FAZLA (=kaldırılmış)** · YANLIŞ.

**EN AĞIR HATA — KAYITLI ÇAĞRI KARTI HİÇ KURULMUYORDU.** Üç çağrı yerinin ÜÇÜ de
`CagriKisi.kayitsiz` geçiyordu → kart HER ZAMAN "Kayıtsız" çıkıyor; bakiye şeridi, müşteri kodu
rozeti, adres/son sipariş satırları ve "Sipariş Oluştur / Defteri Aç" **ULAŞILAMAZ KODdu.** Ayarlar
"4 varyant" vaat ediyor, tek varyant gösteriyordu. `cagri/cagri_cozumleyici.dart` yazıldı (son-10
hane + `idx_phones_last10`, arşivli müşteri "kayıtsız", deterministik satır seçimi, log YOK/KVKK) ve
üç yer de bağlandı.

**INPUT YÜKSEKLİĞİ — kök sebep ölçülerek bulundu.** `InputDecoration.constraints` DIŞ yuvayı
büyütür, BOYANAN kutuyu büyütmez (`input_decorator.dart:2673-2676` ↔ `:1107-1123`); `isDense: true`
+ `contentPadding.vertical: 0` kutuyu satır yüksekliğine çöktürüyordu → 46 px yuvanın altında
**~26 px ölü boşluk**, 37 çağrı yerinde. `SipInputOlcu` tek ölçü kaynağı kuruldu; yükseklik
dolgudan türetiliyor, satır çarpanı `style` VE `hintStyle`a birlikte veriliyor (yoksa kutu yazmaya
başlayınca zıplar), `visualDensity` sabitlendi (platform varsayılanı masaüstünde 46'yı 44 yapıyordu).

**TASARIMA HİZALANAN DİĞER İŞLER:** FAB açılır menüsü kaldırıldı (tasarımda tek dokunuş; `.fabpop*`
ölü CSS'ti) · sipariş detay sheet'ine başlık + tutamaç + KAPAT düğmesi geri geldi (kullanıcının
sheet'i kapatacak görünür düğmesi yoktu) · geçmiş sipariş satırı artık kalem dökümü +
`saat · ödeme · kurye` (önce tam tersi: saat üstte, NOT altta) · **ayrı Kasa Devri ekranı
kaldırıldı** (tasarımda rota yok; devir Gün Sonu'nun "Hesabı Kapat · Kasa Devri" sheet'inde —
`CashHandoverRepository` ve tablo YERİNDE, kurye kapanışı devri yazmaya devam ediyor, testi eklendi)
· ana ekran hero'sunda SAHİP adı / çekmecede İŞLETME adı · son aktivite satırı sipariş detayını
açıyor ve ürün dökümü yazıyor · ilk girişte kurulum sihirbazı tam ekran (damga cihaz-yerel) ·
müşteri detayı `.md-bal` hero kartından `.md-bakiye` şeridine indi, eylem ızgarası 4→2 · sihirbazın
5 izin gerekçesi birebir (bildirim adımında anlam kaymıştı), Xiaomi adımı ve `sdk>=34` koşulu
kaldırıldı (tasarım 6 SABİT adım) · ürün görseli artık GERÇEK galeri seçicisi (`image_picker`) ·
avatarlar kaldırıldı · muaf/profil/abonelik-kilidi metinleri tasarıma çevrildi · Faz 0 ölçüm
ekranının girişi `kDebugMode` altına alındı (öksüz kalmıştı — "ölü dal" dersi).

**KULLANICI KARARLARI:** tezgâh satışı giriş kapısı ve kuryenin "Benim" sekmesi KALDIRILDI ·
salt-okunur şeritleri ve Çağrı Geçmişi ekranı KALDI · kuryede Gün Sonu yuvası kalır, "Kasa Devri"
satırı yalnız kuryede (tek satır role göre etiketlenir, kopya hedef oluşmaz).

**AJAN HATTI VE ALINAN DERSLER:** 5 salt-okunur denetim ajanı ~90 fark çıkardı; 6 düzeltme ajanı
AYRIK dosya (ve test dosyası) sahipliğiyle uyguladı; `flutter test` YALNIZ lead koştu (eşzamanlı
koşum `sqlite3.dll` yarışıyla aracı çökertiyor). Üç ajan aynı test tuzağına düştü: `LineInput`a
`productId` verilmezse satır `serbestMi` gereği SERBEST sayılır ve `×adet` yazılmaz. Dört test
kırılması ürün kodunda DEĞİL, testin görünür-alan ve akış-bekleme varsayımlarındaydı (bkz.
DECISIONS son iki satır: `SipGovde` bir `ListView`, tembel çizer). Bir denetim ajanının bir bulgusu
kanıtla yanlış çıktı (`.md-kupon` "tasarımda var" demişti) ve düzeltildi; bir düzeltme ajanı lead'in
"düğmeyi hiç çizme" kararını haklı olarak iyileştirdi (yeteneği gizlemek yerine pasif + gerekçe).

**ÖLÇÜMLER:** `dart analyze` 0 (lib+test) · `flutter test` **359/359** · API **220/220** (788
assert) · pint ✓ · phpstan 0 · Drift **v10** · debug APK derlendi.

**AÇIK KALANLAR:** ⚠️ **CİHAZDA GEZİNTİ YAPILMADI** (telefon vardiya boyunca kullanıcıdaydı) —
kayıtlı çağrı kartının 4 varyantı, input yüksekliği ve gün sonunda kurye kapsamı GÖZLE
doğrulanmalı. `test/ui_dilim3_test.dart` 608 satır (ortak alan, bölünmeyi bekliyor). Tasarımda
JSX'in kullandığı ama CSS'te kuralı OLMAYAN üç sınıf var (`balrozet*`, `mrow-tag`, `ara-ic`);
ölçüleri kaynaktan çıkarılamıyor, uygulamada TAHMİNLE duruyor — tasarım tarafının güncellenmesi
istendi.

### VARDİYA 2026-07-26/3 — BÖLÜM B: KUPON KALDIRMA (tasarım kararı, tam silme)

**TETİKLEYİCİ:** Tasarım (claude.ai/design) kuponu üründen çıkardı — hiçbir `s-*.jsx` kupon
çizmiyor, `ODEME_TIPLERI` yalnız nakit/kart/havale/veresiye, CSS'teki `.gs-kupon`/`.md-kupon`
sınıfları yalnız ARTIK olarak duruyor. Kullanıcı TAM SİLME onayı verdi (UI + repo + Drift +
Postgres + sync applier + `orders.payment_type` CHECK'i).

**YAPILAN (gerekçeler DECISIONS son satırında):**
- **Mobil:** `coupon_repository.dart` ve `ledger_coupon_test.dart` SİLİNDİ; `CouponMovements`/
  `CouponBalances` Drift tabloları, `writeCouponMovement`/`recomputeCouponBalance`/
  `watchCouponBalance`/`kuponDurumu`/`kuponBakiyesi`/`kuponAdedi`, kupon sheet'i · bakiye kartı
  çipi · gün-sonu kupon bölümü · teslim sheet'i kupon uyarısı, `RolYetkileri.kuponSatisi` ve
  `SipText.gsKuponEtiket` kaldırıldı. Teslimde artık dört ödeme tipi var; **tezgâh satışında
  veresiye kilidi KORUNDU.**
- **Drift şema v10:** iki tablo `DROP TABLE IF EXISTS` ile düşürülür. Düşürme kendini-onarma
  kapısından **ÖNCE ve koşulsuz** koşar — kapı `tenant_settings` varsa erken döndüğü için
  `if (from < 10)` bloğu v9 damgalı cihazlarda hiç çalışmazdı (v10 tablo eklemediği için kapının
  işareti de güncellenemiyor). Regresyon testi: `migration_test.dart` "v9→v10 KUPON KALDIRMA".
- **API:** `CouponMovement`/`CouponBalance` modelleri + `CouponChangeApplier` SİLİNDİ;
  `ChangeApplier` dallanması, `SyncService` snapshot anahtarları, `SyncPushRequest`
  `entity_type=coupon` ve kupona özel `grant`/`use`/`correction` OP'ları, `PanelExportService`
  tabloları (12→10), demo seeder kupon bloğu temizlendi.
- **Migration `2026_07_26_000703_drop_coupons`:** tabloları düşürür (policy/grant'lar tabloyla
  birlikte gider), `orders.payment_type` CHECK'ini daraltır; daraltmadan ÖNCE kalan `'kupon'`
  satırları NULL'a çekilir (yoksa migration düşerdi). Veri kaybı DEĞİL: kuponla teslim hiç para
  hareketi üretmiyordu ve olgu APPEND-ONLY `order_events` payload'ında duruyor. `down()` şemayı
  geri kurar, satırları geri getirmez (dosyada açıkça yazılı).
- **Belgeler:** `BRIEF.md` kupon maddesi SİLİNMEDİ, altına "KALDIRILDI" notu düşüldü (saha gerçeği
  olarak tarihsel kayıt kalsın).

**DOĞRULAMA:** `dart analyze` 0 · `flutter test` 308/308 · API phpunit 220/220 (788 iddia) ·
`pint --test` passed · phpstan 0 hata · migration geliştirme DB'sine uygulandı · `flutter build
apk --debug` başarılı.

### VARDİYA 2026-07-26/2 (giriş firma kodu+kullanıcı adı · oto sıralama rota · 4 boşluk)

**TETİKLEYİCİ:** Kullanıcı "UI'da hâlâ yanlışlıklar ve eksikler var; MCP ile analiz et, eski
handoff klasörlerini SİL, MVP'nin güncel hâlini oku — orada uygulamada olmayan alanlar var,
**arka uç dahil** eklenmeli" dedi.

**KAYNAK ARTIK DEPODA DEĞİL — CANLI.** `design_handoff/` ve `design_handoff_v2/` **silindi**
(git'ten de). Tasarımın tek kaynağı Claude Design projesi `a4ab826a-d312-4313-96be-e66519b64fce`
("Sipario APP Reesign", handoff klasörü `design_handoff_sipario/`); `DesignSync` MCP aracıyla
okunur. Gerekçe: aynı hata iki kez yapıldı — kopya bayatladı ve iki vardiya yanlış kaynağı doğru
sandı. Koddaki 31 ölü `design_handoff_v2/` yorumu da temizlendi. **Önce `DESIGN_SYSTEM.md`'yi oku**
(sıfırdan yazıldı, kaynağı ve okuma yolunu anlatır).

**DENETİM YÖNTEMİ VE SONUCU:** uzak handoff'un 17 dosyasının TAMAMI okundu (16 ekran + 656 satır
CSS). Tasarımın 40 ayrı davranışı/metni tek tek kodda arandı — **39'u zaten vardı.** Uygulama
beklenenden çok daha sadık çıktı; gerçek boşluklar dört taneydi:

1. **GİRİŞ MODELİ YANLIŞTI (en büyük, arka uç dahil).** Tasarım `s-giris.jsx`: **Firma Kodu +
   Kullanıcı Adı + Parola**. Uygulama e-posta istiyordu. Gerekçe tasarımın kendi metninde:
   İşletme Profili firma kodunu "Kullanıcılarınız bu kodla giriş yapar" diye yayınlıyor —
   bayinin kuryesinin e-postası yok, hesabını patron açıyor.
   Yapılan: `users.username` (tenant içinde tekil + CHECK `^[a-z0-9._-]{3,60}$`), `tenants.slug`
   ZORUNLU oldu (giriş kimliği olacaksa NULL meşru değil) + CHECK, `sipario_login_lookup`ın
   (firma kodu, kullanıcı adı) alan İKİ ARGÜMANLI sürümü, LoginRequest/AuthController, hız
   sınırı anahtarı kullanıcı adı DEĞİL **çift** üzerinden (yoksa bir bayiye kaba kuvvet tüm
   bayilerin "patron" hesabını kilitlerdi), mobilde üç alanlı form + saf doğrulama fonksiyonu.
   **E-postalı tek argümanlı fonksiyon KALDI** — abonelik WEB SİTESİ onu kullanır, o ayrı bir
   yüzeydir. Mevcut kullanıcılara kullanıcı adı e-postanın yerel parçasından geri dolduruldu.
2. **"Oto Sırala (rota)" HİÇ ÇİZİLMİYORDU.** Kod vardı ama `otoHak` hiçbir yerden geçilmiyordu;
   çekmecedeki kontör kartı da beslenmiyordu. Arka uçta sayaç (`route_credits`) vardı, **tüketen
   servis yoktu.** Yapılan: `tenants.route_credits_monthly` (aylık kota — çekmecedeki çubuğun
   paydası), `POST /orders/auto-route` (kilitli sayaç düşümü + en-yakın-komşu rota; koordinatsız
   duraklar sona, sayısı kullanıcıya söylenir), `RouteOrderer` saf sınıfı, mobil `RouteApi` +
   liste ekranı bağlantısı + çekmece kartı. **Uç nokta siparişlere YAZMAZ** — yalnız sıra önerir,
   yazma yine `sort_set` olayıyla outbox'tan geçer (tek yazma yüzeyi korundu).
3. **Gün sonu `gunEngel` kuralı yoktu:** kuryelerin bir kısmı hesabını kapatmışken gün
   kapatılabiliyordu (yarım kalmış devir). Mevcut "açık sipariş" engelinin yanına eklendi.
4. **Varsayılan sekme** tasarımda `siparis`, uygulamada `ana`ydı — düzeltildi.

**ÖLÇÜMLER:** `dart analyze` **0** (lib+test) · `flutter test` **319/319** · API **233/233**
(808 assert) · `pint` ✓ · `phpstan` 0 · Drift şema **v9** (additif, `_addColumnIfMissing`) ·
codegen `--force-jit` ile koştu.

**CİHAZDA DOĞRULANDI (Samsung SM-S721B, yerel sunucu + `adb reverse tcp:8000`):**
giriş (firma kodu `demo` · kullanıcı adı `demo`) → açılış SİPARİŞLER sekmesinde → Sırala sayfası
"Oto Sırala (rota) · 34 hak" → oto sıralama KOŞTU: toast *"Rota otomatik sıralandı · 33 hak
kaldı · 1 sipariş konumsuz, sona alındı"*, liste rota sırasına geçti (Kepez → Lara → konumsuz
Ahmet), ekran elle/rota kipine girdi (tutamaçlar + "Bitti") → çekmecede lisans ve oto-sıralama
kartları çizildi ve kontör 33'e düştü (sunucuyla birebir).

**CİHAZDA YAKALANAN İKİ GERİLEME (ikisi de aynı sınıftan — testler yeşildi):**
- **"Oto Sırala · 0 hak" gösteriliyordu, sunucuda 34 vardı.** Kalan hak `initState`te TEK ATIŞ
  okunuyordu; kontör GİRİŞ YANITINDA GELMEZ, ilk senkron yazar. Ekran girişten hemen sonra 0
  görüp orada donuyordu. `AppDatabase.watchSyncState()` eklendi, ekran akışa abone edildi;
  regresyon testi yazıldı (ekran açıkken senkron yazınca düğme tazeleniyor mu).
- **Çekmecedeki kart "34 hak"ta kaldı, oto sıralama 33'e düşürdükten sonra bile.** Kabuk da
  sync_meta'yı tek atış okuyordu ve yalnız senkron olayında tazeliyordu. O da akışa bağlandı;
  `_git()` dönüşündeki ikinci tazeleme yolu KALDIRILDI (iki yol tutmak ikisinin ayrışmasıydı).
- Ders: **sunucu sahipli alanlar (abonelik, firma kodu, kontör) TEK ATIŞ okunmaz, akışla okunur.**
  Ne `dart analyze` ne 318 test bunu gördü; ölçüt "ekran çizildi" değil "değer değişince
  tazelendi" olmalıydı — `icon_paint_test` dersinin aynısı.

**AÇIK KALAN (cihazda görülemedi):** Gün Sonu'ndaki yeni `gunEngel` uyarısı demo bayide
KURYE OLMADIĞI için tetiklenmiyor; widget testiyle sınandı, cihazda görmek için demo bayiye iki
kurye eklemek gerekir. Gün Sonu / Ana / Müşteriler ekranları bu vardiyada değişmedi (önceki
vardiyada cihazda gezilmişti).

**KAYDA DEĞER:** `RouteCoverageGuardTest` yeni uç noktayı izolasyon matrisine eklemeden geçirmedi
— kırmızı çizgi #1'in bekçisi çalıştı, cross-tenant senaryosu yazıldı (B'nin siparişi A'nın
isteğine konsa sıraya girmiyor, B'nin kontörü etkilenmiyor).

**MAĞAZA NOTU DÜZELTİLDİ:** `docs/magaza/inceleme-notlari.md` incelemeciye hâlâ e-postayla giriş
söylüyordu — o bilgiyle giriş yapılamaz, inceleme reddedilirdi. Firma Kodu `demo` · Kullanıcı Adı
`demo` · Şifre `demo1234` olarak güncellendi (DemoSeeder de).

### VARDİYA 2026-07-25/26 (SİPARİO 3.0 — YENİ TASARIM, TÜM ARAYÜZ YENİDEN YAZILIYOR)

> ⚠️ **Bu vardiya bir öncekinin işini GEÇERSİZ KILDI.** Aşağıdaki "VARDİYA 2026-07-23" bölümü
> tarihsel kayıt olarak duruyor; oradaki tasarım (koyu tema · IBM Plex Sans · Azur mavi ·
> `design_handoff/`) **artık yürürlükte değil.** Yeni kimlik için önce `DESIGN_SYSTEM.md`'yi oku.

**TETİKLEYİCİ:** Kullanıcı önce tüm dış/kritik-yol işlerini (iyzico, mağaza hesapları, avukat, prod
VPS, pilot…) ERTELEDİ, sonra Claude Design'da **sıfırdan yeni bir tasarım** yaptırdı ve
`design_handoff_v2/` olarak depoya koydu. Bağlayıcı kuralı: *"Tasarımda olan her detay back
tarafında da olacak — DB'de kaydedilmeyen bir şey eklediysem ona karşılık gelen şemayı da
oluşturman gerekiyor."* İş 6 paralel ajana bölündü.

**HANDOFF KLASÖRÜ — DİKKAT:** `design_handoff_v2/` İKİ projenin dosyasını taşıyor.
Sipario = **`s-` ön ekli `.jsx` dosyaları + `Sipario.html`** (tüm CSS orada, satır 14–668).
Ön eksiz dosyalar (`uygulama.jsx`, `pano.jsx`, `veri.jsx`, `yonetici*.jsx`, `Aspendos ERP-*.html` …)
kullanıcının **Aspendos ERP** projesine ait — AÇMA.
**`s-bugun.jsx` de ÖLÜ dosya:** tasarımın terk edilmiş bir ara sürümü — `Sipario.html` onu
yüklemiyor ve kullandığı CSS sınıflarının hiçbiri stil dosyasında yok (farklı jeton seti:
`--vurgu`/`--borc`). Yerini `s-ana.jsx` aldı.

**YENİ KİMLİK:** açık tema varsayılan (koyu tema da var) · koyu gece-mürekkep "hero" blokları ·
elektrik moru vurgu `#5A45F0` · **Sora** (başlık + rakam) ve **Hanken Grotesk** (gövde) değişken
fontları · düz yüzeyler (gölge yok) · Lucide ikonlar. Ayrıntı: `DESIGN_SYSTEM.md`.

**TEMEL KATMAN BİTTİ VE DOĞRULANDI (`lib/theme/`, 41/41 test yeşil):**
- `tokens.dart` — `SipTokens` artık bir **ThemeExtension** (tema çalışma anında değişiyor);
  ekranlar `context.sip.surface` diye okuyor. `static const SipColors` KALKTI.
- `typography.dart` — `SipText`, stiller **renksiz** (renk `DefaultTextStyle`tan miras).
- `svg_path.dart` + `icons.dart` — Lucide SVG yollarını çizen bağımlılıksız ayrıştırıcı
  (SVG paketi eklenmedi; `Path.arcToPoint` SVG yay semantiğiyle birebir eşleşiyor).
- `components/` — `atoms.dart` artık **barrel**: `bicim · dokunma · form · rozetler · yerlesim`
  (+ `states.dart`, `overlays.dart`). `SnackBar`/`AppBar`/`InkWell` KULLANILMIYOR
  (yerine `SipToast` · `SipUst` · `SipDokun`).
- Fontlar `assets/fonts/`'a gömüldü (OFL, değişken font). **IBM Plex Sans SİLİNDİ.**
- **Türkçe büyük harf tuzağı:** Dart'ın `toUpperCase()`'i `i`→`I` yapıyor. `trBuyuk()`/`trKucuk()`
  eklendi; `toUpperCase()` yazmak yasak. `test/ui_temel_test.dart` bunu sınıyor.
- **Değişken font tuzağı:** yalnız `fontWeight` vermek yetmiyor (tek dosya = tek ağırlık);
  `fontVariations: [FontVariation('wght', N)]` şart. `test/font_variable_test.dart` bunu
  gerçek TTF yükleyip ÖLÇEREK kanıtlıyor (7/7).

**ŞEMA v8 — tasarım/arka uç eşitliği kuruldu (backend ajanı):**
Yeni tablolar `tenant_settings`, `exempt_numbers` (muaf numaralar — çağrı kartını engeller),
`call_logs`, `day_closings`; yeni alanlar `customer_addresses.region`, `products.barcode`,
`products.image_url`, `orders.sort_index` (elle sıralama), `order_lines.is_custom` (serbest satır).
Postgres migration + RLS + revoke + sync applier + Drift v8 + yeni repo'lar yazıldı.

**TÜM EKRANLAR YENİDEN YAZILDI.** Tasarımın `s-*.jsx` bileşenlerinin tamamının Dart karşılığı var:
Ana ekran (hero + bento + son aktivite) · alt navigasyon + çekmece · giriş · kurulum sihirbazı
(izinler) · müşteriler/detay/defter/tahsilat/düzeltme · siparişler/detay/POS yeni sipariş/teslim ·
ürünler (barkod + görsel) · gün sonu + arşiv · kasa devri · ayarlar · işletme profili · kuryeler ·
muaf telefonlar · çağrı kartı (Flutter + native Kotlin) · abonelik kilidi.

**ÖLÇÜMLER (bu makinede doğrulandı):** `dart analyze` **0** (lib + test) · `flutter test`
**302/302** · API **220/220** (760 assert) + pint/phpstan temiz · Postgres migration 601–607
`migrate:fresh` ile sıfırdan koştu · RLS dört yeni tabloda FİİLEN sınandı · `flutter build apk
--debug` **başarılı** (Kotlin dahil).

**BU VARDİYADA YAKALANAN GERİLEMELER (kayda değer):**
- **Salt-okunur kapısı düşmüştü:** yeni sipariş girişi listeden kabuğa taşınırken üç çağrı yeri de
  `OrderFormScreen.writable`ı geçmiyordu (varsayılan `true`) → abonelik kilidi açıkken sipariş
  girilebiliyordu. Çağrı yerleri düzeltildi, parametre **zorunlu** yapıldı.
- **Türkçe büyük harf:** Dart'ın `toUpperCase()`'i `i`→`I` yapıyor. Avatar baş harfleri ve ürün
  yer tutucuları bundan etkileniyordu; `trBuyuk()`/`trKucuk()` eklendi, testle sabitlendi.
- **Değişken font ekseni:** yalnız `fontWeight` vermek tek dosyalı değişken fontta ETKİSİZ.
  `test/font_variable_test.dart` gerçek TTF yükleyip genişlik ÖLÇEREK kanıtlıyor.
- **Giriş ekranı taşması:** `IntrinsicHeight` metni sonsuz genişlikte ölçüp sarmalanan satırları
  tek satır sayıyordu (21 px). `ConstrainedBox(minHeight) + mainAxisAlignment.end` ile çözüldü.

**CİHAZ TESTİ YAPILDI (Samsung SM-S721B / Galaxy S24 FE — önceki vardiyadaki Xiaomi DEĞİL,
dolayısıyla MIUI'ye özel izin dalları bu cihazda sınanmadı).** Ana ekran, bento ızgarası, alt
navigasyon, çekmece düğmesi, hızlı eylem ve son aktivite listesi tasarımla örtüşüyor; hem AÇIK hem
KOYU tema cihazda görüldü.

**CİHAZDA YAKALANAN KRİTİK HATA — hiçbir ikon çizilmiyordu.** `SipIcon` yalnız `hepsi[ad]`
sözlüğüne bakıyordu ama `SipIcons.phone` bir anahtar değil path'in KENDİSİ; arama `null` dönüp
sessizce boş kutu çiziliyordu. 307 testin hiçbiri yakalayamadı çünkü ölçütleri "yol ayrıştı" ve
"widget çökmedi"ydi. Düzeltildi (`_pathMi` ile iki biçim de kabul) ve
`test/icon_paint_test.dart` eklendi: ikonları gerçekten boyayıp **piksel sayıyor**; düzeltme geri
alındığında kırmızıya döndüğü doğrulandı.

**CİHAZDA EKRAN EKRAN GEZİLDİ (2026-07-26, ikinci tur) — ENTEGRASYON KOPUKLUKLARI BULUNDU.**
Kaynak şüphesi önce MCP ile kapatıldı: claude.ai/design projesi okundu, uzak `s-ana.jsx` yerelle
bayt bayt aynı, `Sipario - Standalone.html` ile `Sipario.html`in CSS sınıf kümeleri birebir eşit
(390 = 390) — Standalone yeni bir tasarım değil, aynı tasarımın gömülü sürümü. Sorun kaynakta
değil, ekranların BİRBİRİNE BAĞLANMAMASINDAYDI:
- **Ayarlar · Kuryeler · Muaf Telefonlar · İşletme Profili · Çağrı Geçmişi hiçbir yerden
  açılamıyordu.** Çekmece, bu ekranlar yazılmadan önce yazılmış ve güncellenmemişti; Ayarlar bir
  merkez olduğu için dalın tamamı ölüydü. Çekmece tasarımdaki hâline getirildi
  (YÖNETİM: Ürünler · Kuryeler · Muaf Telefonlar — UYGULAMA: tek satır Ayarlar).
- **Çekmece yalnız Ana sekmesinden açılabiliyordu** — kabuk `onMenu`yu diğer üç sekmeye
  geçmiyordu (Gün Sonu'nda yerine işlevsiz bir geri oku vardı). Düzeltildi + regresyon testi.
- **Durum çubuğu açık temada okunmuyordu** — stil yalnız kabukta kuruluyordu, push edilen
  ekranlar hero için beyaza çevrilmiş ikonları miras alıyordu. Kökte (`main.dart`) kuruldu.
- **Ayarlar'daki tema anahtarı takılı kalıyordu** — push edilen rota `bool` kopyası tutuyordu;
  `ValueListenable`a çevrildi. (Anahtar zaten sahteydi: yerel bayrak, kalıcı depoya bağlı değildi.)
- Sunucu adresi ölü bir tünel URL'sine bakıyordu; yerel köprüye çevrilince senkron çalıştı
  ("Senkron güncel"), çevrimdışı bandı kalktı. Bant DOĞRU davranıyormuş.

Gezilen ve tasarıma uygun bulunan ekranlar: Ana · Müşteriler · Siparişler · Gün Sonu · Çekmece ·
Giriş · Ayarlar · Kuryeler · İşletme Profili · Muaf. Her iki tema da cihazda görüldü.

**AÇIK KALANLAR:**
- **Çağrı kartı cihazda HENÜZ ÖLÇÜLMEDİ** — 1 sn bütçesi ve kilit ekranı davranışı için gerçek
  gelen çağrı testi gerekiyor. Ayarlar → Arayan Tanıma → "Gelen çağrıyı dene" bu iş için var.
- Müşteri detayı, yeni sipariş (POS) akışı ve sipariş detay sheet'i cihazda AÇILMADI — kod ve
  testleri var, gözle doğrulanmayı bekliyor.
- Cihaz Samsung Galaxy S24 FE; **MIUI'ye özel izin dalları hâlâ Xiaomi'de sınanmadı.**
- **Senkron cihazda başarısız** (ana ekranda çevrimdışı bandı duruyor). Bant DOĞRU davranıyor —
  son senkron denemesi başarısız olduğu için çıkıyor, uydurma değil. Sebep büyük olasılıkla
  geliştirme köprüsü (cihazdaki API taban adresi ↔ `adb reverse tcp:8000`); araştırılmadı.
- `lib/phase0/phase0_screen.dart` 663 satır (500 sınırını aşıyor) — **bu vardiyadan ÖNCE de
  aşıyordu** (656), regresyon değil; Faz 0 tanı ekranı, bölünmeyi bekliyor.
- `test/ui_dilim3_test.dart` (621) ve `ui_dilim4_test.dart` (529) de sınırın üstünde.
- Sipariş formunda salt-okunur uyarısının 1. adımdan itibaren görünmesi istendi (3. adıma kadar
  gizliydi) — kapatıldıysa doğrula.
- **Windows tuzağı:** iki `flutter test` aynı anda koşarsa
  `build/native_assets/windows/sqlite3.dll` kopyalamada yarışır ve araç çökme raporu yazarak
  düşer. Çözüm: `rm -rf build/native_assets`. Kodla ilgisi yok, bu vardiyada onlarca kez yaşandı.
- **API testini `artisan test` ile KOŞMA — `vendor/bin/phpunit` kullan.** Bu makinede pdo_pgsql
  php.ini'de kapalı, `-d extension=...` ile veriliyor; ama `artisan test` işçi alt süreçler
  doğuruyor ve o bayraklar MİRAS ALINMIYOR → 220 testin 209'u "could not find driver" ile düşüyor
  ve gerçek bir kırılma sanılıyor. Doğrusu:
  `php -d extension=pdo_pgsql -d extension=pgsql -d extension=zip vendor/phpunit/phpunit/phpunit --no-coverage`
  (tek süreç, bayraklar geçerli → 220/220, 760 assert).

### VARDİYA 2026-07-23 (TARİHSEL — bu tasarım ARTIK GEÇERSİZ; üstteki bölüme bak)

**TETİKLEYİCİ:** Kullanıcı Claude Design'da (claude.ai/design) mobil arayüzü yeniden tasarladı, handoff
paketini `design_handoff/`'a koydu ("çok basit tasarımı var, yeniden düzenlet"). Görev: handoff'u
Flutter'a idiomatik uygula, ekran ekran onay kapılarıyla (kullanıcı 7 kurallı iş emri verdi).
Handoff = koyu tema, katmanlı yüzeyler, su-temalı Azur vurgu, kartlar + bakiye rozetleri, IBM Plex Sans.
Handoff'ta detaylı mockup olan ekranlar: **Müşteriler, Siparişler (boş+dolu), Gelen Çağrı Popup (3 varyant)**.

**NE BİTTİ (hepsi bu makinede doğrulandı — dart analyze 0 · flutter test 161/161 · debug APK):**
- **Merkezî tema katmanı `apps/mobile/lib/theme/`** — `tokens.dart` (SipColors/SipRadius/SipSpace),
  `typography.dart` (SipText + TextTheme), `app_theme.dart` (SipTheme.dark → M3 ThemeData:
  appbar/nav/fab/input/dialog/buton temaları), `components/` (BalanceBadge, SipEmptyState, SipSegmented).
  **Ekranlarda ham renk/ölçü/font YASAK — hepsi token'dan.** Özet: **`DESIGN_SYSTEM.md`** (YENİ, repo kökü —
  sonraki TÜM ekranların referansı; önce onu oku).
- **Font IBM Plex Sans `assets/fonts/`'a GÖMÜLDÜ** (OFL; google_fonts DEĞİL — offline-first/kırmızı çizgi #3
  runtime indirmeyi reddeder). 400/600/700. İkonlar Flutter yerleşik `Icons.*` (Material Symbols'a yakın).
- **Ekran 1 — Müşteriler** (`customer_list_screen.dart`): kart satırları (avatar baş-harf + ad + telefon),
  sağda `BalanceBadge` (borç dolgulu kırmızı), başlıkta canlı "N borçlu" rozeti, dolgulu arama, boş durum
  ortak bileşen. Alt gezinme (seçili hap + dolu ikon) ve abonelik şeridi de tasarıma uydu (`home_shell.dart`).
- **Ekran 2 — Siparişler** (`order_list_screen.dart`): `SipSegmented` filtre + sipariş kartı (müşteri +
  ürün özeti + durum rozeti Açık/Teslim/İptal + alt satırda saat·ödeme·kurye + tutar). Kurye "Benim" sekmesi korundu.
- **İki additive salt-okunur sorgu** (testli sözleşmelere DOKUNMADAN): `watchCustomerRows` (birincil telefon
  LEFT JOIN) ve `watchOrderItemsSummary` (sipariş ürün özeti). `watchCustomers`/`watchOrders` AYNEN korundu.

**NE YARIM KALDI / AÇIK:**
- **Ekran 3 — Gün sonu: KOD BAŞLAMADI. Repo'da HÂLÂ ESKİ görünümde.** Ultracode tasarım-paneli workflow'u
  başlatıldı (3 öneri → jüri → sentez) ama vardiya kapanınca DURDURULDU (jüri+sentez koşmadı, KOD ÜRETİLMEDİ).
  Sonraki kişi Gün sonu'nu **DESIGN_SYSTEM.md'yi izleyerek DOĞRUDAN uygulasın** — özet bir ekran için panel
  gereksiz; Ekran 1/2 kart desenini kopyalamak yeter.
- **Kalan ekranlar (kullanıcı sırası):** Ekran 3 Gün sonu → Ekran 4 Menü → Ekran 5 Ürünler → **Ekran 6 Gelen
  Çağrı Popup** (overlay penceresi; ANA Scaffold'a bağımlı OLMAYAN bağımsız widget; tema token'larını lib/theme/'den
  alır; 2 varyant: kayıtlı müşteri [borçlu/temiz] + kayıtsız numara — handoff'ta 3 detaylı mockup var).
- **Elle çizilmeyen ekranlar (global temayı MİRAS alıyor, otomatik uydu ama tam sadakat için elden geçebilir):**
  login, müşteri detay/form, sipariş form/detay, ürün listesi, kasa devri, kupon, abonelik-kilit, Faz 0.
  Kullanıcı Ekran 2 checkpoint'inde "form/detay da elle gerekli mi?" sorusunu YANITLAMADI — sor.

**SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ:**
1. **Önce `DESIGN_SYSTEM.md`'yi oku** (tema sözleşmesi) + DECISIONS.md sonundaki "Tasarım sistemi" bölümü.
2. **Ekran 3 = Gün sonu** (`lib/screens/day_end_screen.dart`). **KORUNACAK (testler find.text ile arıyor):**
   kart başlıkları **"Kasa (bugün)" / "Veresiye (açık borç)" / "Kupon"**. Salt-okunur (aksiyon/FAB YOK).
   `gunSonuOzeti`/`bugunTr` testli — DOKUNMA. Desen: SafeArea + "Gün sonu" başlık + tarih + kartlar
   (Material s1 + kenar line + radius card; etiket/tutar satırları amount stiliyle; borç>0 kırmızı, eksi kupon kırmızı).
3. **Her ekran bitince:** `dart analyze` + `flutter test` + `flutter build apk --debug`, sonra kullanıcıya
   "KARAR GEREKLİ" ile göster, onay al, SONRAKİ ekrana geç (kullanıcının 7 kurallı iş emri böyle).

**BİLİNEN TUZAKLAR (bu vardiya):**
- **Codegen GEREKMEDİ** — şema değişmedi, yalnız mevcut üretilmiş tablolarla yeni sorgular; build_runner
  AOT/`--force-jit` tuzağına hiç girilmedi. **Şema (tables.dart) değiştirirsen o tuzak geri gelir** (pubspec notu).
- **Testli sorgu sözleşmelerine DOKUNMA** — `watchCustomers`/`watchOrders`/`gunSonuOzeti` testler DOĞRUDAN
  çağırır; görüntü için ek veri gerekince (telefon, ürün özeti) AYRI additive fonksiyon yaz, mevcut imzayı koru.
- **Ekranlarda ham renk/ölçü YAZMA** — bir kez `Color(0xFF...)` (iptal rozeti) kaçtı, analyze DEĞİL gözle
  yakalandı → `SipColors.s3`. Her değer token'dan; lint hardcoded rengi yakalamaz.
- **Font makine-yerel OFL kopyası** (geçerli TTF doğrulandı, magic 00010000) — kanonik IBM Plex ile değiştirilebilir.
- **Ultracode workflow'u vardiya kapanışında TaskStop ile durdurulmalı** — arka plan workflow'u farklı oturuma taşınmaz.

### VARDİYA 2026-07-22 (GERÇEK CİHAZ TESTİ — Samsung S24 FE + arkadaş cihazı; 2 saha hatası bulundu ve KAPATILDI)

**DEVRALAN KİŞİ — BURADAN BAŞLA (rehber):**
1. **İlk iş: cihaz testinin sonucunu öğren/tamamla.** Düzeltilmiş APK kullanıcının telefonuna kuruldu
   ama "açılış düzeldi + kart adresle çıkıyor" TEYİDİ vardiya kapanırken HENÜZ GELMEMİŞTİ. Test
   senaryosu: uygulamayı aç (veri SİLME — onarım kodu damgayı yerinde tamir eder) → giriş →
   kayıtlı numaradan ara → kart ≤1 sn'de ADRESLE çıkmalı → uygulamayı tamamen kapatıp tekrar ara
   (journal_mode/native sınavı) → sipariş→teslim→tahsilat→gün sonu akışı → Menüde "Kasa devri"
   GÖRÜNMEMELİ (demo bayi tek kişilik).
2. **Sunucu köprüsü (arkadaş-testi için):** Bu makinede OTURUMDAN BAĞIMSIZ iki süreç çalışıyor:
   `php.exe` (0.0.0.0:8000, pgsql eklentili) + `cloudflared.exe` (hızlı tünel). Tünel adresi:
   `https://chemicals-discussions-customized-mailing.trycloudflare.com/api/v1` — **makine yeniden
   başlarsa İKİSİ DE ÖLÜR ve tünel adresi HER SEFERİNDE DEĞİŞİR.** Yeniden kurmak için:
   `apps/api` içinde `php -d extension=pdo_pgsql -d extension=pgsql -d extension=zip -S 0.0.0.0:8000 -t public`
   (⚠️ `artisan serve` KULLANMA — alt sürece -d bayraklarını GEÇİRMİYOR, "could not find driver")
   + `cloudflared tunnel --url http://127.0.0.1:8000` (URL çıktıda). Yeni adresi test cihazlarına
   "Gelişmiş"ten yeniden girmek gerekir (çıkış yap → yeni adresle gir; veri silinmez).
   USB'li cihaz için alternatif: `adb reverse tcp:8000 tcp:8000` → adres `http://127.0.0.1:8000/api/v1`
   (kablo çıkınca reverse DÜŞER, yeniden kur).
3. **Giriş bilgileri:** demo hesap `demo@sipario.com.tr / demo1234` (4 sahte müşteri + gerçek test
   kaydı "Ahmet BUĞRA +905442014305" sunucuda). Cihaz: Samsung S24 FE (SM-S721B, Android 16),
   adb yetkili.
4. **Sıradaki işler:** cihaz teyidi sonrası YAPILACAKLAR.md kritik yolu (iyzico anahtarı → ben
   bağlarım; Apple D-U-N-S erken başla; release imza anahtarı; avukat). PR #11 merge hâlâ insanda.

### NE OLDU (bu vardiya — gerçek cihaz testi 2 GERÇEK hata yakaladı, TAM AMACINA ULAŞTI)
- **Kurulum zinciri ÇALIŞTI:** APK Samsung'a kuruldu, USB tüneliyle giriş + senkron BAŞARILI
  (sunucuya gerçek müşteri kaydı düştü — yazma zinciri kanıtlı), arkadaş cihazına internet
  tüneliyle uzaktan kurulum yapıldı.
- **SAHA HATASI 1 — sonsuz loading (İKİ cihazda):** Faz 0 ölçüm ekranı `sipario.db`'yi sqflite
  `version: 1` ile açıyordu → Drift'in v7 `user_version` damgası 1'e eziliyordu → sonraki soğuk
  açılışta migration YENİDEN koşup "duplicate column: updated_occurred_at" ile çöküyor, açılış
  sonsuz spinner'da kalıyordu. "Arayan tanıma sihirbazını kur → bir süre sonra girilmez ol → veri
  sil → düzel → sihirbazı yeniden kur → yeniden boz" döngüsünün açıklaması. Logcat ile kanıtlandı.
  **DÜZELTME (3 katman):** (a) kaynak kaldırıldı — `lib/phase0/local_db.dart` SİLİNDİ, Phase0Screen
  artık ürünün AppDatabase'ini + CustomerRepository'yi kullanır (spike tohum verisi de artık üretim
  DB'sine YAZILMAZ; eski çöpler — id `c1/c2/c3` ve `c-<zaman>` — beforeOpen'da otomatik silinir);
  (b) migration KENDİNİ ONARIR — v7 işareti (`users` tablosu) varken migration atlanır, Drift
  damgayı yeniden yazar + tüm ALTER'lar "duplicate column"a toleranslı `_addColumnIfMissing`;
  (c) `main.dart` açılış hatasını EKRANA basar — sonsuz spinner yapısal olarak imkânsız.
- **SAHA HATASI 2 — taze kurulumda arayan tanıma HEP "kayıtsız" (arkadaş cihazı):**
  `CustomerLookup.kt` sorgusu `customers.address` okuyordu; taze v7 kurulumda o kolon YOK (Faz 2
  normalizasyonu — "native adres sorgusu taşınacak" devri unutulmuştu, PLAN Faz 2 "BİLİNEN AÇIK"
  maddesiydi). Sorgu "no such column" ile patlayıp her aramada null dönüyordu. **DÜZELTME:** adres
  `customer_addresses` birincilinden alt-sorguyla; arşivli müşteri/telefon eşleşmez.
- **Doğrulama:** `dart analyze` 0 · `flutter test` **161/161** (+2 yeni regresyon: sürüm-damgası-
  ezilme onarımı [dosya-DB ile], native SQL sözleşme testi [Kotlin sorgusunun birebir kopyası taze
  şemada koşar]) · APK derlendi + kullanıcının telefonuna kuruldu. migration_test'in korunma kanıtı
  spike-temizliğiyle çakışmasın diye uuid-biçimli kimliğe taşındı + temizlik kanıtı eklendi.
- **Ortam işleri:** bu makinenin Docker DB'sine Faz 4+5 migration'ları uygulandı
  (`php artisan migrate --database=pgsql_owner --force` — ⚠️ owner bağlantısı ŞART, düz migrate
  "must be owner" ile düşer) + DemoSeeder koşuldu. `sipario_panel` rolü bu makinede kuruldu.

### BİLİNEN TUZAKLAR (bu vardiya — YENİ dersler)
- **`php artisan serve` -d eklenti bayraklarını alt sürece GEÇİRMEZ** → "could not find driver".
  Doğrudan `php -d ... -S 0.0.0.0:8000 -t public` kullan.
- **Hızlı tünel (trycloudflare) adresi her başlatmada değişir** ve süreç ölünce istemciler SESSİZCE
  senkronsuz kalır (offline-first hata göstermez — tasarım gereği). Cihazda "Şimdi senkronla"
  sonucu tek dokunuşta gerçeği söyler. Kalıcı çözüm: prod VPS (kritik yol).
- **Claude oturumunun arka plan görevleri kalıcı sunucular için güvenilmez** (bu vardiya iki kez
  dışarıdan öldürüldü) → sunucu/tünel `Start-Process` ile AYRIK başlatıldı; kapatmak istersen Görev
  Yöneticisi'nden `php.exe` + `cloudflared.exe`.
- **`adb reverse` kablo çıkınca düşer** — telefon "sunucuya ulaşılamadı" derse önce `adb reverse --list` bak.
- **Aynı DB dosyasını İKİNCİ bir açıcıyla (sqflite/SQLiteOpenHelper) `version` parametreli AÇMA** —
  user_version damgasını ezer, Drift migration'ı raydan çıkar. Tek yazıcı AppDatabase'dir; native
  taraf YALNIZ `SQLiteDatabase.openDatabase(..., OPEN_READONLY)` (versiyonsuz).

### VARDİYA 2026-07-21/3 (4b DİLİM 4 — kurye + kasa devri; 4 ajanlı hat, koordinasyon kazalı ama YEŞİL)

**Kullanıcı talebi:** "plandaki kalan görevlerin hepsini ajanlarla bitir." Hat: **architect** (Plan tipi,
tasarım) → **coder-2** → **tester-2** → **reviewer-2**. Ek görevler: guzzle güvenlik yükseltmesi (4
Dependabot uyarısı) + customer_ledger mağaza-kuralı simetri testi.

### NE BİTTİ (bu vardiya — üç bağımsız doğrulama: tester-2, reviewer-2, lead)
- **4b DİLİM 4 BİTTİ → 4b · Saha UI TAMAMEN KAPANDI:**
  - **Sunucu:** `SyncService::teamPayload` — push/pull yanıtına `team` bloğu (subscription deseni;
    YALNIZ id/name/role/status — parola/telefon/e-posta ASLA; sipario_app bağlantısı = FORCE RLS →
    cross-tenant yapısal imkânsız). `SyncTeamTest` 5 test (cross-tenant sızmaz + PII-asgari kanıtı).
  - **Mobil:** Drift **v7 additif** `users` aynası (senkronda toptan tazelenir; `team=null` → dokunma
    [eski sunucu uyumu], `[]` → temizle); `lib/screens/team.dart` — `yetkiler()` K2 rol matrisi
    (kurye: teslim+tahsilat+kendi kasa devri; yönetici işleri patron/operator; **atama ve kasa devri
    yalnız AKTİF KURYE VARSA** → tek kişilik bayide HİÇ render edilmez — BRIEF pazarlıksız, testli);
    sipariş listesinde kuryeye "Benim" sekmesi + atanmış kurye chip'i; sipariş detayında atama UI;
    `cash_handover_screen.dart` (beklenen nakit `CashHandoverRepository.onizle()` — ekran ve kayıt
    AYNI koddan; sayılan tutar parseKurus; fark KANIT, eksik para kırmızı görünür kalır; düzeltme
    YENİ devirle); home_shell rol/yetki gating.
  - **Guzzle 7.14.0 → 7.15.1** (+psr7): 4 Dependabot uyarısının hepsi kapandı, `composer audit` temiz,
    majör atlama yok, kod değişikliği yok.
- **Doğrulama:** mobil `dart analyze` 0 · `flutter test` **159/159** (~7 sn; 130 taban + 29) · debug
  APK derlendi · izin bekçisi temiz; API `phpunit` **174/174 (608 assert)** · pint ✓ · phpstan sv6 0 ·
  `composer audit` temiz. **İnceleme (reviewer-2): 8 madde dosya:satır kanıtıyla YEŞİL — kırmızı çizgi
  ihlali YOK; en kritik risk (#1 pull'a team eklenmesi) test+kod düzeyinde kanıtlandı.**

### KODLA YAPILABİLİR İŞ BİTTİ — KALAN HER ŞEY DIŞSAL/İNSAN
1. **PR #11 merge** (dev→main; Faz 3–6 + 4b'nin tamamı) — düğme insanda.
2. **Gerçek cihaz doğrulaması** — güncel APK'da artık TAM ürün akışı var: giriş → müşteri → ürün →
   sipariş → teslim → tahsilat → gün sonu → (kurye varsa) atama + kasa devri → arayan tanıma +
   journal_mode/native uyumu. `adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
3. **YAPILACAKLAR.md** (kanonik dışsal liste): iyzico anahtarı + verify güvenlik testi, hukuk/avukat,
   mağaza hesapları + release imza anahtarı, Mac/Xcode (iOS), e-arşiv, VERBİS, Antalya pilotu.

### BİLİNEN TUZAKLAR (bu vardiya — YENİ dersler, çoğu AJAN KOORDİNASYONU)
- **Ajan adı çakışması:** aynı adla ikinci ajan spawn edilince yeni ajan `-2` eki alır ama ESKİ ada
  giden SendMessage eski (bitmiş) ajanı DİRİLTİR — bu vardiya eski 'coder' yanlış mesajla Dilim 4'ü
  paralel yazmaya başladı. Ders: her tura TAZE benzersiz adlar ver; yanlış diriltilen ajanı nazik "dur"
  mesajı TUR ORTASINDA durdurmaz — `TaskStop` (sert sonlandırma) gerekir, sonra ağacın gerçekten
  donduğunu mtime taramasıyla doğrula.
- **`Get-Process dart,flutter_tester -ErrorAction Stop` TUZAĞI:** listedeki HERHANGİ bir ad yoksa
  istisna fırlar ve VAR OLAN süreçler de gizlenir (bu vardiya iki zombi flutter_tester bu yüzden
  görünmedi, sqlite3.dll kilidi 3 koşum yaktı). Süreçleri AYRI AYRI sorgula.
- **Kilitli `build/native_assets/.../sqlite3.dll`:** `rm -rf` sessizce başarısız olur (kabuk asılır);
  önce dll'i tutan süreci bul (`Get-Process | ? { $_.Modules.FileName -eq $yol }`), öldür, sonra sil.
- **`addTearDown(db.close)` widget testinde YİNE yazıldı** (Dilim 1 dersi tekrar yaşandı — bu kez
  eski-coder'ın test dosyasında): akış-abonelikli drift db widget-test zonunda kapatılMAZ; shrink
  sonrası `pump(Duration(seconds: 5))` şart (!timersPending). Test dosyasının başına açıklama kondu.
- **Ajan sessiz ölebilir:** coder-2 doğrulama aşamasında yanıtsız kaldı (dürtme dahil) — kalan işi
  lead devraldı. Ders: teslim mesajı gelmeden "bitti" sayma; ağaç + süreç durumundan gerçeği oku.


### VARDİYA 2026-07-21/2 (4b DİLİM 3 — 4 AJANLI HAT: auditor→coder→tester→reviewer)

**Kullanıcı talebi:** "yapılmış görevleri analiz et, eksikleri ajanlarla tamamla." Sıralı hat kuruldu
(hepsi aynı dev ağacında — worktree yasak; inceleme donmuş ağaçta): **auditor** (salt-okunur denetim +
repo imza çıkarımı) → **coder** (Dilim 3 ekranları) → **tester** (9 ek derinleştirme testi) →
**reviewer** (8 maddelik kırmızı-çizgi incelemesi + bağımsız koşum). Lead ayrıca bağımsız doğruladı.

### NE BİTTİ (bu vardiya — commit a90b70f + b0fa8ec, otomatik kalite-kapısı hook'u commit'ledi)
- **4b DİLİM 3 BİTTİ — defter/tahsilat/gün-sonu ekranda:**
  - `lib/screens/customers/customer_ledger.dart` (417 satır, YENİ) — müşteri detayına defter bölümü:
    hareket listesi (entry_type/payment_type Türkçe etiketli, imzalı renkli tutar), **"Tahsilat al"**
    (parseKurus + nakit/kart/havale → LedgerRepository), **"Kupon sat"** (adet + not → CouponRepository;
    eksi bakiye kırmızı ama hiçbir işlem engellenmez), **"Ters kayıtla düzelt"** (satır menüsünden;
    yalnız ters kayıt — silme/ezme YOK, salt-okunurda menü hiç render edilmez).
  - `lib/screens/day_end_screen.dart` (218 satır, YENİ) — Menü → **"Gün sonu"**: kasa özeti ödeme tipi
    bazında + veresiye toplamı + kupon özeti (DayEndRepository read-model, TAMAMEN salt-okunur).
  - `customer_detail_screen.dart` +9 (CustomerLedgerSection entegre; dosya 500 sınırının altında
    kalsın diye defter ayrı dosyada), `home_shell.dart` +9 (Gün sonu menü girişi).
  - `test/ui_dilim3_test.dart` (498 satır): coder 12 + tester 9 = 21 test. Öne çıkanlar: **append-only
    kanıtı** (düzeltme sonrası satır sayısı +1 VE orijinal satır drift value-equality ile birebir
    değişmemiş), tahsilatın bakiye+kasayı AYNI tutarda değiştirmesi, kupon zinciri (sat→düş→eksiye düş),
    gün-sonu rakamlarının ELLE kurulan beklentiyle karşılaştırılması, salt-okunur kapı kontrastları,
    ekran-repo tutarlılığı (12345 kuruş → "+123,45 ₺").
- **İNCELEME: YEŞİL (reviewer, bağımsız koşumla).** 8 madde kod kanıtıyla: append-only ✓ para-int-kuruş ✓
  mağaza kuralı ✓ KVKK (sıfır log) ✓ salt-okunur kip ✓ offline-first ✓ kalite (<500, ekran-dışı sorgular) ✓
  ekran-defter tutarlılığı ✓. Repository'lere DOKUNULMADI (Faz 3'te incelenmişlerdi; Dilim 3 yalnız delege eder).
- **Doğrulama (üç bağımsız koşum: tester, reviewer, lead):** `dart analyze` 0 · `flutter test`
  **130/130 (~6 sn)** · debug APK derlendi · `check_permissions_source.sh` temiz.

### NE YARIM KALDI / AÇIK
- **Dilim 4 (son UI dilimi): kurye ekranları + kasa devri** — atama (assign/unassign repoda hazır),
  kurye görünümü, kasa devri (`CashHandoverRepository` hazır). **Tek kişilik bayide kurye adımları
  HİÇ GÖRÜNMEZ (BRIEF)** — kullanıcı listesi/rol bilgisi üzerinden koşullanacak.
- **Reviewer'ın minör gözlemi (bloklamaz):** customer_ledger için ayrı mağaza-kuralı regresyon testi yok
  (day_end ve orders'ta var; ekran yalnız iş ₺'si gösteriyor, ihlal değil) — simetri için eklenebilir.
- Gerçek cihaz doğrulaması + PR #11 merge + dışsal işler (YAPILACAKLAR.md) — değişmedi, insanda.

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **Sıradaki kod işi = Dilim 4: kurye + kasa devri** (son UI dilimi; desen aynı). Tek kişilik bayi
   gizleme kuralına dikkat.
2. **Telefon bağlanırsa öncelik:** gerçek cihaz doğrulaması (Dilim 1-2-3'lü APK hazır:
   `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`) — giriş → müşteri → ürün → sipariş →
   teslim → tahsilat → gün sonu → arayan tanıma → journal_mode/native uyumu.
3. PR #11 merge insanda; dışsal işler `YAPILACAKLAR.md`.

### BİLİNEN TUZAKLAR (bu vardiya — YENİ ders)
- **Widget-testin sahte-zaman diliminde HERHANGİ gerçek async drift çağrısı asılır — yalnız watch()
  değil, DÜZ Future sorgular da** (`getSingle()`, `.first`): `tester.runAsync(() async {...})` sarmalı
  ŞART. Dilim 1 dersinin genişletilmiş hali; tester bunu 6 dk asılı koşumla yaşadı (normal koşum ~6 sn —
  koşum dakikalara uzuyorsa asılı test var demektir, 10 dk timeout'u bekleme).
- Asılı `flutter test` öldürünce yetim süreç temizliği: `Get-Process dart,flutter_tester | Stop-Process -Force`
  (sqlite3.dll kilidi sonraki build'i kırar — Dilim 1'den beri geçerli).
- **Stop hook'u ajan oturumlarının sonunda otomatik commit + push yaptı** (a90b70f, b0fa8ec —
  "otomatik(dev)" mesajlı). Ajanlara "commit yapma" dense de hook devrede; kapanışta `git log`'a bak,
  işin zaten commit'lenmiş olabilir.

### VARDİYA 2026-07-21 (4b DİLİM 2 — sipariş ekranları; İKİNCİ GELİŞTİRİCİ MAKİNESİ)

**Bu vardiya `C:\Users\GokhanT\Desktop\sipario` makinesinde koştu** (diğer geliştiricininki
`C:\Users\bugra\OneDrive\Masaüstü\...`). **Önemli fark: bu makinede yol ASCII** — geçen vardiyanın
"Türkçe-yol tuzakları" (build_runner `--force-jit`, `flutter analyze` LSP çökmesi, AGP ASCII reddi)
BURADA YAŞANMADI; `flutter analyze`/`dart analyze` ve normal build sorunsuz. Flutter `C:\flutter`'da,
php Laragon'da PATH'te, Docker/Postgres ayakta DEĞİL (mobil iş için gerekmedi).

### NE BİTTİ (bu vardiya — hepsi bu makinede koşulup doğrulandı)
- **4b DİLİM 2 BİTTİ — sipariş akışı uçtan uca ekranda:**
  - `lib/screens/orders/order_list_screen.dart` — Açık/Teslim/Tümü sekmeli liste (`watchOrders()`
    ekrandan ayrı, müşteri adı LEFT JOIN, en yeni önce), durum ikonu, tutar, salt-okunur FAB kapısı.
  - `lib/screens/orders/order_form_screen.dart` — yeni sipariş: müşteri seçici (Dilim 1'in son-10
    telefon arama kuralını AYNEN kullanır), katalogdan ürün ekleme (aynı ürün ikinci kez seçilince
    adet artar), **serbest satır** (katalogda olmayan tek seferlik iş; ürün kaydı OLUŞTURMAZ),
    adet ±, canlı toplam, not. **Ödeme tipi BURADA sorulmaz** — teslimde sorulur.
  - `lib/screens/orders/order_detail_screen.dart` — satırlar/toplam/durum + **teslim kapatma**
    (`OrderRepository.deliver`) ve iptal. Ödeme tipi alt sayfası: nakit/kart/havale + **müşteri
    varsa** veresiye/kupon. Kuponda "N adet düşer · kalan M" gösterilir, M<0 kırmızıdır ama
    **teslim REDDEDİLMEZ** (BRIEF: teslim edilmiş mal gerçektir).
  - `lib/screens/products/product_list_screen.dart` — Menü → **Ürünler** (ekle/düzenle/pasifle).
    Gerekçe: taze kurulumda bayinin hiç ürünü yok, sipariş ekranı onsuz kullanılamazdı (ürünler
    senkronla da gelir ama ilk ürünü birinin girmesi gerek). Silme yok, PASİFLEME var.
  - `lib/screens/money.dart` — `formatKurus` (customer_list'ten taşındı) + **yeni `parseKurus`**:
    kullanıcı yazımı ↔ int kuruş sınırı tek yerde. "1.234" TR binlik sayılır; 2 haneden uzun kuruş
    REDDEDİLİR (sessiz yuvarlama yok — para).
  - `home_shell` `_OrdersPlaceholder` KALDIRILDI → gerçek sipariş sekmesi; Menü'ye Ürünler eklendi.
  - Müşteri detayına **"Sipariş oluştur"** düğmesi (telefon çaldı → kart açıldı → sipariş: BRIEF'in
    "birkaç dokunuş" akışı).
- **Doğrulama: `dart analyze` 0 sorun · `flutter test` 109/109 (89 → +20) · debug APK derlendi ·
  `check_permissions_source.sh` temiz (kırmızı çizgi #6 bekçisi).**
- **Yeni testler (`test/ui_dilim2_test.dart`):** parseKurus (TR yazımları + gidiş-dönüş + red
  edilenler), toplamKurus, `teslimOdemeTipleri` (müşterisiz siparişte veresiye/kupon SUNULMAZ),
  saatBicimi, watchProducts (aktif/pasif), watchOrders (3 filtre + join + sıra), **`kuponAdedi`
  ekranla defteri aynı sayıda tutuyor mu** (ekran 5 diyorsa defter −5 yazmalı; eksi bakiye kabul),
  OrderList/ProductList salt-okunur kapıları, sipariş ekranında mağaza-kuralı regresyonu.

### NE YARIM KALDI / AÇIK (bu vardiya)
- **Dilim 3 (sıradaki kod işi): defter/tahsilat/gün-sonu ekranları** — `LedgerRepository`
  (tahsilat/borç/alacak/düzeltme), `CouponRepository` (kupon satışı), `DayEndRepository` (kasa/borç/
  kupon salt-okuma) HAZIR bekliyor; müşteri detayında hareket listesi + "Tahsilat al" ve Menü'de
  "Gün sonu" ekranı gelecek. Sonra Dilim 4 (kurye + kasa devri; tek kişilik bayide GİZLİ).
- **Sipariş düzenleme (satır ekle/çıkar) ekranda YOK** — `addLine`/`removeLine`/`setNote` repoda var;
  bilinçli sadelik: açık sipariş yanlışsa iptal edilip yeniden girilir. Saha isterse Dilim 3'e eklenir.
- **Gerçek cihaz doğrulaması HÂLÂ yapılmadı** (geçen vardiyadan devir): arayan tanıma + Drift v6
  `journal_mode=TRUNCATE`'in native salt-okunur açıcıyla uyumu CİHAZDA görülmedi.
- **PR #11 merge insanda** (artık Dilim 2 commit'leri de dahil). Dışsal işler `YAPILACAKLAR.md`.

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **Sıradaki kod işi = Dilim 3: defter/tahsilat/gün sonu ekranları** (desen aynı: ekran → var olan
   repository → ekrandan ayrı `watch*()` sorgusu → saf async test + widget ilk-çizim testi → APK).
2. **Telefon bağlanırsa öncelik:** `adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`
   → giriş → müşteri ekle → ürün ekle → sipariş gir → teslim et → o numaradan ara (kart çıkmalı) →
   journal_mode/native uyumu. Giriş için API telefondan erişilebilir olmalı (aşağıdaki tuzak).
3. PR #11 merge insanda; dışsal işler `YAPILACAKLAR.md`.

### BİLİNEN TUZAKLAR (bu vardiya)
- **İki geliştirici makinesi FARKLI davranıyor:** Türkçe-yol tuzakları yalnız `Masaüstü` yollu
  makinede geçerli; ASCII yollu makinede `flutter analyze` ve normal `build_runner` çalışır.
  Komut sırasını makineye göre seç, "geçen vardiyada böyleydi" diye körlemesine uygulama.
- **`Order` sınıfı Drift'ten gelir** (`Orders` tablosunun satır sınıfı); `drift.dart`'ı material ile
  birlikte import ederken `hide Column` şart (mevcut desen).
- **Testte `Expression<bool>` üzerinde `&` kullanmak drift import'u ister** — ya `hide Column, Table`
  ile import et ya da (tercih) `..where()..where()` zincirle (drift AND'ler).
- **uuid7 aynı milisaniyede monoton değil** — sıralama testi yazarken kayıtlar arasına birkaç ms
  bekleme koy, `occurred_at` ayrışsın (id yalnız eşitlik bozucudur).

### VARDİYA 2026-07-17/2 (Flutter kurulumu + mobil doğrulama + pano düzeltmesi + 4b DİLİM 1)

**TETİKLEYİCİ:** Kullanıcı "avukat/ödeme olmadan APK alıp test edemez miyiz?" diye sordu. Cevap iki katmanlı çıktı:
(1) Evet, mağaza/hukuk/ödeme TEST İÇİN GEREKMİYOR (onlar satış/mağaza koşulu); (2) ama APK alsak içinde
bayinin kullanacağı EKRAN YOK — her faz "UI sonraki iş" deyip devretmiş, iş hiçbir faza yazılmamış,
pano bu eforu hiç saymıyordu. Pano düzeltildi (%79→%68, "4b · Saha UI" %15 satırı eklendi).

### NE BİTTİ (bu vardiya — hepsi bu makinede koşulup doğrulandı)
- **Flutter 3.44.6 BU MAKİNEYE KURULDU** (`C:\src\flutter`, kullanıcı PATH'inde; SDK zip SHA256 doğrulandı).
  Android SDK zaten vardı; `cmdline-tools/latest` eklendi, lisanslar kabul, JDK = Android Studio JBR 21
  (`flutter config --jdk-dir`). `flutter doctor` temiz (tek eksik VS = Windows masaüstü, gerekmiyor).
- **YAPILACAKLAR madde 2 (mobil doğrulama) KAPANDI — partner bağımlılığı bitti:**
  codegen 62 çıktı (`.g.dart` 1.332 satır EKSİKMİŞ — Faz 4/5a şeması hiç üretilmemişti) →
  `dart analyze` temiz (1 GERÇEK hata bulundu+düzeltildi: `courier_test.dart` ambiguous `isNull`,
  drift import'una `hide isNull`) → **`flutter test` 72/72** → **debug APK uçtan uca derlendi**
  (`build/app/outputs/flutter-apk/app-debug.apk`, 150 MB debug-normal).
- **Türkçe-yol tuzakları çözüldü (yol: `OneDrive\Masaüstü` — ü AOT/LSP/AGP'yi kırıyor):**
  (a) `build_runner` AOT yazamıyor → **`--force-jit`**; (b) `flutter analyze` LSP çöküyor →
  **`dart analyze` kullan** (kalite kapısı scripti buna çevrildi + bilinen Flutter yolunu PATH'e
  ekleyen emniyet); (c) AGP ASCII-yol reddi → `gradle.properties`'e `android.overridePathCheck=true`.
- **Pano dürüstleştirildi:** UI eforu hiçbir fazda yoktu; "4b · Saha UI" %15 eklendi, eski ağırlıklar
  ×0,85; genel %79→%68. Faz 4 mobil testi doğrulandığından ~%85→~%92.
- **4b DİLİM 1 BİTTİ (aynı vardiya, commit `94a2f4a`):** giriş/oturum (`lib/auth/` — token sync_meta'da,
  deviceId ilk girişte üretilip KALICI, çıkış veri silmez), senkron servisi (`lib/sync/sync_service.dart` —
  periyodik 2 dk push+pull + durum akışı), ekranlar (`lib/screens/` — login mağaza-kuralı temiz [kayıt/
  fiyat/₺ YOK, regresyon testli], home_shell 3 sekme + abonelik şeridi + salt-okunur kapısı, müşteri
  liste/arama/ekle/detay). Drift şema v6 (additif). **Doğrulama: dart analyze 0 · flutter test 89/89 ·
  APK derlendi.** Testin bulduğu GERÇEK hata: '0532...' yazımı telefon aramasında eşleşmiyordu → normalize
  düzeltildi. Faz 0 ölçüm ekranı üründe KALDI (Menü → arayan tanıma).
- **Kullanıcıya Dilim 1'li APK teslim edildi** (`apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`);
  demo hesap `demo@sipario.com.tr / demo1234` (sunucuda DemoSeeder ile).

### NE YARIM KALDI / AÇIK
- **4b'nin kalan dilimleri (sıradaki kod işi):** Dilim 2 sipariş ekranları (yeni sipariş, açık liste,
  teslim kapatma — `OrderRepository.deliver` hazır bekliyor) → Dilim 3 tahsilat/defter/gün-sonu →
  Dilim 4 kurye+kasa devri (tek kişilik bayide kurye adımları GİZLİ — BRIEF).
- **Gerçek cihaz doğrulaması yapılmadı:** kullanıcı APK'yı telefonda henüz denemedi (vardiya kapanırken
  bekliyordu). Telefon gelince: `adb install -r` → giriş → müşteri ekle → o numaradan ara → kart çıkmalı.
  Aynı seansta **Drift v6 + journal_mode=TRUNCATE'in native salt-okunur açıcıyla uyumu** cihazda sınanmalı
  (Faz 2'den beri açık risk; şema v6'ya büyüdü, native sözleşme korunuyor ama CİHAZDA görülmedi).
- **PR #11 merge bekliyor** (Faz 3+4+5+6 → main; bugünkü Dilim 1 commit'leri de PR'a dahil — dal dev).
  Kullanıcıya "merge düğmesi"nin ne olduğu anlatıldı; hazır olduğunda basacak (veya "merge et" diyecek).
- **Dışsal işler** `YAPILACAKLAR.md` (madde 2 KAPANDI; iyzico/avukat/imza-anahtarı/mağaza/pilot duruyor).

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **Sıradaki kod işi = Dilim 2: sipariş ekranları.** Yeni sipariş (müşteri seç + ürün satırları — ürünler
   sync'le geliyor, `ProductRepository` hazır), açık sipariş listesi, teslim kapatma (ödeme tipi
   peşin/veresiye/kupon — `OrderRepository.deliver` para+kupon defterini zaten yazıyor). Home_shell'deki
   `_OrdersPlaceholder`'ın yerine gelecek. Desen Dilim 1'dekiyle aynı: ekran → repository → test → APK.
2. **Kullanıcı telefonu bağlarsa (öncelik):** `adb install -r apps/mobile/build/.../app-debug.apk` →
   gerçek cihazda giriş + müşteri + arayan-tanıma + **journal_mode/native uyum** doğrulaması (yukarıda).
   Giriş için API'nin telefondan erişilebilir olması gerek — aşağıdaki tuzağa bak.
3. PR #11 merge insanda; dışsal işler `YAPILACAKLAR.md`.

### BİLİNEN TUZAKLAR (bu vardiya — sonraki kişi dikkat)
- **Mobil komut sırası (bu makine):** kısa yola cd (`/c/Users/bugra/OneDrive/MASAST~1/...`) güvenli;
  codegen `--force-jit` ŞART; analiz `dart analyze` (flutter analyze ÇÖKÜYOR, kapı scripti de dart analyze koşar).
  Tam sıra hafıza dosyasında ve DECISIONS "Türkçe-yol" satırında.
- **Drift + widget-test üç dersi (DECISIONS'a işlendi):** akış-zamanlamalı senaryoyu saf async teste indir
  (`watchCustomers()` bu yüzden ekrandan ayrı); akış-abonelikli db'yi widget-testte `close()` ETME (asılı
  kalıyor); test sonunda ağacı boşaltıp sahte saati ilerlet (bekleyen SnackBar/animasyon sayaçları).
- **Takılan `flutter test`'i öldürünce dart süreçleri yetim kalıyor** ve `build/native_assets/.../sqlite3.dll`
  kilitli kalıp SONRAKİ build'i "cannot access file" ile kırıyor → `Get-Process dart,flutter_tester | Stop-Process -Force`.
- **Telefonda GERÇEK giriş için API'ye erişim gerek:** sunucu şu an yalnız bu makinede. Telefon aynı
  Wi-Fi'deyken `php artisan serve --host 0.0.0.0 --port 8000` ile başlat, telefonda login "Gelişmiş" →
  `http://<PC-yerel-IP>:8000/api/v1`. (Mobil bearer kullanır, CORS tarayıcı işi — engel değil.)
- **`flutter build apk` ilk koşuda uzun** (Gradle+CMake indirir, ~5-8 dk); sonrakiler saniyeler-dakikalar.
- **APK debug-imzalı** — telefona yan yükleme OK, Play'e YÜKLENEMEZ (YAPILACAKLAR madde 3: release anahtarı).
- **`android.overridePathCheck=true` commit'lendi** — ASCII-yollu makinelerde etkisiz, zararsız.

### VARDİYA 2026-07-17/1 (kısa vardiya — PR #11 tazelendi, kalite kapıları bağımsız doğrulandı)

**`main` FAZ 2'DE KALMIŞ — "bekliyor" görünümünün sebebi bu (kullanıcı fark etti, önemli).**
main son olarak PR #10'da (Faz 2) merge edildi; o günden beri **Faz 3+4+5+6 dev'de birikti: 40 commit,
123 dosya, +9.947/−347.** GitHub'da main'deki PLAN.md'ye bakan biri Faz 3–7'yi "bekliyor" görür ve
"kod işi kalmadı" ifadesiyle çelişir sanır — **çelişki yok, iş dev'de duruyor, main'e taşınmadı.**
Bu kafa karışıklığı tekrar etmesin: durum panosunun tek doğru kaynağı **dev'deki** PLAN.md'dir.

- **PR #11 yeniden yazıldı** — başlık "Faz 3 — Defter"di, dal ise Faz 3+4+5+6 taşıyordu; merge kararını
  verecek insan PR'a bakınca kapsamı YANLIŞ görüyordu. Yeni başlık/gövde: faz faz kapsam, 6 kırmızı
  çizginin kod düzeyinde kanıtı, doğrulama tablosu, bilinçli kapsam-dışı (dışsal) listesi.
  **PR durumu: MERGEABLE / CLEAN, CI iki kontrol de yeşil (test + manifest-lint). Merge düğmesi İNSANDA.**
- **Kalite kapıları bu makinede BAĞIMSIZ koşuldu (geçen vardiyanın iddiası doğrulandı):**
  phpunit **169/169 (587 assertion)** ✓ · pint temiz ✓ · phpstan sv6 **0 hata** ✓.
- **Yeni kod işi YAPILMADI** — çünkü yok: dışsal girdisiz (anahtar/Flutter/cihaz/avukat) iş geçen
  vardiyada tükendi; bu vardiya o iddiayı sınadı ve doğru buldu. Tam döküm `YAPILACAKLAR.md`.

**SONRAKİ KİŞİ:** (1) PR #11 merge edilirse main'deki pano da güncellenir ve "bekliyor" görüntüsü biter.
(2) Sunucuda dışsal-girdisiz iş yok — bir girdi gelince aç: iyzico sandbox anahtarı → ödeme akışı canlı
bağlanır; partnerde mobil codegen → Faz 4/5a kapanır; hukuk [köşeli]+avukat → 5d tamamlanır.

### VARDİYA 2026-07-16 (otonom, 6 ajan iki dalga + inline — HEAD `c4d9a27`, tam test 169/169, ağaç temiz).
Sunucu kodu (Faz 0–5) zaten bitmişti; kalan her şey dışsal. Anahtar/Flutter/cihaz GEREKTİRMEYEN tüm iç
işleri bitirdim + kullanıcı için tam yapılacaklar dökümanı çıkardım. iyzico'ya (anahtarsız doğrulanamaz)
ve mobile (Flutter yok) BİLEREK dokunulmadı.

### NE BİTTİ (bu vardiya)
- **5d hukuk (4 belge, `apps/api/resources/views/legal/docs/*.blade.php`):** mesafeli-satis (9 madde),
  on-bilgilendirme (Yönetmelik m.5), iptal-iade (cayma m.15/1-ğ), kvkk-aydinlatma (m.10/m.11 + veri
  sorumlusu/işleyen). PLACEHOLDER→gerçek Türkçe TASLAK; ⚠️ banner + `[köşeli]` (uydurma YOK) +
  her belgede B2B/tacir için `<!-- HUKUK NOTU: avukat -->`.
- **Faz 6 mağaza paketi (`docs/magaza/`, 5 md, ⚠️ TASLAK):** play-data-safety, play-listing,
  app-store-listing (iOS'ta arayan tanıma YOK açıkça), inceleme-notlari (demo hesap + "kayıt yok yalnız
  giriş" Apple 3.1.3-f/Play gerekçesi + FULL_SCREEN_INTENT beyanı + video PLACEHOLDER), README.
- **Google Play ZORUNLU hesap-silme sayfası (KOD+TEST):** `/hesap-silme` route (`account.deletion`) +
  view (`legal/hesap-silme.blade.php`) + `AccountDeletionPageTest` 2 test. Mağaza URL'leri bağlandı
  (silme URL + gizlilik = `/sozlesme/kvkk-aydinlatma`). İletişim/süre hâlâ [köşeli].
- **Kırmızı çizgi #6 regresyon bekçisi (KOD+CI) — audit bulgusu:** `check_permissions.sh` hiçbir CI'a
  bağlı değildi (DECISIONS "CI'da çalışır" diyordu, yanlıştı). İki katman kuruldu: `check_permissions_source.sh`
  (Flutter'sız kaynak-manifest denetimi, pozitif kontrolle doğrulandı: enjekte edilen `READ_PHONE_STATE`→exit 1)
  + `.github/workflows/manifest-lint.yml`. Merged-manifest katmanı mobil CI'a devredildi.
- **Uçtan-uca DENETİM (6 ajan: legal-reviewer + audit-phases + audit-redlines + audit-external-deps +
  legal-drafter + store-writer):** Faz 0–7 kod-belge örtüşüyor (uydurma yok), 6 kırmızı çizgi kod düzeyinde
  KANITLANDI, kritik açık yok. Düzeltilen tutarsızlıklar: pano %79/%80→%79; test sayısı 167→**169/169**
  (koşuldu, 587 assert, pint+phpstan sv6 0). Yeni dışsal bulgular: **Android release imza anahtarı**
  (build.gradle.kts TODO — debug-imzalı), **Mac/Xcode**, **e-arşiv sağlayıcı** (kodda yok), **VERBİS kaydı**.
- **`YAPILACAKLAR.md` OLUŞTURULDU** (kullanıcı talebi): proje sahibinin TÜM insan/dışsal işleri tek dökümanda,
  öncelikli (🔴/🟡/🟢), her kalemde NE/NEDEN/NASIL/kanıt + kırmızı-çizgi güvence bölümü. **Dışsal işlerin
  ARTIK KANONİK KAYNAĞI bu dosya.**

### NE YARIM KALDI / AÇIK (bu vardiya — tümü DIŞSAL, ayrıntı `YAPILACAKLAR.md`)
- **iyzico** gerçek sandbox/üretim anahtarı + `verify()` retrieve/imza GERÇEK testi (⚠️ smoke yetmez). BİLEREK dokunulmadı.
- **Mobil (Faz 4+5a)** codegen+analyze+test partnerde (Flutter yok, `.g.dart` STALE).
- **Hukuk** [köşeli] alanlar + avukat onayı; **mağaza** hesap/imza-anahtarı/video/görsel; **Faz 7** pilot.

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. **Önce `YAPILACAKLAR.md`'yi oku** — dışsal işlerin tam öncelikli dökümü orada.
2. Sunucuda test-edilebilir, dışsal-girdisiz yeni kod işi KALMADI (bu vardiya tükendi). Bir dışsal girdi gelince aç:
   (a) **iyzico sandbox anahtarı** → ödeme akışı canlı bağlanır + güvenlik testi koşulur;
   (b) partnerde **mobil codegen** → Faz 4/5a kapanır; (c) **hukuk [köşeli]+avukat** → 5d tamamlanır.
3. İstenirse **PR #11 (dev→main)** — o günden beri dev ilerledi, güncel dev'den yeniden gözden geçir.

### BİLİNEN TUZAKLAR (bu vardiya — sonraki kişi dikkat)
- **`YAPILACAKLAR.md` bu vardiyada eklendi** — dışsal iş listesi artık orada; PLAN "SENİN SIRAN" özet, tam liste YAPILACAKLAR'da (senkron tut).
- **Merged-manifest bekçisi HÂLÂ yok** — yalnız kaynak-manifest katmanı CI'da; 3. parti enjeksiyonunu ancak `check_permissions.sh` (gradle build) yakalar, mobil CI ile gelecek.
- **iyzico `initiate()` buyer/basketItems eksik** — alıcı adı/telefon/kimlik DTO'da yok; doldurmak Subscribe akışını değiştirir + anahtarsız doğrulanamaz → PARK (anahtar gelince sandbox'la yapılır).
- **Elle commit push-lag** — bu vardiya her commit kendi turunda push'landı (temiz); Stop hook'un push'una bel bağlama, `git rev-parse HEAD == origin/dev` ile teyit et.

### VARDİYA 2026-07-15 (önceki — Faz 4+5 KOD TAM)
Faz 4 (Kurye) + Faz 5 (Para) SUNUCU KODU TAMAM ve incelemeden geçti; 5d hukuk iskeleti + Faz 6 demo
hesabı kuruldu; CI YEŞİL (167/167).

### NE BİTTİ (sunucu, doğrulandı — phpunit 167/167, pint temiz, phpstan sv6 0, CI yeşil)
- **Faz 4 — Kurye (API):** olay-kaynaklı sipariş ATAMA (deterministik `(occurred_at,id)` türetme — sunucu+istemci simetrik), TESLİM İDEMPOTENSİ (deterministik uuid5 → iki cihaz offline teslim = TEK defter seti), KASA DEVRİ (append-only `cash_handovers`), nakit atfı (`collected_by_user_id`). Toplu inceleme YEŞİL.
- **Faz 5 — Para (sunucu tam):** 5a abonelik kilidi (`sync/push` enforcement, `locked_at` çıpası, durum yayını; okuma/pull ASLA kilitlenmez); 5b site+iyzico soyutlaması + **GÜVENLİK sertleştirme** (verify FAIL-CLOSED — forged-body bedava-abonelik açığı kapatıldı + tutar koruması); 5c-1/5c-2 yönetim paneli (`sipario_panel` salt-okunur DB rolü — panel iş verisini FİZİKSEL yazamaz; istatistik/export/modül/şifre-sıfırlama/cihaz); geri-dönen bayi web login. Faz 5 toplu inceleme YEŞİL.
- **5d hukuk İSKELET:** 4 belge şablonu (mesafeli satış/ön bilgilendirme/iptal-iade/KVKK) + `/sozlesme/{doc}` route + checkout onay linkleri (metinler PLACEHOLDER).
- **Faz 6 demo hesabı:** `DemoSeeder` — içi dolu AKTİF demo bayi (`demo@sipario.com.tr` / `demo1234`), 4 TELEFONLU müşteri (arayan-tanıma demosu) + defter; `php artisan db:seed --class=DemoSeeder`.
- **CI düzeltildi:** `sipario_panel` rolü CI workflow'una eklendi (migration 504 patlıyordu). Her şey origin/dev'de, **PR #11 (dev→main) Faz 3+4+5'i taşıyor — merge İNSANDA.**

### NE YARIM KALDI / AÇIK (tümü DIŞSAL — "SENİN SIRAN" listesi başta)
- **Mobil (Faz 4 + 5a) DOĞRULANMADI** — bu makinede Flutter yok; `.g.dart` STALE. **Partnerin Flutter makinesinde codegen + analyze + test şart.** Faz 4/5 bu yüzden BÜTÜN olarak kapanmadı.
- **iyzico** gerçek sandbox/üretim anahtarı + `verify()` retrieve/imza'nın GERÇEK testi (⚠️ güvenlik — smoke yetmez).
- **Hukuk metin prose'u** (5d iskelet hazır, tam metin + avukat onayı insan işi).
- **Faz 6** mağaza hesapları/başvuru + **Faz 7** pilot (saha).

### SONRAKİ KİŞİ NEREDEN DEVAM ETMELİ
1. İstersen **PR #11'i incele/merge** (Faz 3+4+5 main'e).
2. Tek bir dışsal girdiyle ilerlet: (a) **iyzico sandbox anahtarı** ver → gerçek ödeme akışı bağlanır+test edilir; (b) partnere **mobil codegen** koştur → mobil doğrulanır, Faz 4/5 kapanır; (c) **hukuk prose'unu** ver → 5d tamamlanır.
3. Sunucuda test-edilebilir yeni kod işi kalmadı; Faz 6/7 çoğunlukla insan/saha.

### BİLİNEN TUZAKLAR (sonraki kişi bunlara dikkat)
- **Flutter yok bu makinede** → mobil test/codegen partnerde. Şema değişince `.g.dart` stale kalır.
- **php PATH'te yok:** `/c/laragon/bin/php/php-8.3.30-Win32-vs16-x64/php.exe` + `-d extension=pdo_pgsql -d extension=pgsql -d extension=zip`. Docker: `docker start sipario_db`.
- **`sipario_panel` rolü küme düzeyinde** (docker init `10-roles.sh` yalnız İLK initdb'de koşar) → yeni makinede ELLE kur; CI'a eklendi (bu vardiya). Şifre `sipario_panel_dev` (phpunit.xml).
- **Elle commit push-lag:** ajan elle commit atınca origin geride kalır → "başlamamış mı?" yanılgısı. HER ZAMAN git tip'e bak; gerekirse `git push origin dev`. (Öneri: elle commit'i kendi turunda pushla.)
- **iyzico callback CSRF-muaf** → `verify()` gövdeye ASLA güvenmemeli (fail-closed kuruldu); anahtar gelince retrieve+imza gerçekten test edilmeli.
- **Drift codegen:** sqlite3 override `<3.0.0` (DECISIONS Faz 3); `.env*` araç-korumalı → `DB_PANEL_USERNAME/PASSWORD` elle eklenmeli.
- Ayrıntı: DECISIONS "Faz 4 — *", "Faz 5 — *", "Faz 5c — CI", "Faz 5d", "Faz 6 — hazırlık".

- **FAZ 3 — DEFTER KAPANDI (kod + test + kalite/güvenlik incelemesi bitti, HEPSİ YEŞİL).**
  Architect'in tasarımı (DECISIONS "Faz 3 — mimari") uygulandı; uygulama kararları DECISIONS
  "Faz 3 — uygulama (coder)"da. Para İMZALI çift-satır (debit+borç / payment−borç, ödeme tipiyle);
  kupon ADET (`coupon_movements` append-only + `coupon_balances` önbellek); gün sonu salt-okuma read-model.
- **İNCELEME SONUCU: YEŞİL — kırmızı çizgi ihlali YOK (reviewer, DECISIONS "Faz 3 — inceleme").** Beş
  kırmızı çizgi kod üzerinden tek tek doğrulandı: kiracı izolasyonu (kupon tablolarında ENABLE+FORCE RLS,
  bileşik `(tenant_id,reverses_*)` self-FK, TÜM yabancı id'lerde — customer/product/order/reverses —
  simetrik RLS-kapsamlı referans doğrulaması), append-only (coupon_movements DB seviyesinde UPDATE/DELETE
  REVOKE, düzeltme yalnız ters kayıt), offline-first (teslimat/kupon çoklu-yazım tek transaction atomik,
  kupon eksi bakiye reddedilmez), KVKK (sıfır PII log), para (her yerde int kuruş). Tester "gözlem B"si
  (ödeme düzeltmesi kasayı düzeltemiyor) inceleme sırasında coder+architect'çe kök nedenden kapatıldı,
  reviewer'ca doğrulandı. Bağımsız doğrulama reviewer'ca bu makinede TEKRAR koşuldu — hepsi yeşil.
  - **Sunucu (apps/api):** 5 migration (301 ledger alter: payment_type/reverses_entry_id + entry_type
    CHECK daralt + unique(tenant_id,id); 302 orders payment_type +kupon; 303 coupon_movements/
    coupon_balances; 304 RLS phase3; 305 coupon_movements REVOKE). Modeller `CouponMovement`/
    `CouponBalance` + `LedgerEntry` genişledi. `ChangeApplier::applyLedger` (işaret doğrulama +
    payment_type + reverses) + yeni `CouponChangeApplier` + `SyncService` snapshot. `SyncPushRequest`
    beyaz listesi `coupon`/grant/use/correction.
  - **İstemci (apps/mobile):** Drift v2→v3 additif migration (LedgerEntries +paymentType/reversesEntryId;
    CouponMovements/CouponBalances yeni). `lib/repo/ledger_ops.dart` (transaction'sız saf yazımlar),
    `LedgerRepository` (tahsilat/borç/alacak/düzeltme), `CouponRepository` (kuponSat/kuponDuzelt),
    `OrderRepository.deliver` genişledi (para/kupon deftere), `DayEndRepository` (kasa/borç/kupon salt-okuma).
    `sync_engine` coupon_movement/coupon_balance apply + ledger yeni kolonlar.
  - **Doğrulama (coder + tester turu, bu makinede koşuldu):** API → pint ✓ · phpstan sv6 **0 hata** ✓ ·
    phpunit **83/83, 310 assertion** ✓. Mobil → `flutter analyze` **0 sorun** ✓ · `flutter test` **52/52** ✓.
    (Faz 2 + Faz 3: peşin çift-satır, işaret doğrulama, kupon satış/kullanım/eksi-bakiye, cross-tenant kupon
    reddi, correction+payment_type kasa telafisi, gün sonu; tester derinleştirmesi + B düzeltmesi dahil.)
  - **TESTER B GÖZLEMİ UYGULANDI (architect onayı):** payment düzeltmesi artık kasayı da düzeltir. Kasa =
    `payment_type IS NOT NULL` kayıtların −amount toplamı (payment+correction, entry_type saymaz);
    `correction` payment_type taşıyabilir ve ters çevirdiği payment'ın tipini KOPYALAR → bakiye VE kasa
    telafi kaydıyla birlikte düzelir (BRIEF "kasa kuruşuna kuruşuna"). validateLedgerEntry payment_type'ı
    payment+correction'da kabul eder (debit/credit YASAK); kasaOzeti invariant'a geçti; LedgerRepository.
    duzeltme reversed kaydın payment_type'ını kopyalar. Ayrıntı DECISIONS "Faz 3 — uygulama".
  - **ORTAM NOTU (Faz 3'te yaşandı):** codegen sqlite3 override sınırı `<3.0.0` olmalı (eski `<3.3` artık
    kırılıyor — 3.2.0 sonradan build-hook kazandı; hook'suz son 2.9.4). pubspec notu düzeltildi.
  - **BİLİNEN AÇIK / FAZ 4'E DEVİR (Faz 3):**
    - **Sipariş-düzeyi teslim idempotensi yok:** iki cihaz aynı siparişi offline teslim ederse iki
      bağımsız ledger seti (çift debit/payment) üretir — append/birleşme deseninin doğal sonucu (kupon
      çifte-harcamayla simetrik, BRIEF kabul); düzeltme ters kayıtla kapanır. Çift-dokunma koruması +
      kalıcı kasa mutabakatı Faz 4 (kurye kasa devri) kapsamında ele alınmalı.
    - Gün sonu Faz 3'te SALT-OKUNUR read-model; **kurye kasa DEVRİ (kalıcı mutabakat kaydı) + atama Faz 4.**
    - Drift `journal_mode=TRUNCATE` native salt-okunur açıcı için ayarlı ama **gerçek cihazda
      doğrulanmadı** (WAL riski — architect B.4); Faz 6 native entegrasyonunda sınanmalı (Faz 2'den devam).
    - UI minimal/yok; repository katmanı hazır, ekranlar sonraki iş.
  - **SONRAKİ KİŞİ BURADAN DEVAM ETSİN:**
    1. İstenirse **dev→main PR** ("PR aç" de) — Faz 2+Faz 3'ü main'e taşır (merge insanda). Test + inceleme
       kapandı, kalite kapısı yeşil; PR'a hazır. (Faz 2 çekirdeği henüz main'e gitmediyse aynı PR'da gider.)
    2. Sonraki kod işi = **Faz 4 — kurye** (atama, teslim kapatma, kasa devri, +iOS başlangıcı); defter +
       append-only + kupon altyapısı hazır, teslim idempotensi + kalıcı kasa mutabakatı bu fazda kurulur.

- **FAZ 2 OFFLINE ÇEKİRDEK KAPANDI — kod + test + kalite/güvenlik incelemesi bitti, HEPSİ YEŞİL.**
  Architect'in tasarımı (DECISIONS "Faz 2 — mimari") uygulandı; uygulama kararları DECISIONS
  "Faz 2 — uygulama (coder)"da. Test derinleştirmesi + inceleme + düzeltmeler aynı vardiyada kapandı.
- **İNCELEME SONUCU: YEŞİL (şartlı kapanış).** Kırmızı çizgiler tek tek doğrulandı — kiracı
  izolasyonu (11 tabloda ENABLE+FORCE RLS, güvenli varsayılan, bileşik FK, tenant_id oturumdan,
  cross-tenant referans doğrulaması), offline-first (outbox+yerel yazma tek transaction,
  client_event_id idempotency, FOR UPDATE monoton seq, olay bazında savepoint izolasyonu, veri
  kaybı senaryosu yok), KVKK (API'de sıfır PII log), para (her yerde int kuruş). 3 bulgu düzeltildi
  (aşağıda). Ayrıntı DECISIONS "Faz 2 — güvenlik/kalite incelemesi".
- **DÜZELTİLEN BULGULAR (inceleme turu):**
  1. **KRİTİK — append-only DB seviyesinde zorlanmıyordu (kırmızı çizgi #2):** 210 migration'ı
     `sipario_app`'e ledger_entries/order_events'te de UPDATE/DELETE veriyordu → append-only yalnız
     kod disipliniyle korunuyordu. Yeni migration `2026_07_13_000211_revoke_writes_on_append_only`:
     `REVOKE UPDATE, DELETE` (ledger_entries, order_events, sync_changes, processed_events;
     tenant_sync_state hariç — seq UPDATE'lenir). Yeni test `AppendOnlyLedgerTest` 42501
     permission-denied'i kanıtlıyor. FORCE RLS felsefesiyle simetrik askı.
  2. **Tester bulgusu:** order_lines.product_id / ledger_entries.related_order_id'de cross-tenant
     referans doğrulaması eksikti → `ChangeApplier` customer_id ile simetrik RLS-kapsamlı kontrol
     eklendi, kalıcı reddetme testleri.
  3. **Kalite:** `ChangeApplier.php` 516 satırdı (500 sınırı aşımı) → üçe bölündü
     (`ChangeApplier` 270 / `OrderChangeApplier` 238 / `SyncPayload` 40). İzlenen 0-baytlık kök
     kabuk artıkları (`'`,`true`,`Xiaomi`,`cursor`,`bölümünü`) `git rm` ile temizlendi.
- **Sunucu (apps/api):** 10 migration (`customers`, `customer_phones`, `customer_addresses`,
  `products`, `orders`, `order_lines`, `order_events`, `ledger_entries` + senkron altyapısı
  `tenant_sync_state`/`sync_changes`/`processed_events`) + Faz 2 RLS migration (11 tabloya
  ENABLE/FORCE + politika). 8 model (HasUuids, casts, @property). `SyncService` (push: FOR UPDATE
  seq kilidi, idempotency, olay bazında savepoint; pull: snapshot/delta) + `ChangeApplier`
  (LWW / append / sipariş olayları). `SyncController` + `SyncPushRequest`/`SyncPullRequest` +
  route'lar `POST/GET /api/v1/sync/push|pull`. `Provisioning` tenant_sync_state satırı ekler.
- **İstemci (apps/mobile):** Drift şeması (`lib/data/tables.dart` + `app_database.dart`, `.g.dart`
  COMMIT'li) — sunucu aynası MİNUS tenant_id, `sipario.db`/`customers`/`customer_phones`/
  `phone_last10` native sözleşmesi korundu. Outbox + sync_meta. UUIDv7 (`lib/data/ids.dart`).
  Repository'ler (`lib/repo/`: müşteri/ürün/sipariş — yerel yazma + outbox aynı transaction).
  Sync motoru (`lib/sync/`: `SyncApi` arayüz + HTTP impl, `SyncEngine` push/pull + apply +
  istemci çakışma kuralı).
- **Doğrulama (test + inceleme turu sonrası, reviewer tarafından bu makinede BAĞIMSIZ koşuldu — HEPSİ YEŞİL):**
  API → pint ✓ · phpstan seviye 6 **0 hata** ✓ · phpunit **66/66, 246 assertion** ✓ · composer audit CVE yok
  (Faz 1'in 37'si + Faz 2: tester'ın derinleştirdiği `SyncTest`/`TenantIsolationTest` cross-tenant &
  senkron sözleşme testleri + reviewer turunun `AppendOnlyLedgerTest` 9 testi; `RouteCoverageGuard`
  sync uçlarını kapsar).
  Mobil → `flutter analyze` **0 sorun** ✓ · `flutter test` **38/38** ✓ (tester +3: outbox atomikliği,
  UUIDv7 üretimi; repository + sync motoru + db smoke + Faz 0).
- **ORTAM NOTLARI (Faz 2'de yaşandı, sonraki kişi için):**
  - API: `larastan/phpstan` bu checkout'ta vendor'da YOKTU; `php -d extension=zip
    /c/ProgramData/ComposerSetup/bin/composer.phar install` ile kuruldu (lock'ta vardı).
    Test/analiz komutları Faz 1'deki gibi `php -d extension=pdo_pgsql -d extension=pgsql
    -d extension=zip ...`. Docker `sipario_db` konteyneri `docker start sipario_db` ile ayağa kalktı.
  - Mobil: **Drift codegen Dart 3.10'da `dart run build_runner`ı kırıyor** (`sqlite3>=3.3` ve
    `objective_c` native hook'ları). `path_provider` kaldırıldı (objective_c gitti), üretilmiş
    `.g.dart` commit'lendi. Şema DEĞİŞİRSE: pubspec sonundaki kapalı `dependency_overrides:
    sqlite3 <3.3` bloğunu geçici aç → `flutter pub get && dart run build_runner build` → override'ı
    yine kapat → `flutter pub get`. `flutter test`/runtime override KAPALI ister (sqlite3 3.4).
- **BİLİNEN AÇIK / SONRAKİ KİŞİYE:**
  - `ledger_entries` şeması + sync hattı kuruldu; defteri ÜRETEN iş akışları (veresiye/kasa/kupon/
    gün sonu) **Faz 3**. Faz 2'de yalnız minimal `ledger.entry` kabulü + bakiye önbelleği tazeleme var.
  - Drift `journal_mode=TRUNCATE` native salt-okunur açıcı için ayarlandı ama **gerçek cihazda
    doğrulanmadı** (WAL riski açık — architect B.4). Faz 6 native entegrasyonunda sınanmalı.
  - Native arayan-tanıma tarafı Faz 2'de dokunulmadı; `customers.address` → `customer_addresses`
    normalizasyonu yapıldığından native adres okuması (varsa) ayrı sorguya taşınmalı (Faz 6).
  - UI minimal/yok (architect: "UI ayrıntısı sonraki iş"); repository katmanı hazır, ekranlar sonra.
- **SONRAKİ KİŞİ BURADAN DEVAM ETSİN:**
  1. İstenirse **dev→main PR** ("PR aç" de) — Faz 2 çekirdeğini main'e taşır (merge insanda).
     Faz 2 test + inceleme kapandı, kalite kapısı yeşil; PR'a hazır.
  2. Sonraki kod işi = **Faz 3 — defter** (veresiye/kasa/kupon/gün sonu); şema+sync hattı hazır,
     ledger append-only artık DB seviyesinde kilitli (düzeltme yalnız ters kayıtla — Faz 3 buna göre).
  3. Faz 2 açık devirleri (aşağıdaki "BİLİNEN AÇIK"): gerçek `HttpSyncApi` network testi
     (FakeSyncApi ile test edildi), Drift journal_mode gerçek cihaz doğrulaması (Faz 6), UI ekranları.
- Faz 1 tamamen kapalı (güvenlik denetimi dahil); Faz 0 GO (şartlı). Ayrıntı DECISIONS.md.

## Faz 1 — yapılan işler (hepsi ✅)

1. ✅ `docker-compose.yml`: Postgres 16, TR locale (ICU), adlandırılmış volume, port 55432
2. ✅ `.env.example` + `config/database.php` (pgsql=app rolü, pgsql_owner=migration)
3. ✅ Migration'lar: `tenants`, `users`, `devices` (UUIDv7, istemci üretimli kimlik)
4. ✅ RLS politikaları migration içinde; `app.tenant_id` yoksa sıfır satır + FORCE RLS
5. ✅ Auth: Sanctum, patron/operatör/kurye, cihaz kaydı; login zamanlama yan-kanalı kapalı
6. ✅ Cross-tenant izolasyon matrisi + route kapsam bekçisi; CI'da postgres:16 service
7. ✅ Faz kapısı: izolasyon matrisi yeşil + auth akışı çalışıyor → **Faz 2'ye hazır**

## Faz 2'ye devreden küçük işler

- ✅ larastan/phpstan eklendi (seviye 6, kalite kapısı `vendor\bin\phpstan.bat` bulunca koşar).
- Kalan düşük öncelikli notlar: logout için ayrı izolasyon assertion'ı;
  `personal_access_tokens`'ın bilinçli RLS'sizliği (raw-SQL eklenirse hatırla);
  429 throttle yanıtlarına `server_time` istenirse `AppendServerTime` exception yolunu da kapsamalı;
  kalite kapısının API kontrollerini bu makinede koşabilmesi için php'yi PATH'e + eklentileri ini'ye almak.

## Açık riskler / şartlar (Faz 0'dan devreden)

- `USE_FULL_SCREEN_INTENT` Play beyanı Faz 6'da onay riski taşıyor
- Stok Android gerçek cihazda test edilmedi (emülatörde doğrulandı)
- MIUI izinleri programla doğrulanamıyor; Xiaomi'li bayide kurulum birlikte yapılacak
- 20 aramalık sistematik ölçüm pilotun ilk haftasına devredildi (ölçüm ekranı üründe)

## Ortam gereksinimleri (yeni makine kurulumu)

- Flutter 3.38+, Android SDK (cmdline-tools + lisanslar), gerçek Android cihaz
- PHP 8.3 + Composer, Docker Desktop
- `apps/api/.env` git'te YOK (bilinçli) — `.env.example`'dan kopyala;
  gizli değerler git dışında, elden paylaşılır
- GitHub erişimi: `tnyligokhan/sipario`, çalışma dalı `dev` (main korumalı)

## Devir ritüeli (vardiya sonu)

1. Claude'a: "PLAN.md güncel durum bölümünü ve varsa yeni kararları DECISIONS.md'ye işle"
2. Ağacın temiz olduğunu doğrula (`git status`) — otomatik commit hook'u genelde halleder
3. `git push` gittiğinden emin ol (hook push'u başarısızsa söyler)
4. Yarım kalan iş varsa PLAN.md'ye "yarım kaldı: ..." satırı bırak
