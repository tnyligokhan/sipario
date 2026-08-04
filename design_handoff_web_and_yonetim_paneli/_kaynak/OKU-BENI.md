# Tasarım referansı — Web sitesi + Yönetim paneli

Bu klasör, kök dizindeki iki `.html` dosyasından **çıkarılmış kaynak koddur**. `.html` dosyaları
paketlenmiş (base64+gzip manifest) React artefaktlarıdır; okunamazlar. Buradaki `.jsx` ve `.css`
dosyaları o paketlerin İÇİNDEN çıkmıştır ve **tasarımın tek okunabilir hâlidir**.

- `web/` — sipario.com.tr genel sitesi + bayinin hesap paneli (14 modül)
- `yonetim/` — bize ait iç yönetim paneli (9 modül)
- Her klasördeki `_style.css` o uygulamanın TAM stil sayfasıdır (font-face blokları çıkarıldı).
- Dosya adlarının başındaki numara, tarayıcıdaki yükleme sırasıdır (bağımlılık sırası).

## Bunlar prototiptir, hedef değildir

Kaynaklar React + `window` global'leri kullanır ve veri gömülüdür. **Hedef stack React DEĞİL**:
Blade + Livewire 3 + Alpine.js (gerekçe DECISIONS.md). Bu dosyalardan taşınacak olan:

1. **CSS birebir** — `_style.css` neredeyse hiç değiştirilmeden `resources/css/` altına gider.
   Sınıf adları sözleşmedir; JSX'te `className="kart-baslik"` varsa Blade'de de `class="kart-baslik"` olur.
2. **Ekran yapısı ve metinler birebir** — başlıklar, boş durum cümleleri, yardım metinleri,
   buton etiketleri, modal bilgi kutuları. Bunlar tasarım kararıdır, kopya iyileştirmesi YAPILMAZ.
3. **Etkileşim davranışı** — hangi buton neyi açar, hangi alan ne zaman pasif, hangi uyarı
   ne zaman çıkar.

## Taşınmayacak olanlar

- `web/05-sw-veri.jsx` ve `yonetim/03-BUGUN.jsx` içindeki **veri** (firmalar, ödemeler, faturalar,
  yorumlar, rakamlar) örnektir. Şekli referans, içeriği değil.
- `web/07-sw-telefon.jsx` — sitede gösterilen mobil uygulama maketi. Saf sunum; CSS + statik
  HTML olarak taşınır, gerçek veriye bağlanmaz.
- React'e özgü her şey (`useState`, portal, `window.X = X` ihracı).
- Fiyat rakamları — bkz. aşağıdaki çelişki notu.

## Bilinen çelişkiler (karar verildi)

| Konu | Web tasarımı | Yönetim tasarımı | BRIEF | **KARAR** |
|---|---|---|---|---|
| Dönem | aylık + yıllık | aylık | yalnız yıllık | **aylık + yıllık** |
| Deneme | 14 gün | 14 gün | 30 gün | **30 gün** |
| Fiyat | 599 ₺/ay · 499 ₺/ay (yıllık) | 399 ₺/ay | — | **panelden düzenlenebilir; tohum 599/499** |
| Ödeme | havale/EFT + elden, kart "yakında" | IBAN + Elden + Bedelsiz | iyzico | **IBAN/havale + elden; iyzico ERTELENDİ** |

Deneme süresi metinleri ("14 gün ücretsiz") **30 gün** olarak taşınır — yoksa site sunucuyla yalan söyler.

## Tasarımda OLMAYAN ama panelde KALMASI zorunlu olanlar

BRIEF kırmızı çizgileri ve mevcut çalışan işlevler. Tasarım dilinde yeniden yerleştirilir, silinmez:

- Bayinin iş verisini görme (müşteri/sipariş/defter/ürün, salt-okunur)
- Müşteri CSV içe/dışa aktarma, sipariş CSV dışa aktarma, JSON dump (BRIEF: "veri rehin alınmaz")
- Denetim günlüğü (`panel_audit`) — KVKK izi
- Panel yönetici hesapları (superadmin/support, pasifleştirme)
- Bayi bazında modül aç/kapa (BRIEF md. 3)
- Patron parola sıfırlama, cihaz listesi (BRIEF md. 3)
- Kullanım/churn istatistikleri (BRIEF md. 3)
