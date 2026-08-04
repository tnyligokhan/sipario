{{--
    Global tost (bildirim baloncuğu). Layout içine BİR KEZ konur (bkz. layouts/panel.blade.php).
    Herhangi bir Livewire bileşeni şöyle tetikler:
        $this->dispatch('tost', mesaj: 'Ödeme kaydedildi · abonelik bitişi 4 Eylül 2026 oldu');
    3.2 saniye sonra kendiliğinden kaybolur; art arda gelen olaylar zamanlayıcıyı sıfırlar.
--}}
<div
    x-data="{ acik: false, mesaj: '', zamanlayici: null }"
    x-on:tost.window="
        mesaj = $event.detail.mesaj;
        acik = true;
        clearTimeout(zamanlayici);
        zamanlayici = setTimeout(() => acik = false, 3200);
    "
    x-show="acik"
    x-transition
    x-cloak
    class="tost"
    role="status"
    aria-live="polite"
    x-text="mesaj"
    style="display:none"
></div>
