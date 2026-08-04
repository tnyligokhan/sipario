{{--
    İşletme bilgileri — tasarım HIsletme.

    FİRMA KODU İPUCU GERÇEĞE UYDURULDU. Tasarım "Değiştirirseniz herkesin yeniden giriş yapması
    gerekir" diyor; sistem öyle davranmıyor: mobil oturum Sanctum token'ıyla yürür ve token
    satırında `tenant_id` yazılıdır (ResolveTenantContext onu okur), yani AÇIK oturumlar kod
    değişince kapanmaz. Değişen tek şey, BUNDAN SONRAKİ girişlerde yeni kodun istenmesidir
    (`sipario_login_lookup(tenant_code, username)` → `tenants.slug`).

    "Verilerimi dışa aktar" DOSYA İNDİRMEZ — BRIEF kırmızı çizgisi: "uygulamada buton yok, yönetim
    panelinde bizde var". Bayi talebi bırakır, dışa aktarımı biz göndeririz (tasarımın kendi metni
    de "e-posta ile göndereceğiz" diyor).
--}}
<div class="hb">
    <form wire:submit="isletmeKaydet">
        <x-site.pano etiket="İşletme">
            <x-site.alan etiket="İşletme adı" :hata="$errors->first('isletme.isletmeAdi')" id="i-a">
                <input id="i-a" class="gir @error('isletme.isletmeAdi') yanlis @enderror" wire:model="isletme.isletmeAdi">
            </x-site.alan>

            <x-site.alan etiket="Firma kodu" :hata="$errors->first('isletme.firmaKodu')" id="i-k"
                ipucu="Ekibiniz mobil uygulamaya bu kodla girer. Değiştirirseniz açık oturumlar kapanmaz, ama bundan sonraki girişlerde yeni kod istenir.">
                <div class="kod-gir">
                    <span class="kod-on mn">sipario.com.tr /</span>
                    <input id="i-k" class="gir @error('isletme.firmaKodu') yanlis @enderror"
                        autocapitalize="none" wire:model="isletme.firmaKodu">
                </div>
            </x-site.alan>

            <div class="alan-ikili">
                <x-site.alan etiket="Yetkili" :hata="$errors->first('isletme.yetkili')" id="i-y">
                    <input id="i-y" class="gir" wire:model="isletme.yetkili">
                </x-site.alan>
                <x-site.alan etiket="Telefon" :hata="$errors->first('isletme.telefon')" id="i-t">
                    <input id="i-t" class="gir" type="tel" inputmode="tel" wire:model="isletme.telefon">
                </x-site.alan>
            </div>

            <x-site.alan etiket="E-posta" :hata="$errors->first('isletme.eposta')" id="i-e"
                ipucu="Fatura ve hesap bildirimleri bu adrese gider. Giriş de bu adresle yapılır.">
                <input id="i-e" class="gir @error('isletme.eposta') yanlis @enderror"
                    type="email" inputmode="email" wire:model="isletme.eposta">
            </x-site.alan>
        </x-site.pano>

        <x-site.pano etiket="Fatura bilgileri">
            <x-site.kutu tur="mor" ikon="bilgi">
                Buradaki bilgiler e-arşiv faturanızda görünür. Değişiklik sonraki faturadan itibaren geçerli olur.
            </x-site.kutu>
            <div style="height:20px"></div>

            <x-site.alan etiket="Ünvan" :hata="$errors->first('isletme.unvan')" id="f-u">
                <input id="f-u" class="gir" wire:model="isletme.unvan">
            </x-site.alan>
            <div class="alan-ikili">
                <x-site.alan etiket="VKN / TCKN" :hata="$errors->first('isletme.vkn')" id="f-v">
                    <input id="f-v" class="gir @error('isletme.vkn') yanlis @enderror"
                        inputmode="numeric" maxlength="11" wire:model="isletme.vkn">
                </x-site.alan>
                <x-site.alan etiket="Vergi dairesi" :hata="$errors->first('isletme.daire')" id="f-d">
                    <input id="f-d" class="gir" wire:model="isletme.daire">
                </x-site.alan>
            </div>
            <x-site.alan etiket="Adres" :hata="$errors->first('isletme.adres')" id="f-a">
                <input id="f-a" class="gir" wire:model="isletme.adres">
            </x-site.alan>
            <div class="alan-ikili">
                <x-site.alan etiket="İlçe" :hata="$errors->first('isletme.ilce')" id="f-i">
                    <input id="f-i" class="gir" wire:model="isletme.ilce">
                </x-site.alan>
                <x-site.alan etiket="İl" :hata="$errors->first('isletme.il')" id="f-l">
                    <input id="f-l" class="gir" wire:model="isletme.il">
                </x-site.alan>
            </div>

            <button type="submit" class="dg dg-a" style="margin-top:6px" wire:loading.attr="disabled">
                <span wire:loading.remove wire:target="isletmeKaydet">Değişiklikleri kaydet</span>
                <span class="donen" wire:loading wire:target="isletmeKaydet"></span>
            </button>
        </x-site.pano>
    </form>

    <x-site.pano :ince="true" etiket="Veri ve hesap">
        <div class="hb-kisa">
            <button type="button" class="hb-k" wire:click="disaAktarTalep">
                <span class="hb-k-ik"><x-site.ikon ad="indir" boy="19" kalin="2" renk="var(--mor)" /></span>
                <span><b>Verilerimi dışa aktar</b><small>Müşteri, sipariş ve defter kayıtları · e-posta ile göndeririz</small></span>
                <x-site.ikon ad="sag" boy="17" kalin="2.2" renk="var(--sonuk)" />
            </button>
            <button type="button" class="hb-k" wire:click="cikis">
                <span class="hb-k-ik"><x-site.ikon ad="cikis" boy="19" kalin="2" renk="var(--kirmizi)" /></span>
                <span><b>Çıkış yap</b><small>Bu tarayıcıdaki oturumu kapat</small></span>
                <x-site.ikon ad="sag" boy="17" kalin="2.2" renk="var(--sonuk)" />
            </button>
        </div>
    </x-site.pano>
</div>
