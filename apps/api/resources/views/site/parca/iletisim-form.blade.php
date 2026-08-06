{{--
    İletişim · form (15-sw-destek.jsx · IletisimSayfa sağ sütunu).

    GÖNDERİM DAVRANIŞI — KARAR: form SUNUCUYA GİTMEZ. Livewire bileşeni yazamıyorum (app/**,
    livewire/** bu dalgada başka ajanların alanı) ve kaynaktaki sahte "Talebiniz alındı" ekranı
    KULLANILMADI — hiçbir yere gitmeyen bir formda o ekranı göstermek kullanıcıya yalan söylemektir.

    Bunun yerine: doğrulama istemcide çalışır (kaynaktaki kurallarla birebir), "Gönder" düğmesi
    alanları hazır bir `mailto:` mesajına çevirir. Hedef adres `destekEposta` (site/parca/_veri.php)
    — config'deki `support_email` köşeli parantezli yer tutucuysa null döner, düğme PASİF kalır ve
    altında gerekçesi yazar; gerçek adres girildiği an kendiliğinden canlanır. Bugün adres gerçek
    (`destek@sipario.com.tr`), yani AKTİF dal çalışıyor — pasif dal yer tutucuya karşı sigortadır.

    Alan işaretlemesi x-site.alan yerine elle yazıldı: hata metnini Alpine sürüyor, bileşenin `hata`
    prop'u ise sunucu tarafı bir değer bekliyor.
--}}
@php($hedef = $sw['destekEposta'])
{{--
    x-data mantığı public/js/alpine.js'teki `iletisimForm` bileşenine taşındı (csp_safe
    sıkılaştırması, 2026-08-04): CSP altında Alpine'ın öznitelik değerlendiricisi ne obje içi
    kısaltılmış metot tanımını (`dogrula() {...}`) ne de düzenli ifadeyi (`/\D/g`) çözebiliyor,
    `window.location.href` gibi çıplak globallere de erişemiyor. Davranış AYNEN korundu.
--}}
<div class="il-sag" x-data="iletisimForm(@js($hedef))">
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
                    {{-- "Kurumsal teklif" → "Çok şubeli işletme" (2026-08-05): Kurumsal diye bir
                         PLAN kalmadı ama bu bir plan adı değil, bir TALEP türü — çok şubeli bayi
                         gerçek bir satış kanalı ve o talep bize hâlâ geliyor. Seçeneği silmek
                         talebin kendisini görünmez yapardı; adı gerçeği söyleyecek şekilde
                         değiştirildi. --}}
                    @foreach (['Demo talebi', 'Çok şubeli işletme', 'Fiyat ve paket sorusu', 'Teknik destek', 'Fatura / ödeme', 'Diğer'] as $k)
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
                {{-- "Soldaki kanallardan ulaşın" cümlesi KOŞULLU: hedef adres yer tutucuysa e-posta
                     kanalı da süzülüp listeden düşer (ikisi de `support_email`ten besleniyor), telefon
                     ve WhatsApp zaten yer tutucu. O durumda solda hiç kanal kalmayabilir ve okuyucuyu
                     olmayan bir yere göndermiş oluruz. --}}
                <button class="dg dg-a tam" type="button" disabled>Gönder, beni arayın</button>
                <p class="od-kucuk">Form gönderimi henüz açık değil — destek adresimiz kesinleşmedi.@if (! empty($sw['kanal'])) Bu arada soldaki kanallardan bize ulaşabilirsiniz.@endif Bilgileriniz yalnızca bu talebe dönmek için kullanılır. <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK aydınlatma metni</a>.</p>
            @endif
        </form>
    </x-site.pano>
</div>
