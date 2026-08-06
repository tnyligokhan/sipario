{{--
    Ekip — gömülü Livewire bileşeni (`App\Livewire\Site\Ekip`, sahibi `ekip` ajanı).

    PARAMETRE GEÇİLMEZ ve bu bilinçlidir: bileşen bayiyi ve yetkiyi `Auth::guard('web')` üzerinden
    KENDİSİ çözer. `Hesap::mount()` bu panele `session('subscription_tenant_id')` ile de (henüz
    giriş yapmamış, ödeme akışının ortasındaki bayi) girilmesine izin veriyor; kimlik YARATAN bir
    yüzeyin o kapıdan açılmaması gerekir. Buradan `$bayiId` geçirmek tam da o kapıyı açardı.
--}}
<livewire:site.ekip />
