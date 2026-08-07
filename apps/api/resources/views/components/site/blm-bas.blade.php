{{-- BlmBas — bölüm başlığı: mono kulak + sola dayalı başlık + açıklama. --}}
@props(['kulak' => null, 'baslik', 'aciklama' => null, 'seviye' => 'h1', 'genis' => false])
<div class="blm-bas" @if($genis) style="max-width:780px" @endif>
    @if($kulak)<span class="blm-kulak mn"><i></i>{{ $kulak }}</span>@endif
    <h2 class="{{ $seviye }}">{{ $baslik }}</h2>
    @if($aciklama)<p class="gvd b">{{ $aciklama }}</p>@endif
    {{ $slot ?? '' }}
</div>
