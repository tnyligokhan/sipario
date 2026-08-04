<?php

namespace App\Livewire\Panel\Forms;

use App\Livewire\Panel\Concerns\Bicim;
use App\Models\AddonPackage;
use Livewire\Attributes\Validate;
use Livewire\Form;

/**
 * "Ek Paket Ekle / Paketi Düzenle" modalı (tasarım `09-PlanDuzenleModal.jsx` · EkPaketModal).
 *
 * Ekranda görünen tür etiketleri tasarımdaki gibi "hak" / "kurye"; DB değerleri
 * `credits` / `courier` (005002 CHECK). Etiket sözleşme, değer şema — ikisi ayrı tutuldu.
 *
 * `aktif` bir METİNdir ('1'/'0'): `x-panel.radyolar` seçimi `$set` ile string yazar; bool bir
 * özelliğe '0' yazmak PHP'de true eder ve "Pasif" seçimi sessizce "Aktif" olurdu.
 */
class PaketForm extends Form
{
    /** null = yeni paket; dolu = düzenleme (servis upsert YAPMAZ, bulunamazsa hata verir). */
    public ?string $paketId = null;

    #[Validate('required|in:credits,courier', as: 'paket türü', message: 'Paket türü hak veya kurye olmalıdır.')]
    public string $tur = AddonPackage::TYPE_CREDITS;

    /** `addon_packages.name` varchar(120). */
    #[Validate('required|string|min:2|max:120', as: 'paket adı', message: 'Paket adı 2-120 karakter olmalıdır.')]
    public string $ad = '';

    /** `quantity` integer, CHECK > 0. */
    #[Validate('required|integer|min:1|max:1000000', as: 'kapsam', message: 'Kapsam 1-1.000.000 arasında olmalıdır.')]
    public int $adet = 100;

    /** Lira metni. */
    #[Validate('required|string|max:24', as: 'ücret', message: 'Ücret zorunludur.')]
    public string $ucret = '';

    #[Validate('required|in:0,1', as: 'satışta', message: 'Satış durumu Aktif veya Pasif olmalıdır.')]
    public string $aktif = '1';

    public function doldur(AddonPackage $paket): void
    {
        $this->paketId = (string) $paket->id;
        $this->tur = $paket->type;
        $this->ad = $paket->name;
        $this->adet = $paket->quantity;
        $this->ucret = Bicim::lira($paket->price_kurus);
        $this->aktif = $paket->active ? '1' : '0';
    }

    public function ucretKurus(): ?int
    {
        return Bicim::kurus($this->ucret);
    }

    public function aktifMi(): bool
    {
        return $this->aktif === '1';
    }
}
