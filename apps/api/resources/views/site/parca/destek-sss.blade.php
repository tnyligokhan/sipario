{{--
    Destek · aranabilir, gruplu SSS (15-sw-destek.jsx · DestekSayfa orta bloğu).

    NEDEN x-site.sss BİLEŞENİ KULLANILMADI: kit bileşeni sabit bir listeyi açıp kapatır; buradaki
    widget arama + grup süzgeci + "sonuç yok" durumu istiyor, yani her SORUNUN ayrı ayrı gizlenmesi
    gerekiyor. Bileşenin içine bu davranışı sokmak onu değiştirmek olurdu (kit benim değil), o yüzden
    akordiyon işaretlemesi burada birebir aynı sınıflarla tekrarlandı.

    ARAMA BÜYÜK/KÜÇÜK HARF: eşleşme dizeleri sunucuda TÜRKÇE kurala göre küçültülür (İ→i, I→ı);
    istemcide de `toLocaleLowerCase('tr-TR')` kullanılıyor. İkisi aynı kuralı uygulamazsa "İptal"
    yazan kullanıcı "iptal" sorusunu bulamaz.
--}}
@php
    $kucult = fn (string $s): string => mb_strtolower(str_replace(['İ', 'I'], ['i', 'ı'], $s), 'UTF-8');
    // Grup adı → o gruptaki her sorunun aranabilir metni (soru + cevap), sıra korunur.
    $aranabilir = [];
    foreach ($sw['sss'] as $g) {
        $aranabilir[$g['g']] = array_map(fn ($x) => $kucult($x['s'].' '.$x['c']), $g['l']);
    }
@endphp
<section class="blm kagit2" x-data="{
    q: '',
    g: 'hepsi',
    acik: null,
    gruplar: @js($aranabilir),
    ara() { return this.q.trim().toLocaleLowerCase('tr-TR'); },
    esles(m) { const a = this.ara(); return a === '' || m.includes(a); },
    grupta(g) { return this.g === 'hepsi' || this.g === g; },
    grupVar(g) { return this.grupta(g) && this.gruplar[g].some(m => this.esles(m)); },
    bulunan() {
        let n = 0;
        for (const g in this.gruplar) { if (this.grupta(g)) n += this.gruplar[g].filter(m => this.esles(m)).length; }
        return n;
    },
}">
    <div class="kap">
        <x-site.blm-bas kulak="Sık sorulanlar" baslik="Aradığınızı yazın." />

        <div class="sss-arac">
            <div class="gir-sarma sss-ara">
                <span class="sss-ara-ik"><x-site.ikon ad="ara" boy="19" kalin="2" renk="var(--sonuk)" /></span>
                <input class="gir" type="search" x-model="q" aria-label="Sık sorulan sorularda ara"
                    placeholder="Örn. iptal, fatura, çevrimdışı…">
                <button type="button" class="gir-goz" x-show="q !== ''" x-cloak @click="q = ''" aria-label="Temizle">
                    <x-site.ikon ad="kapat" boy="17" kalin="2.2" />
                </button>
            </div>
            <div class="sss-filtre" role="group" aria-label="Soru grubu">
                @foreach (array_merge(['hepsi'], array_column($sw['sss'], 'g')) as $x)
                    <button type="button" @class(['sss-f', 'on' => $x === 'hepsi']) :class="{ on: g === '{{ $x }}' }"
                        @click="g = '{{ $x }}'" :aria-pressed="g === '{{ $x }}'">{{ $x === 'hepsi' ? 'Hepsi' : $x }}</button>
                @endforeach
            </div>
        </div>

        <x-site.pano ince class="sss-bos" x-show="bulunan() === 0" x-cloak>
            <span class="h3">“<span x-text="q"></span>” için sonuç yok.</span>
            <p class="gvd">Aradığınızı bulamadıysanız yazmayın, arayın — {{ $sw['kanal'][0]['deger'] }}.</p>
            <a class="dg dg-a" href="{{ route('site.iletisim') }}">Bize ulaşın</a>
        </x-site.pano>

        @foreach ($sw['sss'] as $gi => $g)
            <div class="sss-grup" x-show="grupVar('{{ $g['g'] }}')">
                <span class="mn sss-g">{{ $g['g'] }}</span>
                <div class="sss">
                    @foreach ($g['l'] as $si => $x)
                        @php($anahtar = $gi.'-'.$si)
                        <div class="sss-satir" :class="{ on: acik === '{{ $anahtar }}' }"
                            x-show="grupta('{{ $g['g'] }}') && esles(gruplar['{{ $g['g'] }}'][{{ $si }}])">
                            <button type="button" class="sss-bas"
                                @click="acik = acik === '{{ $anahtar }}' ? null : '{{ $anahtar }}'"
                                :aria-expanded="acik === '{{ $anahtar }}'" aria-expanded="false">
                                <span class="h4">{{ $x['s'] }}</span>
                                <span class="sss-isaret">
                                    <x-site.ikon ad="arti" boy="17" kalin="2.4" x-show="acik !== '{{ $anahtar }}'" />
                                    <x-site.ikon ad="eksi" boy="17" kalin="2.4" x-show="acik === '{{ $anahtar }}'" x-cloak />
                                </span>
                            </button>
                            <div class="sss-govde gvd" x-show="acik === '{{ $anahtar }}'" x-cloak>{{ $x['c'] }}</div>
                        </div>
                    @endforeach
                </div>
            </div>
        @endforeach
    </div>
</section>
