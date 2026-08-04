{{--
    Hukuk onayları — ÜÇÜ DE ZORUNLU (SubscriptionService::startCheckout'un sözleşmesi burada
    korunuyor; bkz. Site\Subscribe bileşen notu). Kutular `legal.show` route'una link verir ve
    kabul edilen SÜRÜMLER beyan kaydına yazılır.

    Tasarım bu onayları yalnız kart formunun altına küçük bir cümle olarak koymuştu; kart formu
    yazılmadığı için onaylar HER İKİ yola (havale + elden) taşındı — satış satıştır.
--}}
<div class="od-onaylar" style="margin-top:20px">
    <label class="onay">
        <input type="checkbox" wire:model="mesafeliSatis">
        <span>
            <a href="{{ route('legal.show', ['doc' => 'mesafeli-satis']) }}" target="_blank" rel="noopener">Mesafeli satış sözleşmesini</a>
            okudum, kabul ediyorum.
        </span>
    </label>
    <label class="onay">
        <input type="checkbox" wire:model="onBilgilendirme">
        <span>
            <a href="{{ route('legal.show', ['doc' => 'on-bilgilendirme']) }}" target="_blank" rel="noopener">Ön bilgilendirme formunu</a>
            okudum, kabul ediyorum.
        </span>
    </label>
    <label class="onay">
        <input type="checkbox" wire:model="kvkk">
        <span>
            <a href="{{ route('legal.show', ['doc' => 'kvkk-aydinlatma']) }}" target="_blank" rel="noopener">KVKK aydınlatma metnini</a>
            okudum, kabul ediyorum.
        </span>
    </label>
    @error('onaylar')
        <span class="hata"><x-site.ikon ad="uyari" boy="14" kalin="2.3" />{{ $message }}</span>
    @enderror
</div>
