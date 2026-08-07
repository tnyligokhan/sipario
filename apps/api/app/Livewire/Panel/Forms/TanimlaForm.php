<?php

namespace App\Livewire\Panel\Forms;

use App\Livewire\Panel\Concerns\Bicim;
use Livewire\Attributes\Validate;
use Livewire\Form;

/**
 * "Ek Paket Tanımla" modalı (tasarım `09-PlanDuzenleModal.jsx` · TanimlaModal).
 *
 * BEDELSİZ → TUTAR 0. Tasarımda alan pasifleşir, `addon_grants` CHECK'i de (005003) bunu zorlar;
 * arayüz de zorlar — üç katman aynı şeyi söylüyor ve hiçbiri diğerine güvenmiyor. Pasif bir
 * girdinin değeri istemciden yine de gönderilebilir, bu yüzden karar SUNUCUDA yeniden verilir
 * (bkz. tutarKurus).
 */
class TanimlaForm extends Form
{
    #[Validate('required|uuid', as: 'firma', message: 'Firma seçilmelidir.')]
    public ?string $firmaId = null;

    #[Validate('required|uuid', as: 'paket', message: 'Paket seçilmelidir.')]
    public ?string $paketId = null;

    #[Validate('required|in:iban,elden,bedelsiz', as: 'tahsilat', message: 'Tahsilat IBAN, Elden veya Bedelsiz olmalıdır.')]
    public string $tahsil = 'iban';

    /** Lira metni. Bedelsizde okunmaz. */
    #[Validate('nullable|string|max:24', as: 'tutar', message: 'Tutar geçersiz.')]
    public string $tutar = '';

    #[Validate('required|date', as: 'tarih', message: 'Geçerli bir tarih seçin.')]
    public string $tarih = '';

    #[Validate('nullable|string|max:500', as: 'not', message: 'Not en fazla 500 karakter olabilir.')]
    public string $not = '';

    public function bedelsizMi(): bool
    {
        return $this->tahsil === 'bedelsiz';
    }

    /** Alan boş → servis paketin liste fiyatını uygular (bilinçli boşluk, hata değil). */
    public function tutarBos(): bool
    {
        return trim($this->tutar) === '';
    }

    /**
     * HAM çözüm: null = ÇÖZÜLEMEDİ (bileşen hata basar). "Bedelsiz → 0" ve "boş → liste fiyatı"
     * kararları burada VERİLMEZ; ikisi de anlamlı sonuçlardır ve null ile karıştırılamaz.
     */
    public function tutarKurus(): ?int
    {
        return Bicim::kurus($this->tutar);
    }
}
