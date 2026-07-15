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

    // iyzico (sandbox). SDK/HTTP entegrasyonu IyzicoPaymentGateway'de; anahtarlar env'den.
    'iyzico' => [
        'api_key' => env('IYZICO_API_KEY', ''),
        'secret_key' => env('IYZICO_SECRET_KEY', ''),
        'base_url' => env('IYZICO_BASE_URL', 'https://sandbox-api.iyzipay.com'),
    ],
];
