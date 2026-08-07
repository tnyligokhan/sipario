{{--
    ÖZET sekmesi = tasarımın iki sütunlu `.detay-yerlesim` düzeni, birebir:
      SOL  → Firma Bilgileri · Abonelik · Ek Paketler
      SAĞ  → Ödeme Geçmişi · Notlar
    Altına BRIEF md. 3'ün zorunlu yetenekleri eklenir (yonetim + kullanim parçaları).

    "Ödeme Ekle" ve "Ek Paket Tanımla" burada MODAL AÇMAZ, ilgili ekrana götürür: o iki modal
    para ekranlarının (`panel.payments` / `panel.packages`) sahibidir; ikinci bir kopyasını burada
    tutmak aynı yazma yolunun iki ayrı doğrulamasını yaratırdı.
--}}
@use('App\Livewire\Panel\Concerns\Bicim')

@php
    $tenant = $detail['tenant'];
    // Para ve tarih biçimi TEK yerden (`Bicim`) gelir — para ekranlarıyla aynı yazım.
    $tl = Bicim::tl(...);
    $tarih = Bicim::tarihKisa(...);

    $deneme = $tenant->status === \App\Enums\TenantStatus::Trial;
    $bitis = $deneme ? $tenant->trial_ends_at : $tenant->valid_until;
    $bitisEtiket = $deneme ? 'Deneme bitişi' : 'Abonelik bitişi';
    $kalan = $bitis ? (int) ceil(now()->diffInDays($bitis, false)) : null;

    $yillik = $tenant->billing_period?->value === 'yearly';
    $planUcret = $yillik ? $tl($yillikKurus).'/yıl' : $tl($aylikKurus).'/ay';

    // Ek paket tanımlamalarının TÜR bazında toplamı (tasarımın "+ N ek" rozetleri).
    $ekHak = $tanimlamalar->where('type', 'credits')->sum('quantity');
    $ekKurye = $tanimlamalar->where('type', 'courier')->sum('quantity');
    $yontemAdi = ['iban' => 'IBAN', 'elden' => 'Elden', 'bedelsiz' => 'Bedelsiz'];
@endphp

<div class="detay-yerlesim">
    <div class="dikey">
        <x-panel.kart baslik="Firma Bilgileri">
            <div class="bilgi-satirlar">
                <x-panel.bilgi-satir k="Firma adı">{{ $tenant->name }}</x-panel.bilgi-satir>
                <x-panel.bilgi-satir k="Firma kodu"><span class="tab">{{ $tenant->slug }}</span></x-panel.bilgi-satir>
                <x-panel.bilgi-satir k="Yetkili">{{ $tenant->contact_name ?: '—' }}</x-panel.bilgi-satir>
                <x-panel.bilgi-satir k="Telefon"><span class="tab">{{ $tenant->phone ?: '—' }}</span></x-panel.bilgi-satir>
                <x-panel.bilgi-satir k="İl / İlçe">
                    {{ $tenant->city ? $tenant->city.($tenant->district ? ' / '.$tenant->district : '') : '—' }}
                </x-panel.bilgi-satir>
                <x-panel.bilgi-satir k="Kayıt tarihi">
                    <span class="tab">{{ $tarih($tenant->created_at) }}</span>
                </x-panel.bilgi-satir>
                <x-panel.bilgi-satir k="Kullanıcı / Cihaz">
                    <span class="tab">{{ $detail['user_count'] }} / {{ $detail['device_count'] }}</span>
                </x-panel.bilgi-satir>
            </div>
        </x-panel.kart>

        <x-panel.kart baslik="Abonelik">
            <div class="bilgi-satirlar">
                <x-panel.bilgi-satir k="Durum"><x-panel.rozet :durum="$tenant->status" /></x-panel.bilgi-satir>
                <x-panel.bilgi-satir k="Plan">{{ $plan?->name ?? 'Sipario' }} — {{ $planUcret }}</x-panel.bilgi-satir>
                <x-panel.bilgi-satir :k="$bitisEtiket">
                    <span class="tab">{{ $tarih($bitis) }}</span>
                    @if ($kalan !== null && $tenant->status !== \App\Enums\TenantStatus::Cancelled)
                        <span style="font-weight:500;margin-left:6px;color:{{ $kalan < 0 ? 'var(--danger)' : 'var(--muted)' }}">
                            ({{ $kalan < 0 ? -$kalan.' gün gecikti' : $kalan.' gün kaldı' }})
                        </span>
                    @endif
                </x-panel.bilgi-satir>
                <x-panel.bilgi-satir k="Kilit anı">
                    <span class="tab">{{ Bicim::tarihSaat($tenant->locked_at) }}</span>
                </x-panel.bilgi-satir>
            </div>

            {{-- Durum düğmeleri destek rolüne HİÇ gösterilmez (pasif de değil, yok). Kapı zaten
                 her eylemin içinde; bu yalnız destek ekibinin kullanamayacağı bir düğmeye
                 bakmamasıdır — mevcut panelin kararıydı, korunuyor. --}}
            <x-slot:aksiyonlar>
                @if ($superadmin && $deneme)
                    <button type="button" class="btn" wire:click="uzatAc">Denemeyi Uzat</button>
                @endif

                {{-- Ödeme kaydı para ekranının işidir; buradan oraya gidilir. --}}
                <a class="btn birincil" href="{{ route('panel.payments') }}">
                    <x-panel.ikon ad="arti" boy="15" /> Ödeme Ekle
                </a>

                @if ($superadmin && in_array($tenant->status->value, ['active', 'trial'], true))
                    <button type="button" class="btn tehlike" wire:click="suspend">Askıya Al</button>
                @endif

                {{-- Tasarımda yalnız "askıda" için vardı; `locked` (süresi doldu) de aynı düğmeyle
                     açılır — kilidi açmanın ayrı bir düğmesi olsaydı iki kavram öğrenmek gerekirdi. --}}
                @if ($superadmin && in_array($tenant->status->value, ['suspended', 'locked'], true))
                    <button type="button" class="btn" wire:click="unlock">Aktifleştir</button>
                @endif

                {{-- TASARIMDA YOK. `cancelled` bayinin BIRAKTIĞI durumdur ve churn sayacına girer;
                     askıya almakla aynı şey değildir (bkz. TenantStatus). --}}
                @if ($superadmin && $tenant->status->value !== 'cancelled')
                    <button
                        type="button"
                        class="btn tehlike"
                        wire:click="iptalEt"
                        wire:confirm="Bu bayi üyeliğini bıraktı olarak işaretlenecek. Verisi SİLİNMEZ. Onaylıyor musunuz?"
                    >İptal Et</button>
                @endif
            </x-slot:aksiyonlar>
        </x-panel.kart>

        <x-panel.kart baslik="Ek Paketler" :adet="$tanimlamalar->count().' tanımlama'">
            <div class="bilgi-satirlar">
                <x-panel.bilgi-satir k="Oto-sıralama hakkı">
                    <span class="tab">{{ $tenant->route_credits_monthly }}/ay</span>
                    @if ($ekHak > 0)
                        <span style="color:var(--accent)"> + {{ $ekHak }} ek</span>
                    @endif
                </x-panel.bilgi-satir>
                {{-- "2 / 3 kurye": kota SUNUCUDA gerçektir (KuryeKotasi). Ek kurye paketi bu
                     limiti büyütür, o yüzden limit plan değeri değil bayinin kendi değeridir. --}}
                <x-panel.bilgi-satir k="Kurye hesabı">
                    <span class="tab">{{ $kuryeKota['kullanilan'] }} / {{ $kuryeKota['limit'] }}</span>
                    @if ($ekKurye > 0)
                        <span style="color:var(--accent)"> + {{ $ekKurye }} ek</span>
                    @endif
                </x-panel.bilgi-satir>
            </div>

            @if ($tanimlamalar->isNotEmpty())
                <x-panel.tablo>
                    <tbody>
                        @foreach ($tanimlamalar as $t)
                            <tr>
                                <td>
                                    <div class="kalin">{{ $t->package_name }}</div>
                                    @if ($t->note)
                                        <div class="soluk" style="font-size:12.5px">{{ $t->note }}</div>
                                    @endif
                                </td>
                                <td class="soluk tab" style="white-space:nowrap">{{ $tarih($t->granted_on) }}</td>
                                <td class="sag kalin tab">
                                    @if ($t->collection_method === 'bedelsiz')
                                        <span class="soluk">Bedelsiz</span>
                                    @else
                                        {{ $tl((int) $t->amount_kurus) }}
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </x-panel.tablo>
            @endif

            <x-slot:aksiyonlar>
                <a class="btn" href="{{ route('panel.packages') }}">
                    <x-panel.ikon ad="arti" boy="15" /> Ek Paket Tanımla
                </a>
            </x-slot:aksiyonlar>
        </x-panel.kart>
    </div>

    <div class="dikey">
        <x-panel.kart baslik="Ödeme Geçmişi" :adet="$odemeler->count().' kayıt'">
            @if ($odemeler->isEmpty())
                <x-panel.bos metin="Henüz ödeme kaydı yok." />
            @else
                <x-panel.tablo>
                    <thead>
                        <tr>
                            <th>Tarih</th><th class="sag">Tutar</th><th>Yöntem</th><th>Dönem</th><th>Not</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($odemeler as $o)
                            <tr>
                                <td class="tab">{{ $tarih($o->occurred_at) }}</td>
                                <td class="sag kalin tab">{{ $tl((int) $o->amount_kurus) }}</td>
                                <td>{{ $yontemAdi[$o->provider] ?? $o->provider }}</td>
                                <td>{{ $o->covers_period ?: '—' }}</td>
                                <td class="soluk">{{ $o->note ?: '—' }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </x-panel.tablo>
            @endif
        </x-panel.kart>

        <x-panel.kart baslik="Notlar" :adet="$notlar->count().' not'">
            @if ($notlar->isEmpty())
                <x-panel.bos metin="Henüz not yok." />
            @else
                <div class="not-liste">
                    @foreach ($notlar as $not)
                        <div class="not-satir">
                            <div class="not-tarih tab">{{ $tarih($not->created_at) }}</div>
                            <div class="not-metin">{{ $not->body }}</div>
                        </div>
                    @endforeach
                </div>
            @endif

            {{-- Notlar APPEND-ONLY: düzenleme/silme yoktur. "Yanlış yazdım"ın karşılığı yeni nottur. --}}
            <div class="not-form">
                <textarea
                    class="girdi"
                    rows="2"
                    wire:model="yeniNot"
                    placeholder='örn. "Telefonla arandı, haftaya ödeyecek."'
                ></textarea>
                <button type="button" class="btn" wire:click="notEkle">Not Ekle</button>
            </div>
        </x-panel.kart>
    </div>
</div>

<div class="dikey" style="margin-top:12px">
    @include('livewire.panel.tenant.yonetim')
    @include('livewire.panel.tenant.kullanim')
</div>

@if ($uzatAcik)
    @include('livewire.panel.tenant.modal-uzat')
@endif

@if ($kuryeAcik)
    @include('livewire.panel.tenant.modal-kurye')
@endif
