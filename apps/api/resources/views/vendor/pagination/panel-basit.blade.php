{{--
    Livewire uyumlu sayfalama görünümü. Laravel'in `LengthAwarePaginator::links()` metodu
    $paginator + $elements'i otomatik geçirir (Livewire'a özel değil); wire:click'ler ise
    WithPagination trait'inin previousPage()/nextPage()/gotoPage() metodlarına gider — bu yüzden
    yalnızca Livewire bileşenleri içinde çalışır (WithPagination kullanan).

    Kullanım (Livewire bileşeninde):
        public function render()
        {
            return view('livewire.panel.odemeler', [
                'odemeler' => Payment::query()->latest()->paginate(20),
            ]);
        }
        // Blade'de: {{ $odemeler->links('vendor.pagination.panel-basit') }}

    Çift sayfalayıcılı ekranlarda ($paginator->getPageName() 'page' değilse) her şey otomatik
    doğru alana yazar — ek ayar gerekmez.

    Sınıf öneki bilerek "sayfalama": mevcut panelde (layouts/app.blade.php) ".pager" adında,
    elle yazılmış farklı bir sayfalama zaten var — isim çakışmasın diye ayrı ad kümesi.
--}}
@php
    if (! isset($scrollTo)) {
        $scrollTo = 'body';
    }

    $kaydirJs = $scrollTo !== false
        ? "(\$el.closest('{$scrollTo}') || document.querySelector('{$scrollTo}')).scrollIntoView()"
        : '';
@endphp

<div>
    @if ($paginator->hasPages())
        <nav class="sayfalama" role="navigation" aria-label="Sayfalama">
            @if ($paginator->onFirstPage())
                <button type="button" class="btn" disabled>
                    <x-panel.ikon ad="geri" boy="14" /> Önceki
                </button>
            @else
                <button
                    type="button"
                    class="btn"
                    wire:click="previousPage('{{ $paginator->getPageName() }}')"
                    x-on:click="{{ $kaydirJs }}"
                    wire:loading.attr="disabled"
                >
                    <x-panel.ikon ad="geri" boy="14" /> Önceki
                </button>
            @endif

            <span class="sayfalama-sayilar">
                @foreach ($elements as $eleman)
                    @if (is_string($eleman))
                        <span class="sayfalama-nokta">{{ $eleman }}</span>
                    @endif

                    @if (is_array($eleman))
                        @foreach ($eleman as $sayfa => $url)
                            @if ($sayfa == $paginator->currentPage())
                                <span class="sayfalama-sayfa secili" aria-current="page">{{ $sayfa }}</span>
                            @else
                                <button
                                    type="button"
                                    class="sayfalama-sayfa"
                                    wire:click="gotoPage({{ $sayfa }}, '{{ $paginator->getPageName() }}')"
                                    x-on:click="{{ $kaydirJs }}"
                                    aria-label="{{ $sayfa }}. sayfaya git"
                                >{{ $sayfa }}</button>
                            @endif
                        @endforeach
                    @endif
                @endforeach
            </span>

            @if ($paginator->hasMorePages())
                <button
                    type="button"
                    class="btn"
                    wire:click="nextPage('{{ $paginator->getPageName() }}')"
                    x-on:click="{{ $kaydirJs }}"
                    wire:loading.attr="disabled"
                >
                    Sonraki <x-panel.ikon ad="sagok" boy="14" />
                </button>
            @else
                <button type="button" class="btn" disabled>
                    Sonraki <x-panel.ikon ad="sagok" boy="14" />
                </button>
            @endif
        </nav>
        <p class="sayfalama-ozet soluk">
            {{ $paginator->firstItem() }}–{{ $paginator->lastItem() }} arası, toplam {{ $paginator->total() }} kayıt
        </p>
    @endif
</div>
