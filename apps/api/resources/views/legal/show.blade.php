{{--
    Hukuk belgesi görüntüleme (5d iskeleti). Route: /sozlesme/{doc}. İçerik legal/docs/<slug>.blade.php
    partial'inden gelir (PLACEHOLDER — tam metin + hukuk onayı insan işidir). Sürüm config'den.
--}}
<x-layouts.app>
    <div class="card" style="max-width: 720px;">
        <h1>{{ $title }}</h1>
        <p class="status">Sürüm: {{ $version }}</p>
        <div style="margin-top:1rem; line-height:1.6;">
            @include('legal.docs.' . $slug)
        </div>
        <p style="margin-top:2rem;"><a href="{{ route('subscription.subscribe') }}">← Aboneliğe dön</a></p>
    </div>
</x-layouts.app>
