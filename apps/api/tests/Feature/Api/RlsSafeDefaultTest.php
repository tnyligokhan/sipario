<?php

namespace Tests\Feature\Api;

use Illuminate\Database\Connection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * RLS güvenli varsayılanı DB seviyesinde kanıtlar (DECISIONS: app.tenant_id set edilmemişse
 * sorgu sıfır satır döner). HTTP katmanını atlar — doğrudan app rolü (sipario_app, NOBYPASSRLS)
 * bağlantısıyla sorgular. Bu testin geçerli olması sipario_app'in superuser/BYPASSRLS OLMAMASINA
 * bağlıdır; owner ile koşulsaydı FORCE'a rağmen superuser RLS'i atlar ve test yeşil yanan bir
 * yalan olurdu.
 */
class RlsSafeDefaultTest extends ApiTestCase
{
    /** app rolü bağlantısı. Testler zaten bununla koşar; niyeti açık kılmak için sabitliyoruz. */
    private function app_conn(): Connection
    {
        return DB::connection('pgsql');
    }

    #[Test]
    public function baglam_set_edilmeden_sorgu_sifir_satir_dondurur(): void
    {
        // Owner ile gerçek veri var; app rolü bağlam olmadan HİÇBİRİNİ görmemeli.
        $this->makeTenant('a');
        $this->makeTenant('b');

        // Bağlam yok (app.tenant_id set edilmedi) → NULLIF(...,'')::uuid = NULL → policy hiç eşleşmez.
        $this->assertSame(0, $this->app_conn()->table('tenants')->count());
        $this->assertSame(0, $this->app_conn()->table('users')->count());
        $this->assertSame(0, $this->app_conn()->table('devices')->count());
    }

    #[Test]
    public function bos_string_baglam_da_sifir_satir_dondurur(): void
    {
        $this->makeTenant('a');

        $rows = $this->app_conn()->transaction(function () {
            // Boş string set → NULLIF ile NULL → sıfır satır (kötü niyetli/eksik set'e karşı güvenli).
            $this->app_conn()->statement("SELECT set_config('app.tenant_id', '', true)");

            return $this->app_conn()->table('users')->count();
        });

        $this->assertSame(0, $rows);
    }

    #[Test]
    public function var_olmayan_tenant_baglami_sifir_satir_dondurur(): void
    {
        $this->makeTenant('a');
        $ghost = (string) Str::uuid7();

        $rows = $this->app_conn()->transaction(function () use ($ghost) {
            $this->app_conn()->statement("SELECT set_config('app.tenant_id', ?, true)", [$ghost]);

            return $this->app_conn()->table('users')->count();
        });

        $this->assertSame(0, $rows);
    }

    #[Test]
    public function dogru_baglam_yalnizca_o_tenantin_satirlarini_dondurur(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        // A bağlamı → yalnız A'nın kullanıcıları/cihazları.
        [$aUsers, $aDevices] = $this->app_conn()->transaction(function () use ($a) {
            $this->app_conn()->statement("SELECT set_config('app.tenant_id', ?, true)", [$a['tenant']->id]);

            return [
                $this->app_conn()->table('users')->pluck('tenant_id')->unique()->values()->all(),
                $this->app_conn()->table('devices')->pluck('tenant_id')->unique()->values()->all(),
            ];
        });
        $this->assertSame([$a['tenant']->id], $aUsers);
        $this->assertSame([$a['tenant']->id], $aDevices);

        // B bağlamı → yalnız B.
        $bUsers = $this->app_conn()->transaction(function () use ($b) {
            $this->app_conn()->statement("SELECT set_config('app.tenant_id', ?, true)", [$b['tenant']->id]);

            return $this->app_conn()->table('users')->pluck('tenant_id')->unique()->values()->all();
        });
        $this->assertSame([$b['tenant']->id], $bUsers);
    }

    #[Test]
    public function with_check_baska_tenanta_insert_reddeder(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        // Bağlam A iken tenant_id=B ile INSERT → WITH CHECK ihlali (SQLSTATE 42501).
        try {
            $this->app_conn()->transaction(function () use ($a, $b) {
                $this->app_conn()->statement("SELECT set_config('app.tenant_id', ?, true)", [$a['tenant']->id]);

                $this->app_conn()->table('devices')->insert([
                    'id' => (string) Str::uuid7(),
                    'tenant_id' => $b['tenant']->id, // yabancı tenant → policy WITH CHECK reddeder
                    'platform' => 'android',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            });

            $this->fail('Yabancı tenant_id ile INSERT reddedilmeliydi (WITH CHECK).');
        } catch (QueryException $e) {
            // 42501 = insufficient_privilege / RLS policy violation.
            $this->assertSame('42501', $e->getCode(), 'RLS policy ihlali beklenirdi.');
        }
    }

    #[Test]
    public function baglam_transaction_bitince_sizmaz(): void
    {
        $a = $this->makeTenant('a');

        // Bir transaction içinde A bağlamı kur, sorgula.
        $inside = $this->app_conn()->transaction(function () use ($a) {
            $this->app_conn()->statement("SELECT set_config('app.tenant_id', ?, true)", [$a['tenant']->id]);

            return $this->app_conn()->table('users')->count();
        });
        $this->assertGreaterThan(0, $inside);

        // Transaction bittikten SONRA (SET LOCAL kapsamı dışı) tekrar sorgu → sıfır (güvenli varsayılan).
        $this->assertSame(0, $this->app_conn()->table('users')->count());
    }
}
