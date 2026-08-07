{{--
    AltBilgi — sayfa altbilgisi. Rota adları henüz açılmamışsa bağlantı atlanır.

    `oturum`: bayi oturumu açıksa "Hesap" sütunu üye bağlantılarını gösterir. Üst menüyle aynı
    sözleşme — bu bileşen kimlik doğrulamayı KENDİSİ sorgulamaz, layout geçer (gerekçe:
    components/layouts/site.blade.php; `Auth::check()` genel sayfalarda RLS yüzünden yalan söyler).

    ── BAĞLANTI SÖZLEŞMESİ (2026-08-05) ─────────────────────────────────────────────────────────
    Her satır GERÇEK ve BENZERSİZ bir hedefe gider. Bu kural bir kusurdan doğdu: alt bilgide
    farklı adlar taşıyan bağlantılar aynı sayfaya çıkıyordu — "Kurulum" ve "Özellikler" ikisi de
    /ozellikler'e, "Sürüm notları" ile "Sık sorulanlar" ikisi de /destek'e, "Demo talebi" ile
    "İletişim" ikisi de /iletisim'e. Kullanıcı için bu bir bağlantı değil TUZAKTIR: yeni bir şey
    vaat eder, gördüğü sayfaya geri atar. Yer doldurmak için satır EKLENMEZ; sütunların satır
    sayısı eşit olmak zorunda değildir (ızgara `repeat(4,1fr)`, hücreler üstten hizalı).

    Yeni bir satır eklemenin ŞARTI: kendi rotası + kendi görünümü olan bir hedef. Sınıfı/görünümü
    olmayan rota açmak depoyu kırar (kayıtlı tuzak) — önce sayfa, sonra bağlantı.
--}}
@props(['oturum' => false])
@php
    // Üçüncü öge çapa (fragment); boşsa sayfanın kendisine gider.
    $urun = [
        ['Özellikler', 'site.ozellikler', ''],
        /*
         * FİYAT BAĞLANTISI /fiyatlar'a DEĞİL, ana sayfanın fiyat özetine gider (2026-08-05,
         * `fiyat` ajanıyla teyitleşilerek). Önce alt bilgide /fiyatlar'ı bırakmıştım; ajanın
         * ölçümü kararı değiştirdi: sayfa `noindex` ile arama motorlarına kapatıldı, ana
         * sayfadaki "Paketleri karşılaştır" kaldırıldı ve "Fiyatlara bak" düğmesi de bu çapaya
         * çevrildi. Yani alt bilgi, kullanıcının "göstermeyelim" dediği sayfaya işaret eden TEK
         * yer olarak kalıyordu — kararın her yerde uygulanıp yalnız burada delinmesi olurdu.
         *
         * Fiyat bilgisi KAYBOLMUYOR: `#fiyat` çapası ana sayfanın fiyat özeti bölümüdür
         * (site/parca/ana-fiyat-ozet.blade.php, `id="fiyat"` — ölçüldü). Yani bağlantı gerçek
         * fiyatın göründüğü yere iniyor. `/fiyatlar` rotası ve sayfası DURUYOR; birebir satışta
         * adresi doğrudan paylaşılabilir, sadece siteden kendini göstermiyor.
         */
        ['Fiyatlandırma', 'site.ana', '#fiyat'],
    ];
    $destek = [
        // Tek satır: /destek sayfası zaten "Destek ve sık sorulan sorular" — kanallar ve SSS aynı
        // sayfada. İki ayrı ad vermek (Yardım merkezi + Sık sorulanlar) iki sayfa vaat ediyordu.
        ['Destek ve SSS', 'site.destek'],
        // Üst menüden buraya indi (kullanıcı kararı 2026-08-05).
        ['İletişim', 'site.iletisim'],
    ];
    // Üçüncü öge route parametresidir (yoksa boş dizi) — `Hesap` sütununda sekme anahtarı taşır.
    $hesap = $oturum
        ? [
            ['Hesabım', 'site.hesap', []],
            // `?bolum=` Hesap ekranının GERÇEK sekme anahtarıdır (App\Livewire\Site\Hesap::BOLUMLER,
            // mount() kapalı listeye karşı doğrular) — yani bu üç satır üç ayrı ekrana gider,
            // aynı sayfanın üç adı değil.
            ['Abonelik', 'site.hesap', ['bolum' => 'abonelik']],
            ['Faturalar', 'site.hesap', ['bolum' => 'fatura']],
            ['Hesap ve veri silme', 'account.deletion', []],
        ]
        : [
            ['Giriş yap', 'subscription.login', []],
            ['İşletme aç', 'subscription.register', []],
            // Google Play, hesap sistemi olan uygulamalar için silme talebinin GENEL ERİŞİLEBİLİR
            // bir adreste durmasını şart koşar. Sayfa vardı ama siteden hiçbir yere bağlı değildi
            // (2026-08-05'te ölçüldü: `account.deletion` görünümlerde sıfır referans) — yalnız
            // data-safety formundaki URL'i bilen bulabiliyordu.
            ['Hesap ve veri silme', 'account.deletion', []],
        ];
    $yasal = [
        ['Mesafeli satış sözleşmesi', 'legal.show', 'mesafeli-satis'],
        // Ön bilgilendirme formu mevzuat gereği mesafeli satışın AYRILMAZ ekidir (sözleşmenin 9.
        // maddesi onu ek olarak sayar) ve belge zaten vardı; alt bilgide yoktu, yani ödeme akışı
        // dışından erişilemiyordu.
        ['Ön bilgilendirme formu', 'legal.show', 'on-bilgilendirme'],
        ['İptal ve iade', 'legal.show', 'iptal-iade'],
        ['Gizlilik ve KVKK', 'legal.show', 'kvkk-aydinlatma'],
        ['Çerez politikası', 'legal.show', 'cerez-politikasi'],
    ];
    // Künye tek kaynaktan: config('subscription.company') — ödeme ekranı, hesap paneli ve
    // mesafeli satış sözleşmesi de aynı bloğu okur. Alt bilgide artık yalnız telif satırında
    // kullanılıyor (aşağıdaki `alt-kunye` notuna bak).
    $sirket = config('subscription.company');
    /*
     * Telif satırındaki son yer tutucu da kapatıldı (2026-08-05). Künye bloğu kalkınca sayfada
     * görünen TEK köşeli parantez "© 2026 [Şirket unvanı]." kalmıştı — kaldırılan dört kutuyla
     * aynı türden kırıklık. Şirket unvanı hâlâ yer tutucuyken markaya düşülüyor: "Sipario" bir
     * varsayım değil, verilmiş karardır (BRIEF: "İsim: Sipario", domain alındı, marka başvurusu
     * süreçte) — uydurma bir tüzel kişilik unvanı basmıyoruz. Unvan config'te gerçek değerle
     * dolduğu an bu satır kendiliğinden gerçek unvana döner; kod değişmez.
     */
    $telifAdi = str_starts_with((string) $sirket['title'], '[') ? 'Sipario' : $sirket['title'];
@endphp
<footer class="alt gece">
    <div class="kap">
        <div class="alt-ust">
            <div class="alt-marka">
                <x-site.marka boy="38" koyu />
                <p class="alt-slogan">Telefon çaldığında müşteriniz ekranda. Bayiler ve esnaf için sipariş, veresiye ve kurye defteri.</p>
                <div class="alt-rzt">
                    <x-site.rozet tur="yesil" nokta>Tüm sistemler çalışıyor</x-site.rozet>
                    <x-site.rozet tur="notr">Veriler Türkiye'de</x-site.rozet>
                </div>
            </div>
            <div class="alt-baglanti">
                <div class="alt-sutun">
                    <span class="mn">Ürün</span>
                    @foreach($urun as [$etiket, $ad, $capa])
                        @if(Route::has($ad))<a href="{{ route($ad).$capa }}">{{ $etiket }}</a>@endif
                    @endforeach
                </div>
                <div class="alt-sutun">
                    <span class="mn">Destek</span>
                    @foreach($destek as [$etiket, $ad])
                        @if(Route::has($ad))<a href="{{ route($ad) }}">{{ $etiket }}</a>@endif
                    @endforeach
                </div>
                <div class="alt-sutun">
                    <span class="mn">Hesap</span>
                    @foreach($hesap as [$etiket, $ad, $par])
                        @if(Route::has($ad))<a href="{{ route($ad, $par) }}">{{ $etiket }}</a>@endif
                    @endforeach
                </div>
                <div class="alt-sutun">
                    <span class="mn">Yasal</span>
                    @foreach($yasal as [$etiket, $ad, $doc])
                        @if(Route::has($ad))<a href="{{ route($ad, $doc) }}">{{ $etiket }}</a>@endif
                    @endforeach
                </div>
            </div>
        </div>
        {{--
            ── `alt-kunye` KALDIRILDI (2026-08-05, kullanıcı kararı) ────────────────────────────
            Buradaki dört kutu (Ünvan / Kayıt / İletişim / Ödeme) sitenin görünen yüzünde DÖRT
            KIRIK KUTU basıyordu: `config('subscription.company')` değerlerinin hepsi hâlâ
            "[Şirket unvanı]", "[MERSİS no]" gibi köşeli parantezli yer tutucu. Yer tutucuyu
            gizlemek yerine bloğun tamamı kalktı — gerçek künye gelene kadar burada gösterilecek
            bir şey yok.

            MEVZUAT KARŞILIĞI KAPALI, ÖLÇÜLDÜ: satıcı künyesi (unvan, açık adres, MERSİS, KEP,
            telefon, e-posta) mesafeli satış mevzuatı gereği erişilebilir kalmak zorundadır ve
            iki ayrı belgede duruyor — `legal/docs/mesafeli-satis.blade.php` madde 1 "Taraflar"
            ve `legal/docs/on-bilgilendirme.blade.php` "Satıcı bilgileri". İkisi de yukarıdaki
            Yasal sütunundan tek tıkla açılıyor (2026-08-05 ölçümü: /sozlesme/mesafeli-satis ve
            /sozlesme/on-bilgilendirme → HTTP 200).

            DİKKAT — İKİ AYRI KAYNAK: alt bilgi config'ten okuyordu, hukuk belgeleri ise künyeyi
            DÜZ METİN yer tutucu olarak taşıyor. Gerçek künye geldiği gün config'i doldurmak
            YETMEZ; iki belgedeki köşeli parantezler de elle doldurulmalıdır.

            Künyenin alt bilgiye geri konup konmayacağı (gerçek değerlerle) KULLANICI KARARIDIR.
        --}}
        <div class="alt-son">
            <span class="kucuk">© {{ date('Y') }} {{ $telifAdi }}. Tüm hakları saklıdır.</span>
            {{--
                "Rakamlar örnektir" notu tasarımda VARDI ve kaldırılmamalı: sitedeki kullanım
                sayıları, yorumlar ve süreler hâlâ TEMSİLİ (bkz. site/parca/_temsili-veri.php).
                Gerçek rakamlarla değiştirildikleri gün bu cümle de kaldırılır — ikisi birlikte
                yaşar, biri diğeri olmadan yanlış olur.
            --}}
            <span class="kucuk">{{ $sirket['hours'] }} · Bu sayfadaki rakamlar örnektir.</span>
        </div>
    </div>
</footer>
