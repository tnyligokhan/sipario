<?php

namespace App\Livewire\Panel;

use App\Panel\PanelStatsService;
use App\Panel\TenantAdminService;
use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Bayi detayı + abonelik/durum eylemleri (Faz 5c). Eylemler TenantAdminService'e delege edilir
 * (tenants UPDATE panel bağlantısıyla; iş verisi salt-okunur). Her eylem 5a kilit mantığıyla tutarlı
 * ve panel_audit'e kayıt bırakır. İş verisi ÖZETİ salt-okunur (kullanıcı/cihaz sayısı).
 */
#[Layout('components.layouts.app')]
class TenantDetail extends Component
{
    public string $tenantId;

    public int $extendDays = 14;

    /** Şifre sıfırlama sonrası admin'e BİR KEZ gösterilir (kalıcı saklanmaz). */
    public ?string $newPassword = null;

    public function mount(string $tenant): void
    {
        $this->tenantId = $tenant;
    }

    public function extendTrial(): void
    {
        $this->service()->extendTrial($this->tenantId, $this->extendDays, $this->adminId());
    }

    public function activate(): void
    {
        $this->service()->activateSubscription($this->tenantId, 365, $this->adminId());
    }

    public function lock(): void
    {
        $this->service()->lock($this->tenantId, $this->adminId());
    }

    public function unlock(): void
    {
        $this->service()->unlock($this->tenantId, $this->adminId());
    }

    public function suspend(): void
    {
        $this->service()->suspend($this->tenantId, $this->adminId());
    }

    /** Opsiyonel modül aç/kapa (FAZ 5c-2). Mevcut durumu tersine çevirir. */
    public function toggleModule(string $module): void
    {
        $detail = $this->service()->tenantDetail($this->tenantId);
        $current = (bool) ($detail['tenant']->modules[$module] ?? false);
        $this->service()->setModule($this->tenantId, $module, ! $current, $this->adminId());
    }

    /** Patron şifre sıfırlama (FAZ 5c-2). Yeni parola BİR KEZ gösterilir (owner ile üretilir). */
    public function resetPassword(): void
    {
        $this->newPassword = $this->service()->resetPatronPassword($this->tenantId, $this->adminId());
    }

    public function render(): mixed
    {
        $detail = $this->service()->tenantDetail($this->tenantId);
        abort_if($detail === null, 404);

        $stats = app(PanelStatsService::class);

        return view('livewire.panel.tenant-detail', [
            'detail' => $detail,
            'dailyOrders' => $stats->dailyOrders($this->tenantId),
            'hourDistribution' => $stats->orderHourDistribution($this->tenantId),
            'minutesToFirstOrder' => $stats->minutesToFirstOrder($this->tenantId),
            'activeDevices' => $stats->activeDeviceCount($this->tenantId),
            'devices' => $stats->devices($this->tenantId),
        ]);
    }

    private function service(): TenantAdminService
    {
        return app(TenantAdminService::class);
    }

    private function adminId(): ?string
    {
        $id = Auth::guard('admin')->id();

        return $id !== null ? (string) $id : null;
    }
}
