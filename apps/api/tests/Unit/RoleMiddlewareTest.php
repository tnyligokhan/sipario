<?php

namespace Tests\Unit;

use App\Enums\UserRole;
use App\Http\Middleware\EnsureRole;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use PHPUnit\Framework\Attributes\Test;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

/**
 * EnsureRole (`role:` middleware) birim testi. Faz 1'de hiçbir route bunu kullanmaz (rol kapıları
 * Faz 3-4 sipariş/kurye akışlarında gelecek), ama mantığı bugünden yeşil kilitliyoruz.
 *
 * Neden birim testi (HTTP değil): rol davranışı yalnız $request->user()->role ile $roles listesine
 * bağlıdır. HTTP üzerinden test etmek route kaydı, guard önbelleği ve auth-hatası render'ı gibi
 * ürünle ilgisiz artefaktlar getirir. Middleware'i doğrudan çağırmak niyeti izole ve determinist
 * biçimde sınar. DB'ye dokunmaz.
 */
class RoleMiddlewareTest extends TestCase
{
    /**
     * Verilen rolle (null = oturum yok) middleware'i çalıştırır; izin verilirse yanıtı döner,
     * reddedilirse HttpException fırlatır.
     */
    private function runWithRole(?UserRole $role, array $allowed): Response
    {
        $middleware = new EnsureRole;

        $request = Request::create('/_role', 'GET');
        $request->setUserResolver(
            fn () => $role === null ? null : new User(['role' => $role->value])
        );

        /** @var Response $response */
        $response = $middleware->handle(
            $request,
            fn () => new Response('ok', 200),
            ...$allowed
        );

        return $response;
    }

    #[Test]
    public function izinli_rol_gecer(): void
    {
        $response = $this->runWithRole(UserRole::Patron, ['patron']);
        $this->assertSame(200, $response->getStatusCode());
    }

    #[Test]
    public function coklu_izinli_rol_listesindeki_her_rol_gecer(): void
    {
        $this->assertSame(200, $this->runWithRole(UserRole::Patron, ['patron', 'operator'])->getStatusCode());
        $this->assertSame(200, $this->runWithRole(UserRole::Operator, ['patron', 'operator'])->getStatusCode());
    }

    #[Test]
    public function izinsiz_rol_403_verir(): void
    {
        try {
            $this->runWithRole(UserRole::Kurye, ['patron', 'operator']);
            $this->fail('Kurye, patron/operator route\'unda 403 almalıydı.');
        } catch (HttpException $e) {
            $this->assertSame(403, $e->getStatusCode());
        }
    }

    #[Test]
    public function oturum_yoksa_401_verir(): void
    {
        try {
            $this->runWithRole(null, ['patron']);
            $this->fail('Kullanıcı yokken 401 beklenirdi.');
        } catch (HttpException $e) {
            $this->assertSame(401, $e->getStatusCode());
        }
    }
}
