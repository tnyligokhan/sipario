{{--
    Ödeme akışı — tasarım 13-sw-odeme.jsx. `site-ciplak` kabuğu.

    YAZILMAYANLAR (bilinçli): kart formu, taksit ızgarası ve 3D Secure ekranı. Tasarımda kart
    seçeneği tıklanamaz bir `div`di ("Yakında" rozetli), yani o form zaten ölü koddu; iyzico da
    ERTELENDİ. Yazılmayan kod sızdırmaz.

    Tasarımın "basari" ekranı "Ödemeniz alındı." diyordu — burada YAZILAMAZ: kaydedilen şey bir
    BEYANDIR, para değil. Aynı ekranın havale/elden metinleri ("Dekont ulaştığı gün hesabınız
    açılır") kullanıldı.
--}}
<main class="od">
    <header class="od-ust">
        <div class="kap od-ust-ic">
            <a class="od-geri" href="{{ $iptalUrl }}">
                <x-site.ikon ad="okSol" boy="18" kalin="2.2" />Vazgeç
            </a>
            <x-site.marka boy="32" />
            <span class="od-guvenli"><x-site.ikon ad="kilit" boy="15" kalin="2.2" />Güvenli ödeme</span>
        </div>
    </header>

    @if ($tesekkur)
        <div class="kap ensiz od-basari">
            <span class="od-tik"><x-site.ikon ad="onay" boy="34" kalin="2.6" renk="#fff" /></span>
            <h1 class="h1">Bildiriminiz alındı.</h1>
            <p class="gvd b">
                @if ($tesekkurYol === 'iban')
                    Havale/EFT ödemelerinde hesabınız, dekont bize ulaştıktan sonra <b>aynı iş günü içinde</b> açılır.
                @else
                    Talebiniz alındı, bugün arayacağız. Tahsilat yapıldığı anda hesabınız açılır ve e-arşiv faturanız e-posta ile gönderilir.
                @endif
            </p>

            <x-site.pano :ince="true" :duz="true" :sikIc="true" class="ozet-pano"
                style="margin:30px 0;text-align:left">
                <div class="ozet-r"><span>Kalem</span><b>{{ $this->kalemAdi() }}</b></div>
                <div class="ozet-r"><span>Tutar</span><b class="tab">{{ $this->tl($tutarKurus) }}</b></div>
                <div class="ozet-r"><span>Yöntem</span><b>{{ $tesekkurYol === 'iban' ? 'Havale / EFT' : 'Elden ödeme' }}</b></div>
                <div class="ozet-r"><span>Referans kodu</span><b class="tab">{{ $referans }}</b></div>
            </x-site.pano>

            <div class="dg-grup" style="justify-content:center">
                <a class="dg dg-a" href="{{ route('site.hesap') }}">
                    Hesap paneline git<x-site.ikon ad="ok" boy="18" kalin="2.2" />
                </a>
            </div>
        </div>
    @else
        <div class="kap od-basl">
            <h1 class="h1 od-h1">Ödeme</h1>
            <p class="gvd od-lead">Aşağıdaki tutar tektir; ödeme adımında ek ücret çıkmaz.</p>
        </div>

        <div class="kap od-ic">
            <div class="od-sol">
                <div class="od-yol">
                    <button type="button" class="sec {{ $yol === 'havale' ? 'on' : '' }}" wire:click="$set('yol', 'havale')">
                        <span class="sec-nokta"></span>
                        <span class="sec-orta">
                            <span class="sec-bas">Havale / EFT</span>
                            <span class="sec-alt">Dekont ulaştığı gün hesabınız açılır</span>
                        </span>
                    </button>
                    <button type="button" class="sec {{ $yol === 'elden' ? 'on' : '' }}" wire:click="$set('yol', 'elden')">
                        <span class="sec-nokta"></span>
                        <span class="sec-orta">
                            <span class="sec-bas">Elden ödeme</span>
                            <span class="sec-alt">Bölgenizdeysek uğrayıp alıyoruz · makbuz yerinde</span>
                        </span>
                    </button>
                    <div class="sec yakinda">
                        <span class="sec-nokta"></span>
                        <span class="sec-orta">
                            <span class="sec-bas">Kredi / banka kartı<x-site.rozet tur="notr">Yakında</x-site.rozet></span>
                            <span class="sec-alt">Online kart ödemesi üzerinde çalışıyoruz</span>
                        </span>
                    </div>
                </div>

                @if ($yol === 'elden')
                    <div class="od-form">
                        <x-site.kutu tur="sari" ikon="bilgi">
                            Elden ödeme şu an Ankara, Antalya ve İzmir'de geçerli. Talebinizi bırakın, aynı gün içinde arayarak saat ayarlayalım.
                        </x-site.kutu>
                        <x-site.pano :ince="true" :duz="true" :sikIc="true" class="havale">
                            <div class="ozet-r"><span>Tutar</span><b class="tab">{{ $this->tl($tutarKurus) }}</b></div>
                            <div class="ozet-r"><span>İşletme</span><b>{{ $bayi->name }}</b></div>
                            <div class="ozet-r"><span>Telefon</span><b>{{ $bayi->phone ?: '—' }}</b></div>
                            <div class="ozet-r"><span>Makbuz</span><b>Teslimde elden verilir</b></div>
                        </x-site.pano>

                        @include('livewire.site.partials.odeme-onaylar')

                        <div class="dg-grup" style="margin-top:20px">
                            <button type="button" class="dg dg-a" wire:click="eldenBildir" wire:loading.attr="disabled">
                                <x-site.ikon ad="telefon" boy="17" kalin="2.1" />Beni arayın
                            </button>
                        </div>
                        <p class="od-kucuk">Tahsilat yapıldığı anda hesabınız açılır ve e-arşiv faturanız e-posta ile gönderilir.</p>
                    </div>
                @else
                    <div class="od-form" x-data="{ bilgi: @js(
                        'Alıcı ünvanı: '.$sirket['unvan'].' | Banka: '.$sirket['banka']
                        .' | IBAN: '.$sirket['iban'].' | Referans: '.$referans
                    ) }">
                        <x-site.kutu tur="sari" ikon="bilgi">
                            Havale/EFT ödemelerinde hesabınız, dekont bize ulaştıktan sonra <b>aynı iş günü içinde</b> açılır. Açıklama alanına referans kodunu yazmayı unutmayın.
                        </x-site.kutu>
                        <x-site.pano :ince="true" :duz="true" :sikIc="true" class="havale">
                            <div class="ozet-r"><span>Alıcı ünvanı</span><b>{{ $sirket['unvan'] }}</b></div>
                            <div class="ozet-r"><span>Banka</span><b>{{ $sirket['banka'] }}</b></div>
                            <div class="ozet-r"><span>IBAN</span><b class="tab">{{ $sirket['iban'] }}</b></div>
                            <div class="ozet-r"><span>Tutar</span><b class="tab">{{ $this->tl($tutarKurus) }}</b></div>
                            <div class="ozet-r"><span>Referans kodu</span><b class="tab">{{ $referans }}</b></div>
                        </x-site.pano>

                        <div class="dg-grup" style="margin-top:20px">
                            <button type="button" class="dg dg-c"
                                @click="navigator.clipboard?.writeText(bilgi); window.dispatchEvent(new CustomEvent('bildir', { detail: 'Hesap bilgileri kopyalandı' }))">
                                <x-site.ikon ad="kopyala" boy="17" kalin="2.1" />Bilgileri kopyala
                            </button>
                            <button type="button" class="dg dg-c" wire:click="bilgileriPostala" wire:loading.attr="disabled">
                                <x-site.ikon ad="posta" boy="17" kalin="2.1" />E-posta ile gönder
                            </button>
                        </div>

                        @include('livewire.site.partials.odeme-onaylar')

                        <button type="button" class="dg dg-a tam dev" style="margin-top:18px"
                            wire:click="havaleBildir" wire:loading.attr="disabled">
                            <span wire:loading.remove wire:target="havaleBildir">Havale yaptım</span>
                            <span class="donen" wire:loading wire:target="havaleBildir"></span>
                        </button>
                        <p class="od-kucuk">
                            "Havale yaptım" bir <b>beyandır</b> ve aboneliği kendiliğinden uzatmaz — dekont bize ulaştığında hesabınız açılır.
                        </p>
                    </div>
                @endif
            </div>

            <div class="od-sag">
                <x-site.pano etiket="Sipariş özeti" class="od-ozet">
                    <div class="od-kalem">
                        <div>
                            <b>{{ $this->kalemAdi() }}</b>
                            <span class="kucuk">
                                {{ $donemAralik }}@if ($tur === 'plan' && $donem === 'yearly' && $hediyeAy > 0) ({{ $hediyeAy }} ay hediye)@endif
                            </span>
                        </div>
                        <b class="tab">{{ $this->tl($tutarKurus) }}</b>
                    </div>
                    <hr class="ayrac">
                    <div class="od-r"><span>Ara toplam</span><span class="tab">{{ $this->tl($tutarKurus - $this->kdvKurus()) }}</span></div>
                    <div class="od-r"><span>KDV (%20)</span><span class="tab">{{ $this->tl($this->kdvKurus()) }}</span></div>
                    <div class="od-toplam">
                        <span class="h4">Ödenecek tutar</span>
                        <b class="rakam kucuk-rakam tab">{{ $this->tl($tutarKurus) }}</b>
                    </div>
                    <div class="od-guven">
                        <x-site.ikon ad="kalkan" boy="17" kalin="2" renk="var(--yesil)" />
                        <span>Ödemenizi havale/EFT ya da elden alıyoruz. Kartla online ödeme yakında açılacak.</span>
                    </div>
                </x-site.pano>
            </div>
        </div>
    @endif
</main>
