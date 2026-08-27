/**
 * ÖLÇÜM — GA4/GTM KURULUMU (2026-08-19; rıza kısmı 2026-08-28'de cerez.js'e taşındı).
 *
 * ── BU DOSYA NEDEN VAR (ve neden satır içi <script> değil) ───────────────────────────────────
 * Sitenin CSP'si `script-src 'self' 'nonce-…'`. Google'ın verdiği hazır parça satır içi bir
 * <script> bloğudur; nonce'layarak çalıştırmak mümkündü ama iki sakıncası vardı:
 *   1. Nonce'lu satır içi blok, HTML enjeksiyonu bulunan bir sayfada saldırganın kopyalayacağı
 *      bir örnek bırakır. Ölçüm mantığı 'self' bir dosyada durursa nonce'a hiç ihtiyaç kalmaz.
 *   2. Mantık burada büyüdü: rıza kapısı, olay yardımcıları, dış bağlantı işaretleme. Bunlar
 *      layout'un içine gömülseydi her sayfada yeniden okunan 4 KB'lık bir blok olurdu.
 *
 * ── RIZA BU DOSYADA YÖNETİLMEZ (2026-08-28) ─────────────────────────────────────────────────
 * Çerez rızası ve tercih penceresi `public/js/cerez.js`e taşındı; burası onun MÜŞTERİSİDİR:
 * `window.siparioCerez.izin('olcum')` diye sorar ve `dinle()` ile karar değişikliğini bekler.
 * Ayrım keyfi değil — rıza altyapısı ölçüm dışında kategoriler de taşır (bugün taşımıyor, ama
 * eklendiği gün bu dosyaya dokunulmayacak). Çerezi burada okumak, ikinci bir ayrıştırıcı ve
 * ilk biçim değişikliğinde sessizce sapan bir kopya demekti.
 *
 * ── RIZA KAPISI: ETİKET RIZADAN ÖNCE HİÇ YÜKLENMEZ ──────────────────────────────────────────
 * Yaygın kurulum, gtag.js'i hemen yükleyip Consent Mode ile "denied" demektir. O yaklaşım
 * GDPR yorumlarında tartışmalıdır ve KVK Kurulu'nun çerez rehberindeki "önceden rıza"
 * beklentisini karşıladığı KESİN DEĞİLDİR: betik yüklenir yüklenmez googletagmanager.com'a
 * bir istek gider ve o istek ziyaretçinin IP'sini Google'a taşır.
 *
 * Burada daha dar olan yol seçildi: rıza gelene kadar `googletagmanager.com`a HİÇBİR İSTEK
 * GİTMEZ. Betik ancak "kabul" tıklandığında DOM'a enjekte edilir. Consent Mode v2 çağrıları
 * yine yapılır (Google'ın kendi sinyal beklentisi için) ama gtag kuyruğuna, betik yüklenmeden
 * önce yazılır — `dataLayer` sıradan bir dizidir, gtag.js sonradan gelip kuyruğu tüketir.
 *
 * Sonuç: Çerez Politikası'ndaki "izin vermezseniz Google'a hiçbir istek gönderilmez" cümlesi
 * ölçülebilir biçimde doğrudur. (Doğrulama: DevTools → Network → "google" filtresi; rıza
 * verilmeden hiçbir satır görünmemeli.)
 *
 * ── SAYFA YAPILANDIRMASI NEREDEN GELİYOR ────────────────────────────────────────────────────
 * Layout, `<script type="application/json" id="olcum-ayar">` içinde ölçüm kimliğini, GTM
 * kimliğini basar (rıza çerezi ARTIK BURADA DEĞİL — cerez.js kendi kanalını okur). Bu, alpine.js
 * "dizi/nesne yükü JSON kanalıyla taşınır" deseninin aynısıdır — burada Alpine yok ama desen
 * aynı sebeple doğru: veri, öznitelik dizesine sıkıştırılmaz.
 */
(function () {
    'use strict';

    var ayar = okuAyar();
    if (!ayar) {
        return; // Ölçüm kapalı ya da kimlik yok — bu dosya hiç yüklenmemiş gibi davranır.
    }

    window.dataLayer = window.dataLayer || [];

    /**
     * Google'ın kendi gtag tanımı. `arguments` nesnesinin KENDİSİ itilir (diziye çevrilmez) —
     * gtag.js bunu böyle bekler; `Array.from(arguments)` ile itmek komutları bozar.
     */
    function gtag() {
        window.dataLayer.push(arguments);
    }
    window.gtag = gtag;

    var rizaVar = izinVar();

    /*
     * Consent Mode v2 — VARSAYILAN REDDEDİLMİŞ.
     *
     * Dört sinyalin dördü de burada. `ad_user_data` ve `ad_personalization` v2 ile zorunlu
     * hâle geldi; eksik bırakmak Google tarafında "consent unspecified" üretir.
     * `wait_for_update`, rıza kararı geç gelirse etiketin erken ateşlenmesini engeller.
     */
    gtag('consent', 'default', {
        ad_storage: 'denied',
        ad_user_data: 'denied',
        ad_personalization: 'denied',
        analytics_storage: 'denied',
        functionality_storage: 'granted', // zorunlu çerezler — rızaya bağlı değil
        security_storage: 'granted',
        wait_for_update: 500
    });

    if (rizaVar) {
        rizayiUygula();
    }

    rizayiDinle();
    olaylariBagla();

    /* ─────────────────────────── Rıza ─────────────────────────── */

    /** Rıza deposuna tek soru noktası. Depo yoksa (betik yüklenmediyse) cevap HAYIR'dır. */
    function izinVar() {
        return !!(window.siparioCerez && window.siparioCerez.izin('olcum'));
    }

    /**
     * Karar değiştiğinde ölçümü açar ya da kapatır. `cerez.js` bu dosyadan ÖNCE çalışır
     * (ikisi de `defer`, belge sırası korunur), bu yüzden `dinle()` burada hazırdır; yine de
     * `sipario-cerez` olayı yedek yol olarak dinlenir — dosya sırası bir gün değişirse ölçüm
     * sessizce sağır kalmasın.
     */
    function rizayiDinle() {
        if (window.siparioCerez && window.siparioCerez.dinle) {
            window.siparioCerez.dinle(rizayiUygulaVeyaKaldir);

            return;
        }

        window.addEventListener('sipario-cerez', function () {
            rizayiUygulaVeyaKaldir();
        });
    }

    function rizayiUygulaVeyaKaldir() {
        if (izinVar()) {
            rizayiUygula();

            return;
        }

        /*
         * REDDEDİLDİĞİNDE VAR OLAN ÇEREZLER SİLİNİR. Ziyaretçi önce kabul edip sonra
         * reddettiyse `_ga` çerezleri tarayıcıda kalmaya devam ederdi — Çerez Politikası
         * "reddettiğiniz anda ölçüm durur ve ilgili çerezler silinir" diyor; burası o cümlenin
         * karşılığı. Alan adı ön eki, `_ga_G-XXXX` biçimindeki mülke özel çerezi de yakalar.
         */
        silCerezOnEki('_ga');
        gtag('consent', 'update', { analytics_storage: 'denied' });
    }

    function rizayiUygula() {
        gtag('consent', 'update', {
            ad_storage: 'denied',          // reklam çerezi KULLANMIYORUZ; rıza verilse de açılmaz
            ad_user_data: 'denied',
            ad_personalization: 'denied',
            analytics_storage: 'granted'
        });

        etiketiYukle();
    }

    /**
     * Etiketi DOM'a enjekte eder. İki yol var ve ikisi de aynı `dataLayer`i kullanır:
     *   • GTM kimliği varsa konteyner yüklenir; GA4 etiketi konteynerin içinden yönetilir.
     *   • Yoksa doğrudan gtag.js yüklenir.
     * `yuklendi` bayrağı, ziyaretçi tercihini iki kez "kabul"e çevirirse betiğin ikinci kez
     * enjekte edilmesini önler (çift sayım üretirdi).
     */
    var yuklendi = false;

    function etiketiYukle() {
        if (yuklendi) {
            return;
        }
        yuklendi = true;

        if (ayar.gtm) {
            gtag('js', new Date());
            ekleBetik('https://www.googletagmanager.com/gtm.js?id=' + encodeURIComponent(ayar.gtm));

            return;
        }

        ekleBetik('https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(ayar.ga4));
        gtag('js', new Date());

        /*
         * `anonymize_ip` GA4'te varsayılan olarak zaten açıktır ve ayrıca gönderilmesi gerekmez;
         * buradaki iki ayar bilinçli:
         *   • `allow_google_signals:false` → Google'ın reklam kimliğiyle eşleştirme kapalı.
         *     Reklam yapmıyoruz; açık bırakmak Çerez Politikası'ndaki "reklam çerezi yok"
         *     cümlesini yalanlardı.
         *   • `allow_ad_personalization_signals:false` → aynı gerekçe.
         */
        gtag('config', ayar.ga4, {
            allow_google_signals: false,
            allow_ad_personalization_signals: false
        });
    }

    /* ─────────────────────────── Olaylar ─────────────────────────── */

    /**
     * Dönüşüm olayı gönderir. Rıza yoksa hiçbir şey yapmaz — sessizce düşer, hata basmaz.
     * Dışarıya açılır ki Livewire tarafındaki `$dispatch('olcum', …)` da buraya bağlanabilsin.
     */
    function siparioOlay(ad, veri) {
        if (!ad || !izinVar()) {
            return;
        }
        gtag('event', ad, veri || {});
    }
    window.siparioOlay = siparioOlay;

    /**
     * `data-olcum="olay_adi"` taşıyan her öğe tıklandığında olayı gönderir. Yeni bir düğmeye
     * ölçüm eklemek için bu dosyaya DOKUNULMAZ; görünüme öznitelik konur.
     *
     * `data-olcum-etiket` varsa GA4'e `etiket` parametresi olarak geçer — aynı olayın hangi
     * sayfadan/hangi düğmeden geldiğini ayırmaya yarar.
     */
    function olaylariBagla() {
        /*
         * SAYFA AÇILIŞINDA KENDİLİĞİNDEN ATEŞLENEN OLAYLAR.
         *
         * Bazı dönüşümlerin karşılığı bir TIKLAMA değil, BİR SAYFAYA VARMAKTIR: girişten sonra
         * hesap paneline düşmek, ödeme adımını açmak. Bunları tıklamayla ölçmek yanlış sayardı —
         * giriş düğmesine basmak giriş yapmış olmak demek değildir (parola yanlış olabilir).
         *
         * Sunucu, olayın gerçekten olduğu durumda sayfaya `<span data-olcum-otomatik="login">`
         * gibi bir işaret basar; burası onu görüp bir kez ateşler. Livewire'ın `dispatch`i bu
         * iş için kullanılamazdı: giriş bir YÖNLENDİRME ile bitiyor ve yönlendirme, o istekte
         * yayılan tarayıcı olaylarını götürür.
         */
        var otomatik = document.querySelectorAll('[data-olcum-otomatik]');
        for (var k = 0; k < otomatik.length; k++) {
            siparioOlay(otomatik[k].getAttribute('data-olcum-otomatik'), {
                etiket: otomatik[k].getAttribute('data-olcum-etiket') || document.title
            });
        }

        document.addEventListener('click', function (e) {
            var hedef = e.target.closest ? e.target.closest('[data-olcum]') : null;
            if (!hedef) {
                return;
            }
            siparioOlay(hedef.getAttribute('data-olcum'), {
                etiket: hedef.getAttribute('data-olcum-etiket') || document.title
            });
        });

        /*
         * Livewire bileşenleri (kayıt sihirbazı, ödeme ekranı) sunucu tarafında olay yayar;
         * tarayıcı tarafında burada karşılanır. `detail` Livewire 3+ biçimidir.
         */
        window.addEventListener('sipario-olcum', function (e) {
            var d = (e && e.detail) || {};
            siparioOlay(d.ad, d.veri);
        });
    }

    /* ─────────────────────────── Yardımcılar ─────────────────────────── */

    function okuAyar() {
        var kanal = document.getElementById('olcum-ayar');
        if (!kanal) {
            return null;
        }
        try {
            var a = JSON.parse(kanal.textContent);

            return a && a.ga4 ? a : null;
        } catch (hata) {
            return null;
        }
    }

    function ekleBetik(src) {
        var s = document.createElement('script');
        s.async = true;
        s.src = src;
        document.head.appendChild(s);
    }

    function silCerezOnEki(onEk) {
        var hepsi = document.cookie.split(';');
        // Google çerezleri hem tam alan adına hem de nokta ön ekli üst alana yazılabilir;
        // ikisini de denemezsek silme yarım kalır ve çerez ekranda durmaya devam eder.
        var alanlar = [location.hostname, '.' + location.hostname];
        var kok = location.hostname.split('.').slice(-2).join('.');
        if (kok !== location.hostname) {
            alanlar.push('.' + kok);
        }

        for (var i = 0; i < hepsi.length; i++) {
            var ad = hepsi[i].split('=')[0].trim();
            if (ad.indexOf(onEk) !== 0) {
                continue;
            }
            for (var j = 0; j < alanlar.length; j++) {
                document.cookie = ad + '=;expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/;domain=' + alanlar[j];
            }
            document.cookie = ad + '=;expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/';
        }
    }
})();
