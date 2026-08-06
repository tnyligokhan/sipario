{{--
    Fiyatlandırma · ek oto-sıralama hak paketleri (11-sw-fiyat.jsx · HakBlm).

    Paketler KATALOGDAN gelir (addon_packages · EkPaketServisi::paketler(true)) — sabit yazılmaz;
    satıştan çekilen paket burada da görünmez. "En avantajlı" rozeti hak başına en ucuz pakete
    hesaplanarak verilir (bkz. _kur.php).

    "Satın al" doğrudan ödeme ekranına gider: `?tur=paket&paket=<id>&geri=fiyatlar`. Sepeti sunucu
    kurar (Subscribe::mount) — tutar İSTEMCİDEN ALINMAZ, satışta olmayan/bilinmeyen paket sessizce
    aboneliğe düşer, uydurma tutar oluşmaz. Misafir kullanıcıyı da Subscribe kendisi girişe
    yönlendirir ("fiyat sayfasından gelen misafir bir hata değil"), o yüzden burada oturum
    kontrolü yapmıyoruz. `geri=fiyatlar` → "Vazgeç" bu sayfaya döner.
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
                        <a class="dg dg-c tam gk"
                            href="{{ route('subscription.subscribe', ['tur' => 'paket', 'paket' => $h['id'], 'geri' => 'fiyatlar']) }}">Satın al</a>
                    </div>
                @endforeach
            </div>
        </div>
    </section>
@endif
