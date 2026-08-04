{{--
    Bildirim — kısa ömürlü alt-orta toast. Bir layout içine BİR KEZ yerleştirilir (site.blade.php /
    site-ciplak.blade.php). Herhangi bir yerden tetiklemek için:
        window.dispatchEvent(new CustomEvent('bildir', { detail: 'Mesaj metni' }))
    veya Livewire tarafında: $this->dispatch('bildir', detail: 'Mesaj metni')->to(...)
    (Livewire olayları da window event'i olarak yayılır.)
--}}
<div x-data="{ metin: null, zamanlayici: null }"
    x-on:bildir.window="metin = $event.detail; clearTimeout(zamanlayici); zamanlayici = setTimeout(() => metin = null, 2600)"
    x-show="metin" x-cloak x-transition class="bildirim" role="status" aria-live="polite">
    <x-site.ikon ad="tamam" boy="17" kalin="2.2" />
    <span x-text="metin"></span>
</div>
