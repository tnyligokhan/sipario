# Google Play — Store Listing Metni Taslağı

⚠️ **TASLAK** — mağaza konsoluna girmeden önce gerçek şirket bilgisi + video + insan kontrolü gerekir.

## Uygulama adı

**Sipario**

## Kısa açıklama (Play sınırı: 80 karakter)

> Telefon çalınca müşteriyi tanı; sipariş, veresiye ve kurye tek uygulamada.

(74 karakter — konsola girerken sayaçtan doğrula.)

## Tam açıklama

> **Sipario — su ve damacana bayileri için sipariş, veresiye defteri ve kurye takibi.**
>
> Telefon çaldığında müşteri kim, ne zaman ne almış, ne kadar borcu var — hepsi ekranda.
> Sipario, eve servis yapan mikro esnafın (su/damacana bayileri başta olmak üzere) günlük
> işini tek uygulamaya toplar:
>
> **📞 Arayan tanıma**
> Müşteri aradığında adı, adresi ve güncel bakiyesi otomatik ekrana gelir — rehbere kayıtlı
> olsun olmasın. Android'in resmî çağrı filtreleme sistemi üzerinden çalışır; hiçbir arama
> kaydına veya SMS'e erişmez.
>
> **🧾 Sipariş ve veresiye defteri**
> Birkaç dokunuşla sipariş gir, teslimatı kapat. Nakit, kart, havale, veresiye — ödeme tipi ne
> olursa olsun defter kendiliğinden işler. Kupon (peşin paket) satışı ve kullanımı takip edilir.
>
> **🛵 Kurye takibi**
> Siparişleri kuryeye ata, teslimatları anlık gör. Gün sonunda kurye kasayı patrona devreder,
> rakamlar tutar.
>
> **📴 İnternetsiz çalışır**
> Sinyal yokken de sipariş gir, teslimat kapat, defter işlesin — bağlantı gelince otomatik
> senkronize olur. Hiçbir işlem internet yüzünden beklemez.
>
> **🔒 Verileriniz güvende**
> Müşteri verileri Türkiye'de barındırılan sunucularda tutulur, KVKK'ya uygun işlenir.
>
> ---
> Sipario, mevcut bir Sipario hesabıyla giriş yapılan bir saha uygulamasıdır. Hesap açma ve
> abonelik işlemleri **sipario.com.tr** üzerinden yürütülür; bu uygulamanın kendisinde satın
> alma veya kayıt ekranı bulunmaz.

## Kategori

**İş (Business)** — alt kategori önerisi: Verimlilik (Productivity) / Perakende (Shopping değil,
B2B saha uygulaması olduğu için "İş" birincil).

## İletişim bilgileri

- Geliştirici adı: `[şirket tüzel adı — PLACEHOLDER]`
- E-posta: `[destek e-postası — PLACEHOLDER]`
- Web sitesi: `sipario.com.tr` (varsayım — domain alındı, DECISIONS'a göre)
- Gizlilik politikası URL: `[sipario.com.tr/gizlilik veya /sozlesme/kvkk — PLACEHOLDER, 5d hukuk metni tamamlanınca kesinleşir]`

## İzin gerekçeleri (Play'in "İzin beyanı" bölümü için)

| İzin | Neden gerekli | Notlar |
|---|---|---|
| `READ_CONTACTS` | Arayan tanımanın rehberde KAYITLI numaralarda da çalışabilmesi için — Android'in `CallScreeningService` API'si, arayan rehberdeyse ve bu izin yoksa uygulamayı hiç çağırmaz. Rehber taranmaz, veri dışa çıkmaz (bkz. `play-data-safety.md` §2). | SMS/Call Log grubundan (READ_CALL_LOG, PROCESS_OUTGOING_CALLS, READ_PHONE_STATE vb.) **hiçbir izin YOK** — bilinçli mimari karar (BRIEF kırmızı çizgi #6). |
| `SYSTEM_ALERT_WINDOW` | Gelen çağrıda müşteri kartını (ad, adres, bakiye) ekranın üzerine çizmek için. | Yalnız çağrı ekranında kullanılır, sürekli açık kalmaz. |
| `USE_FULL_SCREEN_INTENT` | Kilit ekranındayken müşteri kartını gösterebilmenin **tek** teknik yolu — overlay penceresi kilit ekranının altında kalır. | Android 14+ bu izni yalnız arama/alarm uygulamalarına otomatik veriyor; "çekirdek işlev" beyanı gerekiyor (bkz. `inceleme-notlari.md`). İzin verilmezse uygulama çökmez, kilit ekranında normal bildirime düşer. |
| `POST_NOTIFICATIONS` | Overlay izni verilmediğinde yedek yol olarak heads-up bildirim gösterebilmek için (Android 13+). | Yedek yol; ana deneyim overlay/tam ekran karttır. |
| `INTERNET` | Sunucuyla senkronizasyon (sipariş, defter, müşteri verisi). | Uygulama internetsiz de tam çalışır; bağlantı gelince senkronlar. |

## Ekran görüntüleri / grafik varlıklar

Bu pakette YOK — ayrı bir görsel üretim işi (README'de not edildi).

## Hedef kitle / içerik derecelendirmesi

- Hedef yaş grubu: yetişkin (B2B iş uygulaması), çocuklara yönelik içerik yok.
- İçerik derecelendirmesi anketinde "reklam yok", "kullanıcı üretimi içerik yok", "şiddet/uygunsuz
  içerik yok" seçilecek — uygulama saf bir iş aracı.
