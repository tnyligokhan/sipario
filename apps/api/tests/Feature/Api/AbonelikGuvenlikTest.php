<?php

namespace Tests\Feature\Api;

use App\Enums\TenantStatus;
use App\Models\Customer;
use App\Models\Tenant;
use App\Support\Provisioning;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * 2026-08-04 vardiyasının abonelik/panel genişlemesi — YAZILMAMIŞ testler (vardiya devir notu).
 *
 * Kapsam:
 *  - İzin matrisi: sipario_app YENİ 6 tabloyu hiç göremez, sipario_panel yalnız SELECT alır.
 *  - Append-only: addon_grants/tenant_notes güncellenemez/silinemez (panel bağlantısıyla).
 *  - RLS izolasyonu: addon_grants/tenant_notes/payment_notifications cross-tenant (kırmızı çizgi #1).
 *  - `plans` tek satır kısıtı.
 *  - `cancelled` durumu: giriş 403, SyncService::push → locked, offline kayıt (locked_at öncesi) kabul.
 */
class AbonelikGuvenlikTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private const YENI_TABLOLAR = [
        'plans', 'addon_packages', 'addon_grants', 'expenses', 'tenant_notes', 'payment_notifications',
    ];

    private const KIRACI_KAPSAMLI_TABLOLAR = ['addon_grants', 'tenant_notes', 'payment_notifications'];

    // --- İzin matrisi ----------------------------------------------------------------------

    #[Test]
    public function sipario_app_yeni_abonelik_tablolarini_hic_goremez(): void
    {
        // 005010: REVOKE ALL ... FROM sipario_app. Uygulama rolü bu tablolara SELECT bile atamaz.
        foreach (self::YENI_TABLOLAR as $tablo) {
            try {
                DB::connection('pgsql')->table($tablo)->count();
                $this->fail("{$tablo}: sipario_app SELECT atamamalıydı.");
            } catch (QueryException $e) {
                $this->assertSame('42501', $e->getCode(), "{$tablo}: permission denied (42501) beklenir.");
            }
        }
    }

    #[Test]
    public function sipario_panel_yeni_abonelik_tablolarinda_yalniz_select_alir(): void
    {
        foreach (self::YENI_TABLOLAR as $tablo) {
            // SELECT çalışır (0 satır dönse de sorgu izin hatası vermemeli).
            DB::connection('pgsql_panel')->table($tablo)->count();
            $this->assertTrue(true);

            // Yazma yolları 42501 ile reddedilir (INSERT sözdizimi bilerek eksik değil: DEFAULT VALUES
            // panel rolünün kolon listesi bilgisine ihtiyaç duymadan izin katmanını sınar).
            try {
                DB::connection('pgsql_panel')->statement("INSERT INTO {$tablo} DEFAULT VALUES");
                $this->fail("{$tablo}: sipario_panel INSERT atamamalıydı.");
            } catch (QueryException $e) {
                $this->assertSame('42501', $e->getCode(), "{$tablo}: INSERT için 42501 beklenir.");
            }

            try {
                DB::connection('pgsql_panel')->statement("UPDATE {$tablo} SET id = id");
                $this->fail("{$tablo}: sipario_panel UPDATE atamamalıydı.");
            } catch (QueryException $e) {
                $this->assertSame('42501', $e->getCode(), "{$tablo}: UPDATE için 42501 beklenir.");
            }
        }
    }

    // --- Append-only: addon_grants + tenant_notes -------------------------------------------

    #[Test]
    public function addon_grants_ve_tenant_notes_guncellenemez_ve_silinemez(): void
    {
        // Panel yalnız SELECT alır (yukarıdaki test), yani UPDATE/DELETE zaten 42501 ile reddedilir.
        // Burada AYRICA gerçek satır üzerinde deniyoruz: "reddedilen istek satırı hiç etkilemedi" kanıtı.
        $a = $this->makeTenant('a');
        $grantId = $this->asOwner(fn () => DB::connection('pgsql_owner')->table('addon_grants')->insertGetId([
            'id' => (string) Str::uuid7(), 'tenant_id' => $a['tenant']->id,
            'package_name' => 'Test Paketi', 'type' => 'credits', 'quantity' => 100,
            'amount_kurus' => 0, 'collection_method' => 'bedelsiz',
            'granted_on' => now()->toDateString(), 'created_at' => now(),
        ], 'id'));

        $noteId = $this->asOwner(fn () => DB::connection('pgsql_owner')->table('tenant_notes')->insertGetId([
            'id' => (string) Str::uuid7(), 'tenant_id' => $a['tenant']->id,
            'body' => 'İlk not.', 'created_at' => now(),
        ], 'id'));

        foreach (['addon_grants' => $grantId, 'tenant_notes' => $noteId] as $tablo => $id) {
            try {
                DB::connection('pgsql_panel')->table($tablo)->where('id', $id)->update(['id' => $id]);
                $this->fail("{$tablo}: panel UPDATE atamamalıydı.");
            } catch (QueryException $e) {
                $this->assertSame('42501', $e->getCode());
            }

            try {
                DB::connection('pgsql_panel')->table($tablo)->where('id', $id)->delete();
                $this->fail("{$tablo}: panel DELETE atamamalıydı.");
            } catch (QueryException $e) {
                $this->assertSame('42501', $e->getCode());
            }
        }

        // Satırlar yerinde: reddedilen denemeler hiçbir şeyi değiştirmedi.
        $this->assertSame(1, $this->asOwner(fn () => DB::connection('pgsql_owner')->table('addon_grants')->where('id', $grantId)->count()));
        $this->assertSame(1, $this->asOwner(fn () => DB::connection('pgsql_owner')->table('tenant_notes')->where('id', $noteId)->count()));
    }

    // --- RLS izolasyonu: addon_grants / tenant_notes / payment_notifications --------------

    /**
     * `sipario_app`in bu üç tabloda hiçbir izni yok (005010) — izolasyonun BUGÜNKÜ gerçek kanıtı
     * budur. Ama politikanın kendisi de yanlış kurulmuş olabilir (yanlış sütun, FORCE unutulmuş)
     * ve bunu görmenin tek yolu geçici bir GRANT ile fiilen sorgu atmaktır (brief: "app rolüne
     * geçici GRANT verip politikayı kanıtla"). Grant/revoke bloğu try/finally: test başarısız da
     * olsa yetki fazlası sonraki testlere SIZMAZ.
     */
    #[Test]
    public function addon_grants_tenant_notes_payment_notifications_cross_tenant_izole(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $grantA = $this->satirEkle('addon_grants', $a['tenant']->id);
        $grantB = $this->satirEkle('addon_grants', $b['tenant']->id);
        $noteA = $this->satirEkle('tenant_notes', $a['tenant']->id);
        $noteB = $this->satirEkle('tenant_notes', $b['tenant']->id);
        $bildirimA = $this->satirEkle('payment_notifications', $a['tenant']->id);
        $bildirimB = $this->satirEkle('payment_notifications', $b['tenant']->id);

        $tablolar = self::KIRACI_KAPSAMLI_TABLOLAR;

        DB::connection('pgsql_owner')->statement('GRANT SELECT ON '.implode(', ', $tablolar).' TO sipario_app');

        try {
            $gorulenA = DB::connection('pgsql')->transaction(function () use ($a) {
                DB::connection('pgsql')->statement("SELECT set_config('app.tenant_id', ?, true)", [$a['tenant']->id]);

                return [
                    'addon_grants' => DB::connection('pgsql')->table('addon_grants')->pluck('id')->all(),
                    'tenant_notes' => DB::connection('pgsql')->table('tenant_notes')->pluck('id')->all(),
                    'payment_notifications' => DB::connection('pgsql')->table('payment_notifications')->pluck('id')->all(),
                ];
            });

            $this->assertSame([$grantA], $gorulenA['addon_grants'], 'A yalnız kendi addon_grants satırını görmeli.');
            $this->assertSame([$noteA], $gorulenA['tenant_notes'], 'A yalnız kendi tenant_notes satırını görmeli.');
            $this->assertSame([$bildirimA], $gorulenA['payment_notifications'], 'A yalnız kendi payment_notifications satırını görmeli.');

            // B'nin gerçek id'siyle A bağlamında doğrudan sorgu da 0 satır döner (kimlik tahmini korunur).
            $bulunanB = DB::connection('pgsql')->transaction(function () use ($grantB, $a) {
                DB::connection('pgsql')->statement("SELECT set_config('app.tenant_id', ?, true)", [$a['tenant']->id]);

                return DB::connection('pgsql')->table('addon_grants')->where('id', $grantB)->count();
            });
            $this->assertSame(0, $bulunanB, 'A, B\'nin addon_grants satırını id ile bile görememeli.');
        } finally {
            DB::connection('pgsql_owner')->statement('REVOKE SELECT ON '.implode(', ', $tablolar).' FROM sipario_app');
        }
    }

    #[Test]
    public function kiraci_kapsamli_yeni_tablolarda_force_row_level_security_acik(): void
    {
        foreach (self::KIRACI_KAPSAMLI_TABLOLAR as $tablo) {
            $row = $this->asOwner(fn () => DB::connection('pgsql_owner')->selectOne(
                'SELECT relrowsecurity, relforcerowsecurity FROM pg_class WHERE relname = ?',
                [$tablo]
            ));

            $this->assertTrue((bool) $row->relrowsecurity, "{$tablo}: ROW LEVEL SECURITY açık olmalı.");
            $this->assertTrue((bool) $row->relforcerowsecurity, "{$tablo}: FORCE ROW LEVEL SECURITY açık olmalı.");
        }
    }

    /** Owner bağlamında asgari kolonlarla bir satır ekler, birincil anahtarı döner. */
    private function satirEkle(string $table, string $tenantId): string
    {
        $id = (string) Str::uuid7();
        $now = now();

        $satir = match ($table) {
            'addon_grants' => [
                'id' => $id, 'tenant_id' => $tenantId, 'package_name' => 'Test Paketi',
                'type' => 'credits', 'quantity' => 100, 'amount_kurus' => 0,
                'collection_method' => 'bedelsiz', 'granted_on' => $now->toDateString(), 'created_at' => $now,
            ],
            'tenant_notes' => [
                'id' => $id, 'tenant_id' => $tenantId, 'body' => 'Test notu.', 'created_at' => $now,
            ],
            'payment_notifications' => [
                'id' => $id, 'tenant_id' => $tenantId, 'amount_kurus' => 59900, 'method' => 'iban',
                'reference_code' => 'REF-'.substr($id, 0, 8), 'declared_on' => $now->toDateString(),
                'status' => 'pending', 'created_at' => $now,
            ],
            default => throw new \InvalidArgumentException($table),
        };

        $this->asOwner(fn () => DB::connection('pgsql_owner')->table($table)->insert($satir));

        return $id;
    }

    // --- plans tek satır -------------------------------------------------------------------

    #[Test]
    public function plans_tek_satir_ikinci_insert_reddedilir(): void
    {
        // Migration zaten bir satır eker (tohum); ikinci INSERT tekil indeks ((true)) ile 23505 alır.
        try {
            DB::connection('pgsql_owner')->table('plans')->insert([
                'id' => (string) Str::uuid7(), 'name' => 'İkinci Plan',
                'price_monthly_kurus' => 1, 'price_yearly_kurus' => 1,
                'trial_days' => 1, 'route_credits_monthly' => 1, 'courier_limit' => 1,
                'updated_at' => now(),
            ]);
            $this->fail('plans: ikinci satır reddedilmeliydi (tek satır kısıtı).');
        } catch (QueryException $e) {
            $this->assertSame('23505', $e->getCode(), 'plans_single_row tekil indeksi ihlal beklenir.');
        }

        $this->assertSame(1, DB::connection('pgsql_owner')->table('plans')->count());
    }

    // --- cancelled durumu ---------------------------------------------------------------

    #[Test]
    public function iptal_edilmis_bayi_girisi_403_verir(): void
    {
        $a = $this->makeTenant('a');
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)->update([
            'status' => TenantStatus::Cancelled->value,
        ]));

        $yanit = $this->postJson('/api/v1/auth/login', $this->girisGovdesi($a['tenant'], $a['patron']));

        $yanit->assertStatus(403);
        $this->assertStringNotContainsString('iptal', mb_strtolower($yanit->json('message') ?? ''),
            'Mesaj nötr olmalı (iptal sebebini sızdırmadan).');
    }

    #[Test]
    public function iptal_edilmis_bayide_kilit_sonrasi_yazim_locked_bekleyen_offline_yazim_uygulanir(): void
    {
        // BRIEF kırmızı çizgi #5: abonelik bitse/iptal olsa bile veri durur; bekleyen (locked_at'ten
        // ÖNCEKİ) offline kayıt yine kabul edilir. cancelled, writesLocked() üzerinden suspended/locked
        // ile AYNI kod yolunu kullanır (App\Enums\TenantStatus) — burada AYRI ve isimlendirilmiş kanıt.
        $a = $this->makeTenant('a');
        $lockedAt = now()->subMinutes(5);
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)->update([
            'status' => TenantStatus::Cancelled->value,
            'locked_at' => $lockedAt,
        ]));
        $token = $this->tokenFor($a['patron']);

        $bekleyen = $this->customerUpsert(['name' => 'İptalden Önce Birikmiş'], ['occurred_at' => now()->subMinutes(10)->toIso8601String()]);
        $yeni = $this->customerUpsert(['name' => 'İptalden Sonra Yeni'], ['occurred_at' => now()->toIso8601String()]);

        $response = $this->pushEvents($token, [$bekleyen, $yeni]);
        $response->assertOk();
        $response->assertJsonPath('results.0.status', 'applied');
        $response->assertJsonPath('results.1.status', 'locked');
        $response->assertJsonPath('subscription.status', 'cancelled');

        $isimler = $this->asOwner(fn () => Customer::query()->pluck('name')->all());
        $this->assertSame(['İptalden Önce Birikmiş'], $isimler, 'Yalnız bekleyen (locked_at öncesi) kayıt uygulanmalı.');
    }

    #[Test]
    public function iptal_edilmis_bayide_pull_asla_kilitlenmez(): void
    {
        $a = $this->makeTenant('a');
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($a['tenant']->id)->update([
            'status' => TenantStatus::Cancelled->value,
            'locked_at' => now()->subMinutes(5),
        ]));
        $token = $this->tokenFor($a['patron']);

        // Login kapalı olsa da GEÇERLİ bir token'la okuma kilitlenmez — veri rehin alınmaz.
        $snap = $this->pullSince($token, 0);
        $snap->assertOk();
        $snap->assertJsonPath('subscription.status', 'cancelled');
    }
}
