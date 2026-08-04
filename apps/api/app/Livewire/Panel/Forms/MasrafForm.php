<?php

namespace App\Livewire\Panel\Forms;

use App\Abonelik\MasrafServisi;
use App\Livewire\Panel\Concerns\Bicim;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Validate;
use Livewire\Form;

/**
 * "Masraf Ekle" modalı (tasarım `10-MasrafEkleModal.jsx`).
 *
 * KATEGORİ SERBEST METİN DEĞİLDİR: liste `MasrafServisi::KATEGORILER`den gelir ve doğrulama da
 * oradan türer. Ekranda açılır liste olması yetmez — istemci istediğini gönderebilir ve "Reklam"
 * ile "reklam" aylık raporu sessizce ikiye bölerdi (servisin de aynı kapısı var; ikisi de duruyor).
 */
class MasrafForm extends Form
{
    #[Validate('required|date', as: 'tarih', message: 'Geçerli bir tarih seçin.')]
    public string $tarih = '';

    public string $kategori = MasrafServisi::KATEGORILER[0];

    /** Lira metni. */
    #[Validate('required|string|max:24', as: 'tutar', message: 'Tutar zorunludur.')]
    public string $tutar = '';

    #[Validate('nullable|string|max:500', as: 'not', message: 'Not en fazla 500 karakter olabilir.')]
    public string $not = '';

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'kategori' => ['required', Rule::in(MasrafServisi::KATEGORILER)],
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'kategori.required' => 'Masraf kategorisi geçersiz.',
            'kategori.in' => 'Masraf kategorisi geçersiz.',
        ];
    }

    public function tutarKurus(): ?int
    {
        return Bicim::kurus($this->tutar);
    }
}
