{{--
    Kullanım ve ek paketler — tasarım HHak'ın genişletilmişi.

    BÖLÜM İKİYE ÇIKTI (2026-08-05): sayfa yalnız oto-sıralama hakkı satıyordu, oysa `addon_packages`
    kataloğunda ek KURYE paketleri de var (`AddonPackage::TYPE_COURIER`) ve kotası (`courier_limit`)
    sunucuda gerçek — `KuryeKotasi` yeni kurye açılışını o limitle durduruyor. Bayi limite takıldığında
    ekranda hiçbir çıkış yolu görmüyordu; satılan bir şeyin satın alınacağı yer olmalı.

    FİYATLAR SABİT YAZILMAZ: iki bölümün de kartları katalogdan gelir (`EkPaketServisi::paketler(true)`,
    tek sorgu, `Hesap::paketler()` süzer) ve panelden yönetilir. Katalog boşsa "şu an satışta paket yok"
    deseni — uydurma fiyat yok.

    DENEMEDE SATIN ALMA KAPALI (iki bölümde de): tahsilat akışı aboneliğe bağlı; deneme hesabına ek
    paket satmak, henüz ödeme yapmamış bayiye fatura kesmek olurdu.

    PAKET PANOLARINDAKİ `:ic="false"` BİR TERCİH DEĞİL, IZGARA GENİŞLİĞİNİN ÖNKOŞULUDUR (2026-08-05,
    `stil` ile ölçüldü). `.hak-grid` `auto-fit minmax(240px,1fr)` + 18px boşlukla çiziliyor; 3 kartın
    yan yana kalabilmesi için iç genişlik ≥756px olmalı (3×240 + 2×18). Bugün 793px: 1180 (--en) − 56
    (.kap) − 284 (.hs-ic nav+boşluk) − 3 (.pano kenarlık) − 44 (.hb-hak dolgu). `:ic` kaldırılırsa
    araya `.pano-ic{padding:22px}` girer, genişlik 749'a düşer — 756'nın ALTI — ve üçüncü kart
    SESSİZCE alt satıra kayar. Dolguyu bu yüzden `.hb-hak` taşıyor.
--}}
@php
    $hak = $this->hakKotasi();
    $kurye = $this->kuryeKotasi();
@endphp

<div class="hb">
    {{-- ── Oto-sıralama hakkı ─────────────────────────────────────────────── --}}
    <x-site.pano etiket="{{ $deneme ? 'Denemede oto-sıralama' : 'Oto-sıralama' }}">
        <x-site.kota etiket="Oto-sıralama hakkı" :kullanilan="$hak['kullanilan']" :toplam="$hak['toplam']"
            alt="{{ $hak['kalan'] }} hak kaldı · {{ $deneme ? 'deneme boyunca geçerli' : 'aylık kota '.$bayi->route_credits_monthly.' hak' }}" />
        <hr class="ayrac">
        <p class="gvd">Bir rota sıralaması çalıştırdığınızda bir hak düşer. Sıralamayı elle sürüklemek hak harcamaz. Satın aldığınız ek paketlerin süresi dolmaz.</p>
    </x-site.pano>

    <x-site.pano etiket="Ek oto-sıralama hakkı" :ic="false">
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
                            <a class="dg dg-c tam gk" href="{{ $this->odemeUrl(null, $paket->id, 'hak') }}">Satın al</a>
                        @endif
                    </div>
                @endforeach
            </div>
        @endif
    </x-site.pano>

    {{-- ── Ek kurye ───────────────────────────────────────────────────────── --}}
    <x-site.pano etiket="{{ $deneme ? 'Denemede kurye hesapları' : 'Kurye hesapları' }}">
        <x-site.kota etiket="Kurye hesabı" :kullanilan="$kurye['kullanilan']" :toplam="$kurye['limit']"
            renk="var(--yesil)"
            alt="{{ $kurye['kalan'] }} hesap açabilirsiniz · limitiniz {{ $kurye['limit'] }} kurye" />
        <hr class="ayrac">
        <p class="gvd">
            Yalnız <b>aktif</b> kurye hesapları sayılır — işten ayrılan kuryeyi pasife aldığınızda hakkınız geri gelir,
            geçmiş teslimlerinde adı görünmeye devam eder. Patron ve operatör hesapları bu limite girmez.
        </p>
    </x-site.pano>

    <x-site.pano etiket="Ek kurye paketi" :ic="false">
        @if ($deneme)
            <div style="padding:22px 22px 0">
                <x-site.kutu tur="mor" ikon="bilgi">
                    Denemede {{ $kurye['limit'] }} kurye hesabı açabilirsiniz. Ek kurye paketlerini aboneliği başlattıktan sonra satın alabilirsiniz.
                </x-site.kutu>
            </div>
        @endif

        @if ($this->kuryePaketleri->isEmpty())
            <div class="hb-bos">
                <span class="hb-bos-ik"><x-site.ikon ad="musteri" boy="22" kalin="1.9" renk="var(--sonuk)" /></span>
                <b class="h4">Şu an satışta ek kurye paketi yok</b>
                <p class="kucuk">Daha fazla kurye hesabına ihtiyacınız varsa destek hattından bize ulaşın.</p>
            </div>
        @else
            <div class="hak-grid hb-hak">
                @foreach ($this->kuryePaketleri as $paket)
                    <div class="hak">
                        <span class="rakam">+{{ $paket->quantity }}</span>
                        <span class="hak-l mn">kurye</span>
                        <span class="hak-f">{{ $this->tl($paket->price_kurus) }}</span>
                        <span class="kucuk">hesap başına {{ $this->tlk($paket->price_kurus / max(1, $paket->quantity)) }}</span>
                        @if ($deneme)
                            <button type="button" class="dg dg-c tam gk" disabled>Satın al</button>
                        @else
                            <a class="dg dg-c tam gk" href="{{ $this->odemeUrl(null, $paket->id, 'hak') }}">Satın al</a>
                        @endif
                    </div>
                @endforeach
            </div>
        @endif

        <p class="kucuk" style="padding:0 22px 22px">
            Ek kurye hakkı kalıcıdır ve abonelik bitişini değiştirmez — bir SÜRE değil, KAPASİTE satın alırsınız.
            Ödemeniz kaydedildiğinde limitiniz büyür ve yeni kurye hesabını uygulamadan siz açarsınız.
        </p>
    </x-site.pano>
</div>
