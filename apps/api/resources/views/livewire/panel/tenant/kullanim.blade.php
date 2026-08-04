{{--
    TASARIMDA YOK — BRIEF md. 3: "bayi başına günlük sipariş sayısı, sipariş girme saatleri,
    kurulumdan ilk siparişe geçen süre, aktif cihazlar. Bunlar erken terk (churn) sinyalleridir."
    Saat şeridi BRIEF'in cümlesinin birebir karşılığıdır: akşama yığılan giriş, bayinin gün içinde
    uygulamayı kullanmadığını gösterir.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

@php
    // `dailyOrders()` anahtarları ZATEN TR gününe (sabit +03:00) göre gruplanmış 'YYYY-MM-DD'
    // metinleridir; gün kararı sunucuda verilmiştir. Gece yarısı UTC + 3 saat aynı günde kalır,
    // yani `Bicim` dönüşümü bu anahtarları kaydırmaz. Yıl eksenden düşürülür: yedi çubuğun
    // altında "4 Ağu 2026" yazmak dar ekseni taşırır, yıl zaten kart başlığında ("son 7 gün").
    $gunEtiketi = fn (string $gun) => (string) \Illuminate\Support\Str::of(Bicim::tarihKisa($gun))->beforeLast(' ');

    $gunlukVeri = collect($gunlukSiparis)
        ->map(fn ($adet, $gun) => [
            'etiket' => $gunEtiketi($gun),
            'deger' => (int) $adet,
        ])
        ->values()
        ->all();

    $enYogunSaat = array_search(max($saatDagilimi), $saatDagilimi, true);
@endphp

<div class="iki-kolon">
    <x-panel.kart baslik="Günlük sipariş" ikon="grafik" adet="son 7 gün">
        <div style="padding:16px 18px">
            <x-panel.grafik-cubuk
                :veri="$gunlukVeri"
                birim="sipariş"
                :ozet="'Toplam '.array_sum($gunlukSiparis).' sipariş.'"
            />
        </div>
        <div class="bilgi-satirlar">
            <x-panel.bilgi-satir k="Aktif cihaz (7 gün)">
                <span class="tab">{{ $aktifCihaz }}</span>
            </x-panel.bilgi-satir>
            {{-- "Kurulumdan sonra ~10 dakika içinde 'telefon çaldı, ekranda müşteri çıktı' anını
                 yaşamazsa uygulamayı bırakır" (BRIEF, sahadan gerçekler). Bu satır o anın ölçüsü. --}}
            <x-panel.bilgi-satir k="Kurulumdan ilk siparişe">
                <span class="tab">
                    {{ $ilkSiparisDakika !== null ? $ilkSiparisDakika.' dk' : 'henüz sipariş yok' }}
                </span>
            </x-panel.bilgi-satir>
        </div>
    </x-panel.kart>

    <x-panel.kart baslik="Sipariş girme saatleri" ikon="saat" adet="son 30 gün">
        <div style="padding:16px 18px">
            <x-panel.grafik-isi
                :veri="$saatDagilimi"
                :ozet="max($saatDagilimi) > 0
                    ? 'En yoğun saat: '.$enYogunSaat.':00 ('.max($saatDagilimi).' sipariş)'
                    : 'Son 30 günde sipariş girilmemiş.'"
            />
        </div>
    </x-panel.kart>
</div>

<x-panel.kart baslik="Cihazlar" ikon="cihaz" :adet="$cihazlar->count().' cihaz'">
    @if ($cihazlar->isEmpty())
        <x-panel.bos ikon="cihaz" metin="Bu bayide kayıtlı cihaz yok." />
    @else
        <x-panel.tablo>
            <thead>
                <tr><th>Model</th><th>Platform</th><th>Son görülme</th></tr>
            </thead>
            <tbody>
                @foreach ($cihazlar as $cihaz)
                    <tr>
                        <td class="kalin">{{ $cihaz->model ?? '—' }}</td>
                        <td class="soluk">{{ $cihaz->platform ?? '—' }}</td>
                        <td class="tab">{{ Bicim::tarihSaat($cihaz->last_seen_at) }}</td>
                    </tr>
                @endforeach
            </tbody>
        </x-panel.tablo>
    @endif
</x-panel.kart>
