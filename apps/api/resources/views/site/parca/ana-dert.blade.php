{{-- Ana sayfa · "Kâğıt defterin maliyeti" (09-sw-ana.jsx · DertBlm). --}}
<section class="blm kagit2">
    <div class="kap">
        {{--
            Başlık değişti (2026-08-19). Eskisi: "Kâğıt defter iyi bir defterdir. Kötü bir
            sistemdir." Zekice ama iki sebeple yanlış yerdeydi: (1) esnafın kendi defterini
            küçümsüyor — o defter yıllardır işini yürütmüş bir alet, ilk cümlede onu "kötü"
            ilan etmek satışın en kötü açılışı; (2) "X'dir. Y'dir." kalıbı sayfada üç ayrı
            başlıkta tekrarlanıyordu ve o tekrar, metnin bir insan tarafından yazılmadığı
            hissini veren şeyin ta kendisiydi. Yeni başlık aynı fikri suçlamadan söylüyor.
        --}}
        <x-site.blm-bas kulak="Sorun" baslik="Defter yanlış tutulmuyor. Tek bir defter yetmiyor."
            aciklama="Alacak bir yerde, telefondaki bilgi başka yerde, akşamki kasa üçüncü yerde. Sipario bu üçünü aynı yere getiriyor." />
        <div class="dert-grid">
            @foreach ($sw['dert'] as $i => $d)
                <div class="dert">
                    <div class="dert-ust">
                        <span class="dert-no mn">{{ str_pad((string) ($i + 1), 2, '0', STR_PAD_LEFT) }}</span>
                        <span class="dert-ik"><x-site.ikon :ad="$d['ik']" boy="22" kalin="1.9" /></span>
                    </div>
                    <h3 class="h3">{{ $d['t'] }}</h3>
                    <p class="gvd dert-a">{{ $d['a'] }}</p>
                    <div class="dert-c">
                        <x-site.ikon ad="ok" boy="16" kalin="2.4" renk="var(--mor)" />
                        <span>{{ $d['c'] }}</span>
                    </div>
                </div>
            @endforeach
        </div>
    </div>
</section>
