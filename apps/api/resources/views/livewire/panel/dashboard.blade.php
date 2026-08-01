<div>
    <h1>Genel Bakış</h1>

    <div class="metrics">
        <div class="card metric">
            <span class="metric-label">Aktif bayi</span>
            <span class="metric-value">{{ $ozet['yazabilir'] }}</span>
            <span class="metric-note">yazma açık (toplam {{ $ozet['toplam'] }})</span>
        </div>
        <div class="card metric">
            <span class="metric-label">Deneme</span>
            <span class="metric-value">{{ $ozet['dagilim']['trial'] }}</span>
        </div>
        <div class="card metric">
            <span class="metric-label">Abone</span>
            <span class="metric-value">{{ $ozet['dagilim']['active'] }}</span>
        </div>
        <div class="card metric">
            <span class="metric-label">Kilitli</span>
            <span class="metric-value">{{ $ozet['dagilim']['locked'] }}</span>
        </div>
        <div class="card metric">
            <span class="metric-label">Askıda</span>
            <span class="metric-value">{{ $ozet['dagilim']['suspended'] }}</span>
        </div>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>Denemesi bitmek üzere (7 gün)</h2>
        <table>
            <thead><tr><th>Bayi</th><th>Firma kodu</th><th>Deneme bitişi</th><th>Kalan</th></tr></thead>
            <tbody>
                @forelse ($bitenDenemeler as $bayi)
                    @php($kalan = (int) ceil(now()->diffInDays(\Illuminate\Support\Carbon::parse($bayi->trial_ends_at), false)))
                    <tr>
                        <td><a href="{{ route('panel.tenant', $bayi->id) }}">{{ $bayi->name }}</a></td>
                        <td>{{ $bayi->slug }}</td>
                        <td>{{ \Illuminate\Support\Carbon::parse($bayi->trial_ends_at)->format('d.m.Y') }}</td>
                        <td><span class="status">{{ $kalan <= 0 ? 'bugün' : $kalan.' gün' }}</span></td>
                    </tr>
                @empty
                    <tr><td colspan="4">Önümüzdeki 7 günde biten deneme yok.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>Churn riski — son {{ $churnGun }} gündür sipariş yok</h2>
        <p class="hint">Yazma hakkı açık olduğu hâlde sipariş girmeyen bayiler. &ldquo;Son sipariş: hiç&rdquo;
            olanlar kurulumu yapmış ama ürünü hiç kullanmamış demektir.</p>
        <table>
            <thead><tr><th>Bayi</th><th>Firma kodu</th><th>Durum</th><th>Son sipariş</th><th>Kayıt</th></tr></thead>
            <tbody>
                @forelse ($churnRiski as $bayi)
                    <tr>
                        <td><a href="{{ route('panel.tenant', $bayi->id) }}">{{ $bayi->name }}</a></td>
                        <td>{{ $bayi->slug }}</td>
                        <td><span class="status">{{ $bayi->status }}</span></td>
                        <td>
                            @if ($bayi->son_siparis)
                                {{ \Illuminate\Support\Carbon::parse($bayi->son_siparis)->format('d.m.Y H:i') }}
                            @else
                                <span class="err">hiç</span>
                            @endif
                        </td>
                        <td>{{ \Illuminate\Support\Carbon::parse($bayi->created_at)->format('d.m.Y') }}</td>
                    </tr>
                @empty
                    <tr><td colspan="5">Risk listesi boş — aktif bayilerin hepsi sipariş giriyor.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>Yenileme takvimi ({{ $takvimGun }} gün)</h2>

        @php($enYuksek = max(1, max(array_column($kovalar, 'adet'))))
        @php($kovaGenislik = 100 / max(count($kovalar), 1))
        {{-- Saf SVG çubuk grafik: JS grafik kütüphanesi YOK (kullanıcı kuralı). viewBox ile ölçeklenir. --}}
        <svg viewBox="0 0 100 40" preserveAspectRatio="none" class="chart" role="img"
             aria-label="Haftalara göre yenilenecek abonelik sayısı">
            @foreach ($kovalar as $i => $kova)
                @php($yukseklik = $kova['adet'] / $enYuksek * 32)
                <rect x="{{ $i * $kovaGenislik + $kovaGenislik * 0.15 }}"
                      y="{{ 34 - $yukseklik }}"
                      width="{{ $kovaGenislik * 0.7 }}"
                      height="{{ max($yukseklik, 0.4) }}"
                      fill="{{ $kova['adet'] > 0 ? '#2563eb' : '#d1d5db' }}"></rect>
            @endforeach
        </svg>
        <div class="chart-axis">
            @foreach ($kovalar as $kova)
                <span style="width: {{ $kovaGenislik }}%">{{ $kova['etiket'] }}<br><strong>{{ $kova['adet'] }}</strong></span>
            @endforeach
        </div>

        <table style="margin-top:1rem;">
            <thead><tr><th>Bayi</th><th>Firma kodu</th><th>Durum</th><th>Bitiş</th></tr></thead>
            <tbody>
                @forelse ($takvim as $bayi)
                    <tr>
                        <td><a href="{{ route('panel.tenant', $bayi->id) }}">{{ $bayi->name }}</a></td>
                        <td>{{ $bayi->slug }}</td>
                        <td><span class="status">{{ $bayi->status }}</span></td>
                        <td>{{ \Illuminate\Support\Carbon::parse($bayi->valid_until)->format('d.m.Y') }}</td>
                    </tr>
                @empty
                    <tr><td colspan="4">Önümüzdeki {{ $takvimGun }} günde yenilenecek abonelik yok.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>
