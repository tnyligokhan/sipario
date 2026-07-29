<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\Order;
use App\Models\TenantSetting;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * SIRA NUMARALARI — müşteri kodu (102) ve sipariş kodu (#248). Kullanıcı isteği 2026-07-29.
 *
 * Sözleşmenin üç ayağı burada çivileniyor:
 *  1. Kodu SUNUCU atar, istemci ezemez (aynı `balance_kurus` deseni).
 *  2. Numaralar KİRACI İÇİNDE sıralıdır ve kiracılar birbirini etkilemez (kırmızı çizgi #1).
 *  3. Kod bir kez atandıktan sonra DEĞİŞMEZ — bayinin kâğıda yazdığı numara sabit kalmalı.
 */
class SiraKoduTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function musteri_kodlari_100den_baslar_ve_artar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Birinci'])])->assertOk();
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'İkinci'])])->assertOk();

        $kodlar = $this->asOwner(fn () => Customer::query()->orderBy('code')->pluck('code', 'name')->all());
        $this->assertSame(100, $kodlar['Birinci']);
        $this->assertSame(101, $kodlar['İkinci']);
    }

    #[Test]
    public function siparis_kodlari_da_100den_baslar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->orderCreated([$this->line()])])->assertOk();
        $this->pushEvents($token, [$this->orderCreated([$this->line()])])->assertOk();

        $this->assertSame([100, 101], $this->asOwner(fn () => Order::query()->orderBy('code')->pluck('code')->all()));
    }

    #[Test]
    public function istemci_kendi_kodunu_dayatamaz(): void
    {
        // Kod istemciden yazılabilir kolonlar listesinde YOKTUR. Olsaydı bir istemci hatası
        // (ya da kötü niyet) iki müşteriye aynı numarayı verdirebilir, kısmi unique indekse
        // çarpar ve olay reddedilirdi — yani kayıt kaybolmuş GİBİ görünürdü.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [
            $this->customerUpsert(['name' => 'Kod dayatan', 'code' => 5000]),
        ])->assertOk();

        $this->assertSame(100, $this->asOwner(fn () => Customer::query()->firstOrFail()->code));
    }

    #[Test]
    public function kod_ikinci_upsertte_degismez(): void
    {
        // Müşteri adı değiştirildiğinde kodun yeniden atanması, bayinin kâğıda yazdığı
        // numarayı geçersiz kılardı. Kod yalnız OLUŞTURMADA verilir.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $olay = $this->customerUpsert(['name' => 'İlk ad']);
        $this->pushEvents($token, [$olay])->assertOk();
        $id = $olay['payload']['id'];

        $this->pushEvents($token, [
            $this->customerUpsert([
                'id' => $id,
                'name' => 'Düzeltilmiş ad',
            ], ['occurred_at' => now()->addMinute()->toIso8601String()]),
        ])->assertOk();

        $musteri = $this->asOwner(fn () => Customer::query()->findOrFail($id));
        $this->assertSame('Düzeltilmiş ad', $musteri->name);
        $this->assertSame(100, $musteri->code);
    }

    #[Test]
    public function kodlar_kiraci_icinde_sayilir(): void
    {
        // Kırmızı çizgi #1: iki bayi birbirinin numarasını görmez ve ETKİLEMEZ. İkisi de
        // kendi 100'ünden başlar; ortak bir sayaç olsaydı bir bayinin yoğun günü diğerinin
        // numaralarını ileri atardı ("dün 105'teydik, bugün 480'iz").
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $this->pushEvents($this->tokenFor($a['patron']), [$this->customerUpsert(['name' => 'A-1'])])->assertOk();
        $this->pushEvents($this->tokenFor($a['patron']), [$this->customerUpsert(['name' => 'A-2'])])->assertOk();
        $this->pushEvents($this->tokenFor($b['patron']), [$this->customerUpsert(['name' => 'B-1'])])->assertOk();

        $kod = fn (string $ad) => $this->asOwner(
            fn () => Customer::query()->where('name', $ad)->firstOrFail()->code
        );
        $this->assertSame(100, $kod('B-1'));
        $this->assertSame(101, $kod('A-2'));
    }

    #[Test]
    public function kod_senkron_yaniyla_istemciye_doner(): void
    {
        // İstemci kodu kendisi üretmediği için tek öğrenme yolu senkrondur; payload'da
        // gelmezse mobil liste sonsuza dek kodsuz kalırdı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Kodlu'])])->assertOk();
        $this->pushEvents($token, [$this->orderCreated([$this->line()])])->assertOk();

        $snap = $this->pullSince($token, 0);
        $snap->assertOk();
        $this->assertSame(100, collect($snap->json('entities.customer'))->first()['code']);
        $this->assertSame(100, collect($snap->json('entities.order'))->first()['code']);

        // DELTA da kodu taşımalı — ASIL SAHA HATASI BURADAYDI (2026-07-29): kurulu bir cihaz
        // ilk snapshot'tan sonra YALNIZ delta çeker. Kod sunucuda doğru dursa bile deltaya
        // düşmezse telefonda HİÇ görünmez ve hiçbir hata üretmez. Snapshot'ı sınamak yetmez.
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Sonradan gelen'])])->assertOk();
        $delta = $this->pullSince($token, 1);
        $delta->assertOk();
        $delta->assertJsonPath('mode', 'delta');
        $kodlar = collect($delta->json('changes'))
            ->where('entity_type', 'customer')
            ->pluck('payload.code');
        $this->assertTrue($kodlar->filter()->isNotEmpty(), 'delta yükünde kod YOK');
    }

    #[Test]
    public function siparis_kodu_ayari_beyaz_listeye_tabidir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [
            $this->tenantSettingsUpsert(['order_code_display' => 'siparis']),
        ])->assertOk();
        $this->assertSame('siparis', $this->asOwner(fn () => TenantSetting::query()->firstOrFail()->order_code_display));

        // Tanınmayan değer sessizce varsayılana düşer: kararı okuyan mobil yüzeyler
        // bilinmeyen bir dala girmemeli (istemci sürümleri ayrışabilir).
        $this->pushEvents($token, [
            $this->tenantSettingsUpsert(
                ['order_code_display' => 'uydurma'],
                ['occurred_at' => now()->addMinute()->toIso8601String()],
            ),
        ])->assertOk();
        $this->assertSame('musteri', $this->asOwner(fn () => TenantSetting::query()->firstOrFail()->order_code_display));
    }
}
