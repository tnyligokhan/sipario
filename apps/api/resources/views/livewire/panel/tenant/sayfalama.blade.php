{{-- Asgari sayfalama: Livewire'ın hazır görünümleri Tailwind/Bootstrap sınıfları basar, bu panelde
     ikisi de yok. $sayfalayici + $ad (page name) beklenir. --}}
@if ($sayfalayici->hasPages())
    <p class="pager">
        <button type="button" wire:click="previousPage('{{ $ad }}')" @disabled($sayfalayici->onFirstPage())>&larr; Önceki</button>
        <span class="hint">
            Sayfa {{ $sayfalayici->currentPage() }} / {{ $sayfalayici->lastPage() }}
            &middot; toplam {{ $sayfalayici->total() }} kayıt
        </span>
        <button type="button" wire:click="nextPage('{{ $ad }}')" @disabled(! $sayfalayici->hasMorePages())>Sonraki &rarr;</button>
    </p>
@else
    <p class="hint">Toplam {{ $sayfalayici->total() }} kayıt.</p>
@endif
