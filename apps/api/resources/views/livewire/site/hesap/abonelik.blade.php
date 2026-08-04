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
            <p class="kucuk">Deneme kendiliğinden ücretli aboneliğe dönmez. Karar vermezseniz hesap salt-okunur kipe geçer, verileriniz silinmez.</p>
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

    <x-site.pano etiket="{{ $deneme ? 'Aboneliği başlat' : 'Dönemi seçin' }}">
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
                <a class="dn-p {{ ! $deneme && $this->donem()->value === $p['k'] ? 'on' : '' }}"
                    href="{{ $this->odemeUrl($p['k']) }}">
                    @if ($p['k'] === 'yearly' && $hediye > 0)
                        <span class="hak-rzt mn">{{ $hediye }} ay hediye</span>
                    @endif
                    <span class="dn-p-ust"><i class="dn-p-r"></i>{{ $p['ad'] }}</span>
                    <b class="h2 tab">{{ $this->tlk($aylikTutar) }}</b>
                    <span class="kucuk">
                        aylık ·
                        {{ $p['k'] === 'yearly'
                            ? 'yılda '.$this->tl($p['kurus']).' tek ödeme'
                            : 'istediğiniz zaman bırakın' }}
                    </span>
                </a>
            @endforeach
        </div>

        <p class="kucuk" style="margin-top:20px">
            @if ($deneme)
                Ödemeyi havale/EFT ya da elden alıyoruz — kart bilgisi istemiyoruz. Kartla online ödeme yakında açılacak. Deneme süreniz {{ $this->tarih($bayi->valid_until) }} tarihinde bitiyor; erken ödemeniz kalan günlerinizi yakmaz, dönem o tarihten itibaren işler.
            @else
                Dönem, ödemenin yapıldığı anda belirlenir; saklanan bir "gelecek dönem" tercihi yoktur. Erken ödeme kalan günlerinizi yakmaz — yeni dönem {{ $this->tarih($bayi->valid_until) }} tarihinden itibaren işler.
            @endif
        </p>
    </x-site.pano>

    <x-site.pano :ince="true" etiket="{{ $deneme ? 'Denemeyi bırak' : 'Aboneliği sonlandır' }}">
        <p class="gvd">
            @if ($deneme)
                İşinize uygun bulmadıysanız bir şey yapmanız gerekmez — deneme kendiliğinden sona erer ve ücret işlemez.
            @else
                Otomatik yenileme zaten kapalıdır: ödeme yapmadığınız sürece dönem sonunda ({{ $this->tarih($bayi->valid_until) }}) yenileme olmaz. O tarihte hesap salt-okunur kipe geçer — kayıtlarınız silinmez, görmeye ve dışa aktarmaya devam edersiniz.
            @endif
            Hesabı büsbütün kapatmak isterseniz önce verilerinizi isteyin, sonra destek hattından kapatalım.
        </p>
        <div class="dg-grup" style="margin-top:18px">
            <button type="button" class="dg dg-c" wire:click="disaAktarTalep">
                <x-site.ikon ad="indir" boy="17" kalin="2.1" />Verilerimi isteyin
            </button>
            <a class="dg dg-d" href="{{ route('site.destek') }}">Destek hattı</a>
        </div>
    </x-site.pano>
</div>
