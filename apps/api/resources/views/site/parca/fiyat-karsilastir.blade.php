{{--
    Fiyatlandırma · plan detay tablosu (11-sw-fiyat.jsx · KarsilastirBlm).
    Hücre değeri true/false ise işaret, değilse metin basılır (kaynaktaki <H> yardımcısı).

    TEK PAKET (2026-08-05): tablo eskiden "Sipario / Kurumsal" iki değer sütunluydu. Kurumsal
    satılmadığı için karşılaştırılacak ikinci plan yok — tablo TEK değer sütununa indi ve artık
    "planda ne var" sorusunu yanıtlıyor. Satır verisi için bkz. _veri.php · `karsilastir`.
--}}
<section class="blm">
    <div class="kap">
        <x-site.blm-bas kulak="Detaylar" baslik="Planın içinde ne var?" />
        <x-site.pano ince :ic="false" class="krs">
            {{-- .krs'te overflow:hidden var: tablo dar ekranda taşarsa kaydırılamadan KIRPILIRDI.
                 .tbl-sar (overflow-x:auto) fatura tablosundaki mevcut desen — sığdığında görsel fark sıfır. --}}
            <div class="tbl-sar">
            <table class="tbl krs-tbl krs-tek">
                <caption class="gizli">Sipario planının kapsamı</caption>
                <thead>
                    <tr><th scope="col"><span class="gizli">Özellik</span></th><th scope="col">Sipario</th></tr>
                </thead>
                <tbody>
                    @foreach ($sw['karsilastir'] as $g)
                        <tr class="krs-g"><td colspan="2"><span class="mn">{{ $g['g'] }}</span></td></tr>
                        @foreach ($g['s'] as $s)
                            <tr>
                                <td class="krs-ad">{{ $s[0] }}</td>
                                <td class="krs-v">
                                    @if ($s[1] === true)
                                        <x-site.ikon ad="onay" boy="18" kalin="2.6" renk="var(--yesil)" />
                                        <span class="gizli">Var</span>
                                    @elseif ($s[1] === false)
                                        <span class="yok" aria-hidden="true">—</span>
                                        <span class="gizli">Yok</span>
                                    @else
                                        <span>{{ $s[1] }}</span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    @endforeach
                </tbody>
            </table>
            </div>
        </x-site.pano>
    </div>
</section>
