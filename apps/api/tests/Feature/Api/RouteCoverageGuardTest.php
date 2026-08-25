<?php

namespace Tests\Feature\Api;

use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * KIRMIZI ÇİZGİ #1'in "sürekli kanıtla" bekçisi (DECISIONS: yeni endpoint izolasyon testi
 * almadıysa build kırılır). Bu test DB gerektirmez: `tenant` middleware'ine sahip TÜM route'ları
 * sayar ve TenantIsolationTest'in bilerek kapsadığı beklenen kümeyle karşılaştırır.
 *
 * Yeni bir tenant-scope endpoint eklenip bu listeye (ve izolasyon matrisine) eklenmezse test
 * KIRILIR — geliştiriciyi izolasyon kapsamı eklemeye zorlar. Endpoint kaldırılırsa da uyarır.
 */
class RouteCoverageGuardTest extends TestCase
{
    /**
     * TenantIsolationTest tarafından açıkça kapsanan tenant-scope route adları.
     * Bir route buraya eklendiğinde, TenantIsolationTest'e de karşılık gelen cross-tenant
     * senaryosu eklenmelidir (kod incelemesi + bu bekçi birlikte zorlar).
     */
    private const COVERED_TENANT_ROUTES = [
        'api.auth.me',
        'api.auth.logout',

        /*
         * YÖNETİCİ ONAYI (2026-08-18). Kiracılar arası bir yüzey DEĞİLDİR ve olamaz: doğrulanan
         * parola HER ZAMAN oturumdaki kullanıcınındır, kullanıcı adı gövdeden ALINMAZ. Yine de
         * `tenant` middleware'ini taşıdığı için bekçi onu sayar ve matriste karşılığı vardır —
         * "başka bayinin kullanıcısının parolası bu uçtan denenemez" iddiası, tam olarak
         * denenmediği için doğru sayılan türden bir iddiaydı.
         */
        'api.auth.parola-dogrula',
        'api.devices.index',
        'api.devices.store',
        'api.devices.show',
        'api.sync.push',
        'api.sync.pull',
        'api.orders.auto-route',
        'api.geocode.search',
        'api.locations.heartbeat',
        'api.locations.live',
        'api.team.credentials',

        /*
         * Matristeki ilk TARAYICI route'u (2026-08-04): bayinin hesap paneli. Yukarıdakiler
         * bearer token'lı API uçları, bu oturum çerezli bir Livewire ekranı — kimlik farklı
         * taşınıyor ama `tenant` middleware'i taşıdığı için kural aynı ve bekçi onu da sayıyor.
         *
         * Kapsayan senaryolar: `TenantIsolationTest::hesap_paneli_baska_bayinin_kimligine_gecirilemez`
         * (istemci `#[Locked] $bayiId`i yazamaz) ve `..._yalnizca_kendi_bayisinin_verisini_gosterir`.
         */
        'site.hesap',
    ];

    #[Test]
    public function her_tenant_scope_route_izolasyon_matrisinde_kapsanir(): void
    {
        $tenantScoped = collect(Route::getRoutes()->getRoutes())
            ->filter(fn ($route) => in_array('tenant', $route->gatherMiddleware(), true))
            ->map(fn ($route) => $route->getName())
            ->filter() // isimsiz route'ları atla
            ->values()
            ->sort()
            ->values()
            ->all();

        $expected = collect(self::COVERED_TENANT_ROUTES)->sort()->values()->all();

        $this->assertSame(
            $expected,
            $tenantScoped,
            "Tenant-scope route kümesi değişti. Yeni bir endpoint eklendiyse TenantIsolationTest'e ".
            'cross-tenant senaryosunu ekle ve COVERED_TENANT_ROUTES listesini güncelle. '.
            'Kırmızı çizgi #1: her tenant-scope endpoint izolasyon testi almalıdır.'
        );
    }
}
