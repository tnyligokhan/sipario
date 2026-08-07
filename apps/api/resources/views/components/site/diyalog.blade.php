{{--
    Diyalog — modal pencere. Kaynaktaki React portalı yerine düz DOM + position:fixed kullanılır
    (sayfa sarmalayıcısında giriş animasyonu olmadığı için içeren blok sorunu yoktur).

    `acik`   : görünürlüğü süren Alpine BOOLEAN İFADESİ (örn. "dg === 'aylik'")
    `onkapat`: kapatma eylemini yürüten Alpine İFADESİ (örn. "dg = null")
    `alt`    : isteğe bağlı alt slot — aksiyon butonları

    <x-site.diyalog acik="dg === 'aylik'" onkapat="dg = null" baslik="Aylık ödemeye geçiş">
        <p>...</p>
        <x-slot:alt><button class="dg dg-c" @click="dg = null">Vazgeç</button></x-slot:alt>
    </x-site.diyalog>
--}}
@props(['acik', 'onkapat', 'baslik', 'genis' => false])
<template x-if="{{ $acik }}">
    <div class="diyalog-fon" @click="{{ $onkapat }}" @keydown.escape.window="{{ $onkapat }}">
        <div @class(['diyalog']) @if($genis) style="max-width:620px" @endif @click.stop
            role="dialog" aria-modal="true" aria-labelledby="dlg-{{ substr(md5($baslik), 0, 8) }}">
            <div class="diyalog-bas">
                <span class="h3" id="dlg-{{ substr(md5($baslik), 0, 8) }}">{{ $baslik }}</span>
                <button type="button" class="diyalog-x" @click="{{ $onkapat }}" aria-label="Kapat">
                    <x-site.ikon ad="kapat" boy="19" kalin="2.2" />
                </button>
            </div>
            <div class="diyalog-ic">{{ $slot }}</div>
            @isset($alt)<div class="diyalog-alt">{{ $alt }}</div>@endisset
        </div>
    </div>
</template>
