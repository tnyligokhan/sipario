<?php

namespace App\Mail;

/**
 * İÇ BİLDİRİM — BİZE gelen posta (destek kutusu). Bayiye gitmez.
 *
 * BUNUN YERİNE GEÇTİĞİ ŞEY: `Livewire\Site\Hesap::disaAktarTalep()` içindeki `Mail::raw` bloğu.
 *
 * MÜŞTERİ POSTASINDAN İKİ FARKI VAR ve ikisi de bilinçlidir:
 *
 *  1. KONU SATIRINDA "Sipario ·" ÖN EKİ VARDIR. Müşteriye giden postalarda bu ön ek yasak
 *     (gönderen adı zaten Sipario, konu satırı telefonda kırpılıyor); ama BU postalar bizim
 *     kutumuza düşer ve orada ön ek bir SÜZGEÇ ANAHTARIDIR — kural yazıp klasöre düşürürüz.
 *
 *  2. SATIŞ/NEZAKET DİLİ YOKTUR. Selam, imza, "kolay gelsin" yok; yalnız olgular. Bunu okuyan
 *     kişi bir işi kuyruğa alacak, ikna edilmeyecek.
 *
 * ⚠️ KVKK (kırmızı çizgi #4): bu postaya bayinin KENDİ MÜŞTERİSİNİN verisi (ad, telefon, adres)
 * KONULAMAZ. Taşınabilecek şey bayinin kendi kimliğidir (işletme, firma kodu, yetkili) — çağıran
 * taraf bu sınırı gözetmek zorundadır; burada kısıt biçimsel olarak zorlanamaz.
 */
class IcBildirim extends SiparioPostasi
{
    /**
     * @param  array<string, string>  $satirlar
     */
    public function __construct(
        public readonly string $baslik,
        public readonly string $konuEki,
        public readonly array $satirlar,
        public readonly string $aciklama = '',
    ) {}

    protected function sablon(): string
    {
        return 'ic-bildirim';
    }

    protected function konu(): string
    {
        return 'Sipario · '.$this->konuEki;
    }

    protected function onizleme(): string
    {
        return $this->aciklama !== '' ? $this->aciklama : $this->baslik;
    }
}
