# SEO — anahtar kelime haritası

> 2026-08-19'da kuruldu. **Bu dosya bir niyet beyanı değil, sayfa başlıklarının kaynağıdır:**
> aşağıdaki eşleme değişirse `resources/views/site/*.blade.php` içindeki `baslik`/`aciklama`
> proplarının da değişmesi gerekir. Tersi de doğru — başlığı değiştirip burayı güncellememek,
> altı ay sonra "bu başlık niye böyle" sorusunu cevapsız bırakır.

## Kural: bir sayfa, bir birincil kelime

Aynı kelimeyi iki sayfaya hedeflemek (keyword cannibalization) ikisini birden zayıflatır: Google
hangisinin daha alakalı olduğuna karar veremez ve genelde yanlış olanı seçer. Aşağıda her sayfanın
**bir** birincil kelimesi var; ikincil kelimeler gövde metninde geçer, başlıkta değil.

## Ölçülmedi — bu bir HİPOTEZDİR

⚠️ Aşağıdaki kelimelerin **arama hacmi ölçülmedi.** Ürün pilot aşamasında, Search Console verisi
yok. Bunlar sahadan bilinen dile (BRIEF'in "kullanıcının dünyası" bölümü) ve ürünün gerçekten
yaptığı işe göre seçildi. **Veri biriktikten sonra bu tablo veriye göre düzeltilecektir**; bugün
tahminle "optimize" etmek, ölçmeden ayar yapmak olurdu.

Bu dosyayı güncellemenin doğru anı: Search Console'da **90 günlük** veri biriktiğinde. Bakılacak
şey sıralama değil, **tıklanma oranı (CTR)**: 10. sıradaki %8 CTR'li bir sorgu, 3. sıradaki %1
CTR'liden daha değerli bir düzeltme fırsatıdır.

---

## Sayfa → kelime eşlemesi

| Sayfa | Birincil kelime | İkincil (gövdede) | Neden |
|---|---|---|---|
| `/` (ana) | **su bayii programı** | esnaf sipariş programı · veresiye defteri uygulaması · damacana takip | İlk dikey su bayileri (BRIEF: verilmiş karar). En dar ve en niyetli arama. |
| `/ozellikler` | **arayan tanıma programı** | müşteri tanıma · gelen arama müşteri kartı · kurye takip uygulaması | Ürünün varlık sebebi ve rakiplerde olmayan tek şey (BRIEF: "arayan tanıma bu ürünün varlık sebebidir"). |
| `/destek` | **veresiye takip programı** | cari hesap takibi · esnaf borç defteri | Destek sayfası SSS taşıyor; sorular tam da bu kelimenin etrafında dönüyor. |
| `/iletisim` | *(hedef yok)* | — | Marka aramasıyla gelinir; kelime hedeflemek anlamsız. |
| `/sozlesme/*` | *(hedef yok)* | — | "sipario kvkk", "sipario iptal" gibi **marka + belge** aramalarının cevabı. Dizine açık kalmalı. |
| `/fiyatlar` | **hedeflenmiyor — `noindex`** | — | 2026-08-05 kararı: tek pakete geçildi, sayfa siteden gösterilmiyor. |
| `/kayit`, `/giris`, `/abonelik`, `/parola` | **hedeflenmiyor — `noindex`** | — | Kimlik/ödeme akışı; arama sonucunda çıkmasının kimseye faydası yok. |

## Bilerek HEDEFLENMEYEN kelimeler

- **"ön muhasebe programı" / "e-fatura programı"** — Sipario muhasebe programı değil, fatura
  kesmiyor. Bu kelimelerle gelen ziyaretçi aradığını bulamaz; yüksek hemen çıkma oranı sitenin
  tamamına zarar verir. `llms.txt`'in "Ne yapmaz" bölümü de aynı sınırı çiziyor.
- **"ücretsiz sipariş programı"** — ürün ücretli; "ücretsiz" arayan kitle dönüşmez.
- **"restoran / adisyon programı"** — masa, adisyon ve mutfak ekranı yok. Hazırlanan ürün yeteneği
  (`prepared_products`) bir dönerciye yetiyor ama bu bir restoran POS'u değil.
- **Rakip marka adları** — hem sonuç vermez hem marka mevzuatı açısından risklidir.

## Başlık ve açıklama yazım kuralı

- **Başlık ≤ 60 karakter**, birincil kelime **başta**, marka sonda (`… · Sipario`).
- **Açıklama 140–160 karakter**, birincil kelime bir kez geçsin ve cümle **bir vaat** taşısın —
  Google açıklamayı sıralamada kullanmıyor ama **tıklanma oranında** kullanıyor.
- Kelime tekrarı (stuffing) YOK: aynı kelimeyi başlıkta iki kez geçirmek 2010'ların taktiğidir,
  bugün yalnız metni kötüleştirir.
- **Uydurma sayı yok.** "1.240 işletme kullanıyor" gibi bir açıklama, sitedeki uydurma verinin
  silinme gerekçesiyle aynı sebepten yazılamaz (bkz. DECISIONS 2026-08-19).

## Teknik taraf (bu vardiyada kuruldu)

| Ne | Nerede |
|---|---|
| `robots.txt` | `public/robots.txt` — statik (web sunucusu Laravel'e uğratmaz) |
| `sitemap.xml` | `routes/web.php` · `seo.sitemap` → `resources/views/seo/sitemap.blade.php` |
| `llms.txt` | `routes/web.php` · `seo.llms` → `resources/views/seo/llms.blade.php` |
| canonical · OG · Twitter · hreflang | `components/layouts/site.blade.php` |
| `noindex` kararı | layout'un `dizine` prop'u (tek yer) |
| JSON-LD `Organization` + `WebSite` | `components/layouts/site.blade.php` (gövde sonu) |
| JSON-LD `BreadcrumbList` | `legal/show.blade.php` |
| Bekçi testleri | `tests/Feature/Api/OlcumVeSeoTest.php` |

## Yapılmadı — sıradaki

- **`og:image` (1200×630)** yok ve uydurulmadı: olmayan bir dosyaya işaret etmek WhatsApp'ta
  kırık önizleme üretir, hiç etiket olmamasından kötüdür. Satış WhatsApp'tan yürüdüğü için bu
  görsel, listedeki en yüksek getirili tek iştir.
- **`FAQPage` yapısal verisi** `/destek` için eklenebilir (arama sonucunda açılır soru listesi
  verir). Bugün eklenmedi: SSS içeriği `_veri.php`den geliyor ve şemayı oradan üretmek, cevapların
  HTML taşıyıp taşımadığına göre değişen bir kaçış işi — ayrı bir vardiyada ölçülerek yapılmalı.
- **Search Console'a site haritası gönderimi** insan işidir (hesap doğrulaması gerekir).
