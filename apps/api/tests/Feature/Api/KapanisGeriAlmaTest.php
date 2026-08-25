<?php

namespace Tests\Feature\Api;

use App\Models\DayClosing;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * KAPANIŞI GERİ ALMA (kullanıcı kararı 2026-08-18: "patron hata yapabilir, kasayı kapattığında
 * yönetici şifresi ile geriye alabilir, hesapta düzeltme yapabilir").
 *
 * Kapanış bugüne kadar TEK YÖNLÜYDÜ: yanlış sayılmış nakit arşive KALICI donuyor, gün kilitli
 * kalıyordu. Geri alma, `day_closings`e yazılan TERS BİR SATIRdır ve `reverses_closing_id` ile
 * geri aldığı kaydı gösterir — `cash_handovers.reverses_handover_id` (2026-08-13) ve
 * `ledger_entries.reverses_entry_id` deseninin aynısı. GERÇEK SİLME YOK (kırmızı çizgi #2).
 *
 * Dosya DÖRT şeyi kilitler:
 *   ① geri alma uygulanır, kolon dolar ve `changes` ile DİĞER CİHAZA yayılır;
 *   ② başka bayinin kapanışına geri alma BAĞLANAMAZ (kırmızı çizgi #1);
 *   ③ aynı kapanış İKİ KEZ geri alınamaz — uygulayıcıdan da, veritabanından da;
 *   ④ geri almanın geri alınması YASAK — düzeltmenin yolu yeniden KAPATMAKTIR.
 */
class KapanisGeriAlmaTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function geri_alma_ters_satir_olarak_uygulanir_ve_changes_ile_yayilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $device = (string) Str::uuid7();

        $kapanis = $this->dayClosing([
            'scope' => 'day',
            'expected_cash_kurus' => 50000,
            'counted_cash_kurus' => 48000,
            'diff_kurus' => -2000,
        ], ['occurred_at' => '2026-08-18T18:00:00Z', 'device_id' => $device]);

        $this->pushEvents($token, [$kapanis])->assertJsonPath('results.0.status', 'applied');

        $imlec = (int) $this->pullSince($token, 0)->json('cursor');

        $geriAl = $this->dayClosing([
            'scope' => 'day',
            'reverses_closing_id' => $kapanis['payload']['id'],
            'note' => 'yanlis sayim, geri alindi',
        ], ['occurred_at' => '2026-08-18T18:10:00Z', 'device_id' => $device]);

        $this->pushEvents($token, [$geriAl])->assertOk()->assertJsonPath('results.0.status', 'applied');

        // ① Orijinal SİLİNMEZ, DEĞİŞMEZ — kanıt yerinde kalır.
        $satirlar = $this->asOwner(fn () => DayClosing::query()->orderBy('occurred_at')->get());
        $this->assertCount(2, $satirlar, 'Geri alma, orijinali silmez — ters satır olarak eklenir.');
        $this->assertNull($satirlar[0]->reverses_closing_id);
        $this->assertSame(48000, $satirlar[0]->counted_cash_kurus, 'Orijinal satır değişmemeli.');
        $this->assertSame($kapanis['payload']['id'], $satirlar[1]->reverses_closing_id);

        // ① (devam) YAYILMA — sunucuda doğru durup telefona inmeyen alan, o telefonda hiç
        // olmamış demektir: kurye/patron uygulamada günü hâlâ KAPALI görürdü.
        $degisiklikler = collect($this->pullSince($token, $imlec)->json('changes'))
            ->where('entity_type', 'day_closing')->values();
        $this->assertCount(1, $degisiklikler, 'Geri alma tek bir day_closing değişikliği yaymalı.');
        $this->assertSame($geriAl['payload']['id'], $degisiklikler[0]['entity_id']);
        $this->assertSame(
            $kapanis['payload']['id'],
            $degisiklikler[0]['payload']['reverses_closing_id'],
            'reverses_closing_id yayında taşınmalı — inmezse istemci ilişkiyi kuramaz.'
        );
    }

    #[Test]
    public function baska_bayinin_kapanisi_geri_alinamaz(): void
    {
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $device = (string) Str::uuid7();

        $bKapanis = $this->dayClosing(
            ['scope' => 'day'],
            ['occurred_at' => '2026-08-18T18:00:00Z', 'device_id' => $device]
        );
        $this->pushEvents($this->tokenFor($b['patron']), [$bKapanis])
            ->assertJsonPath('results.0.status', 'applied');

        // A, B'nin kapanışını geri almaya çalışır: RLS satırı GİZLER → "bulunamadı" reddi.
        $saldiri = $this->dayClosing([
            'scope' => 'day',
            'reverses_closing_id' => $bKapanis['payload']['id'],
        ], ['occurred_at' => '2026-08-18T18:05:00Z', 'device_id' => $device]);

        $this->pushEvents($this->tokenFor($a['patron']), [$saldiri])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'rejected');

        // B'nin kapanışı hâlâ GEÇERLİ: geri alınmış görünmemeli.
        $this->assertSame(
            0,
            $this->asOwner(fn () => DayClosing::query()
                ->where('reverses_closing_id', $bKapanis['payload']['id'])->count()),
            'B bayisinin kapanışı A tarafından geri alınmamalı.'
        );
    }

    #[Test]
    public function ayni_kapanis_iki_kez_geri_alinamaz(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $device = (string) Str::uuid7();

        $kapanis = $this->dayClosing(['scope' => 'day'],
            ['occurred_at' => '2026-08-18T18:00:00Z', 'device_id' => $device]);
        $this->pushEvents($token, [$kapanis])->assertJsonPath('results.0.status', 'applied');

        $ilk = $this->dayClosing([
            'scope' => 'day',
            'reverses_closing_id' => $kapanis['payload']['id'],
        ], ['occurred_at' => '2026-08-18T18:05:00Z', 'device_id' => $device]);
        $this->pushEvents($token, [$ilk])->assertJsonPath('results.0.status', 'applied');

        // Uygulayıcı kapısı: GÖRÜNÜR red (istemcide karantina), sessiz yutma değil.
        $ikinci = $this->dayClosing([
            'scope' => 'day',
            'reverses_closing_id' => $kapanis['payload']['id'],
        ], ['occurred_at' => '2026-08-18T18:06:00Z', 'device_id' => $device]);
        $this->pushEvents($token, [$ikinci])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'rejected');
    }

    #[Test]
    public function cift_geri_alma_veritabaninda_da_imkansiz(): void
    {
        // Uygulayıcı kapısı TEK BAŞINA YETMEZ: iki cihaz çevrimdışıyken aynı kapanışı geri alıp
        // aynı anda senkron olursa iki okuma da "henüz geri alma yok" görür (okuma-sonra-yaz
        // yarışı). Kısmi unique indeks o yarışı kapatır — bu test uygulayıcıyı ATLAYARAK
        // doğrudan veritabanına yazar, yani gerçekten DB'nin tuttuğunu kanıtlar.
        $a = $this->makeTenant('a');

        $this->asOwner(function () use ($a) {
            $hedef = (string) Str::uuid7();
            DB::table('day_closings')->insert([
                'id' => $hedef,
                'tenant_id' => $a['tenant']->id,
                'scope' => 'day',
                'occurred_at' => '2026-08-18T18:00:00Z',
            ]);

            $satir = fn () => [
                'id' => (string) Str::uuid7(),
                'tenant_id' => $a['tenant']->id,
                'scope' => 'day',
                'reverses_closing_id' => $hedef,
                'occurred_at' => '2026-08-18T18:05:00Z',
            ];

            DB::table('day_closings')->insert($satir());

            $this->expectException(QueryException::class);
            DB::table('day_closings')->insert($satir());
        });
    }

    #[Test]
    public function geri_almanin_geri_alinmasi_yasak(): void
    {
        // Ters satırın tersi "kapanış yeniden geçerli" demek olurdu ve arşivde aynı anda iki
        // geçerli kapanış görünürdü. Düzeltmenin yolu yeniden KAPATMAKTIR — eskiyi diriltmek
        // değil (append-only defterin genel kuralı).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $device = (string) Str::uuid7();

        $kapanis = $this->dayClosing(['scope' => 'day'],
            ['occurred_at' => '2026-08-18T18:00:00Z', 'device_id' => $device]);
        $this->pushEvents($token, [$kapanis])->assertJsonPath('results.0.status', 'applied');

        $geriAl = $this->dayClosing([
            'scope' => 'day',
            'reverses_closing_id' => $kapanis['payload']['id'],
        ], ['occurred_at' => '2026-08-18T18:05:00Z', 'device_id' => $device]);
        $this->pushEvents($token, [$geriAl])->assertJsonPath('results.0.status', 'applied');

        $tersinTersi = $this->dayClosing([
            'scope' => 'day',
            'reverses_closing_id' => $geriAl['payload']['id'],
        ], ['occurred_at' => '2026-08-18T18:06:00Z', 'device_id' => $device]);
        $this->pushEvents($token, [$tersinTersi])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'rejected');
    }

    #[Test]
    public function geri_alma_kapanisla_ayni_kapsamda_olmali(): void
    {
        // Gün kapanışını bir kurye kapanışıyla geri almak, arşivde birbirini işaret eden ama
        // aynı hesabı konuşmayan iki satır bırakırdı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $device = (string) Str::uuid7();

        $gun = $this->dayClosing(['scope' => 'day'],
            ['occurred_at' => '2026-08-18T18:00:00Z', 'device_id' => $device]);
        $this->pushEvents($token, [$gun])->assertJsonPath('results.0.status', 'applied');

        $yanlisKapsam = $this->dayClosing([
            'scope' => 'courier',
            'user_id' => $a['kurye']->id,
            'reverses_closing_id' => $gun['payload']['id'],
        ], ['occurred_at' => '2026-08-18T18:05:00Z', 'device_id' => $device]);

        $this->pushEvents($token, [$yanlisKapsam])
            ->assertOk()
            ->assertJsonPath('results.0.status', 'rejected');
    }
}
