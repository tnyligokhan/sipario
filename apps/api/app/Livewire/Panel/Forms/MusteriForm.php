<?php

namespace App\Livewire\Panel\Forms;

use Livewire\Attributes\Validate;
use Livewire\Form;

/**
 * Panelden müşteri ekleme/düzenleme formu (5c-3 · D3). Doğrulama BURADA (sistem sınırı), yazma
 * PanelWriteService'te. Kara liste ve bakiye BİLEREK bu formda yok: bakiye defterden türer
 * (elle yazılamaz), kara liste ayrı bir düğmedir — formda olsaydı her kaydetmede yeniden
 * gönderilmesi gerekirdi ve unutulduğu an sessizce silinirdi.
 */
class MusteriForm extends Form
{
    /** null = yeni kayıt; dolu = düzenleme. */
    public ?string $musteriId = null;

    #[Validate('required|string|min:2|max:120')]
    public string $ad = '';

    #[Validate('nullable|string|max:500')]
    public string $not = '';

    #[Validate('nullable|string|max:32')]
    public string $telefon = '';

    #[Validate('nullable|string|max:500')]
    public string $adres = '';

    #[Validate('nullable|string|max:60')]
    public string $bolge = '';

    /** Düzenleme için mevcut kaydı forma yükler. */
    public function doldur(object $musteri, ?object $telefon, ?object $adres): void
    {
        $this->musteriId = (string) $musteri->id;
        $this->ad = (string) $musteri->name;
        $this->not = (string) ($musteri->note ?? '');
        $this->telefon = (string) ($telefon->phone_e164 ?? '');
        $this->adres = (string) ($adres->address_text ?? '');
        $this->bolge = (string) ($adres->region ?? '');
    }

    /** @return array<string, mixed> */
    public function veri(): array
    {
        return [
            'id' => $this->musteriId,
            'ad' => $this->ad,
            'not' => $this->not,
            'telefon' => $this->telefon,
            'adres' => $this->adres,
            'bolge' => $this->bolge,
        ];
    }
}
