<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\SyncController;
use Illuminate\Support\Facades\Route;

/*
| Sipario API v1.
| Public: yalnız giriş (mobilde kayıt YOK — kırmızı çizgi).
| Korumalı grup: önce `tenant` (kiracı bağlamını token'dan kurar + isteği transaction'a sarar),
| sonra `auth:sanctum` (kullanıcıyı RLS altında yükler). Sıra önemlidir.
*/

Route::prefix('v1')->group(function () {
    // --- Public -----------------------------------------------------------------
    // throttle:login — kaba kuvvet / kimlik bilgisi doldurma sınırı (F1). Limitler AppServiceProvider'da.
    Route::post('/auth/login', [AuthController::class, 'login'])
        ->middleware('throttle:login')
        ->name('api.auth.login');

    // --- Korumalı ---------------------------------------------------------------
    // throttle:api — kullanıcı/IP başına genel hız sınırı (çalınan token istismarı + DoS yüzeyi).
    Route::middleware(['throttle:api', 'tenant', 'auth:sanctum'])->group(function () {
        Route::get('/auth/me', [AuthController::class, 'me'])->name('api.auth.me');
        Route::post('/auth/logout', [AuthController::class, 'logout'])->name('api.auth.logout');

        Route::get('/devices', [DeviceController::class, 'index'])->name('api.devices.index');
        Route::post('/devices', [DeviceController::class, 'store'])->name('api.devices.store');
        Route::get('/devices/{device}', [DeviceController::class, 'show'])->name('api.devices.show');

        // Senkron: tek yazma yüzeyi (push) + tek okuma yüzeyi (pull). İstemci başka bir yazma
        // endpoint'i görmez; müşteri/sipariş CRUD yerelde Drift + outbox, sunucuya buradan yansır.
        Route::post('/sync/push', [SyncController::class, 'push'])->name('api.sync.push');
        Route::get('/sync/pull', [SyncController::class, 'pull'])->name('api.sync.pull');
    });
});
