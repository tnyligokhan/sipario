{{--
    İşletme açma — tasarım 12-sw-giris.jsx · KayitSayfa (3 adım + başarı ekranı).

    TASARIMDAN İKİ SAPMA, ikisi de bilinçli ve raporlandı:
     1. "14 gün ücretsiz" → PLANDAN gelen gerçek süre (OKU-BENI kararı: 30 gün).
     2. "Sektör" alanı YOK: seçilen sektörün yazılacağı bir kolon/tablo yok ve hiçbir şey
        tetiklemiyor ("hazır katalog" diye bir mekanizma bulunmuyor). Soruyu sorup atmak,
        kullanıcıya yaptığı seçimin bir işe yaradığı hissini verirdi.
     3. Onay satırındaki "kullanım koşulları" → "ön bilgilendirme formu": elimizde
        config('subscription.legal_docs') ile tanımlı dört belge var, "kullanım koşulları"
        onlardan biri değil; olmayan bir belgeye bağlantı vermek 404 demekti.
--}}
@php
    $yasal = fn (string $slug) => route('legal.show', ['doc' => $slug]);
@endphp

@if ($adim === 3)
    <x-site.kimlik-kabuk kulak="Hazır" baslik="İşletmeniz açıldı." :genis="true"
        aciklama="Deneme süreniz bugün başladı. Aşağıdaki giriş bilgileriyle mobil uygulamaya girebilirsiniz.">

        {{--
            ÜÇ BİLGİNİN İKİSİ ARTIK BURADA (2026-08-31). Bu ekran daha önce yalnız firma kodunu
            gösteriyordu; kullanıcı adı sabit 'patron' olduğu için eksiklik gizliydi. Ad artık
            girilen bilgilerden türetiliyor (`KullaniciAdiUretici`), yani bayinin onu ilk kez
            gördüğü yer BURASI. Üçüncüsü — parola — kayıtta kendi yazdığıdır ve saklanmadığı için
            gösterilemez.
        --}}
        <x-site.pano etiket="Giriş bilgileriniz" class="kod-pano">
            <x-site.giris-bilgisi :kod="$olusanKod" :kullanici="$olusanKullanici" />
            <p class="kucuk" style="margin-top:14px">Uygulamanın giriş ekranı bu ikisini ve kayıtta belirlediğiniz parolayı ister. Aynı bilgiler hesap panelinizde de duruyor — buradan not almasanız da kaybolmaz.</p>
        </x-site.pano>

        <div class="kayit-sonraki">
            @foreach ([
                ['Uygulamayı indirin', 'Android için Play Store\'dan "Sipario"yu aratın. iOS sürümü de mağazada.'],
                ['Müşteri listenizi gönderin', 'Excel ya da telefon rehberi olarak destek@sipario.com.tr adresine iletin; aynı gün yükleyelim.'],
                ['Çağrı iznini verin', 'Uygulama ilk açılışta izin isteyecek. İzin verilmezse arayan tanıma çalışmaz.'],
            ] as $i => [$bas, $alt])
                <div class="kayit-s">
                    <span class="kayit-s-n">{{ $i + 1 }}</span>
                    <div><h3 class="h4">{{ $bas }}</h3><p class="kucuk">{{ $alt }}</p></div>
                </div>
            @endforeach
        </div>

        <a class="dg dg-a tam" href="{{ route('site.hesap') }}">
            Hesap paneline git<x-site.ikon ad="ok" boy="18" kalin="2.2" />
        </a>
    </x-site.kimlik-kabuk>
@else
    {{--
        ⚠️ ALT YAZI YANLIŞ YÖNLENDİRİYORDU (2026-08-19). Metin "Zaten hesabınız var mı? SAĞ
        ÜSTTEN giriş yapabilirsiniz." diyordu — ama bu ekran `site-ciplak` layout'unu kullanıyor
        ve o layout'ta ÜST MENÜ YOK (bileşenin kendi belge başlığı da bunu söylüyor: "menüsüz").
        Yani sayfanın sağ üstünde giriş bağlantısı diye bir şey hiç olmadı; hesabı olan kullanıcı
        oraya bakıp bir şey bulamıyordu. Yerine gerçekten çalışan bir bağlantı kondu.

        Açıklamadaki "otomatik ücret alınmaz" ifadesi de sadeleşti: "otomatik ücret" bir yazılım
        deyimi; esnafın korktuğu şeyin adı "kartımdan para çekilmesi"dir.
    --}}
    <x-site.kimlik-kabuk kulak="{{ $this->denemeGun }} gün ücretsiz" baslik="İşletmenizi açalım."
        aciklama="Üç kısa adım, iki dakika sürer. Kart bilgisi istemiyoruz; deneme bitince hiçbir yerden para çekilmez.">

        <x-site.ilerleme :adimlar="['İşletme', 'Yetkili', 'Firma kodu']" :aktif="$adim" />

        <form wire:submit="ileri" novalidate wire:key="adim-{{ $adim }}">
            @if ($adim === 0)
                <x-site.alan etiket="İşletme adı" :hata="$errors->first('isletme')" id="k-isl"
                    ipucu="Müşterilerinizin sizi tanıdığı isim. Sonra değiştirilebilir.">
                    <input id="k-isl" class="gir @error('isletme') yanlis @enderror" autocomplete="organization"
                        placeholder="Merkez Su Bayii" wire:model="isletme">
                </x-site.alan>
                <x-site.alan etiket="E-posta" :hata="$errors->first('eposta')" id="k-eposta"
                    ipucu="Fatura ve hesap bildirimleri buraya gelir.">
                    <input id="k-eposta" class="gir @error('eposta') yanlis @enderror" type="email" inputmode="email"
                        autocomplete="email" placeholder="mehmet@merkezsubayi.com" wire:model="eposta">
                </x-site.alan>
            @elseif ($adim === 1)
                <x-site.alan etiket="Ad soyad" :hata="$errors->first('ad')" id="k-ad">
                    <input id="k-ad" class="gir @error('ad') yanlis @enderror" autocomplete="name"
                        placeholder="Mehmet Yılmaz" wire:model="ad">
                </x-site.alan>
                <x-site.alan etiket="Parola" :hata="$errors->first('parola')" id="k-parola"
                    ipucu="En az 8 karakter. Ekibinizle paylaşmayın — herkesin kendi hesabı olur.">
                    <input id="k-parola" class="gir @error('parola') yanlis @enderror" type="password"
                        autocomplete="new-password" placeholder="••••••••" wire:model="parola">
                </x-site.alan>
            @else
                <x-site.alan etiket="Firma kodu" :hata="$errors->first('kod')" id="k-kod"
                    ipucu="Ekibiniz mobil uygulamaya bu kodla girer. Küçük harf ve rakam; boşluk yok.">
                    <div class="kod-gir">
                        <span class="kod-on mn">sipario.com.tr /</span>
                        <input id="k-kod" class="gir @error('kod') yanlis @enderror" autocapitalize="none"
                            wire:model.blur="kod">
                    </div>
                </x-site.alan>

                <x-site.pano :ince="true" :duz="true" :sikIc="true" class="ozet-pano">
                    <div class="ozet-r"><span>İşletme</span><b>{{ $isletme }}</b></div>
                    <div class="ozet-r"><span>Yetkili</span><b>{{ $ad }}</b></div>
                    <div class="ozet-r"><span>E-posta</span><b>{{ $eposta }}</b></div>
                    <div class="ozet-r"><span>Plan</span><b>Sipario · {{ $this->denemeGun }} gün ücretsiz</b></div>
                </x-site.pano>

                <label class="onay" style="margin:20px 0 6px">
                    <input type="checkbox" wire:model="kvkk">
                    <span>
                        <a href="{{ $yasal('mesafeli-satis') }}" target="_blank" rel="noopener">Mesafeli satış sözleşmesi</a>,
                        <a href="{{ $yasal('on-bilgilendirme') }}" target="_blank" rel="noopener">ön bilgilendirme formu</a> ve
                        <a href="{{ $yasal('kvkk-aydinlatma') }}" target="_blank" rel="noopener">KVKK aydınlatma metnini</a>
                        okudum, kabul ediyorum.
                    </span>
                </label>
                @error('kvkk')
                    <span class="hata" style="margin-bottom:14px"><x-site.ikon ad="uyari" boy="14" kalin="2.3" />{{ $message }}</span>
                @enderror
            @endif

            <div class="kayit-dg">
                @if ($adim > 0)
                    <button type="button" class="dg dg-c" wire:click="geri">
                        <x-site.ikon ad="okSol" boy="18" kalin="2.2" />Geri
                    </button>
                @endif
                <button class="dg dg-a" type="submit" style="flex:1" wire:loading.attr="disabled">
                    <span wire:loading.remove wire:target="ileri">
                        {{ $adim === 2 ? 'İşletmeyi aç' : 'Devam et' }}
                    </span>
                    <span wire:loading.remove wire:target="ileri"><x-site.ikon ad="ok" boy="18" kalin="2.2" /></span>
                    <span class="donen" wire:loading wire:target="ileri"></span>
                </button>
            </div>
        </form>

        {{-- "Sağ üstten giriş yapabilirsiniz" alt yazısının yerini alan GERÇEK bağlantı.
             Bu ekranda üst menü yok (site-ciplak layout'u); hesabı olan kullanıcının çıkışı
             burada olmalı, yoksa geri düğmesine basmaktan başka yolu kalmıyor. --}}
        <p class="kimlik-dip kucuk" style="margin-top:22px">
            Hesabınız zaten var mı? <a class="kimlik-link" href="{{ route('subscription.login') }}">Giriş yapın</a>.
        </p>
    </x-site.kimlik-kabuk>
@endif
