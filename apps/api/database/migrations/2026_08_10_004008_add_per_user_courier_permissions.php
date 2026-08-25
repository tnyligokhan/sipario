<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * KİŞİYE ÖZEL KURYE YETKİSİ — DEVRALMALI (3 durumlu) model (kullanıcı kararı 2026-08-10).
 *
 * Bugüne kadar 13 kurye yetkisi YALNIZ `tenant_settings` üzerindeydi ve bayideki TÜM kuryeler için
 * ortaktı: iki yıllık kuryeye iskonto yetkisi vermek, dün başlayan çırağa da vermek demekti.
 *
 * ÇÖZÜM KOLON TAŞIMAK DEĞİL, KATMAN EKLEMEKTİR. Aynı 13 kolon `users` üzerine **nullable** boolean
 * olarak eklenir ve üç durum taşır:
 *   NULL   → "bayi varsayılanını devral" (kolonun varsayılanı; mevcut her satır böyle başlar)
 *   true   → kişiye özel AÇIK
 *   false  → kişiye özel KAPALI
 * Etkin yetki = `users.courier_x ?? tenant_settings.courier_x`.
 *
 * `tenant_settings`'teki 13 kolon KALIR ve anlamı değişir: "bayi varsayılanı / yeni kurye şablonu".
 * Kaldırmak, sahadaki her istemcinin okuduğu bir alanı yok etmek olurdu (SyncPayload'daki şema
 * evrimi sözleşmesi: alan eklemek serbest, kaldırmak yasak) ve devralınacak bir taban bırakmazdı.
 *
 * SÖZLEŞME AÇISINDAN MINOR: eski istemci yeni alanları hiç göndermez ve okumaz; `team` bloğundaki
 * bilmediği anahtarları yok sayar ve bugünkü gibi tenant varsayılanıyla çalışmaya devam eder.
 *
 * NULLABLE OLMASI KASITLI ve şema sözleşmesini İHLAL ETMEZ: sözleşme "zorunlu bir alanı sonradan
 * nullable yapmak yasak" der — bu kolonlar YENİDİR, hiçbir istemci onları zorunlu okumuyor.
 * Varsayılanı `false` yapmak modeli bozardı: o zaman "devral" hâli ifade edilemez olurdu ve
 * migration bütün kuryelerin yetkisini sessizce kapatırdı.
 *
 * RLS: `users` Faz 1'den beri ENABLE + FORCE ROW LEVEL SECURITY altındadır ve `tenant_isolation`
 * policy'si TABLO düzeyindedir (kolon düzeyinde politika yoktur) — yeni kolonlar kendiliğinden aynı
 * kapsama girer, EK POLİTİKA GEREKMEZ. `sipario_app` rolünün UPDATE yetkisi de tablo düzeyindedir
 * (migration 130000: GRANT ... ON ALL TABLES), kolon bazlı grant kullanılmıyor.
 *
 * `sync_changes` DELTASI YOK ve GEREKMEZ: `users` senkron delta günlüğünde hiç yer almaz, her
 * senkron yanıtındaki `team` bloğuyla toptan iner (SyncService::teamPayload). Ayrıca bu migration
 * mevcut satırların DEĞERİNİ değiştirmiyor — hepsi NULL, yani "bugünkü davranış".
 */
return new class extends Migration
{
    /**
     * Kolon adları `TenantSetting::KURYE_IZINLERI` / `User::KURYE_IZINLERI` ile BİREBİR aynıdır ama
     * BURADA ELLE SAYILIR (migration 004007'nin deseni): migration bir TARİH KAYDIDIR ve yıllar
     * sonra da bugünkü şemayı üretmelidir — uygulama sabitine bağlansaydı, listeye yarın eklenen
     * bir yetki bu migration'ın geçmişini geriye dönük değiştirirdi.
     *
     * @var list<string>
     */
    private const YENI_KOLONLAR = [
        'courier_can_customers',
        'courier_can_orders',
        'courier_can_collect',
        'courier_can_discount',
        'courier_can_day_end',
        'courier_can_see_all_orders',
        'courier_can_view_history',
        'courier_can_expense',
        'courier_phone_mask',
        'courier_can_customer_ledger',
        'courier_can_debt_reminder',
        'courier_can_toggle_stock',
        'courier_can_call_log',
    ];

    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            foreach (self::YENI_KOLONLAR as $kolon) {
                $table->boolean($kolon)->nullable()->default(null);
            }
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(self::YENI_KOLONLAR);
        });
    }
};
