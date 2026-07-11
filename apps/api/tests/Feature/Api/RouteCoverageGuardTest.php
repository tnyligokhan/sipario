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
        'api.devices.index',
        'api.devices.store',
        'api.devices.show',
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
