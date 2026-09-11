{{--
    Müşteri toplu aktarım — TASARIMDA YOK (BRIEF: "veri rehin alınmaz" kapısının içeri yönü).
    Üç adım: şablon indir → dosya yükle (ÖNİZLEME) → onayla. İşlev AYNEN korundu; dosya seçici
    tasarımın `x-panel.dosya-sec` bileşenine geçti.
--}}
<div>
    <x-panel.layout>
        <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
        <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

        <a href="{{ route('panel.tenant', $tenantId) }}" class="geri">
            <x-panel.ikon ad="geri" boy="15" /> Bayi detayı
        </a>

        <x-panel.ust
            baslik="Müşteri Toplu Aktarım"
            :alt="'Bayide şu an '.$sayilar['musteri'].' müşteri kayıtlı.'"
        />

        <div class="dikey">
            <x-panel.kart baslik="1 · Şablonu indir" ikon="indir">
                <div class="modal-bilgi" style="margin:14px 18px">
                    <x-panel.ikon ad="bilgi" boy="15" />
                    <span>Sütunlar: <b class="tab">ad · telefon · adres · bolge · not · kod · favoriler</b>.
                        Yalnız <b>ad</b> zorunludur. <b>kod</b> bayinin eski müşteri numarasıdır
                        (boş bırakılırsa sıradaki numara atanır). <b>telefon</b>, <b>adres</b> ve
                        <b>favoriler</b> hücrelerinde birden çok değer <b class="tab">:::</b> ile ayrılır.
                        Dosya Excel'de düzenlenebilir; ayırıcı <b class="tab">;</b> ya da
                        <b class="tab">,</b> olabilir, Türkçe karakterler desteklenir.
                        Aktarılan müşteriler bayinin cihazlarına senkronla düşer.</span>
                </div>
                <x-slot:aksiyonlar>
                    <a class="btn" href="{{ route('panel.csv.sablon') }}">
                        <x-panel.ikon ad="indir" boy="15" /> musteri-sablonu.csv indir
                    </a>
                </x-slot:aksiyonlar>
            </x-panel.kart>

            <x-panel.kart baslik="2 · Dosyayı yükle" ikon="yukle">
                <div style="padding:16px 18px">
                    <x-panel.dosya-sec ad="dosya" kabul=".csv,text/csv" yertut="CSV dosyası seçilmedi" />
                    <span class="soluk" wire:loading wire:target="dosya,onizle" style="font-size:12px">okunuyor…</span>
                </div>

                @if ($hata)
                    <div
                        class="modal-bilgi"
                        style="margin:0 18px 14px;background:var(--danger-soft);color:var(--danger)"
                        role="status"
                    >
                        <x-panel.ikon ad="uyari" boy="15" />
                        <span>{{ $hata }}</span>
                    </div>
                @endif

                <x-slot:aksiyonlar>
                    <button type="button" class="btn birincil" wire:click="onizle">Önizle</button>
                    <button type="button" class="btn" wire:click="sifirla">Temizle</button>
                </x-slot:aksiyonlar>
            </x-panel.kart>

            @if ($onizleme)
                <x-panel.kart baslik="3 · Önizleme" ikon="goz">
                    <div class="aksiyonlar" style="border-top:none;border-bottom:1px solid var(--line)">
                        <span class="rozet aktif">Eklenecek: {{ $onizleme['ozet']['eklenecek'] }}</span>
                        <span class="rozet askida">Atlanacak: {{ $onizleme['ozet']['atlanacak'] }}</span>
                        <span class="rozet kilitli">Hatalı: {{ $onizleme['ozet']['hatali'] }}</span>
                    </div>

                    <div class="modal-bilgi" style="margin:14px 18px">
                        <x-panel.ikon ad="bilgi" boy="15" />
                        <span>Hiçbir şey yazılmadı. Onaylayana kadar bayinin verisi değişmez.
                            Atlanan satırlar tekrar eden kayıtlardır (müşteri kodu varsa koda, yoksa
                            telefona bakılır) — çift müşteri kaydı oluşmaz. Favori sütunundaki ürün
                            bayide yoksa aktarım sırasında açılır, fiyatı sıfır başlar.</span>
                    </div>

                    <x-panel.tablo>
                        <thead>
                            <tr>
                                <th>Satır</th><th>Durum</th><th>Kod</th><th>Ad</th>
                                <th>Telefon</th><th>Adres</th><th>Favoriler</th><th>Açıklama</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($gosterilecek as $satir)
                                <tr>
                                    <td class="tab">{{ $satir['satir'] }}</td>
                                    <td>
                                        @if ($satir['durum'] === 'eklenecek')
                                            <span class="rozet aktif">eklenecek</span>
                                        @elseif ($satir['durum'] === 'atlanacak')
                                            <span class="rozet askida">atlanacak</span>
                                        @else
                                            <span class="rozet kilitli">hatalı</span>
                                        @endif
                                    </td>
                                    <td class="tab">{{ $satir['kod'] ?? '—' }}</td>
                                    <td class="kalin">{{ $satir['ad'] }}</td>
                                    <td class="tab">{{ $satir['telefon'] }}</td>
                                    <td>{{ $satir['adres'] }}</td>
                                    <td class="soluk">{{ $satir['favoriler'] }}</td>
                                    <td class="soluk">{{ $satir['aciklama'] }}</td>
                                </tr>
                            @endforeach
                        </tbody>
                    </x-panel.tablo>

                    @if ($gizlenen > 0)
                        <div class="modal-bilgi" style="margin:14px 18px">
                            <x-panel.ikon ad="bilgi" boy="15" />
                            <span>… ve {{ $gizlenen }} satır daha (ekranda ilk 200 satır gösterilir;
                                yukarıdaki sayılar dosyanın tamamını kapsar).</span>
                        </div>
                    @endif

                    @if ($onizleme['ozet']['eklenecek'] === 0)
                        <x-panel.bos metin="Eklenecek satır yok — dosyadaki her kayıt ya zaten var ya da hatalı." />
                    @endif

                    <x-slot:aksiyonlar>
                        <button
                            type="button"
                            class="btn birincil"
                            wire:click="uygula"
                            @disabled($onizleme['ozet']['eklenecek'] === 0)
                        >{{ number_format($onizleme['ozet']['eklenecek'], 0, ',', '.') }} müşteriyi aktar</button>
                        <button type="button" class="btn" wire:click="sifirla">Vazgeç</button>
                        @if ($onizleme['ozet']['eklenecek'] > 1000)
                            {{-- Ölçüldü: ~9.000 müşteri ≈ 7,5 dakika. Kullanıcı ne kadar
                                 bekleyeceğini ÖNCEDEN bilmeli; sürprizi sonra yaşamamalı. --}}
                            <span class="soluk" style="font-size:12px">
                                Bu boyuttaki bir dosya birkaç dakika sürer; sayfayı açık bırakın.
                            </span>
                        @endif
                    </x-slot:aksiyonlar>
                </x-panel.kart>
            @endif

            {{--
                İLERLEME KARTI — aktarım adım adım koşarken görünür.
                `wire:poll` her turda `adim()`ı çağırır; `devam` false olunca poll susar ve
                sonuç kartı belirir.

                `.keep-alive` ZORUNLU: Livewire, sekme arka plana geçtiğinde poll'ü DURDURUR
                (`theDirectiveIsMissingKeepAlive`). 7 dakikalık bir aktarımda kullanıcı mutlaka
                başka sekmeye geçer ve aktarım sessizce donardı.

                Üst üste binme sunucuda KİLİTLE engellenir (bkz. CustomerImport::adim) — tarayıcı
                tarafındaki istek sıralamasına güvenmek yetmez, kullanıcı sayfayı ikinci bir
                sekmede de açabilir.
            --}}
            @if ($devam)
                <x-panel.kart baslik="Aktarılıyor…" ikon="yukle" wire:poll.2s.keep-alive="adim">
                    @php
                        $toplam = max(1, (int) ($ilerleme['toplam'] ?? 1));
                        $yuzde = min(100, (int) round(($ilerleme['yazilan'] ?? 0) * 100 / $toplam));
                    @endphp

                    <div style="padding:18px">
                        <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:8px">
                            <span class="kalin">{{ number_format($ilerleme['yazilan'], 0, ',', '.') }}
                                / {{ number_format($ilerleme['toplam'], 0, ',', '.') }} müşteri</span>
                            <span class="tab soluk">%{{ $yuzde }}</span>
                        </div>

                        <div
                            role="progressbar"
                            aria-valuenow="{{ $yuzde }}" aria-valuemin="0" aria-valuemax="100"
                            style="height:8px;border-radius:999px;background:var(--line);overflow:hidden"
                        >
                            <div style="height:100%;width:{{ $yuzde }}%;background:var(--accent);transition:width .4s ease"></div>
                        </div>
                    </div>

                    <div class="modal-bilgi" style="margin:0 18px 14px">
                        <x-panel.ikon ad="bilgi" boy="15" />
                        <span>Bu sayfa açık kalsın — aktarım kendi kendine devam ediyor.
                            Sayfayı kapatırsanız o ana kadar yazılanlar KALIR; aynı dosyayı
                            yeniden yükleyip kaldığı yerden sürdürebilirsiniz.</span>
                    </div>
                </x-panel.kart>
            @endif

            @if ($sonuc)
                <x-panel.kart baslik="Sonuç" ikon="bilgi">
                    @if ($sonuc['durum'] === 'applied')
                        <div class="modal-bilgi" style="margin:14px 18px" role="status">
                            <x-panel.ikon ad="bilgi" boy="15" />
                            <span>{{ $sonuc['eklenen'] }} müşteri eklendi · {{ $sonuc['atlanan'] }} satır atlandı · {{ $sonuc['hatali'] }} satır hatalı.</span>
                        </div>

                        @if ($sonuc['acilan_urunler'] ?? [])
                            <div class="modal-bilgi" style="margin:14px 18px" role="status">
                                <x-panel.ikon ad="bilgi" boy="15" />
                                <span>Favori listelerinde geçtiği için {{ count($sonuc['acilan_urunler']) }} ürün
                                    kataloğa eklendi: {{ implode(', ', $sonuc['acilan_urunler']) }}.
                                    <strong>Fiyatları sıfır başlar</strong> — ürün ekranından güncelleyin.</span>
                            </div>
                        @endif
                    @else
                        <div
                            class="modal-bilgi"
                            style="margin:14px 18px;background:var(--danger-soft);color:var(--danger)"
                            role="status"
                        >
                            <x-panel.ikon ad="uyari" boy="15" />
                            {{--
                                KISMİ YAZMA GERÇEKTİR: aktarım parti parti yazılır, duran partiden
                                öncekiler diskte kalır. "Hiçbir satır yazılmadı" demek kullanıcıyı
                                dosyayı sıfırdan yüklemeye iter ve yazılanları görmediği için
                                paniğe düşürür. Ne yazıldığını SAYIYLA söyle, kurtarmayı da.
                            --}}
                            <span>
                                Aktarım yarıda durdu: {{ $sonuc['mesaj'] }}
                                @if ($sonuc['eklenen'] > 0)
                                    <strong>{{ $sonuc['eklenen'] }} müşteri yazıldı</strong>, kalanı yazılamadı.
                                    Aynı dosyayı yeniden yükleyin — yazılmış müşteriler atlanır,
                                    yalnız eksik kalanlar girer.
                                @else
                                    Hiçbir satır yazılmadı.
                                @endif
                            </span>
                        </div>
                    @endif

                    @if ($sonuc['hatalar'])
                        <div class="kart-baslik">Hatalı satırlar</div>
                        <x-panel.tablo>
                            <thead><tr><th>Satır</th><th>Sebep</th></tr></thead>
                            <tbody>
                                @foreach ($sonuc['hatalar'] as $hataSatiri)
                                    <tr>
                                        <td class="tab">{{ $hataSatiri['satir'] }}</td>
                                        <td class="soluk">{{ $hataSatiri['aciklama'] }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </x-panel.tablo>
                        <div class="modal-bilgi" style="margin:14px 18px">
                            <x-panel.ikon ad="bilgi" boy="15" />
                            <span>Bu satırları dosyada düzeltip yeniden yükleyebilirsiniz;
                                aktarılmış müşteriler kod (kodu yoksa telefon) tekrarından atlanır.</span>
                        </div>
                    @endif

                    <x-slot:aksiyonlar>
                        <button type="button" class="btn" wire:click="sifirla">Yeni dosya yükle</button>
                    </x-slot:aksiyonlar>
                </x-panel.kart>
            @endif
        </div>
    </x-panel.layout>
</div>
