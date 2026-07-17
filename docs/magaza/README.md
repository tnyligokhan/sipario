# Mağaza Başvuru Metin Paketi — Sipario (Faz 6)

⚠️ **TASLAK** — mağaza konsoluna girmeden önce gerçek şirket bilgisi + video + insan kontrolü gerekir.

Bu klasör, Google Play ve Apple App Store başvurularında konsollara elle girilecek
metinlerin taslağını içerir. Hiçbiri dışsal bir sistemi veya API anahtarını gerektirmez;
tamamı düz metin/Markdown. PLAN.md "Faz 6" ve BRIEF.md §4 (abonelik/mağaza kuralları) +
kırmızı çizgi #6 (arayan tanıma izin disiplini) temel alınarak yazıldı.

## Dosyalar

| Dosya | Ne için |
|---|---|
| `play-data-safety.md` | Google Play Data Safety (Veri Güvenliği) formu cevap taslağı |
| `play-listing.md` | Google Play Store liste metni (ad, açıklama, izin gerekçeleri) |
| `app-store-listing.md` | Apple App Store liste metni (ad, alt başlık, açıklama, anahtar kelimeler) |
| `inceleme-notlari.md` | Her iki mağaza için "App Review" / inceleme notları + demo hesap |

## Neden hepsi TASLAK

- Şirket/iletişim bilgileri, gizlilik politikası URL'i, destek e-postası gibi alanlar henüz
  netleşmedi — bu belgelerde `[köşeli parantez]` ile işaretli, UYDURULMADI.
- Arayan-tanıma özelliğini gösteren tanıtım videosu henüz **çekilmedi** — her iki mağazanın
  inceleme notlarında `[PLACEHOLDER — çekilecek]` bağlantı olarak duruyor.
- Metinler mağazaların gerçek karakter sınırlarına (kısa açıklama 80, App Store adı 30 vb.)
  göre yazıldı ama konsola girerken tekrar sayılıp doğrulanmalı — mağaza arayüzleri sürüm
  sürüm değişebiliyor.
- Hukuki metinler (KVKK, mesafeli satış vb.) burada değil; onlar `apps/api/resources/views/legal/`
  altındaki 5d iskeletinde ve avukat onayı bekliyor (DECISIONS "Faz 5d").

## Kalan insan işi (bu paket bitince de kapanmaz)

1. Google Play Console + Apple Developer hesabı açma (şirket tüzel kişiliği, D-U-N-S no vb.).
2. Gerçek şirket bilgilerini (adres, telefon, destek e-postası, gizlilik politikası URL'i) doldurma.
3. Arayan-tanıma özelliğini kilitli/kilitsiz ekranda gösteren tanıtım videosunu çekme (BRIEF §4:
   "her iki mağazanın inceleme notlarına ... arayan-tanıma özelliğini gösteren bir video konur").
4. `USE_FULL_SCREEN_INTENT` "çekirdek işlev" beyanının Play Console'daki resmî formuna aktarılması.
5. Ekran görüntüleri / feature graphic gibi görsel varlıkların üretimi (bu pakette yok).
6. Play Console hesap-silme (data deletion) politikası sayfasının barındırılacağı gerçek URL —
   `play-data-safety.md`'de bu ihtiyaç not edildi, sayfa içeriği değil sadece gereksinim yazıldı.

Metinlerin kendisi mimari/kod değil; **hukuk incelemesi** bu paketi devralan `legal-reviewer`
ajanına devredildi (KVKK/mesafeli satış tutarlılığı için).
