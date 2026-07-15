<?php

use App\Livewire\Panel\Login;
use App\Livewire\Panel\TenantDetail;
use App\Livewire\Panel\TenantList;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

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
    });
});
