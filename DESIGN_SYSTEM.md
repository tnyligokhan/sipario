# DESIGN_SYSTEM.md — Sipario mobil arayüz

> Kaynak: `design_handoff/` (Claude Design). Uygulama: `apps/mobile/lib/theme/`.
> **Kural: ekranlarda ham renk/ölçü/yarıçap/font KULLANILMAZ — her şey buradan gelir.**
> Sonraki tüm ekranlar bu dokümana göre tasarlanır. Bir token değişirse tek yerde (`tokens.dart`)
> değişir, tüm uygulama takip eder.

## Felsefe
Su bayii esnafı için: telefon çalarken **tek elle, hızlı, okunaklı**. Simsiyah değil **katmanlı koyu
yüzeyler** (elevation'ı koyuluk taşır), su temalı **tek vurgu rengi** (Azur), düz satır yerine
**kartlar**, borçluyu bir bakışta ayıran **kırmızı bakiye rozeti**. Rakamlar her yerde tabular
(defterle kuruş hizası). Dokunma hedefi ≥ 52–56 px. Koyu tema (tek tema).

## Dosya haritası (`apps/mobile/lib/theme/`)
| Dosya | İçerik |
|-------|--------|
| `tokens.dart` | `SipColors`, `SipRadius`, `SipSpace`, `sipFontFamily` — ham token'lar (tek kaynak) |
| `typography.dart` | `SipText` (adlandırılmış stiller) + `buildSipTextTheme()` |
| `app_theme.dart` | `SipTheme.dark()` → Material 3 `ThemeData` (buton/appbar/nav/input/dialog…) |
| `components/balance_badge.dart` | `BalanceBadge` — ortak bakiye rozeti (liste + çağrı aynı dil) |

## Renk (SipColors)
**Yüzeyler:** `bg #0C1015` (zemin/scaffold) · `s1 #141A21` (kart, alt gezinme, appbar) ·
`s2 #1C242D` (arama, segment rayı, popup) · `s3 #28323C` (avatar, ikincil buton, çip).
**Çizgi:** `line` beyaz %7 (kart kenarı) · `line2` beyaz %12 (belirgin kenar).
**Metin:** `t1 #EEF2F5` · `t2 #9AA6B2` · `t3 #5F6975`.
**Vurgu (Azur):** `acc #23A9E0` (FAB/tab/aksiyon) · `accFg #54C4EE` (koyu üstünde ikon/yazı) ·
`accInk #06131B` (vurgu dolgusu üstünde yazı) · `accSoft` %15 (seçili zemin).
**Durum:** `debt/err #E85640` + `debtSoft` %16 · `ok #41B883` + `okInk #06231B` + `okSoft` %15 ·
`warn #E7A93C` + `warnSoft` %15.
> Handoff'ta vurgu alternatifleri var (Turkuaz `#16B5AE`, Deniz mavisi `#3B7DE0`) — istenirse
> `SipColors.acc/accFg/accSoft/accInk` dörtlüsü değişir. Köşe "Keskin" varyantı: 10/8/12/10.

## Tipografi — IBM Plex Sans
Font `assets/fonts/`'a **gömülü** (OFL; offline-first, runtime indirme yok). Ağırlık 400/600/700.
Adlandırılmış stiller (`SipText`): `screenTitle` 27/700 · `cardTitle` 17.5/600 · `secondary` 14/400
(ikincil) · `muted` 12.5/500 · `amount` 18/700 · `badge` 15/700 · `navLabel` 11.5/600 ·
`sectionLabel` 11/600 VERSAL · `emptyTitle` 18/600 · `emptyBody` 14.5/400. **Rakamlı stiller tabular.**

## Yarıçap (SipRadius) · Aralık (SipSpace)
`card 16` · `sm 11` (rozet) · `fab 18` · `input 15` · `sheet 22`.
Aralık: `xs 4 · sm 8 · gap 10 (liste) · md 12 · lg 14 · xl 18 · xxl 22 · section 26`.

## Bileşenler
- **BalanceBadge** (`kurus`): + borç → dolgulu kırmızı hap, beyaz yazı (dikkat çeker) · 0 temiz →
  soluk, dolgusuz · − alacak → sessiz yeşil. Tutar `formatKurus`'tan.
- **Kart satırı** (liste): `Material(s1)` + `InkWell` + kenar `line`, yarıçap `card`, iç boşluk 14×13.
  Sol avatar (44 daire `s3`, baş harfler `t2` 15/700), orta ad (`cardTitle`) + ikincil satır
  (`secondary` 13.5), sağ `BalanceBadge`.
- **Alt gezinme** (tema): `NavigationBar`, arka plan `s1`, seçilide `accSoft` hap göstergesi +
  `accFg` ikon/etiket, seçilmeyende `t3`; seçili ikon DOLU varyant. Davranış değişmedi.
- **FAB** (tema): genişletilmiş, `acc` dolgu, `accInk` yazı, yarıçap `fab`. Tip `FloatingActionButton`
  korunur (testler + salt-okunur kapısı).
- **Arama alanı** (tema `InputDecorationTheme`): `s2` dolgu, kenarlıksız, yarıçap `input`, `search`
  ön-ikon + temizle son-ikon.
- **Boş durum:** 84 daire (`s2` + `line`, 40 px ikon `t3`) + `emptyTitle` + `emptyBody`; metin
  bağlama göre (arama mı, hiç kayıt mı).
- **Segment filtresi** (sıradaki ekranlar): `s2` hap ray + seçilide `acc`/`accInk` (check ikonlu),
  seçilmeyende saydam/`t2`. — Ekran 2'de bileşenleşecek.
- **Senkron durumu** (Menü): renkli nokta (ok/acc-nabız/err) + etiket + saat. — Ekran 4'te.

## İkonlar
Flutter yerleşik `Icons.*` (Material Icons) kullanılır — handoff'un Material Symbols Rounded'ına
görsel olarak çok yakın; değişken font gömmenin ağırlığından kaçınılır. Seçili sekmelerde dolu varyant.

## Değişmezler (bozulmayacak)
Durum yönetimi/akış deseni (constructor-injected `db/session/sync/writable/yetki`, `StreamBuilder`),
offline-sync göstergesi, FAB aksiyonları, filtre chip'leri, alt gezinme davranışı, mağaza kuralı
(mobilde fiyat/abone-ol/link YOK), para = int kuruş, KVKK (loglara PII yok). Yalnız GÖRÜNÜM yenilenir.
