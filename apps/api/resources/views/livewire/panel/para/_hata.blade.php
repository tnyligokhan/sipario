{{--
    Modal içindeki servis hatası kutusu — `.modal-bilgi`nin tehlike tonu (bkz. panel.css
    "KİT EKLERİ": `.modal-bilgi.tehlike`).

    Kullanım: @include('livewire.panel.para._hata', ['bildirim' => $bildirim])
--}}
@if (($bildirim['tur'] ?? null) === 'hata')
    <div class="modal-bilgi tehlike" role="alert">
        <x-panel.ikon ad="uyari" boy="15" />
        <span>{{ $bildirim['mesaj'] }}</span>
    </div>
@endif
