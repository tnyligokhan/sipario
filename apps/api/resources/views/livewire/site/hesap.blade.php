{{--
    Hesap paneli — tasarım 14-sw-hesap.jsx. `site` layout'u zaten <main class="ic"> açtığı için
    kök burada <div class="hesap">tir (tasarımdaki <main class="ic hesap"> ikiye bölündü).

    TASARIMDAN ÇIKARILAN: sağ üstteki "Önizleme · Deneme / Abone" anahtarı. O bir prototip aracıydı;
    hesap durumunu istemciye seçtiren bir düğme, ekranın söylediği her şeyi kanıt olmaktan çıkarır.
    Durum `tenants.status`tan gelir.
--}}
@php
    $bayi = $this->bayi();
    $deneme = $this->deneme();
    $kalan = $this->kalanGun();
@endphp
<div class="hesap">
    <div class="kap">
        <div class="hs-bas">
            <div>
                <span class="blm-kulak mn"><i></i>Hesap</span>
                <h1 class="h1 ic-h1">{{ $bayi->name }}</h1>
                <p class="kucuk">{{ $this->isletme->yetkili ?: '—' }} · {{ $this->isletme->eposta }}</p>
            </div>
        </div>

        {{-- DurumBandi --}}
        <div class="hd gece">
            <div class="hd-g">
                <span class="mn">Plan</span>
                <b class="h3">
                    {{ $deneme ? 'Deneme sürümü' : 'Sipario · '.$this->donem()->etiket() }}
                </b>
                @if ($deneme)
                    <x-site.rozet tur="sari" :nokta="true">Ücretsiz · {{ $this->plan()->denemeGun() }} gün</x-site.rozet>
                @else
                    <x-site.rozet tur="yesil" :nokta="true" :canli="true">Aktif</x-site.rozet>
                @endif
            </div>
            <div class="hd-g">
                <span class="mn">{{ $deneme ? 'Deneme bitişi' : 'Sonraki tahsilat' }}</span>
                <b class="h3 tab">{{ $deneme ? $this->tarih($bayi->valid_until) : $this->tl($this->sonrakiTutar()) }}</b>
                <span class="kucuk">{{ $deneme ? 'O güne kadar ücret alınmaz' : $this->tarih($bayi->valid_until) }}</span>
            </div>
            <div class="hd-g">
                <span class="mn">Kalan süre</span>
                <b class="h3 tab">{{ $kalan }} gün</b>
                <div class="hd-bar">
                    <i class="{{ $deneme ? 'sari' : '' }}"
                        style="width:{{ min(100, (int) round($kalan / $this->toplamGun() * 100)) }}%"></i>
                </div>
            </div>
            <div class="hd-g">
                <span class="mn">Firma kodu</span>
                <b class="h3">{{ $bayi->slug }}</b>
                <span class="kucuk">Ekibiniz uygulamaya bu kodla girer</span>
            </div>
        </div>

        <div class="hs-ic">
            <nav class="hs-nav">
                @foreach (\App\Livewire\Site\Hesap::BOLUMLER as $anahtar => $ad)
                    <button type="button" class="hs-l {{ $bolum === $anahtar ? 'on' : '' }}"
                        wire:click="bolumSec('{{ $anahtar }}')">
                        <x-site.ikon :ad="['genel' => 'grafik', 'abonelik' => 'rozet', 'hak' => 'simsek', 'fatura' => 'belge', 'odeme' => 'kart', 'isletme' => 'bina'][$anahtar]"
                            boy="18" kalin="2" />{{ $ad }}
                    </button>
                @endforeach
            </nav>
            <div class="hs-govde">
                <h2 class="h2 hs-h2">{{ \App\Livewire\Site\Hesap::BOLUMLER[$bolum] }}</h2>
                @include('livewire.site.hesap.'.$bolum)
            </div>
        </div>
    </div>
</div>
