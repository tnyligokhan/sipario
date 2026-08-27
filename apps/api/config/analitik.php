<?php

/*
 * ÖLÇÜM (analytics) YAPILANDIRMASI — 2026-08-19.
 *
 * ── NEDEN AYRI BİR CONFIG DOSYASI ────────────────────────────────────────────────────────────
 * Ölçüm kimliğini doğrudan bir Blade dosyasına gömmek üç şeyi birden bozardı: (1) test ortamı
 * gerçek mülke veri yollardı, (2) yerel geliştirmede her sayfa yenilemesi rapora düşerdi,
 * (3) kimliği değiştirmek için görünüm dosyası düzenlemek gerekirdi. Burada tek satır env yeter.
 *
 * ── ÜÇ KAPI: KİMLİK + ORTAM + RIZA ───────────────────────────────────────────────────────────
 * Ölçüm ancak ÜÇÜ birden açıkken çalışır ve üçü farklı soruları cevaplar:
 *
 *   1. KİMLİK — `measurement_id` boşsa hiçbir etiket basılmaz. Anahtarsız kurulum sessizce
 *      çalışır, konsola hata düşmez.
 *   2. ORTAM  — `enabled` varsayılanı `APP_ENV === 'production'`. Testte ve yerelde ölçüm
 *      KAPALIDIR; açmak isteyen `ANALITIK_ETKIN=true` der. Bu, "test koşusu 400 sayfa ziyareti
 *      üretti" tuzağını kapatır.
 *   3. RIZA   — ziyaretçi çerez bandında onay VERMEDİKÇE `googletagmanager.com`a HİÇ İSTEK
 *      GİTMEZ (public/js/olcum.js betiği etiketi rıza sonrası enjekte eder). KVK Kurulu'nun
 *      çerez rehberi, zorunlu olmayan çerezlerde ÖNCEDEN rıza arar; "kullanmaya devam ederseniz
 *      kabul etmiş sayılırsınız" geçerli bir rıza değildir.
 *
 * ── GA4 mi GTM mi? ───────────────────────────────────────────────────────────────────────────
 * İkisi de destekleniyor ve ikisi de İSTEĞE BAĞLI:
 *   • Yalnız `ANALITIK_GA4_ID` doluysa → doğrudan gtag.js (bugünkü kurulum).
 *   • `ANALITIK_GTM_ID` de doluysa     → GTM konteyneri yüklenir, GA4 etiketi GTM içinden
 *     yönetilir. Kod tarafında değişiklik gerekmez; GTM hesabı açıldığı gün tek env satırı.
 * GTM olmadan da her şey çalışır — konteyner açılmasını beklemek, ölçümü hiç başlatmamak olurdu.
 *
 * ── DÖNÜŞÜM OLAYLARI ─────────────────────────────────────────────────────────────────────────
 * Aşağıdaki `olaylar` listesi belgedir, kod değil: hangi olayın hangi anlama geldiğini tek
 * yerde tutar. Olaylar `public/js/olcum.js` içindeki `siparioOlay()` ile gönderilir ve
 * görünümlerde `data-olcum="<ad>"` özniteliğiyle işaretlenir. Yeni bir düğmeye ölçüm eklemek
 * için JS'e dokunulmaz — özniteliği koymak yeter.
 */
return [
    // G-XXXXXXXXXX biçiminde GA4 ölçüm kimliği. Boşsa ölçüm hiç kurulmaz.
    'measurement_id' => env('ANALITIK_GA4_ID', 'G-6SGNK7B0ZK'),

    // GTM-XXXXXXX biçiminde konteyner kimliği. Boş bırakılabilir — GA4 doğrudan çalışır.
    'gtm_id' => env('ANALITIK_GTM_ID', ''),

    // Ortam kapısı. Varsayılan: yalnız üretimde.
    'enabled' => (bool) env('ANALITIK_ETKIN', env('APP_ENV') === 'production'),

    /*
     * ⚠️ RIZA ÇEREZİ BURADA DEĞİL — `config/cerezler.php`de (taşındı: 2026-08-28).
     *
     * Buraya geri KONULMAMALI. Rıza yönetimi ölçümün alt başlığı değildir: zorunlu çerezler
     * (oturum, CSRF, rızanın kendisi) ölçüm kapalıyken de vardır ve aynı rıza altyapısı yarın
     * ölçüm dışında bir kategori de taşıyabilir. Ayarı burada tutmak "ölçüm yoksa çerez de yok"
     * denklemini kurardı ve o denklem yanlıştır.
     *
     * Okuma yolu: App\Support\Cerez\CerezEnvanteri (hem pencere, hem belge, hem JS aynı kaynağı
     * kullanır).
     */

    /*
     * İZLENEN DÖNÜŞÜMLER. Ad → ne anlama geldiği. GA4'te "anahtar olay" (conversion) olarak
     * işaretlenecek olanlar `donusum` sütununda true.
     *
     * ⚠️ İSİMLER TÜRKÇE DEĞİL, GA4 KURALINA UYGUN: küçük harf + alt çizgi, 40 karakter sınırı.
     * GA4 bazı adları (`sign_up`, `login`, `purchase`, `begin_checkout`) ÖNERİLEN OLAY olarak
     * tanır ve raporlarında özel yer verir; onlar bilerek İngilizce bırakıldı. Ürüne özel
     * olanlar `sipario_` ön ekiyle ayrıldı ki standart olaylarla karışmasın.
     */
    'olaylar' => [
        'sipario_kayit_basladi' => ['ne' => 'Kayıt sihirbazının ilk adımı görüntülendi', 'donusum' => false],
        'sign_up' => ['ne' => 'İşletme açıldı — deneme başladı', 'donusum' => true],
        'login' => ['ne' => 'Bayi hesap paneline giriş yaptı', 'donusum' => false],
        'begin_checkout' => ['ne' => 'Abonelik ödeme adımı açıldı', 'donusum' => true],
        'sipario_odeme_beyani' => ['ne' => 'Havale/elden ödeme beyanı gönderildi', 'donusum' => true],
        'purchase' => ['ne' => 'Ödeme onaylandı, abonelik aktive edildi', 'donusum' => true],
        'sipario_iletisim' => ['ne' => 'İletişim formu gönderildi', 'donusum' => true],
        'sipario_telefon_tik' => ['ne' => 'Telefon numarasına tıklandı', 'donusum' => true],
        'sipario_whatsapp_tik' => ['ne' => 'WhatsApp bağlantısına tıklandı', 'donusum' => true],
        'sipario_deneme_tik' => ['ne' => 'Ücretsiz deneme düğmesine tıklandı (henüz kaydolmadı)', 'donusum' => false],
        'sipario_fiyat_goruntuleme' => ['ne' => 'Fiyat bölümü ekrana girdi', 'donusum' => false],
        'sipario_sss_acildi' => ['ne' => 'Bir sık sorulan soru açıldı', 'donusum' => false],
    ],
];
