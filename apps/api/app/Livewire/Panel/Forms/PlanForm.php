<?php

namespace App\Livewire\Panel\Forms;

use App\Livewire\Panel\Concerns\Bicim;
use App\Models\Plan;
use Livewire\Attributes\Validate;
use Livewire\Form;

/**
 * "Planı Düzenle" modalı (tasarım `09-PlanDuzenleModal.jsx`).
 *
 * TASARIMDA OLMAYAN ALAN: `yillik` (yıllık ücret). Prototipte tek bir "Aylık ücret" vardı;
 * sunucuda `plans.price_yearly_kurus` VAR ve site checkout'u onu okuyor. Alanı ekrana koymamak,
 * yıllık fiyatı yalnız migration tohumuyla değiştirilebilir bırakırdı.
 *
 * `ad` varchar(80), sayısal alanlar `integer`/`bigint` (bkz. 005001). Tavanlar kolonlara göre.
 */
class PlanForm extends Form
{
    #[Validate('required|string|min:2|max:80', as: 'plan adı', message: 'Plan adı 2-80 karakter olmalıdır.')]
    public string $ad = '';

    /** Lira metni. */
    #[Validate('required|string|max:24', as: 'aylık ücret', message: 'Aylık ücret zorunludur.')]
    public string $aylik = '';

    #[Validate('required|string|max:24', as: 'yıllık ücret', message: 'Yıllık ücret zorunludur.')]
    public string $yillik = '';

    /** `trial_days` integer, CHECK >= 0. 3650 gün (10 yıl) insan eliyle girilebilecek üst sınır. */
    #[Validate('required|integer|min:0|max:3650', as: 'deneme süresi', message: 'Deneme süresi 0-3650 gün arasında olmalıdır.')]
    public int $denemeGun = 30;

    #[Validate('required|integer|min:0|max:1000000', as: 'aylık oto-sıralama hakkı', message: 'Aylık hak 0-1.000.000 arasında olmalıdır.')]
    public int $hakAy = 50;

    #[Validate('required|integer|min:0|max:10000', as: 'kurye hesabı', message: 'Kurye hesabı 0-10.000 arasında olmalıdır.')]
    public int $kurye = 3;

    public function doldur(?Plan $plan, int $aylikKurus, int $yillikKurus, int $denemeGun, int $hakAy, int $kurye): void
    {
        $this->ad = $plan->name ?? 'Sipario';
        $this->aylik = Bicim::lira($aylikKurus);
        $this->yillik = Bicim::lira($yillikKurus);
        $this->denemeGun = $denemeGun;
        $this->hakAy = $hakAy;
        $this->kurye = $kurye;
    }

    public function aylikKurus(): ?int
    {
        return Bicim::kurus($this->aylik);
    }

    public function yillikKurus(): ?int
    {
        return Bicim::kurus($this->yillik);
    }
}
