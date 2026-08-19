<?php

/*
 * ============================================================================================
 *  T E M S İ L İ   V E R İ  —  2026-08-19'DA   B O Ş A L T I L D I
 * ============================================================================================
 *
 *  Bu dosya bir zamanlar sitenin ana sayfasına şunları basıyordu:
 *
 *    • "1.240 işletme Sipario'yu her gün tezgâhın arkasında kullanıyor"
 *    • "%31 daha az kayıp — tahsil edilemeyen veresiye ilk altı ayda ortalama bu kadar düştü"
 *    • "6 dk — telefonu açmakla siparişi kaydetmek arasındaki süre kısaldı"
 *    • Üç isimli müşteri yorumu: Hasan Yıldırım (Yıldırım Su · Antalya, "9 ay kullanıyor"),
 *      Necla Aksoy (Aksoy Tüp · Konya), Serkan Demir (Demir Market · İzmir)
 *
 *  BUNLARIN HİÇBİRİ GERÇEK DEĞİLDİ. Tasarım prototipinin örnek verisiydi. Ürün pilot
 *  aşamasında: BRIEF hedefi "ilk 6 ayda 20–50 ödeyen bayi", saha testi Antalya'da 2–3 bayiyle
 *  yapılacak. Yani 1.240 işletme yoktu, o üç kişi yoktu, %31'i ölçen bir çalışma yoktu.
 *
 *  ── NEDEN "DÜZELTİLMEDİ" DE SİLİNDİ ────────────────────────────────────────────────────
 *  Bu vardiyanın işi "metinleri doğallaştırmaktı" ve buradaki metinler sitenin en YAPAY
 *  yeriydi — ama sorunları üslup değildi. Uydurma bir yorumu daha doğal bir Türkçeyle yeniden
 *  yazmak, onu daha inandırıcı bir uydurma yapardı; yani işi kötüleştirirdi.
 *
 *  Hukuken de savunulacak yanı yoktu. Ticari Reklam ve Haksız Ticari Uygulamalar Yönetmeliği,
 *  ispatlanamayan nicel iddiaları ve gerçek olmayan tüketici deneyimlerini aldatıcı reklam
 *  sayar; yaptırımı Reklam Kurulu'ndadır. Aynı vardiyada mevzuata uygun hukuk metinleri
 *  yazarken ana sayfada uydurma müşteri yorumu tutmak, iki işi birden değersizleştirirdi.
 *
 *  Eski dosya "yayına çıkmadan önce ZORUNLU: ya gerçek rakamlarla değiştirilecek YA DA
 *  bölümler kaldırılacak" diyordu. Site 2026-08-07'den beri CANLI. Yani o zorunluluğun
 *  tarihi geçmişti; bu vardiya ikinci şıkkı uyguladı.
 *
 *  ── DÜZEN BOZULMUYOR ───────────────────────────────────────────────────────────────────
 *  `ana-kanit.blade.php` ve `ana-yorum.blade.php` boş diziye karşı KORUMALIYDI (`@if (! empty(…))`)
 *  — bölümler sayfadan tamamen düşer, boşluk kalmaz. Bu koruma eski dosyanın kendi notunda
 *  zaten vaat ediliyordu; ölçüldü, çalışıyor.
 *
 *  Kaybolan anlatı boşluğu, ana sayfada uydurma olmayan bir bölümle karşılandı: ürünün ne
 *  YAPTIĞINI söyleyen "güvence" ve "dert" bölümleri zaten oradaydı ve onlar doğrulanabilir.
 *
 *  ── GERİ NASIL GELİR ───────────────────────────────────────────────────────────────────
 *  Gerçek bayilerle çalışılmaya başlandığında:
 *    1. YORUM: bayiden YAZILI İZİN alınır (adı, işletmesi ve cümlesi yayımlanacak). İzinsiz
 *       yorum, KVKK açısından da ayrı bir sorundur — ad ve işletme bilgisi kişisel veridir.
 *    2. RAKAM: iddia ÖLÇÜLMÜŞ olmalı ve nasıl ölçüldüğü söylenebilmelidir. "12 bayide 3 ay
 *       boyunca ölçüldü" denebiliyorsa yayımlanır; denemiyorsa yayımlanmaz.
 *  İki dizi de aşağıda yapısıyla duruyor; doldurmak yeter, bileşenlere dokunulmaz.
 *
 *  Kullanıldığı yerler:
 *    kanit      → site/parca/ana-kanit.blade.php      (ana sayfa · 2. bölüm — şu an basılmıyor)
 *    yorum      → site/parca/ana-yorum.blade.php      (ana sayfa · 7. bölüm — şu an basılmıyor)
 *    planRozet  → KULLANILMIYOR (tek plana geçişte kaldırıldı)
 *
 * ============================================================================================
 */

return [
    /*
     * Sayısal kanıt şeridi. Beklenen biçim:
     *   ['v' => '12', 'b' => 'bayi', 'a' => 'Antalya pilotunda üç ay boyunca her gün kullandı']
     * KURAL: 'a' alanı iddianın NASIL ölçüldüğünü söyleyebilmeli. Söyleyemiyorsa satır yazılmaz.
     */
    'kanit' => [],

    /*
     * Müşteri yorumları. Beklenen biçim:
     *   ['s' => 'cümle', 'k' => 'Ad Soyad', 'r' => 'İşletme · Şehir', 'm' => 'N aydır kullanıyor']
     * KURAL: yayımlanmadan önce bayiden YAZILI izin alınmış olmalı.
     */
    'yorum' => [],

    /*
     * Plan kartının rozeti. Satılan tek plan olduğu için anlamsız ("işletmelerin %90'ı bunu
     * seçiyor" cümlesi ancak seçenek varken bir şey ifade eder). Anahtar, ikinci bir plan geri
     * gelirse nereye takılacağı belli olsun diye null olarak duruyor.
     */
    'planRozet' => null,
];
