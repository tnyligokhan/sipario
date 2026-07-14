<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiters();
    }

    /**
     * Hız sınırları (güvenlik denetimi bulgusu F1 — kaba kuvvet / kimlik bilgisi doldurma).
     *
     * Zamanlama yan-kanalı zaten kapalı (AuthController), ama sınırsız deneme sözlük saldırısına
     * kapı açar. İki katmanlı sınır: (1) hedefli — aynı e-posta+IP'ye kaba kuvvet, (2) yayılı —
     * tek IP'den birçok e-postaya numaralandırma. Aşımda 429 döner (AppendServerTime yine ekler).
     */
    private function configureRateLimiters(): void
    {
        RateLimiter::for('login', function (Request $request) {
            // E-posta gövdeden okunur; büyük/küçük harf normalize (login lookup lower() ile eşleşir).
            $email = Str::lower((string) $request->input('email'));

            return [
                Limit::perMinute(5)->by('login:cred:'.$email.'|'.$request->ip()),
                Limit::perMinute(20)->by('login:ip:'.$request->ip()),
            ];
        });

        // Korumalı API: kimlik doğrulanmışsa kullanıcı başına, değilse IP başına dakikada 60.
        // Çalınan bir token'ın istismar hızını ve genel DoS yüzeyini sınırlar.
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(60)
            ->by($request->user()?->id ?: $request->ip()));
    }
}
