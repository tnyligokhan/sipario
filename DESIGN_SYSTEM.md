# DESIGN_SYSTEM.md — Sipario mobil arayüz (SİPARİO 3.x)

> **Kural: ekranlarda ham renk/ölçü/yarıçap/font KULLANILMAZ — her şey `apps/mobile/lib/theme/`den gelir.**
> Bir token değişirse tek yerde değişir, tüm uygulama takip eder.

## Tasarımın tek kaynağı — YEREL KOPYA YOKTUR

Tasarım **Claude Design projesindedir** ve depoda kopyası TUTULMAZ:

| | |
|---|---|
| Proje | **Sipario APP Reesign** |
| Kimlik | `a4ab826a-d312-4313-96be-e66519b64fce` |
| Bağlantı | <https://claude.ai/design/p/a4ab826a-d312-4313-96be-e66519b64fce> |
| Handoff klasörü | `design_handoff_sipario/` (proje İÇİNDE) |
| Okuma yolu | `DesignSync` MCP aracı → `list_files` / `get_file` |

**Neden yerel kopya yok (2026-07-26 kararı).** Bu proje aynı hatayı iki kez yaptı:
`design_handoff/` (2026-07-23) ve `design_handoff_v2/` (2026-07-25) depoya kopyalandı,
tasarım güncellenince bayatladı ve **iki vardiya boyunca yanlış kaynağı doğru sandı.**
İkisi de silindi. Kopya tutmak, kopyayı güncel tutma sözü vermektir; o söz tutulamadı.
Artık kaynak tek yerde canlı durur, kod ondan okur.

### Handoff'un yapısı (uzakta)

| Yol | İçerik |
|---|---|
| `design_handoff_sipario/README.md` | Handoff'un kendi açıklaması — fidelity, kabuk, ekran tablosu, token listesi |
| `design_handoff_sipario/Sipario-tek-dosya.html` | Çalışan prototipin tamamı tek dosyada (davranışı görmek için tarayıcıda aç) |
| `design_handoff_sipario/kaynak/Sipario.html` | **CSS'in tamamı** (`<style>` bloğu) + script yükleme sırası — **ölçüde BAĞLAYICI kaynak** |
| `design_handoff_sipario/kaynak/s-*.jsx` | 16 ekran/bileşen dosyası |
| `refs/`, `uploads/` | Görsel referanslar — niyeti gösterir, ölçüde bağlayıcı DEĞİLDİR |

> ⚠️ Yalnız `Sipario.html` çekilirse elde edilen şey ~660 satır CSS ve **boş bir `<div id="root">`**tür.
> Ekranlar 16 ayrı `s-*.jsx` dosyasındadır; tasarımı anlamak için hepsi okunur.

### Ekran → dosya haritası

| Ekran | Tasarım dosyası | Flutter karşılığı |
|---|---|---|
| Giriş | `s-giris.jsx` | `screens/login_screen.dart` |
| Kurulum sihirbazı | `s-sihirbaz.jsx` | `screens/sihirbaz/` |
| Ana (hero + bento) | `s-ana.jsx` | `screens/ana_ekran.dart`, `screens/shell/ana_bento.dart` |
| Siparişler + detay + yeni | `s-siparisler.jsx` | `screens/orders/` |
| Müşteriler + detay + defter | `s-musteriler.jsx` | `screens/customers/` |
| Ürünler | `s-urunler.jsx` | `screens/products/` |
| Kuryeler | `s-kuryeler.jsx` | `screens/isletme/kuryeler_ekrani.dart` |
| Muaf numaralar | `s-muaf.jsx` | `screens/isletme/muaf_ekrani.dart` |
| Gün sonu | `s-gunsonu.jsx` | `screens/day_end_screen.dart`, `screens/isletme/gun_sonu_*.dart` |
| Ayarlar | `s-ayarlar.jsx` | `screens/isletme/ayarlar_ekrani.dart` |
| İşletme profili | `s-isletme.jsx` | `screens/isletme/isletme_profili_ekrani.dart` |
| Gelen çağrı kartı | `s-cagri.jsx` | `screens/cagri/` + `android/.../CallerCard.kt` |
| Çekmece + ortak parçalar | `s-bilesenler.jsx` | `screens/shell/`, `theme/components/` |
| Atomlar / ikonlar / yardımcılar | `s-arayuz.jsx` | `theme/` |
| Mock veri | `s-veri.jsx` | *(karşılığı yok — gerçek veri Drift'ten)* |

## Felsefe

Esnaf için: telefon çalarken **tek elle, hızlı, okunaklı**. Kimlik üç öğe üzerine kurulu:

1. **Koyu gece-mürekkep "hero" blokları** — ana ekran başlığı, alt navigasyon, çekmece, giriş
   ekranı, müşteri adres kartı. Ekranın çapası bunlar.
2. **Aydınlık gövde** — içerik `bg` üzerinde beyaz kartlarda yaşar.
3. **Elektrik moru vurgu** (`#5A45F0`) — tek vurgu rengi; FAB, seçili durum, bağlantı, birincil düğme.

Yüzeyler **düz (flat)**: gölge yok, katman ton farkıyla kurulur. Rakamlar her yerde **tabular**
(defterle kuruş hizası). Dokunma geri bildirimi Material dalgası **değil**, zeminin bir ton
koyulaşması. Dokunma hedefi ≥ 44–52 px.

**Tema iki tanedir:** açık (varsayılan) ve koyu; kullanıcı Ayarlar'dan değiştirir.

## Dosya haritası (`apps/mobile/lib/theme/`)

| Dosya | İçerik |
|-------|--------|
| `tokens.dart` | `SipTokens` (ThemeExtension), `SipRadius`, `SipSpace`, `context.sip` kısayolu |
| `typography.dart` | `SipText` — anlamına göre adlandırılmış, **renksiz** metin stilleri |
| `app_theme.dart` | `SipTheme.acik()` / `SipTheme.koyu()` → Material 3 `ThemeData` |
| `svg_path.dart` | SVG `d` → Flutter `Path` ayrıştırıcısı (bağımlılıksız) |
| `icons.dart` | `SipIcons` (Lucide yolları) + `SipIcon` widget'ı — çizim önbellekli |
| `components/atoms.dart` | Barrel: `bicim · dokunma · form · rozetler · yerlesim` |
| `components/states.dart` | `SipUst`, `SipGovde`, boş durum, hata, iskelet, çevrimdışı bandı |
| `components/overlays.dart` | `sipSheet()`, `sipOnay()`, `SipToast` |

Sözleşme testleri: `apps/mobile/test/ui_temel_test.dart`.

## Renk — `SipTokens` (açık = CSS `:root`; koyu = KENDİ paleti)

Renkler `static const` **değildir**: tema çalışma anında değiştiği için bir `ThemeExtension`
içinde yaşar ve `context.sip.surface` biçiminde okunur.

| Jeton | Açık | Koyu | Kullanım |
|-------|------|------|----------|
| `bg` | `#F4F3F7` | `#161519` | Ekran zemini |
| `surface` | `#FFFFFF` | `#212026` | Kart / liste satırı |
| `surface2` | `#EAE8F0` | `#2E2D34` | Basılı hâl, input zemini, çip, segment rayı |
| `ink` | `#17141F` | `#DEDDE2` | Birincil metin |
| `ink2` | `#47434F` | `#B9B8BE` | İkincil metin |
| `muted` | `#8B8794` | `#909097` | Sönük metin / etiket |
| `line` | `#E6E4EC` | `#302F36` | İnce ayraç |
| `line2` | `#D2CFDB` | `#484650` | Belirgin kenarlık |
| `accent` | `#5A45F0` | `#A9A0F4` | Marka vurgusu |
| `accentInk` | `#FFFFFF` | `#151422` | Vurgu dolgusu üstündeki metin |
| `accentSoft` | `#ECE9FE` | `#2B2940` | Vurgunun yumuşak zemini |
| `hero` | `#17141F` | `#100E18` | Koyu mürekkep blok |
| `hero2` | `#241F31` | `#1C1A26` | Hero basılı / ikincil ton |
| `danger` | `#DF3F45` | `#E7827C` | Borç · hata · yıkıcı eylem |
| `dangerSoft` | `#FCE9EA` | `#442524` | |
| `ok` | `#1E9E6A` | `#6AC796` | Alacak · başarı |
| `okSoft` | `#E3F4EC` | `#193426` | |
| `warn` | `#C08415` | `#E2B466` | Uyarı · not |
| `warnSoft` | `#F9F0DC` | `#3B2C13` | |
| `durumInk` *(getter)* | `#FFFFFF` | `#16151E` | danger/ok/warn **dolgusu** üstündeki metin |

### Koyu tema neden açık temanın kopyası değil (karar 2026-08-19)

Koyu tema eskiden CSS `.app.koyu` bloğunun birebir kopyasıydı ve `accent`/`danger`/`ok`/`warn`
ana tonlarını açık temadan **olduğu gibi** taşıyordu. Ölçüm bunun iki ayrı arıza olduğunu gösterdi:

1. **Okunmuyordu.** `#5A45F0` koyu kartın üstünde **2,86:1** — WCAG AA'nın (4,5:1) altında.
   Yani uygulamanın tek vurgu rengi, koyu temada en zor okunan rengiydi.
2. **Titriyordu.** OKLCH kroması **0,242** ile paletin açık ara en doymuş rengiydi. Koyu zeminde
   doymuş mavi-mor "optik titreşim" üretir: göz kırmızı ile moru aynı düzlemde odaklayamaz
   (kromatik sapma), bu da sürekli akomodasyon → göz yorgunluğu demektir. Material'ın koyu tema
   rehberi de bu yüzden doymuş rengi değil, **açılmış/doygunluğu düşürülmüş tonu** (tone 80) ister.

Üstelik nötr yüzeylerin hepsi mor tentliydi (kroma ~0,026) — ekran topluca mor bir sis okuyordu.

**Yeni koyu paletin üç kuralı:**

| Kural | Ne yapıldı | Ölçüm |
|---|---|---|
| Vurgu koyuda **açılır** | mor hue korunur, L .53→.75, C .242→.12 | kart üstünde 2,86 → **6,94:1** |
| Mor **her yerde değil** | nötrlerin kroması ~.026 → ~.010 | mor yalnız vurgu + hero'da |
| Beyaz ışık **kısılır** | `ink` bir tık koyulaştı | zemin üstünde 16,45 → **13,46:1** |

Vurgu ve durum renkleri açıldığı için üstlerindeki mürekkep **tersine döner**: koyuda
`accentInk` ve `durumInk` koyudur (açıkta ikisi de beyaz — yani açık tema hiç değişmedi).

**AÇIK TEMA DEĞİŞMEDİ.** Şikâyet koyu taraftaydı; açık tema tasarımın `:root` bloğudur ve öyle
kalır. Bu yüzden `design_handoff_sipario/` altındaki CSS ile koyu palet artık **kasıtlı olarak**
ayrışır — CSS'e bakıp "Dart sapmış" diye geri almayın.

**Hero üstü katmanlar** (hero daima koyu olduğundan tema-bağımsız; `SipTokens.` altında statik):
`onHero` beyaz · `onHeroStrong` %85 · `onHeroMid` %55 · `onHeroSoft` %38 · `onHeroFill` %7 ·
`onHeroFill2` %12 · `onHeroLine` %8 · `heroDot #3DDC97` (canlı senkron) · `heroPill #B3A6FF` ·
`onHeroWarn #FFD79A` · `scrim` (perde).

**Bakiye dili — üç durum, tek kural:** `+` borç → `danger` / "Borç" · `−` alacak → `ok` / "Alacak" ·
`0` → `ink` / "Temiz". Yardımcılar: `t.bakiyeRenk(kurus)`, `t.bakiyeSoft(kurus)`,
`SipTokens.bakiyeEtiket(kurus)`. Liste satırında bakiye **0 ise çip hiç çizilmez**.

## Tipografi — iki aile

| Aile | Sabit | Nerede |
|------|-------|--------|
| **Sora** | `sipFontDisplay` | Başlıklar **ve tüm rakamlar** |
| **Hanken Grotesk** | `sipFontBody` | Gövde metni |

İkisi de **değişken (variable) font**, `assets/fonts/`'a gömülü (OFL; offline-first, runtime indirme
yok). Ağırlık `fontVariations: [FontVariation('wght', N)]` ile verilir — yalnız `fontWeight`
verilirse Android'de kalınlık kayar; ikisi birlikte yazılır.

**Stiller RENKSİZDİR.** Renk `DefaultTextStyle`tan miras alınır: `ThemeData` gövdeyi `ink` yapar,
hero blokları içlerinde beyaza çevirir. Kullanım: `Text(x, style: SipText.satirAd.copyWith(color: t.ink))`.

CSS'te `em` cinsinden verilen letter-spacing değerleri punto ile çarpılıp piksele çevrilmiştir.

Rakam taşıyan her stil **tabular**. Tutar biçimlendirme tek yerden: `sipTutar(kurus)` →
`"1.234,50 ₺"`; negatifte **tipografik eksi** (U+2212).

## Yarıçap · Aralık

`SipRadius`: `r1` 12 (küçük çip) · `r2` 16 (satır / input / kart) · `r3` 22 (büyük kart, sheet,
çağrı kartı) · `r4` 30 (hero eteği, giriş formu) · `hap` tam yuvarlak.
Hazır değerler: `br1 br2 br3 br4 brHap heroEtek sheetUst cekmece`.

`SipSpace`: `xs` 4 · `sm` 6 · `md` 8 · `lg` 10 · `xl` 12 · `x2` 14 · `x3` 16 ·
**`govde` 18** (ekran gövdesinin yatay iç boşluğu) · `x4` 20 · `x5` 22 · `x6` 26.

Yükseklikler: buton 48 · arama 46 · nav butonu 50 · ikon butonu 38 · segment 34.

## İkonlar — Lucide

Tasarım Lucide'ın ham SVG `d` verisini taşıyor (`s-arayuz.jsx` içindeki `S_ICONS`); biz de öyle
saklıyoruz (`SipIcons`). Çizim için `svg_path.dart` içinde küçük bir ayrıştırıcı var — SVG paketi
eklemek yerine bu tercih edildi: sıfır bağımlılık, sonuç `Path` önbelleğe alındığından maliyet
tek seferlik. SVG yay komutları Flutter'ın `Path.arcToPoint` API'sine birebir eşlenir.

`SipIcon(SipIcons.phone, boyut: 22, kalinlik: 1.8, renk: t.ink2)`. Renk verilmezse çevredeki metin
renginden miras alınır — hero içindeki ikonlar kendiliğinden beyaza döner. İlk parametre hem
sözlük ANAHTARI (`'phone'`) hem doğrudan PATH (`SipIcons.phone`) kabul eder.

> ⚠️ **Yaşanmış hata — testin neyi kanıtladığına dikkat.** Bir sürüm boyunca `SipIcon` yalnız
> `hepsi[ad]` sözlüğüne bakıyordu; ama `SipIcons.phone` bir anahtar DEĞİL, path'in kendisi. Arama
> `null` dönüyor ve fonksiyon sessizce boş kutu çiziyordu — yani **uygulamadaki hiçbir ikon
> görünmüyordu.** Testler yeşildi: yolların ayrıştığını ve widget'ın çökmediğini sınıyorlardı,
> ekrana piksel düştüğünü DEĞİL. Hata ancak cihazda görüldü.
> Bunun için `test/icon_paint_test.dart` var: ikonları gerçekten çizip **piksel sayar**.
> Çizim yapan her bileşende ölçüt "çökmedi" değil, "boyandı" olmalı.

**Material ikonlarına dönülmez:** tasarımın çizgi karakteri (tekdüze kalınlık, yuvarlak uç)
Material'ın dolu/karışık diliyle uyuşmuyor.

## Ölçülmüş kontrast açığı (AÇIK KARAR — sessiz bir eksik değil)

`danger #DF3F45` küçük metin olarak kullanıldığında WCAG AA eşiğinin (normal metin için 4,5:1)
biraz altında kalıyor. Bağımsız olarak iki kez ölçüldü:

| Zemin | Oran | Eşik |
|-------|------|------|
| Açık tema `surface #FFFFFF` | **4,26:1** | 4,5:1 |
| ~~Koyu tema `surface #1E1B26`~~ | ~~3,98:1~~ → **6,07:1** | 4,5:1 ✅ |

> **Koyu taraf 2026-08-19'da kapandı** — yukarıdaki koyu palet kararıyla `danger` koyuda
> `#E7827C`ye açıldı. Açık temadaki açık **duruyor**: aşağıdaki gerekçe yalnız açık tema için
> geçerlidir.

Bu, tek bir ekranın değil **jetonun** özelliği: bakiye çipleri, gün sonu farkları, cevapsız çağrı
satırı — hepsi aynı tonu kullanıyor.

**Renk DEĞİŞTİRİLMEDİ.** Gerekçe: `#DF3F45` tasarımın kendi `:root` değeri; marka rengini tek
taraflı koyulaştırmak tüm ekranlara yayılan ve **kullanıcıya ait** bir karardır. Dolgu olarak
kullanıldığı yerlerde (danger düğme, borç rozeti üstündeki beyaz yazı) sorun yok — açık yalnız
**küçük danger METİN** durumunda. Çözüm istenirse: (a) `danger`ı bir tık koyulaştır (tek jeton,
her yer düzelir) ya da (b) küçük danger metinlerde ağırlığı artır (algılanan okunurluk artar ama
11 px'te WCAG sınıfı değişmez).

## Türkçe büyük/küçük harf

Dart'ın `toUpperCase()`/`toLowerCase()` metotları yerelden bağımsızdır: `'işletme'.toUpperCase()`
`IŞLETME` verir — Türkçede doğrusu `İŞLETME`. Tasarımda form etiketleri, bölüm başlıkları ve
rozetler büyük harf olduğu için bu her ekranda görünen bir kusurdur.

**Kural:** `trBuyuk()` / `trKucuk()` kullanılır (`atoms.dart`); `toUpperCase()` yazılmaz.
Arama karşılaştırmaları da `trKucuk()` üzerinden yapılır.

**İstisna — ASCII kimlikler:** firma kodu ve kullanıcı adı Türkçe metin değil, `^[a-z0-9._-]{3,}$`
sözleşmesine tabi kimliklerdir; onlarda düz `toLowerCase()` kullanılır (`auth/session.dart`).

## Etkileşim kalıpları

- **Dokunma:** `SipDokun` — ripple yok, zemin `surface2`'ye iner. `InkWell` kullanılmaz.
- **Alt sayfa:** `sipSheet(context, baslik:, govde:)` — tutamaç + başlık + kapat; `tam: true` ile
  ekranın %92'si.
- **Onay:** `sipOnay(...)` → `bool`. Yıkıcı eylemlerde `tehlike: true` (düğme danger olur).
- **Bildirim:** `SipToast.goster(context, '…')` — alt navigasyonun üstünde 2,2 sn duran hap.
  **`SnackBar` kullanılmaz:** alt navigasyonu iter ve tasarımın biçimini/konumunu tutturamaz.
- **Başlık:** `SipUst(...)` — **`AppBar` kullanılmaz** (tasarımda gölge/yükseklik yok).
- **Yükleniyor:** liste ekranlarında spinner değil **iskelet** (`SipIskelet`) — algılanan hız için.

## Kimlik ve kontör (tasarımın arka uca dokunan iki alanı)

- **Giriş = firma kodu + kullanıcı adı + parola** (`s-giris.jsx`). E-posta ile mobil giriş YOKtur.
  Firma kodu `tenants.slug`, kullanıcı adı `users.username` (tenant içinde tekil). Abonelik **web
  sitesi** hâlâ e-posta ile girer — o ayrı bir yüzeydir, karıştırılmaz.
- **Oto sıralama (rota) kontörlüdür** (`s-siparisler.jsx` `.sr-oto`, `s-bilesenler.jsx` `.lst-kart`).
  `tenants.route_credits` (kalan) + `route_credits_monthly` (kota) SUNUCU SAHİPLİDİR; istemci
  yazamaz, `subscription` bloğuyla iner. Sıralama `POST /orders/auto-route` ile istenir; uç nokta
  siparişlere YAZMAZ, yalnız sıra önerir — yazma yine `sort_set` olayıyla outbox'tan geçer.
  Kalan hak bilinmiyorsa düğme **hiç çizilmez** (uydurma sayı gösterilmez).

## Değişmezler (bozulmayacak)

Yalnız GÖRÜNÜM yenilendi; şunlar aynı kalır:

- Durum yönetimi/akış deseni (constructor ile geçilen `db/session/sync/writable/yetki`,
  `StreamBuilder`), offline-sync göstergesi, salt-okunur kipin kapıları, rol kapıları (K2).
- **Mağaza kuralı** (Apple 3.1.3(f) / Google Play): mobilde kayıt · üyelik · fiyat · abonelik ·
  satın alma · ödeme bağlantısı **yok**; abonelik kilidi ekranı ve kontör-bitti mesajı nötrdür.
  (Ürün fiyatı ve sipariş tutarı bundan muaftır — o iş verisidir.)
- Para her yerde **int kuruş**; KVKK: loglara PII yazılmaz.
- Defter ve olay tabloları **append-only** — bakiye ezilmez, düzeltme yeni kayıtla.
- Çağrı kartı gerçek cihazda **saf Kotlin**'dir; çağrı sırasında Flutter motoru başlamaz (1 sn
  bütçe). `CallerCard.kt` içindeki renkler bu belgeden **elle aynalanır** — dosyadaki işaretli
  senkron bloğunu koru.
