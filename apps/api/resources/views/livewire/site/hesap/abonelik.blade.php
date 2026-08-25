{{--
    Abonelik — tasarım HAbonelik / HAbonelikDeneme.

    TASARIMDAN ÜÇ SAPMA, üçü de raporlandı:

    1. "Kurumsal'a yükselt" YOK: `plans` tablosu TEK satırlıdır, kurumsal diye bir plan/fiyat
       yoktur. Tasarımdaki 1.499 ₺ ve "3.936 ₺ mahsup" rakamları örnektir; olmayan bir planı
       satmak, karşılığı olmayan bir söz vermektir.

    2. "Planı değiştir" bir TERCİH KAYDI değil, ÖDEME ADIMIdır. Dönem, `subscription_payments`ta
       ödemeyle birlikte belirlenir (`BillingPeriod`); saklanan bir "gelecek dönem tercihi" alanı
       yok. `tenants.billing_period`i şimdi çevirmek, hiç ödenmemiş bir dönemi ödenmiş gibi
       göstermek olurdu. Erken ödeme kalan günleri YAKMAZ (`valid_until > now ? valid_until : now`
       kuralı — SubscriptionService::activate ile aynı), o yüzden bugün ödemek bir kayıp değildir
       ve metin bunu söyler.

    3. "Aboneliği iptal et" düğmesi YOK. `TenantStatus::Cancelled` yazmak yazmayı ANINDA kapatır
       ve bu, ekranın hemen üstündeki "dönem sonuna kadar hiçbir şey değişmez" cümlesinin tam
       tersidir. Kayıt tutulacak bir "iptal talebi" kuyruğu da yok. Ayrılma sebebi sorusu da bu
       yüzden sorulmuyor (kaydedilecek yeri yok). İptal, destek kanalından yürür.
--}}
<div class="hb">
    @if ($deneme)
        <x-site.pano etiket="Mevcut durum">
            <x-slot:sag><x-site.rozet tur="sari" :nokta="true">Deneme</x-site.rozet></x-slot:sag>
            <div class="ab-satirlar">
                <div class="ozet-r"><span>Deneme başlangıcı</span><b>{{ $this->tarih($bayi->created_at) }}</b></div>
                <div class="ozet-r"><span>Deneme bitişi</span><b>{{ $this->tarih($bayi->valid_until) }} · {{ $kalan }} gün kaldı</b></div>
                <div class="ozet-r"><span>Ödeme yöntemi</span><b style="color:var(--sonuk)">Kayıtlı kart yok</b></div>
                <div class="ozet-r"><span>Otomatik yenileme</span><b style="color:var(--sonuk)">Kapalı</b></div>
            </div>
            <hr class="ayrac">
            {{-- "salt-okunur kip" yerine kullanıcının gördüğü davranış (2026-08-19; aynı düzeltme
                 hesap/genel.blade.php ve site SSS'inde de yapıldı — tek bir yerde bırakmak,
                 aynı şeyi iki farklı dille anlatan bir ürün üretirdi). --}}
            <p class="kucuk">Deneme kendiliğinden ücretli aboneliğe dönmez; kartınızdan bir şey çekilmez. Karar vermezseniz süre dolduğunda yeni kayıt giremezsiniz, o kadar — girdikleriniz olduğu gibi durur.</p>
        </x-site.pano>
    @else
        <x-site.pano etiket="Mevcut plan">
            <x-slot:sag><x-site.rozet tur="yesil" :nokta="true">Aktif</x-site.rozet></x-slot:sag>
            <div class="ab-ust">
                <div>
                    <span class="h2">Sipario</span>
                    <p class="gvd">{{ $this->donem()->etiket() }} ödeme · dönem sonu {{ $this->tarih($bayi->valid_until) }}</p>
                </div>
                <div class="ab-fiyat">
                    <b class="rakam kucuk-rakam tab">{{ $this->tl($this->sonrakiTutar()) }}</b>
                    <span class="kucuk">{{ $this->donem() === \App\Enums\BillingPeriod::Yearly ? 'yılda bir' : 'ayda bir' }} · KDV dahil</span>
                </div>
            </div>
            <hr class="ayrac">
            <div class="ab-satirlar">
                <div class="ozet-r"><span>Sonraki tahsilat</span><b>{{ $this->tarih($bayi->valid_until) }}</b></div>
                <div class="ozet-r"><span>Ödeme yöntemi</span><b>Havale / EFT · elden</b></div>
                <div class="ozet-r"><span>Otomatik yenileme</span><b style="color:var(--sonuk)">Kapalı · her dönem elle ödenir</b></div>
            </div>
        </x-site.pano>
    @endif

    <x-site.pano etiket="{{ $deneme ? 'Aboneliği başlat' : 'Yenileme ödemesi' }}">
        @unless ($deneme)
            {{--
                AÇIKLAMA KARTLARIN ÜSTÜNDE, altında değil: bayi buradaki düğmeleri bir AYAR sanıp
                tıklıyordu ("Dönemi seçin" başlığı + radyo düğmeli kartlar öyle okunuyordu). Neyin
                ne olduğu tıklamadan ÖNCE okunmalı.
            --}}
            <p class="gvd" style="margin-bottom:20px">
                Şu an <b>{{ $this->donem()->etiket() }}</b> ödüyorsunuz; dönem {{ $this->tarih($bayi->valid_until) }} tarihinde bitiyor.
                Aşağıdakiler bir ayar değil, <b>ödeme adımıdır</b> — tıkladığınızda ödeme sayfasına gidersiniz,
                hiçbir tercih kaydedilmez. Dönem, ödemenin yapıldığı anda belirlenir; saklanan bir "gelecek dönem"
                tercihi yoktur. Erken ödemeniz kalan günlerinizi yakmaz: yeni dönem {{ $this->tarih($bayi->valid_until) }} tarihinden itibaren işler.
            </p>
        @endunless

        <div class="dn-plan">
            @foreach ([
                ['k' => 'yearly', 'ad' => 'Yıllık', 'kurus' => $this->plan()->yillikKurus()],
                ['k' => 'monthly', 'ad' => 'Aylık', 'kurus' => $this->plan()->aylikKurus()],
            ] as $p)
                @php
                    $aylikTutar = $p['k'] === 'yearly' ? $p['kurus'] / 12 : $p['kurus'];
                    $hediye = $this->plan()->aylikKurus() > 0
                        ? (int) round(($this->plan()->aylikKurus() * 12 - $this->plan()->yillikKurus()) / $this->plan()->aylikKurus())
                        : 0;
                @endphp
                {{--
                    ABONEDE RADYO DÜĞMESİ (`dn-p-r`) VE SEÇİLİ VURGUSU (`on`) YOK. İkisi de bir
                    form kontrolünün görsel dilidir; burada tıklanan şey bir seçenek değil, ödeme
                    sayfasına giden bir bağlantıdır. Hangi dönemin geçerli olduğu kartın kendi
                    metniyle söyleniyor — vurguyla değil. Denemede kart gerçekten bir başlangıç
                    seçimidir, orada radyo kalıyor.
                --}}
                <a class="dn-p" href="{{ $this->odemeUrl($p['k'], null, 'abonelik') }}">
                    @if ($p['k'] === 'yearly' && $hediye > 0)
                        <span class="hak-rzt mn">{{ $hediye }} ay hediye</span>
                    @endif
                    <span class="dn-p-ust">
                        @if ($deneme)<i class="dn-p-r"></i>@endif{{ $deneme ? $p['ad'] : $p['ad'].' ödeme yap' }}
                    </span>
                    <b class="h2 tab">{{ $this->tlk($aylikTutar) }}</b>
                    <span class="kucuk">
                        aylık ·
                        {{ $p['k'] === 'yearly'
                            ? 'yılda '.$this->tl($p['kurus']).' tek ödeme'
                            : 'istediğiniz zaman bırakın' }}
                    </span>
                    @if (! $deneme && $this->donem()->value === $p['k'])
                        <span class="kucuk" style="color:var(--mor);font-weight:700">Şu an bu dönemdesiniz</span>
                    @endif
                </a>
            @endforeach
        </div>

        {{--
            Abonedeki metin YUKARI TAŞINDI (kartların üstüne). Burada bir kopyası kalsaydı aynı şey
            iki kez yazılırdı; kalan cümle her iki durumda da geçerli olan tahsilat yoludur.
        --}}
        <p class="kucuk" style="margin-top:20px">
            Ödemeyi havale/EFT ya da elden alıyoruz — kart bilgisi istemiyoruz. Kartla online ödeme yakında açılacak.
            @if ($deneme)
                Deneme süreniz {{ $this->tarih($bayi->valid_until) }} tarihinde bitiyor; erken ödemeniz kalan günlerinizi yakmaz, dönem o tarihten itibaren işler.
            @endif
        </p>
    </x-site.pano>

    <x-site.pano :ince="true" etiket="{{ $deneme ? 'Denemeyi bırak' : 'Aboneliği sonlandır' }}">
        <p class="gvd">
            @if ($deneme)
                İşinize uygun bulmadıysanız bir şey yapmanız gerekmez — deneme kendiliğinden sona erer ve ücret işlemez.
            @else
                Otomatik yenileme zaten kapalı: ödeme yapmadığınız sürece dönem sonunda ({{ $this->tarih($bayi->valid_until) }}) bir şey yenilenmez. O tarihte yeni kayıt giremezsiniz — kayıtlarınız silinmez, görmeye ve dışa aktarmaya devam edersiniz.
            @endif
            Hesabı büsbütün kapatmak isterseniz önce verilerinizi alın, sonra destek hattından birlikte kapatalım.
        </p>
        <div class="dg-grup" style="margin-top:18px">
            {{--
                DÜĞME ADI DÜZELTİLDİ (2026-08-19). Eskisi "Verilerimi isteyin"di ve emir kipi
                YANLIŞ TARAFA bakıyordu: düğmeye basan bayidir, ama cümle bize "isteyin" diyor.
                Bayi kendi ekranında kendine emir veriyor gibi okunuyordu. Düğme metni, basanın
                ne yaptığını söylemeli.
            --}}
            <button type="button" class="dg dg-c" wire:click="disaAktarTalep">
                <x-site.ikon ad="indir" boy="17" kalin="2.1" />Verilerimi gönderin
            </button>
            <a class="dg dg-d" href="{{ route('site.destek') }}">Destek hattı</a>
        </div>
    </x-site.pano>
</div>
