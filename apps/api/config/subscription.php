<?php

/*
 * FAZ 5b — abonelik + ödeme yapılandırması (DECISIONS "Faz 5 — mimari"). Fiyat/paket YAPILANDIRILABİLİR
 * (iş kararı fiyatı beklemez). Para İMZASIZ int KURUŞ (float yok). iyzico anahtarları env-driven;
 * ÜRETİM anahtarı insan/PLAN işidir, sandbox varsayılanı boş (Fake ile test edilir).
 */
return [
    // Yıllık abonelik fiyatı (kuruş). Örn. 1200,00 TL = 120000 kuruş. Env ile üretimde değişir.
    'price_kurus' => (int) env('SUBSCRIPTION_PRICE_KURUS', 120000),
    'currency' => env('SUBSCRIPTION_CURRENCY', 'TRY'),

    // Abonelik/deneme süreleri (gün). valid_until bu kadar ileri alınır.
    'period_days' => (int) env('SUBSCRIPTION_PERIOD_DAYS', 365),
    'trial_days' => (int) env('SUBSCRIPTION_TRIAL_DAYS', 30),

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

    // iyzico (sandbox). SDK/HTTP entegrasyonu IyzicoPaymentGateway'de; anahtarlar env'den.
    'iyzico' => [
        'api_key' => env('IYZICO_API_KEY', ''),
        'secret_key' => env('IYZICO_SECRET_KEY', ''),
        'base_url' => env('IYZICO_BASE_URL', 'https://sandbox-api.iyzipay.com'),
    ],
];
