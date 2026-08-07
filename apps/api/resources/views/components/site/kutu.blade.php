{{-- Kutu — renkli bilgi kutusu. tur: mor|yesil|sari|kirmizi. ikon="false" ile ikon gizlenir. --}}
@props(['tur' => 'mor', 'ikon' => 'bilgi'])
<div class="kutu kutu-{{ $tur }}">
    @if($ikon !== false)
        <x-site.ikon :ad="$ikon" boy="17" kalin="2.1" />
    @endif
    <span>{{ $slot }}</span>
</div>
