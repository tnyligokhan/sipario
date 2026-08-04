<?php

namespace App\Livewire\Panel\Forms;

use App\Livewire\Panel\Concerns\Bicim;
use Livewire\Attributes\Validate;
use Livewire\Form;

/**
 * "Ödeme Ekle" modalı (tasarım `08-OdemeEkleModal.jsx`).
 *
 * Tutar kullanıcıya LİRA sorulur, sisteme KURUŞ girer; dönüşüm tek yerdedir (Bicim::kurus) ve
 * virgülü de noktayı da kabul eder — esnaf "1.250,50" yazar.
 *
 * TASARIMDA OLMAYAN ALAN: `donem` (aylık/yıllık). Prototip yalnız aylık biliyordu ve modal notu
 * "abonelik bitişi 1 ay uzatılır" diyordu; OKU-BENI.md kararı "aylık + yıllık"tır. Dönem seçimi
 * olmadan ekran, yıllık ödeyen bayiye bir ay verirdi.
 *
 * `kapsam` 'YYYY-MM' ANAHTARIdır; `subscription_payments.covers_period`a insan okunur etiketi
 * ("Ağustos 2026") bileşen yazar. Anahtar tutmak, seçeneği yeniden üretirken etiketle karşılaştırma
 * yapmayı gereksiz kılar (varchar(60) sınırı da etikette değil kolonda durur).
 */
class OdemeForm extends Form
{
    #[Validate('required|uuid', as: 'firma', message: 'Firma seçilmelidir.')]
    public ?string $firmaId = null;

    /** Lira metni ("1.250,50" / "1250.50" / "1250"). */
    #[Validate('required|string|max:24', as: 'tutar', message: 'Tutar zorunludur.')]
    public string $tutar = '';

    #[Validate('required|date', as: 'tarih', message: 'Geçerli bir tarih seçin.')]
    public string $tarih = '';

    #[Validate('required|in:iban,elden', as: 'yöntem', message: 'Yöntem IBAN veya Elden olmalıdır.')]
    public string $yontem = 'iban';

    #[Validate('required|in:monthly,yearly', as: 'dönem', message: 'Abonelik dönemi aylık veya yıllık olmalıdır.')]
    public string $donem = 'monthly';

    #[Validate('required|date_format:Y-m', as: 'kapsadığı dönem', message: 'Kapsadığı dönemi seçin.')]
    public string $kapsam = '';

    /** `subscription_payments.note` TEXT'tir; tavan ekranda durur (tek satırlık bir not alanı). */
    #[Validate('nullable|string|max:500', as: 'not', message: 'Not en fazla 500 karakter olabilir.')]
    public string $not = '';

    /** Çözülemezse null — bileşen alanın altına hata basar. */
    public function tutarKurus(): ?int
    {
        return Bicim::kurus($this->tutar);
    }

    /** `covers_period` kolonuna yazılacak insan okunur etiket ("Ağustos 2026"). */
    public function kapsamEtiketi(): string
    {
        return Bicim::ayAdi($this->kapsam);
    }
}
