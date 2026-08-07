{{-- Marka — Sipario logosu (ikon rozeti + wordmark). koyu: koyu zemin üstünde açık metin. --}}
@props(['boy' => 34, 'koyu' => false])
<span class="marka">
    <span class="marka-ik" style="width:{{ $boy }}px;height:{{ $boy }}px;border-radius:{{ $boy * 0.3 }}px">
        <x-site.ikon ad="cagri" :boy="$boy * 0.56" kalin="2.3" renk="#fff" />
    </span>
    <span class="marka-ad" @if($koyu) style="color:#F3F0EC" @endif>Sipario</span>
</span>
