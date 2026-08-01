<?php

use App\Livewire\Panel\AdminUsers;
use App\Livewire\Panel\AuditLog;
use App\Livewire\Panel\CustomerImport;
use App\Livewire\Panel\Dashboard;
use App\Livewire\Panel\Login;
use App\Livewire\Panel\TenantDetail;
use App\Livewire\Panel\TenantList;
use App\Livewire\Site\Login as SiteLogin;
use App\Livewire\Site\Register;
use App\Livewire\Site\Subscribe;
use App\Panel\Csv;
use App\Panel\PanelCsvExportService;
use App\Panel\PanelExportService;
use App\Panel\PanelImportService;
use App\Payment\SubscriptionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

/*
 * Public abonelik/ödeme sitesi (Faz 5b) — WEB, mağaza kuralı gereği mobil DIŞI. auth YOK; üyelik
 * tenant+patron yaratır (owner), abonelik iyzico ile (soyut PaymentGateway). Callback CSRF muaf
 * (bootstrap/app.php) — iyzico dış POST.
 */
Route::get('kayit', Register::class)->name('subscription.register');
Route::get('giris', SiteLogin::class)->name('subscription.login');
Route::get('abonelik', Subscribe::class)->name('subscription.subscribe');
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

        // Veri export (Faz 5c-2): bayinin iş verisi JSON dump (panel SELECT, salt-okunur, cross-tenant filtreli).
        Route::get('tenants/{tenant}/export', function (string $tenant, PanelExportService $export) {
            $data = $export->export($tenant);
            abort_if($data === [], 404);

            return response()->json($data)
                ->header('Content-Disposition', 'attachment; filename="tenant-'.$tenant.'.json"');
        })->name('panel.tenant.export');

        /*
         * CSV dışa aktarım (5c-3 · D4) — İNSANIN Excel'de açacağı iki liste. Yukarıdaki JSON dump
         * teknik bir taşıma aracıdır ve DURUR; ikisi farklı işlere hizmet eder. Hücreler
         * Csv::hucre'den geçer (formül enjeksiyonu).
         */
        Route::get('tenants/{tenant}/csv/musteriler', function (string $tenant, PanelCsvExportService $csv) {
            return Csv::indirme($csv->musteriler($tenant), 'musteriler-'.$tenant.'.csv');
        })->name('panel.tenant.csv.musteriler');

        Route::get('tenants/{tenant}/csv/siparisler', function (string $tenant, Request $request, PanelCsvExportService $csv) {
            $filtre = $request->only(['durum', 'baslangic', 'bitis']);

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
