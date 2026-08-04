{{--
    Üyeler (tasarım `07-Uyeler.jsx` · Uyeler). Arama + durum çipleri + tablo, birebir.
    Tasarımdan farklar bileşenin belge başlığında; ekranda görünen tek fark 6. çip
    ("Süresi doldu" = sunucudaki `locked`) ve tablonun altındaki sayfalayıcıdır.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

<div>
    <x-panel.layout>
        <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
        <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>

        <x-panel.ust baslik="Üyeler" :alt="$toplam.' kayıtlı firma'">
            <x-slot:sag>
                <x-panel.ara-kutusu
                    wire:model.live.debounce.400ms="arama"
                    yertut="Firma, yetkili veya il ara…"
                />
            </x-slot:sag>
        </x-panel.ust>

        <x-panel.cipler
            :secenekler="$durumlar"
            :secili="$durum"
            wire:model="durum"
            style="margin-bottom:14px"
        />

        <x-panel.kart>
            @if ($uyeler->isEmpty())
                <x-panel.bos
                    ikon="ara"
                    :metin="trim($arama) !== '' ? 'Aramanla eşleşen üye yok.' : 'Bu durumda üye yok.'"
                />
            @else
                <x-panel.tablo>
                    <thead>
                        <tr>
                            <th>Firma</th>
                            <th>Telefon</th>
                            <th>Durum</th>
                            <th>Bitiş</th>
                            <th>Son Ödeme</th>
                            <th class="sag">İşlem</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($uyeler as $uye)
                            {{-- Satırın tamamı tıklanabilir (tasarım kararı). Klavye ve ekran
                                 okuyucu için gerçek bağlantı sağdaki "Detay"dır — satır tıklaması
                                 yalnız fare kolaylığıdır, tek erişim yolu değil. --}}
                            <tr
                                class="satir-tik"
                                x-on:click="window.location = @js(route('panel.tenant', $uye->id))"
                            >
                                <td>
                                    <div class="kalin">{{ $uye->name }}</div>
                                    <div class="soluk" style="font-size:12.5px">
                                        @if ($uye->city)
                                            {{ $uye->city }}@if ($uye->district) / {{ $uye->district }}@endif
                                        @else
                                            {{ $uye->slug }}
                                        @endif
                                    </div>
                                </td>
                                <td class="tab">{{ $uye->phone ?: '—' }}</td>
                                <td><x-panel.rozet :durum="$uye->status" /></td>
                                {{-- Deneme bitişi ile abonelik bitişi aynı sütunda yaşar: bayinin
                                     "ne zaman kapanır" tarihi tektir, hangi çıpadan geldiği
                                     durumun rozetinde zaten yazılı. --}}
                                <td class="tab">{{ Bicim::tarihKisa($uye->valid_until ?? $uye->trial_ends_at) }}</td>
                                <td class="tab">
                                    @if ($uye->son_odeme)
                                        {{ Bicim::tarihKisa($uye->son_odeme) }}
                                    @else
                                        <span class="soluk">—</span>
                                    @endif
                                </td>
                                <td class="sag">
                                    <a
                                        class="link-btn"
                                        href="{{ route('panel.tenant', $uye->id) }}"
                                        x-on:click.stop
                                    >Detay</a>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </x-panel.tablo>
            @endif
        </x-panel.kart>

        {{ $uyeler->links('vendor.pagination.panel-basit') }}
    </x-panel.layout>
</div>
