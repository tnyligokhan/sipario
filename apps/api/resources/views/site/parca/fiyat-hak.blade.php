{{--
    Fiyatlandırma · ek oto-sıralama hak paketleri (11-sw-fiyat.jsx · HakBlm).

    Paketler KATALOGDAN gelir (addon_packages · EkPaketServisi::paketler(true)) — sabit yazılmaz;
    satıştan çekilen paket burada da görünmez. "En avantajlı" rozeti hak başına en ucuz pakete
    hesaplanarak verilir (bkz. _kur.php).

    "Satın al" hesap paneline giriş üzerinden yürür; site.hesap oturum ister ve misafirde
    yönlendirme hedefi tanımlı değil, o yüzden doğrudan giriş sayfasına bağlanıyor.
--}}
@if (! empty($fiyat['kontorPaketleri']))
    <section class="blm kagit2">
        <div class="kap">
            <x-site.blm-bas kulak="Ek paket" baslik="Oto-sıralama hakkı bitince."
                aciklama="Planınızda ayda {{ $fiyat['kontor'] }} hak var. Yoğun aylarda tükenirse tek seferlik paket alın — süresi dolmaz, devreder." />
            <div class="hak-grid">
                @foreach ($fiyat['kontorPaketleri'] as $h)
                    <div @class(['hak', 'iyi' => $h['iyi']])>
                        @if ($h['iyi'])<span class="hak-rzt mn">En avantajlı</span>@endif
                        <span class="rakam">{{ $h['adet'] }}</span>
                        <span class="hak-l mn">hak</span>
                        <span class="hak-f">{{ $h['fiyat'] }}</span>
                        <span class="kucuk">hak başına {{ $h['birim'] }}</span>
                        <a class="dg dg-c tam gk" href="{{ route('subscription.login') }}">Satın al</a>
                    </div>
                @endforeach
            </div>
        </div>
    </section>
@endif
