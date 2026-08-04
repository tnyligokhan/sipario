{{-- Genel bakış — deneme ve abone iki ayrı ekran (tasarım: HGenel / HGenelDeneme). --}}
@php
    $hak = $this->hakKotasi();
    $kurye = $this->kuryeKotasi();
@endphp

<div class="hb">
    @if ($deneme)
        @php $kurulum = $this->kurulum; $bitti = collect($kurulum)->where('bitti', true)->count(); @endphp

        <x-site.pano etiket="Aboneliğe geçiş">
            <x-slot:sag>
                <x-site.rozet tur="sari" :nokta="true">{{ $kalan }} gün kaldı</x-site.rozet>
            </x-slot:sag>
            <div class="ab-ust">
                <div>
                    <span class="h2">Deneme {{ $this->tarih($bayi->valid_until) }}'da bitiyor</span>
                    <p class="gvd">Bittiğinde hesabınız salt-okunur kipe geçer — kayıtlarınız silinmez. Aboneliği şimdi başlatsanız bile ücret {{ $this->tarih($bayi->valid_until) }} tarihinde işler.</p>
                </div>
                <div class="ab-fiyat">
                    <b class="rakam kucuk-rakam tab">{{ $this->tlk($this->plan()->yillikKurus() / 12) }}</b>
                    <span class="kucuk">aylık · yıllık ödemede</span>
                </div>
            </div>
            <div class="dg-grup" style="margin-top:22px">
                <button type="button" class="dg dg-a" wire:click="bolumSec('abonelik')">
                    Aboneliği başlat<x-site.ikon ad="ok" boy="18" kalin="2.2" />
                </button>
                <a class="dg dg-d" href="{{ route('site.fiyatlar') }}">Planları karşılaştır</a>
            </div>
        </x-site.pano>

        <x-site.pano etiket="Kurulum" :ic="false">
            <x-slot:sag>
                <span class="mn" style="color:var(--sonuk)">{{ $bitti }}/{{ count($kurulum) }} tamam</span>
            </x-slot:sag>
            <div class="dn-liste">
                @foreach ($kurulum as $i => $adim)
                    <div class="dn-s {{ $adim['bitti'] ? 'ok' : '' }}">
                        <span class="dn-s-ik">
                            @if ($adim['bitti'])
                                <x-site.ikon ad="onay" boy="15" kalin="2.6" renk="#fff" />
                            @else
                                <b class="mn">{{ $i + 1 }}</b>
                            @endif
                        </span>
                        <span class="dn-s-m"><b>{{ $adim['ad'] }}</b><small>{{ $adim['alt'] }}</small></span>
                    </div>
                @endforeach
            </div>
        </x-site.pano>

        <div class="hb-ikili">
            <x-site.pano etiket="Oto-sıralama hakkı">
                <x-site.kota etiket="Denemede kullanılan" :kullanilan="$hak['kullanilan']" :toplam="$hak['toplam']"
                    alt="Deneme boyunca {{ $hak['toplam'] }} hak ücretsiz · {{ $hak['kalan'] }} hak kaldı" />
            </x-site.pano>
            <x-site.pano etiket="Kullanıcılar">
                <x-site.kota etiket="Kurye hesabı" :kullanilan="$kurye['kullanilan']" :toplam="$kurye['limit']"
                    renk="var(--yesil)" alt="Denemede {{ $kurye['limit'] }} kurye hesabı açabilirsiniz" />
            </x-site.pano>
        </div>

        {{--
            Tasarımda bu üç satır birer toast basıyordu ("Talebiniz alındı…") ve arkasında hiçbir şey
            yoktu. Üçü de destek sayfasına GERÇEK bağlantı yapıldı: gittiği bir yer olan bir düğme,
            hiçbir yere gitmeyen bir bildirimden iyidir.
        --}}
        <x-site.pano etiket="Başlarken yardım" :ic="false">
            <div class="hb-kisa">
                @foreach ([
                    ['telefon', 'Kurulum görüşmesi ayarlayın', '20 dakika · ekranınızı birlikte kuralım'],
                    ['katman', 'Mevcut müşteri listemi taşıyın', 'Excel veya defter fotoğrafı gönderin, biz gireriz'],
                    ['kulaklik', 'Destek merkezi', 'Sık sorulanlar ve video anlatımlar'],
                ] as [$ik, $bas, $alt])
                    <a class="hb-k" href="{{ route('site.destek') }}">
                        <span class="hb-k-ik"><x-site.ikon :ad="$ik" boy="19" kalin="2" renk="var(--mor)" /></span>
                        <span><b>{{ $bas }}</b><small>{{ $alt }}</small></span>
                        <x-site.ikon ad="sag" boy="17" kalin="2.2" renk="var(--sonuk)" />
                    </a>
                @endforeach
            </div>
        </x-site.pano>
    @else
        <div class="hb-ikili">
            <x-site.pano etiket="Oto-sıralama hakkı">
                <x-slot:sag>
                    <button type="button" class="dg dg-d gk" wire:click="bolumSec('hak')">Yönet</button>
                </x-slot:sag>
                <x-site.kota etiket="Kullanılan" :kullanilan="$hak['kullanilan']" :toplam="$hak['toplam']"
                    alt="{{ $hak['kalan'] }} hak kaldı · aylık kota {{ $bayi->route_credits_monthly }}" />
            </x-site.pano>
            <x-site.pano etiket="Kullanıcılar">
                <x-site.kota etiket="Kurye hesabı" :kullanilan="$kurye['kullanilan']" :toplam="$kurye['limit']"
                    renk="var(--yesil)" alt="Planınız {{ $kurye['limit'] }} kurye içerir" />
            </x-site.pano>
        </div>

        <x-site.pano etiket="Kısayollar" :ic="false">
            <div class="hb-kisa">
                @foreach ([['kart', 'Ödeme bilgilerini gör', 'odeme'], ['belge', 'Ödeme geçmişini gör', 'fatura'],
                    ['simsek', 'Ek oto-sıralama hakkı al', 'hak'], ['bina', 'Fatura bilgilerini düzenle', 'isletme']] as [$ik, $etiket, $hedef])
                    <button type="button" class="hb-k" wire:click="bolumSec('{{ $hedef }}')">
                        <span class="hb-k-ik"><x-site.ikon :ad="$ik" boy="19" kalin="2" renk="var(--mor)" /></span>
                        <span>{{ $etiket }}</span>
                        <x-site.ikon ad="sag" boy="17" kalin="2.2" renk="var(--sonuk)" />
                    </button>
                @endforeach
            </div>
        </x-site.pano>

        <x-site.pano etiket="Son işlemler" :ic="false">
            <x-slot:sag>
                <button type="button" class="dg dg-d gk" wire:click="bolumSec('fatura')">Tümü</button>
            </x-slot:sag>
            @if ($this->odemeler->isEmpty())
                <div class="hb-bos">
                    <span class="hb-bos-ik"><x-site.ikon ad="belge" boy="22" kalin="1.9" renk="var(--sonuk)" /></span>
                    <b class="h4">Henüz ödeme kaydı yok</b>
                    <p class="kucuk">İlk ödemeniz kaydedildiğinde burada görünür.</p>
                </div>
            @else
                <table class="tbl">
                    <tbody>
                        @foreach ($this->odemeler->take(3) as $odeme)
                            <tr>
                                <td>
                                    <b>{{ $this->kalemAdi($odeme) }}</b><br>
                                    <span class="kucuk">{{ $this->tarih($odeme->occurred_at) }} · {{ $this->yontemAdi($odeme->provider) }}</span>
                                </td>
                                <td class="sag tab"><b>{{ $this->tl($odeme->amount_kurus) }}</b></td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            @endif
        </x-site.pano>
    @endif
</div>
