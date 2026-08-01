<div>
    <p><a href="{{ route('panel.tenant', $tenantId) }}">&larr; Bayi detayı</a></p>
    <h1>Müşteri Toplu Aktarım</h1>
    <p class="hint">Bayide şu an {{ $sayilar['musteri'] }} müşteri kayıtlı.
        Aktarılan müşteriler bayinin cihazlarına senkronla düşer.</p>

    <div class="card">
        <h2>1 · Şablonu indir</h2>
        <p class="hint">Sütunlar: <code>ad · telefon · adres · bolge · not</code>.
            Yalnız <strong>ad</strong> zorunludur. Dosya Excel'de düzenlenebilir; ayırıcı
            <code>;</code> ya da <code>,</code> olabilir, Türkçe karakterler desteklenir.</p>
        <p><a href="{{ route('panel.csv.sablon') }}">musteri-sablonu.csv indir</a></p>
    </div>

    <div class="card" style="margin-top:1rem;">
        <h2>2 · Dosyayı yükle</h2>
        <form wire:submit="onizle">
            <p>
                <input type="file" wire:model="dosya" accept=".csv,text/csv">
                @error('dosya')<span class="err">{{ $message }}</span>@enderror
            </p>
            <p>
                <button type="submit">Önizle</button>
                <button type="button" wire:click="sifirla">Temizle</button>
                <span class="hint" wire:loading wire:target="dosya,onizle">okunuyor…</span>
            </p>
        </form>
        @if ($hata)<p class="bildirim bildirim-hata">{{ $hata }}</p>@endif
    </div>

    @if ($onizleme)
        <div class="card" style="margin-top:1rem;">
            <h2>3 · Önizleme</h2>
            <p>
                <span class="status">Eklenecek: {{ $onizleme['ozet']['eklenecek'] }}</span>
                <span class="status">Atlanacak: {{ $onizleme['ozet']['atlanacak'] }}</span>
                <span class="status">Hatalı: {{ $onizleme['ozet']['hatali'] }}</span>
            </p>
            <p class="hint">Hiçbir şey yazılmadı. Onaylayana kadar bayinin verisi değişmez.
                Atlanan satırlar telefon numarası tekrarıdır — çift müşteri kaydı oluşmaz.</p>

            <table>
                <thead>
                    <tr><th>Satır</th><th>Durum</th><th>Ad</th><th>Telefon</th><th>Adres</th><th>Açıklama</th></tr>
                </thead>
                <tbody>
                    @foreach ($gosterilecek as $satir)
                        <tr>
                            <td>{{ $satir['satir'] }}</td>
                            <td>
                                @if ($satir['durum'] === 'eklenecek')
                                    <span class="status">eklenecek</span>
                                @elseif ($satir['durum'] === 'atlanacak')
                                    <span class="status">atlanacak</span>
                                @else
                                    <span class="err">hatalı</span>
                                @endif
                            </td>
                            <td>{{ $satir['ad'] }}</td>
                            <td>{{ $satir['telefon'] }}</td>
                            <td>{{ $satir['adres'] }}</td>
                            <td class="hint">{{ $satir['aciklama'] }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
            @if ($gizlenen > 0)
                <p class="hint">… ve {{ $gizlenen }} satır daha (ekranda ilk 200 satır gösterilir;
                    yukarıdaki sayılar dosyanın tamamını kapsar).</p>
            @endif

            <p>
                <button type="button" wire:click="uygula" @disabled($onizleme['ozet']['eklenecek'] === 0)>
                    {{ $onizleme['ozet']['eklenecek'] }} müşteriyi aktar
                </button>
                <button type="button" wire:click="sifirla">Vazgeç</button>
            </p>
            @if ($onizleme['ozet']['eklenecek'] === 0)
                <p class="hint">Eklenecek satır yok — dosyadaki her kayıt ya zaten var ya da hatalı.</p>
            @endif
        </div>
    @endif

    @if ($sonuc)
        <div class="card" style="margin-top:1rem;">
            <h2>Sonuç</h2>
            @if ($sonuc['durum'] === 'applied')
                <p class="bildirim bildirim-ok">
                    {{ $sonuc['eklenen'] }} müşteri eklendi ·
                    {{ $sonuc['atlanan'] }} satır atlandı ·
                    {{ $sonuc['hatali'] }} satır hatalı.
                </p>
            @else
                <p class="bildirim bildirim-hata">
                    Aktarım uygulanamadı: {{ $sonuc['mesaj'] }}
                    <br>Hiçbir satır yazılmadı.
                </p>
            @endif

            @if ($sonuc['hatalar'])
                <h3>Hatalı satırlar</h3>
                <table>
                    <thead><tr><th>Satır</th><th>Sebep</th></tr></thead>
                    <tbody>
                        @foreach ($sonuc['hatalar'] as $hataSatiri)
                            <tr><td>{{ $hataSatiri['satir'] }}</td><td>{{ $hataSatiri['aciklama'] }}</td></tr>
                        @endforeach
                    </tbody>
                </table>
                <p class="hint">Bu satırları dosyada düzeltip yeniden yükleyebilirsiniz;
                    aktarılmış müşteriler telefon tekrarından atlanır.</p>
            @endif

            <p><button type="button" wire:click="sifirla">Yeni dosya yükle</button></p>
        </div>
    @endif
</div>
