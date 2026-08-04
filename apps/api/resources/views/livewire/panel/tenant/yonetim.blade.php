{{--
    TASARIMDA YOK — BRIEF md. 3'ün ve kırmızı çizgi #5'in panelde bulunması ZORUNLU yetenekleri.
    Tasarımın kendi kart diliyle, Özet sekmesinin altına yerleştirildi:
      · bayi bazında modül aç/kapa      · patron parolası sıfırlama
      · kurye hesabı açma (kota kapılı) · veri dışa/içe aktarma
--}}
@php($tenant = $detail['tenant'])

<div class="iki-kolon">
    <x-panel.kart baslik="Hesap ve Modüller" ikon="kilit">
        @if ($superadmin)
            <div class="bilgi-satirlar">
                @foreach ($moduller as $anahtar => $etiket)
                    <x-panel.bilgi-satir :k="$etiket">
                        @if ($tenant->modules[$anahtar] ?? false)
                            <span class="rozet aktif">Açık</span>
                        @else
                            <span class="rozet iptal">Kapalı</span>
                        @endif
                        <button
                            type="button"
                            class="link-btn"
                            style="margin-left:8px"
                            wire:click="toggleModule('{{ $anahtar }}')"
                        >Değiştir</button>
                    </x-panel.bilgi-satir>
                @endforeach

                {{-- Kota SUNUCUDA gerçektir: dolu kotada düğme pasif ve SEBEBİ yazılı olmalı,
                     yoksa kullanıcı tıklar, hata alır ve neden olduğunu bilmez. --}}
                <x-panel.bilgi-satir k="Kurye hesabı">
                    <span class="tab">{{ $kuryeKota['kullanilan'] }} / {{ $kuryeKota['limit'] }}</span>
                    <button
                        type="button"
                        class="link-btn"
                        style="margin-left:8px"
                        wire:click="kuryeAc"
                        @disabled($kuryeKota['kalan'] < 1)
                        @if ($kuryeKota['kalan'] < 1)
                            title="Kurye hesabı hakkı dolu. Ek kurye paketi tanımlayarak kotayı büyütebilirsiniz."
                        @endif
                    >Kurye Aç</button>
                </x-panel.bilgi-satir>
            </div>

            <x-slot:aksiyonlar>
                <button type="button" class="btn" wire:click="resetPassword">Patron Şifresini Sıfırla</button>
                <button type="button" class="btn" wire:click="activate">Aboneliği Kaydet (1 yıl)</button>
                <button type="button" class="btn tehlike" wire:click="lock">Kilitle</button>
            </x-slot:aksiyonlar>
        @else
            <x-panel.bos
                ikon="kilit"
                metin="Abonelik, kilit, modül, kurye ve patron şifresi işlemleri yalnız süper yöneticilerdedir. Müşteri ve ürün girişi sizde açıktır."
            />
        @endif
    </x-panel.kart>

    {{-- KIRMIZI ÇİZGİ #5: "veri rehin alınmaz — bu kapı kapalı kalamaz." Her indirme
         panel_audit'e düşer (route'lar auditExport çağırır); günlüğe yalnız NE indirildiği
         yazılır, indirilen DEĞERLER değil. --}}
    <x-panel.kart baslik="Veri Aktarımı" ikon="indir">
        <div class="bilgi-satirlar">
            <x-panel.bilgi-satir k="Tam veri (JSON)">
                <a class="link-btn" href="{{ route('panel.tenant.export', $tenant->id) }}">İndir</a>
            </x-panel.bilgi-satir>
            <x-panel.bilgi-satir k="Müşteriler (CSV)">
                <a class="link-btn" href="{{ route('panel.tenant.csv.musteriler', $tenant->id) }}">İndir</a>
            </x-panel.bilgi-satir>
            <x-panel.bilgi-satir k="Siparişler (CSV)">
                <a class="link-btn" href="{{ route('panel.tenant.csv.siparisler', $tenant->id) }}">İndir</a>
            </x-panel.bilgi-satir>
            <x-panel.bilgi-satir k="Müşteri şablonu (CSV)">
                <a class="link-btn" href="{{ route('panel.csv.sablon') }}">İndir</a>
            </x-panel.bilgi-satir>
        </div>

        <x-slot:aksiyonlar>
            <a class="btn" href="{{ route('panel.tenant.import', $tenant->id) }}">
                <x-panel.ikon ad="yukle" boy="15" /> Müşteri CSV Aktar
            </a>
        </x-slot:aksiyonlar>
    </x-panel.kart>
</div>
