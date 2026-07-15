<?php

namespace App\Livewire\Panel;

use App\Panel\TenantAdminService;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Bayi listesi (Faz 5c). Panel cross-tenant okur (sipario_panel BYPASSRLS). Salt-okunur özet.
 */
#[Layout('components.layouts.app')]
class TenantList extends Component
{
    public function render(): mixed
    {
        return view('livewire.panel.tenant-list', [
            'tenants' => app(TenantAdminService::class)->tenants(),
        ]);
    }
}
