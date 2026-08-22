<?php

namespace Tests\Feature\Api;

use App\Bildirim\PushOlayi;
use App\Jobs\PushGonderimi;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Support\Sync\EventValidator;
use Illuminate\Support\Facades\Bus;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * İPTAL ONAY AKIŞI — kurye TALEP açar, yönetici onaylar ya da reddeder (kullanıcı isteği
 * 2026-08-22).
 *
 * ══ SUNUCU TARAFINDA KİLİTLENEN İKİ ŞEY ═══════════════════════════════════════════════════
 *
 * 1. TALEP SİPARİŞİ İPTAL ETMEZ. Bu, özelliğin tamamıdır. `cancel_requested` yalnız bir olay
 *    ekler; `recomputeOrder` durumu hâlâ `cancelled`/`delivered`tan türetir. Talep siparişi
 *    kapatsaydı yöneticinin "Reddet" düğmesi geri alınamaz bir işi düzeltmeye çalışırdı ve bu
 *    depoda durum/para kayıtları geri alınmaz, telafi edilir.
 *
 * 2. BİLDİRİM DOĞRU KİŞİYE GİDER. Talep YÖNETİCİLERE (`aliciUserId === null`), ret ise
 *    TALEBİ AÇAN kuryeye. Reddin alıcısı yükte YOKTUR — olay geçmişinden türetilir; yanlış
 *    türetme, reddi hiç talep açmamış bir kuryeye gönderir.
 *
 * ⚠️ ONAYIN AYRI BİR OLAYI YOKTUR ve olmamalı: onaylanan talep siparişi gerçekten iptal eder,
 * yani `cancelled` doğar ve o zaten `SiparisIptal` dürtüsünü kuryeye gönderir.
 */
class IptalOnayAkisiTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /**
     * Bir sipariş açar ve kimliğini döndürür.
     *
     * @return array{0: string, 1: array<string, mixed>}
     */
    private function siparisAc(string $token): array
    {
        $siparis = $this->orderCreated([$this->line()]);
        $this->pushEvents($token, [$siparis])->assertOk();

        return [$siparis['payload']['order']['id'], $siparis];
    }

    #[Test]
    public function iptal_talebi_siparisi_acik_birakir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        $cevap = $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', [
                'order_id' => $siparisId,
                'requested_by_user_id' => $a['kurye']->id,
                'reason' => 'Müşteri vazgeçti',
            ]),
        ]);

        $cevap->assertOk();
        $this->assertSame('applied', $cevap->json('results.0.status'));

        $siparis = $this->asOwner(fn () => Order::query()->findOrFail($siparisId));
        $this->assertSame('open', $siparis->status,
            'TALEP İPTAL DEĞİLDİR — yönetici cevap verene kadar sipariş teslim edilebilir kalmalı');

        // ⚠️ `assertDatabaseHas` KULLANILMAZ: varsayılan bağlantı RLS altındadır ve test
        // sürecinde kiracı bağlamı YOKTUR (o, HTTP isteğinin `ResolveTenantContext`
        // katmanında kurulur ve istekle biter). Bağlamsız okuma "tablo boş" der — yani
        // iddia, olay gerçekten yazılmışken bile kırılır.
        $olaylar = $this->asOwner(fn () => OrderEvent::query()
            ->where('order_id', $siparisId)
            ->where('event_type', 'cancel_requested')
            ->count());
        $this->assertSame(1, $olaylar);
    }

    #[Test]
    public function ret_de_siparisi_acik_birakir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', [
                'order_id' => $siparisId,
                'requested_by_user_id' => $a['kurye']->id,
            ]),
            $this->orderEvent('cancel_rejected', ['order_id' => $siparisId]),
        ])->assertOk();

        $this->assertSame('open', $this->asOwner(fn () => Order::query()->findOrFail($siparisId))->status);
    }

    #[Test]
    public function onay_mevcut_cancelled_yolundan_gecer_ve_siparisi_iptal_eder(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', [
                'order_id' => $siparisId,
                'requested_by_user_id' => $a['kurye']->id,
            ]),
            $this->orderEvent('cancelled', ['order_id' => $siparisId]),
        ])->assertOk();

        $this->assertSame('cancelled', $this->asOwner(fn () => Order::query()->findOrFail($siparisId))->status);

        // Ayrı bir "onaylandı" olayı ÜRETİLMEZ: iptalin tek doğru kaydı `cancelled`tır.
        //
        // ⚠️ OKUMA `asOwner` İÇİNDE: test süreci kiracı bağlamı kurmaz (o, HTTP isteğinin
        // `ResolveTenantContext` katmanında kurulur ve istekle birlikte biter). Bağlamsız
        // okuma RLS altında BOŞ küme döner — yani iddia doğru sebepten değil, hiç satır
        // görülmediği için geçerdi.
        $this->assertSame(
            0,
            $this->asOwner(fn () => OrderEvent::query()
                ->where('order_id', $siparisId)
                ->where('event_type', 'like', '%approve%')
                ->count()),
        );
    }

    #[Test]
    public function baska_bayinin_kullanicisi_talebi_acamaz(): void
    {
        // Kırmızı çizgi #1. Kapı olmasaydı bir istemci başka bayinin kullanıcı kimliğini yüke
        // koyar ve reddi o kişiye bildirtebilirdi.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        $cevap = $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', [
                'order_id' => $siparisId,
                'requested_by_user_id' => $b['kurye']->id,
            ]),
        ]);

        $cevap->assertOk();
        $this->assertSame('rejected', $cevap->json('results.0.status'));
        $this->assertSame('open', $this->asOwner(fn () => Order::query()->findOrFail($siparisId))->status);
    }

    #[Test]
    public function talep_kimliksiz_de_acilabilir(): void
    {
        // Talebi açan cihazda oturum kimliği henüz inmemiş olabilir (`sync_meta.user_id` null).
        // Reddin duyurulamaması, talebin hiç açılamamasından iyidir.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        $cevap = $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', ['order_id' => $siparisId]),
        ]);

        $this->assertSame('applied', $cevap->json('results.0.status'));
    }

    #[Test]
    public function talep_yoneticilere_durtu_gonderir(): void
    {
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', [
                'order_id' => $siparisId,
                'requested_by_user_id' => $a['kurye']->id,
            ]),
        ])->assertOk();

        // `aliciUserId === null` = "bayinin yöneticileri". Belirli bir kişiye yollamak, o kişi
        // telefonuna bakmadığında kuryeyi müşterinin kapısında cevapsız bırakırdı.
        Bus::assertDispatched(
            PushGonderimi::class,
            fn (PushGonderimi $is) => $is->olay === PushOlayi::SiparisIptalTalebi
                && $is->varlikId === $siparisId
                && $is->aliciUserId === null,
        );
    }

    #[Test]
    public function ret_talebi_acan_kuryeye_gider(): void
    {
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', [
                'order_id' => $siparisId,
                'requested_by_user_id' => $a['kurye']->id,
            ]),
        ])->assertOk();

        $this->pushEvents($token, [
            $this->orderEvent('cancel_rejected', ['order_id' => $siparisId]),
        ])->assertOk();

        Bus::assertDispatched(
            PushGonderimi::class,
            fn (PushGonderimi $is) => $is->olay === PushOlayi::SiparisIptalReddedildi
                && $is->aliciUserId === $a['kurye']->id,
        );
    }

    #[Test]
    public function talebi_acan_bilinmiyorsa_ret_durtusu_hic_dogmaz(): void
    {
        // Reddi rastgele birine göndermek, hiç göndermemekten kötüdür.
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', ['order_id' => $siparisId]),
            $this->orderEvent('cancel_rejected', ['order_id' => $siparisId]),
        ])->assertOk();

        Bus::assertNotDispatched(
            PushGonderimi::class,
            fn (PushGonderimi $is) => $is->olay === PushOlayi::SiparisIptalReddedildi,
        );
    }

    #[Test]
    public function iki_kez_talep_acilirsa_ret_son_isteyene_gider(): void
    {
        // İlk talep reddedildi, kurye 2 yeniden istedi. Sıralama anahtarı (occurred_at, id)
        // yanlış olsaydı ret, hiç beklemeyen ilk kuryeye giderdi.
        Bus::fake();

        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        [$siparisId] = $this->siparisAc($token);

        // Aynı bayide ikinci bir kullanıcı — talebi ikinci kez o açıyor.
        $ikinciKurye = $a['operator'];

        $this->pushEvents($token, [
            $this->orderEvent('cancel_requested', [
                'order_id' => $siparisId,
                'requested_by_user_id' => $a['kurye']->id,
            ], ['occurred_at' => '2026-08-22T10:00:00.000Z']),
            $this->orderEvent('cancel_rejected', [
                'order_id' => $siparisId,
            ], ['occurred_at' => '2026-08-22T10:05:00.000Z']),
            $this->orderEvent('cancel_requested', [
                'order_id' => $siparisId,
                'requested_by_user_id' => $ikinciKurye->id,
            ], ['occurred_at' => '2026-08-22T10:30:00.000Z']),
        ])->assertOk();

        Bus::fake(); // buraya kadarki dürtüleri temizle
        $this->pushEvents($token, [
            $this->orderEvent('cancel_rejected', [
                'order_id' => $siparisId,
            ], ['occurred_at' => '2026-08-22T10:35:00.000Z']),
        ])->assertOk();

        Bus::assertDispatched(
            PushGonderimi::class,
            fn (PushGonderimi $is) => $is->olay === PushOlayi::SiparisIptalReddedildi
                && $is->aliciUserId === $ikinciKurye->id,
        );
    }

    #[Test]
    public function iki_yeni_op_da_sozlukte_taninir(): void
    {
        // `EventValidator::OPS` dışındaki bir op `unknown_op` ile reddedilir ve sahadaki
        // istemci sebebini hiç anlamaz. Sözlük, sözleşmenin kendisidir.
        $this->assertContains('cancel_requested', EventValidator::OPS);
        $this->assertContains('cancel_rejected', EventValidator::OPS);
    }

    #[Test]
    public function iki_olay_da_ayni_bildirim_kategorisini_tasir(): void
    {
        // Bayi için tek bir anahtar ("İptal onayı"); metni ayıran şey yükteki `olay` alanıdır.
        $this->assertSame('siparis_iptal_onayi', PushOlayi::SiparisIptalTalebi->kategori());
        $this->assertSame('siparis_iptal_onayi', PushOlayi::SiparisIptalReddedildi->kategori());
    }
}
