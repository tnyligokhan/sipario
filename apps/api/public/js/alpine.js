/**
 * CSP-GÜVENLİ ALPINE BİLEŞENLERİ (2026-08-04, `csp_safe` sıkılaştırması).
 *
 * Alpine'ın CSP derlemesi (Livewire `csp_safe` açıkken kullanılır) HTML özniteliklerindeki
 * (x-data, @click, x-init, x-on:...) ifadeleri kendi sandbox'lı ayrıştırıcısıyla değerlendirir ve bu
 * ayrıştırıcı YALNIZ x-data özelliklerini ve Alpine "magic"lerini ($el, $event, $refs, ...) tanır —
 * `window`, `navigator`, `document`, `setTimeout`, `clearTimeout` gibi çıplak globallere erişim
 * "Undefined variable" hatasıyla SESSİZCE düşer (öznitelik hiç çalışmaz, konsola hata yazılır).
 * Ayrıca `;` ile ayrılmış birden çok deyim ve ok fonksiyonu (`() => ...`) da ayrıştırıcının
 * DESTEKLEMEDİĞİ söz dizimidir.
 *
 * Bu dosya, globale dokunan HER mantığı gerçek bir JS metoduna taşır — öznitelik ifadesi artık
 * yalnız bu metodu ÇAĞIRIR, global bir DEĞERE hiç dokunmaz. Doğrulama: `dev DB'ye dokunmadan,
 * Alpine'ın CSP değerlendiricisinin (Tokenizer/Parser/Evaluator) gerçek kaynağı Node'da izole
 * çalıştırılıp eski ifadelerin hepsinin kırıldığı, yenilerinin hepsinin çalıştığı ölçüldü.
 *
 * Kayıt `alpine:init` olayında yapılır — Alpine bu olayı KENDİ başlamadan hemen önce fırlatır; bu
 * betiğin script etiketi `@livewireScripts`ten (Alpine'ı içeren asıl paket) ÖNCE durmalıdır ki
 * dinleyici Alpine başlamadan kayıtlı olsun (bkz. layout dosyaları).
 */
document.addEventListener('alpine:init', () => {
    /**
     * Kısa ömürlü toast — components/site/bildirim.blade.php.
     * Eskiden: x-on:bildir.window="metin = $event.detail; clearTimeout(...); setTimeout(...)"
     * Şimdi:   x-on:bildir.window="goster($event.detail)"
     */
    Alpine.data('bildirimKutusu', () => ({
        metin: null,
        zamanlayici: null,
        goster(mesaj) {
            this.metin = mesaj;
            clearTimeout(this.zamanlayici);
            this.zamanlayici = setTimeout(() => {
                this.metin = null;
            }, 2600);
        },
    }));

    /**
     * Üst menünün kaydırma durumu — components/site/ust-menu.blade.php.
     * Eskiden: x-init="kaydi = window.scrollY > 12; window.addEventListener('scroll', ...)"
     * Şimdi:   x-data="ustMenu" (init() Alpine.data yaşam döngüsünde kendiliğinden çalışır)
     */
    Alpine.data('ustMenu', () => ({
        kaydi: false,
        acik: false,
        init() {
            this.kaydi = window.scrollY > 12;
            window.addEventListener('scroll', () => {
                this.kaydi = window.scrollY > 12;
            }, { passive: true });
        },
    }));

    /**
     * "Panoya kopyala" + toast — site/hesap/odeme, site/register, site/subscribe (IBAN/firma kodu
     * kopyalama düğmeleri). `deger` metni x-data çağrısıyla (@js(...)) sunucudan gelir.
     * Eskiden: @click="navigator.clipboard?.writeText(bilgi); window.dispatchEvent(new CustomEvent(...))"
     * Şimdi:   @click="kopyala('Hesap bilgileri kopyalandı')"
     */
    Alpine.data('kopyalaKutusu', (deger) => ({
        deger,
        kopyala(mesaj) {
            navigator.clipboard?.writeText(this.deger);
            window.dispatchEvent(new CustomEvent('bildir', { detail: mesaj }));
        },
    }));

    /**
     * Panel: tablo satırına tıklayınca detay sayfasına git — livewire/panel/tenant-list.blade.php.
     * Gerçek erişilebilir bağlantı sağdaki "Detay"dır; bu yalnız fare kolaylığıdır (bkz. görünümdeki
     * yorum) — davranış DEĞİŞMEDİ, yalnız `window.location` erişimi buraya taşındı.
     * Eskiden: x-on:click="window.location = @js(...)"
     * Şimdi:   x-data="satirLink(@js(...))" x-on:click="git()"
     */
    Alpine.data('satirLink', (url) => ({
        git() {
            window.location = url;
        },
    }));
});
