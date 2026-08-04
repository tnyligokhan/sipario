{{--
    Fiyatlandırma · plan karşılaştırma tablosu (11-sw-fiyat.jsx · KarsilastirBlm).
    Hücre değeri true/false ise işaret, değilse metin basılır (kaynaktaki <H> yardımcısı).
--}}
<section class="blm">
    <div class="kap">
        <x-site.blm-bas kulak="Karşılaştırma" baslik="İki plan yan yana." />
        <x-site.pano ince :ic="false" class="krs">
            <table class="tbl krs-tbl">
                <caption class="gizli">Sipario ve Kurumsal planlarının karşılaştırması</caption>
                <thead>
                    <tr><th scope="col"><span class="gizli">Özellik</span></th><th scope="col">Sipario</th><th scope="col">Kurumsal</th></tr>
                </thead>
                <tbody>
                    @foreach ($sw['karsilastir'] as $g)
                        <tr class="krs-g"><td colspan="3"><span class="mn">{{ $g['g'] }}</span></td></tr>
                        @foreach ($g['s'] as $s)
                            <tr>
                                <td class="krs-ad">{{ $s[0] }}</td>
                                @foreach ([$s[1], $s[2]] as $v)
                                    <td class="krs-v">
                                        @if ($v === true)
                                            <x-site.ikon ad="onay" boy="18" kalin="2.6" renk="var(--yesil)" />
                                            <span class="gizli">Var</span>
                                        @elseif ($v === false)
                                            <span class="yok" aria-hidden="true">—</span>
                                            <span class="gizli">Yok</span>
                                        @else
                                            <span>{{ $v }}</span>
                                        @endif
                                    </td>
                                @endforeach
                            </tr>
                        @endforeach
                    @endforeach
                </tbody>
            </table>
        </x-site.pano>
    </div>
</section>
