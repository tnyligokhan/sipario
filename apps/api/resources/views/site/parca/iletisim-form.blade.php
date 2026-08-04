{{--
    İletişim · form (15-sw-destek.jsx · IletisimSayfa sağ sütunu).

    GÖNDERİM DAVRANIŞI — KARAR: form SUNUCUYA GİTMEZ. Livewire bileşeni yazamıyorum (app/**,
    livewire/** bu dalgada başka ajanların alanı) ve kaynaktaki sahte "Talebiniz alındı" ekranı
    KULLANILMADI — hiçbir yere gitmeyen bir formda o ekranı göstermek kullanıcıya yalan söylemektir.

    Bunun yerine: doğrulama istemcide çalışır (kaynaktaki kurallarla birebir), "Gönder" düğmesi
    alanları hazır bir `mailto:` mesajına çevirir. Destek e-posta adresi HENÜZ BELLİ OLMADIĞI için
    (site/parca/_veri.php · destekEposta = null) düğme şu an PASİF ve altında gerekçesi yazılı.
    Adres girildiği an düğme kendiliğinden canlanır; başka değişiklik gerekmez.

    Alan işaretlemesi x-site.alan yerine elle yazıldı: hata metnini Alpine sürüyor, bileşenin `hata`
    prop'u ise sunucu tarafı bir değer bekliyor.
--}}
@php($hedef = $sw['destekEposta'])
<div class="il-sag" x-data="{
    f: { ad: '', isletme: '', telefon: '', konu: 'Demo talebi', mesaj: '' },
    h: { ad: null, telefon: null },
    hedef: @js($hedef),
    dogrula() {
        this.h.ad = this.f.ad.trim() ? null : 'Adınızı girin';
        this.h.telefon = !this.f.telefon.trim()
            ? 'Size ulaşabileceğimiz bir numara girin'
            : (this.f.telefon.replace(/\D/g, '').length < 10 ? 'Numara eksik görünüyor' : null);
        return !this.h.ad && !this.h.telefon;
    },
    gonder() {
        if (!this.hedef || !this.dogrula()) return;
        const govde = [
            'Ad soyad: ' + this.f.ad,
            'İşletme: ' + (this.f.isletme || '—'),
            'Telefon: ' + this.f.telefon,
            '',
            this.f.mesaj,
        ].join('\n');
        window.location.href = 'mailto:' + this.hedef
            + '?subject=' + encodeURIComponent('Sipario · ' + this.f.konu)
            + '&amp;body=' + encodeURIComponent(govde);
    },
}">
    <x-site.pano etiket="Bize yazın" class="il-form">
        <form @submit.prevent="gonder()" novalidate>
            <div class="alan">
                <label class="etk" for="il-ad">Ad soyad</label>
                <input id="il-ad" class="gir" :class="{ yanlis: h.ad }" x-model="f.ad" autocomplete="name" placeholder="Mehmet Yılmaz">
                <span class="hata" x-show="h.ad" x-cloak>
                    <x-site.ikon ad="uyari" boy="14" kalin="2.3" /><span x-text="h.ad"></span>
                </span>
            </div>

            <div class="alan-ikili">
                <div class="alan">
                    <label class="etk" for="il-is">İşletme<small>isteğe bağlı</small></label>
                    <input id="il-is" class="gir" x-model="f.isletme" autocomplete="organization" placeholder="Merkez Su Bayii">
                </div>
                <div class="alan">
                    <label class="etk" for="il-tel">Telefon</label>
                    <input id="il-tel" class="gir" :class="{ yanlis: h.telefon }" x-model="f.telefon"
                        type="tel" inputmode="tel" autocomplete="tel" placeholder="05xx xxx xx 00">
                    <span class="hata" x-show="h.telefon" x-cloak>
                        <x-site.ikon ad="uyari" boy="14" kalin="2.3" /><span x-text="h.telefon"></span>
                    </span>
                </div>
            </div>

            <div class="alan">
                <label class="etk" for="il-konu">Konu</label>
                <select id="il-konu" class="gir" x-model="f.konu">
                    @foreach (['Demo talebi', 'Kurumsal teklif', 'Fiyat ve paket sorusu', 'Teknik destek', 'Fatura / ödeme', 'Diğer'] as $k)
                        <option>{{ $k }}</option>
                    @endforeach
                </select>
            </div>

            <div class="alan">
                <label class="etk" for="il-m">Mesajınız<small>isteğe bağlı</small></label>
                <textarea id="il-m" class="gir" x-model="f.mesaj"
                    placeholder="Kaç kurye ile çalışıyorsunuz, günde kaç sipariş giriyorsunuz?"></textarea>
            </div>

            @if ($hedef)
                <button class="dg dg-a tam" type="submit">Gönder, beni arayın</button>
                <p class="od-kucuk">“Gönder”e bastığınızda e-posta uygulamanız hazırlanmış bir mesajla açılır; göndermeden önce okuyabilirsiniz. Bilgileriniz yalnızca bu talebe dönmek için kullanılır. <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK aydınlatma metni</a>.</p>
            @else
                <button class="dg dg-a tam" type="button" disabled>Gönder, beni arayın</button>
                <p class="od-kucuk">Form gönderimi henüz açık değil — destek adresimiz kesinleşmedi. Bu arada soldaki kanallardan bize ulaşabilirsiniz. Bilgileriniz yalnızca bu talebe dönmek için kullanılır. <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK aydınlatma metni</a>.</p>
            @endif
        </form>
    </x-site.pano>
</div>
