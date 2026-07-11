<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DeviceController;
use Illuminate\Support\Facades\Route;

/*
| Sipario API v1.
| Public: yalnız giriş (mobilde kayıt YOK — kırmızı çizgi).
| Korumalı grup: önce `tenant` (kiracı bağlamını token'dan kurar + isteği transaction'a sarar),
| sonra `auth:sanctum` (kullanıcıyı RLS altında yükler). Sıra önemlidir.
*/

Route::prefix('v1')->group(function () {
    // --- Public -----------------------------------------------------------------
    Route::post('/auth/login', [AuthController::class, 'login'])->name('api.auth.login');

    // --- Korumalı ---------------------------------------------------------------
    Route::middleware(['tenant', 'auth:sanctum'])->group(function () {
        Route::get('/auth/me', [AuthController::class, 'me'])->name('api.auth.me');
        Route::post('/auth/logout', [AuthController::class, 'logout'])->name('api.auth.logout');

        Route::get('/devices', [DeviceController::class, 'index'])->name('api.devices.index');
        Route::post('/devices', [DeviceController::class, 'store'])->name('api.devices.store');
        Route::get('/devices/{device}', [DeviceController::class, 'show'])->name('api.devices.show');
    });
});
