<?php

namespace Tests;

use App\Models\Device;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

/**
 * Gerçek Postgres 16 + RLS'e koşan Faz 1 testlerinin ortak tabanı (kırmızı çizgi #1).
 *
 * Neden RefreshDatabase DEĞİL:
 *  - RefreshDatabase her testi tek bir transaction'a sarıp geri alır. Ama uygulamanın kendisi
 *    her isteği ResolveTenantContext ile ayrı bir transaction'a sarar ve `SET LOCAL app.tenant_id`
 *    yazar. Dıştan bir transaction sararsak istek-içi transaction bir SAVEPOINT'e döner, set_config
 *    dış transaction ömrü boyunca yaşar ve istekler arası tenant SIZAR — üretim davranışının tersi.
 *  - Migration owner (pgsql_owner) ile koşmalı (policy/tablo yaratmak için); RefreshDatabase ise
 *    varsayılan app bağlantısını kullanır ve app rolü CREATE POLICY yapamaz.
 *
 * Bu yüzden: süreç başına BİR KEZ `migrate:fresh --database=pgsql_owner`, testler arası owner ile
 * TRUNCATE. Her HTTP isteği kendi gerçek transaction'ında koşar → SET LOCAL doğal sıfırlanır (prod).
 */
abstract class ApiTestCase extends TestCase
{
    /** Şema süreç başına yalnız bir kez kurulur (migrate:fresh pahalıdır). */
    private static bool $migrated = false;

    /** Testler arası owner ile boşaltılan tablolar (FK'ler CASCADE ile çözülür). */
    private const TABLES = ['personal_access_tokens', 'devices', 'users', 'tenants', 'admin_users', 'panel_audit', 'subscription_payments'];

    protected function setUp(): void
    {
        parent::setUp();

        if (! self::$migrated) {
            // Owner (superuser) ile: tablolar + RLS policy'leri + grant'lar oluşturulur.
            Artisan::call('migrate:fresh', ['--database' => 'pgsql_owner', '--force' => true]);
            self::$migrated = true;
        }

        // Temiz durum: owner bağlantısıyla veri tablolarını boşalt (RLS'i meşru atlar, hesap-üstü).
        DB::connection('pgsql_owner')->statement(
            'TRUNCATE '.implode(', ', self::TABLES).' RESTART IDENTITY CASCADE'
        );
    }

    /**
     * Bir bayi (aktif) + patron/operator/kurye + bir cihaz oluşturur. Provizyon owner bağlamında
     * koşar (yeni tenant satırı WITH CHECK yüzünden app rolüyle eklenemez — yumurta-tavuk).
     *
     * @return array{tenant: Tenant, patron: User, operator: User, kurye: User, device: Device}
     */
    protected function makeTenant(string $prefix): array
    {
        return Provisioning::asOwner(function () use ($prefix) {
            $tenant = Tenant::factory()->active()->create([
                'name' => strtoupper($prefix).' Su Bayii',
            ]);

            $patron = User::factory()->patron()->create([
                'tenant_id' => $tenant->id,
                'name' => strtoupper($prefix).' Patron',
                'email' => "{$prefix}-patron@sipario.test",
            ]);
            $operator = User::factory()->operator()->create([
                'tenant_id' => $tenant->id,
                'name' => strtoupper($prefix).' Operator',
                'email' => "{$prefix}-operator@sipario.test",
            ]);
            $kurye = User::factory()->kurye()->create([
                'tenant_id' => $tenant->id,
                'name' => strtoupper($prefix).' Kurye',
                'email' => "{$prefix}-kurye@sipario.test",
            ]);

            $device = Device::factory()->create([
                'tenant_id' => $tenant->id,
                'user_id' => $patron->id,
            ]);

            return compact('tenant', 'patron', 'operator', 'kurye', 'device');
        });
    }

    /**
     * Verilen kullanıcı için GERÇEK bir Sanctum token'ı üretir ve token satırına tenant_id yazar
     * (üretimdeki login akışının yaptığı). Sanctum::actingAs KULLANMIYORUZ: o TransientToken
     * enjekte eder, token satırı olmaz, tenant_id taşımaz → ResolveTenantContext app.tenant_id
     * set edemez → kullanıcı RLS altında bulunamaz → 401. Token owner bağlamında yazılır
     * (personal_access_tokens RLS'e tabi değildir, ama User'ı yükleyebilmek için owner gerekir).
     */
    protected function tokenFor(User $user): string
    {
        return Provisioning::asOwner(function () use ($user) {
            $token = $user->createToken('test');
            $token->accessToken->forceFill(['tenant_id' => $user->tenant_id])->save();

            return $token->plainTextToken;
        });
    }

    /**
     * Authorization: Bearer başlığıyla JSON isteği kurar.
     *
     * forgetGuards KRİTİK: Laravel auth guard'ı çözülmüş kullanıcıyı örnekte önbellekler ve bu
     * örnek tek test içindeki istekler arası yaşar. Üretimde her istek ayrı süreçtir (önbellek yok);
     * testte guard'ı sıfırlamazsak bir sonraki istek ÖNCEKİ kullanıcıyı döndürür (ör. iptal edilmiş
     * token'la yapılan istek yine eski kullanıcıyı görür). Her istekten önce guard'ı unutup üretimin
     * "her istek taze çözer" davranışını taklit ediyoruz.
     */
    protected function asToken(string $token): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withHeader('Authorization', 'Bearer '.$token)
            ->withHeader('Accept', 'application/json');
    }

    /** Owner (RLS-atlayan) bağlamında bir kayıt sayısı/durum doğrulaması için yardımcı. */
    protected function asOwner(callable $fn): mixed
    {
        return Provisioning::asOwner($fn);
    }
}
