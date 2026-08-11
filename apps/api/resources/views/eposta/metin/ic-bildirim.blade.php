{{ $baslik }}
{{ str_repeat('=', mb_strlen($baslik)) }}
@if ($aciklama !== '')

{{ $aciklama }}
@endif

@foreach ($satirlar as $etiket => $deger)
{{ $etiket }}: {{ $deger }}
@endforeach
