<?php

namespace Tests\Feature\Api;

use Illuminate\Database\Connection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * KIRMIZI ÇİZGİ #1 — tasarım boşluğu tablolarında (migration 601–604, RLS 606) kiracı izolasyonu.
 *
 * Migration'a bakıp "politika var" demek YETMEZ: politika yanlış sütuna bağlanmış, FORCE unutulmuş
 * ya da GRANT fazla verilmiş olabilir. Bu dosya FİİLEN iki tenant bağlamı kurup sorgu atar.
 * RlsSafeDefaultTest'in deseni; app rolü (sipario_app, NOBYPASSRLS) bağlantısında koşar — owner ile
 * koşsaydı superuser RLS'i atlar ve test yeşil yanan bir yalan olurdu.
 */
class RlsDesignGapTest extends ApiTestCase
{
    /** @return list<array{string}> */
    public static function tasarimBoslugTablolari(): array
    {
        return [
            ['tenant_settings'],
            ['exempt_numbers'],
            ['call_logs'],
            ['day_closings'],
        ];
    }

    /** app rolü bağlantısı (RLS'e tabi). */
    private function appConn(): Connection
    {
        return DB::connection('pgsql');
    }

    /** Verilen tenant bağlamında bir kapanış çalıştırır (SET LOCAL transaction ömürlüdür). */
    private function baglamda(string $tenantId, callable $fn): mixed
    {
        return $this->appConn()->transaction(function () use ($tenantId, $fn) {
            $this->appConn()->statement("SELECT set_config('app.tenant_id', ?, true)", [$tenantId]);

            return $fn();
        });
    }

    /**
     * İki bayi + her birine o tablodan birer satır (owner ile, RLS üstü). Satırlar tabloya göre
     * asgari kolonlarla kurulur.
     *
     * @return array{0: array<string, mixed>, 1: array<string, mixed>, 2: string, 3: string}
     */
    private function ikiBayiVeSatir(string $table): array
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $satirA = $this->satirEkle($table, $a['tenant']->id);
        $satirB = $this->satirEkle($table, $b['tenant']->id);

        return [$a, $b, $satirA, $satirB];
    }

    /** Owner bağlamında tek satır ekler, birincil anahtarı döner. */
    private function satirEkle(string $table, string $tenantId): string
    {
        $id = (string) Str::uuid7();
        $now = now();

        $satir = match ($table) {
            'tenant_settings' => ['tenant_id' => $tenantId, 'business_name' => 'Bayi '.substr($tenantId, 0, 8)],
            'exempt_numbers' => [
                'id' => $id, 'tenant_id' => $tenantId,
                'phone_e164' => '+905321112233', 'phone_last10' => '5321112233',
            ],
            'call_logs' => [
                'id' => $id, 'tenant_id' => $tenantId,
                'phone_e164' => '+905324152290', 'phone_last10' => '5324152290',
                'direction' => 'incoming', 'occurred_at' => $now,
            ],
            'day_closings' => [
                'id' => $id, 'tenant_id' => $tenantId, 'scope' => 'day', 'occurred_at' => $now,
            ],
            default => throw new \InvalidArgumentException($table),
        };

        $this->asOwner(fn () => DB::connection('pgsql_owner')->table($table)
            ->insert($satir + ['created_at' => $now, 'updated_at' => $now]));

        return $table === 'tenant_settings' ? $tenantId : $id;
    }

    #[Test]
    #[DataProvider('tasarimBoslugTablolari')]
    public function baglam_kurulmadan_hicbir_satir_gorunmez(string $table): void
    {
        $this->ikiBayiVeSatir($table);

        // Güvenli varsayılan: app.tenant_id yoksa NULLIF → NULL → policy hiç eşleşmez.
        $this->assertSame(0, $this->appConn()->table($table)->count(), "{$table} bağlamsız sızdırıyor.");
    }

    #[Test]
    #[DataProvider('tasarimBoslugTablolari')]
    public function her_bayi_yalnizca_kendi_satirini_gorur(string $table): void
    {
        [$a, $b, $satirA, $satirB] = $this->ikiBayiVeSatir($table);
        $anahtar = $table === 'tenant_settings' ? 'tenant_id' : 'id';

        $gorunenA = $this->baglamda($a['tenant']->id, fn () => $this->appConn()->table($table)->pluck($anahtar)->all());
        $this->assertSame([$satirA], $gorunenA, "A, {$table} tablosunda yalnız kendi satırını görmeli.");

        $gorunenB = $this->baglamda($b['tenant']->id, fn () => $this->appConn()->table($table)->pluck($anahtar)->all());
        $this->assertSame([$satirB], $gorunenB, "B, {$table} tablosunda yalnız kendi satırını görmeli.");
    }

    #[Test]
    #[DataProvider('tasarimBoslugTablolari')]
    public function baska_bayinin_satiri_kimlikle_dogrudan_sorgulansa_da_bulunamaz(string $table): void
    {
        // Kimlik tahmini/sızması senaryosu: B'nin GERÇEK id'sini A bağlamında sormak sıfır satır döner.
        [$a, , , $satirB] = $this->ikiBayiVeSatir($table);
        $anahtar = $table === 'tenant_settings' ? 'tenant_id' : 'id';

        $bulunan = $this->baglamda(
            $a['tenant']->id,
            fn () => $this->appConn()->table($table)->where($anahtar, $satirB)->count()
        );

        $this->assertSame(0, $bulunan, "A, {$table} tablosunda B'nin satırını id ile bile göremez.");
    }

    #[Test]
    #[DataProvider('tasarimBoslugTablolari')]
    public function baska_bayinin_satiri_guncellenemez_veya_silinemez(string $table): void
    {
        // day_closings'te UPDATE/DELETE zaten 42501 ile reddedilir (append-only, migration 607);
        // diğerlerinde politika satırı görünmez kıldığı için 0 satır etkilenir. İki savunma da geçerli:
        // her iki durumda da B'nin satırı DEĞİŞMEZ — ölçtüğümüz budur.
        [$a, , , $satirB] = $this->ikiBayiVeSatir($table);
        $anahtar = $table === 'tenant_settings' ? 'tenant_id' : 'id';

        $this->baglamda($a['tenant']->id, function () use ($table, $anahtar, $satirB) {
            try {
                $etkilenen = $this->appConn()->table($table)->where($anahtar, $satirB)
                    ->update(['updated_at' => now()]);
                $this->assertSame(0, $etkilenen, "{$table}: A, B'nin satırını güncelleyememeli.");
            } catch (QueryException $e) {
                $this->assertSame('42501', $e->getCode()); // append-only REVOKE (day_closings)
            }
        });

        $this->baglamda($a['tenant']->id, function () use ($table, $anahtar, $satirB) {
            try {
                $silinen = $this->appConn()->table($table)->where($anahtar, $satirB)->delete();
                $this->assertSame(0, $silinen, "{$table}: A, B'nin satırını silememeli.");
            } catch (QueryException $e) {
                $this->assertSame('42501', $e->getCode());
            }
        });

        // Kanıt: B'nin satırı hâlâ yerinde (owner ile bak).
        $kalan = $this->asOwner(fn () => DB::connection('pgsql_owner')->table($table)
            ->where($anahtar, $satirB)->count());
        $this->assertSame(1, $kalan, "{$table}: B'nin satırı ayakta kalmalı.");
    }

    #[Test]
    #[DataProvider('tasarimBoslugTablolari')]
    public function yabanci_tenant_idsiyle_insert_with_check_ile_reddedilir(string $table): void
    {
        [$a, $b] = $this->ikiBayiVeSatir($table);

        try {
            $this->baglamda($a['tenant']->id, function () use ($table, $b) {
                $now = now();
                $satir = match ($table) {
                    // tenant_settings'te PK = tenant_id; B'nin satırı zaten var, çakışmayı değil
                    // POLİTİKAYI ölçmek için önce sil denemesi değil doğrudan INSERT denenir —
                    // WITH CHECK unique kontrolünden ÖNCE uygulanır.
                    'tenant_settings' => ['tenant_id' => $b['tenant']->id, 'business_name' => 'Ele geçirme'],
                    'exempt_numbers' => [
                        'id' => (string) Str::uuid7(), 'tenant_id' => $b['tenant']->id,
                        'phone_e164' => '+900000000000', 'phone_last10' => '0000000000',
                    ],
                    'call_logs' => [
                        'id' => (string) Str::uuid7(), 'tenant_id' => $b['tenant']->id,
                        'phone_e164' => '+900000000000', 'phone_last10' => '0000000000',
                        'direction' => 'incoming', 'occurred_at' => $now,
                    ],
                    'day_closings' => [
                        'id' => (string) Str::uuid7(), 'tenant_id' => $b['tenant']->id,
                        'scope' => 'day', 'occurred_at' => $now,
                    ],
                    default => throw new \InvalidArgumentException($table),
                };

                $this->appConn()->table($table)->insert($satir + ['created_at' => $now, 'updated_at' => $now]);
            });

            $this->fail("{$table}: yabancı tenant_id ile INSERT reddedilmeliydi (WITH CHECK).");
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode(), "{$table}: RLS policy ihlali (42501) beklenirdi.");
        }

        // B'nin tarafında fazladan satır oluşmadı.
        $sayi = $this->asOwner(fn () => DB::connection('pgsql_owner')->table($table)
            ->where('tenant_id', $b['tenant']->id)->count());
        $this->assertSame(1, $sayi, "{$table}: B'de yabancı yazımdan satır oluşmamalı.");
    }

    #[Test]
    #[DataProvider('tasarimBoslugTablolari')]
    public function tabloda_force_row_level_security_acik(string $table): void
    {
        // FORCE olmadan tablo SAHİBİ politikayı atlar. Uygulama owner'a düşerse (bakım scripti, hatalı
        // config) izolasyon sessizce kaybolurdu; katalogdan doğrudan doğrula.
        $row = $this->asOwner(fn () => DB::connection('pgsql_owner')->selectOne(
            'SELECT relrowsecurity, relforcerowsecurity FROM pg_class WHERE relname = ?',
            [$table]
        ));

        $this->assertTrue((bool) $row->relrowsecurity, "{$table}: ROW LEVEL SECURITY açık olmalı.");
        $this->assertTrue((bool) $row->relforcerowsecurity, "{$table}: FORCE ROW LEVEL SECURITY açık olmalı.");
    }
}
