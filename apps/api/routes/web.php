<?php

use App\Livewire\Panel\Login;
use App\Livewire\Panel\TenantDetail;
use App\Livewire\Panel\TenantList;
use App\Livewire\Site\Login as SiteLogin;
use App\Livewire\Site\Register;
use App\Livewire\Site\Subscribe;
use App\Panel\PanelExportService;
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
        Route::get('/', TenantList::class)->name('panel.tenants');
        Route::get('tenants/{tenant}', TenantDetail::class)->name('panel.tenant');

        // Veri export (Faz 5c-2): bayinin iş verisi JSON dump (panel SELECT, salt-okunur, cross-tenant filtreli).
        Route::get('tenants/{tenant}/export', function (string $tenant, PanelExportService $export) {
            $data = $export->export($tenant);
            abort_if($data === [], 404);

            return response()->json($data)
                ->header('Content-Disposition', 'attachment; filename="tenant-'.$tenant.'.json"');
        })->name('panel.tenant.export');
    });
});
