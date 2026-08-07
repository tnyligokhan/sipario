<?php

/*
 * ============================================================================================
 *  ⚠️  T E M S İ L İ   V E R İ  —  G E R Ç E K   D E Ğ İ L D İ R
 * ============================================================================================
 *
 *  Bu dosyadaki HER RAKAM VE HER YORUM UYDURMADIR. Tasarım prototipinin örnek verisidir
 *  (design_handoff_web_and_yonetim_paneli/_kaynak/web/05-sw-veri.jsx · SW_KANIT, SW_YORUM,
 *  SW_PLAN[0].rozet). Kaynak dosyanın kendi ilk satırı da bunu söylüyor: "Tümü örnek/temsili."
 *
 *  ÜRÜN HENÜZ PİLOT AŞAMASINDADIR (BRIEF: ilk 6 ayda 20–50 ödeyen bayi hedefi, Antalya'da 2–3
 *  bayiyle saha testi). "1.240 işletme", "%31 daha az kayıp", "%90'ı bunu seçiyor" gibi ifadeleri
 *  ve isimli müşteri yorumlarını gerçekmiş gibi yayınlamak YANLIŞ BEYANDIR.
 *
 *  ─────────────────────────────────────────────────────────────────────────────────────────
 *  YAYINA ÇIKMADAN ÖNCE ZORUNLU: aşağıdaki üç blok ya GERÇEK, doğrulanabilir rakam ve gerçek
 *  (izin alınmış) müşteri yorumlarıyla değiştirilecek, YA DA ilgili bölümler siteden
 *  KALDIRILACAKTIR. Diziyi boşaltmak (`[]`) bölümü sayfadan düşürür — parçalar boş diziye karşı
 *  korumalıdır, düzen bozulmaz.
 *  ─────────────────────────────────────────────────────────────────────────────────────────
 *
 *  Alt bilgideki "Bu sayfadaki rakamlar örnektir" notu bu dosya durduğu sürece KORUNMALIDIR.
 *
 *  Kullanıldığı yerler:
 *    kanit      → site/parca/ana-kanit.blade.php      (ana sayfa · 2. bölüm)
 *    yorum      → site/parca/ana-yorum.blade.php      (ana sayfa · 7. bölüm)
 *    planRozet  → KULLANILMIYOR (tek plana geçişte kaldırıldı — aşağıdaki nota bakın)
 *
 * ============================================================================================
 */

return [
    // Ana sayfa · sayısal kanıt şeridi. UYDURMA.
    'kanit' => [
        ['v' => '1.240', 'b' => 'işletme', 'a' => 'Sipario’yu her gün tezgâhın arkasında kullanıyor'],
        ['v' => '6 dk', 'b' => 'sipariş başına', 'a' => 'Telefonu açmakla siparişi kaydetmek arasındaki süre kısaldı'],
        ['v' => '%31', 'b' => 'daha az kayıp', 'a' => 'Tahsil edilemeyen veresiye, ilk altı ayda ortalama bu kadar düştü'],
    ],

    // Ana sayfa · müşteri yorumları. UYDURMA KİŞİLER, UYDURMA İŞLETMELER, UYDURMA SÜRELER.
    'yorum' => [
        ['s' => 'Defteri bıraktık. Ay sonunda tahsil edemediğimiz para 12 binden 3 bine düştü.', 'k' => 'Hasan Yıldırım', 'r' => 'Yıldırım Su · Antalya', 'm' => '9 ay Sipario kullanıyor'],
        ['s' => 'Telefonu açınca adamın adını söylüyoruz, adresi zaten ekranda. Müşteri “beni tanıdınız” diyor.', 'k' => 'Necla Aksoy', 'r' => 'Aksoy Tüp · Konya', 'm' => '1 yıl 2 ay Sipario kullanıyor'],
        ['s' => 'İki kuryeyle çalışıyoruz. Sıralamayı uygulama kuruyor, günde bir tur azaldı.', 'k' => 'Serkan Demir', 'r' => 'Demir Market · İzmir', 'm' => '5 ay Sipario kullanıyor'],
    ],

    /*
     * Plan kartının rozeti. UYDURMA ORAN — ve 2026-08-05'ten beri ANLAMSIZ: satılan tek plan var,
     * "işletmelerin %90'ı bunu seçiyor" cümlesi seçenek varken bir şey ifade eder. Rozet iki
     * karttan da (ana sayfa + fiyat sayfası) kaldırıldı; anahtar, ikinci bir plan geri gelirse
     * nereye takılacağı belli olsun diye null olarak duruyor.
     */
    'planRozet' => null,
];
