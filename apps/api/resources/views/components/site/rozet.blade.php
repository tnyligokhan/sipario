{{-- Rozet — durum pili. tur: mor|yesil|sari|kirmizi|notr. nokta: küçük renkli işaret. canli: nabız animasyonu. --}}
@props(['tur' => 'notr', 'nokta' => false, 'canli' => false])
<span @class(['rzt', "rzt-{$tur}", 'canli' => $canli])>
    @if($nokta || $canli)<i></i>@endif{{ $slot }}
</span>
