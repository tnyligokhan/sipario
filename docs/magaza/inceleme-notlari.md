# Mağaza İnceleme (App Review) Notları — Google Play + Apple App Store

⚠️ **TASLAK** — mağaza konsoluna girmeden önce gerçek şirket bilgisi + video + insan kontrolü gerekir.

Bu belge her iki mağazanın "App Review bilgileri / notlar" kutusuna kopyalanacak metni içerir.
Amaç: incelemeci uygulamayı **kayıt ekranı olmadan** açabilsin, arayan-tanıma gibi telefon
durumuna bağlı özellikleri video üzerinden anlayabilsin ve hassas izinlerin (`READ_CONTACTS`,
`USE_FULL_SCREEN_INTENT`) neden istendiğini sorgusuz görsün.

## Demo hesap

- **Kullanıcı adı / e-posta:** `demo@sipario.com.tr`
- **Şifre:** `demo1234`
- **Rol:** Patron (tam yetkili)
- Hesap **aktif** ve **içi dolu**: 4 telefonlu müşteri, teslim edilmiş siparişler, veresiye
  bakiyesi olan ve olmayan müşteri örnekleri, kasa hareketi. `DemoSeeder` ile kurulur
  (`apps/api/database/seeders/DemoSeeder.php`), 10 yıllık geçerlilik süresiyle — inceleme
  sırasında abonelik/deneme süresi dolup kilitlenmez.
- Bu **gerçek bir müşteri hesabı değildir**, temsili/sahte veridir; gerçek bir bayiye
  verilmez (KVKK açısından temiz).

## "Neden kayıt ekranı yok?" — incelemeciye açıklama

> Sipario, mevcut bir hesapla giriş yapılan bir **saha uygulamasıdır**. Hesaplar bizim
> tarafımızdan (satış/kurulum sürecinde) veya işletmenin **sipario.com.tr** web sitesinden
> açılır; mobil uygulamanın kendisinde kayıt ol ekranı, satın alma ekranı veya fiyat/paket
> bilgisi **bulunmaz**. Bu bilinçli bir tasarım kararıdır (Apple App Store Review Guideline
> 3.1.3(f) ve Google Play ödeme politikasına uyum içindir) — abonelik yönetimi tamamen web
> sitesinde yaşar, uygulama yalnız zaten var olan bir hesapla giriş yapılan iş aracıdır.
> İncelemeniz için yukarıdaki demo hesabı kullanabilirsiniz.

## Arayan tanıma özelliği (yalnız Android)

> Uygulama, gelen çağrıda müşteriyi otomatik tanıyıp adını/bakiyesini gösteren bir özelliğe
> sahiptir. Bu özellik Android'in resmî `CallScreeningService` API'si (Android 10+) ile
> çalışır — hiçbir arama kaydı (call log) veya SMS izni kullanılmaz, yalnızca o anki gelen
> çağrının numarası anlık okunur. `READ_CONTACTS` izni, yalnızca rehbere kayıtlı numaralarda
> da bu servisin tetiklenebilmesi için Android tarafından şart koşulur — rehber taranmaz,
> hiçbir veri cihaz dışına çıkmaz.
>
> Bu özellik incelemeci ortamında (emülatör/gerçek çağrı simülasyonu olmadan) canlı
> gözlemlenemeyebileceğinden, özelliği kilitli ve kilitsiz ekranda gösteren bir video ekledik:
> **[VİDEO LİNKİ — PLACEHOLDER, çekilecek]**
>
> Videoda demo hesaptaki telefonlu müşterilerden biri arar gibi gösterilir (örn. Ahmet Yılmaz,
> +90 532 111 22 33) ve ekranda ad/adres/bakiye kartının belirdiği anlatılır.
>
> iOS'ta bu özellik **yoktur** — Apple işletim sistemi üçüncü taraf uygulamaların gelen
> çağrıyı bu şekilde yakalamasına izin vermez; iOS sürümü sipariş/veresiye/kurye ile tam
> işlevseldir.

## `USE_FULL_SCREEN_INTENT` — "çekirdek işlev" beyanı (Android 14+, Google Play)

> Bu izin, gelen çağrıda müşteri kartını **kilit ekranındayken** gösterebilmenin teknik
> olarak tek yoludur: normal bir overlay penceresi kilit ekranının altında kalır, yalnız
> `showWhenLocked` bayraklı bir Activity'yi arka plandan başlatmanın belgelenmiş tek
> muafiyeti tam ekran niyetli (full-screen intent) bildirimdir. Uygulamanın **çekirdek
> işlevi** — gelen çağrıda müşteriyi tanımak — telefon kilitliyken de çalışmak zorundadır
> (sahada bayiler telefonu çoğunlukla kilitli/cepte taşır). İzin verilmezse uygulama
> çökmez: kilit ekranında normal bir bildirime düşer, kurulum sihirbazı kullanıcıdan izni
> Ayarlar'dan açmasını ister.

## `READ_CONTACTS` — tekrar, kısa özet

> Yalnız `CallScreeningService`'in rehberde kayıtlı numaralarda da tetiklenebilmesi için.
> Rehber verisi okunmaz/taranmaz/yüklenmez; ayrıntı `play-data-safety.md` §2.

## Test adımları (incelemeci için önerilen akış)

1. Demo hesapla giriş yap (`demo@sipario.com.tr` / `demo1234`).
2. Müşteri listesinde 4 telefonlu müşteriyi ve bakiyelerini gör (2 veresiye borçlu, 1 nakit
   ödemiş, 1 hareketsiz).
3. Sipariş/teslimat akışını dene (uçak modunu açıp kapatarak offline çalışmayı gözlemleyebilir).
4. Arayan-tanıma videosunu izleyerek Android'e özgü özelliği doğrula (gerçek cihaz gerektirir,
   incelemecinin kendi ortamında tetiklenmesi beklenmez).

## Genel iletişim

- İnceleme sırasında soru için: `[destek e-postası — PLACEHOLDER]`
- Acil ret/soru durumunda dönüş: `[telefon — PLACEHOLDER]`
