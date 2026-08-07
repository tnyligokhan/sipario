{{--
    Dashboard (tasarım `06-Dashboard.jsx`). Üstteki 4 istatistik kartı ve altındaki iki liste
    tasarımın birebir karşılığıdır; sonrasındaki bölümler BRIEF md. 3'ün panelde bulunması zorunlu
    yetenekleridir (bileşenin belge başlığında gerekçeleriyle sayılı).

    Para her yerde int KURUŞ tutulur; ₺'ye çevrim BURADA, sunum katmanında yapılır.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

@php
    // Para ve tarih biçimi TEK yerden (`Bicim`) gelir: para ekranlarıyla aynı yazım.
    $tl = Bicim::tl(...);
    $tlNet = Bicim::tlNet(...);
    $tarih = Bicim::tarihKisa(...);
    $kalanGun = fn ($d) => (int) ceil(now()->diffInDays(\Illuminate\Support\Carbon::parse($d), false));
@endphp

<div>
    <x-panel.layout>
        <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
        <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

        {{-- Tarih `now()` ile DEĞİL `Bicim::bugun()` ile: `config('app.timezone')` UTC ve panonun
             başlığı TR saatiyle 00:00–03:00 arasında BİR ÖNCEKİ GÜNÜ yazıyordu. "Bugün kime
             bakmalıyım" panosunun yanlış günü yazması küçük ama tam bu sınıftan bir arıza. --}}
        <x-panel.ust baslik="Dashboard" :alt="Bicim::tarihUzun(Bicim::bugun())" />

        <div class="skartlar">
            <x-panel.skart
                etiket="Aktif Abone"
                :deger="$ozet['dagilim']['active'] ?? 0"
                :alt="$tl($aylikKurus).'/ay plan'"
            />
            <x-panel.skart
                etiket="Deneme Sürümünde"
                :deger="$ozet['dagilim']['trial'] ?? 0"
                :alt="$bitenDenemeler->count().' tanesi bu hafta bitiyor'"
            />
            <x-panel.skart
                etiket="Bu Ay Tahsilat"
                :deger="$tl($ayOzet['gelir_kurus'])"
                :alt="$ayOdemeAdedi.' ödeme'"
            />
            <x-panel.skart
                etiket="Bu Ay Net"
                :deger="$tlNet($ayOzet['net_kurus'])"
                :kip="$ayOzet['net_kurus'] < 0 ? 'eksi' : 'arti'"
                :alt="'Gelir '.$tl($ayOzet['gelir_kurus']).' · Gider '.$tl($ayOzet['gider_kurus'])"
            />
        </div>

        <div class="dikey">
            <div class="iki-kolon">
                <x-panel.kart baslik="Denemesi bitmek üzere" ikon="saat" adet="7 gün içinde">
                    @if ($bitenDenemeler->isEmpty())
                        <x-panel.bos ikon="saat" metin="Bu hafta denemesi biten firma yok." />
                    @else
                        <x-panel.tablo>
                            <tbody>
                                @foreach ($bitenDenemeler as $bayi)
                                    @php($kalan = $kalanGun($bayi->trial_ends_at))
                                    <tr>
                                        <td>
                                            <div class="kalin">{{ $bayi->name }}</div>
                                            <div class="soluk" style="font-size:12.5px">{{ $bayi->slug }}</div>
                                        </td>
                                        <td class="sag">
                                            <span class="rozet deneme">
                                                {{ $kalan <= 0 ? 'Bugün bitiyor' : $kalan.' gün kaldı' }}
                                            </span>
                                        </td>
                                        <td class="sag" style="width:60px">
                                            <a class="link-btn" href="{{ route('panel.tenant', $bayi->id) }}">Detay</a>
                                        </td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </x-panel.tablo>
                    @endif
                </x-panel.kart>

                <x-panel.kart baslik="Ödemesi geciken" ikon="uyari" :adet="$gecikenler->count().' firma'">
                    @if ($gecikenler->isEmpty())
                        <x-panel.bos ikon="kutu" metin="Geciken ödeme yok. Her şey yolunda." />
                    @else
                        <x-panel.tablo>
                            <tbody>
                                @foreach ($gecikenler as $bayi)
                                    @php($gun = -$kalanGun($bayi->valid_until))
                                    <tr>
                                        <td>
                                            <div class="kalin">{{ $bayi->name }}</div>
                                            <div class="soluk" style="font-size:12.5px">{{ max($gun, 0) }} gün gecikti</div>
                                        </td>
                                        <td class="sag kalin tab">
                                            {{ $tl($bayi->billing_period === 'yearly' ? $yillikKurus : $aylikKurus) }}
                                        </td>
                                        <td class="sag" style="width:60px">
                                            <a class="link-btn" href="{{ route('panel.tenant', $bayi->id) }}">Detay</a>
                                        </td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </x-panel.tablo>
                    @endif
                </x-panel.kart>
            </div>

            {{-- TASARIMDA YOK — BRIEF md. 3. Bekleyen beyan bir KUYRUKtur: panoda görünmezse
                 bayi "havale gönderdim" der ve kimse bakmaz. Sayı sıfırken de kart durur ki
                 kuyruğun var olduğu unutulmasın. --}}
            <div class="iki-kolon">
                <x-panel.kart baslik="Bekleyen havale bildirimi" ikon="uyari">
                    <div class="bilgi-satirlar">
                        <x-panel.bilgi-satir k="Beklemede">
                            <span class="tab">{{ $bekleyenBildirim }}</span>
                        </x-panel.bilgi-satir>
                    </div>
                    @if ($bekleyenBildirim === 0)
                        <x-panel.bos ikon="kutu" metin="Beklemede bildirim yok." />
                    @endif
                    <x-slot:aksiyonlar>
                        <a class="btn @if ($bekleyenBildirim > 0) birincil @endif" href="{{ route('panel.notifications') }}">
                            Bildirimleri aç
                        </a>
                    </x-slot:aksiyonlar>
                </x-panel.kart>

                <x-panel.kart
                    baslik="{{ $churnGun }} gündür sipariş girmeyen bayiler"
                    ikon="uyari"
                    :adet="$churnRiski->count().' firma'"
                >
                    @if ($churnRiski->isEmpty())
                        <x-panel.bos metin="Risk listesi boş — yazma hakkı açık bayilerin hepsi sipariş giriyor." />
                    @else
                        <x-panel.tablo>
                            <thead>
                                <tr><th>Bayi</th><th>Son sipariş</th><th class="sag">İşlem</th></tr>
                            </thead>
                            <tbody>
                                @foreach ($churnRiski as $bayi)
                                    <tr>
                                        <td>
                                            <div class="kalin">{{ $bayi->name }}</div>
                                            <div class="soluk" style="font-size:12.5px">{{ $bayi->slug }}</div>
                                        </td>
                                        {{-- "hiç" ile eski bir tarih AYRI hikâyelerdir: ilki kurulumu
                                             yapıp ürüne hiç başlamamış bayidir. --}}
                                        <td class="tab">
                                            @if ($bayi->son_siparis)
                                                {{ $tarih($bayi->son_siparis) }}
                                            @else
                                                <span class="rozet kilitli">hiç</span>
                                            @endif
                                        </td>
                                        <td class="sag" style="width:60px">
                                            <a class="link-btn" href="{{ route('panel.tenant', $bayi->id) }}">Detay</a>
                                        </td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </x-panel.tablo>
                    @endif
                </x-panel.kart>
            </div>

            {{-- TASARIMDA YOK — BRIEF md. 3 (yenileme takvimi). Grafik haftalık kovaları,
                 tablo hangi bayinin ne zaman yenileneceğini gösterir. --}}
            <x-panel.kart baslik="Yenileme takvimi" ikon="takvim" :adet="$takvimGun.' gün'">
                <div style="padding:16px 18px">
                    <x-panel.grafik-cubuk
                        :veri="collect($kovalar)->map(fn ($k) => ['etiket' => $k['etiket'], 'deger' => $k['adet']])->all()"
                        birim="bayi"
                        :ozet="$takvim->count().' bayinin aboneliği önümüzdeki '.$takvimGun.' günde yenilenecek.'"
                    />
                </div>

                @if ($takvim->isEmpty())
                    <x-panel.bos ikon="takvim" metin="Önümüzdeki {{ $takvimGun }} günde yenilenecek abonelik yok." />
                @else
                    <x-panel.tablo>
                        <thead>
                            <tr><th>Bayi</th><th>Firma kodu</th><th>Durum</th><th>Bitiş</th><th class="sag">İşlem</th></tr>
                        </thead>
                        <tbody>
                            @foreach ($takvim as $bayi)
                                <tr>
                                    <td class="kalin">{{ $bayi->name }}</td>
                                    <td class="soluk">{{ $bayi->slug }}</td>
                                    <td><x-panel.rozet :durum="$bayi->status" /></td>
                                    <td class="tab">{{ $tarih($bayi->valid_until) }}</td>
                                    <td class="sag" style="width:60px">
                                        <a class="link-btn" href="{{ route('panel.tenant', $bayi->id) }}">Detay</a>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </x-panel.tablo>
                @endif
            </x-panel.kart>

            {{-- TASARIMDA YOK — BRIEF md. 3 (kullanım istatistikleri / churn sinyalleri). --}}
            <div class="iki-kolon">
                <x-panel.kart baslik="Aylık net" ikon="gelirgider" :adet="'son '.$trendAy.' ay'">
                    <div style="padding:16px 18px">
                        <x-panel.grafik-cizgi
                            :veri="$gelirTrendi"
                            birim="₺"
                            ozet="Gelir eksi gider. Sıfırın altı kırmızıdır."
                        />
                    </div>
                </x-panel.kart>

                <x-panel.kart baslik="Sipariş girme saatleri" ikon="saat" :adet="'son '.$saatGun.' gün'">
                    <div style="padding:16px 18px">
                        <x-panel.grafik-isi
                            :veri="$saatDagilimi"
                            ozet="Akşama yığılan giriş, bayinin gün içinde uygulamayı kullanmadığını gösterir."
                        />
                    </div>
                </x-panel.kart>
            </div>
        </div>
    </x-panel.layout>
</div>
