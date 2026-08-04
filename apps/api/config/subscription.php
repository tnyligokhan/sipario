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

    // Hukuk metni SÜRÜMLERİ (5d ile örtüşür; tam metin insan/hukuk onayı — PLACEHOLDER). Kabul edilen
    // sürüm + zaman subscription_payments'a yazılır (KVKK: kart verisi ASLA; yalnız onay sürümü + zaman).
    'legal' => [
        'distance_sales_version' => env('LEGAL_DISTANCE_SALES_VERSION', '2026-07-15'),
        'preinfo_version' => env('LEGAL_PREINFO_VERSION', '2026-07-15'),
        'kvkk_version' => env('LEGAL_KVKK_VERSION', '2026-07-15'),
    ],

    // Hukuk BELGELERİ (5d iskeleti): slug → başlık + sürüm anahtarı (yukarıdaki 'legal'den çözülür) + içerik
    // partial'i (resources/views/legal/docs/<slug>.blade.php). Metinler PLACEHOLDER — TAM METİN + HUKUK ONAYI
    // İNSAN İŞİDİR (PLAN "SENİN SIRAN"). Checkout onay kutuları bu belgelere link verir; kabul edilen sürüm
    // subscription_payments'a yazılır. Yeni belge = buraya satır + bir partial (route/view otomatik).
    'legal_docs' => [
        'mesafeli-satis' => ['title' => 'Mesafeli Satış Sözleşmesi', 'version_key' => 'distance_sales_version'],
        'on-bilgilendirme' => ['title' => 'Ön Bilgilendirme Formu', 'version_key' => 'preinfo_version'],
        'iptal-iade' => ['title' => 'İptal ve İade Koşulları', 'version_key' => 'preinfo_version'],
        'kvkk-aydinlatma' => ['title' => 'KVKK Aydınlatma Metni ve Açık Rıza', 'version_key' => 'kvkk_version'],
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
