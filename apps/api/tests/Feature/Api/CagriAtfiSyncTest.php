<?php

namespace Tests\Feature\Api;

use App\Models\CallLog;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * ÇAĞRI ATFI (kullanıcı isteği 2026-08-13) — `call_logs.user_id`: çağrıyı KİM karşıladı.
 *
 * NEDEN GEREKTİ: patron ve izin verdiği kullanıcılar diğer kullanıcıların arama geçmişini
 * görebilmeli. Çağrı kayıtları ZATEN senkronlanıyordu ve ekran bayinin tüm çağrılarını
 * gösteriyordu — eksik olan tek şey ATIFTI. Tabloda yalnız `device_id` vardı ve o bir CİHAZI
 * anlatır, kişiyi değil: aynı telefonu iki kişi kullanabilir, kurye telefon değiştirince geçmiş
 * kopar.
 *
 * Bu dosya üç şeyi kilitler:
 *   ① atıf uygulanır ve `changes` ile DİĞER CİHAZA yayılır — yayılmayan atıf, patronun
 *      telefonunda hiç yok demektir ve özelliğin tamamı başkasının geçmişini görmek üzerine;
 *   ② BAŞKA BAYİNİN kullanıcısına atıf bağlanamaz (kırmızı çizgi #1) — koruma bileşik FK'dedir;
 *   ③ alanı GÖNDERMEYEN eski istemci bozulmaz (kolon nullable, atıf uydurulmaz).
 *
 * Damgalar UTC ('…Z') yazılır — gerekçesi için bkz. `AraTahsilatSyncTest` başlığı.
 */
class CagriAtfiSyncTest extends ApiTestCase
{
    use BuildsSyncEvents;

    #[Test]
    public function cagri_atfi_uygulanir_ve_changes_ile_yayilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $kayitId = (string) Str::uuid7();

        // İMLEÇ ÖNCE İLERLETİLİR: taze bayide imleç 0'dır ve sunucu 0'a SNAPSHOT döner. Asıl
        // sınamak istediğimiz DELTA yolu — patronun telefonuna kuryenin çağrısı o yoldan iner.
        $this->pushEvents($token, [$this->callLogUpsert()]);
        $imlec = (int) $this->pullSince($token, 0)->json('cursor');

        $cevap = $this->pushEvents($token, [
            $this->callLogUpsert([
                'id' => $kayitId,
                'phone_e164' => '+905324152290',
                'direction' => 'incoming',
                'user_id' => $a['kurye']->id,
            ], ['occurred_at' => '2026-08-13T09:15:00Z']),
        ]);

        $cevap->assertOk();
        $this->assertSame('applied', $cevap->json('results.0.status'));

        $satir = $this->asOwner(fn () => CallLog::query()->find($kayitId));
        $this->assertSame($a['kurye']->id, $satir->user_id,
            'atıf kaydedilmeli — "kim aradı" sorusunun tek dayanağı bu');

        // YAYIN: sunucuda doğru duran ama DİĞER CİHAZA inmeyen alan YOKTUR. Patronun telefonu
        // kuryenin çağrısını ancak delta ile görür; atıf o yükte taşınmazsa özellik yalnız
        // kaydı yazan telefonda var olur — yani hiç yok.
        $delta = $this->pullSince($token, $imlec);
        $delta->assertOk()->assertJsonPath('mode', 'delta');

        $cagriDegisimleri = collect($delta->json('changes'))
            ->where('entity_type', 'call_log')->values();
        $this->assertCount(1, $cagriDegisimleri);
        $this->assertSame($kayitId, $cagriDegisimleri[0]['entity_id']);
        $this->assertSame($a['kurye']->id, $cagriDegisimleri[0]['payload']['user_id'],
            'user_id senkron yükünde taşınmalı — yoksa atıf diğer cihaza HİÇ inmez');
    }

    #[Test]
    public function baska_bayinin_kullanicisina_atif_baglanamaz(): void
    {
        // KIRMIZI ÇİZGİ #1. Koruma bileşik FK'dedir: (tenant_id, user_id) → users (tenant_id, id).
        // B'nin kuryesinin kimliği A'nın kiracısında bulunamaz, FK 23503 verir ve o SQLSTATE
        // istemci-kaynaklı sayıldığı için PARTİ DÜŞMEZ — yalnız o olay reddedilir.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $token = $this->tokenFor($a['patron']);

        $cevap = $this->pushEvents($token, [
            $this->callLogUpsert(['user_id' => $b['kurye']->id]),
        ]);

        $cevap->assertOk();
        $this->assertSame('rejected', $cevap->json('results.0.status'),
            'başka bayinin kullanıcısına atıf bağlanamaz');
    }

    #[Test]
    public function alani_gondermeyen_eski_istemci_bozulmaz(): void
    {
        // Kolon NULLABLE ve atıf UYDURULMAZ: alanı bilmeyen bir sürüm kayıt yazmaya devam eder,
        // yalnız o satırın atfı boş kalır. `device_id`den kişiye geriye dönük eşleme yapmak,
        // o gün o cihazı kimin kullandığını VARSAYMAK olurdu.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $kayitId = (string) Str::uuid7();

        $cevap = $this->pushEvents($token, [
            $this->callLogUpsert(['id' => $kayitId]),
        ]);

        $cevap->assertOk();
        $this->assertSame('applied', $cevap->json('results.0.status'));
        $this->assertNull($this->asOwner(fn () => CallLog::query()->find($kayitId))->user_id);
    }
}
