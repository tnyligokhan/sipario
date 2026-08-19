<?php

use App\Livewire\Panel\AdminUsers;
use App\Livewire\Panel\AuditLog;
use App\Livewire\Panel\Bildirimler;
use App\Livewire\Panel\CustomerImport;
use App\Livewire\Panel\Dashboard;
use App\Livewire\Panel\GelirGider;
use App\Livewire\Panel\Login;
use App\Livewire\Panel\Odemeler;
use App\Livewire\Panel\Paketler;
use App\Livewire\Panel\TenantDetail;
use App\Livewire\Panel\TenantList;
use App\Livewire\Site\Hesap;
use App\Livewire\Site\Login as SiteLogin;
use App\Livewire\Site\Parola;
use App\Livewire\Site\ParolaYenile;
use App\Livewire\Site\Register;
use App\Livewire\Site\Subscribe;
use App\Models\AdminUser;
use App\Panel\Csv;
use App\Panel\PanelCsvExportService;
use App\Panel\PanelExportService;
use App\Panel\PanelImportService;
use App\Panel\TenantAdminService;
use App\Payment\SubscriptionService;
use App\Yedek\YedekArsivi;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;

/*
 * GENEL SİTE (sipario.com.tr) — pazarlama sayfaları. Livewire DEĞİL, düz Blade görünümü:
 * içerik statiktir, sunucu durumu taşımaz; dönem anahtarı / SSS akordiyonu gibi etkileşimler
 * Alpine ile istemcide çözülür. Tasarım hash-routing kullanıyordu (#fiyat) — biz gerçek URL
 * veriyoruz: bu bir SATIŞ sitesi, sayfaların ayrı ayrı dizine düşmesi gerekiyor.
 */
Route::view('/', 'site.ana')->name('site.ana');
Route::view('ozellikler', 'site.ozellikler')->name('site.ozellikler');
Route::view('fiyatlar', 'site.fiyatlar')->name('site.fiyatlar');
Route::view('destek', 'site.destek')->name('site.destek');
Route::view('iletisim', 'site.iletisim')->name('site.iletisim');

/*
 * "Biz kimiz" (2026-08-19). Tasarım kaynağında yoktu ve eksikliği ölçülebilirdi: site yıllık
 * dört haneli bir ödeme istiyor ama arkasında kimin olduğunu hiçbir yerde söylemiyordu.
 * Boşluk bu vardiyada BÜYÜDÜ — uydurma müşteri yorumları kaldırıldı ve yerlerine gerçek
 * referans konamadı (ürün pilotta, izin alınmış yorum yok). Sayfa o güven boşluğunu sahte
 * olmayan bir şeyle dolduruyor.
 */
Route::view('hakkimizda', 'site.hakkimizda')->name('site.hakkimizda');

/*
 * ── ARAMA MOTORU + YAPAY ZEKÂ KEŞİF DOSYALARI (2026-08-19) ──────────────────────────────────
 *
 * `robots.txt` BURADA DEĞİL: o statik bir dosyadır (public/robots.txt) ve web sunucusu onu
 * Laravel'e hiç uğratmadan döndürür — rota yazmak ölü kod olurdu. Aşağıdaki ikisi ise
 * ÜRETİLMESİ gereken dosyalar: sayfa listesi ve hukuk belgeleri config'ten geliyor, elle
 * yazılan bir kopya ilk belge eklendiğinde bayatlardı.
 *
 * Rotaların `tenant` middleware'i YOK ve olmamalı — içerik kiracıdan bağımsız, üstelik her
 * bot isteğine bir DB transaction'ı bindirmek boşuna maliyet (aynı gerekçe genel site
 * sayfaları için de geçerli; bkz. components/layouts/site.blade.php başlığı).
 */
Route::get('sitemap.xml', function () {
    /*
     * Sayfa → değişim sıklığı + öncelik. `lastmod` BİLEREK YOK: doğru bir lastmod ancak
     * içeriğin gerçekten ne zaman değiştiği biliniyorsa verilebilir. `now()` basmak her tarama
     * turunda "her sayfa bugün değişti" demek olurdu ve Google bunu fark edip lastmod'a
     * tamamen güvenmeyi bırakır — yanlış sinyal, hiç sinyal vermemekten kötüdür.
     */
    $sayfalar = [
        ['site.ana', 'weekly', '1.0'],
        ['site.ozellikler', 'monthly', '0.9'],
        ['site.destek', 'monthly', '0.7'],
        ['site.hakkimizda', 'yearly', '0.6'],
        ['site.iletisim', 'monthly', '0.6'],
        ['account.deletion', 'yearly', '0.3'],
    ];

    $adresler = [];

    foreach ($sayfalar as [$ad, $siklik, $oncelik]) {
        $adresler[] = ['loc' => route($ad), 'changefreq' => $siklik, 'priority' => $oncelik];
    }

    /*
     * Hukuk belgeleri haritadan gelir — yeni bir belge eklendiğinde site haritasına elle
     * eklenmesi gerekmez. Bu sayfalar dizine AÇIKTIR ve açık kalmalı: "sipario kvkk",
     * "sipario iptal" aramaları gerçek ve bu sayfalar o aramanın doğru cevabı.
     */
    foreach (array_keys((array) config('subscription.legal_docs')) as $slug) {
        $adresler[] = ['loc' => route('legal.show', $slug), 'changefreq' => 'yearly', 'priority' => '0.4'];
    }

    // `/fiyatlar` BİLEREK YOK: sayfa `noindex` (2026-08-05 kararı). Site haritasına koyup
    // aynı sayfaya noindex vermek Google'a çelişkili iki sinyal göndermektir.

    return response()
        ->view('seo.sitemap', ['adresler' => $adresler])
        ->header('Content-Type', 'application/xml; charset=utf-8');
})->name('seo.sitemap');

/*
 * llms.txt — yapay zekâ araçlarına sitenin ne olduğunu ve hangi sayfanın neyi anlattığını
 * anlatan düz metin özet (llmstxt.org önerisi).
 *
 * NEDEN: bu ürün hakkında bir dil modeline soru sorulduğunda, model sayfaları tek tek
 * tarayıp çıkarım yapmak yerine burayı okur. Bir SaaS için bu artık markdown bir "hakkımızda"
 * kadar sıradan bir dosyadır ve maliyeti bir rotadır.
 *
 * ⚠️ İÇERİK PAZARLAMA DİLİ TAŞIMAZ. Modeli ikna etmeye çalışan bir metin, modelin ürünü
 * yanlış anlatmasına yol açar. Burada yalnız DOĞRULANABİLİR olgular var — ne yapar, ne
 * yapmaz, hangi platformda çalışır, fiyat nereden okunur.
 */
Route::get('llms.txt', function () {
    return response()
        ->view('seo.llms')
        ->header('Content-Type', 'text/plain; charset=utf-8');
})->name('seo.llms');

/*
 * Public abonelik/ödeme sitesi (Faz 5b) — WEB, mağaza kuralı gereği mobil DIŞI. auth YOK; üyelik
 * tenant+patron yaratır (owner), abonelik iyzico ile (soyut PaymentGateway). Callback CSRF muaf
 * (bootstrap/app.php) — iyzico dış POST.
 */
Route::get('kayit', Register::class)->name('subscription.register');
Route::get('giris', SiteLogin::class)->name('subscription.login');
Route::get('abonelik', Subscribe::class)->name('subscription.subscribe');

// Parola sıfırlama (tasarım: sw-giris.jsx · SifreSayfa). Oturum GEREKMEZ.
Route::get('parola', Parola::class)->name('site.parola');

// Token'lı yenileme ekranı. Tasarımda YOK ama akış onsuz tamamlanmaz. Ad birebir bu olmalı —
// `ResetPassword::createUrlUsing` bu ada bağlanıyor (Laravel'in varsayılan `password.reset` adı
// bu projede tanımlı değil).
Route::get('parola/yenile/{token}', ParolaYenile::class)->name('site.parola.yenile');

/*
 * Bayinin HESAP PANELİ (tasarım: sw-hesap.jsx) — abonelik, oto-sıralama hakkı, faturalar,
 * ödeme yöntemi, işletme bilgileri. Bayinin PATRON hesabıyla ('web' guard) girilir; kurye ve
 * operatör web'e hiç girmez (mobil, firma koduyla). Mağaza kuralı: bu yüzey YALNIZ web'de var.
 */
/*
 * `tenant` middleware'i BURADA ZORUNLUDUR ve süs değildir: `users` tablosunda RLS FORCE açıktır,
 * yani `auth:web` kullanıcıyı yüklemeye çalıştığında `app.tenant_id` kurulmamışsa SIFIR SATIR görür
 * ve giriş yapmış bayi kendi hesap sayfasına giremez. ResolveTenantContext bağlamı oturumdan kurar
 * ve öncelik listesinde zaten auth'tan öne alınmıştır.
 */
Route::get('hesap', Hesap::class)->middleware(['tenant', 'auth:web'])->name('site.hesap');

/*
 * Bayinin çıkışı — POST, GET DEĞİL. Üst menüdeki çıkış düğmesi buraya form + @csrf ile gelir;
 * GET olsaydı önceden getirme (prefetch) ya da üçüncü taraf bir sayfadaki <img> ile İSTEMSİZ
 * tetiklenebilirdi — kullanıcıyı sebepsiz oturumdan atan bir CSRF yüzeyi.
 *
 * `tenant` middleware'i BİLEREK YOK: SessionGuard::logout() oturum verisini kullanıcıyı
 * YÜKLEYEBİLMESİNDEN BAĞIMSIZ olarak temizler, yani RLS bağlamı kurulmadan da doğru çalışır.
 * (Bu sayfaların kullanıcıyı hiç okuyamadığı zaten ölçüldü — bkz. components/layouts/site.blade.php.)
 * Takarsak RouteCoverageGuardTest her `tenant`lı rotadan izolasyon senaryosu ister; çıkış için
 * ödenecek bedel değil.
 *
 * `auth:web` de YOK ve bu da kasıtlı: oturumu zaten düşmüş biri çıkışa basınca giriş ekranına
 * fırlatılmasın. İşlem idempotenttir — gövde `Hesap::cikis()` ile birebir aynıdır.
 */
Route::post('cikis', function () {
    Auth::guard('web')->logout();
    session()->invalidate();
    session()->regenerateToken();

    return redirect()->route('site.ana');
})->name('site.cikis');
Route::post('abonelik/callback', function (Request $request, SubscriptionService $service) {
    $service->handleCallback($request->all());

    return redirect()->route('subscription.subscribe')->with('status', 'Ödeme sonucu işlendi.');
})->name('subscription.callback');

/*
 * Hukuk belgeleri (5d iskeleti) — mesafeli satış / ön bilgilendirme / iptal-iade / KVKK. İçerik
 * config('subscription.legal_docs') haritasından; metinler PLACEHOLDER (hukuk onayı = SENİN SIRAN).
 * Checkout onay kutuları buraya link verir; bilinmeyen slug 404.
 */
Route::get('sozlesme/{doc}', function (string $doc) {
    /** @var array<string, array{title: string, version_key: string}> $docs */
    $docs = config('subscription.legal_docs');
    abort_unless(isset($docs[$doc]), 404);

    return view('legal.show', [
        'slug' => $doc,
        'title' => $docs[$doc]['title'],
        'version' => config('subscription.legal')[$docs[$doc]['version_key']],
    ]);
})->name('legal.show');

/*
 * Hesap ve veri silme talebi sayfası (Faz 6) — Google Play, hesap sistemi olan uygulamalar için
 * genel erişilebilir bir silme URL'i şart koşar; data-safety formu buraya işaret eder. Statik bilgi
 * sayfası (BRIEF: uygulamada silme butonu yok, talep destek kanalından). İletişim/süre PLACEHOLDER.
 */
Route::view('hesap-silme', 'legal.hesap-silme')->name('account.deletion');

/*
 * Yönetim paneli (Faz 5c) — BİZE ait iç araç, `admin` guard (bayilerden ayrı). Livewire + session.
 * İş verisi salt-okunur (sipario_panel DB izniyle zorlanır); panel abonelik/durum yönetir.
 */
Route::prefix('panel')->group(function () {
    Route::get('login', Login::class)->name('panel.login');

    Route::post('logout', function () {
        Auth::guard('admin')->logout();
        session()->invalidate();
        session()->regenerateToken();

        return redirect()->route('panel.login');
    })->name('panel.logout');

    Route::middleware('auth:admin')->group(function () {
        // Ana sayfa GENEL BAKIŞ panosudur (5c-3 · D1): "bugün kime bakmalıyım" sorusunu cevaplar.
        // Tüm bayilerin listesi ayrı sayfaya taşındı — pano büyüdükçe liste onu boğuyordu.
        Route::get('/', Dashboard::class)->name('panel.dashboard');
        Route::get('bayiler', TenantList::class)->name('panel.tenants');
        Route::get('tenants/{tenant}', TenantDetail::class)->name('panel.tenant');

        /*
         * PARA EKRANLARI (yeni tasarım). Eylemler POST route'u DEĞİL, Livewire eylemleridir
         * (wire:click) — sunucu tarafı kapı her eylemin İÇİNDEdir, route middleware'ine
         * güvenilmez (5c-3 güvenlik incelemesinin dersi: route throttle Livewire'ı korumaz).
         */
        Route::get('odemeler', Odemeler::class)->name('panel.payments');
        Route::get('paketler', Paketler::class)->name('panel.packages');
        Route::get('gelir-gider', GelirGider::class)->name('panel.finance');

        // Bayinin siteden yaptığı havale beyanları — panelin "bugün kime bakmalıyım" kuyruğu.
        Route::get('bildirimler', Bildirimler::class)->name('panel.notifications');

        /*
         * Veri export (Faz 5c-2): bayinin iş verisi JSON dump (panel SELECT, salt-okunur, cross-tenant filtreli).
         *
         * Her indirme `panel_audit`e düşer (güvenlik incelemesi 5c-3): bu üç route panelin en
         * yüksek hacimli kişisel veri çıkışıdır ve izsizdi. Günlüğe yalnız eylem türü + hedef bayi
         * yazılır, indirilen değerler DEĞİL (panel_audit'in KVKK-nötr sözleşmesi).
         */
        Route::get('tenants/{tenant}/export', function (string $tenant, PanelExportService $export, TenantAdminService $admin) {
            $data = $export->export($tenant);
            abort_if($data === [], 404);

            $admin->auditExport($tenant, 'json', Auth::guard('admin')->id());

            return response()->json($data)
                ->header('Content-Disposition', 'attachment; filename="tenant-'.$tenant.'.json"');
        })->name('panel.tenant.export');

        /*
         * CSV dışa aktarım (5c-3 · D4) — İNSANIN Excel'de açacağı iki liste. Yukarıdaki JSON dump
         * teknik bir taşıma aracıdır ve DURUR; ikisi farklı işlere hizmet eder. Hücreler
         * Csv::hucre'den geçer (formül enjeksiyonu).
         */
        Route::get('tenants/{tenant}/csv/musteriler', function (string $tenant, PanelCsvExportService $csv, TenantAdminService $admin) {
            $admin->auditExport($tenant, 'csv_musteriler', Auth::guard('admin')->id());

            return Csv::indirme($csv->musteriler($tenant), 'musteriler-'.$tenant.'.csv');
        })->name('panel.tenant.csv.musteriler');

        Route::get('tenants/{tenant}/csv/siparisler', function (string $tenant, Request $request, PanelCsvExportService $csv, TenantAdminService $admin) {
            $filtre = $request->only(['durum', 'baslangic', 'bitis']);
            $admin->auditExport($tenant, 'csv_siparisler', Auth::guard('admin')->id());

            return Csv::indirme($csv->siparisler($tenant, $filtre), 'siparisler-'.$tenant.'.csv');
        })->name('panel.tenant.csv.siparisler');

        // Toplu müşteri aktarımı (5c-3 · D4): şablon indir → yükle → önizle → onayla.
        Route::get('csv/musteri-sablonu', function (PanelImportService $import) {
            return Csv::indirme($import->sablon(), 'musteri-sablonu.csv');
        })->name('panel.csv.sablon');

        Route::get('tenants/{tenant}/musteri-aktar', CustomerImport::class)->name('panel.tenant.import');

        /*
         * Yönetim (5c-3 · D5). Denetim günlüğü her iki role de açıktır (hesap verebilirliği
         * güçlendirir); hesap yönetimi YALNIZ superadmin'e — kapı bileşenin içindedir
         * (mount + her eylem), route seviyesinde bir middleware'e güvenilmiyor.
         */
        Route::get('denetim', AuditLog::class)->name('panel.audit');
        Route::get('yoneticiler', AdminUsers::class)->name('panel.admins');

        /*
         * VERİTABANI YEDEĞİ İNDİRME — panelin EN YÜKSEK riskli çıkışı.
         *
         * Yukarıdaki export route'ları TEK bayinin verisini verir; bu route TÜM bayilerin
         * TÜM verisini tek dosyada verir. Bu yüzden üç fark taşır:
         *
         *  1. YALNIZ SUPERADMIN. `support` rolü bayi destekler, veritabanı taşımaz. Kapı
         *     route'un İÇİNDEdir — `auth:admin` middleware'i yalnız "giriş yapmış mı"
         *     sorusunu cevaplar, "hangi rol" sorusunu değil.
         *  2. Dosya adı KULLANICIDAN gelir; `YedekArsivi::coz()` onu üç kapıdan geçirir
         *     (basename → desen → realpath ön eki). Buraya `file_get_contents($dosya)`
         *     yazmak, container'ın tüm dosya sistemini panele açardı.
         *  3. Her indirme `panel_audit`e düşer. İz olmadan bu route'un varlığı,
         *     "veriyi kim ne zaman aldı" sorusunu cevapsız bırakırdı.
         *
         * Bağlantı günlük e-posta ile gelir (`yedek:baglanti-gonder`). İmzalı-link
         * (`temporarySignedRoute`) BİLEREK kullanılmadı: e-posta kutusu ele geçen biri,
         * imzalı bağlantıyla veritabanının tamamını indirirdi.
         */
        Route::get('yedek/{dosya}', function (string $dosya, TenantAdminService $admin) {
            $yonetici = Auth::guard('admin')->user();

            abort_unless($yonetici instanceof AdminUser && $yonetici->isSuperadmin(), 403);

            $yol = YedekArsivi::varsayilan()->coz($dosya);

            abort_if($yol === null, 404);

            $admin->auditYedekIndirme((string) $yonetici->id, basename($yol));

            return response()->download($yol, basename($yol), [
                'Content-Type' => 'application/gzip',
            ]);
        })->name('panel.yedek.indir');
    });
});
