{{--
    Parola sıfırlama — tasarım 12-sw-giris.jsx · SifreSayfa.

    Tasarım "Bağlantı 30 dakika geçerli" diyor; gerçek süre config/auth.php `passwords.users.expire`
    değeridir (bugün 60). Talimat gereği config'e DOKUNULMADI, metin gerçeğe uyduruldu — yoksa site
    sunucuyla yalan söylerdi.

    ⚠️ KÖK ÖĞE KOŞULLU OLAMAZ — bu dosya bir kez `@if ($asama === 1)` ile BAŞLIYORDU ve o yüzden
    parola sıfırlama SESSİZCE ÖLÜYDU (2026-08-11, canlıda tarayıcıyla ölçüldü).

    Livewire kök özniteliklerini (`wire:id`/`wire:snapshot`) şu düzenli ifadeyle yerleştirir
    (`Livewire\Drawer\Utils::insertAttributesIntoHtmlRoot`):

        /(?:\n|^)(\s*)<([a-zA-Z0-9\-]+)/

    yani kök etiketin SATIR BAŞINDA olmasını şart koşar. Görünüm `@if` ile başlayınca Livewire'ın
    kendi `<!--[if BLOCK]><![endif]-->` işaretçisi araya giriyor ve kabuğun `<main class="kimlik">`
    etiketi ONUNLA AYNI SATIRDA kalıyordu:

        <body>\n    <!--[if BLOCK]><![endif]-->    <main class="kimlik">

    Regex `<main`i göremeyip bir SONRAKİ satır başındaki etikete, yani kabuğun `<aside>`ine
    (soldaki dekoratif panel) atlıyordu. Sonuç: bileşen kökü `<aside>` oluyor, form ise
    `<section>` tarafında, yani KÖKÜN DIŞINDA kalıyordu → `wire:submit` hiç bağlanmıyor,
    düğme formu tarayıcının kendi GET'iyle gönderiyor (`/parola?`), sunucuya hiçbir Livewire
    isteği ulaşmıyordu.

    ARIZANIN HİÇBİR İZİ YOKTU: konsolda hata yok, tüm varlıklar 200, `window.Livewire` yüklü ve
    bileşen kayıtlı görünüyor, `Livewire::test()` sunucuda YEŞİL geçiyor. Yalnız tarayıcıda
    "kök hangi öğe?" diye sorulunca ortaya çıktı.

    KURAL: bu görünümün İLK ÇIKTISI daima tek bir kök öğe olmalı; koşullar kökün İÇİNDE durur.
    `PostaYapilandirmaTest` kardeşi `LivewireKokOgesiTest` bunu makineyle denetler.
--}}
<x-site.kimlik-kabuk kulak="Parola"
    :baslik="$asama === 1 ? 'Bağlantıyı gönderdik.' : 'Parolanızı sıfırlayalım.'"
    :aciklama="$asama === 1
        ? $gonderilen.' adresine parola yenileme bağlantısı gitti. Bağlantı '.$this->gecerlilikDakika().' dakika geçerli.'
        : 'Hesabınızın e-posta adresini yazın; yenileme bağlantısını gönderelim.'">

    @if ($asama === 1)
        <x-site.kutu tur="mor" ikon="posta">
            E-posta gelmediyse gereksiz (spam) klasörüne bakın. Hâlâ yoksa 0850 000 00 00 numaradan bize ulaşın.
        </x-site.kutu>

        <div class="dg-grup" style="margin-top:24px">
            <button type="button" class="dg dg-c" wire:click="adresiDegistir">Adresi değiştir</button>
            <a class="dg dg-a" href="{{ route('subscription.login') }}">Girişe dön</a>
        </div>
    @else
        <form wire:submit="gonder" novalidate>
            <x-site.alan etiket="E-posta" :hata="$errors->first('eposta')" id="s-eposta">
                <input id="s-eposta" class="gir @error('eposta') yanlis @enderror" type="email" inputmode="email"
                    autocomplete="email" placeholder="mehmet@merkezsubayi.com" wire:model="eposta">
            </x-site.alan>

            <button class="dg dg-a tam" type="submit" wire:loading.attr="disabled">
                <span wire:loading.remove wire:target="gonder">Bağlantı gönder</span>
                <span class="donen" wire:loading wire:target="gonder"></span>
            </button>
        </form>

        <a class="dg dg-d tam" style="margin-top:12px" href="{{ route('subscription.login') }}">
            <x-site.ikon ad="okSol" boy="17" kalin="2.2" />Girişe dön
        </a>
    @endif
</x-site.kimlik-kabuk>
