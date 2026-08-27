{{--
    Üyeler (tasarım `07-Uyeler.jsx` · Uyeler). Arama + durum çipleri + tablo, birebir.
    Tasarımdan farklar bileşenin belge başlığında; ekranda görünen farklar 6. çip
    ("Süresi doldu" = sunucudaki `locked`), tablonun altındaki sayfalayıcı ve sağ üstteki
    "Yeni Üye" düğmesidir (elle bayi açma — BRIEF md. 3; tasarımda yoktu).
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
                {{-- Düğmenin gizlenmesi bir kolaylıktır, yetki denetimi DEĞİL: kapı
                     `TenantList::superadminZorunlu()` içinde, her eylemde. --}}
                @if ($superadmin)
                    <button type="button" class="btn birincil" wire:click="uyeAc">
                        <x-panel.ikon ad="arti" boy="15" /> Yeni Üye
                    </button>
                @endif
            </x-slot:sag>
        </x-panel.ust>

        {{-- KURULUM BİLGİSİ — modal kapandıktan sonra da durur; operatör bunları telefondaki
             bayiye okuyacak. Parola yalnız burada görünür, hiçbir yere kaydedilmez. --}}
        @if ($acilan)
            <div class="modal-bilgi" style="margin-bottom:14px" role="status">
                <x-panel.ikon ad="bilgi" boy="15" />
                <span>
                    <b>{{ $acilan['isletme'] }}</b> açıldı — deneme bitişi
                    <b class="tab">{{ $acilan['bitis'] }}</b>.
                    Firma kodu <b class="tab">{{ $acilan['kod'] }}</b> ·
                    kullanıcı adı <b class="tab">{{ $acilan['kullanici'] }}</b> ·
                    parola <b class="tab">{{ $acilan['parola'] }}</b>.
                    @if ($acilan['posta'])
                        Bilgiler <b>{{ $acilan['posta'] }}</b> adresine de gönderildi.
                    @else
                        <b>E-posta gönderilmedi</b>; bu bilgileri siz iletin.
                    @endif
                    <button type="button" class="link-btn" wire:click="acilanKapat">Kapat</button>
                </span>
            </div>
        @endif

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
                                x-data="satirLink(@js(route('panel.tenant', $uye->id)))"
                                x-on:click="git()"
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

        @if ($uyeAcik)
            @include('livewire.panel._uye-modal')
        @endif
    </x-panel.layout>
</div>
