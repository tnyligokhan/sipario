# YAPILACAKLAR — Sipario (proje sahibi/insan işleri)

> **Bu döküman kimin için?** Yazılım tarafı büyük ölçüde bitti; ilerlemenin önündeki her şey artık
> **senin elindeki dışsal girdiler** (anahtar, hesap, cihaz, avukat, saha). Bu liste, Claude'un
> bitiremeyeceği — sana ihtiyaç duyan — TÜM işleri tek yerde toplar.
>
> **Son güncelleme:** 2026-07-16 · **Kaynak:** 3 ajanlı uçtan-uca denetim (audit-phases + audit-redlines
> + audit-external-deps) + kod taraması. **Genel yazılım durumu:** ~%79 (sunucu kodu Faz 0–5 TAM ve
> incelendi, test 169/169 yeşil). Ayrıntılı yol haritası: `PLAN.md`; kararlar: `DECISIONS.md`.

---

## Nasıl kullanılır

Her kalem şu formatta: **NE** (yapılacak) · **NEDEN** (hangi faz/kural bağlar) · **NASIL** (somut adım) ·
**Kanıt** (kod/dosya). Kalemler öncelik sırasında: 🔴 KRİTİK YOL → 🟡 ÖNEMLİ → 🟢 KÜÇÜK. Bir kalemi
bitirince ilgili faz kapanışına yaklaşırsın; hangisini önce açtığın bende bir sonraki kod işini tetikler
(örn. iyzico anahtarı gelince ödeme akışını canlı bağlarım).

---

## 🔴 KRİTİK YOL — bunlar olmadan ürün satılamaz / mağazaya çıkamaz

### 1. iyzico üretim hesabı + API anahtarları
- **NEDEN:** Faz 5 ödeme kodu GÜVENLİK olarak fail-closed kuruldu ama **gerçek iyzico'ya hiç bağlanmadı**;
  anahtar olmadan abonelik tahsilatı canlıya çıkamaz.
- **NASIL:** Önce **sandbox** hesabı aç → `IYZICO_API_KEY` + `IYZICO_SECRET_KEY`'i bana ver (`.env`'e
  girerim). Ben sandbox'ta ödeme akışını canlı bağlayıp **güvenlik testini** koşarım. Sonra **üretim**
  anahtarları.
- **⚠️ PAZARLIKSIZ GÜVENLİK:** anahtar gelince `verify()` sandbox'ta MUTLAKA sınanmalı — (a) forged-body
  reddi, (b) gerçek `retrieve` geri-sorgusu, (c) IYZWSv2 imza. **Smoke-test yetmez** (gövde-güven = bedava
  abonelik açığı).
- **Kanıt:** `apps/api/config/subscription.php:38-40`, `apps/api/app/Payment/IyzicoPaymentGateway.php`.

### 2. Mobil doğrulama (partnerin Flutter'lı makinesinde)
- **NEDEN:** Bu makinede Flutter yok; Faz 4/5a mobil kodu yazıldı ama `.g.dart` STALE (şema-kod uyumsuz),
  test edilemedi. Yeşilse **Faz 4 ve 5a bütün olarak kapanır.**
- **NASIL:** Partnerde: pubspec'teki kapalı `dependency_overrides: sqlite3 <3.0.0` bloğunu **geçici aç** →
  `flutter pub get && dart run build_runner build` → override'ı **kapat** → `flutter pub get && flutter
  analyze && flutter test`. Yeşil çıktıyı bana ilet.
- **Kanıt:** `apps/mobile/lib/data/app_database.g.dart` (Faz 3 tarihli) vs `tables.dart` (Faz 4/5a).

### 3. Android release imza anahtarı  ⭐ YENİ (PLAN'da yoktu, denetim buldu)
- **NEDEN:** `release` derleme hâlâ **debug** anahtarıyla imzalanıyor — debug-imzalı AAB/APK **Play'e
  yüklenemez.** Mağaza başvurusundan ÖNCE gerçek upload/release keystore şart.
- **NASIL:** Play Console'da **Play App Signing** kaydı yap; `keytool -genkeypair` ile upload keystore üret,
  parolasını **güvenli sakla** (kaybolursa uygulama bir daha güncellenemez), `build.gradle.kts`'e bağla
  (kod bağlamayı ben yapabilirim, anahtar üretimi/saklama sende).
- **Kanıt:** `apps/mobile/android/app/build.gradle.kts:32-36` (`// TODO: Faz 6'da kendi imza anahtarımız`).

### 4. Apple + Google Play geliştirici hesapları (tüzel kişilik)
- **NEDEN:** Mağaza başvurusu için zorunlu.
- **NASIL:** Google Play Console (kurumsal) + Apple Developer Program. **Apple kurumsal hesap D-U-N-S
  numarası ister** — yoksa D-U-N-S başvurusu haftalar sürebilir, **ERKEN başla**.
- **Kanıt:** `docs/magaza/README.md`, `BRIEF.md` (mağaza kuralları).

### 5. Mac + Xcode (iOS derleme/imzalama)  ⭐ YENİ
- **NEDEN:** `apps/mobile/ios/` iskeleti var ama HİÇ derlenmedi/imzalanmadı; App Store başvurusu
  Mac + Xcode + Apple sertifikası gerektirir. Ekipte kimde olduğu belirsiz — netleştir.
- **Kanıt:** DECISIONS "Faz 4 — mimari" (iOS doğrulaması ertelendi, Mac yok).

### 6. Hukuk metinlerinin AVUKAT onayı + [köşeli] alanların doldurulması
- **NEDEN:** 4 hukuk belgesi + hesap-silme sayfası TASLAK; şirket bilgileri ve hukuki kararlar boş.
- **NASIL — avukata götür:**
  - Doldurulacak: **şirket unvanı, açık adres, MERSİS no, telefon, e-posta, KEP, KDV oranı, yetkili
    mahkeme, iade/iptal süreleri, saklama süreleri, alt-yüklenici aktarım listesi.**
  - Karara bağlanacak (her belgede `<!-- HUKUK NOTU -->`): **B2B/tacir muhatapta cayma hakkı istisnası**
    (m.15/1-ğ) ve 30 gün deneme ilişkisi; pazarlama açık rızası gerekip gerekmediği.
- **Kanıt:** `apps/api/resources/views/legal/docs/*.blade.php`, `.../legal/hesap-silme.blade.php`.

### 7. Site domain TLS + gerçek prod ortam (sipario.com.tr)
- **NEDEN:** Panel/site tarayıcı erişimi için; deploy öncesi.
- **NASIL:** Prod sunucu (TR VPS + Docker, DECISIONS) + TLS sertifikası; `.env`'e
  `CORS_ALLOWED_ORIGINS=https://sipario.com.tr` yaz (boşsa tarayıcı reddedilir).
- **Kanıt:** `apps/api/config/cors.php` (env boş varsayılan), `PLAN.md` "SENİN SIRAN".

---

## 🟡 ÖNEMLİ — kritik yolu bloklamaz ama Faz 6/7 kapanışı için şart

### 8. Mağaza başvuru paketindeki kalan PLACEHOLDER'lar (`docs/magaza/`)
- **Arayan-tanıma tanıtım videosu** (kilitli+kilitsiz ekran) — HENÜZ ÇEKİLMEDİ; BRIEF mağaza incelemesi
  için zorunlu sayıyor. Demo hesapla çek (`demo@sipario.com.tr` / `demo1234`). `inceleme-notlari.md`.
- **Destek e-postası/telefonu** — üç mağaza dosyasında [köşeli].
- **Ekran görüntüleri + feature graphic** — hiç üretilmedi (görsel iş).
- **`USE_FULL_SCREEN_INTENT` "çekirdek işlev" beyanı** — metin hazır, Play Console formuna elle aktarılacak.
- **Play data-safety: disk şifreleme + bağımsız güvenlik incelemesi** soruları — VPS seçimine bağlı.

### 9. e-arşiv fatura sağlayıcı  ⭐ YENİ (BRIEF'te var, kodda hiç yok)
- **NEDEN:** Yasal gereklilik; hukuk metni "fatura elektronik iletilir" diyor ama entegrasyon SIFIR.
- **NASIL:** Bir e-arşiv/e-fatura entegratörü seç (iş kararı) + API bilgilerini ver → ben bağlarım.
- **Kanıt:** `BRIEF.md` (yasal gereklilikler), `mesafeli-satis.blade.php:22`; kodda grep = 0 sonuç.

### 10. VERBİS kaydı (Veri Sorumluları Sicili)  ⭐ YENİ
- **NEDEN:** KVKK metni şirketi "veri sorumlusu" ilan ediyor; çalışan sayısı/veri hacmine göre VERBİS
  kaydı zorunlu olabilir. İdari/hukuki adım — avukat/DPO ile değerlendir.
- **Kanıt:** `kvkk-aydinlatma.blade.php`.

### 11. `sipario_panel` DB rolü + `.env` (yeni makine/prod)
- **NEDEN:** Rol küme düzeyinde elle kuruldu; docker init yalnız İLK initdb'de çalışır. Prod/yeni makinede
  unutulursa panel bağlantısı düşer.
- **NASIL:** Rol SQL'ini elle koş (Faz 1 `sipario_app` deseni) + `.env`'e `DB_PANEL_USERNAME=sipario_panel`
  + `DB_PANEL_PASSWORD=...` ekle (araç `.env*`'i koruduğu için elle). CI'a zaten eklendi.
- **Kanıt:** `PLAN.md` "SENİN SIRAN", DECISIONS "Faz 5c-1".

### 12. Antalya pilotu (Faz 7)
- **NEDEN:** Gerçek doğrulama. 2–3 gerçek bayi + gerçek Android cihaz + saha ziyareti.
- **NASIL:** Pilotun ilk haftasında **20 aramalık sistematik arayan-tanıma ölçümü** (ölçüm ekranı üründe
  hazır). MIUI izinlerini Xiaomi'li bayide **birlikte** kur (programla verilemiyor).
- **Kanıt:** `BRIEF.md`, DECISIONS "Faz 0 kapanışı".

---

## 🟢 KÜÇÜK — akışı bloklamaz, unutulmasın

- **13. PR #11 (dev→main) merge** — Faz 3+4+5'i main'e taşır; merge düğmesi sende. *(Not: dal o günden beri
  ilerledi; PR'ı güncel dev'den yeniden gözden geçir.)*
- **14. Transactional mail yok** — `MAIL_MAILER=log`; panel "patron şifre sıfırlama" yeni şifreyi ekranda
  gösteriyor, e-posta göndermiyor. E-posta ile iletilecekse mail sağlayıcı (Postmark/Resend) anahtarı gerekir.
- **15. Drift `journal_mode=TRUNCATE`** gerçek Android cihazda doğrulanmadı (native salt-okunur açıcı WAL
  riski) — Faz 6 native entegrasyonunda sınanacak.
- **16. `sipario_panel` CI şifresi** `sipario_panel_dev` sabit — prod'a giderken değiştir (madde 11 ile).
- **17. Stok Android gerçek cihaz testi** — yalnız emülatörde; pilot Xiaomi/Samsung ağırlıklı, risk düşük ama açık.
- **18. Marka başvurusu** (9/35/42 sınıfları) süreçte — durumu takip et (BRIEF).

---

## ✅ Güvence — kod düzeyinde doğrulanan (senden bir şey İSTEMEYEN) kısımlar

Uçtan-uca denetim, PLAN/DECISIONS'ın "kapandı" dediği her şeyi gerçek kodla çapraz-doğruladı; uydurma/abartı
bulunmadı. BRIEF'in **6 kırmızı çizgisi** kod düzeyinde yerinde:
- **Kiracı izolasyonu:** her tabloda PostgreSQL RLS ENABLE+FORCE + güvenli-varsayılan politika; `sipario_app`
  NOSUPERUSER/NOBYPASSRLS; panel export'unda 12 tabloda açık `tenant_id` filtresi; CI cross-tenant matrisi.
- **Append-only para:** `ledger_entries`/`order_events`/`coupon_movements`'ta DB seviyesinde UPDATE/DELETE
  REVOKE (42501).
- **Offline-first:** outbox + `client_event_id` idempotency + `FOR UPDATE` monoton seq + çakışma birleşme.
- **KVKK:** API kodunda PII log'u yok; müşteri verisi TR sunucu kararı.
- **Veri rehin alınmaz:** kilitliyken outbox akar; panel export var; hesap-silme yalnız talep üzerine.
- **iyzico verify() fail-closed:** gövdedeki `paymentStatus`'a güvenmiyor, sunucu-sunucu retrieve + tutar
  eşleşmesiyle karar veriyor (yapısal, smoke değil).

> Bu bölüm "yapılacak" değil, **"için rahat olsun"** bölümüdür. Tek istisna: bu güvenceler **kod** düzeyinde;
> **canlı** doğrulama (iyzico gerçek anahtar, mobil gerçek cihaz, pilot) yukarıdaki kritik-yol kalemlerinde.

---

## Önerilen başlangıç sırası

1. **iyzico sandbox anahtarı** (madde 1) → bana ver, ödeme akışını canlı bağlayıp güvenlik testini koşayım.
2. **Mobil codegen** (madde 2) → partnere koştur, Faz 4/5a kapansın.
3. **Apple D-U-N-S + mağaza hesapları** (madde 4) → uzun sürebilir, paralelde erken başlat.
4. **Avukat + release imza anahtarı** (madde 6, 3) → mağaza başvurusunun ön koşulları.
