<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\GeocodeController;
use App\Http\Controllers\Api\LocationController;
use App\Http\Controllers\Api\RouteController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Controllers\Api\TeamController;
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

        // "Oto Sırala (rota)" — SIRA ÖNERİSİ döner ve sunucu-sahipli kontörü düşer; siparişlere
        // YAZMAZ. Yazma yine tek yüzeyden (sync push → sort_set) geçer, yukarıdaki kural bozulmaz.
        // Ek `throttle:rota` (inceleme bulgusu 2026-07-29): kontör ön-bakışı KİLİTSİZ ve paralı
        // Google çağrısı kilitten ÖNCE koşuyor — sınır olmasa 1 kontörlü bayinin 5 cihazı aynı
        // anda basıp 1 kontöre karşılık 5 ücretli çağrı yakabilirdi. Geocode ile aynı çare:
        // parayla ölçülen uç nokta kiracı başına ayrıca sınırlanır.
        Route::post('/orders/auto-route', [RouteController::class, 'autoRoute'])
            ->middleware('throttle:rota')
            ->name('api.orders.auto-route');

        // "Adresten Konum Al" — serbest adres metnini ADAY koordinatlara çevirir; hiçbir şey
        // YAZMAZ (seçilen koordinat yine sync push ile gider). Sağlayıcı anahtarı yalnız
        // sunucuda durur. Ek `throttle:geocode`: bu uç nokta parayla ölçülür, kiracı başına
        // dakikalık + günlük tavanı vardır (genel `throttle:api` yeterli değil).
        Route::post('/geocode', [GeocodeController::class, 'search'])
            ->middleware('throttle:geocode')
            ->name('api.geocode.search');

        // "Canlı kurye konumu". Kalp atışını HERKES gönderir (patron da sahadadır), listeyi
        // YALNIZ patron okur. Ek `throttle:konum`: bu uç nokta uygulama açık olduğu sürece
        // düzenli çağrılır — genel `throttle:api` (60/dk) bozuk bir istemci döngüsüne karşı
        // fazla cömerttir ve o döngü kullanıcının GERÇEK isteklerinin hakkını yerdi. Kullanıcı
        // başına 6/dk, meşru ~30 sn'lik aralığın üç katı pay bırakır (limit AppServiceProvider'da).
        Route::post('/locations/heartbeat', [LocationController::class, 'heartbeat'])
            ->middleware('throttle:konum')
            ->name('api.locations.heartbeat');

        // Ekip üyesinin GİRİŞ BİLGİLERİ (kullanıcı adı/parola). Senkron yolundan AYRI ve
        // bilinçli olarak ONLINE: kimlik yüzeyi offline kuyruğa açılmaz (ayrıntı controller'da).
        // `role:patron` şart — kurye kendi ya da arkadaşının parolasını değiştiremez.
        Route::patch('/team/{user}/credentials', [TeamController::class, 'credentials'])
            ->middleware('role:patron')
            ->name('api.team.credentials');

        // Yalnız patron: kuryenin diğer kuryeleri haritada görmesi için iş gerekçesi yok
        // (KVKK veri minimizasyonu — verilmeyen yetki sızdırılamaz). Aksi rolde 403.
        Route::get('/locations/live', [LocationController::class, 'live'])
            ->middleware('role:patron')
            ->name('api.locations.live');
    });
});
