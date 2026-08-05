/**
 * CSP-GÜVENLİ ALPINE BİLEŞENLERİ (2026-08-04, `csp_safe` sıkılaştırması).
 *
 * Alpine'ın CSP derlemesi (Livewire `csp_safe` açıkken kullanılır) HTML özniteliklerindeki
 * (x-data, @click, x-init, x-on:...) ifadeleri kendi sandbox'lı ayrıştırıcısıyla değerlendirir ve bu
 * ayrıştırıcı YALNIZ basit değer/çağrı ifadelerini destekler:
 *  - `window`, `navigator`, `document`, `setTimeout`, `clearTimeout` gibi çıplak globallere erişim
 *    "Undefined variable" hatasıyla SESSİZCE düşer (öznitelik hiç çalışmaz, konsola hata yazılır) —
 *    ayrıştırıcının tanıdığı TEK kimlikler x-data özellikleri ve Alpine "magic"leridir ($el, $event,
 *    $refs, $wire, ...).
 *  - `;` ile ayrılmış birden çok deyim, ok fonksiyonu (`() => ...`), obje içi KISALTILMIŞ metot/getter
 *    tanımı (`sec(f) {...}`, `get eslesen() {...}`) ve düzenli ifade (`/\D/g`) da DESTEKLENMEZ —
 *    değerlendiricinin (Evaluator) düğüm anahtarında bunlara karşılık gelen bir dal yok.
 *
 * Bu dosya, yukarıdaki sınırların HERHANGİ birine çarpan mantığı gerçek bir JS metoduna/bileşenine
 * taşır — HTML özniteliği artık yalnız bu metodu ÇAĞIRIR (basit CallExpression/MemberExpression),
 * asıl mantık burada, sıradan tarayıcı JS motoruyla çalışan bir `.js` dosyasında yaşar ve Alpine'ın
 * sandbox'lı ayrıştırıcısına hiç uğramaz.
 *
 * DOĞRULAMA (dev DB'ye dokunmadan): Alpine'ın CSP değerlendiricisinin (Tokenizer/Parser/Evaluator)
 * gerçek kaynağı `vendor/livewire/livewire/dist/livewire.csp.js`ten birebir alınıp Node'da izole
 * çalıştırıldı — bu dosyadaki taşımadan ÖNCEKİ ifadelerin TAMAMI (globallere erişim + `;` zinciri +
 * ok fonksiyonu) ölçülerek KIRILDIĞI, taşımadan SONRAKİ hâllerin (yalnız çağrı/üye erişimi) TAMAMI
 * çalıştığı doğrulandı.
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

    /**
     * Panelin toast'u — components/panel/tost.blade.php (layouts/panel.blade.php'de BİR KEZ).
     * `bildirimKutusu`nun panel karşılığı; alan adları (`mesaj`/`acik`) ve süre (3200ms) tasarımın
     * kendi bileşeniyle aynı kalsın diye korunuyor, iki toast BİLEREK ayrı bileşen (site 2600ms'de
     * kayboluyor, panel 3200'de — birleştirmek ilgisiz iki ekranı gereksiz bağlardı).
     * Eskiden: x-on:tost.window="mesaj = $event.detail.mesaj; acik = true; clearTimeout(...); ..."
     * Şimdi:   x-on:tost.window="goster($event.detail.mesaj)"
     */
    Alpine.data('tostKutusu', () => ({
        acik: false,
        mesaj: '',
        zamanlayici: null,
        goster(mesaj) {
            this.mesaj = mesaj;
            this.acik = true;
            clearTimeout(this.zamanlayici);
            this.zamanlayici = setTimeout(() => {
                this.acik = false;
            }, 3200);
        },
    }));

    /**
     * Panel: firma arama kombosu — components/panel/firma-combo.blade.php (Ödemeler/Paketler'in
     * "Ödeme Ekle"/"Tanımla" modallarında). `model` seçilen firmanın yazılacağı `wire:model` hedefidir
     * (kullanım yerine göre değişir: `form.firmaId` ya da `tanimlaForm.firmaId`) — bu yüzden fabrika
     * ikinci parametre olarak alır, sabit yazılmaz.
     *
     * `$wire` NOTU: orijinal ifade bunu ÇIPLAK bir Alpine magic'i olarak kullanıyordu (satır içi
     * HTML özniteliğinde `with()` benzeri bir kapsam genişlemesiyle otomatik erişilebilir). Gerçek
     * bir Alpine.data() metodunun İÇİNDE aynı magic `this.$wire` üzerinden erişilir — Alpine
     * component nesnesine metotları ÇAĞRILDIĞINDA bağlar, bu yüzden `$wire.set(...)` burada
     * `this.$wire.set(...)`e çevrildi (davranış AYNI, yalnız erişim yolu farklı).
     * Eskiden: x-data="{ ..., sec(f) { ...; $wire.set('{{ $model }}', f.id); } }"
     * Şimdi:   x-data="firmaCombo(@js($liste), @js($model))"
     */
    Alpine.data('firmaCombo', (liste, model) => ({
        acik: false,
        metin: '',
        liste,
        get eslesen() {
            const a = this.metin.toLocaleLowerCase('tr');
            return this.liste.filter((f) => f.ad.toLocaleLowerCase('tr').includes(a));
        },
        sec(f) {
            this.metin = f.ad;
            this.acik = false;
            this.$wire.set(model, f.id);
        },
    }));

    /**
     * SSS arama/grup süzgeci — site/parca/destek-sss.blade.php. `aranabilir` grup adı → o gruptaki
     * her sorunun (soru+cevap, TR küçültülmüş) aranabilir metin dizisidir; sunucuda hazırlanır.
     * Eskiden: x-data="{ ..., ara() {...}, esles(m) {...}, grupta(g) {...}, grupVar(g) {...},
     *                     bulunan() {...} }" (obje içi kısaltılmış metotlar — CSP ayrıştırıcısı
     *                     bunları çözemez, `FunctionExpression` düğümü için bir dal yok).
     * Şimdi:   x-data="sssArama(@js($aranabilir))"
     */
    Alpine.data('sssArama', (aranabilir) => ({
        q: '',
        g: 'hepsi',
        acik: null,
        gruplar: aranabilir,
        ara() {
            return this.q.trim().toLocaleLowerCase('tr-TR');
        },
        esles(m) {
            const a = this.ara();
            return a === '' || m.includes(a);
        },
        grupta(g) {
            return this.g === 'hepsi' || this.g === g;
        },
        grupVar(g) {
            return this.grupta(g) && this.gruplar[g].some((m) => this.esles(m));
        },
        bulunan() {
            let n = 0;
            for (const g in this.gruplar) {
                if (this.grupta(g)) {
                    n += this.gruplar[g].filter((m) => this.esles(m)).length;
                }
            }
            return n;
        },
    }));

    /**
     * İletişim formu — site/parca/iletisim-form.blade.php. Sunucuya HİÇ gitmez (bkz. görünümün
     * kendi belge başlığı); "Gönder" düğmesi `mailto:` bağlantısını hazırlayıp tarayıcıya devreder.
     * Eskiden: x-data="{ ..., dogrula() {...}, gonder() { ...; window.location.href = 'mailto:...' } }"
     * Şimdi:   x-data="iletisimForm(@js($hedef))"
     *
     * NOT (davranış BİLEREK değiştirilmedi — CSP taşıması saf bir taşımadır): `gonder()` içindeki
     * `&amp;body=` parçası HTML kaçışlı bir dizeyi `mailto:` URL'sine AYNEN taşıyor; bu muhtemelen
     * bu taşımadan ÖNCEKİ bir yazım hatasıdır (mailto sorgu dizisi HTML değildir, `&` beklenir).
     * Kapsam dışı bırakıldı, raporlandı — burada DÜZELTİLMEDİ.
     */
    Alpine.data('iletisimForm', (hedef) => ({
        f: { ad: '', isletme: '', telefon: '', konu: 'Demo talebi', mesaj: '' },
        h: { ad: null, telefon: null },
        hedef,
        dogrula() {
            this.h.ad = this.f.ad.trim() ? null : 'Adınızı girin';
            this.h.telefon = !this.f.telefon.trim()
                ? 'Size ulaşabileceğimiz bir numara girin'
                : (this.f.telefon.replace(/\D/g, '').length < 10 ? 'Numara eksik görünüyor' : null);
            return !this.h.ad && !this.h.telefon;
        },
        gonder() {
            if (!this.hedef || !this.dogrula()) {
                return;
            }
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
    }));

    /**
     * Hero telefonunun kendi kendine oynayan gösterimi — site/parca/ana-hero.blade.php.
     * Kaynak: _kaynak/web/07-sw-telefon.jsx · `TelefonCanli` (React'te useState + useEffect).
     * Kareler ve süreler ORADAN birebir: 0 sakin (2200ms) → 1 çağrı gelir (4200ms) → 2 sipariş
     * oluştu bildirimi + ciro/açık sipariş artar (3000ms) → başa. Toplam döngü 9,4 sn.
     *
     * Zamanlayıcı BURADA yaşamak zorunda: `csp_safe` altında Alpine'ın öznitelik değerlendiricisi
     * `setTimeout` gibi çıplak globalleri "Undefined variable" ile sessizce düşürür. HTML yalnız
     * `x-data="heroDongu"` der. `destroy()` Alpine bileşeni sökerken zamanlayıcıyı temizler —
     * aksi halde geri sayım DOM'dan kopmuş bir bileşene yazmaya devam ederdi.
     */
    Alpine.data('heroDongu', () => ({
        kare: 0,
        zamanlayici: null,
        sureler: [2200, 4200, 3000],
        init() {
            this.sirala();
        },
        sirala() {
            this.zamanlayici = setTimeout(() => {
                this.kare = (this.kare + 1) % 3;
                this.sirala();
            }, this.sureler[this.kare]);
        },
        destroy() {
            clearTimeout(this.zamanlayici);
        },
    }));
});
