<?php

namespace App\Abonelik;

use Illuminate\Database\ConnectionInterface;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * `App\Abonelik` servislerinin ortak temeli: bağlantı seçimi + denetim günlüğü.
 *
 * NEDEN VARSAYILAN `pgsql_owner` (hepsi için tek cevap, her sınıfta tekrar edilmesin):
 *
 *  1. YAZMALAR ÇOK TABLOLUDUR VE ATOMİK OLMAK ZORUNDADIR. Elle ödeme = subscription_payments
 *     INSERT + tenants UPDATE; ek paket tanımlama = addon_grants INSERT + subscription_payments
 *     INSERT + tenants kota UPDATE. Tek transaction = tek bağlantı. `sipario_panel`e bu tabloların
 *     hepsinde yazma izni vermek, panel rolünün "iş verisine yazamaz" sınırını (BRIEF md. 3,
 *     migration 000504) sulandırırdı — o yüzden panel rolü SELECT'te bırakıldı (005010) ve yazma
 *     kiracı-üstü meşru eylem olarak owner'a verildi (Provisioning'in tenant açma deseni).
 *
 *  2. BAZI YOLLAR PUBLIC SİTEDEN KOŞAR. Bayinin "havale gönderdim" bildirimi ve checkout fiyat
 *     okuması, panel rolünün BULUNMADIĞI bir bağlamda çalışır; `sipario_app`in ise bu tablolarda
 *     bilinçli olarak hiçbir izni yoktur. Geriye owner kalır — SubscriptionService'in Faz 5b'den
 *     beri yaptığının aynısı.
 *
 * Salt-okunur panel ekranları bağlantıyı yapıcıdan `pgsql_panel` olarak geçebilir (o rol SELECT
 * iznine sahiptir) — okuma için superuser kullanmak zorunlu değildir.
 */
abstract class AbonelikServisi
{
    public function __construct(protected readonly string $connection = 'pgsql_owner') {}

    protected function db(): ConnectionInterface
    {
        return DB::connection($this->connection);
    }

    /**
     * panel_audit'e nötr kayıt (TenantAdminService deseni). KVKK: yalnız EYLEM TÜRÜ + HEDEF yazılır;
     * tutar, IBAN, not metni gibi DEĞERLER ASLA. "Ne kadar ödendi" sorusunun cevabı
     * subscription_payments'tadır, denetim günlüğünün işi "kim neyi yaptı"dır.
     */
    protected function denetle(?string $adminId, ?string $tenantId, string $action, ?string $detail = null): void
    {
        $this->db()->table('panel_audit')->insert([
            'id' => (string) Str::uuid7(),
            'admin_user_id' => $adminId,
            'tenant_id' => $tenantId,
            'action' => $action,
            'detail' => $detail,
            'created_at' => now(),
        ]);
    }
}
