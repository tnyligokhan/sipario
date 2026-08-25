<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * LWW DAMGALARI `timestamptz(0)` → `timestamptz(6)` — saniye-altı ayrım (2026-08-17).
 *
 * NEDEN: çakışma çözümü "son yazan kazanır"dır ve damga saniye çözünürlüğündeyken aynı saniyeye
 * düşen iki yazım BERABERE kalıyor, karar `device_id` karşılaştırmasına iniyordu. O ayrım
 * deterministiktir (DECISIONS: "eşitlikte device_id ile deterministik ayrım") ama SEMANTİK
 * DEĞİLDİR: kazanan daha YENİ olan değil, kimliği BÜYÜK olandır. Sonucu şudur — çevrimdışı bir
 * cihazın 09:00:00.100'de yaptığı ESKİ yazım, başka bir cihazın 09:00:00.900'deki YENİ yazımını
 * ezebilir. Bayi için bu "az önce düzelttiğim ad geri döndü" demektir ve sebebi hiçbir ekranda
 * görünmez.
 *
 * Taviz depoda zaten biliniyordu ve panel tarafında elle aşılıyordu: `PanelSyncYazici::damga()`
 * sentetik bir PANEL_DEVICE_ID + "kendi damgasını bir saniye ileri alma" hilesi kullanıyor
 * (aynı hile `Livewire\Site\Ekip`te de var). Mobil senkron yolunda böyle bir kapak YOKTU.
 *
 * ⚠️ KOD DEĞİŞMEDİ ve bu bilinçli: `ChangeApplier::lwwWins()` gelen ISO dizesini Carbon'a
 * çeviriyor ve `equalTo`/`greaterThan` ile karşılaştırıyor — yani karşılaştırma ZATEN
 * çözünürlükten bağımsızdı. Saniye-altını yok eden tek şey KOLON TİPİYDİ: Postgres
 * `timestamptz(0)`a yazarken değeri yuvarlıyordu. İstemci damgayı en başından mikrosaniyeli
 * gönderiyor (`2026-08-06T09:00:00.900000Z`).
 *
 * ⚠️ DEĞER DEĞİŞTİRMEZ, dolayısıyla `sync_changes`e DELTA DÜŞMEZ: çözünürlük GENİŞLETİLİYOR,
 * daraltılmıyor. Mevcut satırların değerleri aynı kalır (`09:00:00` → `09:00:00.000000`), yani
 * hiçbir istemcinin gördüğü veri değişmez ve "değer değiştiren migration deltaya düşmeli"
 * kuralı (SyncPayload şema evrimi sözleşmesi) burada TETİKLENMEZ.
 *
 * ⚠️ ESKİ İSTEMCİ KIRILMAZ (MINOR, MAJOR değil): eski uygulama damgayı zaten mikrosaniyeli
 * gönderiyordu ve yanıtta gelen ISO dizesini olduğu gibi okuyor. Değişen tek şey sunucunun
 * artık o hassasiyeti KAYBETMEMESİ.
 *
 * KAPSAM — yalnız KARAR VEREN damgalar (19 kolon). Defter tutan `created_at`/`updated_at`/
 * `deleted_at` kolonlarına DOKUNULMADI: onlar bir çakışmayı çözmüyor, yalnız kayıt tutuyor;
 * hepsini çevirmek yarıçapı üç katına çıkarır ve karşılığında hiçbir kararı düzeltmezdi.
 */
return new class extends Migration
{
    /**
     * Karar veren damgalar: LWW karşılaştırması (`updated_occurred_at`), olay sıralaması
     * (`occurred_at`), kasa devri penceresi (`period_start`) ve kurye konumu tazeliği
     * (`reported_at`).
     *
     * @var array<int, string>
     */
    private const KOLONLAR = [
        'call_logs.occurred_at',
        'call_logs.updated_occurred_at',
        'cash_handovers.occurred_at',
        'cash_handovers.period_start',
        'courier_locations.reported_at',
        'customer_addresses.updated_occurred_at',
        'customer_phones.updated_occurred_at',
        'customers.updated_occurred_at',
        'day_closings.occurred_at',
        'day_closings.period_start',
        'exempt_numbers.updated_occurred_at',
        'ledger_entries.occurred_at',
        'order_events.occurred_at',
        'orders.occurred_at',
        'products.updated_occurred_at',
        'subscription_payments.occurred_at',
        'sync_changes.occurred_at',
        'tenant_settings.updated_occurred_at',
        'users.updated_occurred_at',
    ];

    public function up(): void
    {
        $this->cozunurlugeCevir(6);
    }

    /**
     * Geri alma DEĞER KAYBETTİRİR ve bu kaçınılmazdır: `timestamptz(0)`a dönmek saniye-altını
     * yuvarlar. Yine de yazılıyor — geri alınamayan bir migration, sorunu fark eden kişiyi
     * çaresiz bırakır. Geri alındığında LWW eski (device_id'ye inen) davranışına döner.
     */
    public function down(): void
    {
        $this->cozunurlugeCevir(0);
    }

    private function cozunurlugeCevir(int $cozunurluk): void
    {
        foreach (self::KOLONLAR as $hedef) {
            [$tablo, $kolon] = explode('.', $hedef);
            // `USING` gerekmez: aynı tip ailesi içinde çözünürlük değişimi Postgres'in kendi
            // dönüşümüyle yapılır.
            DB::statement("ALTER TABLE {$tablo} ALTER COLUMN {$kolon} TYPE timestamptz({$cozunurluk})");
        }
    }
};
