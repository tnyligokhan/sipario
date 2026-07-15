<?php

namespace App\Panel;

use App\Models\Tenant;
use Illuminate\Support\Facades\DB;

/**
 * Bir bayinin iş verisi DIŞA AKTARIMI (FAZ 5c-2; BRIEF: veri rehin alınmaz, bayi destek kanalıyla
 * export talep edebilir; panelde bizdedir). SALT-OKUNUR — panel `pgsql_panel` (BYPASSRLS) ile okur.
 *
 * KIRMIZI ÇİZGİ #1: BYPASSRLS tüm bayileri görür → her tablo tenant_id ile AÇIKÇA filtrelenir;
 * BAŞKA bayinin verisi export'a SIZMAZ (PanelExportTest kanıtlar). KVKK: export destek talebiyle,
 * loglara PII yazılmaz (dönen veri talebin kendisidir).
 */
class PanelExportService
{
    /** Bir tenant'a bağlı iş verisi tabloları (hepsinde tenant_id). */
    private const TABLES = [
        'customers', 'customer_phones', 'customer_addresses', 'products',
        'orders', 'order_lines', 'order_events', 'ledger_entries',
        'coupon_movements', 'coupon_balances', 'cash_handovers', 'devices',
    ];

    public function __construct(private readonly string $connection = 'pgsql_panel') {}

    /**
     * Bayinin tüm iş verisi dump'ı. Yoksa boş dizi.
     *
     * @return array<string, mixed>
     */
    public function export(string $tenantId): array
    {
        $tenant = Tenant::on($this->connection)->find($tenantId);
        if ($tenant === null) {
            return [];
        }

        $data = [
            'tenant' => [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'status' => $tenant->status->value,
                'exported_at' => now()->utc()->toIso8601String(),
            ],
        ];

        foreach (self::TABLES as $table) {
            // tenant_id FİLTRESİ ZORUNLU: BYPASSRLS her satırı görür, sızıntı ancak açık filtreyle önlenir.
            $data[$table] = DB::connection($this->connection)->table($table)
                ->where('tenant_id', $tenantId)->get()->toArray();
        }

        return $data;
    }
}
