{{-- Siparişler sekmesi — SALT-OKUNUR. Mevcut işlev korundu, tasarım diline geçirildi. --}}
@use('App\Livewire\Panel\Concerns\Bicim')
<div class="dikey">
    <x-panel.kart baslik="Siparişler" ikon="kutu" :adet="$siparisler->total().' kayıt'">
        <div class="modal-bilgi" style="margin:14px 18px">
            <x-panel.ikon ad="bilgi" boy="15" />
            <span>SALT-OKUNUR — sipariş panelden değiştirilmez (defter tutarlılığı, kırmızı çizgi #2).</span>
        </div>

        <div class="aksiyonlar" style="border-top:none;border-bottom:1px solid var(--line)">
            <x-panel.alan label="Durum">
                <select class="girdi" wire:model.live="siparisDurum" wire:change="siparisSuzgeciUygula">
                    <option value="">hepsi</option>
                    <option value="open">açık</option>
                    <option value="delivered">teslim</option>
                    <option value="cancelled">iptal</option>
                </select>
            </x-panel.alan>
            <x-panel.alan label="Başlangıç">
                <input class="girdi" type="date" wire:model.live="siparisBaslangic" wire:change="siparisSuzgeciUygula">
            </x-panel.alan>
            <x-panel.alan label="Bitiş">
                <input class="girdi" type="date" wire:model.live="siparisBitis" wire:change="siparisSuzgeciUygula">
            </x-panel.alan>

            {{-- CSV indirme AYNI süzgeçleri taşır: ekranda süzüp farklı bir liste indirmek en can
                 sıkıcı kusurlardan biri olurdu. --}}
            <a
                class="btn"
                style="align-self:flex-end"
                href="{{ route('panel.tenant.csv.siparisler', [
                    'tenant' => $tenantId,
                    'durum' => $siparisDurum,
                    'baslangic' => $siparisBaslangic,
                    'bitis' => $siparisBitis,
                ]) }}"
            >
                <x-panel.ikon ad="indir" boy="15" /> Bu listeyi CSV indir
            </a>
        </div>

        @if ($siparisler->isEmpty())
            <x-panel.bos ikon="ara" metin="Bu süzgeçle sipariş bulunamadı." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr>
                        <th>Kod</th><th>Müşteri</th><th>Durum</th><th class="sag">Tutar</th>
                        <th>Ödeme</th><th>Kurye</th><th>Tarih</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($siparisler as $s)
                        <tr>
                            <td class="tab">{{ $s->code ? '#'.$s->code : '—' }}</td>
                            <td class="kalin">{{ $s->musteri ?? '—' }}</td>
                            <td class="soluk">{{ $s->status }}</td>
                            <td class="sag kalin tab"><x-kurus :value="$s->total_kurus" /></td>
                            <td class="soluk">{{ $s->payment_type ?? '—' }}</td>
                            <td class="soluk">{{ $s->kurye ?? '—' }}</td>
                            <td class="tab">{{ Bicim::tarihSaat($s->occurred_at) }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>

    {{ $siparisler->links('vendor.pagination.panel-basit') }}
</div>
