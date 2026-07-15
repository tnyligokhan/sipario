<?php

namespace App\Panel;

use App\Enums\TenantStatus;
use App\Models\Device;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Yönetim paneli tenant/abonelik yönetimi (Faz 5c). TÜM okuma/yazma `pgsql_panel` bağlantısı
 * (sipario_panel rolü — BYPASSRLS cross-tenant görür, iş verisine YAZAMAZ) üzerinden yapılır; elle
 * tenant açma tek istisnadır (INSERT gerektirir → Provisioning owner ile, kiracı-üstü meşru eylem).
 *
 * Abonelik eylemleri 5a kilit mantığıyla TUTARLIdır (DECISIONS): writable olması için locked_at=null
 * + valid_until gelecekte + status ∈ {trial, active}. Her eylem panel_audit'e nötr kayıt bırakır
 * (KVKK: yalnız eylem türü + hedef id; iş verisi DEĞERİ yazılmaz).
 */
class TenantAdminService
{
    public function __construct(private readonly string $connection = 'pgsql_panel') {}

    /**
     * Tüm bayiler (özet). Panel cross-tenant okur (BYPASSRLS).
     *
     * @return Collection<int, Tenant>
     */
    public function tenants(): Collection
    {
        return Tenant::on($this->connection)->orderBy('created_at', 'desc')->get();
    }

    /**
     * Bayi detayı + salt-okunur özet (kullanıcı/cihaz sayısı). Yoksa null.
     *
     * @return array{tenant: Tenant, user_count: int, device_count: int}|null
     */
    public function tenantDetail(string $tenantId): ?array
    {
        $tenant = Tenant::on($this->connection)->find($tenantId);
        if ($tenant === null) {
            return null;
        }

        return [
            'tenant' => $tenant,
            'user_count' => User::on($this->connection)->where('tenant_id', $tenantId)->count(),
            'device_count' => Device::on($this->connection)->where('tenant_id', $tenantId)->count(),
        ];
    }

    /** Deneme uzat: trial_ends_at + valid_until'ı ileri al, status=trial, kilidi temizle. */
    public function extendTrial(string $tenantId, int $days, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);
        $base = $this->maxNow($tenant->trial_ends_at);
        $newEnd = $base->copy()->addDays($days);

        return $this->apply($tenant, [
            'status' => TenantStatus::Trial->value,
            'trial_ends_at' => $newEnd,
            'valid_until' => $newEnd,
            'locked_at' => null,
        ], $adminId, 'extend_trial', "+{$days}d");
    }

    /** Abonelik kaydet: valid_until = now+days (varsayılan 1 yıl), status=active, kilit temizle. */
    public function activateSubscription(string $tenantId, int $days = 365, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Active->value,
            'valid_until' => now()->addDays($days),
            'locked_at' => null,
        ], $adminId, 'activate', "+{$days}d");
    }

    /** Kilitle: status=locked, locked_at=now (5a: occurred_at>locked_at yeni yazım reddedilir). */
    public function lock(string $tenantId, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Locked->value,
            'locked_at' => now(),
        ], $adminId, 'lock');
    }

    /** Aç: status=active, locked_at=null, valid_until'ı ileri al (geçmişse now+30g — 5a re-lock önlenir). */
    public function unlock(string $tenantId, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Active->value,
            'locked_at' => null,
            'valid_until' => $this->forwardValidUntil($tenant),
        ], $adminId, 'unlock');
    }

    /** Askıya al: status=suspended, locked_at=now (kilit ile aynı 5a enforcement). */
    public function suspend(string $tenantId, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Suspended->value,
            'locked_at' => now(),
        ], $adminId, 'suspend');
    }

    /**
     * Elle bayi aç (siteden gelmeyen, birebir satış bayisi). Provisioning owner ile INSERT eder
     * (panel rolü tenants'a INSERT edemez — bilinçli); denetim kaydı panel bağlantısıyla.
     *
     * @return array{tenant: Tenant, patron: User}
     */
    public function createTenant(string $name, string $email, string $password, ?string $adminId = null): array
    {
        $result = Provisioning::createTenantWithPatron($name, $email, $password);
        $this->audit($adminId, $result['tenant']->id, 'create_tenant');

        return $result;
    }

    // ------------------------------------------------------------------------------------

    private function find(string $tenantId): Tenant
    {
        return Tenant::on($this->connection)->findOrFail($tenantId);
    }

    /**
     * Değişiklikleri panel bağlantısıyla UPDATE eder (sipario_panel tenants UPDATE'e sahip) + audit.
     *
     * @param  array<string, mixed>  $attrs
     */
    private function apply(Tenant $tenant, array $attrs, ?string $adminId, string $action, ?string $detail = null): Tenant
    {
        $tenant->forceFill($attrs)->save();
        $this->audit($adminId, $tenant->id, $action, $detail);

        return $tenant;
    }

    private function audit(?string $adminId, ?string $tenantId, string $action, ?string $detail = null): void
    {
        DB::connection($this->connection)->table('panel_audit')->insert([
            'id' => (string) Str::uuid7(),
            'admin_user_id' => $adminId,
            'tenant_id' => $tenantId,
            'action' => $action,
            'detail' => $detail,
            'created_at' => now(),
        ]);
    }

    /** valid_until gelecekteyse korunur, geçmiş/null ise now+30g'ye çekilir (asla geriye alınmaz). */
    private function forwardValidUntil(Tenant $tenant): Carbon
    {
        $current = $tenant->valid_until;
        $floor = now()->addDays(30);

        return ($current !== null && $current->greaterThan($floor)) ? $current : $floor;
    }

    private function maxNow(?Carbon $date): Carbon
    {
        return ($date !== null && $date->greaterThan(now())) ? $date : now();
    }
}
