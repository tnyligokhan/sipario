<?php

namespace App\Livewire\Panel;

use App\Panel\PanelDashboardService;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Panel GENEL BAKIŞ (5c-3 · D1) — panelin ana sayfası. TAMAMEN SALT-OKUNUR: hiçbir eylemi yoktur,
 * yalnız `PanelDashboardService`in cross-tenant agregatlarını çizer. Bayi listesi ayrı sayfaya
 * (`panel.tenants`) taşındı; pano "bugün kime bakmalıyım" sorusunu cevaplar, liste "hepsini göster"i.
 */
#[Layout('components.layouts.app')]
class Dashboard extends Component
{
    /** Churn eşiği (gün) — kaç gündür sipariş girilmemiş bayiler riskli sayılsın. */
    public int $churnGun = 3;

    /** Yenileme takviminin ufku (gün). */
    public int $takvimGun = 60;

    public function render(): mixed
    {
        $service = app(PanelDashboardService::class);
        $takvim = $service->yenilemeTakvimi($this->takvimGun);

        return view('livewire.panel.dashboard', [
            'ozet' => $service->ozet(),
            'bitenDenemeler' => $service->bitenDenemeler(7),
            'churnRiski' => $service->churnRiski($this->churnGun),
            'takvim' => $takvim,
            'kovalar' => $service->haftalikKovalar($takvim, $this->takvimGun),
        ]);
    }
}
