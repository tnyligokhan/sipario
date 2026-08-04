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
use App\Panel\Csv;
use App\Panel\PanelCsvExportService;
use App\Panel\PanelExportService;
use App\Panel\PanelImportService;
use App\Panel\TenantAdminService;
use App\Payment\SubscriptionService;
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
    });
});
