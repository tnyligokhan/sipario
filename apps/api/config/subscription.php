<?php

/*
 * FAZ 5b — abonelik + ödeme yapılandırması (DECISIONS "Faz 5 — mimari"). Fiyat/paket YAPILANDIRILABİLİR
 * (iş kararı fiyatı beklemez). Para İMZASIZ int KURUŞ (float yok). iyzico anahtarları env-driven;
 * ÜRETİM anahtarı insan/PLAN işidir, sandbox varsayılanı boş (Fake ile test edilir).
 */
return [
    /*
     * 2026-08-04'TEN İTİBAREN BU BLOK YALNIZ YEDEKTİR. Fiyat, deneme süresi ve kotaların TEK DOĞRU
     * KAYNAĞI `plans` tablosudur (panelden düzenlenir; App\Abonelik\PlanDeposu okur). Buradaki
     * değerler yalnız plan satırı okunamadığında devreye girer — o durum ARIZAdır ama sitenin
     * "0 ₺" gösterip bedava abonelik açmasından iyidir.
     */

    // Aylık / yıllık abonelik fiyatı (kuruş). Tohum: 599 ₺/ay · 5.988 ₺/yıl (ayda 499 ₺).
    'price_monthly_kurus' => (int) env('SUBSCRIPTION_PRICE_MONTHLY_KURUS', 59900),
    'price_yearly_kurus' => (int) env('SUBSCRIPTION_PRICE_YEARLY_KURUS', 598800),

    // ESKİ ANAHTAR (yıllık) — geriye dönük uyumluluk için duruyor; yeni kod price_yearly_kurus okur.
    'price_kurus' => (int) env('SUBSCRIPTION_PRICE_KURUS', 598800),
    'currency' => env('SUBSCRIPTION_CURRENCY', 'TRY'),

    // Abonelik/deneme süreleri (gün). valid_until bu kadar ileri alınır.
    'period_days' => (int) env('SUBSCRIPTION_PERIOD_DAYS', 365),
    'trial_days' => (int) env('SUBSCRIPTION_TRIAL_DAYS', 30),

    // Plan kapsamındaki kotalar — yeni bayinin tenants kolonlarına tohumlanır.
    'route_credits_monthly' => (int) env('SUBSCRIPTION_ROUTE_CREDITS_MONTHLY', 50),
    'courier_limit' => (int) env('SUBSCRIPTION_COURIER_LIMIT', 3),

    /*
     * Hukuk metni SÜRÜMLERİ. Kabul edilen sürüm + zaman `subscription_payments`a yazılır (KVKK:
     * kart verisi ASLA; yalnız onay sürümü + zaman).
     *
     * 2026-08-19 — TÜM METİNLER BAŞTAN YAZILDI, sürümler bu tarihe çekildi. Eski değer 2026-07-15
     * bir İSKELETİ işaretliyordu ("PLACEHOLDER", hukuk onayı bekliyor); bugünkü metinler
     * mevzuata göre yazılmış TAM metinlerdir ve yalnız künye alanları eksiktir. Aynı sürüm
     * numarasını taşımaya devam etselerdi, 2026-07-15'te onay veren bir bayinin kabul ettiği
     * belge ile bugün kabul edilen belge kayıtta ayırt edilemez olurdu — onay kaydının tek işi
     * bu ayrımı yapabilmek.
     *
     * ⚠️ SÜRÜM ARTIRMA KURALI: metnin ANLAMI değişince (madde eklendi/çıktı, süre/koşul değişti)
     * sürüm ilerletilir. Yazım düzeltmesi sürümü değiştirmez — değiştirirse her tipo, sahadaki
     * her bayinin onayını "eski sürüme verilmiş" hâle getirir.
     */
    /*
     * ── DÖRT SÜRÜM DE 2026-09-01'E ÇIKTI ────────────────────────────────────────────────
     * Bu vardiyada belgelerin ESASA İLİŞKİN hükümleri değişti; sürüm artırmamak, bayinin
     * onayladığı metinle yayında duran metnin farklı olması demekti (onay kayıtları sürüm
     * anahtarını saklıyor — hangi bayinin neyi kabul ettiği ancak bu numaradan okunur).
     *
     * Hangi belge, ne değişti:
     *  · distance_sales — 14 günlük iade taahhüdü kaldırıldı (md. 8/9).
     *  · preinfo — aynı taahhüt ön bilgilendirmede ve İPTAL/İADE belgesinde kaldırıldı;
     *    iptal-iade belgesi bu anahtarı paylaşıyor ve baştan yazıldı.
     *  · kvkk — barındırmanın Almanya'da (Frankfurt) olduğu ve bunun bir YURT DIŞI AKTARIM
     *    sayıldığı, aydınlatma metnine ve gizlilik politikasına işlendi. Eski metin "veriler
     *    Türkiye'deki sunucuda" diyordu ve bu ölçülerek yanlışlandı.
     *  · terms — veri işleyen ekindeki alt işleyen tablosunda barındırma satırı düzeltildi.
     */
    'legal' => [
        'distance_sales_version' => env('LEGAL_DISTANCE_SALES_VERSION', '2026-09-01'),
        'preinfo_version' => env('LEGAL_PREINFO_VERSION', '2026-09-01'),
        'kvkk_version' => env('LEGAL_KVKK_VERSION', '2026-09-01'),
        // Üyelik/kullanım sözleşmesi ve veri işleyen eki AYRI sürüm hattı taşır: mesafeli satış
        // mevzuatı değişmeden bu ikisi değişebilir (ör. yeni bir alt işleyen eklenmesi).
        'terms_version' => env('LEGAL_TERMS_VERSION', '2026-09-01'),
    ],

    /*
     * Hukuk BELGELERİ: slug → başlık + sürüm anahtarı + (varsa) kısa açıklama. İçerik
     * `resources/views/legal/docs/<slug>.blade.php` partial'idir; route ve görünüm otomatik
     * (routes/web.php · legal.show). Yeni belge = buraya satır + bir partial.
     *
     * SIRA ÖNEMLİDİR: belge sayfasının sol sütunu ve alt bilginin "Yasal" sütunu bu sırayı
     * kullanır. Satış hattı (sözleşme → ön bilgi → iptal → kullanım) önce, veri hattı
     * (aydınlatma → gizlilik → açık rıza → veri işleyen → çerez → başvuru) sonra.
     *
     * `ozet` alanı iki yerde birden çalışır: belge sayfasının meta açıklaması (SEO) ve sol
     * sütundaki bağlantının `title`ı. İkinci bir yerde tekrar yazılmasın diye burada duruyor.
     */
    'legal_docs' => [
        'mesafeli-satis' => [
            'title' => 'Mesafeli Satış Sözleşmesi',
            'version_key' => 'distance_sales_version',
            'ozet' => 'Sipario aboneliğinin satışına ilişkin mesafeli sözleşme: taraflar, bedel, ifa, cayma ve fesih koşulları.',
        ],
        'on-bilgilendirme' => [
            'title' => 'Ön Bilgilendirme Formu',
            'version_key' => 'preinfo_version',
            'ozet' => 'Satıcı künyesi, hizmetin nitelikleri, toplam bedel, ödeme ve ifa şekli ile cayma hakkına ilişkin ön bilgilendirme.',
        ],
        'iptal-iade' => [
            'title' => 'İptal, Cayma ve İade Koşulları',
            'version_key' => 'preinfo_version',
            'ozet' => 'Aboneliği nasıl iptal edersiniz, cayma hakkı hangi hâlde işler, iade nasıl ve ne sürede yapılır.',
        ],
        'kullanim-kosullari' => [
            'title' => 'Kullanım Koşulları ve Üyelik Sözleşmesi',
            'version_key' => 'terms_version',
            'ozet' => 'Sipario hesabını kullanmanın kuralları: hesap güvenliği, kabul edilebilir kullanım, hizmet seviyesi, sorumluluk ve fesih.',
        ],
        'kvkk-aydinlatma' => [
            'title' => 'KVKK Aydınlatma Metni',
            'version_key' => 'kvkk_version',
            'ozet' => '6698 sayılı KVKK m.10 kapsamında aydınlatma: hangi kişisel veri, hangi amaçla, hangi hukuki sebeple işlenir ve kime aktarılır.',
        ],
        'gizlilik-politikasi' => [
            'title' => 'Gizlilik Politikası',
            'version_key' => 'kvkk_version',
            'ozet' => 'Verilerinizi nerede tutuyoruz, kim görebiliyor, ne kadar saklıyoruz ve nasıl koruyoruz — teknik ve idari tedbirler.',
        ],
        'acik-riza' => [
            'title' => 'Açık Rıza ve Ticari Elektronik İleti Metni',
            'version_key' => 'kvkk_version',
            'ozet' => 'Yalnız pazarlama iletileri ve isteğe bağlı ölçüm için istenen açık rıza — hizmetin kendisi rızaya bağlı değildir.',
        ],
        'veri-isleyen' => [
            'title' => 'Veri İşleyen Sözleşmesi (Ek-1)',
            'version_key' => 'terms_version',
            'ozet' => 'Bayinin kendi müşterilerine ait veriler için veri sorumlusu–veri işleyen ilişkisini kuran ek: talimat, güvenlik, alt işleyenler, ihlal bildirimi.',
        ],
        'cerez-politikasi' => [
            'title' => 'Çerez Politikası',
            'version_key' => 'kvkk_version',
            'ozet' => 'Sitede hangi çerezler kullanılıyor, hangileri zorunlu, hangileri açık rızaya bağlı ve tercihinizi nasıl değiştirirsiniz.',
        ],
        'kvkk-basvuru' => [
            'title' => 'İlgili Kişi Başvuru Formu',
            'version_key' => 'kvkk_version',
            'ozet' => 'KVKK m.11 haklarınızı kullanmak için başvuru yolu, zorunlu bilgiler ve 30 günlük yanıt süresi.',
        ],
    ],

    /*
     * ŞİRKET KÜNYESİ — bizim (satıcının) bilgileri. Havale talimatında, e-arşiv faturada, sitenin
     * alt bilgisinde ve mesafeli satış sözleşmesinde AYNI kaynaktan okunur; ikinci bir kopya
     * çıkarsa biri bayatlar ve bayi yanlış hesaba para gönderir.
     *
     * ⚠️ DEĞERLER HENÜZ GERÇEK DEĞİL — köşeli parantezli yer tutucular BİLEREK böyle. Ekranlarda
     * "[Şirket IBAN]" görünmesi, uydurma bir IBAN'ın gerçekmiş gibi görünmesinden İYİDİR: birinciyi
     * kimse kullanmaz, ikincisi paranın kaybolmasıdır. Şirket kurulup banka hesabı açılınca env'den
     * doldurulur; kod değişmez.
     *
     * BAYİNİN IBAN'IYLA KARIŞTIRMA: `tenants.iban` bayinin KENDİ müşterilerinden tahsilat yaptığı
     * hesaptır (borç hatırlatma mesajlarında kullanılır). Abonelik tahsilatında onu kullanmak,
     * bayinin parasını bize yönlendirmek olurdu.
     */
    'company' => [
        'title' => env('COMPANY_TITLE', '[Şirket unvanı]'),
        'address' => env('COMPANY_ADDRESS', '[Şirket adresi]'),
        'mersis' => env('COMPANY_MERSIS', '[MERSİS no]'),
        'tax_office' => env('COMPANY_TAX_OFFICE', '[Vergi dairesi ve no]'),
        'iban' => env('COMPANY_IBAN', '[Şirket IBAN]'),
        'bank' => env('COMPANY_BANK', '[Şirket bankası]'),
        'phone' => env('COMPANY_PHONE', '[Telefon]'),
        'email' => env('COMPANY_EMAIL', 'destek@sipario.com.tr'),
        // Destek kutusu: bayinin dışa aktarım/iptal gibi talepleri buraya düşer (BRIEF: "veri
        // rehin alınmaz" kapısı destek kanalından yürür). Genel e-postadan AYRI bir anahtar —
        // yarın bir talep kuyruğuna bağlanırsa kurumsal adres değişmeden yönü değişir.
        'support_email' => env('COMPANY_SUPPORT_EMAIL', env('COMPANY_EMAIL', 'destek@sipario.com.tr')),
        'hours' => env('COMPANY_HOURS', 'Hafta içi 09:00 – 19:00'),
    ],

    // iyzico (sandbox). SDK/HTTP entegrasyonu IyzicoPaymentGateway'de; anahtarlar env'den.
    'iyzico' => [
        'api_key' => env('IYZICO_API_KEY', ''),
        'secret_key' => env('IYZICO_SECRET_KEY', ''),
        'base_url' => env('IYZICO_BASE_URL', 'https://sandbox-api.iyzipay.com'),
    ],
];
