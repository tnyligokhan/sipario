{{--
    Bildirim — kısa ömürlü alt-orta toast. Bir layout içine BİR KEZ yerleştirilir (site.blade.php /
    site-ciplak.blade.php / panel.blade.php — panelin kendi eşdeğeri <x-panel.tost>). Herhangi bir
    yerden tetiklemek için:
        window.dispatchEvent(new CustomEvent('bildir', { detail: 'Mesaj metni' }))
    veya Livewire tarafında: $this->dispatch('bildir', detail: 'Mesaj metni')->to(...)
    (Livewire olayları da window event'i olarak yayılır.)

    `goster()` metodu `public/js/alpine.js`teki `bildirimKutusu` bileşenindedir (csp_safe
    sıkılaştırması, 2026-08-04): `setTimeout`/`clearTimeout` gibi globallere Alpine'ın CSP
    değerlendiricisi öznitelik içinden erişime izin vermez, bu yüzden mantık gerçek bir JS
    metoduna taşındı — öznitelik yalnız `$event` magic'ini metoda geçirir.
--}}
<div x-data="bildirimKutusu"
    x-on:bildir.window="goster($event.detail)"
    x-show="metin" x-cloak x-transition class="bildirim" role="status" aria-live="polite">
    <x-site.ikon ad="tamam" boy="17" kalin="2.2" />
    <span x-text="metin"></span>
</div>
