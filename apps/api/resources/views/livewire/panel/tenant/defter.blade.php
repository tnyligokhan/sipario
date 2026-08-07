{{-- Defter sekmesi — SALT-OKUNUR, append-only. Mevcut işlev korundu, tasarım diline geçirildi. --}}
@use('App\Livewire\Panel\Concerns\Bicim')
<div class="dikey">
    <x-panel.kart baslik="Defter" ikon="belge" :adet="$defter->total().' kayıt'">
        <div class="modal-bilgi" style="margin:14px 18px">
            <x-panel.ikon ad="bilgi" boy="15" />
            <span>SALT-OKUNUR — defter append-only'dir; panelden para kaydı girilmez/silinmez.</span>
        </div>

        @if ($defterOzet->isEmpty())
            <x-panel.bos metin="Hiç defter kaydı yok." />
        @else
            <div class="bilgi-satirlar">
                @foreach ($defterOzet as $o)
                    <x-panel.bilgi-satir :k="$o->entry_type">
                        <span class="tab">{{ $o->adet }} kayıt · <x-kurus :value="$o->toplam" /></span>
                    </x-panel.bilgi-satir>
                @endforeach
            </div>
        @endif

        <div class="aksiyonlar" style="border-bottom:1px solid var(--line)">
            <x-panel.alan label="Tip">
                <select class="girdi" wire:model.live="defterTip" wire:change="defterSuzgeciUygula">
                    <option value="">hepsi</option>
                    <option value="debit">borç (debit)</option>
                    <option value="payment">tahsilat (payment)</option>
                    <option value="credit">alacak (credit)</option>
                    <option value="discount">iskonto (discount)</option>
                    <option value="correction">düzeltme (correction)</option>
                </select>
            </x-panel.alan>
        </div>

        @if ($defter->isEmpty())
            <x-panel.bos ikon="ara" metin="Defter kaydı bulunamadı." />
        @else
            <x-panel.tablo>
                <thead>
                    <tr>
                        <th>Tarih</th><th>Müşteri</th><th>Tip</th>
                        <th class="sag">Tutar</th><th>Ödeme</th><th>Not</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($defter as $d)
                        <tr>
                            <td class="tab">{{ Bicim::tarihSaat($d->occurred_at) }}</td>
                            <td class="kalin">{{ $d->musteri ?? '—' }}</td>
                            <td class="soluk">{{ $d->entry_type }}</td>
                            <td class="sag kalin tab"><x-kurus :value="$d->amount_kurus" /></td>
                            <td class="soluk">{{ $d->payment_type ?? '—' }}</td>
                            <td class="soluk">{{ $d->note ?? '—' }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </x-panel.tablo>
        @endif
    </x-panel.kart>

    {{ $defter->links('vendor.pagination.panel-basit') }}
</div>
