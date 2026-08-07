<?php

namespace App\Livewire\Panel\Forms;

use Livewire\Attributes\Validate;
use Livewire\Form;

/**
 * Panelden ürün ekleme/düzenleme formu (5c-3 · D3).
 *
 * Fiyat kullanıcıya LİRA olarak sorulur, sisteme KURUŞ olarak girer (para her yerde tamsayı
 * kuruştur — DECISIONS). Dönüşüm tek yerde, burada; ekranda "45,00" yazıp veritabanına 4500
 * yazmak formun işidir, servisin değil.
 *
 * Görsel (image_url) ve aktiflik formda YOK: ilki panelde girilmiyor, ikincisi ayrı düğme.
 * İkisi de düzenlemede korunur (PanelWriteService mevcut satırdan okur).
 */
class UrunForm extends Form
{
    /** null = yeni kayıt; dolu = düzenleme. */
    public ?string $urunId = null;

    #[Validate('required|string|min:2|max:120')]
    public string $ad = '';

    /** Lira cinsinden metin ("45" ya da "45,50"). */
    #[Validate('required|string|max:20')]
    public string $fiyat = '';

    #[Validate('nullable|string|max:20')]
    public string $birim = 'adet';

    /**
     * 64 DEĞİL 32: `products.barcode` kolonu `varchar(32)`. Daha geniş bir sınır, kolonu aşan
     * değeri Postgres'e taşır ve `22001` üretir — o kod `SyncService::CLIENT_DATA_SQLSTATES`
     * listesinde olmadığı için olay bazında reddedilmez, partiyi düşürür. Sınır formda durmalı ki
     * kullanıcı alanın altında hatayı görsün.
     */
    #[Validate('nullable|string|max:32')]
    public string $barkod = '';

    public function doldur(object $urun): void
    {
        $this->urunId = (string) $urun->id;
        $this->ad = (string) $urun->name;
        $this->fiyat = number_format(((int) $urun->unit_price_kurus) / 100, 2, ',', '');
        $this->birim = (string) ($urun->unit ?: 'adet');
        $this->barkod = (string) ($urun->barcode ?? '');
    }

    /** @return array<string, mixed> */
    public function veri(): array
    {
        return [
            'id' => $this->urunId,
            'ad' => $this->ad,
            'fiyat_kurus' => $this->fiyatKurus(),
            'birim' => $this->birim,
            'barkod' => $this->barkod,
        ];
    }

    /**
     * "45,50" / "45.50" / "45" → kuruş. Virgül de nokta da ondalık ayırıcı sayılır (klavye alışkanlığı
     * kişiden kişiye değişir); binlik ayırıcı KABUL EDİLMEZ çünkü "1.500" iki farklı şey demek olurdu.
     */
    public function fiyatKurus(): int
    {
        $ham = str_replace(',', '.', trim($this->fiyat));

        return (int) round(((float) $ham) * 100);
    }
}
