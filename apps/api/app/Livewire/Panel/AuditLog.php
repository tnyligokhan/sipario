<?php

namespace App\Livewire\Panel;

use App\Panel\PanelAdminService;
use Livewire\Attributes\Layout;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * GENEL denetim günlüğü (5c-3 · D5) — tüm bayilerdeki tüm panel eylemleri. SALT-OKUNUR.
 *
 * Her iki rol de görebilir: destek ekibinin kendi yaptığını (ve başkasının yaptığını) görmesi
 * hesap verebilirliği zayıflatmaz, güçlendirir. Günlük zaten DEĞER taşımaz — yalnız eylem türü ve
 * hedef kimlik (KVKK, kırmızı çizgi #4).
 */
#[Layout('components.layouts.app')]
class AuditLog extends Component
{
    use WithPagination;

    public string $eylem = '';

    public function updatedEylem(): void
    {
        $this->resetPage('gsayfa');
    }

    public function render(): mixed
    {
        $service = app(PanelAdminService::class);

        return view('livewire.panel.audit-log', [
            'kayitlar' => $service->denetimGunlugu(['eylem' => $this->eylem]),
            'eylemTurleri' => $service->eylemTurleri(),
        ]);
    }
}
