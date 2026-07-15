<?php

namespace App\Livewire\Panel;

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

    public function render(): mixed
    {
        $detail = $this->service()->tenantDetail($this->tenantId);
        abort_if($detail === null, 404);

        return view('livewire.panel.tenant-detail', ['detail' => $detail]);
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
