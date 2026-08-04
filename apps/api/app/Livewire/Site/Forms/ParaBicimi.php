<?php

namespace App\Livewire\Site\Forms;

/**
 * Sitenin para biçimi — tasarımın `tl()` / `tlk()` işlevlerinin sunucu karşılığı (05-sw-veri.jsx).
 *
 * NEDEN `<x-kurus>` BİLEŞENİ DEĞİL: o bileşen her hâlde iki hane basar ("5.988,00 ₺"), tasarım ise
 * tam tutarları kuruşsuz yazar ("5.988 ₺") ve yalnız taksit/birim fiyat gibi bölünmüş değerlerde
 * kuruş gösterir. Ekran metni sözleşmedir; biçim de metnin parçasıdır.
 *
 * Para her yerde İMZASIZ int KURUŞtur; `₺` YALNIZ burada, sunum anında eklenir.
 *
 * Bileşen görünümlerinde `{{ $this->tl($kurus) }}` olarak çağrılır.
 */
trait ParaBicimi
{
    /** Tam tutar — kuruş sıfırsa kuruşsuz yazılır (tasarımın `tl()`i). */
    public function tl(int $kurus): string
    {
        return $kurus % 100 === 0
            ? number_format(intdiv($kurus, 100), 0, ',', '.').' ₺'
            : number_format($kurus / 100, 2, ',', '.').' ₺';
    }

    /** Her zaman iki haneli (tasarımın `tlk()`si) — birim fiyat, hak başına ücret. */
    public function tlk(int|float $kurus): string
    {
        return number_format($kurus / 100, 2, ',', '.').' ₺';
    }
}
