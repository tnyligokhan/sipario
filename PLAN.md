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
> _(**2026-08-09 — ÜRÜN CANLIDA (2026-08-07'den beri) ama pano yüzdesi DEĞİŞMEDİ ve bu bilinçli.**
> Üretim altyapısı (TR VPS + Coolify + TLS + sabit adres) bu panoda hiçbir zaman ayrı bir faz olarak
> sayılmamıştı; Faz 5 ve Faz 7'nin altyapı önkoşuluydu ve pano zaten o fazların kalanını "DIŞSAL
> girdiler" diye işaretliyordu. Canlıya çıkmak **Faz 7'nin (Antalya pilotu) önündeki teknik engeli
> kaldırdı** — pilot artık tünel adresi ezberletmeden başlayabilir; ama pilotun kendisi (gerçek bayi,
> gerçek cihaz, saha) hâlâ yapılmadı, o yüzden Faz 7 ⬜ kalıyor. Yeni bir satır açıp yüzde eklemek
> paydayı şişirirdi: altyapı bir teslim edilebilir değil, teslimatın zeminidir. Ölçüm bu vardiyada
> bizzat koşuldu: mobil **1108/1108** · API **682/682** · phpstan **0** · pint temiz.)_
> _(2026-07-29: pano YÜZDESİ DEĞİŞMEDİ ve bu bilinçli — vardiya yeni faz açmadı, mevcut ürünü
> saha geri bildirimiyle düzeltti ve dört sessiz arızayı kapattı. Faz 4/5'in kalan yüzdeleri
> hâlâ DIŞSAL girdilerde (iyzico anahtarı, mağaza hesapları, gerçek cihaz ölçümü, hukuk).
> Bitmiş işi yeniden saymak paydayı şişirir; ürün olgunlaştı, faz sınırları oynamadı.)_
> _(2026-07-21/3: **UI Dilim 4 BİTTİ — 4b TAMAMEN KAPANDI: kurye listesi sunucudan team bloğuyla,
> Drift v7 users aynası, K2 rol-yetki matrisi, atama UI, kasa devri ekranı, tek-kişilik gizleme;
> mobil 159/159 · API 174/174 · inceleme YEŞİL · APK derlendi · guzzle güvenlik yükseltmesi (4
> Dependabot uyarısı kapandı)**. KODLA YAPILABİLİR İŞ BİTTİ — kalan her şey dışsal/insan:
> YAPILACAKLAR.md + PR #11 merge + gerçek cihaz + pilot.)_

| Faz | Ağırlık | Durum | Katkı |
|-----|---------|-------|-------|
| 0 · Arayan tanıma kanıtı | %7 | ✅ kapandı — **GO KESİN** (20/20 ölçüldü 2026-08-17) | 7 |
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

> **🔴 GÜNCELLEME 2026-08-09 — BU LİSTENİN BEŞ MADDESİ ARTIK GEÇERSİZ.** Aşağıda ✅/❌ ile
> işaretlendiler. Ürün canlıya geçtiği için listenin dünyası değişti: "tünel + saha sunucusu"
> varsayımıyla yazılmış maddeler artık farklı anlam taşıyor. **Bugünün gerçek listesi
> yukarıdaki 2026-08-09 devir notunun "SIRADAKİ İŞLER" bölümüdür.**

- **[✅ KAPANDI — 2026-08-17]** ~~Coolify → Environment Variables denetimi.~~ `APP_KEY` 2026-08-09'da
  kapandı; `MAIL_*` 2026-08-15'te tanımlı ölçüldü ve **2026-08-17'de test sunucusunda gerçekten posta
  gittiği doğrulandı** (yani `log` değil `smtp`); `GEOCODING_DRIVER` + `ROTA_SURUCU=google` çalışır
  durumda. `IYZICO_*` **askıya alındı** (aşağıya bakınız) — denetlenecek bir şey kalmadı.
- **[✅ KAPANDI — 2026-08-15]** ~~Makine dışı yedek kararı.~~ S3 ertelendi; her sabah 08:00'de
  indirme bağlantısı `YEDEK_EPOSTA` adresine postalanıyor. **Tek kalan adım kullanıcıda:
  Coolify'da `YEDEK_EPOSTA` değişkenini tanımlamak** (tanımlanana kadar görev her sabah bilerek
  HATA ile çıkar, sessizce başarılı dönmez).
- **[✅ KAPANDI]** ~~Mobil doğrulama partnerin Flutter'lı makinesinde~~ — **bu makinede Flutter VAR**
  (`C:\flutter`); 2026-08-09'da `flutter test` burada koşuldu: **1108/1108**.
- **[✅ KAPANDI]** ~~`dev→main` PR (#11) merge kararı~~ — birleştirme yapıldı (`86c418b`) ve canlı
  artık `main`'i izliyor. **AMA DİKKAT:** `main` şu an `dev`'den 2 commit geride; her vardiya sonunda
  birleştirme yeniden gerekiyor — bu artık rutin bir adım, tek seferlik karar değil.
- **[⏸️ ASKIYA ALINDI — 2026-08-17, kullanıcı kararı]** ~~iyzico **üretim** hesabı + API anahtarları~~
  ve ~~e-arşiv fatura sağlayıcı~~. **Gündeme alınmaz, sorulmaz** — yeniden açılması ancak yeni bir
  kullanıcı kararıyla olur. Kod tarafı hazır ve fail-closed duruyor; askı kalktığı gün geçerli olacak
  pazarlıksız şart burada saklı: `IyzicoPaymentGateway::verify()` iyzico'ya sunucu-sunucu geri-sorgu +
  IYZWSv2 imza doğrulaması yapmalı, sandbox'ta forged-body reddi ayrıca sınanmalı (smoke-test YETMEZ —
  gövde-güven = bedava abonelik açığı).
- **[Faz 5c ortam]** `sipario_panel` DB rolü küme düzeyinde ELLE kuruldu (mevcut container); **CI/yeni makinede rol SQL'i elle koşulmalı** (Faz 1 sipario_app deseni). `.env`/`.env.example`'a `DB_PANEL_USERNAME=sipario_panel` + `DB_PANEL_PASSWORD=...` eklenmeli (config default'u var, testler yeşil; araç `.env*`'i koruyor).
- **[GÜNCELLEME — TEK SEFERLİK ELLE KURULUM GEREKİYOR]** Güncelleme bandı bağlanmamıştı (2026-07-28 bulgusu, düzeltildi). Ama düzeltme KENDİNİ TAŞIYAMAZ: telefondaki mevcut uygulamada bant kodu ağaçta olmadığı için hiçbir release ona bant gösteremez. **Bir kez elle** yeni CI APK'sını (`saha` release'indeki `saha-arm64.apk`) kurmak gerekiyor; ondan sonrası kendiliğinden yürür. Not: imza uyuşmazlığı çıkarsa (cihazdaki uygulama elle/debug imzalı kurulduysa) tek seferlik sil + kur — veri sunucudan geri gelir.
- **[KONUM — SÜRÜCÜ `kademeli`: GOOGLE ÖNCE, YANDEX GEREKTİĞİNDE]** Kullanıcı kararı 2026-07-29/2 (ilk `coklu` tasarımını geri çevirdi: *"iki sonucu birleştirme; Google ve Yandex ayrı görünsün, doğrusunu ben seçeyim"* + kota gerçeği): her sorgu önce **Google**'a gider; **Yandex yalnız Google BİNA kesinliğinde aday veremezse** ve **günlük tavana kadar** sorulur (`YANDEX_DAILY_LIMIT=900`, global — 1000/gün limiti hesabın tamamına ait, yüz kullanıcı bir günde eritebilir). Sonuçlar **BİRLEŞTİRİLMEZ**: her aday "Google"/"Yandex" etiketiyle ayrı satır, seçim kullanıcıda. Tavan dolunca ya da bir sağlayıcı arızalanınca özellik düşmez; aynı adresin ikinci sorgusu 30 günlük önbellekten döner, kota yalnız ilk soruşta yanar. Bilinen bedel (konuşuldu): Google YANLIŞ binayı gösterirse kademe tetiklenmez, Yandex'in muhtemelen doğru adayı görünmez.
- **[✅ KAPANDI — 2026-08-17, kullanıcı doğruladı]** ~~GOOGLE ANAHTAR KISITLAMASI~~ — anahtarlar **IP ile
  kısıtlandı**, sohbete sızmış anahtarın serbest kullanımı kapandı. Geocoding API ve Routes API aynı
  projede (`142583979849`) etkin ve ölçülmüş (auto-route `engine:"google"` döndü). Kullanılan anahtar
  ikinci anahtar; ilk anahtar (proje `42963591866`) terk edildi. **Bu madde bir daha listeye alınmaz.**
- **[KONUM — KAPI NUMARASI BORCU KAPANDI ✅]** Ölçüldü: `"Şirinyalı Mah. 1497. Sk. No: 9"` → Google **`ROOFTOP`, `partial=false`** ile kapıyı BULDU (36.86004,30.73569); Yandex aynı sorguda hâlâ sokağa düşüyor (36.86318,30.73490). Yani `kapiNumarasiniAt` geri çekilmesini ortak koda taşımaya **gerek yok** — Google'ın kendi davranışı yeterli. Borç kapandı.
- **[KONUM — KVKK]** Adres metni sınır dışına çıkıyor ve artık **İKİ ülkeye birden**: Yandex (Rusya) + Google (ABD). Ad/telefon/müşteri kimliği ÇIKMIYOR (uç nokta kabul etmiyor, testle kilitli) ama **KVKK aydınlatma metnine "adres bilgisi coğrafi kodlama amacıyla yurt dışı sağlayıcılara aktarılır" satırı eklenmeli** — zaten bekleyen avukat işinin kapsamında. Metin sağlayıcı ADI vermemeli ya da ikisini de saymalı; sürücü bir env satırıyla değişiyor, tek isim yazmak metni bayatlatır.
- **[❌ GEÇERSİZ — YEREL VERİ ONARIMI]** Bu madde `111` kimliğine taşınmış bir yerel demo bayisini
  onarmayı tarif ediyordu. **Kimlik 2026-08-07'de `demo/demo/demo1234`'e geri döndüğü için tarif
  ettiği durum artık yok.** Yerel veritabanında `111` slug'lı bir kabuk kalmış olabilir; zararsızdır,
  canlıyı etkilemez. Tarihsel değeri olan ders korunuyor: **RLS altında `updateOrCreate` idempotent
  DEĞİLDİR** — "önce ara, yoksa ekle" deseni aramanın satırı görebildiğini varsayar.

- **[✅ KAPANDI]** ~~Demo kimliğinin geri alınması borcu~~ — `111/111/1111` → **`demo/demo/demo1234`**
  geri döndürüldü (2026-08-07, `DemoSeeder`). 2026-08-09'da `docs/magaza/inceleme-notlari.md` ve
  `scripts/saha-sunucu.ps1` de aynı değere hizalandı (üç gün boyunca bayat kalmışlardı).
  Not: bu hesabın parolası doğası gereği depoda açıktır — mağaza incelemecisi girebilsin diye.
  Riski parolanın gücü değil **kiracı izolasyonu** sınırlar: hesap yalnız kendi demo bayisini görür.
- **[⏸️ ASKIYA ALINDI — 2026-08-17, kullanıcı kararı]** ~~Apple geliştirici hesabı + D-U-N-S~~ ve
  ~~iOS~~. **Gündeme alınmaz, sorulmaz.**
- **[Faz 6 — AÇIK, zamanı var]** Google Play geliştirici hesabı + **release imza anahtarı (keystore)**
  + mağaza başvurusu; `USE_FULL_SCREEN_INTENT` "çekirdek işlev" beyanı; KVKK aydınlatma + mesafeli
  satış/ön bilgilendirme metinlerinin **hukukça onayı**. (Kullanıcı 2026-08-17: keystore için "henüz
  daha var" — acil değil, ama Play'e yükleme bu satır olmadan yapılamaz.)
- **[Faz 7]** Antalya'da 2–3 gerçek bayi + gerçek Android cihazlar (pilot).

## Fazlar

| Faz | Kapsam | Durum |
|-----|--------|-------|
| 0 | Arayan tanıma kanıtı (gerçek cihazlarda go/no-go) | ✅ **KAPANDI — GO KESİN** (şart 2026-08-17'de düştü: 20/20 ölçüm yapıldı) |
| 1 | Temel: Laravel API, Postgres+RLS, auth, izolasyon test matrisi | ✅ **KAPANDI** (güvenlik denetimi dahil, 2026-07-13) |
| 2 | Offline çekirdek: SQLite/Drift, outbox, senkron motoru, müşteri+sipariş | ✅ **ÇEKİRDEK KAPANDI — test + inceleme yeşil** (2026-07-13) |
| 3 | Defter: veresiye, kasa, ödeme tipleri, kupon, gün sonu | ✅ **KAPANDI — test + inceleme yeşil** (2026-07-14) |
| 4 | Kurye: atama, teslim kapatma, kasa devri (+iOS başlangıcı) | 🔄 **~%92** (API ✅ inceleme ✅ mobil test ✅ 2026-07-17; iOS/gerçek-cihaz açık) |
| 5 | Para: site, iyzico, abonelik kilidi, yönetim paneli | 🔄 **KOD TAM** (sunucu ✅ inceleme ✅ güvenlik ✅); ⏸️ **iyzico ASKIDA (2026-08-17 kullanıcı kararı)** — kalan dışsal: hukuk metinleri |
| 6 | Mağaza+hukuk: Play beyanları, demo hesap, KVKK/mesafeli satış | 🔄 Play ayağı açık (keystore, acil değil); ⏸️ **Apple/iOS ASKIDA (2026-08-17)** |
| 7 | Antalya pilotu: 2–3 gerçek bayi | bekliyor |

> **2026-07-29 (ikinci vardiya) — KONUM İKİ SAĞLAYICIYLA CANLI (`GEOCODING_DRIVER=kademeli`).**
> Nihai tasarım (kullanıcı iki turda şekillendirdi): her sorgu önce **Google**; **Yandex yalnız
> Google bina kesinliğinde aday veremezse** ve günlük tavana kadar (`YANDEX_DAILY_LIMIT=900`,
> global). Sonuçlar **birleştirilmez** — "Google"/"Yandex" etiketli ayrı satırlar, seçim
> kullanıcıda. (İlk `coklu` tasarımı — her sorguda ikisi + birleştirme + mutabakat rozeti —
> aynı gün geri çevrildi; alias duruyor.) Google faturalandırması bağlandı ve CANLI (ikinci
> anahtar, proje `142583979849`). Bulgular: **(kapandı)** Google kapı numarasını buluyor →
> `kapiNumarasiniAt`ı ortak koda taşımaya gerek yok. **(BULUNDU+DÜZELTİLDİ)** Google anlamsız
> sorguya `ZERO_RESULTS` değil `OK` + **"Türkiye"** dönüyordu (ülke merkezi, sınır kontrolünü
> geçiyordu) — ülke/il düzeyi adaylar artık eleniyor (testli, Yandex'e de aynı kural).
> **(AÇIK GÖZLEM)** Yandex olmayan kapı numarasını sessizce başkasına çevirip "bina" diyebiliyor.
> **Kademe canlı ölçüldü:** Google bina bulunca Yandex'e gidilmiyor (sayaç sabit); sokakta
> kalınca Yandex devrede (sayaç +1). **Testler:** API **259/259** · mobil **744/744** ·
> phpstan L6 **0** · pint temiz. **Kalan iş İNSANDA:** anahtarı "Geocoding API" + sunucu
> IP'siyle kısıtla.
>
> **OTO SIRALAMA v2 + HARİTA (2026-07-29, üçüncü iş — iki Ruflo ajanıyla paralel).** Kullanıcı
> istedi: konuma en yakından uzağa mantıklı durak sistemi + açık siparişlerin pinli haritası.
> Sunucu: `start` parametresi (zincir cihaz konumundan başlar; start yoksa eski davranış),
> `RotaMotoru` soyutlaması — **Google Routes API sürücüsü** (`computeRoutes` +
> `optimizeWaypointOrder`, gidiş-dönüş varsayımı, ≤25 ara durak, permütasyon KATI doğrulanır)
> + yakın-komşu yedeği: Google düşerse özellik ASLA 5xx vermez, kontör iki kez yanmaz. Kilit
> penceresinde HTTP yok. KVKK en dar yorum: Google'a yalnız KOORDİNAT gider (sipariş kimliği
> bile gitmez), log'a koordinat yazılmaz. `phpunit.xml`'e test sürücüsü sabitlendi — yoksa her
> test koşusu gerçek Routes'a çıkıp para yakardı. Mobil: `flutter_map 8.3.1` (SAF DART — native
> eklenti değil, bilinçli: platform kanallı paketler bu depoda widget testlerini iki kez kırdı),
> `siparis_harita.dart` ekranı (yalnız açık siparişler, `sort_index` sırasıyla NUMARALI pinler,
> cihaz işareti, "N sipariş konumsuz" bandı, karo sağlayıcı test dikişi — testler ağa çıkmaz,
> boş durumda FlutterMap hiç kurulmaz), sıralamada cihaz konumu `guvenilir` değilse `start`
> gönderilmez + toast "konum alınamadı, ilk duraktan" der. Birincil adres kuralı sıkı: ikincile
> düşülmez (liste/harita ayrışması olmasın). **Canlı ölçüm: auto-route `engine:"google"` döndü —
> Routes API konsol etkinleştirmesi çalışıyor, gerçek yol optimizasyonu devrede.**
> İnceleme turu (bağımsız ajan) sonrası: `throttle:rota` (kiracı başına 5/dk — eşzamanlı yarışın
> maliyet tavanı) · `order_ids distinct` · kapalı siparişler rotaya girmez + toast söyler ·
> permütasyon/ağ-arızası/KVKK-katılık/429 testleri eklendi.
> Ölçüm (son): API **273/273** (+14) · mobil **758/758** (+14) · analyze 0 · release APK derlendi.
>
> **AYRICA — GİRİŞ ARIZASI BULUNDU VE KAPATILDI.** Bayi doğru parolayla giriş yapamıyor, ham
> `SQLSTATE[23505] devices_pkey` görüyordu. Kök neden bir zincirdi: demo kimliği `demo`→`111`
> değişince `DemoSeeder` eski bayiyi göremedi (idempotenslik `slug`a bağlıydı — yani DEĞİŞEN
> alanın kendisine), ikinci bir bayi kurmaya başladı, global `users_email_unique` kısıtına
> çarpıp yarıda kaldı ve **kabuk bayi** bıraktı (tenant + patron var, başka hiçbir şey yok);
> `saha-sunucu.ps1` seeder hatasını `*> $null` ile yuttuğu için bu hiç görünmedi. Kullanıcı boş
> bayiye girdi ve telefonun KALICI `device_id`si eski bayinin satırında olduğu için
> `updateOrCreate` RLS altında satırı göremeyip INSERT'e düştü → birincil anahtar çakışması.
> **Üç düzeltme:** giriş artık cihaz çakışmasında DÜŞMÜYOR (log'a yazılır, 200 döner, başka
> bayinin satırına dokunulmaz) · `DemoSeeder` tek `DB::transaction` içinde koşuyor (kabuk bayi
> imkânsız) · script seeder hatasını ekrana basıyor. **Ders: RLS altında `updateOrCreate`
> idempotent DEĞİLDİR** — "önce ara, yoksa ekle" deseni aramanın satırı görebildiğini varsayar.
> ⚠️ **YEREL VERİ ONARIMI SENDE** — aşağıdaki "İnsan gerektiren işler" listesinde.

> **2026-07-29 (dördüncü iş) — DEMO VERİSİ BURSA OLDU, ADRESLER GERÇEK.** DemoSeeder 11 müşteriyi
> gerçek Bursa adresleriyle kuruyor (8 konumlu — koordinatlar canlı geocoder'dan, bina kesinliği;
> 3 bilinçli konumsuz). Eski veri silinmeden yedeklendi (~/sipario-yedekler/). Canlı doğrulama:
> giriş + Kükürtlü başlangıçlı auto-route → engine:google, 6 açık sipariş. **TELEFONDA ZORUNLU:**
> uygulama verisini temizle (ya da sil-kur) → 111/111/1111 — yoksa eski Antalya kayıtları zombi kalır.
>
> **2026-08-01 (on ikinci iş) — ROTA/HARİTA UX YENİDEN YERLEŞİMİ (rota-ux ajanı).** Başlıkta
> yalnız 'Sırala' kaldı; sekmelerin altına araç şeridi ('Harita' çipi + 'Kurye: Tümü/Ad' süzgeci);
> Oto Sırala HARİTAYA taşındı (alt ortada 'Oto Sırala · N hak', dört kilit gerekçesi tek yerde,
> istek yolda yukleniyor); oto sonrası elle kipi YOK — yeni 'Rota sırası' görünümü (sort_index,
> tutamaçsız), 'Bitti' de artık rota görünümüne döner (eski UX borcu kapandı). Bonus kusur:
> kümeden dışlanan siparişin bayat sort_index'i rota sırasını bozuyordu — küme artık tüm açık
> siparişler. Ölçüm: analyze 0 · mobil **885/885** (+5; lead bağımsız teyit etti).
>
> **2026-08-01 (on birinci iş) — SESLİ DİKTE KURALI TERSİNE + "KURYE ATA" ÇİPİ (iki saha
> düzeltmesi, lead doğrudan).** (a) Dikte: mikrofona basmak TEMİZ SAYFA açar — alandaki eski
> metin diktenin yerine geçer; oturum içindeki esler birikmeye devam eder (iki senaryoyla tarif
> edildi; eski "sonuna ekle" kuralı ve testi çevrildi). (b) Atanmamış AÇIK siparişte liste
> satırına ve detaya soluk "Kurye ata" çipi — eskiden çip yalnız doluyken çiziliyordu ve
> formun "sonra da atanabilir" vaadinin gideceği yüzey yoktu; tek-kişilik ilkesi
> `yetkiler().atama` kapısıyla korunuyor. Ölçüm: analyze 0 · mobil **880/880**.
>
> **2026-08-01 (onuncu iş) — SEKİZ SAHA İSTEĞİ, 5 AJANLI SWARM.** ① Adres alanı 3 satır (dikte
> sonu görünür) · ⑦ sesli dikte YENİDEN: kesinleşen cümleler birikir, alan silinmez, motor kendini
> kapatınca oturum tazelenir · ⑧ barkoda fener (mevcut torch API, paket yok) · ③ çağrı kartında
> açık siparişin yaşı "Hazırlanıyor · 23 dk önce" (Kotlin+Dart iki ayna) · ④ sipariş formuna
> opsiyonel kurye seçimi (mevcut atama yolu) · ⑤ "sıralanacak sipariş yok" kök nedeni: düğme
> yanlış sekmede/süzgeçte de etkindi — artık gerekçeli pasif; boş sekmeye taşınan bayat liste ve
> her build'de yeniden kurulan akış da düzeldi · ② müşteri silme (soft delete + telefon/adres
> cascade tombstone — silinen müşteri çağrı kartında dirilmez) + kara liste (rozet + 3 noktada
> sipariş engeli; ad düzenlemek damgayı ezmez) · ⑥ kapıda iskonto (defterde `discount` tipi;
> kasa 400 görür, gün sonunda "İskonto (kasaya girmedi)" ayrı satır; sunucu doğrulaması kasaya
> sızmayı kapatır). İki ajan oturum limitinde kesildi, SendMessage ile kaldıkları yerden devam.
> Ölçüm (lead, donmuş ağaç): analyze 0 · mobil **878/878** (+80) · API **298/298** (+11) ·
> phpstan 0 · pint temiz · `compileSahaReleaseKotlin` yeşil · release APK kapısı koşuldu.
> KALAN BORÇ: native çağrı kartında kara liste rozeti yok (Flutter tarafı engelliyor, kart geç
> söylüyor); order_queries 610 ve order_list/form 500 sınırı üstünde — bölme ayrı iş.
>
> **2026-07-30 (dokuzuncu iş) — AYARLAR'A "ARAYAN TANIMA" AÇ/KAPA ANAHTARI.** Tercih düz dosyada
> (`sipario_arayan.txt`, tema deseninin aynısı) çünkü kartı çizen Kotlin Flutter'sız okur; CİHAZ-YEREL,
> varsayılan AÇIK, okunamazsa AÇIK. Kapalıyken kart+bildirim+yeniden gösterim susar ama çağrı GÜNLÜĞÜ
> ve cevapsız düzeltmesi çalışır (`CallSessionWatcher kartGoster=false` ile yine başlar); Çağrı
> Simülasyonu anahtardan etkilenmez (kasıtlı deneme). Dart: `ArayanTanimaDeposu` + satır (bölümün ilk
> satırı, alt başlık seçili durumu yazar); Kotlin: `ArayanAyari.kt` + screening service kapısı.
> Ölçüm: analyze 0 · mobil **798/798** (+6) · `compileSahaReleaseKotlin` BUILD SUCCESSFUL · APK kapısı koşuldu.
>
> **2026-07-30 (sekizinci iş) — CANLI KURYE KONUMU (patron haritada herkesi görür).** Google'SIZ:
> Fleet Engine kurumsal/pahalı, Maps SDK gereksiz (CARTO var), Firebase gereksiz — kendi backend +
> mevcut geolocator; YENİ ANAHTAR YOK. Sunucu: `courier_locations` (PK=user_id, kullanıcı başına TEK
> satır — geçmiş tutulmaz, KVKK), RLS'li, `KonumDeposu` arayüzü + bind; `POST /locations/heartbeat`
> (herkes, throttle:konum 6/dk) + `GET /locations/live` (YALNIZ patron, 403 testli; taze ≤3 dk,
> >60 dk listeden düşer — karar sunucuda). Mobil: `KonumBildirici` 30 sn'de bir sessiz tur (dikiş:
> `sessizKonumOku`; hatalar sessiz, koordinat loglanmaz, arka plan izni YOK — ve artık kod da durduruyor:
> paused/hidden/detached'ta sayaç durur, resumed'da oturum varsa döner); patron haritasında kurye
> katmanı (bike ikonu, ad, bayat=soluk "X dk önce", 25 sn tazeleme; rol akıştan, patron değilse API'ye
> hiç çıkılmaz). Üç ajan: api-konumcu · mobil-konumcu · konum-denetci. Denetçi 2 kusuru kendisi düzeltti
> (±0 m sahte kesinlik; tek bozuk alanın listeyi düşürmesi), kapıları bağımsız koştu: API **287/287** ·
> mobil 792 · phpstan 0. Ortam dersi: paralel `artisan test` Postgres max_connections=100'ü doldurup
> PanelTest'i ORTAMSAL kırmızıya boyayabiliyor — önce bağlantı sayısına bak.
>
> **2026-07-30 (yedinci iş) — HARİTA PERFORMANSI + DARK MOD.** Saha: "çok kasıyor" + "dark modda
> renk değişmedi". Kasma: karo istekleri iptal edilemiyordu → `flutter_map_cancellable_tile_provider`
> (kadraj dışı karo isteği anında kesilir). Dark: karo şablonu temayı izler (light_all ↔ dark_all,
> ValueKey ile stil karışması yok, iki tema da testli). Ajan servisi arızalıydı (art arda 500),
> lead doğrudan yazdı. Testler: 771/771 · analyze 0 · APK kapısı koşuldu.
>
> **2026-07-29 (altıncı iş) — HARİTA STİLİ + KONTROLLER.** Karolar CARTO Positron (anahtarsız,
> gri-minimal — OSM'in kırmızı yol/POI gürültüsü bitti, mor pinler öne çıktı; atıf çipi zorunlu ve
> testli). Sağ altta: yakınlaş/uzaklaş · duraklara sığdır · konumum (taze okuma, hata sebebiyle
> konuşur). Testler: mobil 769/769 · analyze 0. APK CI'dan çıkınca telefonda görülecek.
>
> **2026-07-29 (beşinci iş) — ROTA YÖNÜ DÜZELTİLDİ + PİN ÖZET SAYFASI.** Saha raporu: "en uzak 1.
> sırada". Kök neden: destination=origin DÖNGÜSÜNÜN yönü belirsiz — Google ters yönü seçebiliyor.
> Düzeltme: hedef = başlangıca kuş uçuşu EN UZAK durak (ölçüm: 27,6 km → 20,0 km, yön sabit).
> CİHAZDA doğrulandı (adb: gerçek GPS Kestel ±53 m; ekran sırası 5,8→8,3→11,8→13,9→15,9 km,
> harita pinleri 1→5 aynı sıra, ekran görüntülü). Pin özeti: dokun → sheet (durak no + ad, adres,
> kod rozeti, tutar, not; Yol Tarifi birincil · Ara telefon varsa · Sipariş Detayı). Testler:
> API 273 · mobil 764. Kalan: order_queries harita bölümü ayrılıyor (ajanda), anahtar kısıtlaması sende.
>
## Güncel durum

### 🔻 VARDİYA DEVİR NOTU — 2026-08-17/2 — KOD BORÇLARI ERİDİ + SAHADA ÖLÜMCÜL İKİ GÖÇ ARIZASI BULUNDU (mobil 0.25.0 → **0.25.1**, API DEĞİŞMEDİ 1.9.0)

**🔴 BU VARDİYANIN EN ÖNEMLİ CÜMLESİ: `onUpgrade`de İKİ GERÇEK ARIZA VARDI ve ikisi de sahadaki
telefonu ÖLDÜRÜYORDU.** Kod borcu #13 ("yükseltme yolu testi yok") tam olarak bunun için
duruyordu; test yazılır yazılmaz ikisi birden çıktı.

| Arıza | Ne olurdu | Kanıt |
|---|---|---|
| `users.username` adımının ALTER'ı **hiç yazılmamış** (kolon v13'te eklendi, göç adımı yok) | v7+ damgalı cihazda `users` sorgusu çöker → **Kuryeler ekranı, atama, `team` senkronu ölür** | düzeltme geri alınınca `$UsersTable.map` patlıyor |
| `route_credits_monthly` adımı kendini-onarma **kapısının ARKASINDA** | v8 damgalı cihazda kapı erken döner, adım hiç koşmaz → `sync_meta` okunamaz → **uygulama HİÇ AÇILMAZ** | düzeltme geri alınınca `$SyncMetaTable.map` patlıyor |

Düzeltme: iki adım da kapıdan ÖNCEye taşındı. **Testlerin gerçekten yakaladığı ölçülerek
kanıtlandı** — düzeltme geçici olarak geri alındı, iki test kırmızı yandı, geri kondu.

> ⚠️ **KURAL (bir daha ihlal edilmesin):** kendini-onarma kapısı (`if (latest.isNotEmpty) return;`)
> `tenant_settings` arar ve o tablo **v8'de doğar**. Yani **kapıdan SONRA yazılan her adım, v8 ve
> sonrası damgalı cihazlarda ÖLÜDÜR.** Yeni adım yazarken tek soru: "bu adımın koşması gereken
> cihazda `tenant_settings` var mı?" Varsa adım kapıdan ÖNCE yazılır. Gerekçenin tamamı
> `app_database_gocler.dart` başlığında.

**KAPANAN KOD BORÇLARI (altısı da bitti):**

| # | Borç | Sonuç |
|---|---|---|
| 9 | Yetki Matrisi'nin testi yok | **26 satır × 5 senaryoluk veri tablosu + 32 test** (`yetki_matrisi_test.dart` 23 + `ui_rol_kapisi_test.dart` 9 + `support/yetki_matrisi_tablosu.dart`) |
| 10 | 500 satır kuralını 13 dosya çiğniyor | **`lib/` altında 500'ü aşan dosya KALMADI** (tablo aşağıda) |
| 11 | Testlerde sabit yazılmış iş değerleri | `SubscriptionTest` dönem süresi → `BillingPeriod::Yearly->uzat()`; `LiveLocationTest` sınırı → `config('konum.kalp_atisi_limit')` + "sınır genelden DAR olmalı" iddiası (vakuma düşmesin diye) |
| 12 | Flutter SDK ↔ lock sapması | **Sapma ölçülemedi: `dart analyze` 0 issue, lock DEĞİŞMEDİ.** `onReorder` hâlâ kullanımda ve deprecated UYARISI ÇIKMIYOR — kör göç YAPILMADI, madde kapandı |
| 13 | Yükseltme yolu testi | v1/v7/v8 zincir testleri + v19/v20/v21 + `support/migration_yardimcilari.dart` iskelesi; **`semaTamOlmali` sınıf düzeyinde koruma** (yükseltilmiş şema ⊇ taze şema) |
| 14 | CI'da birleştirilmiş manifest denetimi | `mobil-apk.yml`e adım eklendi + `check_permissions.sh`teki **gerçek hata** düzeltildi |

**500 SATIR — ÖNCE/SONRA (hepsi ölçüldü):**

| Dosya | Önce | Sonra |
|---|---|---|
| `home_shell.dart` | 1022 | 461 + durum 99 + gezinme 200 + çağrı 235 + gövde 110 |
| `sync_engine.dart` | 850 | 253 + `sync_cekme` 380 + `sync_itme` 281 |
| `kuryeler_ekrani.dart` | 754 | 340 + `kurye_karti` 226 + `kurye_formu` 230 |
| `order_queries.dart` | 728 | bölündü (`order_musteri_sorgulari` vb.) |
| `phase0_screen.dart` | 663 | 201 + kartlar 267 + test kartı 223 |
| `customer_form_screen.dart` | 559 | 424 + `musteri_formu_eylemler` 162 |
| `tables.dart` | 566 | 272 + `tables_isletme` 312 |
| `app_database.dart` | 546 | 151 + `app_database_gocler` 423 |
| `cekmece.dart` | 541 | 368 + `cekmece_satirlari` 182 |
| `day_end_screen.dart` | 513 | + `gun_sonu_eylemleri` |
| `form.dart` | 512 | 274 + `form_kontroller` 255 |
| `ana_ekran.dart` | 509 | 274 + `ana_ekran_parcalari` 245 |
| `bildirim_sozlesmesi.dart` | 504 | 467 + `sessiz_saatler` 53 |

> **BÖLME YÖNTEMİ (sonraki vardiya aynısını yapsın):** widget'ın kendi başına yaşayabildiği yerde
> AYRI KÜTÜPHANE + `export` ile sözleşme korunur (`kurye_formu`, `form_kontroller`); sınıfın ÖZEL
> durumuna dokunan yüzeylerde `part` + `extension` kullanılır (`home_shell`, `sync_engine`).
> ⚠️ `part`taki extension `setState`i DOĞRUDAN çağıramaz (`@protected`) — kabuk `_durumDegisti`
> kapısını açar. ⚠️ Drift tabloları `part` ile bölünür: ayrı kütüphane 19 bin satırlık üretilmiş
> dosyayı yeniden ürettirirdi; `part` sayesinde **`app_database.g.dart` hiç değişmedi.**

**ÖLÇÜMLER (üç kapı da bizzat koşuldu, ağaç dondurulmuş hâlde):**
- **mobil `flutter test`: 1362/1362 YEŞİL.** ⚠️ Bu sayıyı 1108'le karşılaştırmayın: o ölçüm
  2026-08-09 tarihlidir ve aradaki sekiz günün işini de içerir. **Bu vardiyanın kendi katkısı 38
  yeni testtir** (yetki matrisi 23 + rol kapısı 9 + göç zinciri 3 + v19/v20/v21 üçer bir).
- `dart analyze`: **0 issue** (`onReorder` info'su dahil hiçbir uyarı yok)
- API: `pint` temiz (370 dosya) · `phpstan` **0 hata** · dokunulan iki test dosyası 26/26
- **Birleştirilmiş manifest denetimi KIRMIZI YAKABİLİYOR — kanıtlandı:** `magaza` manifestine
  `READ_SMS` enjekte edildi → betik kanalı isimlendirerek düştü (çıkış kodu 1), sonra geri alındı.
  Gradle görev adı (`:app:processMagazaReleaseManifest`) de yerel olarak doğrulandı.

**🔴 KAYDA GEÇEN BULGU — KARAR KULLANICIDA (düzeltilmedi, testle KİLİTLENDİ):**
`YoneticiKapisi` rol `null` iken **AÇILIYOR** (`rol != 'kurye'`), oysa `yetkiler(rol: null)` en dar
küme olan KURYE'yi veriyor. İki kural aynı soruya farklı cevap veriyor. Bugün açık üretmiyor
(o dört ekrana giden tek yol çekmece ve o da aynı ölçütü kullanıyor), ama kapının VARLIK SEBEBİ
"çekmece atlandığında korumak"tı — derin bağlantıda rol henüz inmemişse koruma yok. Deponun kendi
ilkesi "belirsizlikte AÇILAN değil KAPANAN taraf seçilir" der; hizalamak bir YETKİ değişikliğidir
(MINOR) ve kullanıcı kararı ister. `ui_rol_kapisi_test.dart` mevcut davranışı kilitledi.

**⚠️ AÇIK KALAN:** **14 TEST DOSYASI 500 satırı aşıyor** (toplam 9.214 satır; en büyükleri
`ara_tahsilat_test` 1126 · `ui_siparis_harita_test` 925 · `ui_siparis_test` 862). Kural testlere de
uygulanır; bu vardiya `lib/` tarafını bitirdi, test tarafı ayrı bir iş kolu olarak duruyor.

**⚠️ BU VARDİYADA YAPTIĞIM BİR HATA, KAYDA GEÇSİN:** `cekmece_parcalari.dart`ı **var olan bir dosya
olduğunu kontrol etmeden** üzerine yazdım (2026-08-13'te oluşturulmuştu). Git izlediği için tek
komutla geri alındı, kayıp yok. Ders: bölmede yeni dosya adı seçerken hedefin BOŞ olduğu önce
ölçülür — `ls` bir saniye, kurtarma beş dakika.

**AJAN HATTI ÖLDÜ AMA İŞ DURMADI:** beş ajan (yetki-testci · gocmen · bolucu-ekran ·
bolucu-cekirdek · api-ci) oturum limitine çarpıp aynı dakikada düştü. **İşleri commit edilmemiş
hâlde ağaçta duruyordu** ve yarım bir bölme ağacı kırıyordu (`borclu_karti.dart` veri dosyasını
arıyordu, dosya hiç yazılmamıştı). Lead devraldı, yarımı tamamladı, ölçtü. Ders yine aynı:
**ajan limitte ölünce önce `git status` + `git log` — iş yapılmış olabilir.**

### 🔻 VARDİYA DEVİR NOTU — 2026-08-17 — YEDİ MADDE KAPANDI, DÖRT MADDE ASKIYA ALINDI (kod DEĞİŞMEDİ, sürüm DEĞİŞMEDİ: API 1.9.0, mobil 0.25.0)

**Bu vardiya kod yazmadı** — kullanıcı sahada/panelde biriken işleri bitirdi ve durumu bildirdi;
yapılan iş bunların üç ayrı listede (baştaki "İnsan gerektiren işler", "SIRADAKİ İŞLER — TEK LİSTE",
arşiv 2026-07 listesi) **aynı anda** işaretlenmesidir. Bir yerde kapatıp ötekinde bırakmak, maddenin
bir sonraki vardiyada yeniden "açık" diye karşımıza çıkması demekti — üç listenin biri hâlâ eskisini
söylüyor olurdu.

**✅ KAPANANLAR (kullanıcı doğruladı):**

| Madde | Ne oldu |
|---|---|
| Coolify bildirim kanalı | **Telegram kuruldu**, bildirimler kullanıcının telefonuna düşüyor. Bir çöküşü fark etmek artık ölçüme değil kanala bağlı. |
| Google API anahtarı | **IP ile kısıtlandı** — sohbete sızmış anahtarın serbest kullanımı kapandı. |
| SMTP / e-posta | **Test sunucusunda postalar gidiyor** → `MAIL_MAILER` gerçekten `smtp`, `log` değil. Parola sıfırlama ve günlük yedek postası da aynı yoldan çıkıyor. |
| **Arayan tanıma 20/20** | **Ölçüm yapıldı → FAZ 0'IN ŞARTI DÜŞTÜ, GO KESİN.** BRIEF'in 1 numaralı korkusu ve ürünün varlık sebebi artık doğrulanmış. |
| Deneme APK'sı | **Elle kuruldu ve testleri yapıldı** (`com.sipario.app.test`); bundan sonrası kendini günceller. |
| Coolify Stop → ağ silinir → deploy kilidi | **Çözüldü.** Kurtarma satırı (`docker network create …`) arşivde tarihsel bilgi olarak duruyor. |
| Test ortamında gerçek yol ağı sıralaması | **AÇIK** — `ROTA_SURUCU=google`; yakın-komşu artık yalnız yedek yol. |

**⏸️ ASKIYA ALINANLAR — kullanıcı kararı, YENİDEN GÜNDEME GETİRİLMEZ:**
**iyzico** · **Apple (D-U-N-S + geliştirici hesabı)** · **iOS** · **e-arşiv fatura**.
Bunlar "unutulmuş iş" değil, bilinçli bekletmedir; sıradaki işler listesinden kendiliğinden
tetiklenmezler. Yeniden açılmaları ancak yeni bir kullanıcı kararıyla olur. Tarifleri arşiv
listesinde olduğu gibi duruyor — askı kalktığı gün hazır bulunsun diye.

**🟡 AÇIK AMA ACELESİ YOK:** **Android release keystore** (kullanıcı: *"henüz daha var"*). Release
hâlâ debug anahtarıyla imzalanıyor; Play'e yükleme bu satır olmadan yapılamaz ama başvuru gündemde
değil. **Her vardiyada hatırlatılmaz.**

**🔵 KULLANICIDA KALAN TEK KÜÇÜK İŞ:** Coolify'da **`YEDEK_EPOSTA`** tanımı (kullanıcı: "yapacağım").
Tanımlanana kadar `yedek:baglanti-gonder` her sabah **bilerek HATA ile** çıkar — sessizce başarılı
dönmemesi tasarımdır, arıza değil.

> ⚠️ **BAYAT ÇIKAN İKİ SATIR, ÖLÇÜLEREK DÜZELTİLDİ (belgeye değil koda bakıldı):**
> (1) Arşiv listesindeki **"mobil CI yok"** maddesi aylardır yanlıştı — `mobil-apk.yml` `dart analyze`
> + `flutter test` + imzalı APK + `surum.json` yayınını zaten koşuyor. (2) `kDebugMode` kapısının
> dosya yolu (`ayarlar_ekrani.dart:266`) ayarların beşe bölünmesiyle taşınmış; doğrusu
> `screens/isletme/ayarlar/uygulama_ayarlari_ekrani.dart:138`.

**Sürüm neden artmadı:** kullanıcıya görünen hiçbir davranış değişmedi, tek satır kod yazılmadı.
Sürüm kuralı "kullanıcıya görünen değişiklik" der; burada değişen yalnız belgenin gerçeğe uyumudur.

### 🔻 VARDİYA DEVİR NOTU — 2026-08-16 — LARAGON KALDIRILDI, API TARAFI TAMAMEN DOCKER'DA (sürüm DEĞİŞMEDİ: API 1.9.0, mobil 0.25.0)

**Kullanıcı kararı:** *"Local tarafında Laragon ve Docker kullanıyoruz, bunu istemiyorum; her şey
Docker üzerinde olsun ve Laragon bağımlılığından kurtulalım."* + *"Coolify tarafında bir şeyleri
etkilemesin."*

**⚠️ SÜRÜM ARTMADI VE BU DOĞRU:** kullanıcıya görünen hiçbir davranış değişmedi — bu tümüyle
geliştirici ortamı işidir. Sürüm kuralı "kullanıcıya görünen değişiklik" der; burada görünen
şey yok.

**COOLIFY'A HİÇ DOKUNULMADI (kısıt buydu):** `docker-compose.prod.yml` ve üretim imajı
`docker/php/Dockerfile` **değişmedi**. Dev tarafı yalnız `docker-compose.yml`de yaşıyor.

**LARAGON FİİLEN NE SAĞLIYORDU (ölçüldü):** yalnız **PHP 8.3 CLI + Composer**. Apache/vhost hiç
kullanılmıyordu, Postgres zaten Docker'daydı. Bağımlılık küçüktü ama GÖRÜNMEZDİ ve iki script'e
gömülüydü.

**YAPILAN:**
- `docker-compose.yml`e iki servis: **`php`** (`sleep infinity` ile elde tutulan komut kabuğu) ve
  **`web`** (`artisan serve`, `127.0.0.1:8000`). İkisi AYRI: web bir sözdizimi hatasında ölse bile
  testler ve kalite kapısı çalışmaya devam etsin diye.
- `scripts/api.ps1` (**yeni**) — tek giriş noktası: `artisan · composer · pint · phpstan`.
- `scripts/quality-gate-commit.ps1` — PHP arama bloğu Docker'a çevrildi.
- `scripts/saha-sunucu.ps1` — `Bul-Php` ve `Pgsql-Var` kaldırıldı; migrate/seed/serve container'a taşındı.
- `README.md` — Laragon satırı ve "PHP eklentilerini aç" adımı kaldırıldı, kurulum akışı yeniden yazıldı.
- **Docker tamamen sıfırlandı** (kullanıcı emri): 1 container, 3 volume, 5 imaj, 21 build cache
  katmanı silindi (938 MB), yığın sıfırdan kuruldu.

**ÜÇ TUZAK, ÜÇÜ DE ÖLÇÜLEREK BULUNDU:**
1. **`vendor` named volume ROOT sahipliğinde doğuyor**, container `www-data` koşuyor →
   `composer install` ilk pakette düşüyor. Bu, üretim compose'unda `storage/logs` için zaten
   yazılı olan tuzağın aynısı. **Sonunda named volume tümüyle bırakıldı** (aşağıda).
2. **Port sessizce genişliyordu.** Compose'a düz `"8000:8000"` yazmak paneli yerel ağdaki
   herkese açar; yerini aldığı `artisan serve --host=127.0.0.1` yalnız bu makineye açıktı.
   `127.0.0.1:8000:8000` yapıldı — sahaya açmanın yolu tüneldir, yerel ağ değil.
3. **🔴 MOUNT KAPSAMI DAR OLUNCA 11 TEST DÜŞTÜ.** İlk kurulumda yalnız `apps/api` bağlanmıştı.
   `RolParolaEsitlemeTest` depo kökündeki dosyaları okur (`dirname(__DIR__, 5)` →
   `docker-compose.prod.yml`) ve Laravel'i hiç önyüklemez; container'da depo kökü olmadığı için
   `/var` çıkıyor ve "dosya yok" diyordu. **Ortam, testin denetlediği şeyi görünmez yapmıştı.**
   Düzeltme: depo kökü bağlanır (`./:/depo`), `working_dir: /depo/apps/api`.

> ⚠️ **KENDİ TEŞHİSİMDE BİR KEZ YANILDIM, KAYDA GEÇSİN:** 11 kırığı önce "suite koşarken
> migrate/seed çalıştırdım, rol parolaları çakıştı" diye açıkladım. Temiz koşuda **aynı 11
> kırık** çıktı — açıklama yanlıştı. Ders deponun kendi dersinin tersi yönünde: eşzamanlılık
> bu depoda gerçekten sahte kırmızı üretti (birden çok kez), ama **tanıdık açıklama doğru
> açıklama değildir**; kırığın mesajı okunmadan sebep atanmaz.

**ÖLÇÜMLER (üçü de bizzat koşuldu, tam takım):**

| Ortam | Sonuç | Süre |
|---|---|---|
| Host / Laragon PHP | 868 ✓, 1 atlandı, 1 incomplete | 753 sn |
| Container, dar mount | 855 ✓, **11 kırık** | 740 sn |
| **Container, depo kökü mount** | **868 ✓, 0 kırık**, 1 incomplete | **1007 sn** |

- **Kapsam GENİŞLEDİ:** host'ta *atlanan* 1 test (openssl/Windows) Linux container'da artık
  gerçekten koşuyor ve geçiyor. Atlanan test sayısı 1 → 0.
- **Bedel: %34 yavaşlama** (753 → 1007 sn). Sebebi `vendor`ün Windows bind mount'una düşmesi
  (dar mount + named volume denemesinde 740 sn'ydi). **Bilerek kabul edildi:** kalite kapısı
  `artisan test` koşmuyor (yalnız pint + phpstan, saniyeler sürüyor), tam takım çoğunlukla
  CI'da koşuyor. Rahatsız ederse `vendor`ü named volume'e döndürmek gerekir — ama o zaman
  yukarıdaki 1. tuzak ve "boş volume host vendor'ünü içine kopyalıyor" sorunu ayrıca çözülmeli.
- `pint` temiz (370 dosya) · üç PowerShell script'i sözdizimi denetiminden geçti.

> ✅ **TÜNEL TÜMÜYLE KALDIRILDI (aynı vardiya, kullanıcı kararı):** *"Tünel artık yok, onunla
> alakalı her şey silinebilir."* Yani yukarıdaki "sahada denenmemiş parça" sorunu ortadan kalktı —
> denenecek bir şey kalmadı. **Silinenler:** `scripts/saha-sunucu.ps1` (375 satır) ·
> `scripts/SUNUCU-BASLAT.bat` · `apps/api/storage/logs/tunnel.log`. Script tünelsiz anlamsızdı:
> geriye kalan işleri (docker başlat · migrate · seed) `docker compose up -d` ve
> `scripts/api.ps1` zaten yapıyor.
>
> ⚠️ **`bootstrap/app.php`'DEKİ `trustProxies` SİLİNMEDİ ve SİLİNMEMELİ.** Yorumu cloudflared'i
> anlatıyordu ama ayarın kendisi tünele ait değil: üretim dalı (`production ? '*'`)
> Coolify/Traefik arkasında koşan her istek için gerekli. Kaldırılsaydı `asset()`/`route()`
> mutlak URL'leri `http://` üretir, HTTPS sayfada karışık içerik doğar ve mobil Chrome CSS'i
> koşulsuz engellerdi — sahada birebir yaşanmış bir arıza. Yorum, "bu ayar tünele ait değildir,
> silinmez" uyarısıyla güncellendi.
>
> Saha denemesi artık gerçek sunucuya karşı yapılıyor; yerel web sunucusu yalnız `127.0.0.1`e
> bağlı ve dışarı hiç açılmıyor.

**YEREL VERİTABANI SADELEŞTİRİLDİ (kullanıcı isteği, aynı vardiya):** `migrate:fresh` + seed
sonrası iş verisi boşaltıldı ve fazla hesaplar silindi. Kalan: **1 işletme (`demo`)**,
**1 patron (`demo`)**, **1 kurye (`emre`)**, parola `demo1234`; 2 panel yöneticisi (parolaları
sıfırlandı, kullanıcıya bir kez gösterildi). Müşteri/sipariş/ürün/defter **0**.
⚠️ Bu sadeleştirme YALNIZ VERİTABANINDA — `DemoSeeder` bilerek DEĞİŞTİRİLMEDİ (kullanıcı seçimi),
yani `db:seed` koşulursa 5 kullanıcı ve zengin demo verisi geri gelir. Gerekçe: `DemoSeederTest`
en az 2 aktif + 1 pasif kurye zorunlu kılıyor ve bu veri mağaza incelemecisinin gördüğü veridir.

### 🔻 VARDİYA DEVİR NOTU — 2026-08-15/2 — GÜNLÜK YEDEK BAĞLANTISI POSTALANIYOR (API 1.8.0 → **1.9.0**, mobil DEĞİŞMEDİ 0.25.0)

**Kullanıcı kararı:** *"Yedekleme sunucuda kalsın… bana geri yükleme yapabileceğim bir şekilde
her gün link üretip SMTP ile mail adresine iletsin. Para kazanmaya başlayınca S3 kullanırım."*

**ÖNCE ÖLÇÜLDÜ, BELGEYE GÜVENİLMEDİ:** `PLAN.md`'nin "SMTP kurulu değil" notu **BAYATMIŞ** —
Coolify'da `MAIL_MAILER · MAIL_HOST · MAIL_PORT · MAIL_USERNAME · MAIL_PASSWORD · MAIL_SCHEME`
hepsi TANIMLI (`list_env_keys` ile okundu; değerleri API vermiyor). SMTP hesabı da var:
`titan.hayalhost.com:465`, `noreply@sipario.com.tr`. Yani 4. maddenin ön koşulu zaten kapalıydı.

**YAPILAN:**
- `sipario_backups` volume'ü `app` ve `scheduler`'a **salt-okunur** (`:ro`) bağlandı. Bugüne
  kadar bu dosyalara sidecar DIŞINDA hiçbir şey erişemiyordu — yedek alınıyordu ama
  **alındığı görünmüyor, indirilemiyordu.**
- `App\Yedek\YedekArsivi` — arşivi okur; `coz()` kullanıcıdan gelen dosya adını **üç kapıdan**
  geçirir (basename → sidecar ad deseni → realpath ön eki).
- `panel.yedek.indir` route'u — **yalnız superadmin**, her indirme `panel_audit`e düşer
  (`action=yedek_indirme`, `tenant_id=NULL`, detayda yalnız dosya adı).
- `yedek:baglanti-gonder` komutu + `YedekHazir` postası (HTML + düz metin) — her sabah
  **08:00 Europe/Istanbul**. Postada dosya adı, boyut, tarih, indirme düğmesi ve
  **geri yükleme komutu** var.
- Sürüm: `apps/api/config/app.php` → **1.9.0** (MINOR, mobile tamamen nötr).

**İKİ TASARIM KARARI, ikisi de bilinçli:**
1. **İmzalı link (`temporarySignedRoute`) KULLANILMADI.** Yedek, ürünün en yoğun kişisel veri
   taşıyıcısıdır (tüm bayilerin tüm müşterileri tek dosyada); imzalı bağlantı, e-posta kutusu
   ele geçen birine veritabanının tamamını verirdi. Bağlantı panel girişinin arkasındadır.
2. **Komut sessiz başarı üretmez.** Adres tanımsızsa, arşiv boşsa → çıkış kodu HATA. Yedek
   bayatsa (>30 saat) posta **uyarı bandıyla** gider — sidecar durursa o bant arızanın tek
   görünür işaretidir.

> ⚠️ **SEÇİLEN ÇÖZÜMÜN SINIRI YAZILI OLARAK KABUL EDİLDİ:** yedeğin makine dışına çıkması
> **insanın her gün postayı açıp indirmesine** bağlıdır. Kimse indirmezse sunucu öldüğünde
> yedek de ölür. Bu, otomatik uzak kopyanın (S3) yerini **tutmaz**.

> ⚠️ **HOSTINGER YOLU DENENDİ VE BIRAKILDI.** Kurulum sırasında hosting **SSH parolası sohbete
> düz metin yapıştırıldı** → parola yanmış sayıldı ve değiştirilmesi istendi. SSH anahtarından
> farkı: parola **değiştirilebiliyor**, yani bu sızıntı kapatılabilir bir sızıntıydı.

**ÖLÇÜMLER (bizzat koşuldu):** `YedekTest` **12/12 yeşil** (45 assertion) · **tam API takımı
869 test / 868 yeşil** (4205 assertion; 1 atlandı = openssl/Windows, 1 incomplete = LWW
saniye-altı — ikisi de bu vardiyadan önce de öyleydi, 857→869 artışı bu vardiyanın 12 yeni
testidir) · `pint` temiz · `phpstan` temiz.

⚠️ `phpstan` ilk koşuda **iki gerçek kusur** yakaladı ve biri sessizdi: `CarbonImmutable::
createFromFormat` başarısızlıkta `null` döner, `false` DEĞİL — `=== false` yazılmış savunma
hiçbir zaman çalışmayacaktı. Testler bunu göremezdi (geçerli adlarla koşuyorlar).

⚠️ **TEST DB'Yİ AÇMAK GEREKTİ:** Docker Desktop kapalıydı, suite `Connection refused … 55432`
verdi. Çözüm bilinen desen: Docker Desktop → `docker start sipario_db` (`docker compose up`
DEĞİL).

**İKİ TEST BİLEREK DEĞİŞTİRİLDİ** (`PanelAccessControlTest`): panel route yüzeyi kilitli bir
listedir ve yeni route insan gözden geçirmeden geçemez — `panel.yedek.indir` listeye
gerekçesiyle eklendi. Ayrıca korunan-URL üreteci route tablosundan türetildiği için parametreli
route'a örnek değer verilmesi gerekti; route'u listeden çıkarmak testin varlık sebebini
delerdi.

> ✅ **ÖLÇÜLDÜ VE AÇIKLANDI — ARIZA DEĞİL, KULLANICI KARARI (2026-08-15):** Coolify'da yalnız
> **"Sipario Dev"** var; `main` **2026-08-10'da donmuş** (API 1.0.0, mobil 0.10.0) ve `dev`
> **78 commit** önde. **Kullanıcının cümlesi:** *"Main şu an beklemede! Sunucu tarafında sadece
> test ile devam ediyorum, her şey oturduğunda main'e yani canlıya geçeceğim; geçileceği zaman
> haber ederim."*
>
> **Sonraki vardiyalar için üç sonuç:**
> 1. `main`'in geride olması bir **borç değil, bilinçli bir bekletme**. `dev`→`main` merge'ünü
>    KENDİ BAŞINA yapma — geçiş zamanını kullanıcı söyler.
> 2. Ölçüm ve doğrulamalar **test ortamında** yapılır; "canlıda doğrulandı" diye bir kanıt
>    şu an üretilemez.
> 3. Bu vardiyanın yedek postası da **önce test ortamında** koşacak. Oradaki ilk posta,
>    `MAIL_MAILER`'ın gerçekten `smtp` olup olmadığının da sınavıdır.

### 🔻 VARDİYA DEVİR NOTU — 2026-08-15 — SIZAN SSH ANAHTARI: YEREL KOPYALAR SİLİNDİ, DÖNDÜRME **KULLANICI ONAYIYLA ES GEÇİLDİ (KAPANDI)**

> ✅ **KARAR — 2026-08-15, KULLANICI ONAYI: BU MADDE KAPANDI, BİR DAHA SIRADAKİ İŞLER'E GİRMEZ.**
> Coolify anahtarı **kullanımdayken silmeye izin vermiyor**; döndürme teknik olarak engellendi.
> Kullanıcı riski bilerek kabul etti. **Sonraki vardiyalar bunu yeniden gündeme getirmesin** —
> yeniden açılması ancak yeni bir kullanıcı kararıyla olur.

**Karar (kullanıcı, ortağıyla görüşerek):** Coolify'ın sunucu SSH ÖZEL ANAHTARI daha önce
sohbete düz metin yapıştırılmıştı. Coolify anahtarı **kullanımdayken silmeye izin vermiyor**;
döndürme bu vardiyada YAPILMADI ve **risk bilinçli olarak kabul edildi.**

**Yapılan:** yereldeki tüm kopyalar silindi — `~/.claude/history.jsonl` (3) ·
`2ecce529-….jsonl` (6 blok + 5 gövde) · `4dec15f2-….jsonl` (1+1) · `05b48db3-….jsonl` (1 ad).
Doğrulandı: `BEGIN … PRIVATE KEY` ve `b3BlbnNzaC1rZXktdjE` (openssh-key-v1 base64 imzası)
aramaları **0 sonuç**; her dosyada satır sayısı korundu ve **JSON bütünlüğü TAM**.
Depoda ve PowerShell PSReadLine geçmişinde zaten hiç geçmiyordu (ölçüldü).

> ⚠️ **ANAHTAR HÂLÂ YANMIŞ SAYILIR.** Yerel silme sızıntıyı geri almaz: anahtar bir API
> isteğinin gövdesinde ağdan geçti ve sunucudaki `authorized_keys` satırı duruyor.
> ⚠️ **SİLME SIRASI ÖNEMLİ** — ters yapılırsa Coolify sunucuya erişimini kaybeder:
> yeni anahtar ekle → sunucuyu ona geçir → **Validate** → eski anahtar artık kullanımda
> olmadığı için silinebilir hâle gelir → en son `authorized_keys`teki satırı çıkar.
> ⚠️ **DERS:** ilk temizleme denemesi 104 satırı yutacaktı (desendeki karakter sınıfına boşluk
> konulmuştu, gerçek satır sonlarını aşıyordu). Satır sayısı koruması dosyaya hiç dokunmadan
> iptal etti. **Kayıt dosyasına toplu düzenleme satır-bazlı yapılır ve JSON bütünlüğü ölçülür.**

### 🔻 VARDİYA DEVİR NOTU — 2026-08-14/4 — "BİLDİRİM GELMİYOR" TEŞHİSİ (mobil 0.24.0 → **0.25.0**, API DEĞİŞMEDİ 1.8.0)

Saha denemesi: patron siparişi kuryeye attı, sipariş kuryenin telefonunda **görüldü** (senkron
çalışıyor), bildirim izni **açıktı** — bildirim yoktu. Sunucu ölçülerek elendi (API 1.8.0
üretimde, `FCM_HIZMET_HESABI` **girildi**, `PushGonderimi` işleri kuyrukta koşup tamamlanmıştı).

**KÖK NEDEN:** `pushArkaPlanIsleyici` AYRI BİR ISOLATE'te koşar; orada `main()` hiç çalışmadığı
için Flutter eklenti kayıtları KURULU DEĞİLDİR. `DartPluginRegistrant.ensureInitialized()`
çağrılmadan zincir sessizce kırılıyordu: `flutter_local_notifications` çözülemiyor →
`izinDurumu()` false → bildirim çizilmeden return. Belirtisi aldatıcıydı: **ön planda çalışıyor,
arka planda çalışmıyor** — yani tam da bildirimin gerektiği durumda (telefon cepte, uygulama
kapalı) yok. Analiz, 1275 test ve APK derlemesi hepsi yeşildi.

**İKİNCİ KUSUR:** `pushKur` sunucu adresini ham kolondan (`meta.apiBaseUrl`) okuyordu; bu alan
NULL OLABİLİR ve oturum katmanının tamamı `Session.baseUrlOf` ile varsayılana düşer — yardımcıyı
kullanmamak, null bir kurulumda push'un HİÇ kurulmaması demekti.

**ASIL DERS TEŞHİSTEydi: bakılacak hiçbir veri yoktu.** Sunucu logu yalnız `PushGonderimi … DONE`
diyordu (kaç cihaza gittiği yazmıyordu), telefon jetonu neden göndermediğini hiçbir yere
kaydetmiyordu. İkisi de kapatıldı: sunucu artık `aday: N, gonderilen: M` logluyor; telefon
`PushDurumu`nu (oturum-yok · kurulamadi · jeton-alinamadi · bildirilemedi · hazir) cihaz-yerel
ayar dosyasına yazıyor ve **Ayarlar → Bildirimler → "Anlık bildirimler"** satırında GÖSTERİYOR —
bayi/destek tek bakışta söyleyebilir, log toplamaya gerek kalmaz. (Şema alanı DEĞİL,
`tutamac_deposu`/`tema_deposu` desenindeki cihaz-yerel dosyada: bir tanı bayrağı için migration
açmak o deseni kırardı.)

> ⚠️ **DÜZELTME SAHADA DOĞRULANMADI.** 0.25.0'ın çalıştığının tek kanıtı iki telefonla,
> **uygulama KAPALIYKEN** yapılacak provadır. Sıradaki işlerin birincisi budur.

### 🔻 VARDİYA DEVİR NOTU — 2026-08-14/3 — HEADS-UP · GENİŞLETİLMİŞ · SES + ALTI YENİ BİLDİRİM (mobil 0.23.0 → **0.24.0**, API 1.7.0 → **1.8.0**)

**⚠️ ÖNCE BU KISITI OKU — bildirimlere dokunacak herkesi ilgilendirir:**

> Android'de bir bildirim kanalının **önem derecesi (heads-up) ve sesi, kanal ilk
> oluşturulduğunda DONAR.** Uygulama sonradan değiştiremez; yalnız kullanıcı değiştirebilir.
> Bir kategoriyi sonradan heads-up yapmak **yeni kanal kimliği** gerektirir ve yeni kanal,
> bayinin eskisinde yaptığı kısmaları hatırlamaz.
>
> Bu yüzden iş sırası tersine çevrildi: **önce** heads-up/ses kararı alındı, **sonra** yeni
> kategoriler o ayarla doğdu. 0.22.0 henüz hiçbir telefona inmediği için üç push kanalı da
> bedavaya doğru ayarla kuruldu.

**HEADS-UP CİMRİ DAĞITILDI — 3/9 kategori:** sipariş atandı · sipariş iptal · yeni cihaz.
İlk ikisi kuryenin YOLUNU değiştirir, üçüncüsü güvenliktir. Kalan altısı rafa düşer, titrer,
simge çıkar ama işi bölmez. Gerekçe `GunlukSinir` ile aynı: her bildirim ekranın üstünde
belirirse bayi bir haftada hepsini kapatır ve o andan sonra önemliyi de kaçırır.

**İKİ AYRI SES** (`scripts/bildirim_sesi_uret.dart` — ham PCM hesabıyla üretildi, telif
tamamen bizim): yükselen ton = yeni iş, alçalan ton = iptal. Tek ses kuryeye iptali "yeni
sipariş" sandırırdı; sesin var olma sebebi zaten bildirimi göremediği durumdur.

**ALTI YENİ BİLDİRİM:** sipariş iptal (push→atanmış kurye) · yeni cihaz girişi (push→yönetici)
· kapanış hatırlatması (kasa 21:00 + gün 09:00, tek kategori) · kullanım hakkı (rota kontörü)
· senkron uyarısı. Sonuncusu `sistem` kategorisini ilk kez DOLDURDU — o kategori tanımlıydı
ama hiçbir yerden bildirim üretmiyordu, yani ayarlarda çalışmayan bir anahtar duruyordu.

**Abonelik bildirimi EKLENMEDİ** (kullanıcı kararı): 7 abonelik postası + günlük hatırlatma
görevi zaten çalışıyor; Apple 4.5.4 ve BRIEF'in mobilde satın alma yasağı karşısında risk
ürünün tamamı.

> ⚠️ **SES DOSYALARI İLK DERLEMEDE APK'YA HİÇ GİRMEDİ** ve bu ölçülerek bulundu. Dart onları
> string adla istiyor (`RawResourceAndroidNotificationSound`), R8 statik referans göremeyip ölü
> saydı ve attı — `resources.arsc` içinde adları bile yoktu. `res/raw/keep.xml` ile korundu ve
> APK içeriği zip olarak açılıp DOĞRULANDI (`res/GC.wav` · `res/jN.wav`, arsc'ta adlar duruyor).
> **Analiz temiz, 1275 test yeşil, APK üretilmişti — yalnız ses yoktu.** Bu depodaki üç kapıya
> dördüncüsü eklendi: **derleme ≠ paketlenmiş içerik.**

**ÖLÇÜMLER (bizzat koşuldu):** `flutter analyze` **temiz** · **1275 mobil test yeşil** ·
**API tam takım 856/857 yeşil** (4154 assertion; 1 atlandı = openssl/Windows, 1 incomplete —
ikisi de bu vardiyadan önce de öyleydi) · `flutter build apk --release` **saha + deneme
yeşil** · APK içeriği ses dosyaları için ayrıca açılıp doğrulandı · `pint` + `phpstan` temiz.

**SIRADAKİ İŞLER:**
1. **`FCM_HIZMET_HESABI`'yi Coolify'a gir** ve iki telefonla saha provası yap — push'un
   çalıştığının TEK kanıtı budur. Sesleri de o provada dinle (ton beğenilmezse
   `scripts/bildirim_sesi_uret.dart` içindeki nota sabitleri değişir, komut yeniden koşulur).
2. **iOS push** — Apple Developer hesabı + APNs sertifikası. Ses dosyaları iOS'ta ayrıca
   `Runner`a eklenmeli (`res/raw` yalnız Android'dir).
3. Önceki vardiyalardan devredenler: uzaktan oturum kapatma · uygulama kilidi (PIN) ·
   karantina dökümü · ölü kod temizliği · `day_end_screen.dart` 513 satır.

### (ÖNCEKİ) 2026-08-14/2 — DÖRT BİLDİRİM KALDIRILDI (mobil 0.22.0 → **0.23.0**, API DEĞİŞMEDİ 1.7.0)

Kullanıcı kararı: *"Borç eşiği, Vadesi geçen borç, Müşteri gecikti, Rutin teslim günü —
bunları kaldır tamamen hiç olmasınlar."*

Dördü de çalışıyordu ve iyi kurulmuştu (borç eşiği bir SEVİYE değil GEÇİŞ yüklemiydi; vade
taraması FIFO alacak yaşlandırmasının kendisiydi). Sorun kalite değil, İSTENMEMELERİYDİ:
hepsi bayinin zaten bildiği bir şeyi hatırlatıp günlük bildirim bütçesini yiyordu.

**SİLİNDİ, bayrak arkasına ALINMADI** (~830 satır kural + ~74 test): `kurallar/musteri_*` iki
dosya · `para_kurallari`nda iki kural · `DayEndRepository.bugunEsigiAsanlar` /
`gecikmisBorclular` · `orderRepository.musteriTeslimGecmisleri` · `BildirimAyarlari`nde
`borcEsigiKurus` ve onun TEK İSTİSNAsı · `BildirimTetikleyici`nin ANLIK tarama yolu
(`_anlik` — geriye tek zamanlanmış kural kaldı).

> ⚠️ Sahadaki telefonlarda bu dört KANAL kalır (Android kanalı uygulama silmedikçe durur).
> Artık bildirim üretmezler; sistem ayarlarında boş satır olarak görünürler.
> `deleteNotificationChannel` BİLEREK çağrılmadı: kanal silmek, aynı `wire` bir gün geri
> gelirse kullanıcının o kanalda yaptığı ayarı da yok eder.

**ÖLÇÜMLER:** `flutter analyze` temiz · **1250 mobil test yeşil** (1324'ten düştü: silinen
kuralların testleri).

**Kalan bildirimler:** gün sonu özeti (yerel) · uygulama durumu (`sistem` — ⚠️ TANIMLI AMA
HİÇ KULLANILMIYOR, aşağıya bak) · sipariş atandı · teslim edildi · kasa devri (push).

### 🔻 VARDİYA DEVİR NOTU — 2026-08-14 — PUSH BİLDİRİMİ KURULDU (mobil 0.21.0 → **0.22.0**, API 1.6.0 → **1.7.0**)

Kullanıcının cümlesi: *"Push bildirimlerini kurmamız gerekiyor!"*

**KAPSAM (kullanıcı onayı ile):** operasyon olayları · yalnız Android · Firebase projesini
kullanıcı kendi Google hesabıyla açtı (`sipario-acd9e`).

**1. NEDEN GEREKTİ.** Bildirim altyapısı vardı ama tamamı YERELDİ — telefon kendi verisinden
üretiyordu. Olayın BAŞKA BİR CİHAZDA olduğu durumu bu kapatamaz: patron siparişi kendi
telefonundan kuryeye atar, kuryenin telefonunda o an hiçbir şey yoktur. Tek kişilik bayide
görünmeyen bu boşluk, patron+kurye olan bayide ürünün eksik yarısıydı.

**2. DÜRTÜ VERİ TAŞIMAZ.** FCM yükü `{olay, id, kategori}` — müşteri adı/adres/tutar YOK
(kırmızı çizgi #4). Sıra: dürtü → senkron → veri yerel DB'ye iner → bildirim YEREL veriden
çizilir. Asıl mimari kazanç bu değil, şu: dürtü kaybolsa bile (telefon kapalı, Play Services
yok — Huawei) veri mevcut senkronla akar. **Push HIZLANDIRICIDIR, taşıyıcı değil**; "push
gelmezse ürün çalışmaz" durumu tasarım gereği doğamaz.

**3. `notification` alanı BİLEREK gönderilmiyor, yalnız `data`.** Olsaydı bildirimi Android
sistemi çizerdi ve sessiz saatler · günlük bütçe · kategori kısma kurallarının hiçbiri
işlemezdi; metin de sunucudan gelmek zorunda kalır, kişisel veri FCM'e sızardı.

**4. Kural tek yerde** (`app/Bildirim/PushTetikleyici.php`): yalnız `applied` olaylar
(offline istemcinin `duplicate` yeniden denemesi telefonu öttürmez) · üç olay (atandı→ATANAN
kuryeye, teslim ve kasa devri→yöneticilere) · ters kasa devri (iptal) hariç · olayı üreten
cihaz elenir. Gönderim KUYRUKTAN koşar (teslim kapatma bir ağ turuna bağlanamaz) ve okuma
`pgsql_owner` iledir — kuyrukta RLS kiracı değişkeni kurulu değildir, izolasyon elle
`where tenant_id` ile zorlanır.

**5. SESSİZ ARIZA KAPATILDI.** `POST /devices` ve giriş yolu, `push_token` gönderilmediğinde
alana `null` yazıyordu. FCM jetonu girişten SONRA asenkron geldiği için bu, **her açılışta
jetonu silerdi** — hata çıkmaz, yalnız bildirimler bir gün gelmemeye başlardı.
(`TenantSettingsRepository`de mobilde çözülen "verilmedi ≠ boşalt" probleminin ikizi.)

**ÖLÇÜMLER (bizzat koşuldu):** `flutter analyze` **temiz** · **1324 mobil test yeşil** (tam
takım) · **API tam takım 852/853 yeşil** (4137 assertion; 1 atlandı = openssl, 1 incomplete —
ikisi de bu vardiyadan önce de öyleydi) · `flutter build apk --release` **hem `saha` hem
`deneme` tadında yeşil** (deneme `.test` paket adı taşır; `google-services.json` ikisini de
kapsıyor — doğrulandı) · `scripts/check_permissions_source.sh` temiz.

**İZİN DENETİMİ (kırmızı çizgi #6) — birleşik manifest okundu, varsayılmadı.** Firebase üç
izin ekledi: `com.google.android.c2dm.permission.RECEIVE` · `WAKE_LOCK` · `VIBRATE`. Hiçbiri
Play'in kısıtlı izin grubunda DEĞİL; SMS/Call Log grubundan tek bir izin gelmedi. Bunu kaynak
manifest'e bakarak söylemek YETMEZDİ — paketler izni birleşme sırasında ekler, o yüzden
`build/.../merged_manifest/sahaRelease` çıktısı okundu.

> ⚠️ **ÜRETİMDE HENÜZ AÇIK DEĞİL.** `FCM_HIZMET_HESABI` (hizmet hesabı JSON'unun base64'ü)
> Coolify'a girilmedi. Girilene kadar push sistemi KAPALIDIR ve bu bir hata değildir — kod
> sessizce atlar. Anahtar `docker-compose.prod.yml`deki `*app-env`e eklendi, yani `queue`
> konteynerine de gider (gönderim orada koşar).

> ⚠️ **İMZA YOLU YEREL TESTTE ATLANIYOR.** `openssl_pkey_new` bu Windows makinesinde
> `openssl.cnf` bulamıyor; `imza_gercekten_uretilir` testi `markTestSkipped` ile geçiliyor.
> CI (Linux) o testi GERÇEKTEN koşar. İmza hatalıysa FCM `invalid_grant` döner ve TÜM push
> tek noktadan sessizce ölür — ilk gerçek gönderimde bu doğrulanmalı.

**SIRADAKİ İŞLER (bu vardiyadan devreden):**
1. **`FCM_HIZMET_HESABI`'yi Coolify'a gir** ve iki telefonla saha provası yap (patron sipariş
   atar → kuryenin telefonu titrer). Push'un çalıştığının TEK kanıtı budur.
2. **iOS push** — Apple Developer hesabı + APNs sertifikası gerekir. Kod iOS'a hazır yazıldı;
   `PushServisi` platform ayrımı yapmıyor, yalnız jeton kaydında `'android'` sabiti var.
3. Önceki vardiyadan devredenler değişmedi: uzaktan oturum kapatma (jeton↔cihaz bağı) ·
   uygulama kilidi (PIN/biyometrik) · karantina dökümü · ölü kod temizliği ·
   `day_end_screen.dart` 513 satır.

### (ÖNCEKİ) 2026-08-13/3 — AYARLAR KONULARINA BÖLÜNDÜ + HESAP SAYFASINA VARLIK NEDENİ (mobil 0.20.1 → **0.21.0**, API DEĞİŞMEDİ 1.6.0)

Kullanıcının cümlesi: *"Ayarlarda bulunan Hesap ve İşletme sayfaları çok işlevsiz! Özellikle
Hesabım sayfasının varlık amacı ne, hiçbir şeye yaramıyor neden var? … İşletme Kimliği düzenleme
içerisindeki bir çok şey orada olmasa da olur… mesaj şablonları ilerleyen zamanlarda mesaj sayısı
artacak orada olmaya devam mı edecek! Fiş bölümü özellikle… Lütfen kafanı çalıştır, geleceğe
yönelik olmalı!"*

**1. ÖNCE TEMEL, SONRA SAYFA.** Bölme doğrudan yapılamazdı: `TenantSettingsRepository.save` bir
LWW UPSERT ve imzası düz `String?` olduğu için "alan verilmedi" ile "alan boşaltılsın" aynı şeye
(null) benziyordu — her çağıran 14 alanı birden göndermek zorundaydı. Bedeli koda YAZILIYDI:
`kuryeIzinleriKaydet` ve `siparisKoduTercihiKaydet` her biri 14 alanı elle taşıyan birer kopyaydı
ve doc'ta "aynı disiplin ileride eklenecek her ayar için de geçerli" yazıyordu. Drift'in `Value<>`
sentineli getirildi (`Value.absent()` = dokunma, `Value(null)` = boşalt); iki kopya tek satıra
indi. Asıl kazanç satır sayısı değil: bir alanı listeye eklemeyi unutunca bayinin IBAN'ını sessizce
silme hatası YAPISAL olarak kalktı.

**2. İşletme dört konuya ayrıldı.** Kimlik (ad·yetkili·iletişim·vergi·saatler) ·
**Tahsilat** (IBAN + alıcı adı + fiş notu) · **Mesajlar** · Sipariş. Ayarlar listesindeki her satır
KENDİ DURUMUNU özetliyor (IBAN girilmemişse orada yazıyor) — "Düzenle" düğmeleriyle dolu bir liste
hiçbir bilgi vermiyordu.

**3. Mesajlar bir LİSTE olarak kuruldu, tek alan olarak değil** — kullanıcının asıl endişesi
buydu. Yeni şablon eklemek `kMesajSablonlari` sabitine bir kayıt yazmaktır; ekran değişmez.

**4. Kurallar ekranla birlikte taşındı.** `ibanHatasi` zaten `iban.dart`taydı; şablon sınırı
`hatirlatmaSablonuHatasi` olarak `borc_hatirlatma.dart`a çıktı. Kuralı eski form doğrulayıcısında
bırakmak, çağıranı olmayan bir dalı testin yeşil tuttuğu ölü kod demekti.

**5. HESAP SAYFASINA CİHAZLAR EKLENDİ.** Sayfanın gösterdiği her şey (ad, rol, çıkış) çekmecede
zaten vardı — yani aynı bilgiyi ikinci bir UI ile tekrar ediyordu, tam da kullanıcının bir önceki
vardiyada uyardığı hata. Cihazlar, ürünün hiçbir yerinde sorulamayan soruyu cevaplıyor: hesabım
hangi telefonlarda açık, hangisi en son ne zaman görüldü. Mevcut `GET /devices` kullanıldı, sunucu
değişmedi.

> ⚠️ **UZAKTAN OTURUM KAPATMA BİLEREK EKLENMEDİ ve bu bir eksiklik olarak KAYITLIDIR.** Sunucuda
> jeton ile cihaz kaydı arasında bağ yok — `AuthController` jetonu düz `'mobile'` adıyla üretiyor.
> Bir "Oturumu kapat" düğmesi bayiye kapattığını sandırır, telefon çalışmaya devam ederdi; güvenlik
> ekranında olabilecek en kötü şey. Düğmenin sessizce eklenmesini engelleyen bir test yazıldı
> (`cihazlar_test.dart`). Liste ÇEVRİMDIŞI ÖNBELLEKLENMİYOR: bayat liste "eski telefonum artık
> bağlı değil" diye yanlış bir güvenlik izlenimi üretirdi — ağ yoksa ekran boş liste değil hata
> gösteriyor, bu da testle kilitli.

**ÖLÇÜMLER (bizzat koşuldu):** `flutter analyze` **temiz** · **1309 mobil test yeşil** (tam takım).
API'ye dokunulmadı, sürümü 1.6.0'da kaldı — iki hat bağımsızdır.

**SIRADAKİ İŞLER (bu vardiyadan devreden):**
1. **Uzaktan oturum kapatma** — sunucuda jeton↔cihaz bağı kurulmalı (`createToken('mobile')`
   yerine cihaz kimliğini taşıyan ad + revoke uç noktası), sonra Cihazlar ekranına düğme.
   Eski istemci uyumu YAZILI olarak kararlaştırılmalı (bağsız eski jetonlar ne olacak).
2. **Uygulama kilidi (PIN/biyometrik)** — yeni paket + native dokunuş; `flutter build apk
   --release` kapısı ZORUNLU (desugaring tuzağı).
3. **Karantina dökümü** (`outbox.lastError` + detay ekranı) — önceki vardiyalardan devreden borç.
4. **Ölü kod temizliği** — `OrderDetailScreen` (hiç örneklenmiyor), `phase0/setup_wizard.dart`,
   "Gelen çağrıyı dene" ayarlardan kurulum sihirbazına.
5. `day_end_screen.dart` **513 satır** — 500 sınırının 13 satır üstünde (azalan borç, yine borç).

### (ÖNCEKİ) 2026-08-13/2 — ARA TAHSİLAT: YETKİ DARALDI + İPTAL GELDİ (mobil 0.15.0 → **0.16.0**, API 1.3.0 → **1.4.0**)


Kullanıcının iki cümlesi: *"Gün sonu tarafında Yönetici tahsilat silebilmeli"* ve *"Kurye ara
tahsilat yapamaz sadece patron."*

**1. Ara tahsilatı artık yalnız yönetici alır.** `_araTahsilatAlabilir` içindeki
`_kuryeId == widget.kullaniciId` dalı kaldırıldı; gün sonu ekranındaki üç para eyleminin
(kapatma · ara tahsilat · iptal) üçü de tek anahtara bağlandı: `yetkiler().gunuKapatma`.
2026-08-11'de yazılmış "devir yolu KAPANMADI, ara tahsilat kuryede DURUYOR" gerekçesi artık
yanlış olduğu için ilgili yorum blokları da düzeltildi (kod değişince onu anlatan yorum da
değişir — bu depoda yalanlaşan yorum, yanlış koddan daha pahalıya patlıyor).

**2. "Silme" ters kayıt olarak uygulandı.** Gerçek silme BRIEF kırmızı çizgi #2'yi ihlal ederdi
ve çevrimdışı bir cihaz silineni senkronla geri diriltirdi. Bunun yerine `ledger_entries`
desenindeki gibi `cash_handovers.reverses_handover_id` (drift v19→v20 + Laravel migration
`2026_08_13_004011_add_handover_reversal.php`): ters işaretli ikinci bir devir satırı.
Kullanıcı gözünde sonuç istenen şey — satır "iptal edildi" görünür, üstü çizili çizilir,
toplamdan ve sayaçtan düşer — ama kanıt kaybolmaz.

**PARA NEDEN KAPANIYOR:** `teslimEdilenNakit` orijinal(+) ve iptal(−) satırlarını birlikte
sayıyor, net sıfırlanıyor; yani kuryenin beklenen nakdi kendiliğinden iptal öncesine dönüyor ve
kapanış sheet'ine doğru rakam gidiyor. `from_user_id` ORİJİNALDEKİYLE AYNI tutuluyor (iptali kim
yaptıysa o değil) — pencere matematiği cebi bu alandan ölçtüğü için, iptali başka bir kişiye
yazmak parayı hiç geri vermezdi. Testle kilitli: *"iptal sonrası kurye hesabı kapatılınca arşive
DOĞRU tutar donar, fark 0."*

**ÇİFT İPTAL ÜÇ KATMANDA KAPALI** ve asıl kapak son ikisi: istemci kapısı · sunucu uygulayıcısı ·
kısmi unique indeks. Gerekçe: iki cihaz ÇEVRİMDIŞIYKEN aynı tahsilatı iptal edebilir ve
birbirlerinin kapısını göremez; iki ters satır parayı kasaya İKİ KEZ döndürür ve append-only
olduğu için bu kalıcı bozardı.

Yeni bir senkron `op` açılmadı — alan mevcut `handover` op'una eklendi (ayrı bir op, eski
istemcide tanınmayan olay demekti).

**ÖLÇÜMLER (bizzat koşuldu):** `flutter analyze` temiz · **1275 mobil test yeşil** ·
`php artisan test --filter=AraTahsilat` **9/9, 81 assertion**. API Feature suite'in tamamı
(710/710) bu vardiyanın API ajanı tarafından ölçüldü, kod o ölçümden sonra değişmedi.

> ⚠️ **Vardiya notu — ajanlar oturum limitinde öldü.** Üç ajan (mobil · api · tester) sırayla
> düştü; işleri otomatik kanca tarafından commit'lenmişti, `git log` ile bulundu. Tek kayıp,
> `tester`'ın yazıp KOŞTURAMADAN öldüğü widget testiydi: import eksikti ve yardımcı seçicisi
> hatalıydı — `satir(tutar)` yalnız tutara bakıyordu, oysa 40,00 iptal edilince **toplam satırı
> 20,00'a düşüp ayakta kalan satırla aynı rakamı gösteriyor** ve seçici iki satırı birden
> yakalıyordu ("Too many elements"). Ürün doğru çiziyordu; seçici artık `toplam` bayrağına
> bakıyor. Ders: iptal/indirim gibi TOPLAMI DÜŞÜREN bir davranışı ölçen testte, satırı tutarla
> aramak toplamla çakışmaya açıktır.

**SIRADAKİ İŞLER (bu vardiyadan devreden):**
1. **Reddedilen senkron olaylarının GEREKÇESİ kullanıcıya ulaşmıyor.** Sunucu net bir mesaj
   döndürüyor ("bu kasa devri zaten iptal edilmiş") ama yerelde saklanmıyor; kabukta yalnız genel
   karantina bandı çıkıyor. Kapatmak için `outbox.lastError`a gerekçeyi yazmak (kolon zaten var) +
   karantinayı satır satır gösteren bir ekran gerekiyor. Bu vardiyada BİLİNÇLİ olarak açılmadı:
   kapsamı bu özellikten geniş — reddedilen HER olay aynı sessizlikten geçiyor — ve buraya
   iliştirilmiş yarım bir çözüm asıl işi bir daha görünmez yapardı. Bugünkü etkisi dar (yalnız
   çok cihazlı + çevrimdışı yarış), veri kaybı yok. Not `sync_engine.dart:330` civarında zaten
   duruyor.
2. `day_end_screen.dart` **513 satır** — 500 sınırının 13 satır üstünde. Bu vardiyaya 538 satır
   olarak girdi, ara tahsilat akışları `isletme/gun_ozeti_eylemleri.dart`'a çıkarılarak kısaldı
   ama sınırın altına inmedi. Azalan bir borç, yine de borç.

### (ÖNCEKİ) 2026-08-13 — YENİ SİPARİŞ FORMU: UI/UX + KURYE ZORUNLU (mobil 0.14.0 → **0.15.0**)

> ⚠️ **0.14.1 NUMARASI YAKILDI — sürüm notu listesinde YOK.** O numara `test` kanalına iki kez,
> iki farklı içerikle çıktı (21:52 ve 22:38 koşumları). Sebebi bir varsayımdı: CI kırmızı kaldığı
> için yayınlanmadığı sanıldı, `gh run list` ile doğrulanmadı. Ders: **"CI kırmızıydı" bir hafıza
> değil, bir ölçümdür** — yayınlanıp yayınlanmadığı `gh run list` + release'in `surum.json`ıyla
> bakılır. Cihazlar doğru güncellendi (karşılaştırma `yapim` sayısıyla, SemVer ile değil).

**KURYE ATAMASI ARTIK ZORUNLU** (kullanıcı kararı — 2026-08-11'deki "opsiyonel" kararı değişti),
ama koşulsuz değil: `_kuryeGerekli = yetkiler().atama && seçilmemiş`. `atama = yönetici && aktif
kurye var` olduğu için tek kişilik bayide ve kurye rolünde kapı hiç kurulmaz — kurulsaydı o iki
kullanıcı hiç sipariş giremezdi. Engel sepet-boş kapısının aynı yüzeyini kullanıyor (sarsıntılı
kırmızı şerit + sönük ama canlı düğme). Dört durum testle kilitli.

Kullanıcı isteği: *"işlevsellik çalışıyor ama UI/UX tatmin edici değil, tasarım dilinin dışına çıkma."*
Hiçbir akış, kapı ya da yazma yolu değişmedi — yalnız düzen, hiyerarşi ve metin. Tasarım dili korundu
(`.ys-*` / `.sdx-*` jetonları, Sora/Hanken, tek accent). **1250 mobil test yeşil, `flutter analyze` temiz.**

Ne değişti (`screens/orders/`):
1. **Adım 2 iki bölgeye ayrıldı.** Üç ekleme yolu sepetin üstüne/altına/arasına dağılmıştı; artık hız
   sırasına dizili tek blok (her zamanki ürünler → katalog → serbest satır), altında kendi başlığı ve
   kalem sayacı olan **Kalemler** bölümü. Serbest satır bağlantısı sepetin dibinden katalog düğmesinin
   altına taşındı.
2. **Sepet satırı 3 satırdan 2 satıra indi.** Not çağrısı her kalemin altında accent renkli ayrı bir
   satırdı; birim yazısıyla aynı satıra, muted renge indi (`Not ekle` + kalem ikonu). Not girilince
   yerini warn-soft rozet alıyor.
3. **Özette toplam bir kez yazıyor.** `SdKart.toplamGoster: false` — sabit alt çubuk zaten sahibi.
4. **Kurye seçimi gövdeden ALT ÇUBUĞA taşındı** (kullanıcı isteği, aynı gün ikinci tur):
   `AltKuryeCipi` "Siparişi Kaydet"in solunda, aynı yükseklik/yarıçapta; toplam da tam genişlikte
   kendi satırına çıktı (`YsAltCubugu.yanEylem`). Etiket "Kurye seç" — eski uzun cümle çipe
   sığmıyor, opsiyonelliği testin kanıtladığı DAVRANIŞ söylüyor. 360 px'de taşma sınavı yapıldı.
5. **Adım rozetleri geçilmiş adımlara dokunulabilir**; müşteri araması tasarımdaki gibi otomatik
   odaklanıyor (`SipArama.otomatikOdak`); boş sepette "Devam" tasarımdaki gibi sönük (opacity .6).
6. Boş sepet kutusu artık düğmenin sözünü tekrarlamıyor: *"Eklenen kalemler burada listelenir."*

Ölçüm yöntemi: ekranın altı hâli (adım 1/2/3, boş sepet, favori şeridi, koyu tema, serbest satır,
kurye satırı) gerçek fontlarla golden PNG olarak çizilip **gözle** incelendi; kurye satırının görünmez
zemini böyle bulundu. Önizleme koşumu geçiciydi, depoya bırakılmadı.

> ⚠️ Yan bulgu (düzeltilmedi, kapsam dışı): `assets/fonts/Sora.ttf` ve `HankenGrotesk.ttf` **₺
> (U+20BA) glifini taşımıyor** — golden'larda tofu çıkıyor. Cihazda sistem yedeği (Roboto) çizdiği
> için görünür, ama para rakamları "tabular Sora" iken ₺ başka aileden gelir. Tüm ekranları ilgilendirir;
> çözümü ya font değişimi ya da ₺ için açık bir yedek aile tanımıdır.

### (ÖNCEKİ) Güncel durum (son güncelleme: **2026-08-12 — E-POSTA ŞABLONLARI: 13 ŞABLON, MARKA DÜZENİ, İLK ZAMANLANMIŞ GÖREV**.
Bu vardiya SUNUCU tarafında geçti, mobile hiç dokunulmadı. Başlangıç ölçümü: depoda `app/Mail` ve
`app/Notifications` **yoktu**; posta gönderen üç yer vardı ve üçü de çirkindi. En kötüsü sessiz bir
arızaydı: **parola sıfırlama postası İngilizce çıkıyordu** — `.env`de `APP_LOCALE=tr` yazıyor ama depoda
`lang/tr` dizini yok, Laravel'in `ResetPassword` bildirimi `__('Reset Password')` anahtarlarını çeviri
bulamayınca anahtarın KENDİSİNE düşürüyordu; yani hesabına giremeyen esnafa "Hello! You are receiving this
email..." gidiyordu. Diğer ikisi `Mail::raw` düz metindi ve biri PARA TAŞIYORDU (havale talimatı, IBAN'ı
boşluklarla hizalıyordu — telefonda orantılı yazı tipiyle o hizalama dağılır). Ayrıca `MAIL_FROM_ADDRESS`
hâlâ Laravel varsayılanı **`hello@example.com`**'du: bedeli görüntü değil TESLİMAT, çünkü SPF/DKIM
doğrulanamayan gönderen alan adı spam'e düşer ve bu sessizce olur. **Kurulan şey bir şablon yığını değil,
bir tasarım sistemi:** `public/css/site.css`teki "Levha" paleti/tipografisi posta kutusuna taşındı
(`components/eposta/duzen` + 7 blok bileşeni: `baslik` `metin` `dugme` `kutu` `veri` `kod` `tutar` `adimlar`
`imza`). Üç posta-istemcisi kısıtı tasarımın İÇİNE katıldı ve testle kilitlendi: **web font yüklenmez**
(Sora/Hanken yalnız yığının başı), **SVG silinir** (Gmail `<svg>`i ve `data:image/svg+xml`i kaldırır — bu
yüzden marka GÖRSELSİZ kuruldu: mor yuvarlak kare + "S" + wordmark; harici logo dosyası da BİLEREK yok,
uzak görsel "resimleri göster" denene kadar boş kutudur ve markanın ilk izlenimi kırık ikon olurdu),
**flex/grid yok** (Outlook'un Word çizicisi tanımaz → her şey `role="presentation"` tablosu + satır içi
stil). Koyu mod uydurulmadı: markanın zaten tanımlı `.gece` paleti kullanıldı. **13 şablon** yazıldı, hepsi
Türkçe, hepsinin düz metin karşılığı var (`SiparioPostasi` tabanı `sablon()` adından iki görünümü birden
çözüyor — düz metni yazmayı unutmak imkânsız, dosya yoksa gönderim patlar). **Ve hepsi BAĞLANDI** — bağlanmamış
şablon dekordur: kayıt (bugüne kadar HİÇ posta yoktu, oysa mobil giriş firma kodu + kullanıcı adı ister ve
bayi başarı ekranını kapatınca kodu öğrenemiyordu) · havale talimatı · ödeme beyanı alındı · ödeme onaylandı ·
**ödeme eşleşmedi** (bu yol tamamen sessizdi: bayi parayı gönderdiğine inanıyor, hesabı açılmıyor, sebebi
öğrenmesinin yolu yok) · kurye hesabı açıldı · parola değişti · ek paket · parola sıfırlama · dışa aktarma
iç bildirimi. **Bu deponun İLK zamanlanmış görevi kuruldu** (`abonelik:hatirlat`, günlük 09:30 Europe/Istanbul):
deneme T-7/3/1, yenileme T-15/3, süre dolumu. Yeni konteyner GEREKMEDİ — `schedule:work` aylardır koşuyor ve
"No scheduled commands" basıyordu. Aynı posta iki kez gitmez (`Cache::add` işareti bayi+tür+eşik+HEDEF TARİH
ile anahtarlı; hedef tarih olmasaydı zamanlayıcı yeniden başladığında ikinci posta giderdi). Dil kararları
tasarım kadar önemliydi ve kod yorumlarında gerekçeleriyle duruyor: ret postasında **"reddedildi" YOK**
("eşleşmedi" — en olası sebep bayinin hatası değil, açıklamaya yazılmamış referans kodu), güvenlik postasında
**tıklanacak bağlantı YOK** ("değiştirmediyseniz tıklayın" kimlik avının taklit ettiği kalıptır; testle
kilitli), süre dolumu postasında **ilk ve en büyük cümle veri güvencesidir, ödeme çağrısı değil** (BRIEF
kırmızı çizgi #5; sıralama testle kilitli), kurye postasında **parola yazılmaz**, iç bildirimde konu ön eki
`Sipario ·` KORUNUR (süzgeç anahtarı) ama müşteriye giden postada YASAK (gönderen adı zaten Sipario, telefonda
konu ~35 karakterde kırpılır). Künye yer tutucuları (`[Şirket IBAN]`) müşteri postasına sızmıyor — düzen
bileşeni süzüyor, test kilitliyor. Yan düzeltme: `ResetPassword::createUrlUsing` `Parola.php`'den
`AppServiceProvider`'a taşındı — orada yalnız o ekrandan geçen isteklerde kuruluyordu, başka bir yol parola
sıfırlama tetiklerse Laravel'in var olmayan `password.reset` rotasını arayacaktı. Ölçüm BİZZAT koşuldu:
yeni `EpostaSablonlariTest` **89/89** (şablonlar gerçekten gönderilip üretilen iletiden okunuyor, yani kuyruk
serileştirmesi de kanıtlanıyor) · dokunulan yolların testleri **216/216** · pint temiz · `schedule:list`
doğrulandı · komut kuru koşuldu. Tasarım tarayıcıda açık ve koyu modda gözle denetlendi. **API sözleşmesi
DEĞİŞMEDİ** (yeni uç nokta/alan yok) — sürüm **1.3.0** sabit, mobil **0.14.0** sabit. **AÇIK:** e-posta
doğrulama akışı (kullanıcı "doğrulanmadan giriş yok" dedi) YAZILMADI — aşağıdaki devir notunda gerekçesi ve
tasarım kısıtları duruyor. **SMTP hâlâ kurulu değil** (`MAIL_MAILER=log`); şablonlar hazır ama üretimde
posta çıkmıyor.

<br>

**ÖNCEKİ:** **2026-08-11/3 — GİRİŞ ERGONOMİSİ + SÜRÜM NOTLARI EKRANI (uygulama 0.14.0)**.
Dört saha isteği kapatıldı, ikisi giriş ekranında. ① **Parola göster/gizle** — tasarımda yoktu çünkü
`s-giris.jsx` tarayıcının kendi göz düğmesine güveniyor; Android'de öyle bir hediye yok, yani eksiklik
tercih değildi. `SipInput.sonEk` + `SipIcons.goz/gozKapali` eklendi; ikon EYLEMİ resmeder (göz = "göstermek
için dokun"), `Semantics` etiketi aynı eylemi söyler. Test ikona DEĞİL `obscureText`e bakar: dönen bir
ikon + gizli kalan alan hiçbir hata üretmeden özelliği tamamen işlevsiz bırakırdı. ② **"Beni hatırla"** —
`sync_meta`ya iki cihaz-yerel kolon (şema **v19**), **PAROLA SAKLANMAZ** ve bu bir sınır olarak testle
kilitlendi (tüm `sync_meta` satırı taranıyor). Sunucu sahipli `tenantCode`a bindirilmedi: o senkronun
yazdığı bir önbellek, bu kullanıcının kapatabildiği bir tercih — tek kolon olsalardı "hatırlamayı" kapatan
bayinin ekranında kod yine belirirdi. Çıkışta SİLİNMEZ; token zaten çıkışa kadar duruyor, yani silinseydi
alan hiç okunmazdı. ③ **Güncelleme bandı sadeleşti** (kullanıcı: "sadece sürüm yazsın") — `Güncelleme var —
Sipario 0.13.0 (139)` yerine iki satır + sürüm rozeti; **yapım numarası ekrandan kalktı ama
KARŞILAŞTIRMADAN kalkmadı** ve tam bu ayrım iki iddiayla kilitlendi. ④ **Yenilikler ekranı** (Ayarlar →
Hakkında) — notlar derlemenin İÇİNDE sabit, sunucudan çekilmiyor: "ne değişti?" sorusu güncelleme indikten
sonra, ağın garanti olmadığı anda sorulur; ayrıca commit başlıkları ("otomatik(dev): 16 dosya") bayiye
hiçbir şey anlatmaz — sürüm notu bir ÇEVİRİDİR, çevirmeni insandır. Listeyi bayatlamaktan koruyan bekçi
testi var: **en üstteki kayıt `pubspec.yaml` sürümüyle aynı olmak zorunda**, ayrıca teknik dil ve mağaza
yasağı taranıyor. **YAN BULGU (bir sonraki vardiyanın saatlerini kurtarır):** Drift kod üretimi
`dependency_overrides` yordamıyla artık koşmuyor — `objective_c` de build-hook kazandı ve cache'teki üç
sürümünün üçü de hook'lu, yani düşürülecek sürüm yok. Asıl sebep hiçbir zaman sqlite3 değildi:
`build_runner` betiği AOT derliyor, AOT hook desteklemiyor. Doğru komut tek satır ve override istemiyor:
**`dart run build_runner build --force-jit`** (pubspec.yaml'daki not yeniden yazıldı). Ölçüm bizzat
koşuldu: mobil **1250/1250** (+30) · `flutter analyze` temiz · `flutter build apk --release --flavor saha`
**BUILD SUCCESSFUL**. Sunucu sözleşmesi DEĞİŞMEDİ — API **1.3.0** sabit, uygulama 0.13.0→**0.14.0** (MINOR:
geriye dönük uyumlu yeni davranış).

<br>

**ÖNCEKİ:** **2026-08-11/2 — GÜN ÖZETİ KURYEDE KENDİ HESABINA DARALDI + ÖDEME TÜRÜ DÖKÜMÜ**. Saha şikâyeti: "kurye kendi işlemlerini görmüyor, genel raporu görüyor". ① **"Tümü" kapsamı kuryede artık ÜRETİLMİYOR** — kapsam listesi role göre kuruluyor, yani seçim fonksiyonu kuryeye gün hesabını verebilecek bir dizin bile üretemiyor (kapı görünürlükte değil, veri üretiminde). Tek kapsam kaldığı için segment de çizilmiyor; ama bu koşul ROLE bağlı, seçenek sayısına değil — yalnız uzunluğa bakan ilk yazım hiç kuryesi olmayan bayide YÖNETİCİNİN segmentini gizledi ve mevcut bir test bunu yakaladı. ② **Kurye hiçbir hesabı kapatamaz** (2026-08-09 kararının tersi). Kapanış geri alınamaz bir mutabakattır; yanlış sayımla kapatan kuryenin bıraktığı farkı ertesi gün patron çözemez. **Ara tahsilat kuryede DURUYOR** — kaldırılsaydı kurye cebindeki parayı sisteme hiç işleyemezdi. ③ **Nakit/Kart/Havale satırları dokunulabilir** → o günün o türdeki dökümü; altta anahtarla açılan "Günün Teslimatları" dökümü (müşteri · adres · saat · tutar · tür). **Döküm kasa kartıyla AYNI süzgeçten geçer** (`_kasayaDokunanlar` ortak atası) ve testi toplam eşitliğini dört türde kilitliyor — ayrı yazılsaydı özellik "detay" değil ikinci bir gerçek üretirdi. Döküm TAHSİLAT taşır: veresiye sipariş listede yoktur, ters kayıtlar negatif görünür, sorgu yalnız açılınca koşar. ④ İki kullanıcı metni gerçeğe çekildi (ikisi de yalan söylüyordu): alt çubuktaki "yalnız kendi kurye hesabınızı kapatabilirsiniz" ve yetki ekranındaki "Tüm işletmenin ciro/kasa özetini görür". ⑤ Kimliği çözülemeyen kurye gün hesabına DÜŞMEZ, hiçbir rakam görmez (alt çubuk dahil) — belirsizlikte kapanan taraf seçilir. Sunucu sözleşmesi değişmedi (API **1.3.0** sabit); uygulama **0.13.0**. Yeni testler: `gun_tahsilat_detay_test` (9) + `ui_gun_tahsilat_test` (3); değişen davranışın eski testleri güncellendi (kurye kapanış testleri artık aynı kapsamı PATRON yolundan sürüyor — iddia korundu). Ölçüm: mobil **1220/1220** · analyze **temiz**. **CİHAZDA DOĞRULAMA YAPILMADI.** Öncesinde — 2026-08-11 — **BEŞ SAHA İSTEĞİ KAPANDI** (uyarı · favori · satır notu · birim menüsü · geçmiş limiti)**. ① **Açık sipariş kapısı:** müşterinin `open` siparişi varsa yeni sipariş öncesi uyarı çıkar, onaylanabilir. TEK KAPI (`siparisAcmadanOnceDogrula`) — sipariş açmanın birden çok giriş noktası var, uyarıyı kopyalamak dördüncü noktada sessizce delinirdi. Kara liste SERT engel, açık sipariş YUMUŞAK uyarı; sıra bilinçli. Kapsam yalnız `open` (teslim/iptal sayılmaz) çünkü görmezden gelinen uyarı, olmayan uyarıdır. ② **Favori ürünler:** `customers.favorite_product_ids` JSON dizisi (ayrı tablo DEĞİL — müşteri satırı zaten LWW ile senkronlanıyor). Müşteri kartında düzenlenir, sipariş formunda hızlı seçim olarak çıkar. Çözümleme hiçbir girdide çökmez; silinmiş ürün id'si elenir, "stokta yok" ürün ELENMEZ. ③ **Sepet satır notu:** `order_lines.note` — siparişin kendi `note`undan AYRI alan; sipariş detayında ve teslim yüzeyinde de görünür. ④ **Birim menüsü:** serbest metin → açılır menü (Adet·Kg·Gram·Litre·Paket·Koli·Metre·Kutu + Diğer…). Liste TEK KAYNAKTA (`birimler.dart`) çünkü `order_lines.unit` aynı sözcükleri yazar. **Sahadaki serbest değer ("damacana") KORUNUR** — hiçbir yerde "listede yoksa varsayılana düş" dalı yok; eşleşme Türkçe-duyarlı küçültmeyle ('LİTRE' sessizce kaçıyordu). ⑤ **Geçmiş limiti:** müşteri kartında son 3 sipariş + toplam sayı (AYRI akış — kart 3 satır okuyup "toplam 5" diyemez), tümü ayrı ekranda. Mobil şema **v18**, API'de iki migration (004009 · 004010). **VARDİYA GERÇEĞİ — okunması gereken kısım:** 4 ajanlı swarm kuruldu; **beşi de (üç yeni + yanlış adresleme yüzünden uyanan bir ESKİ ajan) oturum limitinde öldü** ve ağaç DERLENMEZ hâlde kaldı. Altı derleme hatasının tamamı bağlama hatasıydı — eksik import ×3, sınıf içinden görünmeyen üst düzey fonksiyon adı, ve drift'in `&` operatörünün dar `show` yüzünden kapsam dışı kalması ×2 (çözüm: `..where` zinciri, deponun kendi deseni). **Mobil testlerin TAMAMI lead tarafından yazıldı** (34 test, 4 dosya: `migration_v18_test` · `favori_ve_satir_notu_test` · `urun_birimi_test` · `ui_siparis_kapisi_test`) — ajanlara "kendi testini kendin yaz" denmesine rağmen hiçbiri yetişemedi; geçen vardiyanın birebir tekrarı. Bir regresyon yakalandı ve düzeltildi: birim alanı `TextField` olmaktan çıkınca ürün formu testi `at(3)` ile "index should be less than 3" veriyordu — indekse dayalı finder'ın bedeli. İki araç tuzağı yine ölçüldü: `testWidgets` içinde `db.close()` sahte zamanda ASILIYOR (saf sorgu testi `test()` olmalı) ve durdurulan koşu yetim `flutter_tester` bırakıp `sqlite3.dll`'i kilitliyor. **ORTAM ARIZASI — API kapısı önce KOŞULAMADI:** tam suite 30 dakika boyunca CPU'su boşta "koşuyor" göründü; sebep test veritabanının ayakta olmamasıydı (`sipario_db` container'ı durmuş, Docker Desktop kapalı). Test DB Laragon'un 5432'si DEĞİL, `docker-compose.yml:27` ile `55432:5432` haritalanan container'dır. Docker açılıp `docker start sipario_db` ile (compose `up` DEĞİL — farklı dizinden `-f` çağrısı proje adını değiştirip "container name already in use" üretiyor) kapı koşuldu. Ölçüm BİZZAT koşuldu: mobil **1208/1208** · `flutter analyze` **temiz** · API **723/723** (3727 doğrulama, 1 kasıtlı incomplete), yeni `FavoriVeSatirNotuTest` **16/16**. Sözleşme geriye dönük uyumlu (**MINOR**): API **1.3.0**, uygulama **0.12.0**. **CİHAZDA DOĞRULAMA YAPILMADI.** Öncesinde — 2026-08-10/4 — **KURYE YETKİLERİ ARTIK KİŞİYE ÖZEL (DEVRALMALI, ÜÇ DURUMLU)**. Kullanıcı isteği: "kurye yetkileri kuryeye özel atanmalı, direkt role değil". 2026-08-04'te bilinçli olarak kiracı düzeyinde kurulan 13 yetki artık **bayi varsayılanı / yeni kurye şablonu**; kişiye özel karar `users`'a eklenen aynı adlı **13 NULLABLE** kolonda yaşıyor ve etkin yetki TEK saf fonksiyonda çözülüyor (`kuryeIzinleriCoz` → `kisisel ?? varsayilan`; mobil şema **v17**, API migration **004008**). Eski kararın gerekçesi korundu: kopyalamak değil DEVRALTMAK seçildi, böylece yeni kurye kurulum adımı gerektirmeden doğuyor ve patron varsayılanı değiştirdiğinde devralanlar birlikte hareket ediyor. Ekranda üç durum var (Varsayılan / Açık / Kapalı) ve "Varsayılan" seçiliyken DEVRALINAN GERÇEK DEĞER rozette yazıyor; kuryeler listesinde ezmesi olana "özel yetki" rozeti düşüyor; "Hepsini varsayılana döndür" 13 ezmeyi birden siliyor. **`null` ≠ `false` ≠ "anahtar yok"** — payload'da anahtarın hiç olmaması "dokunma" (sürüm çarpıklığı koruması), açık `null` "devral", bool "kişiye özel karar"; üçünü ikiye indiren her katman ya kapatılmış yetkiyi geri açar ya kuryeyi eski ezmesine çakılı bırakır. Yetki alanlarının senkron yoluna açılması YENİ BİR YETKİ YÜKSELTME VEKTÖRÜ doğurdu ve kapısıyla geldi: `user_profile` push'unda yetki anahtarı varsa aktör patron/operatör olmak zorunda (`UserRole::kuryeYetkisiAtayabilir`), aktör olay GÖVDESİNDEN okunmuyor ve kapı LWW'den ÖNCE. `users` her turda `team` bloğuyla toptan yenilendiği için 13 alan o bloğa da eklendi — eklenmeseydi yetki kaydedilir, sunucuya yazılır ve bir tur sonra cihazda sessizce sıfırlanırdı (özellik "çalışıyor" görünüp kendini silerdi). Sözleşme geriye dönük uyumlu (**MINOR**): API **1.2.0**, uygulama **0.11.0**. VARDİYA NOTU: 5 ajanlı swarm kuruldu, `api` ve `testci` **oturum limitine takılıp öldü** (21:00 sıfırlanma); `api`'nin işi otomatik kanca tarafından commit'lenmişti ve tamdı, ama `testci` TEK TEST YAZAMADAN öldü — mobil testlerin tamamı (25 test, 3 dosya) lead tarafından sonradan yazıldı. Ölçüm BİZZAT koşuldu: mobil **1177/1177** · API **707/707** (3615) · `flutter analyze` **temiz**. **CİHAZDA DOĞRULAMA YAPILMADI.** ARAÇ NOTU: `flutter pub run build_runner build` bu sürümde AOT aşamasında düşüyor ("'dart compile' does not support build hooks"); çalışan komut `dart run build_runner build --force-jit` ve `--delete-conflicting-outputs` kaldırılmış. Ayrıca durdurulan bir `flutter test` yetim `flutter_tester` süreci bırakıp `sqlite3.dll` kopyasını kilitliyor — sonraki koşu araç çökmesiyle patlıyor; çözüm DLL'i silmek değil, yetim süreci kapatmak. Öncesinde — 2026-08-10 — **API SÜRÜMÜ ARTIK HER YANITTA + İKİ SESSİZ ARIZA**. Önceki vardiyanın en üstteki kod borcu kapandı: `config/app.php`'de tanımlı olan API sürümü hiçbir yanıtta okunmuyordu. Artık `AppendServerTime` → **`AppendServerMeta`** (ad da gerçeği söylüyor) ve `api_version` her JSON API yanıtına TAŞIMA katmanından ekleniyor — uç nokta uç nokta değil, çünkü alan uç noktanın değil taşımanın özelliğidir. Ek olarak **kimliksiz `GET /api/v1/version`**: "canlıda hangi sürüm koşuyor?" sorusunu soran taraf çoğu zaman token'ı OLMAYAN taraftır. Telefon tarafında sürüm **`sync_meta.api_version`**'a önbellekleniyor (şema **v16**, yükseltme testi yazıldı ve totoloji OLMADIĞI kanıtlandı — ALTER geri alınınca kırmızıya döndü) ve Ayarlar → Hakkında'da AYRI bir "Sunucu" satırında görünüyor; uygulama sürümüyle BİRLEŞTİRİLMEDİ (iki ayrı hat, CLAUDE.md → Sürümleme). Yokluk bilinen son sürümü EZMEZ, tip kontrolü zorunlu (`as String` bir gösterim alanına senkronu düşürme yetkisi verirdi), karşılaştırma/uyarı BİLİNÇLİ olarak yok (uyumsuzluk kuralı önce YAZILI kararlaştırılır). Bağ makineyle zorlandı: API testi mobil ayrıştırıcının `api_version` okuduğunu kaynaktan denetliyor. **İKİ SESSİZ ARIZA BULUNDU, ikisi de bu turun işi değildi:** ① durum çubuğu **"YAYIN BORCU 384"** diyordu, gerçek borç **0**'dı — kimse yerelde `main`e checkout etmediği için yerel ref `16833e7`te donmuş, uzak `827767a`ydı; ölçüm `origin/main..origin/dev`e alındı. Kusur göstergenin var oluş sebebine düşüyordu (41'i görünce alarm versin diye konmuş kırmızı sayı, 0 iken 384 diyorsa artık okunmaz) — bu depoda ikinci kez: **yanlış alarm gerçek alarmı görünmez yapar.** ② `PaymentSecurityTest`'in "gövdeye güvenilmez, iyzico retrieve'i esastır" testi **aylardır KIRMIZIYDI** ve iki kardeşi YEŞİL ama VAKUMDU: fiyat 2026-08-04'te 5.988 ₺'ye çıkınca test içindeki sabit `1200.00` tutar denetimine takılıyordu; tutar artık `config`ten türetiliyor. **Önceki vardiya API'yi "685/685 ✅" diye kaydetmişti; bu ağaçta o rakam 684 yeşil + 1 kırmızı çıktı.** Ölçüm BİZZAT koşuldu: mobil **1152/1152** · API **688/688** (3481, 1 kasıtlı incomplete) · `dart analyze` **1 info** (aşağıda) · phpstan **0** · pint temiz. **YENİ BULGU:** bu makinedeki Flutter SDK artık `pubspec.lock`tan yenidir — `flutter test` lock'taki dört geçişli paketi bump ediyor (geri alındı, SDK yükseltmesi ayrı bir karardır) ve `order_list_parts.dart:161` `onReorder` için yeni bir deprecation info'su çıkıyor. Yani "analyze 0" artık otomatik doğru değil. **CİHAZDA DOĞRULAMA YAPILMADI.** Öncesinde — 2026-08-09/2-3-4 — **SAHA ARIZASI KAPANDI + DAĞITIM İKİYE AYRILDI**. Kurye atama arızasının kök nedeni bulundu ve kullanıcı GERÇEK CİHAZDA doğruladı (yenilemede anında, dokunmadan 15–20 sn): yerel yazım senkron turunu TETİKLEMİYORDU; artık bekleyen-outbox akışına bağlı yazım tetiği + ön planda 30 sn aralık + tur başına 90 sn sınır var. Aynı bölgede dört "watch* build içinde kuruluyor" titremesi ve kurye başlık sayacı da kapatıldı; `PushOzeti.beklemede` banda bağlandı (tanımlıydı, hiç okunmuyordu). ALTYAPI: üretim iki kez çöktü (17:01 · 20:10) ve sebebi ARANAMADI çünkü günlükler container ile birlikte siliniyordu → `LOG_CHANNEL=stderr` + json-file döndürme (10 MB × 3); aylardır yanan `running:unhealthy` alarmının suçlusu `queue`/`scheduler` container larının temel imajdan MİRAS aldığı HTTP healthcheck i çıktı (SSH + `docker inspect` ile OKUNDU; dışarıdan yürütülen üç tahmin de yanlıştı) → `healthcheck: disable: true`; dekoratif `deploy:` bloğu kaldırıldı. Deploy kesintisi ÖLÇÜLDÜ: **52,3 sn** (218 örnek), kesinti deploy un SONUNDA — ilk ~86 sn build ve site normal. DAĞITIM: `dev` e atılan her commit SAHADAKİ BAYİLERİN telefonuna iniyordu; kanal ayrıldı (`main`→saha · `dev`→test), ayrı paket kimliği (`com.sipario.app.test`), sunucu adresi derleme sabiti oldu; `test.sipario.com.tr` ortamı kuruldu (kendi veritabanı, Google anahtarları BOŞ, mail `log`). SemVer kuralı `CLAUDE.md` → "Sürümleme"ye yazıldı: uygulama **0.10.0**, API **1.0.0**, birbirine EŞİTLENMEZ; derleme numarası sürüm değil, makinenin karşılaştırma anahtarıdır. Durum çubuğu yeniden tasarlandı (SAHA/TEST/API/YAYIN BORCU · renkli · BÜYÜK HARF etiketler · `+N` yalnız MOBİL değişikliği sayar, `surum.json` artık commit SHA taşıyor). `check_permissions.sh` harf duyarlılığı yüzünden flavor lu manifestlere HİÇ bakmıyordu — kırmızı çizgi #6 nın otomatik denetimi delikti, kapatıldı ve dişli olduğu kanıtlandı (saha 2 · deneme 2 · magaza 0). Ölçüm: mobil **1143/1143** · API **685/685** · analyze **0** · phpstan **0** · pint temiz · iki APK derlendi ve kendi çıktılarından doğrulandı. Dallar eşit (`main` == `dev` == `ca7dde7`), saha ve test kanalları 0.10.0. AÇIK VE ACİL: **SSH anahtarı DÖNDÜRÜLMELİ** (sohbete düz metin yapıştırıldı) · **bildirim kanalı yok** (çöküşü kimse duymuyor) · **API sürümü hiçbir yanıtta okunmuyor**. Öncesinde — 2026-08-09 — **ÜRÜN CANLIDA + KAYIP VARDİYA HAFIZASI ONARILDI**. Sipario **2026-08-07'den beri Türkiye'de bir VPS üzerinde Coolify ile canlı çalışıyor**: `sipario.com.tr` (site + `/panel`) ve `api.sipario.com.tr` (mobil), Postgres 16 (ICU tr-TR, üç rol, port dışarı kapalı), Traefik+Let's Encrypt TLS, Cloudflare DNS, izlenen dal `main`. Mobil uygulamanın varsayılan sunucu adresi canlıya çevrildi ve giriş ekranındaki "+ Gelişmiş (sunucu adresi)" bölümü kaldırıldı. **Ama bu gerçek üç gün boyunca bu dosyada YAZILI DEĞİLDİ:** Claude oturumu limitle kesilince iş Gemini (Antigravity CLI) ile sürdürüldü, araç `CLAUDE.md`'yi okumadığı için vardiya sözleşmesini bilmiyordu — kod yazıp commit attı, ortak hafızayı güncellemedi. Bedeli ölçüldü: 2026-08-09'da yeni bir oturum "canlıya geçelim" isteğine **sıfırdan üretim altyapısı planı** sundu, oysa `docker-compose.prod.yml` iki gündür repodaydı. Bu vardiya hafızayı onardı ve **üç güvenlik açığı kapattı**: ① `AdminUserSeeder` panel superadmin parolasını (`SiparioAdmin2026!`) public depoda düz metin taşıyor ve `updateOrCreate` ile her deploy'da geri yazıyordu — parolayı elle değiştirmek işe yaramıyordu; artık seeder parola TAŞIMIYOR, yeni hesap rastgele parolayla doğuyor, var olana `firstOrCreate` ile dokunulmuyor, parola `panel:admin --sifirla` ile alınıyor. ② `Dockerfile` entrypoint'i her container açılışında `db:seed` koşuyordu (`DatabaseSeeder` → Admin + **DemoSeeder**), yani ÜRETİM veritabanına her deploy'da demo bayisi ve sahte Bursa müşterileri yazılıyordu — seed deploy'dan çıkarıldı, kurulu demo bayisi yerinde. ③ `|| true` migration hatasını yutuyor, şema güncellenmese bile container "sağlıklı" kalkıyordu — bu, bu dosyada "sessiz arıza dersi" olarak YAZILI olan `saha-sunucu.ps1` hatasının birebir tekrarıydı; artık `set -e` (migrate düşerse rollback devreye girer). **COOLIFY ENV DENETİMİ YAPILDI (kullanıcı doğruladı):** `APP_KEY` **tanımlı** → compose'daki public varsayılan kullanılmıyor, kritik madde KAPANDI. `GEOCODING_DRIVER=kademeli` ✅. `IYZICO_BASE_URL` sandbox (beklenen — üretim anahtarı yok). **`ROTA_SURUCU=yakin-komsu`** → Google Routes KAPALI, oto sıralama kuş uçuşu çalışıyor (bilinçli mi belirsiz; açmak `ROTA_SURUCU=google` + `GOOGLE_ROUTES_KEY` ile tek satır). **🔴 `MAIL_MAILER=smtp` ama SMTP KURULMADI** — parola sıfırlama SESSİZCE çalışmıyor: bayi "e-posta gönderildi" görüyor, e-posta hiç gelmiyor (`Parola.php` `try/catch`+`report`, numaralandırmayı önlemek için ekrana yansıtmıyor); parolasını unutan bayinin kurtulma yolu YOK. Ayrıca Coolify MCP kuruldu (salt-okunur, kullanıcı kapsamında) ve ilk turda üç şey buldu: migration ZATEN post-deployment'ta koşuyordu (Dockerfile'daki ikinci kopya kaldırıldı, yarış borcu kapandı) · healthcheck `curl`e dayanıyordu ve uygulama `running:unhealthy` görünüyordu (PHP tabanlı teste çevrildi; sahte alarm sustu ama `healthy` doğrulanamadı) · `www`+`api` altalanları ölüydü, kök neden domain alanındaki virgül+boşluk (kullanıcı sildi, üçü de 200; `api./` 404 ile `BlockApiHostWebRoutes` ilk kez gerçekten kanıtlandı). **MCP SINIRI:** env değerlerini döndürmüyor, deployment logu yok. Belgeler gerçeğe döndürüldü: demo kimliği `111/111/1111` → `demo/demo/demo1234` (mağaza notları + `saha-sunucu.ps1`). Ölçüm BİZZAT koşuldu: mobil **1108/1108** · phpstan **0** · pint temiz (önceki not "1077/1077 · 668/668" diyordu — kopyalanmış rakamlardı). Kalan borçlar: makine dışı yedek YOK · Yetki Matrisi'nin (+2816 satır) hiç testi yok · migration yarışı (`start-first` + iki container) · cihaz doğrulaması. Öncesinde — 2026-08-06 — **ÜÇ SAHA İSTEĞİ + GÜN SONU → GÜN ÖZETİ** (4 ajanlı swarm, ÜÇ bağımsız inceleme turu). ① Müşteri listesi artık kayıt sırasına göre (en yeni üstte); "rasgele diziyor" şikâyetinin kökü alfabetikti — SQLite BINARY collation Türkçe harfleri tüm ASCII'den sonra dizdiği için "Şükrü" listede "Zeynep"in altına düşüyordu. ② İşletme profiline **IBAN alıcı adı** ve **düzenlenebilir hatırlatma şablonu** geldi (`*musteriadi*` `*isletmeadi*` `*siparistutar*` `*ibanodemebilgileri*`; sonuncusu SABİT blok, dokunulmamış bayide mesaj bir karakter bile değişmiyor; mobil şema v14 + sunucu + web hesap paneli). ③ **Gün Sonu → Gün Özeti**: ilk ekran bugün, Geçmiş AYRI ekran ve teslim sekmesinin gün şeridiyle geziliyor (kopyalanmadı, aynı bileşen), kapalı VE açık geçmiş günler görünüyor; **ara tahsilat** eklendi (sayımlı serbest tutar, gün açık kalır, patron her kuryeden / kurye yalnız kendi kasasından, tek kişilik bayide hiç çizilmez) ve ŞEMA DEĞİŞİKLİĞİ GEREKMEDİ — `cash_handovers` zaten append-only ve `period_start` "son devir" tanımlıydı. **Asıl iş "beklenen nakit" tanımındaydı ve ÜÇ kez yanlış kuruldu**, üçünü de inceleme turları yakaladı: (1) yalnız ara tahsilatları düşmek kurye hesabı kapandığında parayı İKİ KEZ istiyordu, (2) tüm devirleri düşmek gün kapsamında İÇ TRANSFERİ para çıkışı sayıyordu (patron 10.000'i kasasında görürken ekran "beklenen 0" diyordu → her akşam sahte FAZLA), (3) kurye STOKUNU düşmek bir AKIŞTAN bir STOK çıkarıyordu (kurye dünden para taşıyorsa beklenen negatife düşüyor, üstelik "her gün biraz artık para tutan kurye" senaryosunda sapma BİRİKİYORDU). NİHAİ: `gün = günün nakdi − Σ(kuryenin O GÜN topladığı − O GÜN teslim ettiği)`, `kurye = penceresinde topladığı − teslim ettiği` (pencere son kurye kapanışına demirli, yoksa alttan AÇIK). YAN KAZANÇLAR — hiçbiri bu turun işi değildi, üçü de gerçek arızaydı: senkronda **zehirli hap** (Carbon'un çözüp Postgres'in reddettiği damga TÜM PARTİYİ 500'e düşürüp kuyruğu kalıcı kilitliyordu → sınırda normalizasyon + `22007`/`22008`), **offset'li damga 3 saat kayıyordu** (TR 23:30'da kapanan gün ertesi güne düşüyordu; aynı olayın zamanı `sync_changes`e doğru, varlık tablosuna kaymış yazılıyordu), **dünü kapatan kapanış "dün kapalı" göstermiyordu** (özellik sessizce çalışmıyordu), WhatsApp hatırlatmasında boşluklar `+` oluyordu, gün sınırı cihaz saatinden kesiliyordu (artık `lib/data/tr_gun.dart` tek tanım + düzeltilmiş sunucu saati, ekranlar ve bildirim üreticileri dahil). VARDİYANIN KALICI DERSİ: **anlamı değişen sayıyı eski kelimesiyle taşımak** — aynı hata sınıfı YEDİ kez tekrarlandı ve her seferinde analyze+suite yeşil geçti; üç kapak kuruldu (anlam değerle taşınır/`DusulenKalem` enum'u · ekran metni formül iddia etmez · etiketler iki yönlü kilitlenir). Ayrıca `a − b == c` testinin `c` zaten `a − b` ise VAKUM olduğu ölçüldü. AÇIK BORÇ: **LWW'nin saniye-altı ayrımı YOK** (kolonlar `timestamptz(0)`; aynı saniyede kazanan "daha yeni" değil `device_id`si büyük olan — panel kapağını koymuş, mobil senkron yolunda kapak yok; 18 kolonluk migration ister, `markTestIncomplete` ile suite'te CANLI sinyal). Ölçüm: mobil **1077/1077** (+119) · API **668/668** (3347, 1 kasıtlı incomplete) · analyze **0** · phpstan **0** · pint temiz. **CİHAZDA DOĞRULAMA YAPILMADI.** Öncesinde — 2026-08-05/4 — **SAHADAN 10 MADDELİK SİTE LİSTESİ KAPANDI** (5 ajanlı swarm). Kullanıcı web tarafında 10 madde saydı; **ikisi sessiz ARIZAYDI**, sekizi ürün kararı. (1) "Giriş yaptım ama giriş yapmış görünmüyorum": genel sayfalar `tenant` middleware'i taşımadığı için `app.tenant_id` kurulmuyor, `users` RLS FORCE sıfır satır veriyor ve `Auth::guard('web')->check()` giriş yapmış patrona **false** diyor — ÜSTELİK `$oturum` prop'unu hiçbir sayfa geçmiyordu, yani iki arıza üst üsteydi ve birini düzeltmek yetmezdi. Çözüm kullanıcıyı hiç yüklemiyor (`session()->has(...)`, sıfır sorgu). (2) Oturumdan çıkmanın tek yolu "İşletme bilgileri" sekmesinin dibine gömülüydü → üst menüye POST+`@csrf` çıkış (GET olsaydı prefetch/`<img>` ile istemsiz tetiklenirdi), yeni `site.cikis` rotası. Ürün kararları: "Dönemi seçin"→"Yenileme ödemesi" (radyo düğmeleri kalktı — ekran form kontrolü diliyle konuşurken aslında ödeme adımıydı) · ödeme "Vazgeç"i beyaz listeli `geri` anahtarıyla geldiği sekmeye döner (`Referer` reddedildi) · "Oto-sıralama"→"Kullanım ve ek paketler", ek KURYE paketi de satılıyor · **web'den kurye hesabı açma/devre dışı bırakma** (yeni Ekip sekmesi; üç ayrı yazma yolu, gerçek DELETE yok çünkü FK olmadığı için sahipsiz para kaydı bırakırdı; kota İKİ YÖNDE zorlanıyor) · **"Kurumsal" plan siteden kaldırıldı** (uydurma vitrindi, `plans` tek satırlı), `/fiyatlar` `noindex`+menüden çıktı · üst menü 4→2 · alt bilgideki 4 İKİZ bağlantı kaldırıldı · footer künye bloğu kaldırıldı (mevzuat karşılığı iki hukuk belgesinde ölçülerek kanıtlandı) · `a` alt çizgisi yalnız düz metinde. YAN KAZANÇ: `/hesap-silme` siteden hiçbir yere bağlı değildi — Google Play şartı, mağaza başvurusunu bloke edebilirdi. Ölçüm: **643/643** (3197) · pint temiz · konsol sıfır hata. AÇIK: mobil yerleşim tarayıcıda ölçülemedi (`resize_window` no-op, iframe kendi güvenlik başlıklarımıza takılıyor) — kullanıcının telefonundan doğrulanacak. Öncesinde — **WEB UI ARCI: İKİ KÖK NEDEN KAPANDI**. "Web tarafında büyük sorunlar" şikâyetinin altından iki ayrı kök neden çıktı ve ikisi de kapatıldı: ① `trustProxies` yokluğu — cloudflared tüneli arkasında tüm varlıklar `http://` üretiliyor, HTTPS sayfada AKTİF KARIŞIK İÇERİK doğuyor ve mobil Chrome CSS'i koşulsuz engelliyordu; site tünelden herkese ÇIPLAK görünüyordu, masaüstünden `http://127.0.0.1:8000`e bakan kimse görmüyordu (çözüm: `bootstrap/app.php` dar kapsamlı `trustProxies`, `URL::forceScheme` REDDEDİLDİ). ② `@js(dizi/nesne)` + csp_safe — Blade'in ürettiği `JSON.parse` ifadesini CSP değerlendiricisi çözemiyor, x-data SESSİZCE hiç kurulmuyor; /fiyatlar bu yüzden "Aylık" seçiliyken YANLIŞ FİYAT (499 ₺, doğrusu 599 ₺) gösteriyordu, /destek SSS'i ve panel firma-combo ölüydü (çözüm: yük `application/json` kanalı/`data-*` + `jsonKanal`, kural alpine.js başlığında). Ek: panel modallarında dış-tıklama kapatması `if` DEYİMİ yüzünden ölüydü → Alpine `.self` değiştiricisi. Tasarım farkları kapandı: JetBrains Mono yerel woff2 (orijinal paketten, dış indirme YOK) · hero telefon animasyonu (`heroDongu`, kare/süreler TelefonCanli'den birebir) · `.dg` alt çizgi · 44px dokunma hedefleri · çerez politikası + 4. yasal bağlantı · "Parolamı unuttum" etiket satırında · `[Telefon]` düz-cümle kullanımı koşullu. "Oturumumu açık tut" BİLİNÇLİ dışarıda (users.remember_token migration'ı + güvenlik incelemesi ister — borç). Doğrulama: 7 sayfa desensiz konsol taramasında sıfır hata, /fiyatlar anahtarı ve /destek canlı ölçümlü, panel combo+modal canlı, gerçek cihazda 7 sayfa tam stilli+https zinciri. AÇIK: 360/320px canlı yerleşim turu (ajanlar 15:30'da limitten dönüyor) · kullanıcının telefonundan son kabul · telefonda ~11 trycloudflare sekmesinin temizliği. Öncesinde — **BAĞIMSIZ İNCELEME: HÜKÜM DÜZELTİLDİ + SÜRÜM ÇARPIKLIĞI KAPANDI**. Kullanıcı önceki teşhise güvenmeyip çürütme amaçlı swarm istedi; haklı çıktı. Olayın en olası sebebi zehirli hap DEĞİL, o an WiFi'ın internet vermemesiymiş (cihaz radyo kayıtları: WiFi bağlıyken trafik mobil veriye düştü) — "PC'den curl 200 → telefon suçlu" çıkarımı geçersizdi, veri temizliği muhtemelen gereksizdi ama eski bant her şeye "Çevrimdışı" dediği için bilinemezdi. AYNI swarm kullanıcının migration hipotezini HATA SINIFI olarak doğruladı: eski istemcinin push'u bilmediği yeni kolonları null'a çeviriyordu (IBAN+kurye yetkileri+sipariş kodu · kara liste · kurye telefonu) → `SyncPayload::gonderilenler` "anahtar YOK ≠ anahtar null" (testli); pull yönünde İKİNCİ zehirli hap (tek bozuk delta satırı cursor'u kilitliyordu) → satır izolasyonu + görünür `veri` hatası, bilinen boşluğu borçta; zaman aşımı yolu testle kilitli, `batchSize` 400, ana ekran çipi dürüstleşti. Cihaz kanıtları (SM-S721B): locked ertelemesi kalp-atışı yöntemiyle, içerik bütünlüğü, dürüst bant+adres ekran görüntülü. Ölçüm: API **610/610** (3077) · mobil **958/958** · analyze **0** · phpstan **0** · pint temiz. Cihaza **2250** kuruluyor. Öncesinde — **SENKRONDA DÖRT ZEHİRLİ HAP KAPANDI + KALİTE KAPISI ARIZASI**. Sahadan "giriş yapıyorum ama Çevrimdışı yazıyor" şikâyeti geldi; sunucu her boyutta sağlamdı (login 200, pull 200, migration'lar koşulu) ve arıza telefondaydı. Dört ayrı yol senkronu KALICI kilitliyordu ve tek "çözüm" uygulama verisini silmekti — ki bu bekleyen sipariş/tahsilatı yok eder: **(1)** parti düzeyinde 422 (tek bozuk olay tüm kuyruğu rehin alıyor; `SyncPushRequest`in belge başlığı tersini SÖZ VERİYORDU), **(2)** `locked` → `acked` (abonelik kilitliyken yazılan kayıt sessizce siliniyor, yenilense bile gönderilmiyor), **(3)** bilinmeyen durum → `acked` (sunucu yeni bir status eklediği gün eski istemciler kaydı silecekti), **(4)** `22001`/`22003` → 500 (uzun müşteri adı senkronu kilitliyor; 4xx'ten kötü, çünkü istemci 5xx'i geçici sayıp sonsuza dek deniyor). Sunucu artık olayı per-olay reddediyor (`EventValidator`, `reason`+`index` sözleşmesi) ve **bu düzeltme sahadaki kilitlenmiş telefonu uygulama güncellemesi OLMADAN kurtarıyor**; istemci tarafında bisect + karantina (kayıt SİLİNMEZ) + dürüst bant (`hataTuru` artık 4xx'i "çevrimdışı" demiyor, bant hangi adrese ulaşamadığını yazıyor). **Ayrıca gecenin kendisi bir bulgu üretti:** `Stop` kancasına bağlı kalite kapısı `artisan test`+`flutter test` koşuyor ve her ajan turunda ateşleniyor — çok ajanlı vardiyada eşzamanlı suite'ler ~130 SAHTE kırık üretiyordu (aynı ağaç: 433/600 · 387/600 · 504/600 → kilitlendikten sonra **601/601**). ~3 saat ve üç yanlış teşhis buna gitti; kimse kancadan şüphelenmedi çünkü commit mesajları "kalite kapisi yesil" diyordu. Mutex + süreç kontrolü ile kapatıldı. Ölçüm: API **601/601** (3033) · mobil **942/942** · analyze **0** · phpstan **0** · pint temiz. **Cihaz doğrulaması YAPILMADI** — kablosuz adb kuruldu (SM-S721B) ama telefondaki build 2221 bu düzeltmeleri taşımıyor. Öncesinde — **TASARIM ENTEGRASYONU: PANEL SIFIRDAN + SİTE BAŞTAN**. `design_handoff_web_and_yonetim_paneli/` altındaki iki paket açıldı (paketlenmiş React; 26 modül + 71 KB CSS `_kaynak/` altına çıkarıldı) ve Blade+Livewire+Alpine ile hayata geçirildi — React DEĞİL, gerekçe DECISIONS'ta. **Yönetim paneli sıfırdan yazıldı** (10 ekran; tasarımın 5'i + BRIEF'in zorunlu kıldığı iş verisi sekmeleri/dışa aktarım/modül/parola/cihaz/churn + tasarımda olmayan havale kuyruğu ve kurye açma). **Site baştan kuruldu**: pazarlama sayfaları + 3 adımlı işletme açma + parola sıfırlama/yenileme + **IBAN ödeme akışı** + **bayinin hesap paneli**. Abonelik modeli: aylık+yıllık, deneme 30 gün, fiyat DB'de ve panelden düzenlenebilir; **havale beyanı ≠ ödeme** (beyan abonelik UZATMAZ, panel eşleştirir); hukuk onayları kolonlarda (`consent_version`/`consented_at`, DB CHECK'li). 12 migration · 6 model · 8 servis · CSP başlığı (üç ayrı politika, `csp_safe`). **Ondört sessiz arıza bulundu** — hiçbiri çökmüyordu: hesap paneli `auth:web`+RLS yüzünden hiç çalışamazdı, panel düğmeleri Livewire kalıcı middleware eksikliğinden ölüydü, aramaya tek harf yazınca 500, `"izmir"` `İZMİR`'i bulamıyordu, `%` tüm bayileri getiriyordu, sekiz ekran UTC saatiyle yanlış gün basıyordu, ek paket kotası paralel istekte iki kez artıyordu (geri alınamaz), iptal eden bayi yazmaya devam edebiliyordu, erken yenileyen kalan günlerini kaybediyordu, ve kırmızı çizgi #1'i koruduğu sanılan iki test namespace hatası yüzünden HİÇ KOŞMUYORDU. Ölçüm: **593/593** (2966 doğrulama) · phpstan L6 **0** · pint temiz. **Mobil tarafa dokunulmadı.** Öncesinde — **PANEL GİRİŞ ARIZASI KAPANDI**: panel girişi e-postayı normalize etmiyordu; hesabı açan iki yol da küçülterek saklarken giriş HAM değerle sorguladığı için tarayıcının büyüttüğü ilk harf DOĞRU PAROLAYLA "Giriş bilgileri hatalı." veriyordu (sondaki boşluk ise `email` kuralına takılıyordu). Ekran numaralandırmaya karşı bilerek nötr konuştuğundan kullanıcı teşhis edemiyordu. Ayrıca `panel:admin --sifirla` eklendi: komut kendi açıklamasında "kurtarma yolu" diyordu ama var olan hesabı sıfırlayamıyordu — parola bir kez basılıp saklanmadığı için kilitlenen yöneticinin gidecek yeri yoktu. Ölçüm: API **437/437** (+4 test) · pint temiz. Öncesinde — **ALTI SAHA İSTEĞİ + SAHA SUNUCUSU 530 ARIZASI**. Kurye yönetimi büyüdü: giriş bilgileri (kullanıcı adı/parola) uygulamadan düzenlenebiliyor (`PATCH /team/{user}/credentials`, çevrimiçi, yalnız patron, parola değişince oturumlar düşer) ve **5 anahtarlı kurye yetki sistemi** geldi (müşteri/sipariş/tahsilat açık · gün sonu/iskonto kapalı doğar; kiracı düzeyinde, çağrı yerlerine bağlı). Borçlulara **tek tuşla WhatsApp hatırlatması** (IBAN Ayarlar→İşletme Profili'nde, mod-97 denetimli; mesaj hazırlanır, gönderilmez). Teslim sekmesine **gün gezinmesi**. Sipariş kaydı artık **siparişler ekranına** dönüyor. Müşteri kodu doğrulandı (çalışıyor, kod değişikliği yok). Altyapı: `saha-sunucu.ps1` tünel adresini DOĞRULUYOR ve QUIC engellenmişse http2 ile yeniden deniyor — bayinin gördüğü HTTP 530'un kök nedeni buydu ve script "hazır" deyip yeşil yanıyordu. Ölçüm: API **433/433** · mobil **906/906** · analyze **0** · phpstan **0** · pint temiz. Eski not aşağıda tarihsel duruyor: 2026-08-01/2 — **ROTA/HARİTA UX YENİDEN YERLEŞTİ** (Oto Sırala haritada, 'Rota sırası' görünümü, araç şeridi) + dikte kuralı tersine + 'Kurye ata' çipi. Ölçüm: analyze **0** · mobil **885/885** · API **298/298**. Aynı gün öncesinde — **SEKİZ SAHA İSTEĞİ KAPANDI** (5 ajanlı swarm): sesli dikte birikimli oldu, adres alanı büyüdü, barkoda fener, çağrı kartında sipariş yaşı, sipariş formuna kurye seçimi, oto sırala düğmesi gerekçeli-pasif (kök neden: yanlış sekmede etkin düğme), müşteri silme + kara liste (cascade tombstone + LWW damga koruması), kapıda iskonto (`discount` defter tipi, kasa değişmezi korunur). Ölçüm: analyze **0** · mobil **878/878** · API **298/298** · phpstan **0** · pint temiz · Kotlin saha-release yeşil · APK kapısı koşuldu. Önceki gün: 2026-07-30 — **CANLI KURYE KONUMU + ARAYAN TANIMA ANAHTARI**: patron haritada tüm ekibin canlı konumunu görüyor (kendi backend, Google'sız, KVKK: tek satır/geçmiş yok/yalnız patron okur); Ayarlar'a arayan tanıma AÇ/KAPA anahtarı (düz dosya köprüsü, native taraf zil anında okur; günlük kapalıyken de doğru). Aynı gün öncesinde: harita performans+dark mod, harita stil+kontroller, rota yönü düzeltmesi+pin özeti, Bursa reseed, kademeli geocoder, giriş arızası. Ölçüm: `dart analyze` **0** · `flutter test` **798/798** · `php artisan test` **287/287** · phpstan L6 **0** · `compileSahaReleaseKotlin` **BUILD SUCCESSFUL** · release APK kapısı koşuldu. Eski not aşağıda tarihsel duruyor: 2026-07-29 — sıra kodları (müşteri 100+ · sipariş #248, sunucu atar), borç görünürlüğü, Borçlular ekranı, gün sonu yeniden yapılandırıldı (geçmiş günler + gün detayı + ürün kırılımı), aşağı çekerek yenile, sihirbazdaki pil/otomatik-başlatma karışıklığı. Altyapıda: CDN bayat `surum.json` (güncelleme hiç düşmüyordu), senkron deltasına düşmeyen kodlar (telefona hiç gitmiyordu), kalite kapısının SESSİZCE kapalı API bölümü, çerçeve davranışına bağlanmış font testi. Öncesinde: konum altyapısı (Yandex, sağlayıcı soyut), tam otomatik saha dağıtımı, çağrı kartı+bildirim, otomatik versiyonlama. Ölçüm: `dart analyze` **0** · `flutter test` **740/740** · `php artisan test` **247/247** · phpstan L6 **0** · pint **temiz** · Kotlin `:app:compileSahaDebugKotlin` **BUILD SUCCESSFUL** · yayındaki saha yapımı **158**, ağaç **159**)

### 🔻 VARDİYA DEVİR NOTU — 2026-08-12 (e-posta şablonları)

**NE YAPILDI** (hepsi ölçüldü):

| İş | Nerede | Durum |
|----|--------|-------|
| Posta tasarım sistemi | `resources/views/components/eposta/` (düzen + 8 blok bileşeni) | ✅ |
| 13 şablon (HTML + düz metin) | `app/Mail/` · `resources/views/eposta/` + `eposta/metin/` | ✅ |
| Ortak taban + postacı | `app/Mail/SiparioPostasi.php` · `app/Eposta/BayiPostacisi.php` | ✅ |
| Tetikleyicilere bağlama | `Register` · `Subscribe` ×2 · `Hesap` · `Ekip` · `ParolaYenile` · `OdemeBildirimServisi` ×2 · `EkPaketServisi` · `AppServiceProvider` | ✅ |
| İlk zamanlanmış görev | `app/Console/Commands/AbonelikHatirlatmalari.php` · `routes/console.php` | ✅ |
| Sözleşme testi | `tests/Feature/EpostaSablonlariTest.php` | ✅ 89/89 |
| Gönderen adresi | `.env` + `.env.example` (`hello@example.com` → `bilgi@sipario.com.tr`) | ✅ |

**NE YAPILMADI (ve neden):**

- **E-POSTA DOĞRULAMA AKIŞI YAZILMADI.** Kullanıcı "sert: doğrulanmadan giriş yok" dedi ama bu kademe
  onaylanan kapsamın (①+②+③) DIŞINDAYDI ve bir posta şablonu değil, giriş yolunu değiştiren bir
  ÖZELLİKtir: migration (`users.email_verified_at` **yok**) + `MustVerifyEmail` + giriş kapısı + doğrulama
  ekranı + panelde elle doğrulama. Yarım bırakılırsa insanları hesaplarından kilitler. **Yazılmadan önce
  bilinmesi gereken üç kısıt ölçüldü:**
  1. **Kural MOBİLDE UYGULANAMAZ.** Kurye e-postaları SAHTEdir — `Provisioning.php:209` onları
     `<kullanıcı>@<firma-kodu>.sipario.local` diye türetir; o adrese doğrulama postası gitmez. Mobil
     uygulamaya giren asıl kitle kuryedir.
  2. **Mağaza incelemesi kırılır.** BRIEF: "Giriş ekranlı uygulamayı incelemeci açamazsa reddedilir."
     Demo hesabı doğrulanmamışsa uygulama mağazadan döner.
  3. **`Login.php:26` ters yönde bir kural taşıyor:** "süresi dolan bayi tam da ÖDEME YAPMAK için giriş
     yapar". Doğrulama kapısı o yolu kapatmamalı.
  **ÖNERİLEN KAPSAM:** yalnız WEB + yalnız PATRON; mobil giriş bu kapıya hiç bakmaz. Ayrıca yazım hatası
  kalıcı kilide dönüşmesin diye doğrulama ekranında **adres düzeltme + yeniden gönderme**, panelde **elle
  doğrulama** düğmesi şart.
- **SMTP KURULMADI.** `MAIL_MAILER=log`. Şablonlar hazır ama üretimde hiçbir posta çıkmıyor; bu bir kod
  işi değil, altyapı işi (aşağıda SIRADAKİ İŞLER'de).
- **Kademe ④'ün kalanı** (yeni cihaz girişi bildirimi, "dışa aktarma hazır" postası) kapsam dışıydı.
  İkincisi zaten dışa aktarım aracının kendisi olmadan yazılamaz.

**SIRADAKİ İŞLER (öncelik sırasıyla):**
1. **SMTP sağlayıcısı bağlanmalı + SPF/DKIM/DMARC kurulmalı.** Bu yapılmadan 13 şablonun hiçbiri kimseye
   ulaşmaz. Gönderen `bilgi@sipario.com.tr`; alan adı doğrulanmazsa postalar spam'e düşer ve bu SESSİZ olur.
   Doğrulandıktan sonra gerçek bir kutuya (Gmail + Outlook + iOS Mail) test gönderimi yapılmalı — bu vardiya
   tarayıcıda doğruladı, gerçek istemcide DOĞRULAMADI.
2. **E-posta doğrulama akışı** — yukarıdaki üç kısıt ve önerilen kapsamla.
3. `dev` → `main` birleştirme (bir önceki vardiyanın mobil işi hâlâ telefonlara inmedi).

### (ÖNCEKİ) VARDİYA DEVİR NOTU — 2026-08-11/3 (giriş ergonomisi + sürüm notları)

**NE YAPILDI** (hepsi ölçüldü, hiçbiri "yazıldı ama koşulmadı" değil):

| İş | Nerede | Durum |
|----|--------|-------|
| Parola göster/gizle | `login_screen.dart` · `form.dart` (`SipInput.sonEk`) · `icons.dart` (`goz`/`gozKapali`) | ✅ |
| Beni hatırla | `tables.dart` + şema **v19** · `session.dart` · `login_screen.dart` | ✅ |
| Güncelleme bandı sadeleşti | `guncelleme_banti.dart` | ✅ |
| Yenilikler ekranı | `guncelleme/surum_notlari.dart` (veri) · `screens/isletme/surum_notlari_ekrani.dart` (ekran) · Ayarlar→Hakkında girişi | ✅ |
| Yeni testler | `giris_hatirla_ve_parola_test.dart` (17) · `surum_notlari_test.dart` (13) · bant testi güncellendi (+2) | ✅ 1250/1250 |
| Sürüm | `pubspec.yaml` 0.13.0 → **0.14.0** | ✅ |

**NE YAPILMADI (bilinçli):**
- **Parola SAKLANMIYOR** ve bu bir karardır, eksiklik değil (gerekçe DECISIONS 2026-08-11/3). "Beni hatırla"
  yalnız firma kodu + kullanıcı adını doldurur. Genişletmek istenirse `PAROLA HİÇBİR ALANA YAZILMAZ` testi
  kırmızıya döner ve karar yazılı olarak yeniden alınır — sessizce genişleyemez.
- **Güncelleme bandı sürüm notlarına BAĞLANMADI.** Bandın tüm yüzeyi "kurmak için dokun"dur; içine ikinci
  bir dokunma hedefi koymak, yanlışlıkla kurulum başlatan bir bayi üretirdi. Yenilikler ekranı yalnız
  Ayarlar'dan açılıyor.
- **Sunucudan sürüm notu çekilmiyor** (gerekçe `surum_notlari.dart` başlığında, üç maddeli).

**SIRADAKİ İŞLER (öncelik sırasıyla):**
1. **`dev` → `main` birleştirme.** Bu vardiyanın işi telefonlara ancak oradan iner (saha kanalı yalnız
   `main`den beslenir). Rutin adım, tek seferlik karar değil.
2. **Gerçek cihazda giriş ekranı provası.** Widget testinde test fontu ~1,8× geniştir; parola gözünün ve
   "Beni hatırla" satırının dar ekranda (küçük telefon + büyük yazı tipi) nasıl durduğu ÖLÇÜLMEDİ.
3. **Sürüm notu yazma alışkanlığı.** Bundan sonra sürümü artıran her vardiya `kSurumNotlari`'nin başına
   bir kayıt ekler; eklemezse `EN ÜSTTEKİ kayıt pubspec.yaml sürümüyle AYNI` testi kırmızı olur (kapı
   kuruldu, ama alışkanlık insanda).
4. Önceki devir notunun açık maddeleri (aşağıda) hâlâ geçerli.

### 🔻 2026-08-10/3 — "8 KEZ YENİDEN BAŞLADI" ALARMININ KAYNAĞI KENDİ BAYRAĞIMIZDI

Kullanıcı Coolify'da yine yeniden başlatma gördü. **Sunucudan SSH ile ölçüldü, panele bakılarak
akıl yürütülmedi:** `queue` → `RestartCount=8` ama `ExitCode=0`, `OOMKilled=false`, `Error=""`;
`app`/`db`/`scheduler`/`backup` hepsi **0**. Yaratılış `01:36:48`, son başlangıç `09:37:16` —
**8 saat 28 saniyede tam 8 yeniden başlatma, yani saatte bir.** Çöküş yoktu: `--max-time=3600`
işçiye "1 saat sonra kendini sonlandır" diyordu ve o da tam bunu yapıyordu.

Zarar üç halkada doğuyordu: ① Docker `unless-stopped` altında çıkış kodu 0 ile çöküşü ayırmaz;
② Coolify sayaç arttıysa **çıkış koduna bakmadan** `crash` yazar ve sayacı uygulamanın **bütün
container'larının MAX'ı** olarak alır (`GetContainersStatus.php:465,474-480`) — sayaç yalnız tam
`exited`ta ya da yeni deploy'da sıfırlanır; ③ tavanda `StopApplication` (`:484`) → `CleanupDocker`
→ `external` ağ silinir → sonraki her deploy "network not found". Yani bu bayrak **tavana saatte
bir tıklayan bir sayaçtı**; ölçüm anında **8/10**'daydı ve ~2 saat sonra üretimi kendi kendine
durduracaktı. Her deploy sayacı sıfırlayıp fitili 10 saat sonrası için yeniden kurduğu için arıza
aylarca "arada bir" görünüp teşhis edilmedi.

**Yapıldı:** `--max-time=3600` compose'dan kaldırıldı (bellek koruması durur — `queue:work` zaten
varsayılan `--memory=128` ile koşar; fark, yeniden başlatmanın bir TAKVİM olmaktan çıkıp bir OLAY
olmasıdır). Kullanıcı panelden `max_restart_count`'u **0**'a (kapalı) çekti; `restart_count` da
0'a sıfırlandı — DB'den doğrulandı. `DeploySirasiTest`'e dördüncü madde eklendi ve **totoloji
olmadığı ölçüldü** (bayrak geri konunca kırmızı, çıkarılınca yeşil); iddia yoruma değil
`entrypoint:` satırına bağlandı, yoksa gerekçeyi yazmak testi kıracaktı. **4/4 yeşil.**

**Ders:** bayrağın kendisi doğruydu, yanlış olan onu **Docker'ın gözetmenliğine** bağlamaktı —
Docker "planlı çıkış" diye bir kavram tanımaz. Daha genel olanı: **bir sayaç, neyi saydığını
bilmeyen bir aksiyona bağlanırsa sağlıklı davranış ile arıza aynı sayıya yazılır.**

**AÇIK:** düzeltme henüz **deploy EDİLMEDİ** — dev'de koşan container hâlâ eski entrypoint'i
taşıyor (saatte bir yeniden başlamaya devam eder, ama tavan kapalı olduğu için zararsız).

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

**Sağlayıcı durumu (2026-07-29, son hali): sürücü `kademeli` — GOOGLE ÖNCE, YANDEX GEREKTİĞİNDE.**

| | |
|---|---|
| **Sıra** | Her sorgu önce Google'a; Yandex YALNIZ Google `bina` kesinliğinde aday veremezse (boş / sokak / semt / arıza) |
| **Birleştirme** | YOK (kullanıcı kararı 2026-07-29/2) — her aday "Google"/"Yandex" etiketiyle ayrı satır, Google'ınkiler önce |
| **Kota** | Yandex GLOBAL günlük tavan `YANDEX_DAILY_LIMIT=900` (1000/gün limitine pay); dolunca Yandex susar, Google devam eder |
| **Sayaç** | `geo:yandex:gun:<tarih>` önbellek anahtarı; yalnız GERÇEK Yandex çağrısında artar, çağrıdan ÖNCE (rezervasyon) |
| **Arıza** | Biri düşerse diğeri cevaplar; 503 ancak hiçbiri cevap veremezse |
| **Önbellek** | Aynı adres 30 gün önbellekten — kota yalnız İLK soruşta yanar |

`coklu` sürücü adı alias olarak yaşıyor (aynı kademeli davranış) — eski bir .env sürücüyü sessizce null'a düşürmesin diye. İlk `coklu` tasarımı (her sorguda ikisi + ≤25 m birleştirme + mutabakat rozeti) birkaç saat yaşadı ve kullanıcı geri çevirdi; ölçüm de destekledi (üç gerçek adreste 25 m mutabakat hiç oluşmadı).

**Canlı kademe ölçümü (2026-07-29, gerçek istekler):** `Aspendos Blv. No:75` → Google `bina` buldu, **Yandex'e hiç gidilmedi** (sayaç sabit) · `1497. Sok.` → Google sokakta kaldı, **Yandex devreye girdi** (sayaç +1), iki aday ayrı satır (`google` önce, `yandex` sonra).
### Canlı ölçüm — İKİ SAĞLAYICI AÇIKKEN (2026-07-29, gerçek istekler)

| Sorgu | Yandex | Google | Yorum |
|---|---|---|---|
| `1497. Sk. No: 9` | **sokak** 36.86318,30.73490 | **bina** 36.86004,30.73569 | Google kapıyı buldu, Yandex bulamadı — **iki sağlayıcı kararının somut kazancı** |
| `Aspendos Blv. No:75` | **bina** 36.88972,30.74301 | **bina** 36.88719,30.73194 | ⚠️ İkisi de "bina" diyor ama aralarında **~1 km** var |
| `Tekelioğlu Cad. No: 999999` | **bina** "…**No:9**…" | **sokak** (partial_match) | ⚠️ Yandex olmayan numarayı **sessizce No:9'a çevirdi** ve "bina" dedi |
| `zzzqqq bulunmayan adres` | — | — | Boş liste (Google'ın "Türkiye" adayı elendi) |

**Üç ders, üçü de ölçümden çıktı:**

1. **Sağlayıcılar birbirini tamamlıyor, doğrulamıyor.** Üç sorgunun HİÇBİRİNDE 25 m mutabakat oluşmadı; ikisi de kendinden emin, ikisi de farklı yeri gösteriyor. Seçimi kullanıcıya bırakmak süs değil, zorunluluk.
2. **"bina" etiketi tek başına güven vermiyor.** Aspendos örneğinde iki servis de "bina" diyor ve 1 km ayrışıyorlar. Kullanıcı koordinata/metne bakarak seçmeli — bu yüzden aday satırı ikisini de gösteriyor.
3. **Yandex olmayan kapı numarasını sessizce başka bir numaraya çevirebiliyor** (`No: 999999` → `No:9`, kesinlik "bina"). Bu, kesinlik alanının Yandex'te her zaman dürüst olmadığı anlamına gelir; Google aynı sorguda dürüstçe sokağa düştü. **Açık gözlem — düzeltilmedi:** yakalamak için dönen metindeki kapı numarasını sorgudakiyle karşılaştırmak gerekir. Tek sağlayıcıda bu sessiz bir yalandı; artık yanında Google'ın sokak adayı durduğu için kullanıcı farkı görebiliyor.

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

# 🔻 VARDİYA DEVİR NOTU — ÖNCE BUNU OKU (2026-08-11 · BEŞ SAHA İSTEĞİ + AJAN ÖLÜMLERİ)

> **BEŞ CÜMLELİK ÖZET:**
> 1. **Beş saha isteği de kapandı:** açık sipariş uyarısı (tek kapı, yalnız `open`) · favori
>    ürünler (`customers.favorite_product_ids` JSON dizisi) · sepet satır notu
>    (`order_lines.note`) · birim açılır menüsü · müşteri kartında son 3 sipariş + tümü ekranı.
>    Mobil şema **v18**, API'de iki migration. Sürümler MINOR: API **1.3.0**, uygulama **0.12.0**.
> 2. **Swarm'ın BEŞ ajanı da oturum limitinde öldü** ve ağacı DERLENMEZ bıraktı. Altı hatanın
>    hepsi bağlama hatasıydı (eksik import ×3, sınıf içinden görünmeyen üst düzey ad, dar
>    `show` yüzünden kapsam dışı kalan drift `&` operatörü ×2) — mantık hatası YOKTU.
> 3. **Mobil testlerin tamamını lead yazdı** (34 test, 4 dosya). Ajanlara "kendi testini kendin
>    yaz" denmişti; hiçbiri yetişemedi. Bu ÜST ÜSTE İKİNCİ vardiyadır — testler her zaman en
>    son sıradaki iş oluyor ve ajan ömrü ona yetmiyor. Bir sonraki swarm'da testi İLK iş yap.
> 4. **Veri kaybı yasağı iki yerde kilitlendi:** birim menüsünde "listede yoksa varsayılana
>    düş" dalı YOK (sahadaki "damacana" korunur, testi var) ve favori JSON çözümlemesi hiçbir
>    girdide çökmez (müşteri satırı her ekranda okunuyor; tek istisna o ekranı kaybettirirdi).
> 5. **Ölçüm:** mobil **1208/1208** · API **723/723** · `flutter analyze` temiz.
>    **CİHAZDA DOĞRULAMA YAPILMADI.**
>
> **SIRADAKİ İŞLER (bu vardiyadan devreden):**
> - **Cihazda doğrula:** açık siparişi olan müşteriye ikinci sipariş aç (uyarı çıkmalı, "Vazgeç"
>   durdurmalı) · favoriye ürün ekleyip sipariş formunda hızlı seçimden sepete at · satır notu
>   gir ve KURYENİN gördüğü yerde okunduğunu gör · listede olmayan birimli bir ürünü açıp kaydet
>   ve biriminin değişmediğini doğrula.
> - **Üç araç tuzağı yeniden ölçüldü:** ① `testWidgets` içinde `db.close()` sahte zamanda ASILIR
>   (saf sorgu testi `test()` olmalı); ② durdurulan `flutter test` yetim `flutter_tester` bırakıp
>   `sqlite3.dll`'i kilitler — DLL'i silme, süreci kapat; ③ **`artisan test` dakikalarca CPU'su
>   boşta "koşuyorsa" test DB'si kapalıdır** — Sipario'nun test veritabanı Laragon'un 5432'si
>   değil, `docker-compose.yml:27`'deki `55432:5432` container'ıdır. Tanı: `netstat | grep 55432`,
>   sonra tek dosyayı `--filter` ile koş (gerçek hata saniyeler içinde düşer). Kurtarma:
>   `docker start sipario_db` — `compose up` DEĞİL.
> - **Ajan adlandırma tuzağı:** aynı isim ikinci kez kullanılınca yeni ajan `ad-2` oluyor; eski
>   isme yazan bir ajan GEÇEN VARDİYANIN ölü ajanını uyandırıyor ve o, bu vardiyanın alanına
>   kod yazıyor. Bu turda yaşandı; swarm kurarken adları baştan ayır.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-10/4 · KURYE YETKİLERİ KİŞİYE BAĞLANDI)

> **BEŞ CÜMLELİK ÖZET:**
> 1. **Kurye yetkileri artık role değil KİŞİYE bağlı.** 13 yetki `tenant_settings`'te "bayi
>    varsayılanı" olarak kaldı; kişiye özel karar `users`'ın 13 **NULLABLE** kolonunda yaşıyor ve
>    etkin yetki `kisisel ?? varsayilan` ile TEK saf fonksiyonda çözülüyor (`kuryeIzinleriCoz`).
> 2. **`null` ≠ `false` ≠ "anahtar yok"** — payload'da anahtar yoksa "dokunma", açık `null` ise
>    "devral", bool ise "kişiye özel". Bu üçlüyü ikiye indiren her dokunuş ya bayinin kapattığı
>    yetkiyi geri açar ya kuryeyi eski ezmesine çakılı bırakır. Sözleşmenin can alıcı yeri budur.
> 3. **Yeni bir güvenlik kapısı eklendi:** yetki alanı taşıyan `user_profile` push'unu yalnız
>    patron/operatör yapabilir (`UserRole::kuryeYetkisiAtayabilir`); aktör olay gövdesinden
>    OKUNMAZ ve kapı LWW'den öncedir. Kapı olmasaydı kurye kendi iskontosunu offline açabilirdi.
> 4. **`team` bloğu pazarlıksızdı:** `users` her senkron turunda toptan silinip yazılıyor, o yüzden
>    13 alan yayına da eklendi. Eklenmeseydi yetki kaydedilir, sunucuya gider ve bir tur sonra
>    cihazda sessizce sıfırlanırdı — özellik "çalışıyor" görünüp kendini silerdi.
> 5. **Ölçüm:** mobil **1177/1177** · API **707/707** · analyze temiz · API **1.2.0** / uygulama
>    **0.11.0** (MINOR, geriye dönük uyumlu). **CİHAZDA DOĞRULAMA YAPILMADI** — sıradaki iş bu.
>
> **SIRADAKİ İŞLER (bu vardiyadan devreden):**
> - **Cihazda doğrula:** iki kuryeye farklı yetki ver, ikisinin telefonunda ekranların gerçekten
>   ayrıştığını gör. Özellikle `team` bloğu turundan SONRA ezmenin hâlâ yerinde olduğunu doğrula.
> - **Panel tarafı**: yönetim panelinde kurye yetkisi gösteren/yazan bir yüzey YOK; kişiselleşen
>   yetkiyi panelden görmek isteyip istemediğimiz karara bağlanmalı.
> - **Araç borcu:** `build_runner` komutu belgede eski (`flutter pub run …` AOT'ta düşüyor,
>   doğrusu `dart run build_runner build --force-jit`).

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-10/2 · ÜRETİM ÇÖKTÜ, KÖK NEDEN BULUNDU, KALICI DÜZELTİLDİ)

> **BEŞ CÜMLELİK ÖZET:**
> 1. **Üretim ~1 saat kapalıydı ve manuel deploy'lar "network not found" ile ölüyordu.** Bu bir
>    sonuçtu, hastalık değil: `queue` çöküyor → docker yeniden başlatıyor → Coolify 10. yeniden
>    başlatmada `StopApplication` çağırıyor → `CleanupDocker` `external` ağı siliyor → sonraki
>    HER deploy ağ yok diye ölüyor. Zinciri **canlı izledik**, tahmin yürütülmedi.
> 2. **Kök neden: `DB_PASSWORD` döndürülmüş, ama roldeki parola değişmemişti.** `10-roles.sh`'i
>    PostgreSQL YALNIZ boş veri dizininde koşturur; hacim doluydu, betik bir daha hiç koşmadı.
>    Uygulama yeni anahtarla eski kilidi açmaya çalışıyordu.
> 3. **KALICI DÜZELTME KODA GİRDİ (`3ec0384`, `dev`)** — roller artık `db` her açıldığında env
>    parolalarıyla hizalanıyor; eşitleme container'ın İÇİNDEN koşuyor (dışarıdan imkânsız, çünkü
>    owner parolası bayatken kimlik doğrulanamaz). Dört bekçi test + gerçek container ölçümü.
> 4. **Teşhis sırasında iki kez yanıldım ve ikisi de ölçüm hatasıydı** — aşağıda "YANILGILAR"
>    bölümünde yazılı; ikisi de bu projede tekrar edebilecek sınıftan.
> 5. **Kullanıcı her iki Coolify uygulamasını da SİLDİ** (bilerek, veri feda edildi); ardından
>    **`Sipario Dev` sıfırdan kuruldu ve YEŞİL** — düzeltmenin sıfırdan kurulum yolu ilk kez
>    sahada sınandı ve geçti. **Üretim hâlâ kurulmadı.** Eski hacimler öksüz duruyor.
>
> **Ölçüm (vardiya sonu, BİZZAT koşuldu):** API **695/695** (3537 iddia, 1 kasıtlı incomplete) ✅ ·
> `phpstan` **0** ✅ · `pint` temiz ✅ · sıfırdan kurulum ve **parola döndürme** senaryoları
> gerçek container'da koşuldu ✅ · dev CANLIDA ölçüldü (`test.sipario.com.tr` 200, rol eşitleme
> günlüğü, üç rol scram ile, geocoding + sıralama uçtan uca) ✅.
> **Mobil test koşulmadı** (bu vardiya mobil koda dokunmadı) · **APK derlenmedi.**
>
> **Dallar (vardiya sonu):** `dev` itildi · `main` == `827767a` — **`main` `dev`'in gerisinde** ve
> üretim düzeltmelerinin HİÇBİRİ `main`'e gitmedi (13. madde, artık ACİL).

## NE YAPILDI

**① Arıza zinciri kaynağına kadar sökülüp yazıldı.** `queue` günlüğündeki
`FATAL: password authentication failed for user "sipario_app"` tek kanıttı ve ona ulaşmak için
önce `LOG_CHANNEL`'ın `stderr`e çekilmesi gerekti — çünkü geceki çöküşte kanıt yoktu.

**② `LOG_CHANNEL=stderr` düzeltmesi aylardır ÖLÜYDÜ.** Compose'da `${LOG_CHANNEL:-stderr}` yazıyor
ama `:-` **yalnız değişken tanımsızken** devreye girer; Coolify panelinde `LOG_CHANNEL=stack`
tanımlıydı, dolayısıyla varsayılan hiç çalışmadı. Önceki vardiyanın "üretim günlüğü stderr'e
alındı" kaydı ağaçta doğruydu, **yürürlükte değildi.**

**③ Kalıcı düzeltme (`3ec0384`):** `10-roles.sh` artık iki yerden koşar — initdb'de ve **her
container açılışında** (`sipario-entrypoint.sh` → `sipario-rol-esitle.sh`). `ALTER ROLE`'ler
koşulsuz; owner rolü de hizalanır. Parolalar SQL'e gömülmez (psql değişkeni), boş parola sessizce
geçmez. Aynı sırrın ikinci adları (`SIPARIO_*_PASSWORD`, `DB_APP_PASSWORD`) kaldırıldı. Yerel
compose `image:` yerine `build:` kullanır — aksi halde eşitleyici yerelde hiç koşmaz ve yerel
yığın üretimden ayrışarak aynı sınıf arızayı gizlerdi.

**④ `RolParolaEsitlemeTest` (4 test).** Totoloji OLMADIĞI ölçüldü: `Dockerfile`'dan `ENTRYPOINT`
satırı çıkarılıp koşuldu, test kırmızıya döndü.

**⑤ SSH anahtarı döndürüldü.** Benim erişim anahtarım tazelendi (`sipario_v2_ed25519`), yanmış
olan sunucudan silindi ve reddedildiği ÖLÇÜLDÜ.

**⑥ DEPLOY YARIŞI KAPATILDI — migration artık tek atımlık bir ÖNKOŞUL servisi.**
Dev sıfırdan kurulurken ölçüldü: `queue` iki kez çöküp yeniden başladı (`relation "cache" does
not exist`), çünkü yalnız `db healthy` bekliyordu ve tabloları yaratan migration Coolify'ın
**post-deployment** adımında, yani yığın ayağa kalktıktan SONRA koşuyordu. İki yeniden başlatma
zararsız görünür ama Coolify'ın tavanı 10'dur ve bu sayı migration süresine bağlıdır — aşıldığında
ne olduğunu aynı gün yaşadık (①'deki zincirin ilk halkası). Artık compose'da `migrate` servisi var
(`restart: "no"`) ve `app`/`queue`/`scheduler` ona `service_completed_successfully` ile bağlı;
`backup` BİLEREK bağlanmadı (migration düşerse kurtarma aracı yine koşmalı). Yan kazanç: migration
başarısız olursa deploy DÜŞER — eskiden yığın kalkar, migration ayrı adımda düşer ve yarı göçmüş
şemayla trafik alırdı. `DeploySirasiTest` (3 test) bağı denetler; `queue`'nun bağı koparılıp
kırmızıya döndüğü ölçüldü.

## 🔴 BU VARDİYADA YAPTIĞIM İKİ YANILGI (ikisi de ölçüm hatasıydı — desen olarak not edilmeli)

**① `127.0.0.1` üzerinden yapılan parola testi SAHTE "GEÇTİ" verdi.** `pg_hba.conf`'ta
`host all all 127.0.0.1/32 trust` var: o yoldan bağlanan istemciye parola HİÇ sorulmaz. Ben
"parola doğru" diye rapor ettim, oysa uygulama ağ üzerinden (`scram-sha-256`) bağlanıyor ve
reddediliyordu. **Ders: kimlik doğrulama testi, uygulamanın kullandığı YOLDAN yapılmazsa hiçbir
şey kanıtlamaz.** Doğru testte üç rol de başarısızdı.

**② `.env`'deki değişkenleri karşılaştırıp "iki ayrı parola var" dedim — yanlıştı.** Compose
`SIPARIO_APP_PASSWORD: ${DB_PASSWORD}` diye dolaylama yapıyor ve `environment:` bloğu env
dosyasını ezer; container'a giden değer her zaman `DB_PASSWORD`'ünkiydi. `.env`'de duran ayrı
`SIPARIO_APP_PASSWORD` girdisi ölü bir kalıntıydı ve teşhisi saatlerce yanlış yöne çekti.
**Ders: "dosyada ne yazıyor" ile "container'a ne gidiyor" ayrı sorulardır.**

## ⚠️ BU VARDİYADAN KALAN AÇIKLAR

- **`Sipario Dev` SIFIRDAN KURULDU ve YEŞİL** (yeni uuid `l1o1xouuvwwqo394xypycgcy`).
  Ölçüldü: `test.sipario.com.tr` **HTTP 200** · beş container ayakta · `db healthy` ·
  migration 38 tablo · üç rol **ağ üzerinden (scram)** bağlanıyor ·
  günlükte `[SIPARIO-ROL-ESITLEME] roller env parolalariyla hizalandi` —
  **düzeltmenin canlıda koştuğunun kanıtı budur, sıfırdan kurulum yolu ilk kez sınandı.**
  Rota/sıralama zinciri de uçtan uca ölçüldü: `GoogleGeocoder` canlı sorguda gerçek
  koordinat döndürüyor (Muratpaşa 36.88276,30.76948 · Atatürk Cd. 36.97097,30.75089) ve
  `YakinKomsuMotoru` kuzeyden güneye doğru zinciri kuruyor, konumsuz durağı sona atıp
  dış servise göndermiyor. `GOOGLE_ROUTES_KEY` BOŞ — gerçek yol ağı sıralaması kapalı,
  bedava kuş uçuşu motoru çalışıyor (bilinçli, bkz. 19. madde).
- **`Sipario App` (üretim) HÂLÂ KURULMADI.** Kurulmadan önce 13. madde (dev→main merge)
  yapılmalı, yoksa üretim rol eşitleme düzeltmesini taşımaz.
- **[✅ KAPANDI — dev'de ölçüldü]** ⑥'daki `migrate` servisi deploy edildi (dev deploy #162,
  commit `8d30f76`, `finished`) ve açık bıraktığım iki soru da ÖLÇÜLDÜ:
  (a) **yarış kapandı** — `queue` `RestartCount` **0** (aynı ortamda önceki deploy'da 2'ydi),
  altı container'ın hiçbirinde yeniden başlatma yok;
  (b) **panel kirlenmedi** — `Exited (0)` kalan `migrate` container'ına rağmen Coolify'ın
  `status` alanı `running:unknown`, yani değişiklikten önceki hâlin aynısı; korktuğum alarm
  körlüğü DOĞMADI. `migrate` çıktısı `Nothing to migrate.`, site **HTTP 200**.
- **Coolify'da post-deployment command TEMİZLENMELİ** (`php artisan migrate --database=pgsql_owner
  --force`). Migration artık compose'un içinde; panelde kalırsa aynı komut ikinci kez koşar —
  zararsız ama "migration nerede koşuyor?" sorusunun iki cevabı olur ve bu vardiya tam olarak
  bu tür ikiliklerin (iki parola değişkeni, iki log kanalı) bedelini ödedi.
- **Öksüz hacimler sunucuda duruyor:** `h43pc3…_sipario-pgdata-v4` (silinen üretimin verisi:
  1 bayi, 6 kullanıcı, 21 sipariş, 73 çağrı kaydı), `pz3gsgc8…`, ayrıca iki eski kuşaktan
  (`un35zcb…`, `xwdasjxc…`) kalanlar. Veri istenerek feda edildi ama **fiilen silinmedi** —
  ya `docker volume rm` ile temizlenmeli ya da bilinçli olarak bırakıldığı yazılmalı.
- **Düzeltme `main`'e gitmedi.** Üretim sıfırdan kurulurken `main` koşulacaksa, `main` bu
  düzeltmeyi TAŞIMIYOR ve aynı arıza ilk parola döndürmesinde geri gelir.
- **Coolify'ın kendi sunucu anahtarı hâlâ eski** (`authorized_keys`'te `coolify` yorumlu satır) —
  önceki oturumda sohbete yapıştırılmıştı. Panel işi, app silmekten etkilenmedi.
- **Mobil taraf bu vardiyada hiç ölçülmedi.**

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-10 · API sürümü + iki sessiz arıza)

> **DÖRT CÜMLELİK ÖZET:**
> 1. **API sürümü artık her yanıtta.** Önceki listenin 6. maddesi (tek kod borcu) kapandı:
>    `AppendServerMeta` her JSON yanıta `api_version` koyuyor, telefon onu `sync_meta`ya
>    önbellekliyor (şema **v16**), Ayarlar → Hakkında'da ayrı bir "Sunucu" satırı çiziyor.
> 2. **Kimliksiz `GET /api/v1/version`** eklendi — token'ı olmayan taraf (durum çubuğu, dağıtım
>    doğrulaması) da sunucunun hangi sürümü koştuğunu sorabilsin diye.
> 3. **Durum çubuğu yalan söylüyordu: "YAYIN BORCU 384", gerçek 0.** Yerel `main` ref'i aylardır
>    donmuş; ölçüm `origin/main..origin/dev`e alındı.
> 4. **Bir güvenlik testi aylardır kırmızıydı, iki kardeşi yeşil ama vakumdu** (`PaymentSecurityTest`,
>    sebep test içine sabit yazılmış fiyat). Önceki notun "API 685/685 ✅" kaydı bu ağaçta tutmadı.
>
> **Ölçüm (bu vardiyada BİZZAT koşuldu):** mobil **1152/1152** ✅ · API **688/688** (3481, 1 kasıtlı
> incomplete) ✅ · `phpstan` **0** ✅ · `pint` temiz ✅ · `dart analyze` **1 info** (aşağıda, benim
> değişikliğim değil). **APK derlenmedi, cihazda doğrulanmadı.**
>
> **Dallar:** `main` == `dev` == `827767a` (vardiya başında) · saha **0.10.0** · test **0.10.0** ·
> API sürümü **1.0.0 → 1.1.0** (aynı commit'te artırıldı; MINOR = geriye dönük uyumlu yeni alan —
> sürüm çalışan koda aittir, o yüzden artış deploy'a ERTELENMEDİ). ⚠️ **Canlıda `/api/v1/version`
> HENÜZ YOK** — istek 404 döndüğü için canlı sürüm "eski" diye değil, HİÇ okunamıyor; çubuk
> sessizce ağaçtaki değere düşüyor ve tek numara gösteriyor (`API 1.1.0`). Deploy indiğinde canlı
> okuma BAŞLAR; `→` oku ancak bir sonraki sürüm artışından itibaren iş görür.

## NE YAPILDI

**① API — sürüm her yanıtta (`AppendServerTime` → `AppendServerMeta`).**
Alan `server_time` ile AYNI yerden ekleniyor. **Uç nokta uç nokta EKLENMEDİ, bilinçli:** yalnız
`sync/pull`a koymak, yarın eklenecek bir uç noktanın onu taşımamasına yol açardı — `server_time`
tam olarak bu sebeple taşıma katmanında. Middleware ÜZERİNE YAZMAZ: gövdeyi kendi kuran uç
noktanın değeri kalır, middleware yalnız eksiği tamamlar.

**② Kimliksiz `GET /api/v1/version`.** Gerekçe controller'da yazılı: sürümü soran taraf çoğu zaman
token'ı olmayan taraftır ve girişe garip veri POST'layıp 401 gövdesinden sürüm okumak hız sınırını
yakar. Dönen tek şey kendi sözleşme numaramız — PHP/Laravel sürümü, ortam, yapılandırma sızmaz;
DB'ye gitmez, kiracı verisine dokunmaz. `throttle:api` (IP başına 60/dk) DoS payını sınırlar.
`tenant` middleware'i taşımadığı için `RouteCoverageGuardTest`in izolasyon matrisine girmez — doğru.

**③ Telefon sürümü ÖNBELLEKLİYOR (`sync_meta.api_version`, şema v16).**
Push VE pull'dan yazılır (telefon çoğu turda yalnız pull yapar; tek yöne bağlamak sürümü "yalnız
yazan cihazlar görür" hâline getirirdi). **Saklanıyor çünkü uygulama offline-first:** bayi Ayarlar'ı
çoğu zaman ağ yokken açar ve saklamayan bir gösterim, tam da sürümün en çok merak edildiği anda
boş kalırdı. **YOKLUK EZMEZ** (eski sunucu sürüm bildirmezse bilinen son değer durur).
**Tip kontrolü zorunlu** — `as String` yazmak, sunucunun bir gün sayı göndermesi hâlinde TÜM turu
TypeError ile düşürürdü; bir gösterim alanının senkronu durdurmaya yetkisi yoktur.
**Karşılaştırma/uyarı BİLİNÇLİ OLARAK YOK:** "sunucu benden yeni, kilitleneyim" demek için önce
hangi sürüm çiftinin uyumsuz olduğunu söyleyen YAZILI bir karar gerekir (CLAUDE.md → Sürümleme).

**④ Ayarlar → Hakkında'ya "Sunucu" satırı.** Uygulama sürümüyle BİRLEŞTİRİLMEDİ: iki ayrı hattır ve
"Sipario 0.10.0 / 1.0.0" gibi tek satır, okuyanı bir numaranın diğerini takip ettiğine inandırırdı.
Metin İDDİA ETMEZ — "güncel/uyumlu" demez, yalnız en son GÖRÜLEN numarayı yazar.

**⑤ Bağ makineyle zorlandı.** `SurumCarpikligiTest::mobil_istemci_api_surumunu_okuyor` mobil
ayrıştırıcının `api_version` okuduğunu KAYNAKTAN denetler (`batchSize` bekçisiyle aynı desen) —
"tanımlı ama bağlı değil" deseninin beşinci kez doğmaması için.

**⑥ Yükseltme yolu testi (`migration_v16_test.dart`).** Listenin 9. maddesinin ilk taksiti.
Totoloji OLMADIĞI ÖLÇÜLDÜ: `ALTER TABLE` geçici olarak çıkarılıp koşuldu, test kırmızıya döndü.

## 🔴 BU VARDİYADA BULUNAN İKİ SESSİZ ARIZA (ikisi de bu turun işi değildi)

**① DURUM ÇUBUĞU YALAN SÖYLÜYORDU: "YAYIN BORCU 384", gerçek borç 0.**
`ci-durum-yenile.cjs` düz `main..dev` ölçüyordu. Bu depoda kimse yerelde `main`e checkout etmiyor
ve oturum başındaki fast-forward yalnız çalışılan dalı ilerletiyor → yerel `main` `16833e7`te
donmuş, uzak `827767a`. Ölçüm `origin/main..origin/dev`e alındı (uzak ref yoksa yerele düşer).
**Kusur göstergenin var oluş sebebine düşüyordu:** borç 41'e çıktığında alarm versin diye konmuş
kırmızı bir sayı, 0 iken 384 diyorsa artık okunmaz ve gerçek borç büyüdüğünde kimse fark etmez.

**② BİR GÜVENLİK TESTİ AYLARDIR KIRMIZIYDI, İKİ KARDEŞİ YEŞİL AMA VAKUMDU.**
`PaymentSecurityTest` iyzico retrieve cevabını `paidPrice: '1200.00'` diye SABİT taklit ediyordu.
Yıllık fiyat 2026-08-04'te 5.988 ₺'ye çıkınca `verify()`in tutar denetimi haklı olarak reddetti ve
"gövdeye güvenilmez, retrieve esastır" testi kırmızıya döndü — **koruduğu davranış hâlâ doğruyken.**
Daha sinsisi kardeşlerindeydi: "gövdedeki SUCCESS iyzico'nun FAILURE'ını ezemez" iddiası
`assertFalse` beklediği için YEŞİL kalmaya devam etti ama artık iddiasını KANITLAMIYORDU — sonuç
zaten TUTAR yüzünden `false`tu. Tutar artık `config('subscription.price_kurus')`ten türetiliyor.
⚠️ **Bu, önceki notun ölçüm kaydını da düzeltir:** orada "API **685/685** ✅" yazıyor; aynı ağaçta
yeniden koşulduğunda 684 yeşil + 1 kırmızı çıktı.

## ⚠️ BU VARDİYADAN KALAN AÇIKLAR

- **Canlıya deploy EDİLMEDİ.** `/api/v1/version` yalnız bu ağaçta var; durum çubuğunun `apiCanli`
  ölçümü deploy'a kadar sessizce boş kalır (tasarlanan davranış, hata basmaz).
- **Cihazda doğrulanmadı.** Şema v16 yükseltmesi gerçek telefonda koşmadı; test dosyası o yolu
  birebir taklit ediyor ama gerçek cihaz ayrı bir kanıttır.
- **`dart analyze` artık 1 info veriyor** — `order_list_parts.dart:161` `onReorder` deprecated.
  Benim değişikliğim DEĞİL: bu makinedeki Flutter SDK `pubspec.lock`tan yeni. Aynı sebeple
  `flutter test` lock'ta dört geçişli paketi bump ediyor (geri alındı — SDK yükseltmesi ayrı bir
  karardır ve `onReorder` → `onReorderItem` göçü indeks kaydırma semantiği taşır, yani siparişlerin
  sürükle-sırala davranışını sessizce bozabilir; kör yapılmaz).

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-09/2-3-4 · TEK UZUN VARDİYA)

> **Bu vardiya bir saha arızasıyla başladı, bir dağıtım mimarisiyle bitti.** Sırayla oku;
> bölümler kronolojik ve her biri bir öncekinin açtığı kapıdan girdi.
>
> **BEŞ CÜMLELİK ÖZET:**
> 1. **"Patron kuryeye atıyor, kurye göremiyor" arızası KAPANDI** — kök neden: yerel yazım
>    senkron turunu tetiklemiyordu. Kullanıcı gerçek cihazlarda doğruladı (15–20 sn).
> 2. Aynı bölgede **dört ekran titremesi + kurye sayacı** kusuru daha bulundu ve kapatıldı.
> 3. **Üretim iki kez çöktü** (17:01 ve 20:10); sebebi ARANAMADI çünkü günlükler container'la
>    birlikte siliniyordu → `LOG_CHANNEL=stderr` + döndürme geldi.
> 4. **`running:unhealthy` gizemi çözüldü:** suçlu `queue`/`scheduler`'ın temel imajdan miras
>    aldığı HTTP healthcheck'iydi; panel aylardır kırmızıydı ve GERÇEK çöküşü görünmez kılıyordu.
> 5. **Dağıtım ikiye ayrıldı:** `main`→saha (bayiler) · `dev`→test (ekip) + `test.sipario.com.tr`
>    ortamı + SemVer kuralı. Öncesinde **`dev`'e atılan her commit bayilerin telefonuna iniyordu.**

**Ölçüm (bu vardiyada BİZZAT koşuldu, kopyalanmadı — en son değerler):**
mobil **1143/1143** ✅ (taban 1108 → +35) · API **685/685** (3472 iddia, 1 incomplete KASITLI) ✅ ·
`flutter analyze` **0** ✅ · `phpstan` **0** ✅ · `pint` temiz ✅ ·
`saha` + `deneme` APK'ları derlendi ve **kendi çıktılarından** doğrulandı.

**Dallar ve kanallar (vardiya sonu):** `main` == `dev` == `ca7dde7` · saha **0.10.0** ·
test **0.10.0** · API sürümü **1.0.0** · canlı/`api.`/test uçları **200**.

## ARIZA VE KÖK NEDEN

Saha raporu: *"Patron hesabından bir kuryeye atama yaptığımda, kurye hesabında yenileme yapmama
rağmen güncelleme gelmiyor. Fakat patron hesabında uygulamayı alta alıp tekrar açtığımda, kurye
yenilediğinde geliyor."*

**Kök neden: yerel yazım senkron turunu TETİKLEMİYORDU.** Atama outbox'a kusursuz düşüyordu
(`order_repository.dart:294`, tek transaction) ama `enqueueOutbox` yalnız INSERT ediyor, kimseye
haber vermiyordu. Tur yalnız dört yoldan açılıyordu: 2 dk zamanlayıcı · connectivity değişimi ·
`home_shell.dart:283` `resumed` · aşağı çekerek yenile. Kullanıcının "alta alıp açınca gidiyor"
gözlemi tam olarak üçüncü maddedir. Kurye ne kadar yenilerse yenilesin, **sunucuda henüz olmayan
bir şeyi çekemez.**

Bu bir **tutarlılık** değil **GECİKME** arızasıydı — ve önceki vardiyanın teşhisinin
(*"sistemde kusur yok, eski cihazda bayat veri"*, DECISIONS 2026-08-09) neden yanlış hüküm
verdiğini de bu açıklıyor: o ölçüm temiz cihazda **durağan durumu** karşılaştırıyordu
(`last_pulled_seq` sunucuyla birebir, 21 sipariş eşleşiyor) ve o yöntem gecikmeyi göremezdi.
Ölçüm yanlış değildi, **soruya cevap vermiyordu.**

## SUNUCU TEMİZ ÇIKTI — KOŞUMLA

Kuryenin KENDİ tokenıyla üç senaryo yazılıp koşuldu; hepsi yeşil ve artık depoda kalıcı
(`apps/api/tests/Feature/Api/CourierSyncTest.php`, `--filter=CourierSyncTest` → 10/10):
kuryenin hiç görmediği sipariş atanınca delta'da iniyor · yeniden atama iniyor · snapshot
süzülmüyor. Sebebi kodda da açık: delta sorgusunda kullanıcı/rol yüklemi YOK, RLS yalnız kiracı
bazlı — **kapsam süzgeci tamamen mobilde.** Atama LWW'den geçmiyor (olay-kaynaklı append), yani
'stale' diye sessizce düşmesi imkânsız.
⚠️ Test kurgusunda tuzak var, yorumda yazılı: **boş bayide imleç 0 döner ve `since=0` tanım gereği
SNAPSHOT demektir** — imleç gerçek cihazdaki gibi >0 yapılmalı, yoksa test kendi kurgusundan kırmızı verir.

## YAPILAN DÜZELTMELER

1. **Yazım tetiği** (`sync_service.dart::yazimTetigiBagla`, `app_database.dart::watchBekleyenSayisi`).
   Bekleyen outbox sayacı akışına abone olunur; **YALNIZ ARTIŞTA** tur açılır. Tetik
   `enqueueOutbox`ten çağrılmaz — her yazım bir transaction içindedir, commit'ten önce açılan tur
   ya kaydı göremez ya yazma kilidine girer; Drift bildirimi commit SONRASI düşer. Böylece outbox'a
   yazan 25 çağrı yerinin (11 dosya) hepsi tek tetiği paylaşır, yarın eklenecek yazım unutulmaz.
   ⚠️ Düşüşte tetiklemek sonsuz tur döngüsü kurardı (push ack'leyince sayı düşer) — testle kilitli.
   Pencere klasik debounce DEĞİL: ilk artış pencereyi açar, pencereye düşenler aynı tura biner
   (klasik debounce toplu yazımda turu sürekli ertelerdi).
2. **Ön plan aralığı 2 dk → 30 sn** (`onPlanAralik`/`arkaPlanAralik`, kabuk yaşam döngüsüne bağlı).
   Patronun yazımı anında gitse bile kurye onu ancak kendi pull'unda görür; çözümü "yenilemeye bas"
   olamaz. Arka planda 2 dk'ya döner (pil). `inactive` bilinçli olarak arka plan SAYILMAZ.
3. **Tur düzeyinde 90 sn üst sınır.** Zaman aşımı istek başınaydı (25 sn), tur başına yoktu; uzun
   bir tur boyunca zamanlayıcı, öne gelme VE yeni yazım tetiği tur süresi kadar gecikiyordu.
   Güvenli olduğu ÖLÇÜLDÜ: `_applyDelta` imleci sayfa başına kalıcı yazıyor
   (`sync_engine.dart:383-384`), snapshot hiç sayfalanmıyor (`SyncService.php:318` `has_more=false`)
   → sınır geri sarma değil, en fazla tekrar üretir. Cins **`sunucu`** seçildi: `ag` demek yalan
   olurdu (ağ ölü olsa tur 90 sn'ye varmadan `ag` ile düşer), `veri` de yalan olurdu (ortada bozuk
   kayıt yok). `.timeout` bilinçli olarak FIRLATMIYOR — fırlatsaydı taşımanın kendi 25 sn'lik
   `TimeoutException`ı da aynı kefeye düşer ve `sync_zaman_asimi_test`in kilitlediği sözleşme
   sessizce bozulurdu.
4. **"Akış build içinde kuruluyor" kusuru — DÖRT nüsha kapatıldı.** `watch*` her çağrıda YENİ
   Stream nesnesi döndürür; build'de çağrılırsa StreamBuilder aboneliği koparır ve o kare
   `snap.data` null olur. Kabuk senkron/kontör/meta tiklerinde setState ettiği için titreme SIK.
   Kapatılanlar: `ana_ekran.dart` "Açık Sipariş" kutusu (0'a düşüyordu) · `ana_ekran.dart`
   "Son aktivite" ("henüz hareket yok" parlıyordu) · `ana_bento.dart` "Son Arama".
   Desenin tanımı `order_list_screen.dart:119-123`te YAZILI ve orada düzeltilmişti — **yazılı ders
   üç ayrı yere uygulanmamıştı.** Bedeli artık dört kez ödendi, beşincisi yazılmasın.
5. **Kurye başlık sayacı kapsam değişimini kaçırıyordu** (`order_list_screen.dart`): `late final`
   bir kez değerleniyordu, liste akışı kapsam değişince yeniden kuruluyor ama sayaç kurmuyordu →
   başlıkta 12, listede 2. Kapsamı belirleyen iki girdi de asenkron iniyor (`_kuryeIzin`, `_userId`);
   `ef545ec`in hizalaması yalnız ilk kare için geçerliydi.
   **GÖRÜNÜR DAVRANIŞ DEĞİŞİKLİĞİ (kullanıcı kararı):** sayaç artık etkin kurye süzgecini sayar —
   patron bir kurye seçtiğinde rakam da o kuryeye düşer.

## ✅ BORÇ AYNI VARDİYADA KAPATILDI — bekleyen kayıt bandı

Aşağıdaki borç önce kapsam dışı bırakıldı, sonra kullanıcı isteğiyle KAPATILDI. `PushOzeti.beklemede`
artık `SyncOutcome.beklemede` olarak taşınıyor ve kabukta yeni bir bant çiziyor:
*"Bazı kayıtlar sırada bekliyor · cihazda güvende, abonelik ya da uygulama güncellenince
gönderilecek"*. Turun CİNSİ bilerek bozulmadı (`ok` hâlâ `true`) — erteleme bir başarısızlık
değildir; turu kırmızıya boyamak "sunucu kayıtları kabul etmiyor" derdi ve yalan olurdu.
Öncelik: canlı tur hatası > karantina > bekleyen. Metin bilerek "bağlanınca gönderilecek"
DEMİYOR (ağ zaten var) ve "destekle görüşün" DEMİYOR (çare abonelik/güncelleme).
**Asıl korunan senaryo abonelik değil SÜRÜM ÇARPIKLIĞIDIR:** kilitli bayide zaten kilit ekranı
var, ama sunucu tanınmayan bir durum döndürdüğünde (beyaz liste onu `beklet`e düşürür) başka
hiçbir sinyal yoktur. Beş test eklendi; düzeltme geri alınıp koşularak testin totoloji olmadığı
KANITLANDI (kırmızıya döndü).
⚠️ Test yazarken ölçülen tuzak: sahte durum akışına `add` + tek `pump()` YETMEZ — broadcast
akışının olayı dinleyiciye ulaştırması `runAsync` ile GERÇEK bir olay döngüsü turu ister
(ölçüm: bant 0 → bir tur sonra 1). `ekranaKoy`un `runAsync` kullanmasının sebebi de budur.

## ⚠️ (TARİHSEL — YUKARIDA KAPATILDI) Borcun özgün tanımı

**`PushOzeti.beklemede` hiç tüketilmiyor.** `sync_engine.dart:34`te tanımlı, `:126`da doldurulmuş,
`lib/` içinde TEK okuyucusu yok. Sonuç: abonelik kilidi (`locked`) yüzünden gönderilemeyen kayıtlar
varken bant "senkron başarılı" diyor. Veri kaybı YOK (kayıt `pending` kalır, `attempts` artmaz,
`locked`/`duplicate` doğru okunuyor — `sync_engine.dart:174-193` beyaz listesi denetlendi) ve
kilitliyken kullanıcı zaten `SubscriptionLockedScreen` görüyor. Alanın var oluş sebebi
GÖRÜNÜRLÜKTÜ ve o yüzey hiç bağlanmadı — "sessiz arıza" sınıfının küçük bir örneği.

## ✅ BU VARDİYADA KAPANANLAR (sıradaki işler için AŞAĞIDAKİ tek listeye bak)

1. **[✅ KAPANDI — KULLANICI GERÇEK CİHAZDA DOĞRULADI]** İki gerçek telefonla ölçüldü: patron
   atama yapıyor → kurye yenilediğinde **anında** düşüyor; **hiç dokunmadan beklendiğinde ortalama
   15–20 sn** içinde ekrana düşüyor. Bu rakam teoriyi de doğruluyor: ön plan aralığı 30 sn ve
   atama anı tur döngüsüne rastgele düştüğü için beklenen ortalama bekleme ~15 sn'dir — yani
   **ölçülen davranış tasarlanan davranışın ta kendisi**, tesadüfi bir düzelme değil. Düzeltmenin
   iki yarısı da sahada çalışıyor: yazım tetiği (patron tarafı anında push) + 30 sn ön plan
   aralığı (kurye tarafı dokunmadan görüyor).
2. **[✅ KAPANDI]** ~~`PushOzeti.beklemede` borcu~~ — aynı vardiyada kapatıldı (bekleyen kayıt bandı, 5 test).
3. **[✅ KAPANDI]** ~~`main` dalı `dev`'in gerisinde~~ — 41 commit birleştirildi ve **canlıya alındı** (`817047f`, deploy `finished`). Bu artık her vardiya sonunda rutin adım.

## 🔧 ALTYAPI — AYNI VARDİYADA ÜÇ İŞ (2026-08-09/3, hepsi CANLIDA ÖLÇÜLDÜ)

**① `running:unhealthy` gizemi çözüldü — suçlu `queue` + `scheduler`.**
Panel aylardır kırmızıydı ve "sinyal bozuk, site çalışıyor" diye normalleştirilmişti. Sunucuya SSH
ile bağlanıp `docker inspect` ile OKUNDU (dışarıdan üç tur tahmin yürütüldü, ÜÇÜ DE YANLIŞTI —
sırasıyla "db bozuk", "app healthcheck'i bozuk", "`ports_exposes: 3000` yanlış porta vuruyor").
Gerçek: temel imaj `serversideup/php` KENDİ healthcheck'ini taşıyor
(`curl --fail http://localhost:$NGINX_HTTP_PORT$HEALTHCHECK_PATH`) ve compose'da healthcheck
tanımlamadığımız her serviste o miras kalıyor. `queue`/`scheduler` entrypoint'i ezip CLI süreci
koşuyor — içlerinde nginx yok — kontrol her 10 sn `curl: (7) Failed to connect to localhost port
8080` ile düşüyordu. `app` ve `db` ölçüldü: İKİSİ DE HEALTHY. Coolify durumu toplulaştırdığı için
iki CLI container'ı bütün kaynağı kırmızıya boyuyordu.
**Çözüm:** `healthcheck: disable: true` (queue + scheduler). Sahte `pgrep`/`ps` kontrolü YAZILMADI:
ön planda koşan CLI sürecinde SÜREÇ = CONTAINER, ölürse `restart: unless-stopped` geri getirir.
**Deploy sonrası ölçüm:** `app healthy` · `db healthy` · queue/scheduler/backup sağlık durumu YOK
(tasarım) · **hiçbir yerde `unhealthy` kalmadı** · Coolify `running:unhealthy` → `running:unknown`.
**Yan bulgu: imajda `curl` VAR** — healthcheck'i curl'den PHP'ye çevirmenin gerekçesi yanlış öncüle
dayanıyormuş (PHP kontrolü çalıştığı için değiştirilmedi).

**② Üretim günlüğü `stderr`e alındı + döndürme eklendi.**
17:01'de uygulama çöktü, 16 kez yeniden başladı, `max_restart_count: 10` aşılınca Coolify pes etti,
site elle redeploy edilene kadar 503 kaldı — **ve sebep aranamadı çünkü kanıt yoktu**:
`LOG_CHANNEL=stack/single` container İÇİNE yazıyordu, `storage/logs` için volume yok, container her
yeniden yaratılışında günlükler siliniyordu. Artık `stderr` → Docker → Coolify log ekranı.
Zorunlu eşlikçi: `json-file` döndürmesi 10 MB × 3 (app/queue/scheduler) — yoksa sınırsız büyüyen
günlük diski doldurup YENİ bir kesinti üretirdi. `storage/logs` volume'ü BİLİNÇLİ eklenmedi
(root sahipli volume + `www-data` süreç = yazamayan log dizini).

**③ Dekoratif `deploy:` bloğu compose'dan kaldırıldı** — Swarm dışında yok sayılıyordu, "rollback
beni korur" sanısı veriyordu. Gerçek geri dönüş ELLEDİR (Coolify → önceki deployment → Redeploy).

## 🚀 DAĞITIM DÜZENİ YENİDEN KURULDU (2026-08-09/4)

**① İKİ ORTAM.** Coolify'da ikinci uygulama: **`Sipario Dev`** (`pz3gsgc8aawn0lp85uwz2pfe`), dal
`dev`, domain **`test.sipario.com.tr`**, KENDİ veritabanı. Canlıdan farkları API ile düzeltildi
ve geri okunarak doğrulandı: `CORS` test domaini · `GEOCODING_DRIVER=null` · `ROTA_SURUCU=yakin-komsu`
· Google anahtarları BOŞ (test gerçek kotayı/parayı yakmasın) · `MAIL_MAILER=log`. Coolify her
değişkenin bir de **önizleme kopyasını** tutuyor; ikisi birden hizalandı, yoksa önizleme
dağıtımı açıldığı gün Google kotası yine yanardı. Ölçüm: test `/up` 200, giriş 401 (şema kurulu).

**② İKİ MOBİL KANAL — `dev`'e her push SAHAYA İNİYORDU, kapatıldı.**
`main` → `saha` kanalı (bayiler, `com.sipario.app`) · `dev` → `test` kanalı (ekip,
`com.sipario.app.test`, "Sipario Deneme"). Tek iş akışı `mobil-apk.yml` dala göre kanal seçer;
`main` dışındaki her şey deneme sayılır (kazayla saha ezilmesin). Flavor adı `test` OLAMAZ
(Android o adı kaynak kümesi için ayırır) → flavor `deneme`, etiket `test`. Sunucu adresi artık
derleme sabiti (`--dart-define=SIPARIO_API`), kullanıcıya sorulmaz.
**Yan bulgu:** `check_permissions.sh` harf duyarlılığı yüzünden flavor'lu manifestlere HİÇ
bakmıyordu (kırmızı çizgi #6'nın denetimi delikti) — düzeltildi, üç kanal da denetleniyor,
dişli olduğu kanıtlandı (saha 2 · deneme 2 · magaza 0 beyan).

**③ SÜRÜMLEME KURALI — SemVer, iki ayrı hat.** Kural `CLAUDE.md` → "Sürümleme"de.
Uygulama `apps/mobile/pubspec.yaml` (**0.10.0**), API `apps/api/config/app.php` (**1.0.0**);
birbirine EŞİTLENMEZ. Derleme numarası sürüm değildir, makinenin karşılaştırma anahtarıdır.
⚠️ **API sürümü hiçbir yanıtta okunmuyor** — "tanımlı ama bağlı değil" deseninin dördüncüsü
olmasın diye borç olarak yazıldı; doğru devamı senkron yanıtına koyup sürüm çarpıklığını
görünür kılmak.

**④ DURUM ÇUBUĞU.** İki satır: üstte durum, altta `SAHA … │ TEST … │ API … │ YAYIN BORCU …`.
Etiket gri + değer parlak, bütün etiketler BÜYÜK HARF, emoji yerine renkli metin (emoji
hizalamayı bozuyor, 🟢/🔴 renk körlüğünde ayırt edilemiyor). `+N` = o kanaldan kaç commit
ileride. `YAYIN BORCU` = `main..dev`; 20'yi geçince kırmızı — 41'e çıktığında sunucu ile
telefonlar farklı kod çalıştırıyordu. `NO_COLOR` destekli, dört bozulma senaryosu sınandı.
⚠️ Çubuk 60 sn'lik ÖNBELLEKTEN okur (ağa çıkmaz); CI beklerken "güncellenmedi" hissi verebilir.

**⑤ Deploy kesintisi ÖLÇÜLDÜ: 52,3 sn** (218 örnek, 0,4 sn aralık). Kesinti deploy'un SONUNDA,
container değişiminde; ilk ~86 sn build ve site normal. Sıfırlamak Swarm/iki replika ister ve
ÖN KOŞULU expand/contract migration disiplinidir — o olmadan 52 sn'lik dürüst kesinti, geçiş
anındaki 500'lerle takas edilir. Mobil offline-first olduğu için bu kesintiden ETKİLENMEZ.

## 🔴 SIRADAKİ İŞLER — TEK LİSTE (vardiyaya başlayan BURADAN devam eder)

> 🔴 **2026-08-17/2 GÜNCELLEMESİ — KOD BORÇLARI KAPANDI.** 7 · 8 · 9 · 14 · 15 kapandı (ayrıntı
> 2026-08-17/2 devir notunda). **Bu bölümden geriye yalnız ORTAM/İŞLETME maddeleri (10 · 11 · 16 ·
> 17) ve iki AÇIK KUYRUK kaldı:** LWW saniye-altı `incomplete`i ve 500 satır kuralının TEST tarafı
> (14 dosya). Ayrıca kayda geçen bir bulgu var, kararı kullanıcıda: `YoneticiKapisi` rol `null`
> iken açılıyor, `yetkiler(rol: null)` ise en dar kümeyi veriyor.
>
> 🔴 **2026-08-17 GÜNCELLEMESİ — LİSTE KISALDI.** Kapananlar: **2** (Telegram bildirimi) ·
> **3** (Google anahtarı IP kısıtlaması) · **4** (SMTP/e-posta gerçekten gidiyor) ·
> **12** (deneme APK'sı kuruldu) · **18** (Coolify deploy kilidi) · **19** (gerçek yol ağı açık).
> Ayrıca **arayan tanıma 20/20 ölçümü yapıldı → Faz 0'ın şartı düştü, GO kesin.**
> Kullanıcı kararıyla **ASKIYA ALINANLAR — bu listeye bir daha girmezler:** iyzico · Apple/D-U-N-S ·
> iOS · e-arşiv fatura. **Açık ama acelesi yok:** Android release keystore.
> **Kullanıcıda kalan tek küçük iş:** Coolify'da `YEDEK_EPOSTA` tanımı.
>
> **2026-08-10 GÜNCELLEMESİ:** 6. madde (API sürümü okunmuyor) **KAPANDI**. 9. madde (yükseltme
> yolu testi) ilk taksitini aldı (`migration_v16_test.dart`) ama KURAL olarak duruyor: şema
> değiştiren her vardiya kendi testini yazmalı. Listeye üç yeni madde eklendi (13-15).

**İNSAN/GÜVENLİK — önce bunlar:**

0. **⏸️ ÜRETİM BEKLEMEDE — KULLANICI KARARI, ACELE EDİLMEZ (2026-08-15'te teyit edildi).**
   *"Sunucu tarafında sadece test ile devam ediyorum, her şey oturduğunda canlıya geçeceğim;
   geçileceği zaman haber ederim."* Yani aşağıdaki kurulum tarifi **hazır beklesin, kendi
   başına uygulanmasın** — geçiş komutunu kullanıcı verir. Tarif olduğu gibi geçerlidir:
   (dev ✅ kuruldu ve yeşil). Kullanıcı 2026-08-10/2 vardiyasında
   `Sipario App` ve `Sipario Dev`'i Coolify'dan sildi (bilerek); dev sıfırdan kuruldu, üretim
   bekliyor. Kurarken **iki tuzak** (dev'de ikisi de doğru yapıldı, üretimde tekrarlanmalı):
   (a) `SIPARIO_APP_PASSWORD` / `SIPARIO_PANEL_PASSWORD` değişkenlerini panele **ekleme** —
   compose artık kullanmıyor, durmaları yalnız bir sonraki teşhisi yanıltır (bu vardiyada
   saatlerce yanılttı). (b) `LOG_CHANNEL`'ı panelde **tanımlama** — compose'daki
   `${LOG_CHANNEL:-stderr}` varsayılanı, panelde `stack` tanımlı olduğu için aylardır ölüydü ve
   geceki çöküşün kanıtını yok eden şey buydu. Tanımlamazsan varsayılan ilk kez gerçekten işler.
   ⚠️ Üretim `main`'den deploy edilir; **önce 13. madde (merge) yapılmalı**, yoksa üretim
   düzeltmeyi taşımaz.
1. **[✅ KAPANDI — 2026-08-15, KULLANICI ONAYIYLA ES GEÇİLDİ]** ~~SSH anahtarını döndür.~~
   Claude'un erişim anahtarı tazelendi (`sipario_v2_ed25519`), yanmış olan sunucudan silindi ve
   reddedildiği ölçüldü. Coolify'ın KENDİ sunucu anahtarı eski kalıyor: **Coolify kullanımdaki
   anahtarı silmeye izin vermiyor**, döndürme teknik olarak engellendi ve kullanıcı riski
   bilerek kabul etti. **Bu madde bir daha SIRADAKİ İŞLER'e alınmaz** — yeniden açılması ancak
   yeni bir kullanıcı kararıyla olur.
1b. ~~**SSH ANAHTARINI DÖNDÜR.**~~ (özgün metin) Teşhis sırasında Coolify'ın sunucu SSH ÖZEL ANAHTARI sohbete düz
   metin yapıştırıldı (kullanıcı verdi, kullanıldı, geçici kopya silindi) — ama oturum dökümünde
   ve kabuk geçmişinde duruyor. Coolify → Keys & Tokens → yeni anahtar; sunucuda
   `authorized_keys`ten eskisini çıkar. **Bu listenin en acil maddesi.**
2. **[✅ KAPANDI — 2026-08-17, kullanıcı doğruladı]** ~~Bildirim kanalı kur~~ — Coolify →
   Notifications → **Telegram** kuruldu ve bildirimler kullanıcının telefonuna DÜŞÜYOR
   (kullanıcının kendi cümlesi). Artık bir çöküşü fark etmek ölçüme değil kanala bağlı.
   **Bu madde bir daha SIRADAKİ İŞLER'e alınmaz.**
3. **[✅ KAPANDI — 2026-08-17, kullanıcı doğruladı]** ~~Google anahtarını kısıtla~~ — anahtarlar
   **IP ile kısıtlandı**. Sohbete sızan anahtarın serbest kullanımı böylece kapandı.
   **Bu madde bir daha SIRADAKİ İŞLER'e alınmaz.**
4. **[✅ KAPANDI — 2026-08-17, kullanıcı doğruladı]** ~~SMTP bağla / bir postanın gittiğini gör~~ —
   **test sunucusunda e-postalar GİDİYOR.** Yani `MAIL_MAILER` gerçekten `smtp`, `log` değil; parola
   sıfırlama ve yedek postası da aynı yoldan çıkıyor. (Coolify değişkenleri 2026-08-15'te zaten
   tanımlıydı: `titan.hayalhost.com:465`.) **Bu madde bir daha SIRADAKİ İŞLER'e alınmaz.**
5. **[✅ KAPANDI — 2026-08-15, kullanıcı kararı]** ~~Makine dışı yedek kararı~~ — S3 ertelendi;
   yerine her sabah 08:00'de indirme bağlantısı `YEDEK_EPOSTA` adresine postalanıyor
   (`yedek:baglanti-gonder`). ⚠️ Sınırı yazılı: yedeğin makine dışına çıkması **insanın postayı
   açıp indirmesine** bağlıdır, otomatik uzak kopyanın yerini tutmaz. **Coolify'da `YEDEK_EPOSTA`
   tanımlanmadan bu görev her sabah HATA ile çıkar** (bilerek: sessizce başarılı dönmez).

**KOD BORÇLARI:**

6. **[✅ KAPANDI — 2026-08-10]** ~~API sürümü hiçbir yanıtta okunmuyor~~ — `AppendServerMeta` her
   JSON yanıta `api_version` koyuyor · kimliksiz `GET /api/v1/version` · telefon `sync_meta`ya
   önbellekliyor (şema v16) · Ayarlar → Hakkında'da "Sunucu" satırı · durum çubuğu canlı/ağaç
   farkını `API 1.0.0→1.0.1` biçiminde gösteriyor. **Kalan tek adım: canlıya deploy** (13. madde).
7. **[✅ KAPANDI — 2026-08-17]** ~~Yetki Matrisi'nin testi yok~~ — 26 satır × 5 senaryoluk veri
   tablosu (`test/support/yetki_matrisi_tablosu.dart`) + **32 test**. ⚠️ **LWW saniye-altı ayrımı
   AÇIK KALDI** (`SyncZamanNormalizasyonuTest.php:208`, kasıtlı `incomplete` — canlı sinyal olarak
   duruyor; kapatmak damga çözünürlüğü değişikliği ister).
8. **[✅ KAPANDI — 2026-08-17]** ~~500 satır kuralını 13 dosya çiğniyor~~ — **`apps/mobile/lib`
   altında 500'ü aşan dosya KALMADI** (önce/sonra tablosu 2026-08-17/2 devir notunda).
   ⚠️ **TEST TARAFI AÇIK: 14 test dosyası 500'ü aşıyor** (toplam 9.214 satır; `ara_tahsilat_test`
   1126 · `ui_siparis_harita_test` 925 · `ui_siparis_test` 862 …). Kural testlere de uygulanır.
9. **[✅ KAPANDI — 2026-08-17]** ~~Yükseltme yolu testi~~ — v1/v7/v8 **zincir** testleri +
   v19/v20/v21 + ortak iskele (`test/support/migration_yardimcilari.dart`). En değerli parça
   `semaTamOlmali`: yükseltilmiş şemayı taze şemayla karşılaştırır ve "ALTER yazmayı unutulmuş
   kolon" sınıfını tek başına yakalar. **Bu testler yazılır yazılmaz iki gerçek arıza buldu**
   (bkz. 2026-08-17/2 devir notu). Kural olarak duruyor: şema değiştiren her vardiya kendi
   testini yazar.

**ORTAM/İŞLETME:**

10. **Deploy kesintisi 52,3 sn** (ölçüldü). Sıfırlamak Swarm/iki replika ister ve ÖN KOŞULU
    expand/contract migration disiplinidir. Şimdilik kararı: **staging'e yaslan, canlıya seyrek çık.**
11. **Test ortamı boş** — `test.sipario.com.tr` çalışıyor ama içinde bayi yok. Demo verisi yüklemek
    ayrı bir adım (canlıya bulaşmayacak şekilde).
12. **[✅ KAPANDI — 2026-08-17, kullanıcı doğruladı]** ~~Deneme APK'sı bir kez ELLE kurulmalı~~ —
    **kuruldu ve testleri yapıldı.** Yeni paket kimliği (`com.sipario.app.test`) cihazda; bundan
    sonrası kendi kendini günceller. **Bu madde bir daha SIRADAKİ İŞLER'e alınmaz.**

**YENİ (2026-08-10):**

13. **`dev` → `main` birleştir + canlıya deploy.** ⏸️ **KULLANICI KARARIYLA BEKLEMEDE
    (2026-08-15) — "acil" ibaresi ARTIK GEÇERSİZ, kendi başına merge etme.** Aşağıdaki gerekçe
    teknik olarak hâlâ doğrudur ve geçiş günü okunacaktır; ama geçişin ZAMANINI kullanıcı
    söyler. Fark bu vardiyada ölçüldü: `main` 2026-08-10'da donmuş, `dev` **78 commit** önde.
    ⚠️ (Aşağıdaki "ACİL" değerlendirmesi 2026-08-10 tarihlidir, tarihsel olarak korunuyor:) `main` (`827767a`) rol parolası eşitleme düzeltmesini (`3ec0384`) TAŞIMIYOR. Üretim
    `main`'den deploy edildiği için, `main` merge edilmeden kurulan bir üretim ilk parola
    döndürmesinde birebir aynı arızayla düşer. Merge edilmesi gereken 4 commit var.
    Aşağıdaki `/api/v1/version` gerekçesi hâlâ geçerli ve aynı merge'le kapanır.
    `/api/v1/version` yalnız bu ağaçta var; deploy
    edilene kadar durum çubuğunun canlı sürüm ölçümü sessizce boş kalır ve API sürümü işinin
    yarısı kâğıt üstünde durur. Deploy sonrası tek satırlık doğrulama:
    `curl -s https://api.sipario.com.tr/api/v1/version` → `{"api_version":"1.1.0",...}`.
    **API sürümü 1.0.0 → 1.1.0 ZATEN ARTIRILDI** (aynı commit'te; MINOR = geriye dönük uyumlu
    yeni alan).
    ⚠️ **ÖLÇÜLDÜ — çubuktaki `→` oku BU deploy'da ÇIKMAZ:** canlıda `/version` uç noktası HENÜZ
    YOK, yani canlı sürüm `1.0.0` diye okunmuyor, HİÇ okunamıyor (istek 404 → `apiCanli` boş →
    sessizce ağaçtaki değere düşülür, tasarlanan davranış). Bu yüzden çubuk şu an tek numara
    gösteriyor: `API 1.1.0`. **Deploy'un indiğinin işareti okun kaybolması değil, canlı okumanın
    BAŞLAMASIDIR** — ok mekanizması ancak bir SONRAKİ sürüm artışından itibaren iş görür.
    Bu tur için doğrulama yukarıdaki `curl`dür.
14. **[✅ KAPANDI — 2026-08-17, ÖLÇÜLDÜ]** ~~Flutter SDK ↔ `pubspec.lock` sapması~~ — **sapma
    ölçülemedi:** tam takım koşuldu, `pubspec.lock` DEĞİŞMEDİ ve `dart analyze` **0 issue** verdi;
    bahsi geçen `onReorder` info'su artık ÇIKMIYOR (çağrı hâlâ yerinde,
    `order_list_parts.dart:282`). **Göç KÖR YAPILMADI** — indeks kaydırma semantiği siparişlerin
    sürükle-sırala davranışını sessizce bozabilirdi ve bunu gerektiren bir kanıt yok.
    "analyze 0" yeniden otomatik doğru.
15. **[✅ KAPANDI — 2026-08-17]** ~~Test içine SABİT YAZILMIŞ İŞ DEĞERLERİ~~ — tarandı, iki gerçek
    bulgu düzeltildi: `SubscriptionTest` dönem süresini `BillingPeriod::Yearly->uzat()`tan okuyor
    (eski `addDays(300)` eşiği "yıllık"ı değil yalnız "çok uzun"u kanıtlıyordu), `LiveLocationTest`
    sınırı `config('konum.kalp_atisi_limit')`ten okuyor. ⚠️ **Düzeltme testin varlık sebebini
    delmesin diye** konum testine ayrıca "sınır genel API sınırından DAR olmalı" iddiası eklendi —
    yoksa değeri kaynaktan okumak testi "her zaman geçer" hâline getirirdi.

**YENİ (2026-08-10/2):**

16. **`${DEGISKEN:-varsayilan}` TUZAĞINI TARA.** `LOG_CHANNEL: ${LOG_CHANNEL:-stderr}` aylarca
    ölü kaldı çünkü `:-` yalnız değişken **tanımsızken** işler ve Coolify panelinde `LOG_CHANNEL`
    tanımlıydı. Compose'da bu desende onlarca satır var; her biri "varsayılanım korur" sanısı
    üretiyor. Panelde tanımlı olan her değişken için varsayılan ÖLÜDÜR — hangilerinin fiilen
    yürürlükte olduğu `docker inspect` ile okunmalı, dosyaya bakarak değil.
17. **Öksüz hacimleri karara bağla.** Sunucuda dört kuşak öksüz veri hacmi birikti
    (`h43pc3…`, `pz3gsgc8…`, `un35zcb…`, `xwdasjxc…`). Coolify uygulamayı silerken hacmi
    silmiyor; bu bir güvenlik ağı ama sessizce disk yiyor ve "veri silindi mi?" sorusunu
    belirsiz bırakıyor. Ya temizlenmeli ya da bilinçli olarak tutulduğu yazılmalı.
18. **[✅ KAPANDI — 2026-08-17, kullanıcı doğruladı]** ~~Coolify `StopApplication` → `CleanupDocker`
    → `external` ağ silinir → deploy kilitlenir.~~ **Sorun çözüldü.** Kilit bir daha gündeme
    gelmeyecek; aşağıdaki satır TARİHSEL KURTARMA BİLGİSİ olarak duruyor, iş maddesi değildir:
    kilit yeniden doğarsa çıkış yolu tek satırdır —
    `docker network create --driver bridge --attachable <app-uuid>`.
19. **[✅ KAPANDI — 2026-08-17, kullanıcı doğruladı]** ~~Test ortamında gerçek yol ağı sıralaması
    KAPALI~~ — **AÇIK.** `ROTA_SURUCU=google` ve Routes API çalışıyor; yakın-komşu artık yalnız
    yedek yol (anahtar/kota/ağ arızasında controller sessizce ona düşer, kullanıcı 5xx görmez).
    ⚠️ **Yürürlükte kalan tek kural (iş maddesi değil, dikkat notu):** test ve üretim aynı Google
    anahtarını paylaşmamalı — test döngüsü üretimin kotasını yakar; dev'de `GEOCODING_DAILY_LIMIT`
    düşük tutulur.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-09 · ÜRÜN CANLIDA + kayıp vardiya hafızasının onarımı)

> **EN ÖNEMLİ TEK CÜMLE: SİPARİO 2026-08-07'DEN BERİ CANLI SUNUCUDA ÇALIŞIYOR.**
> Bu satır bu dosyada üç gün boyunca YOKTU. Aşağıdaki "kayıp vardiya" bölümü nedenini anlatıyor.

**Ölçüm (bu vardiyada BİZZAT koşuldu — önceki nottaki rakamlar kopyalanmıştı):**
mobil **1108/1108** ✅ · API **682/682** (3441 iddia, **1 incomplete KASITLI** — LWW borcunun canlı
sinyali) ✅ · `phpstan` **0** ✅ · `pint` temiz ✅.

Önceki not "mobil 1077 · API 668" diyordu; bunlar 2026-08-06 vardiyasından KOPYALANMIŞ rakamlardı,
o vardiyada ölçülmemişti. Gerçek değerler **1108** ve **682** — yani iki suite de büyümüş ve yeşil.
**Bu önemli bir bulgu:** 08-07/08-08'de eklenen +2816 satır kod mevcut testlerin hiçbirini kırmamış.
Kod kalitesi sorunu YOK; sorun yeni davranışın (Yetki Matrisi) kendi testinin olmaması.

## 🔴 ÖNCE BUNU ANLA — "KAYIP VARDİYA" (2026-08-07 → 08-08)

Claude oturumu limit nedeniyle kesildikten sonra iş **Gemini (Antigravity CLI)** ile sürdürüldü.
Antigravity `CLAUDE.md`'yi okumadığı için bu projenin vardiya sözleşmesini bilmiyordu: kod yazdı,
commit attı, **ama `PLAN.md`/`DECISIONS.md`'yi ortak hafıza olarak güncellemedi.** Sonuç, bu projenin
en pahalı hata sınıfı oldu: **depoda çalışan bir gerçek var ama hiçbir yerde yazılı değil.**

Bunun somut bedeli ölçüldü: 2026-08-09'da yeni bir Claude oturumu, "canlıya geçelim" isteği üzerine
**sıfırdan üretim altyapısı planı sundu** — `docker-compose.prod.yml` zaten iki gündür repoda dururken.
Yanlış plan, yanlış zaman, boşa giden vardiya. Hafızayı güncellememenin maliyeti budur.

**Kural (değişmedi, ama artık kanıtı var):** hangi araçla çalışılırsa çalışılsın, vardiya sonunda
`PLAN.md` + `DECISIONS.md` güncellenir. Sohbet geçmişi paylaşılmaz; bu iki dosya + git ortak hafızadır.

## ✅ CANLI SUNUCU — MEVCUT GERÇEK (2026-08-07'de kuruldu, ilk kez burada yazılıyor)

| Ne | Değer |
|----|-------|
| Barındırma | **Türkiye'de VPS + Coolify** (kırmızı çizgi #4 sağlanıyor) |
| Uygulama | **`sipario.com.tr` — HER ŞEY buradan**: site + `/panel` + `/api/v1` (mobil dahil) |
| ⚠️ `api.` altalanı | **BAĞLI DEĞİL — 503 döndürüyor** (2026-08-09'da ölçüldü). Ayrıntı aşağıda. |
| Yığın | `docker-compose.prod.yml`: `app` · `queue` · `scheduler` · `db` (Postgres 16, ICU tr-TR) · `backup` |
| İmaj | `serversideup/php:8.3-fpm-nginx`, çok aşamalı build (`docker/php/Dockerfile`) |
| TLS | Coolify/Traefik + Let's Encrypt |
| DNS | Cloudflare |
| İzlenen dal | **`main`** |
| DB portu | Dışarı KAPALI (dev'deki 55432 yalnız yereldi) |
| Migration | Container açılışında `migrate --database=pgsql_owner` |
| Mobil bağlantı | `session.dart` varsayılanı **`https://sipario.com.tr/api/v1`**; giriş ekranındaki "+ Gelişmiş (sunucu adresi)" bölümü KALDIRILDI |

**🔬 CANLI SAĞLIK ÖLÇÜMÜ (2026-08-09, `curl` ile bizzat):**

| Uç nokta | Sonuç | Yorum |
|---|---|---|
| `https://sipario.com.tr/up` | **200** ✅ | Uygulama ayakta |
| `https://sipario.com.tr/` | **200** ✅ | Pazarlama sitesi çalışıyor |
| `https://sipario.com.tr/api/v1/auth/login` | **422** ✅ | **Mobilin kullandığı adres — sağlıklı** (422 = form doğrulama, yani uç nokta canlı) |
| `https://api.sipario.com.tr/` | **503** ❌ | Traefik'e ulaşıyor ama arkasında servis yok |
| `https://api.sipario.com.tr/api/v1/auth/login` | **503** ❌ | Aynı |

## 🔴 `www` VE `api` ALTALANLARI ÖLÜ — TEK KARAKTERLİK SEBEP (Coolify MCP ile bulundu)

**Bu bölüm bir kez YANLIŞ yazıldı ve MCP kurulunca düzeltildi.** İlk teşhis "`api.` Coolify'da
bağlı değil" idi. Gerçek bunun tersi: **üçü de bağlı.** Coolify'daki kayıtlı değer şu:

```
https://sipario.com.tr, https://www.sipario.com.tr, https://api.sipario.com.tr
```

Virgüllerden sonra **BOŞLUK** var. Ölçüm (üç hostname, aynı anda):

| Hostname | Sonuç | Yanıtı veren |
|---|---|---|
| `sipario.com.tr` | **200** | `Server: nginx` → container'a ulaşıyor ✅ |
| `www.sipario.com.tr` | **503** `no available server` | Coolify proxy — route YOK ❌ |
| `api.sipario.com.tr` | **503** `no available server` | Coolify proxy — route YOK ❌ |

DNS ikisinde de çalışıyor (proxy'ye ulaşılıyor), TLS geçerli.

### ✅ SONUÇ: BOŞLUK TEŞHİSİ **DOĞRUYDU** — KULLANICI DÜZELTTİ

**Bu bölüm iki kez yanlış yazıldı, nihai hâli budur.** Önce "api. bağlı değil" denildi (yanlış),
sonra "boşluk teşhisi çürüdü, deploy düzeltti" denildi (bu da yanlış). **Gerçek:** boşluk teşhisi
doğruydu ve **kullanıcı Coolify'daki boşlukları elle sildiği için** üç hostname de çalışmaya başladı.

**İkinci hatanın kök nedeni bir çıkarım hatasıydı:** "Coolify'da hiçbir şey değiştirmedim, demek ki
düzelme deploy'dan geldi" diye akıl yürütüldü. Eksik olan şey şuydu — **bu sistemde tek aktör ben
değilim.** Kullanıcı aynı anda paralel çalışıyordu. "Ben değiştirmedim" ile "değişmedi" aynı şey
değildir; ikisini eşitlemek, ölçümün kontrol edilmeyen bir değişkenini yok saymaktır.

Düzeltmeden sonraki ölçüm:

| Hostname | `/up` | `/` (ana sayfa) |
|---|---|---|
| `sipario.com.tr` | **200** | **200** ✅ |
| `www.sipario.com.tr` | **200** | **200** ✅ |
| `api.sipario.com.tr` | **200** | **404** ✅ — `BlockApiHostWebRoutes` ÇALIŞIYOR |

**Kök neden KESİN:** Coolify domain alanında virgülden sonraki boşluklar; yalnız ilk domain route
alıyordu. Kullanıcı boşlukları sildi → üçü de ayağa kalktı. Hipotez, düzeltme uygulanıp sonuç
ölçülerek **kanıtlandı**.

**İki ders:**
1. **"Ben değiştirmedim" ≠ "değişmedi".** Canlı bir sistemi ölçerken tek aktör sen değilsin;
   kullanıcı paralel çalışıyor olabilir. Bir düzelmeyi kendi son eylemine (deploy) atfetmeden önce
   **"başka kim ne yaptı?" diye sor.** Bu vardiyada o soru sorulmadığı için doğru bir teşhis
   gereksiz yere geri alındı ve belgeye yanlış bir "çürütüldü" kaydı düşüldü.
2. **`BlockApiHostWebRoutes` artık ölü kod değil, kanıtlanmış bir kapı:** `api.sipario.com.tr/`
   404, `api.sipario.com.tr/up` 200. Mobil trafiğin kapısından panele/siteye erişilemiyor —
   middleware tasarlandığı işi yapıyor ve bu ilk kez GERÇEKTEN ölçüldü.

**Kurulum sırasında çözülen gerçek arızalar** (15 commit, 08-07 09:08–10:30): Postgres init betikleri
mount edilemiyordu → imaja gömüldü (`docker/postgres/Dockerfile`) · `10-roles.sh` DB adını sabit
yazıyordu · roller mevcut tablolara grant almıyordu → `ensure_roles_exist` migration'ı · healthcheck
`start_period` yetersizdi, container "unhealthy" görünüyordu · Traefik label'ları Coolify'ın kendi
yönlendirmesiyle çakışıyordu → elle label'lar kaldırıldı · `.dockerignore` pagination şablonlarını
dışlıyordu. Bunlar gerçek mühendislik işiydi ve **doğru çözüldü**.

## ⚠️ BU VARDİYADA BULUNAN VE KAPATILAN ÜÇ GÜVENLİK AÇIĞI

1. **Panel superadmin parolası public depoda düz metindi.** `AdminUserSeeder` `SiparioAdmin2026!`
   parolasını koda gömüyor ve `updateOrCreate` ile HER deploy'da iki superadmin hesabına yeniden
   yazıyordu. Depo public, panel canlıda → bütün bayilerin iş verisine ve **dışa aktarım yetkisine**
   açık kapı. Üstelik parolayı elle değiştirmek işe yaramıyordu: bir sonraki deploy eskiyi geri yazıyordu.
   **Kapatıldı:** seeder artık parola TAŞIMIYOR; yeni hesap `Str::password(24)` ile doğar, var olan
   hesaba `firstOrCreate` ile DOKUNULMAZ (parola değişikliğin kalıcı, kapattığın hesap kapalı kalır).
   Parola alma yolu zaten vardı: `php artisan panel:admin "Ad" e-posta --sifirla`.
2. **Her deploy üretim veritabanına demo verisi basıyordu.** `Dockerfile` entrypoint'inde
   `db:seed --force`, `DatabaseSeeder` → `AdminUserSeeder` + **`DemoSeeder`**. Yani canlı bayilerin
   yanına her deploy'da demo bayisi ve sahte Bursa müşterileri yazılıyordu. **Kapatıldı:** seed
   satırı deploy'dan çıkarıldı; kurulu demo bayisi yerinde duruyor (mağaza incelemesi için gerekli).
3. **`|| true` migration hatasını yutuyordu.** Şema güncellenmese bile container "sağlıklı" kalkıyor,
   uygulama eski şemayla çalışıyordu. Bu, bu dosyada "sessiz arıza dersi" olarak YAZILI olan
   `saha-sunucu.ps1` hatasının (`*> $null` ile seeder hatasını yutmak) birebir tekrarıydı — ders
   yazılmıştı ama yeni araç onu okumadı. **Kapatıldı:** `set -e`; migrate düşerse container başlamaz
   ve arıza GÖRÜNÜR olur.
   ⚠️ **Ama otomatik rollback YOK — ve bu ölçülerek anlaşıldı.** Compose'daki `deploy.update_config`
   (`order: start-first` + `failure_action: rollback`) **yalnız Docker Swarm'da** çalışır; Coolify düz
   `docker compose` kullandığı için bu alanlar SESSİZCE YOK SAYILIYOR. Kanıt: bu vardiyanın
   iki ayrı deploy'unda `sipario.com.tr` **40–60 saniye boyunca 503** verdi — `start-first` gerçekten
   uygulansaydı hiç kesinti olmazdı. **Bu süre pilot sırasında fark edilir:** kurye teslim kapatırken
   denk gelirse yazma isteği düşer (offline kuyruk onu tutar, veri kaybı yok — ama "sunucuya
   ulaşılamıyor" bandı görünür). Yani deploy'lar şimdilik yoğun saat dışında yapılmalı. Yani migrate düşerse `restart: unless-stopped` döngüye girer ve **site aşağıda
   kalır**; eski sürüme dönüş ELLE yapılır (Coolify → önceki deployment → Redeploy).
   Takas bilinçli: bir defter uygulamasında GÖRÜNÜR kesinti, yanlış şemayla sessizce çalışıp para
   kayıtlarını bozmaktan iyidir. Ama "rollback beni korur" diye güvenilmemeli — **compose'daki o iki
   satır bugün dekoratiftir.** (Sıradaki işlerde: ya Swarm'a geçilir ya da o alanlar kaldırılıp
   yanlış güven veren yazı temizlenir.)

## ✅ COOLIFY ORTAM DEĞİŞKENLERİ — DENETLENDİ (2026-08-09, kullanıcı doğruladı)

| Değişken | Değer | Durum |
|---|---|---|
| `APP_KEY` | tanımlı | ✅ **Kritik güvenlik maddesi KAPANDI** — compose'daki public varsayılan kullanılmıyor |
| `GEOCODING_DRIVER` | `kademeli` | ✅ Üretim sürücüsü (Google önce, gerekirse Yandex) |
| `ROTA_SURUCU` | ~~`yakin-komsu`~~ → **`google`** | ⚠️ Kullanıcı düzeltti (bilinçli değildi). **Anahtar + deploy doğrulaması bekliyor** — aşağıya bak |
| `IYZICO_BASE_URL` | sandbox | ⚠️ Beklenen (üretim anahtarı yok) — ödeme canlıda çalışmaz |
| `MAIL_MAILER` | `smtp` | 🔴 **SMTP KURULMAMIŞ** — aşağıya bak |

### 🔴 E-POSTA SESSİZCE ÇALIŞMIYOR

`MAIL_MAILER=smtp` ama SMTP sunucusu henüz kurulmadı. Sonuç ölçüldü ve **çökme değil, sessiz kayıp**:
`Parola.php:132` gönderimi `try/catch` içinde tutup `report($e)` ile logluyor — numaralandırma
saldırısını önlemek için ekrana hiçbir şey yansımıyor. Yani:

- Bayi "Parolamı unuttum" der → ekranda **"e-posta gönderildi"** görür → **e-posta hiç gelmez.**
- Parolasını unutan bayinin kendi kendine kurtulma yolu YOK; destek kanalı gerekiyor.
- Her deneme log'a bir exception yazar (log şişer).
- Aynı yol: havale/ödeme bildirimleri (`OdemeBildirimServisi`, `Subscribe`, `Hesap`, panel `Bildirimler`).

**Not:** `MAIL_MAILER=log` da e-posta göndermez ama exception üretmez. Yani `smtp` bırakmak, SMTP
kurulana kadar sadece log kirletir — kullanıcı açısından ikisi de "e-posta gelmiyor"dur.
**Asıl iş SMTP'yi bağlamak** (hosting'in SMTP'si zaten var, karar verilmişti).

### ⚠️ `ROTA_SURUCU` — `yakin-komsu` idi, kullanıcı `google` yaptı (2026-08-09); DOĞRULAMA BEKLİYOR

**Bilinçli bir karar değildi:** Antigravity vardiyasında bu değerle kurulmuş ve öyle kalmıştı. Yani
oto sıralama günlerce **kuş uçuşu** çalıştı — gerçek yol ağını, tek yönleri ve dönüşleri bilmeden.
Özellik çalışıyordu, sadece rota kalitesi düşüktü; kimse fark etmedi çünkü hiçbir yerde sinyal yok.

Kullanıcı Coolify'da `google` yaptı. **Ama iki sessiz tuzak var ve ikisi de "çalışıyor" sanmaya yol açar:**

1. **`GOOGLE_ROUTES_KEY` boşsa `ROTA_SURUCU=google` HİÇBİR ŞEY YAPMAZ.**
   `AppServiceProvider::rotaMotoruKur()` son satırı: `return $google->hazirMi() ? $google : $yakinKomsu;`
   Anahtar yoksa sessizce yakın-komşuya düşer — hata yok, log yok, uyarı yok. Bu bilinçli bir
   yıkılmazlık tasarımıdır (yanlış bir env satırı özelliği KAPATMASIN) ama teşhis açısından körlük yaratır.
2. **Coolify'da env değiştirmek tek başına yetmez — YENİDEN DEPLOY gerekir.** İmajda
   `AUTORUN_LARAVEL_CONFIG_CACHE=true`; yapılandırma container açılışında önbelleğe alınıyor.

**Doğrulama (kod bunu kolaylaştırmış):** uygulamadan bir kez **Oto Sırala** çalıştır; sunucu yanıtındaki
`engine` alanı çalışan motoru söyler. `"google"` → tamam. `"yakin-komsu"` → anahtar eksik ya da deploy
yapılmamış. **Bu ölçüm yapılmadan "Google rota açıldı" yazılmamalı.**

⚠️ Aynı tuzak `GEOCODING_DRIVER=kademeli` için de geçerli: `GOOGLE_GEOCODER_KEY` / `YANDEX_GEOCODER_KEY`
yoksa sürücü Null'a düşer ve "Adresten Konum Al" dürüstçe "bu kurulumda tanımlı değil" der.
Ayrıca Google tarafında **faturalandırma açık değilse** anahtar geçerli olsa bile her istek
`REQUEST_DENIED` döner (sürücü bunu 503'e çevirir) — 2026-07-29'da bu bir kez ödendi.

## 🔑 ~~SENDE OLAN TEK KRİTİK İŞ — `APP_KEY`~~ ✅ KAPANDI (yukarıdaki tabloya bakınız)

`docker-compose.prod.yml:34` bir **varsayılan `APP_KEY` içeriyor** ve o değer public depoda yazılı:
`base64:Wi45ki1vmGrHW3XQUjFSQbkyNj0I/gGiyxlHlIpg5Wk=`. Coolify'ın Environment Variables sekmesinde
`APP_KEY` AYRICA tanımlı DEĞİLSE canlı bu anahtarı kullanıyordur. Bu anahtarla oturum çerezi
üretilebilir (panel oturumu dahil) ve `encrypt()` ile korunan her şey açılır.
**Yapılacak:** Coolify → Environment Variables → `APP_KEY` dolu mu bak. Değilse
`php artisan key:generate --show` ile üret, oraya gir, yeniden deploy et.
⚠️ Anahtar değişince mevcut oturumlar düşer (herkes yeniden giriş yapar) — **para/iş verisi
etkilenmez**, çünkü veritabanındaki hiçbir alan `APP_KEY` ile şifreli değil.

## 🔌 COOLIFY MCP KURULDU (2026-08-09) — ne görülebilir, ne görülemez

`https://coolify.gostra.co/mcp` **kullanıcı kapsamında** (`--scope user`) kuruldu; token
`~/.claude.json`'da durur ve **public depodaki `.mcp.json`'a değmez** (doğrulandı). Sunucu
kendini "**Read-only** MCP server for Coolify" diye tanıtıyor: root token verilse bile MCP
üzerinden hiçbir şey DEĞİŞTİRİLEMEZ. Coolify sürümü **4.1.2**.

**10 araç:** `get_infrastructure_overview` · `list/get_servers` · `list/get_projects` ·
`list/get_applications` · `list/get_databases` · `list/get_services`.

| ✅ Görülebiliyor | ❌ Görülemiyor |
|---|---|
| Sunucu/proje/uygulama envanteri ve durumu | **Environment variables** — yanıtta hiç yok |
| Domain eşlemesi, git dalı ve commit | Deployment logları / deploy geçmişi |
| Healthcheck ayarları, pre/post deploy komutları | Container içi durum, `docker logs` |
| Kaynak limitleri, restart sayacı, `last_online_at` | Yedek dosyaları |

### ✅ ENV GÖRÜNÜRLÜĞÜ ÇÖZÜLDÜ — MCP DEĞİL, **REST API**

MCP env döndürmüyor ama Coolify'ın **REST API'si döndürüyor** ve mevcut root token buna yetiyor:

```
GET https://coolify.gostra.co/api/v1/applications/{uuid}/envs
Authorization: Bearer <COOLIFY_TOKEN>
```

Uygulama UUID'si: `h43pc3jwcl2daz1pcfgutvd5`. Yanıt her değişken için `key` + `real_value` verir
(144 kayıt). **Kural: değerler sohbete/loga BASILMAZ** — denetim "dolu mu / boş mu / kaç karakter"
düzeyinde yapılır, sır olmayanlar (sürücü adları, portlar) açıkça okunabilir.

**2026-08-09 denetiminin tam sonucu:**

| Dolu ✅ | Boş / eksik |
|---|---|
| `APP_KEY` (52) · `DB_*_PASSWORD` (3×32) | `IYZICO_API_KEY` · `IYZICO_SECRET_KEY` (beklenen) |
| `GOOGLE_ROUTES_KEY` (39) · `GOOGLE_GEOCODER_KEY` (39) · `YANDEX_GEOCODER_KEY` (36) | |
| `MAIL_HOST=mail.sipario.com.tr` · `MAIL_PORT=587` · `MAIL_ENCRYPTION=tls` · `MAIL_USERNAME` (22) · `MAIL_PASSWORD` (32) | |

**Bu, "SMTP kurulmadı" varsayımını çürüttü:** posta yapılandırması EKSİKSİZ. Yani e-postanın
gitmemesinin sebebi eksik ayar değil — ya `mail.sipario.com.tr` ayakta değil ya kimlik yanlış.
Artık tahmin değil, **test edilebilir** bir soru.

### 🔴 `APP_DEBUG=true` — ÜRETİMDE, EN YÜKSEK ETKİLİ AÇIK

`APP_ENV=production` ama `APP_DEBUG=true`. `.env.example` bunu kendi satırında yasaklıyor:
*"ÜRETİMDE MUTLAKA false: true iken hata sayfaları yığın izini ve ortam değişkenlerini basar."*

Somut risk: canlıda **herhangi bir** hata oluştuğunda Laravel'in debug ekranı bütün ortam
değişkenlerini basar — `APP_KEY`, üç DB parolası, Google anahtarları, SMTP parolası. Tek bir 500,
bu vardiyada tek tek kapatılan sırların hepsini birden sızdırır. Panel parolasını repodan
çıkarmak, `APP_DEBUG` açıkken anlamını yitirir.

**Yapılacak:** Coolify → `APP_DEBUG` → `false` → redeploy. **Tek satır, en yüksek getiri.**

**İlk turda MCP'nin bulduğu üç şey** (üçü de belgedeki bir varsayımı çürüttü):
1. `www` ve `api` altalanlarının ölü olduğu ve **sebebi** (yukarıdaki bölüm) — önceki teşhis yanlıştı.
2. **Migration zaten Coolify post-deployment komutunda koşuyordu** (`app` container'ında,
   deploy başına bir kez). Yani "kalıcı çözüm post-deployment'a taşımak" diye yazdığım borç
   çoktan çözülmüştü; ben farkında olmadan Dockerfile'a İKİNCİ bir kopya koymuştum. Kopya
   kaldırıldı → migration yarışı borcu KAPANDI.
3. **`status: running:unhealthy`** (`restart_count: 0` — site çalışıyor, yalnız sinyal bozuk).
   Compose'daki healthcheck `curl` çağırıyordu; `serversideup/php` yalın bir imaj ve `curl`
   varlığı garanti değil. Test PHP tabanlıya çevrildi (PHP tanım gereği var).

## 🗺️ HARİTA "YÜKLENİYORDA KALIYOR" — SESSİZ ARIZA BULUNDU (saha raporu, 2026-08-09)

Kullanıcı demo hesabıyla girip haritaya dokundu; ekran sonsuza dek "Yükleniyor" dedi.

**Kök neden ekranın KENDİSİYDİ:** `siparis_harita.dart` `StreamBuilder<HaritaVerisi>` kullanıyor
ama **`snap.hasError` hiç kontrol edilmiyordu** — yalnız `snap.data`ya bakılıyor, `null` ise iskelet
çiziliyordu. Sorgu patladığında `veri` sonsuza dek `null` kalır, ekran donar ve **gerçek sebep
hiçbir yerde görünmez.** Bu deponun defalarca bedel ödediği sessiz-arıza sınıfının aynısı.

**Düzeltildi:** hata durumu artık ayrı çiziliyor (başlık altı "Yüklenemedi", gövdede "Harita
yüklenemedi" + Drift/SQLite'ın kendi mesajı). Mesaj KVKK açısından güvenli — tablo/kolon adları
taşır, müşteri verisi taşımaz. Davranış teste kilitlendi (`ui_siparis_harita_test.dart`, gerçek
senaryoyu taklit ediyor: bir tabloyu düşürüp şema uyumsuzluğu üretiyor).

**⚠️ Düzeltmenin kendisi ikinci bir arıza üretmişti ve test yakaladı:** uzun bir yığın izi
`SipBosDurum` içinde **3864 piksel taşırıyordu** — yani "hatayı göster" çözümü ekranı okunamaz
hâle getiriyordu. Kaydırılabilir yapıldı + mesaj 400 karakterde kırpıldı.

### 🔴 KÖK NEDEN BULUNDU (kablosuz adb, SM-S721B) — **SCHEMA SÜRÜMÜ ARTIRILMAMIŞ**

Cihaza `adb connect 192.168.1.103:37093` ile bağlanıldı, uygulama açıldı, haritaya dokunuldu ve
yeni hata ekranı **gerçek sebebi yazdı**:

```
SqliteException(1): while preparing statement,
no such column: tenant_settings.courier_can_see_all_orders
SQL logic error (code 1)
```

**Kök neden tek satırlık bir eksiklik:** Yetki Matrisi (2026-08-08) `tenant_settings`e 13 kolon
ekledi ve `app_database.dart` `onUpgrade` içine ALTER TABLE'larını da **yazdı** (satır 111-127) —
**ama `schemaVersion` 14'te bırakıldı.** Drift `onUpgrade`'i YALNIZ sürüm değiştiğinde çağırır;
sahadaki cihazlar zaten v14 damgalı olduğu için o ALTER TABLE'lar **hiç koşmadı.**

**Etki alanı haritadan çok daha geniş:** `tenant_settings`e dokunan HER sorgu, önceki sürümü
kurulu olan HER cihazda patlıyordu. Yani **Yetki Matrisi özelliğinin tamamı sahada ölüydü** —
harita yalnız en görünür belirtisiydi.

**Neden 1109 yeşil test bunu göremedi:** hepsi `NativeDatabase.memory()` ile TAZE veritabanı kurar,
yani `onCreate` yolundan geçer ve şema her zaman tamdır. **Hiçbiri YÜKSELTME yolundan geçmiyordu.**
Kusur yalnız "önceki sürümü kurulu olan cihazda" görünür — yani tam olarak gerçek kullanıcıların
durumunda, ve hiçbir yerde başka bir sinyal üretmeden.

**Düzeltme:** `schemaVersion => 15` + `migration_v15_test.dart` (v14 diskini birebir taklit eder:
güncel şemayla kurar, 13 kolonu DROP eder, `user_version = 14` damgalar, yeniden açar). Test
**kırılabilirliği kanıtlandı**: sürüm 14'e geri alınınca kırmızı yanıyor, yani vakum değil.
İddianın merkezi sahada patlayan sorgunun kendisi (`watchHaritaDuraklari`).

## 🔐 KURYE YETKİLERİ GERÇEKTEN BAĞLANDI (2026-08-09, saha raporu üzerine)

Saha raporu: *"yetkilendirme ekranında ayarlar var ama arka planda hiçbir kısıtlama devreye
girmiyor; kurye hâlâ her şeyi görüyor."* **Ölçüm kullanıcıyı doğruladı.**

**Teşhis:** `RolYetkileri` **26 alan** tanımlıyor, `yetkiler()` çözümleyicisi hepsini **doğru
hesaplıyor** — ama **yedisi hiçbir kapıya bağlı değildi**: `tumSiparisleriGorme` ·
`gecmisTeslimatlariGorme` · `gecmisHesapArsivi` · `gunuKapatma` · `isletmeAbonelikAyarlari` ·
`cihazAyarlari` · `rotaCalistir`. Yani **beyin sağlamdı, kollar takılı değildi**: ayar ekranda
görünüyor, `tenant_settings`e yazılıyor, hiçbir şeyi etkilemiyordu.

⚠️ Üstüne bir de `schemaVersion` kusuru biniyordu (yukarıda): o 13 kolon sahadaki cihazlarda
zaten YOKTU. Yani doğru bağlanmış kapılar bile ayarı okuyamazdı. İki kusur üst üsteydi.

**Yapılanlar (istek sırasıyla):**

| # | İstek | Önce | Şimdi |
|---|---|---|---|
| 1a | Gün özetinde yalnız kendi tahsilatı | ✅ zaten çalışıyordu (`day_end_screen:75,126`) | korundu |
| 1b | Kasa işlemleri kısıtlı | ❌ `gunSonu` okunuyordu → o izin açık olan kurye **GÜN hesabını** kapatabiliyordu | `gunuKapatma` (yalnız yönetici); kurye **yalnız kendi devrini** yapar |
| 1c | Geçmişi göremesin | ❌ kapı yok | "Geçmiş" düğmesi `gecmisHesapArsivi` ile çizilir |
| 2 | Borçlular görünmesin | ⚠️ tıklama engelli ama **kutu ve rakam görünüyordu** | kutu hiç çizilmez (`borclulariGoster`) |
| 3 | Yalnız kendi siparişleri | ❌ hiç yok | liste kilitlenir + başlık **"yalnız size atananlar"** der |
| 4 | Geçmiş teslimat yetkiye bağlı | ❌ hiç yok | gün şeridi `gecmisTeslimatlariGorme` ile çizilir |
| 5 | Ayarlar kısıtlı | ⚠️ İşletme zaten patronda; **Çağrı Geçmişi koşulsuzdu** | `cagriGunlugu` kapısı eklendi |

**Madde 3'ün özel notu:** filtreleme 2026-07-27'de **bilinçli kaldırılmıştı** — gerekçe "kuryenin
listesini HABER VERMEDEN daraltırdı" idi. Yani itiraz kısıtlamaya değil, SESSİZLİĞE idi. Bu yüzden
kısıtlama geri gelirken başlık bunu açıkça yazıyor; kurye eksik listeyi "iş yok" sanıp teslimat
kaçırmasın.

**Kasa devri kararı (kullanıcı, 2026-08-09):** kurye **kendi** kasasını devredebilir (BRIEF:
"gün sonunda kurye kasayı patrona devreder"), ama günü kapatamaz, başka kuryenin kapsamına
giremez, geçmiş arşivi göremez.

**Test:** `ui_kurye_kisitlari_test.dart` (4 test) — kurye yalnız kendine atananı görür · kısıtlama
sessiz değil · yönetici etkilenmez · yetki verilmezse eski davranış korunur. **Kırılabilirliği
kanıtlandı** (kapı kaldırılınca 3/4 kırmızı). `kurye_yetkileri_test.dart` "doğru hesaplıyor mu"yu
sınıyordu; bu dosya eksik yarısını kapatıyor: **hesaplanan yetki ekranda bir şeyi değiştiriyor mu.**

### ⚠️ BU İŞTEN KALAN AÇIK BORÇLAR

- **Kısıtlama YALNIZ ARAYÜZDE** (kullanıcı kararı). `SyncService.php:281` pull'u
  `WHERE tenant_id = ?` ile yapıyor — kullanıcı/rol süzmesi YOK, yani **bayinin tüm verisi kurye
  cihazına iniyor**. Ekranda gizlemek, cihazda yok etmek değildir. Sunucu süzmesi ayrı ve büyük
  bir iş (offline-first ile çatışır: atama değişince veri akışı ve tombstone yönetimi karmaşıklaşır).
- **`day_end_screen` ve `ayarlar_ekrani` kapılarının widget testi YOK.** Kod yazıldı ve
  `dart analyze` temiz, ama bu iki kapı yalnız gözle doğrulandı — madde 3'ünki gibi kırılabilir
  bir teste bağlanmalı.
- **Diğer yetkilerin "kullanılıyor" görüntüsü aldatıcı olabilir.** `cagriGunlugu` 4 yerde
  geçiyordu ama dördü de ayarı KAYDEDEN kod; tek bir kapı yoktu. Aynı denetim
  `sahaGideri` · `stokPasifleme` · `musteriGecmisDefteri` · `borcHatirlatma` · `telefonMaskeleme`
  için de yapılmalı — "geçiyor" ile "kapı" aynı şey değil.

## 📋 SIRADAKİ İŞLER (2026-08-09 itibarıyla, öncelik sırasıyla)

### 🔴 HEMEN — canlı sistemin sağlığı
0. 🔴🔴 **`APP_DEBUG=false` YAP** (Coolify → redeploy). Üretimde `true`; bir hata sayfası tüm
   ortam değişkenlerini (APP_KEY, DB parolaları, API anahtarları, SMTP parolası) ekrana basar.
   Bu vardiyada kapatılan bütün sırları tek bir 500 geri açar. **Tek satır, en yüksek getiri.**
1. 🔴 **SMTP: yapılandırma TAM, sunucu şüpheli.** (Düzeltildi — "kurulmadı" sanılıyordu.)
   `MAIL_HOST=mail.sipario.com.tr` · `587` · `tls` · kullanıcı adı ve parola dolu. Yani eksik ayar
   YOK; ya posta sunucusu ayakta değil ya kimlik yanlış. Doğrulama: canlıda bir test e-postası
   gönderip `report()`un log'a yazdığı gerçek SMTP hatasını okumak. Parola sıfırlama şu an
   SESSİZCE ÇALIŞMIYOR (aşağıdaki eski açıklama geçerli).
2. ~~SMTP'yi bağla~~ — parola sıfırlama şu an SESSİZCE ÇALIŞMIYOR. `MAIL_MAILER=smtp` ama SMTP
   sunucusu kurulmadı. Bayi "Parolamı unuttum" der, ekranda **"e-posta gönderildi"** görür, e-posta
   hiç gelmez (`Parola.php:132` `try/catch` + `report($e)` — numaralandırmayı önlemek için ekrana
   yansıtmıyor). Parolasını unutan bayinin kendi kendine kurtulma yolu YOK. Aynı yol havale/ödeme
   bildirimlerini de taşıyor. Karar zaten verilmişti: **hosting'in SMTP'si.** Gereken:
   `MAIL_HOST` · `MAIL_PORT` · `MAIL_USERNAME` · `MAIL_PASSWORD` · `MAIL_ENCRYPTION`.
   Bağlanana kadar `MAIL_MAILER=log` yapmak log kirlenmesini durdurur (e-posta yine gitmez).
2. **`ROTA_SURUCU=google` DOĞRULAMASI** — değer değişti ama etkili olduğu ölçülmedi. Uygulamadan bir
   kez **Oto Sırala** çalıştır ve yanıttaki `engine` alanına bak: `"google"` mi `"yakin-komsu"` mu?
   `yakin-komsu` çıkarsa iki sebepten biridir: `GOOGLE_ROUTES_KEY` boş, ya da env değişikliğinden
   sonra yeniden deploy yapılmadı (config önbelleğe alınıyor). **Ölçmeden "açıldı" sayma.**
3. ~~**`dev` → `main` birleştirmesi**~~ ✅ Yapıldı; güvenlik düzeltmeleri canlıda.
4. ~~**`APP_KEY` doğrulaması**~~ ✅ **KAPANDI** — Coolify'da tanımlı olduğu doğrulandı (2026-08-09).
   Compose'daki public varsayılan kullanılmıyor.
5. ~~**`www` / `api` altalanları ölü**~~ ✅ **KAPANDI (2026-08-09).** Kök neden Coolify domain
   alanındaki virgül+boşluktu; **kullanıcı boşlukları sildi** ve üçü de ayağa kalktı.
   `api.sipario.com.tr/` 404 vererek `BlockApiHostWebRoutes`in gerçekten çalıştığını da kanıtladı.
6. ~~**Migration yarışı**~~ ✅ **KAPANDI (2026-08-09, MCP ile).** Migrate'in ZATEN Coolify
   post-deployment komutunda (`app` container'ı, deploy başına bir kez) koştuğu görüldü; borç olarak
   yazılan "post-deployment'a taşı" çözümü çoktan uygulanmıştı. Dockerfile'daki ikinci kopya
   kaldırıldı → yarış yüzeyi ortadan kalktı, şema tek yerden güncelleniyor.
7. **Healthcheck — KISMİ SONUÇ, ZAFER İLAN EDİLMEDİ.** Test `curl`den PHP'ye çevrildi ve deploy
   sonrası durum `running:unhealthy` → **`running:unknown`** oldu; 150 saniye boyunca izlendi,
   `healthy`ye dönmedi. Yani:
   - ✅ **Sahte alarm bitti** — panel artık yanlış yere kırmızı göstermiyor (alarm körlüğü riski geçti).
   - ❌ **Healthcheck'in GERÇEKTEN çalıştığı kanıtlanmadı.** Coolify'daki diğer tüm uygulamalar da
     `running:unknown` gösteriyor; bu, "healthcheck sonucu yok" varsayılanı olabilir — yani sinyal
     yeşile dönmedi, sadece sustu.
   **Kesin kanıt için** sunucuda `docker ps` çıktısındaki STATUS sütununa bakılmalı: `(healthy)`
   yazıyorsa iş bitmiştir. MCP container düzeyi ayrıntı vermediği için bu yolla ölçülemiyor.

### 🟠 YAKINDA — açık riskler
5. **Makine dışı yedek YOK.** `backup` sidecar günlük `pg_dump` alıyor ama yalnız sunucunun kendi
   `sipario_backups` volume'una. Sunucu ölürse yedek de ölür. Kırmızı çizgi #5 ("veri rehin alınmaz")
   bir kopya stratejisi olmadan sadece bir cümledir. Karar kullanıcıya bırakıldı (hosting'e rsync /
   S3 uyumlu TR depolama / elle indirme).
6. **Yetki Matrisi'nin testi yok.** 08-07→08-08 arası **+2816 satır kod, sıfır yeni test**. 13 izin
   anahtarı, 3 şablon ve tüm ekran kapıları yalnız elle bakışla doğrulandı. Mevcut suite kırılmadı
   (iyi haber) ama yeni davranışı kilitleyen hiçbir iddia yok. En az: sunucu tarafı izin kapıları +
   `yetkiler()` çözümleyicisi için birim testleri.
7. **Cihaz doğrulaması yapılmadı** (SM-S721B): kurye yetkileri ekranı, 3 şablonun DB'ye yazması,
   kurye ROLÜYLE giriş (kendi kasası ✓ / başkasının kapsamı ✗), gün kapanışı SUBMIT + arşiv okuma.
8. **Google anahtarı hâlâ kısıtsız olabilir.** Artık **sabit sunucu IP'si var** — bu iş nihayet
   yapılabilir: Cloud Console → anahtarı "Geocoding API" + "Routes API" ve sunucu IP'siyle kısıtla.
   (HTTP referrer SEÇME — sunucu anahtarıdır, referrer kuralı isteği reddeder.)

### 🟡 SONRAKİ VARDİYA — taşınan borçlar
- **LWW saniye-altı ayrımı yok** (18 kolonluk `timestamptz(6)` migration'ı; suite'te `markTestIncomplete`
  ile canlı sinyal). Ayrıntı aşağıdaki "AÇIK BORÇLAR"da.
- **`order_list_screen.dart:118`** hâlâ cihaz saatiyle gün seçiyor (`bugunTr()`). Para yazmıyor ama
  teslim sekmesinin gün gezinmesini kaydırır.
- **`SyncService.php` 500 satır sınırında · `ChangeApplier.php` 499** — bir sonraki ekleme bölmeyi ister.
- **Hukuk:** KVKK aydınlatma + mesafeli satış/ön bilgilendirme metinlerinin avukat onayı. Site canlı
  olduğu için bu metinler artık gerçek yasal beyan. KVKK metnine "adres bilgisi coğrafi kodlama
  amacıyla yurt dışı sağlayıcılara aktarılır" satırı eklenmeli (Google/Yandex).
- **iyzico üretim anahtarı** — gelene kadar ödeme akışı canlıda çalışmaz (kod fail-closed).
- **Mağaza başvurusu** (Play + App Store hesapları, `USE_FULL_SCREEN_INTENT` beyanı, tanıtım videosu).

### ℹ️ Rolü değişen araç
`scripts/saha-sunucu.ps1` + `SUNUCU-BASLAT.bat` artık **saha dağıtım aracı DEĞİL** — canlı sunucu o işi
devraldı. Yerel geliştirme sunucusu olarak değerini koruyor (Docker + migrate + demo veri + tünel).
Demo kimliği bu vardiyada güncellendi (`111/111/1111` → `demo/demo/demo1234`); ekrandaki
"arkadaşına gönderilecek adres" metni artık yalnız yerel deneme içindir.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-08 · Kurye Yönetimi Ekranı Yeniden Tasarımı)

> ⚠️ Bu not Antigravity (Gemini) vardiyasında yazıldı. **Ölçüm rakamları (mobil 1077 / API 668)
> KOPYALANMIŞTIR, o vardiyada ölçülmemiştir** — 2026-08-09'da bizzat koşulan gerçek değerler
> yukarıdaki güncel notta. Ayrıca notun "canlıya geçmeden" ifadesi yanlıştır: ürün o sırada
> ZATEN canlıydı. İçerik tarihsel kayıt olarak korunuyor.

**Bir cümlede:** Kurye Yönetimi Ekranı **yeniden tasarımı** (yeni `KuryeYetkileriEkrani.dart`,
466 satır) + 3 hızlı şablon (Varsayılan/Tam Yetkili/Kısıtlı) + 6 kategori × 13 izin matrisi · Güvenlik
güncellemesi (guzzlehttp/commonmark yamaları) · Badge/boş durum uyumu. Hiçbiri **cihazda test edilmedi**.

## YAPILAN İŞLER (2026-08-08)

1. **Kurye Yönetimi Ekranı Yeniden Tasarımı** (653b2b2, 8 Ağustos 23:29)
   - **Yeni Dosya:** `apps/mobile/lib/screens/isletme/kurye_yetkileri_ekrani.dart` (466 satır)
   - **Sipario Genel Yetki Matrisi** tam uyumlu
   - **3 Hızlı Şablon:** Varsayılan · Tam Yetkili · Kısıtlı Saha
   - **6 Kategori:** Sipariş & Teslimat · Kasa & Tahsilat · Gün Sonu & Devir · Müşteri & KVKK · Ürün & Stok · Çağrı & Ayarlar
   - **13 İzin Anahtarı** (musteri, siparis, tahsilat, iskonto, gunSonu, tumSiparisler, gecmisTeslimatlar, 
     sahaGideri, telefonMaskeleme, musteriGecmisDefteri, borcHatirlatma, stokPasifleme, cagriGunlugu)
   - Kuryeler ekranına "Yetkiler" butonu eklendi (üst sağ)
   - Yetki matrisi kategorilere göre kartlar halinde gösteriliyor

2. **Kurye Yönetimi Ekranı Genişletildi** (653b2b2)
   - Yetkileri ayrı sayfaya taşındı (kalabalık önlemek için)
   - Kuryeler listesinde yetki matrisi kartı eklendi
   - Tasarım: "Sipario 3.0" modern, ferah, kullanışlı

3. **Güvenlik Güncellemesi** (78c3aea, 8 Ağustos 23:37)
   - `guzzlehttp/guzzle` güvenlik yamalarının uygulanması
   - `league/commonmark` güvenlik güncellemesi
   - Composer.lock 52 satır değiştirildi (26 insert + 26 delete)

4. **Badge & Empty State Uyumu** (d4bb9f6, 8 Ağustos 23:39)
   - Kurye ekranı passive badge ve empty state durumları
   - Test suite ile hizalanması (83 satır değiştirildi)
   - UI tutarlılığı sağlandı

## ⚠️ BEKLENEN NAKİT — NİHAİ TANIM (üç yanlış denemeden sonra; ayrıntı DECISIONS'ta)
```
beklenen (gün)   = günün nakdi − Σ(kuryenin O GÜN topladığı − O GÜN teslim ettiği)     ← AKIŞ
beklenen (kurye) = o kuryenin PENCERESİNDE topladığı − teslim ettiği                    ← STOK
```
Kurye penceresi son `scope=courier` kapanışına demirli; hiç kapanışı yoksa **alttan AÇIK** (cep gece
yarısı boşalmaz). Gün kapsamının okunur doğrulama ifadesi: *"bugün kasaya fiilen giren para" = patronun
kendi tahsilatı + bugün alınan devirlerin SAYILAN toplamı.* Orta terim NEGATİF olabilir (kurye dünün
parasını bugün teslim eder) ve KIRPILMAZ; ekran işareti ve etiketi değere göre seçer
("Kuryelerde kalan" / negatifte "Kuryelerden devir").
**İki kapsam iki farklı soru sorar — gün kapsamı kurye STOKUNU ödünç ALMAZ.** Bu tam olarak
düzeltilen kusurdu.

## ⚠️ AÇIK — CİHAZDA TEST YAPILMADI

**Tüm yukarıdaki kod değişiklikleri henüz **canlı cihazda sınanmadı**. Yazılı testler yeşil (1077/1077 + 668/668) 
ama sahada dokunmasız. Başlangıç için gereken adımlar:**

- SM-S721B kablosuz adb kuruldu (build 2292)
- Kurye yetkileri ekranının UI/UX kontrol edilmedi
- 13 izin anahtarının tamamının (özellikle yeni eklenenler) cihazda çalıştığı doğrulanmadı
- Yetki şablonlarının (Varsayılan/Tam Yetkili/Kısıtlı) doğru kayıtları geçip geçmediği bilinmiyor

## ÜÇÜNCÜ İNCELEME TURU — altı bulgu daha, hepsi kapandı
İlk iki tur gerçek kusur bulmuştu; üçüncü tur **henüz hiç incelenmemiş son değişikliklerin üstüne** koşuldu ve yine buldu:
1. **`kapat()` kapanmış kapsamı reddetmiyordu.** Ara tahsilat yolunda bu kapı VARDI (gerekçesi bile "sheet açıkken başka cihazdan kapanış inebilir" diyor), kapanış yolunda YOKTU. Sonuç: aynı para iki kez sayılıyor, gün beklenen 10.000 yerine 20.000 çıkıyor, patron "EKSİK 10.000" görüp arşive donduruyordu. **Çift kapak:** istemcide `kapaliMi` kapısı + **deterministik id** (`uuid5(tenant|scope|user_id|TR gün)`; bağlı devir aynı çekirdekten ayrı etiketle, **ara tahsilatlar RASTGELE id'de KALIR** — yoksa gün içinde çok tahsilat özelliği ölür).
   ⚠️ **Sunucuya tekillik indeksi konması DEĞERLENDİRİLDİ ve REDDEDİLDİ:** kapanış sunucuya İKİ AYRI OLAY olarak gidiyor; indeks yalnız arşiv satırını reddeder, para hatasına dokunmaz ve sahipsiz kalan devir sistemin kendi kuralıyla **hayalet bir ARA TAHSİLATA terfi eder**. Okuma tarafını daha da bozardı.
   Sunucuda uygulayıcılar artık aynı id'de fırlatmıyor, **`'duplicate'`** dönüyor (mobilde `acked`). **Bilinçli bedel: ikinci denemenin SAYILAN tutarı kayda geçmez, ilk mutabakat kalır.**
2. **`ana_ozet.dart` kendi gün sınırını tutuyordu** (ham `DateTime.now()`) — bento "Bugün Kasa 0,00 ₺" derken bir dokunuş ötedeki Gün Özeti "12.000 ₺" diyebiliyordu. `tr_gun.dart`a bağlandı; gün artık **akıştan** türüyor (`watchSyncState` → offset), gece yarısını geçen ekran kendiliğinden yeni güne dönüyor.
3. **Kurye kapanışı ARŞİVE tutarsız rakam donduruyordu** (`cash_nakit_kurus` GÜN, `expected_cash_kurus` PENCERE). `ClosingOnizleme.cerceveKasa` ile kayıt kendi içinde tutarlı; `toplam == nakit+kart+havale` kimliği korunuyor. Ekranda ayrıca çerçeve notu: *"Önceki günden devreden nakit dahil — ekrandaki gün toplamıyla aynı aralık değil"* (çerçeveler çakışıyorsa çizilmez).
4. **Ara tahsilat FARKI hiçbir ekranda görünmüyordu** — BRIEF'in "eksik para KANIT olarak görünür kalmalı" kuralı. Kart satırına eklendi ("Emre · 14:30 · kuryede kalan 30,00 ₺"), sıfırsa yazılmıyor; sheet'in tonu korundu (arıza dili YOK — ara tahsilatta tutar serbesttir).
5. **Ölü ama TUZAKLI iki alan** temizlendi: `GunSonuGorunumu.arsiv` (her yüklemede 50 satır çekiyordu, sıfır okuyucu) ve `ozet.kasa` (tipi daraltılarak `g.ozet.kasa` artık DERLENMİYOR — ekranlara dokunmadan kapatmanın yolu buydu).
6. **`duzeltme()` yanlış kişiye atfediyordu:** ters kayıt yazanın üstüne yazılıyordu. Patron kuryenin 2.000'ini ters çevirince gün beklenen −2.000 ("FAZLA"), kuryenin kapanışında ise **hiç var olmamış 2.000'lik EKSİK** ona donuyordu. Atıf artık ters çevrilen satırdan devralınıyor; sunucuda ayrıca **çelişkiyi REDDEDEN** dar bir kapı var (sunucunun beyanı yeniden YAZMASI reddedildi — "counted/expected/diff istemci snapshot'ıdır" güven modelini kırardı).

**Yan kazançlar:** `day_closings` panel export'una eklendi (`cash_handovers` vardı, kapanış arşivi YOKTU — "veri rehin alınmaz" taahhüdünde boşluktu) · `DemoSeeder` `credit`+`payment_type` yazıyordu, ürünün kendi yolu (`payment`) ile uyumlandı · `ledger_entries`e `payment_type` kapsam CHECK'i eklendi (**`NOT VALID`** — ölçüldü: dev DB'de kuralı ihlal eden 1 satır vardı, düz CHECK migration'ı patlatırdı ve append-only satır düzeltilemezdi).

**Kiracı çakışması ÖLÇÜLDÜ ve güvenli çıktı:** `day_closings.id` GLOBAL primary key; deterministik çekirdeğe `tenantCode` konmasaydı `scope='day'` tüm bayilerde çakışırdı. Başka kiracının aynı id'si RLS sayesinde `find()`e görünmüyor → `'duplicate'` DEĞİL, PK ihlaliyle **görünür** red. Testte yalnız sonuç değil MEKANİZMA da (`invalid_data`) kilitlendi; RLS düşerse test kırmızı yanar.

## ✅ CİHAZDA DOĞRULANDI (2026-08-06 · SM-S721B, kablosuz adb, yapım **2292**)
Kurulum CI APK'sıyla (`saha-arm64`, git sayısı 292) veri kaybı olmadan üstüne yapıldı.
- **Müşteri sırası:** 115→114→113→112→111→110→109, kayıt sırası tersten. ✓
- **Gün Özeti:** başlık + çekmece + alt sekme + bildirim ayarı hepsi "Gün özeti" diyor. ✓
- **Ana ekran ↔ Gün Özeti çapraz kontrolü:** ikisi de aynı günü konuşuyor (ikisi de 0,00 ₺). ✓
- **Geçmiş ekranı:** dünde açılıyor, gün şeridi çalışıyor, **ileri ok bugünde soluklaşıp duruyor**,
  kapatılmamış günde uyarı bandı, boş günde "Bu güne ait hareket yok", kurye kapsamı süzüyor. ✓
- **Ara tahsilat (GERÇEK KAYIT yazıldı, kullanıcı onayıyla):** Emre Kurye'den 300 ₺ alındı
  (beklenen 345 ₺) → sheet canlı **"KURYEDE KALAN 45,00 ₺"** gösterdi, kayıt oluştu, **gün AÇIK kaldı**,
  özet kartında `18:48 · kuryede kalan 45,00 ₺ → 300,00 ₺` satırı belirdi. Not: "cihaz dogrulama testi".
- **⭐ NİHAİ TANIM CANLI KANITLANDI:** ardından gün kapanışı sheet'i
  `Günün nakdi 0,00 ₺ · Kuryelerden devir **+ 300,00 ₺** · Beklenen nakit **300,00 ₺**` yazdı —
  yani orta terim NEGATİFE düştü, **işaret `+`'ya ve etiket "Kuryelerden devir"e** çevrildi.
  Reddedilen üç tanım bu senaryoda sırasıyla "FAZLA 300", "−300" ve "−45" derdi; yalnız nihai tanım
  doğru rakamı verdi. (Kapanış SUBMIT EDİLMEDİ, gün açık bırakıldı.)
- **Tazelik satırı:** "Sunucuya son ulaşma: 1 dk önce" — dürüst dil, "veriler güncel" demiyor. ✓
- **Çerçeve notu:** kasa kartı Emre için 0,00 ₺ gösterirken sheet 345,00 ₺ beklerken altında
  *"Önceki günden devreden nakit dahil — ekrandaki gün toplamıyla aynı aralık değil"* çizildi. ✓
- **İşletme Profili:** IBAN Alıcı Adı alanı + Hatırlatma Mesajı alanı + 4 yer tutucu çipi +
  "Varsayılanı yükle" (varsayılan şablon birebir yüklendi) + "IBAN ve alıcı adı sabittir" açıklaması. ✓
- **⭐ WhatsApp kodlaması (ajanın "cihazda ölçemedim" dediği TEK yer):** mesaj WhatsApp yazı kutusuna
  **boşluklarla** düştü, `+` YOK; `₺` doğru basıldı; alıcı adı boş olduğu için "Alıcı: Merkez Su Bayii"
  olarak işletme adına düştü. **MESAJ GÖNDERİLMEDİ.** ✓

⚠️ **Demo bayinin defterinde kalıcı bir kasa devri kaydı var** (300 ₺, Emre Kurye, 6 Ağustos 18:48,
notu "cihaz dogrulama testi"). Append-only olduğu için silinemez; gerekirse telafi kaydıyla düzeltilir.

## (ARŞİV) 2026-08-08 vardiyasının o günkü iş listesi
> Güncel liste yukarıdaki 2026-08-09 notundadır. Aşağıdaki "canlıya geçmeden" ifadesi YANLIŞTIR —
> ürün o tarihte zaten canlıydı. Cihaz doğrulama maddeleri hâlâ geçerli ve güncel listeye taşındı.

### (o günkü) HEMEN — SM-S721B
1. **Kurye Yetkileri Ekranı Cihaz Testi** — yeni `KuryeYetkileriEkrani.dart`'ın UI/mantık kontrolü:
   - Yönetici hesaptan açılabiliyor mu (İşletme → Ayarlar → Kuryeler → Yetkiler)
   - 13 izin anahtarı tamamı kategoriye göre gruplandırılıyor mu
   - 3 Hızlı Şablon (Varsayılan/Tam Yetkili/Kısıtlı) tıklanabiliyor mu
   - Şablon seçimi → toast gösteriyor mu + DB'ye yazıyor mu
   - Salt-okunur kip uyarı gösteriyor mu (kurye oturumda)
   - Kurye rolü bu ekranı görmüyor mu (K2 kuralı)

2. **Kurye ROLÜyle Giriş Senaryosu** (eski gerekçe 378-379 hattı):
   - Kurye hesabı ile giriş (önceden oluşturulmuş demo kurye)
   - Kendi kasasını teslim etme işlemi (hangi izinler aktif)
   - Diğer kuryenin kapsamını GÖRMEME (RLS kontrolü)
   - Gün kapanışı SUBMIT etme + arşiv satırı okuma
   - İki cihazlı senaryo (determinitik ID yakınsaması)

3. **Müşteri Sırası Doğrulaması** (eski vardiyadakanlar):
   - Müşteri listesi `code IS NULL DESC → code DESC → rowid DESC` sırası kontrol
   - En son kayıt en üstte görünüyor mu

### 🟡 SONRAKI VARDIYA
- **`order_list_screen.dart:118`** — cihaz saatiyle gün seçiyor (`bugunTr()`). Düzeltilmiş saate geçmeli.
- **LWW saniye-altı borcu** — 18 kolonluk migration, şema evrimi. Ayrı vardiya işi.

## AÇIK BORÇLAR (bu turdan)
- **LWW'nin saniye-altı ayrımı YOK.** Kolonlar `timestamptz(0)`; aynı saniyeye düşen iki yazımda kazanan
  "daha yeni olan" değil, `device_id`si büyük olandır. Panel bunu sentetik cihaz kimliği + damga ileri
  alma ile aşıyor; **kapağı olmayan yer MOBİL senkron yolu.** Kapatmak 18 kolonluk
  `TYPE timestamptz(6)` migration'ı + şema evrimi sözleşmesi + o iki hilenin gözden geçirilmesini ister.
  Borç `SyncZamanNormalizasyonuTest` içinde `markTestIncomplete` ile **CANLI sinyal** (suite'teki 1
  incomplete budur — sessiz bir TODO değil).
- **`EventValidator` `device_id`yi opsiyonel sayıyor** (cash_handover). Zorunlu kılmak REDDEDİLDİ: para
  kaydını sessizce düşürürdü. Doğru kapı sunucuda uyarı + panelde görünürlük.
- **`_guvenliUygula` atlama boşluğu** artık somut kurbanıyla biliniyor: atlanan satır bir `cash_handover`
  olursa kuryenin penceresi KALICI bayat kalır. Kapağı şema sürümü işi.
- **`EventValidator` göreli damgaları elemiyor** (`"now"`, `"+1 day"`) — sunucunun bugününe çözülür.
- **Tam tablo taramaları** (`kasaOzeti`, `teslimEdilenNakit`, `araTahsilatlar`, `gunKayitVarMi`…) tüm
  tabloyu çekip Dart'ta süzüyor. Bugün sorun değil, iki yıllık defterde olacak.
- **`SyncService.php` 500 satır sınırında** — bir sonraki ekleme bölmeyi gerektirir.
- **`ChangeApplier.php` 499 satır** — `applyLedger`ı `OrderChangeApplier` deseninde bir `LedgerChangeApplier`a ayırmak doğru hamle; hot path olduğu için bu vardiyada başlatılmadı.
- **"İki cihaz aynı gün için FARKLI tutar saydı" bilgisi hiçbir yere düşmüyor.** Deterministik id ile ikinci deneme sessizce yakınsıyor; kayıp veri yok (ilk mutabakat duruyor) ama farklı sayım bilgisi kayboluyor. İstemcideki `kapaliMi` kapısı bu yolu nadirleştiriyor; kalıcı çözüm bir uyarı/log satırı.
- **`ledger_entries_payment_type_scope_check` `NOT VALID`** — dev DB'de kuralı ihlal eden 1 eski demo satırı var. O satır temizlenince (`migrate:fresh` + reseed) `VALIDATE CONSTRAINT` ile tam kısıta yükseltilebilir; kontrol sorgusu migration yorumunda hazır.
- **④ kapısı (correction atfı) DB'ye indirilemez** — başka satıra bakıyor, CHECK yapamaz. Eloquent'le doğrudan yazan bir yol açılırsa (seeder deseni) kapı atlanır.
- **Bu turun migration'ları dev DB'ye UYGULANMADI** (`004004` panel grant, `004005` payment_type kapsam CHECK'i). Test DB'sine koşum sırasında uygulandı; dev/saha ortamında elle `php artisan migrate` gerekiyor.

## BU VARDİYANIN KALICI DERSİ (DECISIONS'ta uzun hâli)
**Anlamı değişen sayıyı eski kelimesiyle taşımak** — aynı hata sınıfı bir vardiyada YEDİ kez tekrarlandı
ve her seferinde analyze + suite yeşil geçti. Üç kapak kuruldu: anlam DEĞERLE taşınır (`DusulenKalem`
enum'u, `switch` derlemeyi kırar) · ekran metni FORMÜL İDDİA ETMEZ · etiketler İKİ YÖNLÜ kilitlenir
(doğru kelimenin varlığı + öbür kapsamın kelimesinin yokluğu). Ayrıca: **`a − b == c` biçiminde bir
test, `c` zaten `a − b` olarak dolduruluyorsa VAKUMDUR** — kusur tam da o kimlik yeşilken oluştu.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-05/4 · sahadan 10 maddelik site listesi — HEPSİ KAPANDI)

**Ölçüm:** API **643/643** (3197 iddia) · `pint` temiz · `view:cache` yeşil · 7 site sayfası +
`/hesap` panelinde konsol hatası **sıfır**. 5 ajanlı swarm (gezinme · hesap · ekip · fiyat · stil).

**Bir cümlede:** Kullanıcı web tarafında 10 madde saydı; ikisi sessiz ARIZA çıktı (giriş durumu
görünmüyordu — RLS yüzünden `Auth::check()` yalan söylüyor VE `$oturum` prop'u hiç geçilmiyordu;
çıkışın tek yolu bir sekmenin dibine gömülüydü), sekizi ürün kararıydı. Hepsi kapandı, kararların
gerekçeleri DECISIONS.md sonunda iki uzun satırda.

## KAPANANLAR (madde numaraları kullanıcının listesinden)
1. **Oturum görünürlüğü** — `session()->has(Auth::guard('web')->getName())`; kullanıcı HİÇ yüklenmiyor
   (sıfır sorgu). `tenant` middleware'ini pazarlama sayfalarına takmak REDDEDİLDİ.
2. **"Dönemi seçin" → "Yenileme ödemesi"**; radyo düğmesi/seçili vurgusu kaldırıldı (ekran form
   kontrolü diliyle konuşurken aslında ödeme adımıydı).
3. **Ödeme "Vazgeç"** beyaz listeli `geri` anahtarıyla geldiği sekmeye döner (`Referer` reddedildi).
4. **"Oto-sıralama" → "Kullanım ve ek paketler"** (anahtar `hak` korundu), ek KURYE paketi de satılıyor.
5. **`a` alt çizgisi** kapatıldı, yalnız düz metin akışında kaldı (WCAG 1.4.1).
6. **Web'den kurye hesabı aç/devre dışı bırak** — yeni `Ekip` sekmesi. Üç ayrı yazma yolu, üçü de
   farklı bağlantı; gerçek DELETE YOK (FK olmadığı için sahipsiz para kaydı bırakırdı).
7. **"Kurumsal" plan siteden kaldırıldı** (uydurma vitrindi), `/fiyatlar` `noindex` + menüden çıktı,
   ek kurye fiyatı `addon_packages` kataloğundan.
8. **Üst menü 4→2** (Özellikler + Destek). 9. **Alt bilgideki 4 İKİZ bağlantı** kaldırıldı.
10. **Footer künye bloğu** kaldırıldı; mevzuat karşılığı iki hukuk belgesinde ÖLÇÜLEREK kanıtlandı.

## YAN KAZANÇ
`/hesap-silme` siteden hiçbir yere BAĞLI DEĞİLDİ (`account.deletion` referansı sıfır) — Google Play
şartı, mağaza başvurusunu bloke edebilirdi. Alt bilgiye eklendi. Ön bilgilendirme formu da yalnız
ödeme akışından erişilebiliyordu, o da eklendi.

## AÇIK BORÇLAR (bu turdan)
- **MOBİL YERLEŞİM TARAYICIDA ÖLÇÜLEMEDİ.** `resize_window` bu ortamda **no-op** (üç ajan bağımsız
  doğruladı: "Successfully resized" der, `innerWidth` 1920 kalır); iframe yolu da kendi
  `X-Frame-Options: DENY` + `frame-ancestors 'none'` başlıklarımıza takılıyor (ölçüm için güvenlik
  başlığı GEVŞETİLMEDİ). Elde deterministik kanıt var (CSSOM'dan `@media` kural sırası okundu) ama
  görsel prova YOK. Yol: kullanıcının telefonu (tünel) ya da DevTools cihaz araç çubuğu ELLE.
- **Mobilden pasifleştirme açık Sanctum oturumunu düşürmüyor** — `AuthController` yalnız YENİ girişte
  `status` bakıyor; web'den pasifleştirme düşürüyor, mobilden düşürmüyor. `ProfileChangeApplier` işi.
- **`kuryeler_ekrani.dart:191`** "yeni kurye hesabı yönetim panelinden açılır" diyor; artık "web hesap
  panelinizden" olmalı (metin `ui_isletme_ayarlar_test.dart:376`da kilitli — mobil ajanın işi).
- **`/iletisim` sol sütun 255px / form 666px** dengesizliği — BİLEREK dokunulmadı: sol sütun gerçek
  künye geldiği gün kendiliğinden dolacak, bugünkü hâl geçici.
- Kapsam dışı bırakılanlar: operatör hesabı AÇMA (koltuk kotası yok), web'den kurye parolası sıfırlama.
- Yalıtık test DB'leri duruyor: `sipario_test_hesap`, `sipario_test_ekip` (silinebilir).

## OTOMATİK COMMIT ZİNCİRİ ONARILDI (2026-08-06)
Kapı commit'e HİÇ ulaşamıyordu: pint 2sn + phpstan 3sn + `artisan test` **599sn** = 604sn, kanca
timeout'u **600sn** — zaman aşımı dört saniyeyle kaybediliyordu ve süre dalgalandığı için bazen
geçip bazen geçmiyordu. Yavaş/hızlı ayrımı yapıldı: kancada yalnız sır taraması · pint · phpstan ·
dart analyze kaldı (**~4sn**, commit+push artık her turda tamamlanıyor); tam suite'ler CI'da.
`api-ci.yml` zaten her push'ta koşuyordu (yerel koşum tekrardı, üstelik CI'daki daha güçlü);
mobilde `flutter test` TEK bekçiydi, o yüzden `saha-apk.yml`e `test` işi eklendi ve derleme ona
`needs: test` ile bağlandı — **test kırmızıysa APK üretilmez, telefona bozuk sürüm gitmez**.
**Onarım anında iki gizli kusur yakalandı** (bozuk kapının kaçırdıkları): pint ihlali
`SiteGezinmeTest.php` · phpstan generic tipi `Hesap::$katalog`. İkisi de düzeltildi, CI yeşil.
⚠️ Betiği ELLE koşarken `< /dev/null` şart — stdin açık kalırsa sonsuza kadar asılır (gerekçe ve
denenip tutmayan iki zaman aşımı yolu betiğin başında yazılı).

## TESTLE KİLİTLENEN KARARLAR (sessizce geri kaymasınlar diye)
`SiteGezinmeTest` (10) · `SiteIcerikTest` (5, **mutasyonla kanıtlandı**: süzgeç devre dışı bırakılınca
tam olarak yakalaması gereken 2 regresyonu yakaladı) · `SiteHesapTest` (24) · `SiteEkipTest` (16).

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-05/3 · web UI — karışık içerik + @js tuzağı)

**Bir cümlede:** "Web tarafında büyük sorunlar var" şikâyetinin altından İKİ ayrı kök neden çıktı —
① `trustProxies` yokluğu: cloudflared tüneli arkasında tüm varlıklar `http://` üretiliyor, HTTPS
sayfada karışık içerik oluşuyor ve mobil Chrome CSS'i koşulsuz engelliyordu (site tünelden herkese
ÇIPLAK görünüyordu); ② `@js(dizi)` + csp_safe: Blade'in ürettiği `JSON.parse` ifadesini CSP
değerlendiricisi çözemiyor, x-data sessizce hiç kurulmuyordu — **/fiyatlar bu yüzden "Aylık"
seçiliyken YANLIŞ FİYAT (499 ₺, doğrusu 599 ₺) gösteriyordu**, /destek SSS'i ve panelin firma
arama kombosu ölüydü. İkisi de düzeltildi ve canlıda kanıtlandı; ayrıca tasarım farkları kapatıldı
(JetBrains Mono yerel woff2 · hero telefon animasyonu · çerez politikası + 4. yasal bağlantı ·
"Parolamı unuttum" etiket satırında · düğme alt çizgileri · 44px dokunma hedefleri).

**Ölçüm (şu an):** 7 site sayfası tarayıcıda DESENSİZ konsol taramasında sıfır hata · /fiyatlar
anahtarı canlı: Aylık→599 ₺ "Her ay", Yıllık→499 ₺ "Yılda bir kez 5.988 ₺" · /destek: boş sorguda
kart yok+11 satır, eşleşmesizde yalnız kart, akordeon çalışır · hero 3 kare döngüde, tek kare
görünür · panel firma-combo canlı (yaz→süz→seç→$wire.set) · panel modal dış tıklamayla kapanıyor ·
gerçek cihazda 7 sayfa tam stilli, gezinme https kalıyor · `view:cache` yeşil.

## BU TURDA KAPANANLAR
1. **Karışık içerik** → `bootstrap/app.php` `trustProxies(at: ['127.0.0.1','::1'])` — bilinçli dar
   ('*' hız sınırı IP anahtarlarını sahteletirdi). `URL::forceScheme` önerisi REDDEDİLDİ (yerel
   http'yi kırar). Gerekçe dosyada 17 satır yorum.
2. **@js(dizi)+csp_safe sessiz ölümü** → yük `application/json` kanalı/`data-*` ile taşınır,
   `Alpine.data` bileşeni `init()`te çözer (`jsonKanal`, kural alpine.js başlığında). Kurbanlar:
   `destek-sss` · `fiyat-planlar` (`donemAnahtar`) · panel `firma-combo`. `@js(dize/bool)` güvenli.
3. **Panel modal dış-tıklama** → `x-on:mousedown` içindeki `if` DEYİMİ CSP ayrıştırıcısında
   "Unexpected token: $refs" veriyordu → Alpine'ın `.self` değiştiricisine devredildi (tüm panel
   modallarını etkiliyordu; Escape zaten sağlamdı).
4. Tasarım farkları: mono fontlar (orijinal paketten çıkarıldı, dış indirme YOK) · `heroDongu`
   (kare/süreler TelefonCanli'den birebir) · `.dg text-decoration:none` · alt bilgi 44px hedefler ·
   çerez politikası taslağı · `[Telefon]` düz-cümle kullanımı koşullu (künyedekiler BİLEREK duruyor).
5. **"Oturumumu açık tut" DIŞARIDA** (bilinçli): `users.remember_token` migration'ı (senkronlu
   tablo!) + kalıcı-çerez güvenlik incelemesi ister — borçlara yazıldı.

## AÇIK KALANLAR (ajanlar 15:30'da limitten dönüyor)
- **360/320px canlı yerleşim turu** (mobil-denetci): kurallar deterministik + 412dp'de taşma sıfır
  ölçüldü, ama dar ekran canlı doğrulaması yapılmadı (lead'in emülasyon denemeleri kendi
  `frame-ancestors 'none'` başlığına ve popup engelleyiciye takıldı — bu yol ÇIKMAZ, tarayıcı
  emülasyonu gerekir).
- **Kullanıcının telefonundan son kabul** (tünel + sert yenileme).
- **Telefondaki Chrome'da ~11 trycloudflare sekmesi** kapatılacak — mobil-denetci'nin tek tek
  kapatma planı ONAYLI, kullanıcının görüşmesi bitince koşacak(tı); limit yüzünden yarım kaldı.
- Geçici not: combo testi için açılan `gecici-combo-test@sipario.local` admini SİLİNDİ (iz yok).

## SONRAKİ VARDİYAYA BORÇLAR
- "Oturumumu açık tut" (yukarıda) · pull-atlama boşluğu · anahtar rotasyonu · iade süresi
  çelişkisi · şirket künyesi+IBAN (kullanıcıda) · tünel A/B/C kararı · `destek@sipario.com.tr`
  kutusunun gerçekten canlı olup olmadığı.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-05/2 kapandı)

**Bir cümlede:** Kullanıcı önceki turun teşhisine güvenmeyip çürütme amaçlı bağımsız bir swarm
istedi ve HAKLI ÇIKTI — olayın en olası sebebi zehirli hap değil **o an WiFi'ın internet
vermemesiymiş** (cihaz radyo kayıtlarıyla); ama aynı swarm, kullanıcının "migrate edince uygulama
bozuluyor" hipotezini HATA SINIFI olarak doğrulayıp **üç sessiz veri silme + pull yönünde ikinci
bir zehirli hap** buldu ve kapattı; düzeltmeler gerçek cihazda (SM-S721B) senaryo senaryo kanıtlandı.

**Ölçüm (kapanış):** API **610/610** (3077) · mobil **958/958** · analyze **0** · phpstan **0** ·
pint temiz. Karar gerekçeleri DECISIONS.md sonunda (2 uzun satır). Cihazda **2250** kurulu
(bu turun TÜM düzeltmeleriyle).

## HÜKÜM — dünkü olayın sebebi
**KANITLANAMAZ**, ama sıralama değişti: ① taşıma zaman aşımı/yarı-açık bağlantı (cihaz kanıtı:
WiFi bağlıyken trafik mobil veriye düştü — WiFi internet vermiyordu) ② parti-422 zehirli hapı
(mekanizma gerçek, tetikleyici bulunamadı). Kullanıcının veri temizliği muhtemelen GEREKSİZDİ ama
bunu bilmesi imkânsızdı — eski bant her şeye "Çevrimdışı" diyordu. **Logcat bu sınıfı asla
veremez** (uygulama ağ hatası detayını KVKK gereği loglamaz) — orada iz aramak boşa vakittir.

## BU TURDA KAPANANLAR
1. **Üç sessiz veri silme (migration × eski istemci):** eski istemcinin push'u bilmediği yeni
   kolonları null'a çeviriyordu — IBAN+kurye yetkileri+sipariş kodu tercihi · kara liste · kurye
   telefonu. Çözüm: **anahtar YOK ≠ anahtar null** (`SyncPayload::gonderilenler`, testli).
2. **Pull zehirli hapı:** delta'daki tek bozuk satır cursor'u kilitleyip senkronu KALICI
   öldürüyordu → satır bazında izolasyon, cursor ilerler, tur görünür `veri` hatası yayınlar.
3. **Zaman aşımı yolu testle kilitli** (karantina/bisect tetiklemez; bisect ortasında teslim
   edilen yarı korunur) + `batchSize` 500→400 payı.
4. **Ana ekran çipi dürüstleşti** (bant "sunucu" derken çip "bağlantı yok" diyordu — cihaz
   testinin yakaladığı tutarsızlık).
5. **Cihaz kanıtları:** locked ertelemesi (`tenant_sync_state.updated_at` kalp atışı yöntemiyle) ·
   içerik bütünlüğü · dürüst bant+adres satırı (ekran görüntülü). Test siparişleri 115/116 demo
   bayide bilerek bırakıldı.

## SONRAKİ VARDİYAYA BORÇLAR
- **Pull-atlama boşluğu (bilinçli):** bir daha hiç dokunulmayan varlığın kaçan güncellemesi geri
  gelmez; kapağı = atlanan en erken seq'i `sync_meta`ya yazıp sürüm değişiminde cursor'u geri
  sarmak (şema sürümü işi). Gerekçe `sync_engine.dart` "SÜRÜM ÇARPIKLIĞI KAPISI" bloğunda.
- Saha anahtarının şifresi bu oturumun transkriptine düştü (yerel dosyada zaten düz metindi) —
  mağaza başvurusu öncesi zaten planlı olan anahtar rotasyonunda bu da temizlenir.
- Uygulama hangi ağ arayüzünden çıktığını kaydetmiyor — cihaz kaydediyor ve bu olayda belirleyici
  kanıt oradan geldi; küçük bir teşhis alanı olarak değerlendirilebilir.
- Önceki devir notunun bekleyenleri duruyor: iade süresi çelişkisi · şirket künyesi+IBAN ·
  tünel A/B/C · tarayıcı smoke turu.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-05 kapandı)

**Bir cümlede:** Sahadan gelen "giriş yapıyorum ama üstte Çevrimdışı yazıyor" şikâyeti kovalandı
ve altından **dört ayrı zehirli hap** çıktı — her biri senkronu KALICI olarak kilitliyor ve tek
"çözüm" uygulama verisini silmek oluyordu, ki bu **bekleyen sipariş/tahsilatı yok eder**
(kırmızı çizgi #3 ihlali). Ayrıca gecenin kendisi bir bulgu üretti: **kalite kapısı kendi kendini
zehirliyordu.**

**Ölçüm (kapanış):** API **601/601** (3033 doğrulama) · mobil **942/942** · `dart analyze` **0** ·
phpstan L6 **0** · pint temiz. Karar gerekçeleri DECISIONS.md sonunda (3 satır).

## KAPANAN DÖRT ZEHİRLİ HAP

| # | Yol | Nasıl kilitliyordu |
|---|---|---|
| 1 | Parti düzeyinde **422** | Tek bozuk olay tüm kuyruğu rehin alıyordu. `SyncPushRequest`in kendi belge başlığı "tüm partiyi düşürmez" diye SÖZ VERİYORDU, kuralları yapmıyordu. |
| 2 | `locked` → `acked` | Abonelik kilitliyken yazılan sipariş/tahsilat **sessizce siliniyordu**, yenilense bile bir daha gönderilmiyordu (kırmızı çizgi #5). |
| 3 | Bilinmeyen durum → `acked` | Sunucu yeni bir `status` eklediği gün eski istemciler kaydı silecekti. |
| 4 | `22001`/`22003` → **500** | Uzun bir müşteri adı senkronu kalıcı kilitliyordu. 4xx'ten DAHA kötü: istemci 5xx'i geçici sayıp sonsuza dek dener, bisect de karantina da devreye girmez. |

**Ortak kök desen:** tanımadığını "başarılı" sayıp silmek · anlamadığını "geçici" sayıp sonsuza
dek denemek.

## ⚠️ GECENİN EN PAHALI DERSİ — KALİTE KAPISI SUITE'İ KOŞUYOR

`.claude/settings.json` → **`Stop` hook** → `scripts/quality-gate-commit.ps1` içinde
`php artisan test` (~10 dk) **ve** `flutter test` var. Kanca **her ajanın her turu bittiğinde**
ateşlenir. Çok ajanlı vardiyada makinede sürekli, kendiliğinden, **eşzamanlı tam suite** koşar;
iki `migrate:fresh` birbirinin şemasını düşürür ve suite **~130 SAHTE kırık** verir.

**Kanıt (aynı ağaç, dört koşu):** 433/600 · 387/600 · 504/600 *(kanca serbest)* → **601/601**
*(kanca kilitli)*. Her seferinde **farklı** testler kırılıyordu.

Bu, dört ajanın ve lead'in **~3 saatini** yedi ve üç yanlış teşhis doğurdu: "başka ajan koşuyor"
· "kendi phpunit çocuğunu görüyorsun" · lead'in **imkânsız** "zaman aşımını 900000 ver" talimatı
(Bash aracı 600000'de tavanlıyor). **Kimse kancadan şüphelenmedi çünkü commit mesajları
"kalite kapisi yesil" diyordu** — kendi başarısını raporlayan araç şüphe listesinden düşüyor.

**Kapatıldı (iki katman):** adlandırılmış mutex + kancanın `artisan test|phpunit` süreci araması.
Mutex tek başına YETMEZ: yalnız kancayı kancadan korur, ajanın elle koşumundan korumaz.

**Sahte kırığı gerçekten ayırt etme kuralı:** koşuyu tekrarla, kırılan test **İSİMLERİNİ**
karşılaştır. Deterministik regresyon her koşuda AYNI testleri kırar; farklı isimler + aynı sayı
= ORTAM. Ve `Get-Process php`e **tek bir ana** bakmak yetmez — koşu BOYUNCA örnekle.

## SIRADAKİ — CİHAZ DOĞRULAMASI (yapılmadı)

Kablosuz adb kuruldu: **SM-S721B**, `com.sipario.app`, `adb mdns services` ile bulunuyor.
⚠️ **Telefondaki build 2221 bu düzeltmelerin HİÇBİRİNİ taşımıyor** — yeni yapım gerekiyor.

Cihazda sınanacaklar:
1. Eski kuyrukta bozuk olay varken **aynı parti tekrar tekrar gitmemeli**; masum kayıtlar ilk
   turda gitmeli, yalnız bozuk olan geride kalmalı; ~6 dk sonra `outbox.status='rejected'`.
2. Bant "Çevrimdışı" DEĞİL, "Sunucu kayıtları kabul etmiyor" demeli — ve **altında sunucu
   adresi** yazmalı.
3. **`locked` senaryosu (en sinsi olan):** aboneliği kilitle → çevrimdışı sipariş yaz → senkron
   → `outbox` satırı `pending`, `attempts=0` kalmalı (ESKİ kodda satır KAYBOLURDU). Aboneliği
   yenile → aynı olay gitmeli.

## SUNUCU DÜZELTMESİ SAHADAKİ TELEFONU KURTARIR
Yanıta yalnız alan EKLENDİ (`reason`, `index`); hiçbiri kaldırılmadı. Eski istemci `rejected`
yolunu bugünkü gibi işler — yani **kilitlenmiş bir cihaz uygulama güncellemesi olmadan** akmaya
başlar. Mobil düzeltme istemcinin kendi dayanıklılığıdır, kurtarma sunucudan gelir.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-04/2 kapandı)

**Bir cümlede:** `design_handoff_web_and_yonetim_paneli/` altındaki iki tasarım paketi sisteme
alındı — **yönetim paneli SIFIRDAN yazıldı** ve **sipario.com.tr sitesi baştan kuruldu**
(pazarlama sayfaları + kayıt/giriş/parola + **IBAN ödeme akışı** + **bayinin hesap paneli**);
9 ajanlı swarm ile yürüdü.

**Ölçüm (kapanış):** `php artisan test` **593/593** (2966 doğrulama) · phpstan L6 **0** ·
pint temiz · Blade derlemesi temiz · 12 yeni migration — **üretim/dev DB'de koşulmalı**.
Mobil tarafa HİÇ DOKUNULMADI. Karar gerekçeleri DECISIONS.md sonunda (8 satır).

## ⚠️ ÖNCE BUNU OKU — TAM SUITE'İ **ARKA PLANDA** KOŞ

**Suite ~575–600 sn sürüyor. Bash aracının AZAMİ zaman aşımı 600000 ms (10 dk).**
Yani suite tavanın bir tık altında koşuyor ve **ön planda koşmak yazı-turadır**: 575 sn'de
sığar, 599 sn'de sığmaz. Sığmadığında koşu **arka plana düşer ama ÖLMEZ**; yeniden denersen
ikinci bir tam koşu başlar, iki `migrate:fresh` çakışır ve suite ~130 **sahte** kırık verir
(`relation "admin_users" does not exist`, "beklenen 200 gelen 401", "kayıt bulunamadı").

**DOĞRU YOL — Bash aracını `run_in_background: true` ile kullan:**
```
php artisan test > /tmp/sipario-suite.log 2>&1; echo "EXIT=$?"; tail -20 /tmp/sipario-suite.log
```
Zaman aşımına hiç takılmaz, bitince bildirim gelir.

**Sahte kırığı gerçek regresyondan ayırt etme kuralı:** koşuyu tekrarla ve kırılan test
İSİMLERİNİ karşılaştır. Deterministik bir regresyon her koşuda **AYNI** testleri kırar.
Farklı isimler (özellikle dokunmadığın modüller: `SyncTest`, `AuthFlowTest`, `GeocodeTest`)
+ aynı sayı = **ORTAM**, kod değil. Bu ayrım bu vardiyada bir güvenlik iyileştirmesinin
haksız yere geri alınmasını önledi.

**Koşmadan önce `Get-Process php` BOŞ olmalı.** Bir koşu = **2** `php.exe`
(`artisan test` + onun `phpunit` çocuğu — `collision/TestCommand.php:162`). **4 görürsen iki
koşu var demektir: BEKLE, ÖLDÜRME.**

_Bu, PLAN'daki eski "paralel artisan test → bağlantı tavanı" tuzağının GERÇEK mekanizmasıdır
ve bugüne kadar yanlış kaydedilmişti. Bu vardiyada üç ayrı teşhis yapıldı, ikisi yanlıştı:
"başka bir ajan koşuyor" (yanlış), "kendi phpunit çocuğunu iki koşu sanıyorsun" (kısmen doğru
ama eksik). Lead ayrıca "zaman aşımını 900000 ver" diye **imkânsız** bir talimat verdi — araç
600000'de tavanlıyor. Kaybedilen süre: ~2 saat._

## Bu vardiyada NE YAPILDI

**Tasarım paketleri açıldı.** İki `.html` dosyası paketlenmiş React uygulamasıydı (1,7 MB blob);
26 kaynak modül + 71 KB CSS çıkarılıp `design_handoff_web_and_yonetim_paneli/_kaynak/` altına
kondu (`OKU-BENI.md` çelişki tablosunu ve taşınmayacakları anlatıyor).

**Stack: Blade + Livewire 3 + Alpine, React DEĞİL.** Gerekçe DECISIONS'ta. CSS birebir taşındı,
sınıf adları sözleşme; fontlar paketten çıkarılıp yerelleştirildi (Google Fonts'a çıkılmıyor).

**Yönetim paneli (sıfırdan):** Giriş · Dashboard · Üyeler · Üye Detayı · Ödemeler · Paketler ·
Gelir-Gider · **Havale Bildirimleri** (tasarımda yok, eklendi) · Denetim · Hesaplar.
Tasarımda olmayan ama BRIEF'in zorunlu kıldığı her şey korundu ve yeni dile taşındı: iş verisi
sekmeleri, CSV içe/dışa aktarma + JSON dump, modül aç/kapa, patron parola sıfırlama, cihaz
listesi, churn/kullanım grafikleri (saf SVG), **kurye hesabı açma** (bugüne kadar hiç yoktu).

**Site (baştan):** ana · özellikler · fiyatlar · destek · iletişim · yasal · giriş · 3 adımlı
işletme açma · parola sıfırlama+yenileme · ödeme akışı · hesap paneli (6 bölüm).

**Veri katmanı:** 12 migration (`plans` · `addon_packages` · `addon_grants` · `expenses` ·
`tenant_notes` · `payment_notifications` + alterler + GRANT/RLS), 6 model, `app/Abonelik/`
altında 8 servis, `TenantStatus::Cancelled`.

## BULUNAN GERÇEK ARIZALAR (hiçbiri çökmüyordu, hiçbiri günlüğe yazmıyordu)

| Arıza | Etkisi |
|---|---|
| `auth:web` + `users` RLS FORCE | Bayinin hesap paneli **hiç çalışamazdı** (500) |
| Livewire kalıcı middleware eksik | Panel açılır, **hiçbir düğme çalışmazdı** (`/livewire/update` route middleware'ini yeniden koşmaz) |
| `TenantList` `ESCAPE '\'` | Aramaya **tek harf** yazınca 500 (PDO ters bölüyü kaçış sanıp `?`leri yutuyor) |
| `lower()` Türkçe harmanlamada | `lower('I')`='ı', `lower('İ')`='i' → `"izmir"` araması `İZMİR`'i **bulamıyordu** |
| Firma aramasında joker kaçışı yok | `%` yazan kullanıcı **tüm bayileri** getiriyordu |
| `app.timezone` UTC ↔ +03:00 | **Sekiz ekran** yanlış saat/gün basıyordu ("Kilit anı" dahil) |
| Üç modalda UTC varsayılan tarih | Ayın ilk gecesinde tahsilat **yanlış dönemi** kapatıyordu |
| Pano başlığı UTC | Gece 00:00–03:00 arası **bir önceki günü** yazıyordu |
| `EkPaketServisi` idempotens yok | Paralel istek kotayı **iki kez** artırıyordu — append-only, **geri alınamaz** |
| `cancelled` bayi kilidi | İptal eden bayi **yazmaya devam edebiliyordu** (`resolveLock` sabit listeydi) |
| `activate()` tabanı `now()` | Erken yenileyen bayi **kalan günlerini kaybediyordu** |
| Firma kodu çakışması | **Sessizce yutuluyordu**, bayi kodunu alamadığını bilmiyordu |
| `CannotUpdateLockedPropertyException` namespace'i | Kırmızı çizgi #1'i koruyan **iki test hiç koşmuyordu** ("Class does not exist") |
| `site.hesap` izolasyon testi yok | `RouteCoverageGuardTest` build'i kırdı — **kural PLAN'da yazılıydı, lead yine de düştü** |

## Bu vardiyada NE YAPILMADI / SIRADAKİ

- **12 migration üretim/dev DB'de KOŞULMADI** (yalnız test DB'sinde). Önceki turdan bekleyenler
  de olabilir.
- **Hiçbir ekran gerçek tarayıcıda görülmedi.** Testler headless; bir smoke turu şart.
  **CSP sıkılaştırması bu boşluğu kritik kılıyor:** `csp_safe` açık ve Alpine artık HTML
  içindeki ifadelerde globallere izin vermiyor; kaçan bir ifade **sessizce** ölür (konsola
  düşer, düğme hiçbir şey yapmaz). Tarayıcıda mutlaka denenecekler:
  (a) panelde **"Ödeme Ekle" modalında firma kombosu** seçim yapıyor mu,
  (b) sitede **IBAN ve firma kodu "Kopyala"** düğmeleri gerçekten kopyalıyor mu,
  (c) **iletişim formu** `mailto:` açıyor mu, (d) **Destek SSS araması** süzüyor mu,
  (e) panel ve site **toast**'ları görünüyor mu, (f) üst menü mobilde açılıp kapanıyor mu.
  Alpine ifadeleri Node'da gerçek CSP değerlendiricisiyle sınandı (eski hâlin kırıldığı da
  kanıtlandı) ama DOM/reaktivite katmanı ölçülemedi.
- **Mobil tarafa dokunulmadı** — `flutter test` bu vardiyada hiç koşulmadı.
- **Site canlıya çıkamaz** (aşağıdaki insan kararları olmadan).

## İNSAN KARARI BEKLEYEN — YAYINA ENGEL

1. **🔴 İADE SÜRESİ ÇELİŞKİSİ:** site "14 gün koşulsuz iade, sebep sormuyoruz" diyor;
   `legal/docs/iptal-iade.blade.php` "m.15/1-ğ uyarınca cayma hakkı KULLANILAMAYABİLİR, avukat
   onayı bekleniyor" diyor. **İkisi aynı anda yayında olamaz** — biri yanlış beyandır.
2. **🔴 ŞİRKET KÜNYESİ:** unvan · adres · MERSİS · vergi dairesi · **IBAN** · banka · telefon.
   Hepsi `config/subscription.php` → `company` bloğunda `[köşeli parantez]` yer tutucu.
   Verildiğinde ödeme ekranı + footer + mesafeli satış sözleşmesi TEK noktadan dolar.
   ⚠️ `tenants.iban` BAYİNİN kendi tahsilat hesabıdır — abonelik tahsilatında KULLANILAMAZ.
3. **`destek@sipario.com.tr` gerçekten açık mı?** Config varsayılanı o olduğu için iletişim
   formunun "Gönder" düğmesi CANLI. Açık değilse `COMPANY_SUPPORT_EMAIL="[destek e-postası]"`
   yeter — düğme kendiliğinden pasifleşir.
4. **Temsili veri:** `site/parca/_temsili-veri.php` — "1.240 işletme", "%31 daha az kayıp", üç
   müşteri yorumu, "%90'ı bunu seçiyor". Diziyi boşaltmak bölümleri düzen bozmadan düşürür.
5. **Kurumsal "1.499 ₺'den başlar"** — sunucuda karşılığı yok, doğrulanamaz fiyat vaadi.
6. **"Kullanım koşulları" belgesi yok** — kayıt onayında tasarım onu sayıyordu; `legal_docs`ta
   slug olmadığı için "ön bilgilendirme formu" yazıldı.

## TÜNEL — karar bekliyor (A/B/C)
Cloudflare quick tunnel her açılışta YENİ adres üretiyor; uygulama adresi yalnız GİRİŞTE
kaydediyor → sunucu her açıldığında telefona **elle** adres girmek gerekiyor.
**A)** Adlandırılmış tünel (`api.sipario.com.tr` zaten uygulamanın varsayılanı) — kökten çözer.
**B)** Script adresi `saha` sürümüne yayınlasın, uygulama `onbelleksizAdres()` ile çeksin
(mekanizma ZATEN YAZILI).
**C)** Küçük yamalar: çekmeceye "Sunucu adresi" alanı (bugün değiştirmek için ÇIKIŞ gerekiyor) ·
çevrimdışı bandı hangi adrese ulaşamadığını yazsın · script adresi dosyaya yazıp QR bassın.
_C, hangisi seçilirse seçilsin değerli: bugünkü arıza tam olarak "uygulama gerçek sebebi
söylemiyor"du._

## BİLİNEN TUZAKLAR (bu vardiyada öğrenilenler)

1. 🔴 **Tam suite'i ARKA PLANDA koş.** Yukarıdaki ilk bölüm — süre tavana bir tık altında,
   ön planda koşmak yazı-turadır ve kaybedince ~130 sahte kırık üretir.
2. **Yeni tenant-scope route = İKİ zorunlu adım** (`RouteCoverageGuardTest` listesi +
   `TenantIsolationTest` senaryosu). Kural eskiden beri yazılıydı, bu vardiyada LEAD ihlal etti.
3. **İkinci kopya sessizce ayrışır.** Gün sınırı sekiz ekranda, arama katlaması iki dosyada
   ayrışmıştı. Tek kaynaklar: `Bicim` (tarih/saat/gün) ve `App\Support\TurkceArama` (arama).
   Yeni bir tarih/arama kodu yazmadan önce bunlara bak.
4. **Route'u sınıftan ÖNCE açma.** `RouteAction::makeInvokable` patlar ve bu yalnız o ekranı
   değil, uygulamayı önyükleyen HER kalite kapısını (phpstan dahil) kırar.
5. **Import'u ÖNCE ekle.** Bu vardiyada iki ajan bir dosyayı bölerken/çağrı değiştirirken
   kesildi ve `use` satırı eksik kaldığı için ağacı kırmızı bıraktı.
6. **`grep` sayısı doğrulama değildir.** Lead `tanimla()`nın idempotens parametresi aldığını
   grep eşleşmesiyle "doğruladı"; eşleşme yerel bir değişkendendi ve iş yapılmamıştı.
7. **Livewire yetki kapısı bileşenin İÇİNDE** (route middleware `/livewire/update`i korumaz) —
   ve tersi de doğru: **route middleware Livewire'a ULAŞMAZ**, kalıcı listeye eklenmesi gerekir.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-04 kapandı)

**Bir cümlede:** Altı saha isteği kapatıldı — kurye yönetimi ciddi biçimde büyüdü (giriş
bilgileri düzenlenebilir + 5 anahtarlı yetki sistemi), borçluya tek tuşla WhatsApp/IBAN
hatırlatması geldi, teslim sekmesine gün gezinmesi eklendi, sipariş kaydı artık siparişler
ekranına dönüyor; ayrıca **saha sunucusunun HTTP 530 arızası** teşhis edilip kalıcı olarak
düzeltildi.

**Ölçüm (kapanış):** `php artisan test` **433/433** (2266 doğrulama, +12) · `flutter test`
**906/906** (+21) · `dart analyze` **0** · phpstan L6 **0** · pint temiz · migration 2 yeni
(`iban`, `courier_permissions`) — **üretim/dev DB'de koşulmalı**.
Karar gerekçeleri DECISIONS.md sonunda (6 satır).

## Bu vardiyada NE YAPILDI

1. **SAHA SUNUCUSU HTTP 530 — kök neden bulundu ve kapatıldı.** `SUNUCU-BASLAT`'ın verdiği
   adres 530 (Cloudflare Error 1033) veriyordu. Yerel taraf sağlamdı; cloudflared varsayılan
   **QUIC (UDP 7844)** ile bağlanamıyordu. Sinsi olan: **adres YİNE DE üretiliyor** (adres
   Cloudflare API'sinden gelir, port 443) — script "hazır" deyip yeşil yanıyor, bayi adrese
   giriyor ve arkasında tünel olmadığı için 530 görüyordu. Ölçüldü: aynı makinede varsayılan
   protokol FAIL, `--protocol http2` → `Registered tunnel connection`, giriş isteği 200.
   `saha-sunucu.ps1` artık adresi DOĞRULUYOR ve doğrulanamazsa http2 ile YENİDEN deniyor
   (eski "yine de dene" uyarısı kaldırıldı).
2. **Kurye giriş bilgileri** (`PATCH /team/{user}/credentials`) — Kuryeler ekranındaki forma
   "Giriş Bilgileri" bölümü. Senkron yolundan AYRI ve çevrimiçi; yalnız patron, yalnız
   kurye/operatör hedefi. Parola değişince hedefin tüm oturumları düşer, kullanıcı adı
   değişimi oturumu düşürmez. `team` bloğuna `username` eklendi (parola hiçbir yönde okunmaz).
3. **Kurye yetkileri — 5 on/off anahtar** (Kuryeler ekranının üstünde): müşteri düzenleme ·
   sipariş açma · tahsilat (açık doğar) · gün sonu · kapıda iskonto (kapalı doğar). Kiracı
   düzeyinde, yalnız kurye rolünü etkiler. Anahtarlar çağrı yerlerine BAĞLANDI (FAB menüsü,
   çağrı kartı, müşteri listesi, teslim sheet'i).
4. **Borçlulara WhatsApp hatırlatması** — kartta "Hatırlat" düğmesi; IBAN Ayarlar → İşletme
   Profili → Tahsilat bölümünde (mod-97 denetimli). Mesaj HAZIRLANIR, gönderilmez.
5. **Teslim sekmesine gün gezinmesi** — "‹ Bugün · 4 Ağustos ›"; etikete dokunmak bugüne döner.
   Yalnız Teslim sekmesinde (gerekçe DECISIONS'ta).
6. **Sipariş kaydı sonrası yönlendirme** — form kapanınca siparişler sekmesine gidilir ve
   üstteki push'lar kapanır (müşteri kartından girilen sipariş artık "kaybolmuyor").
7. **Müşteri kodu doğrulandı** (kod değişikliği YOK) — sunucu atıyor, snapshot+delta ile
   telefona düşüyor, SiraKoduTest 7/7 yeşil.

## Bu vardiyada NE YAPILMADI / SIRADAKİ

- **Landing page** — önceki devir notunun "sıradaki iş"i; bu vardiyada da başlanmadı
  (saha istekleri öne alındı). Hâlâ sıradaki en büyük açık iş.
- **Migration koşulmalı**: `2026_08_04_004001_add_tenant_iban` +
  `2026_08_04_004002_add_courier_permissions` (yerelde koşuldu, üretim/dev'de bekliyor).
  Ayrıca önceki turdan `2026_08_01_003001_add_admin_user_disabled_at` hâlâ bekliyor olabilir.
- **Cihazda denenmedi** — bu vardiyanın hiçbir maddesi gerçek telefonda görülmedi.
  Saha kontrol listesi: (a) Kuryeler ekranında yetki anahtarları + giriş bilgileri formu,
  (b) borçlu kartında "Hatırlat" → WhatsApp hazır metinle açılıyor mu, (c) Teslim sekmesinde
  gün okları, (d) müşteri kartından sipariş girince siparişler ekranına dönüyor mu.
- **Kurye yetkilerinin widget testi yok** — saf karar matrisi testli (`kurye_yetkileri_test.dart`)
  ama "anahtar kapalıyken FAB menüsünde satır çizilmiyor" gibi ekran davranışları sınanmadı.

## Sonraki kişi NEREDEN devam etmeli

1. **Migration'ları koş** (aşağıdaki tuzak #1) — yoksa IBAN ve kurye yetkileri sunucuda YOK ve
   senkron partisi hata verir.
2. **Cihazda doğrula** — yukarıdaki dört maddelik saha listesi.
3. **Landing page** — iki vardiyadır sıradaki iş olarak duruyor, hiç başlanmadı.
4. Kod tarafında kalan en değerli iş hâlâ **mobil CI** (mobil testler yalnız geliştirici
   makinesinde koşuyor).

## BİLİNEN TUZAKLAR (bu vardiyada öğrenilenler + duranlar)

1. 🔴 **İki yeni migration koşulmadı** (`add_tenant_iban`, `add_courier_permissions`). Bu
   vardiyanın kodu o kolonları YAZIYOR: kolonlar yoksa `tenant_settings` push'u reddedilir ve
   bayi "işletme profili kaydedilmiyor" der. Yerelde koşuldu, üretim/dev'de bekliyor.
2. **Cloudflared QUIC tuzağı (yeni öğrenildi):** tünel adresi üretilmesi tünelin KURULDUĞU
   anlamına GELMEZ — adres Cloudflare API'sinden gelir (443), tünel 7844'ten. UDP 7844 engelli
   bir ağda adres alınır, bayi HTTP 530 görür. Script artık doğruluyor ve http2'ye düşüyor;
   ama **elle `cloudflared tunnel --url` çalıştıran biri aynı tuzağa düşer** — `--protocol http2`
   eklemeli. Teşhis: `%TEMP%\sipario-tunel.log` içinde "Registered tunnel connection" var mı.
3. **`teamPayload` PII sözleşmesi katı testli:** `SyncTeamTest` team bloğundaki anahtar kümesini
   TAM eşitlikle kontrol eder. Yeni bir kolon eklerseniz test kırılır — bu kasıtlıdır, testi
   düzeltmeden önce "bu alan gerçekten telefona inmeli mi" diye sorun.
4. **Yeni tenant-scope route = iki zorunlu adım:** `RouteCoverageGuardTest`'in listesine EKLE +
   `TenantIsolationTest`'e cross-tenant senaryosu YAZ. Bu vardiyada `/team/{user}/credentials`
   eklenince ikisi de kırmızı yandı (doğru davranış).
5. **`TenantSettingsRepository.save` satırın TAMAMINI yazar (LWW upsert).** Yalnız bir alanı
   değiştiren her yeni ekran, geri kalan alanları MEVCUT değerinden taşımak zorunda — yoksa
   bayi bir anahtara dokununca IBAN'ı/vergi no'su boşalır. Bu vardiyada iki yardımcı bu yüzden
   var: `siparisKoduTercihiKaydet` ve `kuryeIzinleriKaydet`.
6. **Drift `withDefault` kolon = data class'ta ZORUNLU alan.** `users.username` eklenince
   `isletme_kurallari_test.dart` derlenmedi (3 `User(...)` çağrısı). Yeni kolon eklerken
   `dart analyze test/` de koşulmalı — `dart analyze lib` bunu görmez.
7. **Gün sınırı TEK yerde:** `ayniTrGun` / `bugunTr` (sabit +03:00, `gun_sonu_ozet.dart`).
   Sipariş listesinin gün süzgeci bilerek SQL'de değil Dart'ta koşuyor; ikinci bir gün-sınırı
   kopyası, gün sonu ekranıyla sipariş listesinin farklı sayı göstermesi demektir.
8. **Demo giriş `111/111/1111` hâlâ geçici** ve mağaza başvurusundan önce geri alınmalı
   (önceki vardiyalardan devreden borç, "İnsan gerektiren işler" listesinde).

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-08-01 kapandı)

**Bir cümlede:** Yönetim paneli "abonelik açma/kapama aracı"ndan **tam teşekküllü iç yönetim
ürününe** büyüdü (5c-3) — kullanıcı kararıyla BRIEF'in "panel iş verisine dokunamaz" sınırı
gevşetildi: panel artık bayinin verisini GÖRÜR (müşteri/sipariş/defter/ürün, salt-okunur),
müşteri+ürün GİRER/DÜZENLER ve müşteri CSV toplu aktarır; **sipariş+para kayıtları panelden
salt-okunur kaldı** (kırmızı çizgi 2). Dört ajanlık swarm ile yürüdü (araştırma→kod→test→güvenlik).

**Ölçüm (kapanış):** `php artisan test` **421/421, 2213 doğrulama** · phpstan L6 **0** · pint
temiz · çalışma ağacı temiz. Mobil DOKUNULMADI (panel tamamen sunucu tarafı). Ayrıntılı karar
gerekçeleri DECISIONS.md sonunda (2026-08-01 blokları — 7 satır).

## Bu vardiyada NE YAPILDI (özet)
1. **Genel Bakış panosu** (`/panel`): aktif/deneme/kilitli dağılımı, ≤7 gün kalan denemeler,
   3 gündür sipariş girmeyen bayiler (churn), 60 günlük yenileme takvimi (saf SVG, JS kütüphanesi yok).
   Bayi listesi `/panel/bayiler`e taşındı.
2. **Bayi detayı 6 sekme:** Özet · Müşteriler (arama+sayfalama+bakiye) · Siparişler · Defter ·
   Ürünler · Denetim.
3. **Panelden YAZMA (yalnız müşteri+ürün):** mobilin AYNI sync yolundan (`SyncService::push` →
   `ChangeApplier`, RLS'li `pgsql` bağlantısı, sabit `PANEL_DEVICE_ID`) — cihaza düştüğü testli.
   Abonelik kilidi paneli de bağlar. 'stale' kullanıcıya başarısızlık olarak görünür. Düzenleme
   upsert DEĞİLDİR (bulunamayan id = hata). Müşteri pasifleştirme = kara liste (`blacklisted_at`).
4. **CSV:** müşteri içe aktarma (şablon→önizleme→onay, telefon dedup, TR Excel toleransı: `;`,
   BOM, Windows-1254) + müşteri/sipariş dışa aktarma (formül enjeksiyon kaçışlı, export'lar
   artık panel_audit'e düşer).
5. **Hesap yönetimi:** `superadmin`/`support` rolleri (kapı her Livewire eyleminin İÇİNDE),
   `disabled_at` ile pasifleştirme (açık oturumu da düşürür), `php artisan panel:admin` komutu,
   genel denetim günlüğü ekranı.
6. **Testçi 2 üretim hatası buldu:** aramaya yapıştırılan 10 haneli telefon int4 taşırıp 500
   veriyordu; çevrilmiş CSV başlığı veri sanılıyordu. +33 test. Form `max:` tavanları artık
   şemayla otomatik karşılaştırılıyor (22001 sınıfı kapandı).
7. **Güvenlik incelemesi 4 açık kapattı:** panel girişine kaba kuvvet sınırı (bileşen İÇİNDE —
   route throttle Livewire'ı korumaz), export'lara KVKK denetim izi, `SecurityHeaders` web
   grubuna, `$tenantId`'ye `#[Locked]`.

## Bu vardiyada NE YAPILMADI / SIRADAKİ
- **Landing page** — kullanıcının açıkça istediği SIRADAKİ iş; hiç başlanmadı.
- Üretim/dev DB'de yeni migration koşulmalı (`2026_08_01_003001_add_admin_user_disabled_at`)
  ve ilk admin `php artisan panel:admin` ile açılmalı (panel hesabı seed EDİLMEZ).
- Panel gerçek tarayıcıda gözle görülmedi (testler headless) — 5 dakikalık smoke turu iyi olur.
- Küçük raporlanan-ama-dokunulmayan pürüzler reviewer raporunda: bozuk UUID'de 500 (404 olmalı),
  `UrunForm::$fiyat` üst sınırsız, `Csv::indirme` dosya adı sanitizasyonu (bugün yalnız UUID),
  reddedilen yazma denemeleri denetime düşmüyor.

---

# (ÖNCEKİ) VARDİYA DEVİR NOTU (2026-07-29 kapandı)

**Bir cümlede:** Bayiden gelen 12 istek/şikâyetin tamamı kapatıldı; ama vardiyanın asıl değeri
**dört SESSİZ arızayı** bulmasıydı — hiçbiri çökmüyor, hiçbiri günlüğe yazmıyor, yalnız *hiçbir şey
olmuyordu*: (1) CDN yayından saatler sonra bile eski `surum.json`u veriyordu, yani **güncelleme
bandı hiç düşmüyordu**; (2) migration'la atanan kodlar senkron **deltasına düşmediği için telefona
hiç ulaşmıyordu**; (3) kalite kapısının API bölümü php PATH'te olmadığı için **aylardır sessizce
atlanıyordu** ("yeşil" diyordu, pint/phpstan/testler hiç koşmamıştı); (4) sihirbazın "pil" adımı
**otomatik başlatma** ekranını açıyor, pil kısıtlaması hiç kaldırılmıyordu.

**Ölçüm (kapanış):** `dart analyze` **0** · `flutter test` **740/740** · `php artisan test`
**247/247** · phpstan L6 **0** · pint temiz · Kotlin derlemesi başarılı.
**CİHAZDA DENENMEDİ** — saha kontrol listesi aşağıda.

## Bu vardiyada NE YAPILDI

**Ürün (bayi istekleri):**
1. **Borç görünürlüğü** — "Borçlu" sekmesinde satır siparişin TUTARINI yazıyordu, borcunu değil
   (veresiye teslimde ikisi aynı olduğu için kimse fark etmemişti; kısmi ödemede ayrışıyor).
   Satıra kalan borç pili, detaya borç kutusu, "Tahsilat Al · 250,00 ₺" eklendi.
2. **Borçlular ekranı** — ana ekrandaki "Açık Veresiye" kutusu "Borçlular" oldu ve müşteriler
   sekmesi yerine kendi ekranını açıyor: borçlu müşteriler + her birinin ödenmemiş siparişleri.
3. **FAB iki seçenek** — "Müşteri Ekle" · "Sipariş Ekle".
4. **Sıra kodları** — müşteri kodu (100, 101…) ve sipariş kodu (#248). **Sunucu atar**, istemci
   üretmez; sipariş satırında hangisinin görüneceği bayi ayarı (`tenant_settings`).
5. **Açık siparişte "Açık" yerine bekleme süresi** ("12 dk" · "1 sa 5 dk" · "2 gün").
6. **Gün sonu yeniden yapılandırıldı** — eksen KAPSAM değil GÜN: geçmiş günler listesi
   (`28.07 Salı · 2.100 ₺ · 18 teslimat`, kapatılmamış gün de listede), gün detayında kasa +
   kurye kartları + **satılan ürün dökümü** + kapanış kayıtları. İstatistik arayüzü bunun üstüne oturur.
7. **Aşağı çekerek yenile** (10 ekran) + ana ekranda güncelleme kontrolü ve "Sürüm güncel" çipi.
8. **Selam dört kuşak** (Günaydın / Kolay gelsin / İyi akşamlar / İyi geceler).
9. **Bento kutuları ortalandı.**
10. **Müşteri DÜZENLEMEDE de "Konum Al"** (önceden yalnız yeni kayıtta vardı).
11. **Sipariş detayına "Konum Güncelle"** — cihazın anlık konumunu teslimat adresine yazar.
12. **Demo giriş `111/111/1111`** (geçici — aşağıda borç olarak duruyor).

**Altyapı (bulunan arızalar):**
- **CDN bayat cevap** — `surum.json` düz adresten istendiğinde `X-Cache: HIT`, yayından 9 saat
  eski içerik. Artık hem `surum.json` hem APK **benzersiz sorgu parametresiyle** isteniyor.
- **Migration senkrona düşmüyordu** — kodlar sunucuda doğru, telefonda hiç yok. Ayrı bir
  migration delta üretti. **Kural: veriyi değiştiren her migration onu senkrona da düşürmeli.**
- **Kalite kapısı** php'yi kendisi buluyor (PATH → Laragon → XAMPP); pint/phpstan/API testleri
  artık gerçekten koşuyor. Kapının bulduğu 6 stil hatası düzeltildi.
- **Font testi** çerçeve davranışına bağlıydı (Flutter 3.44.6 artık `fontWeight`i wght eksenine
  kendi eşliyor) — kapıyı kilitliyordu; test davranışa değil SÖZLEŞMEYE bağlandı.
- **`saha-sunucu.ps1`** araçlarını kendi buluyor (php/cloudflared), şemayı kuruyor, yetim
  süreçleri komut satırı kalıbıyla temizliyor. `/ci` kısayolu + durum çubuğunda CI segmenti eklendi.

## Bu vardiyada NE YAPILMADI / YARIM KALDI

- 🔴 **`.env`'de coğrafi kodlama anahtarı YOK.** `GEOCODING_DRIVER=yandex` +
  `YANDEX_GEOCODER_KEY=...` eklenmeden **"Konum Al" aday döndürmez** (NullGeocoder dürüstçe
  "bu kurulumda tanımlı değil" der). Yeni eklenen **"Konum Güncelle" bundan bağımsız** — cihaz
  GPS'i, sunucuya hiç gitmiyor. Araç `.env`'e yazamıyor, **proje sahibinde**.
- 🔴 **Demo giriş bilgileri GEÇİCİ** (`111/111/1111`). Mağaza başvurusundan önce geri alınmalı;
  tek değiştirme noktası `DemoSeeder` sabitleri. Ayrıntı "İnsan gerektiren işler" listesinde.
- **Telefon en az yapım 156'yı almalı.** CDN düzeltmesi **kendini taşıyamaz**: 156'dan eski bir
  pakette bu kod yok ve o cihaz bayat `surum.json` görmeye devam edebilir. Ayarlar'daki
  `Sipario 0.9.0 (N)` satırına bak; N < 156 ise linkten **bir kez elle** kur.
- **Emanet/boş damacana kararı HÂLÂ BEKLİYOR** (üç seçenek sunuldu, cevap gelmedi).
- **`orders.customer_id` indeksi hâlâ yok**; `ui_dilim3_test.dart` 608 satır; `letterSpacing`
  em/px tipografi denetimi; `SipIcons.mic` taşınmadı — hepsi önceki turdan devam.
- **Kotlin birim testi altyapısı yok** — `OemBatteryGuide`'ın yeni pil/autostart ayrımı yalnız
  Dart tarafından (kanala giden metot) kilitlendi; native intent çözümlemesi cihazda denenmeli.

## Sonraki kişi NEREDEN devam etmeli

1. **Cihazda doğrula** (aşağıdaki liste) — bu vardiyanın hiçbir maddesi cihazda denenmedi.
2. **`.env` anahtarı** girilirse "Konum Al" akışı ilk kez uçtan uca çalışır.
3. Kod tarafında sıradaki en değerli iş hâlâ **mobil CI** (SIRADAKİ İŞLER #5) — mobil testler
   yalnız geliştirici makinesinde koşuyor.
4. İstatistik arayüzü istenirse zemin hazır: `gun_arsivi.dart` ürün/kurye kırılımını zaten
   hesaplıyor, haftalık/aylık toplamlar onun üstüne oturur.

## SAHA KONTROL LİSTESİ (cihazda bakılacaklar)

1. **Kodlar:** müşteri listesinde adın başında numara var mı; sipariş satırında ayara göre
   `102` ya da `#248`; Ayarlar → İşletme → "Sipariş satırındaki kod" seçimi listeyi değiştiriyor mu.
2. **Borç:** teslim edilmiş veresiye siparişte satırda "Borç 200,00 ₺" pili; kısmi ödemede
   pil KALANI yazıyor mu (sipariş tutarını değil).
3. **Gün sonu:** geçmişte tarihler görünüyor mu; kapatılmamış gün "kapatılmadı" rozetiyle
   listede mi; gün detayında ürün dökümü kasa özetiyle tutuyor mu.
4. **Yenileme:** her ekranda aşağı çekince gösterge dönüyor mu; ana ekranda çekince "Sürüm
   güncel" çipi çıkıyor mu (çevrimdışıyken ÇIKMAMALI).
5. **Sihirbaz:** "Arka planda çalışma" adımında **"Pil Ayarını Aç"** gerçekten pil ekranını,
   **"Otomatik Başlatmayı Aç"** autostart listesini açıyor mu (asıl saha hatası buydu).
6. **Konum:** müşteri düzenlemede "Konum Al" görünüyor mu; sipariş detayında "Konumu Kaydet"
   dokununca müşteri kartında konum yeşile dönüyor mu.
7. **Bekleme süresi:** açık siparişte dakika ilerliyor mu (uygulama açıkken ~1 dk bekle).

---

### VARDİYA 2026-07-27 (TARİHSEL — güncel devir notu yukarıdadır)

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

# (ARŞİV) SIRADAKİ İŞLER — 2026-07 listesi, ÇOĞU KAPANDI/ASKIDA

> 🔴 **BU LİSTE ARTIK GÜNCEL DEĞİLDİR — güncel liste yukarıdaki
> "🔴 SIRADAKİ İŞLER — TEK LİSTE" bölümüdür.** 2026-08-17'de maddelerin çoğu kapandı ya da
> kullanıcı kararıyla askıya alındı; her biri kendi başlığında işaretlendi. Buradaki tarifler
> yalnız TARİHSEL/REFERANS değer taşır — askıdaki bir madde yeniden açılırsa adımları hazır bulunur.
>
> **Okuma kılavuzu:** Her iş için **NEDEN**, **KİMDE**, **ADIMLAR**, **BİTTİ SAYILIR** ve **KANIT** var.

## ⏸️ 1. iyzico sandbox anahtarı — **ASKIYA ALINDI (2026-08-17, kullanıcı kararı)**

> **Gündeme alınmaz, sorulmaz.** Aşağısı askı kalktığı gün okunacak tariftir; iş maddesi değildir.

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

## 🟡 2. Android release imza anahtarı (keystore) — **AÇIK, AMA ACİL DEĞİL (2026-08-17)**

> Kullanıcı: *"Android Release keystore için henüz daha var."* Yani iş duruyor ama zamanı
> gelmedi — **her vardiyada hatırlatılmaz**, mağaza başvurusuna yaklaşınca gündeme gelir.

**NEDEN:** `release` derleme **hâlâ debug anahtarıyla imzalanıyor**. Debug imzalı paket Play'e
**yüklenemez** — mağaza başvurusu bu satır yüzünden ilk adımda durur. Yapılması yarım saat.

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

## ⏸️ 3. Apple D-U-N-S + Apple geliştirici hesabı — **ASKIYA ALINDI (2026-08-17, kullanıcı kararı)**

> **Gündeme alınmaz, sorulmaz.** Apple tarafı (D-U-N-S, Developer Program, iOS çıkışı) askıda.
> Google Play ayağı 2. maddede ayrı yaşıyor ve askıda DEĞİL.

**NEDEN (tarihsel):** Mağaza başvurusunun ön koşulu; D-U-N-S başvurusu HAFTALAR sürebilir.

**KİMDE:** Tamamen **sende** (tüzel kişilik gerektirir).

**ADIMLAR:**
1. **D-U-N-S başvurusunu BUGÜN yap** — ücretsiz, sonucu beklerken diğer işler yürür.
2. Google Play Console kurumsal hesabı aç (tek seferlik ücret).
3. Apple Developer Program kaydı (D-U-N-S gelince).
4. Hesaplar açılınca `docs/magaza/` altındaki başvuru paketi Claude tarafından doldurulur.

**BİTTİ SAYILIR:** İki konsola da giriş yapılabiliyor.

## ✅ 4. Arayan tanıma 20/20 ölçümü — **YAPILDI (2026-08-17, kullanıcı doğruladı)**

> ✅ **FAZ 0'IN ŞARTI DÜŞTÜ: GO ARTIK KESİN.** BRIEF'in 1 numaralı korkusu ve Faz 0'ın "şartlı GO"
> kaydı tam olarak bu ölçüme bağlıydı (*20/20 aramada ≤1 sn*); ölçüm sahada yapıldı. Ürünün varlık
> sebebi artık doğrulanmış durumda. **Bu madde bir daha SIRADAKİ İŞLER'e alınmaz.**
>
> ℹ️ Tek teknik not (iş maddesi DEĞİL, bilgi): ölçüm ekranına giden Ayarlar satırı kodda hâlâ
> `kDebugMode` ile sarılı (`screens/isletme/ayarlar/uygulama_ayarlari_ekrani.dart:138` — dosya
> ayarların beşe bölünmesiyle taşındı, eski `ayarlar_ekrani.dart:266` yolu bayattır). Yani release
> derlemede satır çizilmez. Ölçüm tamamlandığı için bu artık kimseyi bloklamıyor; sahada YENİDEN
> ölçüm istenirse gizli kapı (sürüm numarasına 7 kez dokunma) o gün açılır.

**NEDEN (tarihsel):** Faz 0 "şartlı GO" ile kapanmıştı; şart bu ölçümdü.

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

## ✅ 5. Mobil CI — **KAPANDI** (2026-08-17'de koddan ölçüldü; bu satır aylardır bayatmış)

> `.github/workflows/mobil-apk.yml` **var ve koşuyor**: `dart analyze` (79-81. satır) +
> `flutter test` (86-88. satır, varlık indirmesini yeniden deneyen sarmalayıcıyla) + imzalı APK
> derleme + sürümü APK'nın kendisinden doğrulama + `surum.json` yayınlama.
> ℹ️ Tek eksik alt adım (iş maddesi değil, bilgi): 3. adımdaki **birleştirilmiş** manifest denetimi
> kurulmadı — kırmızı çizgi #6'yı `manifest-lint.yml` hâlâ **kaynak** manifest üzerinden koruyor
> (`scripts/check_permissions_source.sh`).

**NEDEN (tarihsel):** Ürünün ağırlık merkezi mobil, ama CI'da **yalnız API ve manifest
denetimi** koşuyordu. `flutter test` / `dart analyze` **sadece geliştiricinin makinesinde** çalışıyordu —
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

- **[⏸️ ASKIYA ALINDI — 2026-08-17, kullanıcı kararı]** ~~e-arşiv fatura:~~ BRIEF yasal gereklilik
  sayıyor, kodda **sıfır**. **Gündeme alınmaz, sorulmaz.** (Askı kalkarsa: entegratör seçimi
  kullanıcıda, bağlama Claude'da; `mesafeli-satis.blade.php:22` "fatura elektronik iletilir" diyor.)
- **[⏸️ ASKIYA ALINDI — 2026-08-17, kullanıcı kararı]** ~~iOS:~~ `apps/mobile/ios/` iskeleti hiç
  derlenmedi, Mac + Xcode gerekiyor. **Gündeme alınmaz, sorulmaz** (Apple tarafıyla birlikte askıda).
- **Mağaza görselleri + arayan-tanıma tanıtım videosu:** BRIEF mağaza incelemesi için zorunlu
  sayıyor, hiç üretilmedi. Video demo hesapla çekilecek (kilitli + kilitsiz ekran).
- **[✅ KAPANDI — 2026-08-17]** ~~Transactional e-posta: `MAIL_MAILER=log`~~ — test sunucusunda
  e-postalar gerçekten gidiyor (kullanıcı doğruladı), yani şifre sıfırlama da postalanıyor.
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

> **MAKİNE NOTU (2026-07-29):** Bu makinede varsayılan JDK **25**'tir (`Eclipse Adoptium jdk-25.0.3.9`, PATH'te)
> ve Gradle 8.14'ün gömülü Kotlin derleyicisi bu sürüm dizgisini ayrıştıramıyor
> (`java.lang.IllegalArgumentException: 25.0.3`). Doğrudan `gradlew` çağrıları bu yüzden düşer.
> Çözüm: `$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"` (JDK 21) ile koş.
> `flutter build apk` ETKİLENMEZ — Flutter zaten Android Studio'nun JBR'ını kullanıyor
> (`flutter doctor -v` bunu yazar). CI de etkilenmez (kendi JDK'sını kurar).
