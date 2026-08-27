/**
 * ÇEREZ RIZASI VE TERCİH MERKEZİ (2026-08-28).
 *
 * ── BU DOSYA NEDEN OLCUM.JS'TEN AYRI ────────────────────────────────────────────────────────
 * Rıza, ölçümün bir parçası değildir; ölçüm rızanın MÜŞTERİSİDİR. Kodu ayırmanın somut karşılığı
 * şu: yarın rızaya bağlı ikinci bir kategori (ör. gömülü video) eklendiğinde ölçüm dosyasına
 * hiç dokunulmaz — yeni tüketici aynı olayı dinler. Birleşik dosyada her yeni kategori, ölçüm
 * mantığının içine sızardı.
 *
 * Yükleme sırası ZORUNLUDUR: bu dosya olcum.js'ten ÖNCE gelir (layout'ta cerez-onay bileşeni
 * olcum bileşeninden önce basılır) ve ikisi de `defer`lidir — `defer` betikler belge sırasına
 * göre çalışır. olcum.js `window.siparioCerez`i hazır bulur.
 *
 * ── RIZA ÇEREZİNİN BİÇİMİ ───────────────────────────────────────────────────────────────────
 *   "<surum>|<izinli kategoriler, virgülle>"     örn:  "1|olcum"   ·   "1|"  (hepsi ret)
 * Kaçış YOK ve bu bilinçli: kullanılan karakterlerin hepsi çerez değerinde geçerlidir, böylece
 * ziyaretçi DevTools'ta çerezine bakınca neye izin verdiğini OKUYABİLİR. Sunucu tarafı aynı
 * biçimi App\Support\Cerez\CerezEnvanteri içinde ayrıştırır; iki taraf da eski tek düğmeli
 * sürümün `kabul`/`ret` değerlerini onurlandırır (o ziyaretçilere pencere yeniden açılmaz).
 *
 * ── SÜRÜM UYUŞMAZLIĞI = KARAR VERİLMEMİŞ ────────────────────────────────────────────────────
 * Rıza, verildiği listeye aittir (KVKK m.3/1-a: belirli bir konuya ilişkin). Liste değişip
 * `surum` artınca eski tercih geçersizleşir ve pencere bir kez daha sorar. Bu, "her ziyarette
 * sor" değildir — sürüm ancak liste gerçekten değişince artar (config/cerezler.php).
 *
 * ── BİR KEZ KARAR VERİLDİ Mİ BİR DAHA SORULMAZ ──────────────────────────────────────────────
 * İki kapı birden: (1) sunucu bandı `hidden` basar (titreme önlemesi), (2) burası çerezi görüp
 * bandı hiç açmaz. Ziyaretçi fikrini değiştirmek isterse alt bilgideki "Çerez tercihleri"
 * düğmesi ya da bandın "Çerezleri yönet" düğmesi pencereyi açar — rızanın GERİ ALINABİLİR
 * olması KVKK m.11 gereğidir; geri alma yolu göstermeyen bir rıza geçersizdir.
 */
(function () {
    'use strict';

    var ayar = okuAyar();
    if (!ayar) {
        return; // Rızaya bağlı çerez yok — bu dosya hiç yüklenmemiş gibi davranır.
    }

    var band = document.getElementById('cerez-band');
    var pencere = document.getElementById('cerez-pencere');
    var dinleyiciler = [];
    var oncekiOdak = null;

    var izinler = cozumle(okuCerez(ayar.cerez));

    kurBand();
    kurPencere();
    kurAcmaDugmeleri();

    /*
     * DIŞ YÜZEY. `olcum.js` ve gelecekteki tüketiciler yalnız bunu kullanır; çerezi kendileri
     * okumaz. Tek okuma noktası olması, biçim değiştiğinde tek dosyanın değişmesi demektir.
     */
    window.siparioCerez = {
        izin: function (kategori) {
            return izinler !== null && izinler.indexOf(kategori) !== -1;
        },
        kararVerildiMi: function () {
            return izinler !== null;
        },
        ac: function () {
            acPencere();
        },
        dinle: function (fn) {
            if (typeof fn === 'function') {
                dinleyiciler.push(fn);
            }
        }
    };

    /* ─────────────────────────── Karar ─────────────────────────── */

    /**
     * Kararı yazar, arayüzü kapatır ve tüketicilere haber verir.
     * `secilen` izin verilen kategori adlarından oluşan dizi.
     */
    function karar(secilen) {
        izinler = temizle(secilen);
        yazCerez(ayar.cerez, ayar.surum + '|' + izinler.join(','), ayar.gun);

        gizleBand();
        kapatPencere();
        duyur();
    }

    function duyur() {
        for (var i = 0; i < dinleyiciler.length; i++) {
            try {
                dinleyiciler[i](izinler.slice());
            } catch (hata) {
                // Bir tüketicinin hatası diğerlerini ve rıza akışını durdurmamalı.
            }
        }

        /*
         * Livewire bileşenleri ve sayfaya özel betikler için tarayıcı olayı. `dinle()` API'sini
         * kullanamayan (bu dosyadan sonra yüklenen) taraflar buradan haberdar olur.
         */
        window.dispatchEvent(new CustomEvent('sipario-cerez', { detail: { izinler: izinler.slice() } }));
    }

    /* ─────────────────────────── Bant ─────────────────────────── */

    function kurBand() {
        if (!band) {
            return;
        }

        // Sunucu zaten `hidden` basmış olabilir; karar yoksa açığa çıkar.
        band.hidden = izinler !== null;

        tikla('cerez-ret', function () { karar([]); });
        tikla('cerez-kabul', function () { karar(ayar.kategoriler); });
        tikla('cerez-yonet', function () { acPencere(); });
    }

    function gizleBand() {
        if (band) {
            band.hidden = true;
        }
    }

    /* ─────────────────────────── Pencere ─────────────────────────── */

    function kurPencere() {
        if (!pencere) {
            return;
        }

        tikla('cerez-p-kapat', kapatPencere);
        tikla('cerez-p-ret', function () { karar([]); });
        tikla('cerez-p-kabul', function () { karar(ayar.kategoriler); });
        tikla('cerez-p-kaydet', function () { karar(secililer()); });

        // Karartıya tıklamak kapatır — ama KARAR VERMEZ. Kapanan pencere "kabul" sayılamaz;
        // rızanın sessizlikten türetilmesi tam olarak rehberin geçersiz saydığı şeydir.
        pencere.addEventListener('mousedown', function (e) {
            if (e.target === pencere) {
                kapatPencere();
            }
        });

        document.addEventListener('keydown', function (e) {
            if (pencere.hidden) {
                return;
            }
            if (e.key === 'Escape') {
                kapatPencere();

                return;
            }
            if (e.key === 'Tab') {
                odagiTut(e);
            }
        });

        kurAkordeonlar();
        kurAnahtarlar();
    }

    function acPencere() {
        if (!pencere) {
            return;
        }

        yansitAnahtarlar();
        oncekiOdak = document.activeElement;
        pencere.hidden = false;
        document.body.classList.add('cerez-kilit');

        var ilk = odaklanabilirler()[0];
        if (ilk) {
            ilk.focus();
        }
    }

    function kapatPencere() {
        if (!pencere || pencere.hidden) {
            return;
        }

        pencere.hidden = true;
        document.body.classList.remove('cerez-kilit');

        if (oncekiOdak && typeof oncekiOdak.focus === 'function') {
            oncekiOdak.focus();
        }
        oncekiOdak = null;
    }

    /**
     * Akordeon. Başlığa basınca o kategorinin çerez tablosu açılır. `aria-expanded` ve `hidden`
     * BİRLİKTE güncellenir: yalnız görsel açmak, ekran okuyucuya kapalı görünen bir tablo
     * bırakırdı.
     */
    function kurAkordeonlar() {
        var basliklar = pencere.querySelectorAll('.cz-kat-ac');

        for (var i = 0; i < basliklar.length; i++) {
            basliklar[i].addEventListener('click', function () {
                var govde = document.getElementById(this.getAttribute('aria-controls'));
                if (!govde) {
                    return;
                }
                var acik = govde.hidden;
                govde.hidden = !acik;
                this.setAttribute('aria-expanded', acik ? 'true' : 'false');
            });
        }
    }

    /** Anahtar kutuları — tıklama anında hiçbir şey KAYDEDİLMEZ; kayıt alt sıradaki düğmelerledir. */
    function kurAnahtarlar() {
        var kutular = anahtarlar();

        for (var i = 0; i < kutular.length; i++) {
            kutular[i].addEventListener('keydown', function (e) {
                // Boşluk tuşu sayfayı kaydırmasın; onay kutusunun kendi davranışı zaten çalışır.
                if (e.key === ' ') {
                    e.preventDefault();
                    this.checked = !this.checked;
                }
            });
        }
    }

    /** Kayıtlı tercihi anahtarlara yansıtır. Karar yoksa hepsi KAPALI açılır (varsayılan ret). */
    function yansitAnahtarlar() {
        var kutular = anahtarlar();

        for (var i = 0; i < kutular.length; i++) {
            var kat = kutular[i].getAttribute('data-cerez-kat');
            kutular[i].checked = izinler !== null && izinler.indexOf(kat) !== -1;
        }
    }

    function secililer() {
        var kutular = anahtarlar();
        var secim = [];

        for (var i = 0; i < kutular.length; i++) {
            if (kutular[i].checked) {
                secim.push(kutular[i].getAttribute('data-cerez-kat'));
            }
        }

        return secim;
    }

    function anahtarlar() {
        return pencere ? pencere.querySelectorAll('[data-cerez-kat]') : [];
    }

    /* ─────────────────────────── Odak tuzağı ─────────────────────────── */

    /**
     * Modal açıkken Tab, pencerenin dışına çıkmamalı. Çıkarsa klavye kullanıcısı arkadaki
     * sayfada kaybolur ve pencereyi kapatamaz — görme engelli bir ziyaretçi için bu, rızayı
     * geri alma yolunun fiilen kapanması demektir.
     */
    function odagiTut(e) {
        var liste = odaklanabilirler();
        if (liste.length === 0) {
            return;
        }

        var ilk = liste[0];
        var son = liste[liste.length - 1];

        if (e.shiftKey && document.activeElement === ilk) {
            e.preventDefault();
            son.focus();
        } else if (!e.shiftKey && document.activeElement === son) {
            e.preventDefault();
            ilk.focus();
        }
    }

    function odaklanabilirler() {
        var hepsi = pencere.querySelectorAll('button, input, a[href], [tabindex]:not([tabindex="-1"])');
        var acik = [];

        for (var i = 0; i < hepsi.length; i++) {
            // Kapalı akordeonun içindeki bağlantılar odak sırasına GİRMEMELİ.
            if (hepsi[i].offsetParent !== null || hepsi[i].classList.contains('cz-svc-g')) {
                acik.push(hepsi[i]);
            }
        }

        return acik;
    }

    /* ─────────────────────────── Alt bilgi / sayfa içi açıcılar ─────────────────────────── */

    function kurAcmaDugmeleri() {
        var acicilar = document.querySelectorAll('[data-cerez-ac]');

        for (var i = 0; i < acicilar.length; i++) {
            acicilar[i].addEventListener('click', function (e) {
                e.preventDefault();
                acPencere();
            });
        }
    }

    /* ─────────────────────────── Yardımcılar ─────────────────────────── */

    function okuAyar() {
        var kanal = document.getElementById('cerez-ayar');
        if (!kanal) {
            return null;
        }
        try {
            var a = JSON.parse(kanal.textContent);

            return a && a.cerez && a.kategoriler && a.kategoriler.length ? a : null;
        } catch (hata) {
            return null;
        }
    }

    /**
     * Çerez değerini izinli kategori listesine çevirir. Karar verilmemişse `null` döner ve bu,
     * boş diziyle AYNI ŞEY DEĞİLDİR: boş dizi "hepsini reddettim"dir ve tekrar sorulmaz.
     */
    function cozumle(deger) {
        if (!deger) {
            return null;
        }

        // Eski tek düğmeli sürümün biçimi.
        if (deger === 'kabul') {
            return temizle(['olcum']);
        }
        if (deger === 'ret') {
            return [];
        }

        var ayrac = deger.indexOf('|');
        if (ayrac === -1) {
            return null;
        }
        if (parseInt(deger.slice(0, ayrac), 10) !== ayar.surum) {
            return null; // Liste değişmiş — eski rıza yeni maddeyi kapsamaz.
        }

        return temizle(deger.slice(ayrac + 1).split(','));
    }

    /** Bilinmeyen/boş kategori adlarını atar — çerez elle kurcalanmış olabilir. */
    function temizle(liste) {
        var cikti = [];

        for (var i = 0; i < (liste || []).length; i++) {
            var ad = String(liste[i]).trim();
            if (ad && ayar.kategoriler.indexOf(ad) !== -1 && cikti.indexOf(ad) === -1) {
                cikti.push(ad);
            }
        }

        return cikti;
    }

    function okuCerez(ad) {
        var m = document.cookie.match('(^|;)\\s*' + ad + '\\s*=\\s*([^;]+)');

        return m ? decodeURIComponent(m[2]) : null;
    }

    function yazCerez(ad, deger, gun) {
        var son = new Date();
        son.setTime(son.getTime() + gun * 86400000);
        // SameSite=Lax + Secure: çerez yalnız kendi sitemizde ve yalnız HTTPS üzerinde taşınır.
        // Değer KAÇIŞLANMAZ — biçimdeki karakterlerin hepsi çerez değerinde geçerli ve okunabilir
        // kalması amaç (bkz. dosya başlığı).
        document.cookie = ad + '=' + deger + ';expires=' + son.toUTCString() +
            ';path=/;SameSite=Lax' + (location.protocol === 'https:' ? ';Secure' : '');
    }

    function tikla(id, fn) {
        var el = document.getElementById(id);
        if (el) {
            el.addEventListener('click', fn);
        }
    }
})();
