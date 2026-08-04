{{--
    Oto-sıralama — tasarım HHak. Paket fiyatları SABİT YAZILMAZ: katalog `addon_packages`tan gelir
    (EkPaketServisi::paketler(true)) ve panelden yönetilir.
--}}
@php $hak = $this->hakKotasi(); @endphp

<div class="hb">
    <x-site.pano etiket="{{ $deneme ? 'Denemede kullanım' : 'Kullanım' }}">
        <x-site.kota etiket="Oto-sıralama hakkı" :kullanilan="$hak['kullanilan']" :toplam="$hak['toplam']"
            alt="{{ $hak['kalan'] }} hak kaldı · {{ $deneme ? 'deneme boyunca geçerli' : 'aylık kota '.$bayi->route_credits_monthly.' hak' }}" />
        <hr class="ayrac">
        <p class="gvd">Bir rota sıralaması çalıştırdığınızda bir hak düşer. Sıralamayı elle sürüklemek hak harcamaz. Satın aldığınız ek paketlerin süresi dolmaz.</p>
    </x-site.pano>

    <x-site.pano etiket="Ek paket al" :ic="false">
        @if ($deneme)
            <div style="padding:22px 22px 0">
                <x-site.kutu tur="mor" ikon="bilgi">
                    Denemede {{ $hak['toplam'] }} hak zaten yüklü geliyor. Ek paketleri aboneliği başlattıktan sonra satın alabilirsiniz.
                </x-site.kutu>
            </div>
        @endif

        @if ($this->hakPaketleri->isEmpty())
            <div class="hb-bos">
                <span class="hb-bos-ik"><x-site.ikon ad="simsek" boy="22" kalin="1.9" renk="var(--sonuk)" /></span>
                <b class="h4">Şu an satışta ek paket yok</b>
                <p class="kucuk">Ek hak ihtiyacınız varsa destek hattından bize ulaşın.</p>
            </div>
        @else
            <div class="hak-grid hb-hak">
                @foreach ($this->hakPaketleri as $paket)
                    <div class="hak">
                        <span class="rakam">{{ $paket->quantity }}</span>
                        <span class="hak-l mn">hak</span>
                        <span class="hak-f">{{ $this->tl($paket->price_kurus) }}</span>
                        <span class="kucuk">hak başına {{ $this->tlk($paket->price_kurus / max(1, $paket->quantity)) }}</span>
                        @if ($deneme)
                            <button type="button" class="dg dg-c tam gk" disabled>Satın al</button>
                        @else
                            <a class="dg dg-c tam gk" href="{{ $this->odemeUrl(null, $paket->id) }}">Satın al</a>
                        @endif
                    </div>
                @endforeach
            </div>
        @endif
    </x-site.pano>
</div>
