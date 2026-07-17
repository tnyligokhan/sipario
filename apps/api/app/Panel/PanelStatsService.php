<?php

namespace App\Panel;

use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Yönetim paneli KULLANIM İSTATİSTİKLERİ (FAZ 5c-2; BRIEF churn sinyalleri). SALT-OKUNUR — panel
 * `pgsql_panel` rolüyle (BYPASSRLS) cross-tenant okur; yeni kalıcı durum ÜRETMEZ. Gün sınırı SABİT
 * +03:00 (Etc/GMT-3 = UTC+3; DayEndRepository ile tutarlı, DST yok).
 *
 * BYPASSRLS tüm bayileri görür → her sorgu tenant_id ile AÇIKÇA filtrelenir (sızıntı yok).
 */
class PanelStatsService
{
    public function __construct(private readonly string $connection = 'pgsql_panel') {}

    /**
     * Son $days günde günlük sipariş sayısı (TR gününe göre gruplu).
     *
     * @return array<string, int> tarih (YYYY-MM-DD) => adet
     */
    public function dailyOrders(string $tenantId, int $days = 7): array
    {
        $rows = DB::connection($this->connection)->table('orders')
            ->where('tenant_id', $tenantId)
            ->whereNull('deleted_at')
            ->where('occurred_at', '>=', now()->subDays($days))
            ->selectRaw("to_char(occurred_at AT TIME ZONE 'Etc/GMT-3', 'YYYY-MM-DD') as d, count(*) as c")
            ->groupBy('d')->orderBy('d')->get();

        $out = [];
        foreach ($rows as $r) {
            $out[(string) $r->d] = (int) $r->c;
        }

        return $out;
    }

    /**
     * Sipariş GİRME SAATİ dağılımı (0-23, TR). Akşam yoğunlaşması = gün içi kullanmama = churn sinyali.
     *
     * @return array<int, int> saat (0-23) => adet
     */
    public function orderHourDistribution(string $tenantId, int $days = 30): array
    {
        $rows = DB::connection($this->connection)->table('orders')
            ->where('tenant_id', $tenantId)
            ->whereNull('deleted_at')
            ->where('occurred_at', '>=', now()->subDays($days))
            ->selectRaw("EXTRACT(HOUR FROM occurred_at AT TIME ZONE 'Etc/GMT-3')::int as h, count(*) as c")
            ->groupBy('h')->get();

        $out = array_fill(0, 24, 0);
        foreach ($rows as $r) {
            $out[(int) $r->h] = (int) $r->c;
        }

        return $out;
    }

    /** Kurulumdan (tenant.created_at) ilk siparişe kadar geçen dakika; sipariş yoksa null (churn: hiç başlamadı). */
    public function minutesToFirstOrder(string $tenantId): ?int
    {
        $tenant = DB::connection($this->connection)->table('tenants')->where('id', $tenantId)->first();
        if ($tenant === null) {
            return null;
        }

        $first = DB::connection($this->connection)->table('orders')
            ->where('tenant_id', $tenantId)->whereNull('deleted_at')->min('occurred_at');
        if ($first === null) {
            return null;
        }

        return (int) round(Carbon::parse((string) $tenant->created_at)->diffInMinutes(Carbon::parse((string) $first), true));
    }

    /** Son $days günde görülen aktif cihaz sayısı. */
    public function activeDeviceCount(string $tenantId, int $days = 7): int
    {
        return DB::connection($this->connection)->table('devices')
            ->where('tenant_id', $tenantId)
            ->where('last_seen_at', '>=', now()->subDays($days))
            ->count();
    }

    /**
     * Cihaz listesi (salt-okunur): model, platform, son görülme.
     *
     * @return Collection<int, \stdClass>
     */
    public function devices(string $tenantId): Collection
    {
        return DB::connection($this->connection)->table('devices')
            ->where('tenant_id', $tenantId)
            ->orderByDesc('last_seen_at')
            ->get();
    }
}
