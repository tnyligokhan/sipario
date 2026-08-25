<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\LedgerEntry;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * SAHA GİDERİ — `entry_type = 'expense'` sunucu sözleşmesi (kullanıcı isteği 2026-08-25:
 * *"bu sayfada Gider Ekleme özelliği de olmalı"*).
 *
 * GİDERİN TEK AYIRT EDİCİ ÖZELLİĞİ: kasadan ÇIKAN nakittir. Öbür tiplerin hepsi bir MÜŞTERİ
 * BORCUNU değiştirirken gider hiçbir borca dokunmaz — dokunsaydı bayinin benzin parası, rastgele
 * bir müşterinin borcuna eklenirdi. Bu dosya o ayrımın sunucuda tuttuğunu kanıtlar.
 *
 * Kasa ölçütü ENUM SAYMAZ, değişmezi kullanır: "payment_type taşıyan kayıt kasaya dokundu"
 * (DECISIONS Faz 3). Gider bu değişmezin İÇİNDEDİR ve olması gereken de budur: taşımasaydı kasa
 * sorguları onu hiç görmez ve çekmeceden çıkan para görünmez bir kayda dönerdi.
 */
class LedgerExpenseTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private const GIDER = 20000; // 200,00 ₺ benzin

    #[Test]
    public function gider_kasadan_duser_ve_hicbir_borca_dokunmaz(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Borcu Değişmeyen']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // Müşteriden 300,00 ₺ nakit tahsilat.
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'payment',
            'amount_kurus' => -30000, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'applied');

        // Kasadan 200,00 ₺ benzin çıktı — MÜŞTERİSİZ.
        $this->pushEvents($token, [$this->ledgerEntry([
            'entry_type' => 'expense', 'amount_kurus' => self::GIDER,
            'payment_type' => 'nakit', 'note' => 'Yakıt',
        ])])->assertJsonPath('results.0.status', 'applied',
            'expense CHECK kısıtında yoksa olay reddedilir ve gider sessizce kaybolurdu');

        // KASA = payment_type taşıyan kayıtların toplamı; gider onu 200,00 ₺ AZALTIR.
        // (İşaret kuralı: kasaya giren = −amount_kurus. Tahsilat −30000 → +30000 girdi;
        //  gider +20000 → −20000 çıktı. Net kasa katkısı 10.000 kuruş = 100,00 ₺.)
        $kasa = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->whereNotNull('payment_type')->sum('amount_kurus'));
        $this->assertSame(-10000, $kasa, 'çekmecede 100,00 ₺ kalmalı');

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(-30000, $balance,
            'gider MÜŞTERİ BORCUNA DOKUNMAZ — yalnız tahsilatın etkisi görünür');
    }

    #[Test]
    public function gider_musteriye_baglanamaz(): void
    {
        // Tüm entry_type'lar borç-deltası taşır ve `applyLedger` bakiyeyi DEFTERDEN yeniden kurar.
        // Müşterili bir gider, o müşterinin borcunu benzin parası kadar ŞİŞİRİRDİ — tek bir alan
        // unutulduğunda sessizce yanlış bakiye üreten türden bir hata; kapı o yüzden sunucuda.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Yanlışlıkla Bağlanan']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'expense',
            'amount_kurus' => self::GIDER, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'rejected');

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(0, $balance, 'reddedilen kayıt bakiyeye hiç dokunmaz');
    }

    #[Test]
    public function gider_yalniz_nakit_olabilir(): void
    {
        // v1 KARARI: bu özelliğin sorusu "ÇEKMECEDE ne kalmalı"dır ve karttan ödenen bir masraf
        // çekmeceye dokunmaz. `payment_type` HİÇ verilmemesi de reddedilir — o hâlde kayıt kasa
        // sorgularına girmez ve gider görünmez bir satıra dönerdi.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        foreach (['kart', 'havale'] as $tip) {
            $this->pushEvents($token, [$this->ledgerEntry([
                'entry_type' => 'expense', 'amount_kurus' => self::GIDER, 'payment_type' => $tip,
            ])])->assertJsonPath('results.0.status', 'rejected');
        }

        $this->pushEvents($token, [$this->ledgerEntry([
            'entry_type' => 'expense', 'amount_kurus' => self::GIDER,
        ])])->assertJsonPath('results.0.status', 'rejected',
            'payment_type taşımayan gider kasaya hiç dokunmazdı');

        $sayi = $this->asOwner(fn () => LedgerEntry::query()->count());
        $this->assertSame(0, $sayi, 'reddedilen kayıt deftere hiç girmez');
    }

    #[Test]
    public function gider_pozitif_yazilir_iptali_negatif(): void
    {
        // İşaret öbür tiplerin TERSİDİR ve bu bilinçli: gider kasadan ÇIKAN paradır. Negatif bir
        // "gider" ise ancak bir İPTALDİR ve `reverses_entry_id` taşımak zorundadır — serbest
        // bırakmak, iptal adı altında kasaya para eklemenin yolunu açardı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->ledgerEntry([
            'entry_type' => 'expense', 'amount_kurus' => -self::GIDER, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'rejected',
            'ters çevirdiği kayıt belli olmayan negatif gider kabul edilmez');

        $this->pushEvents($token, [$this->ledgerEntry([
            'entry_type' => 'expense', 'amount_kurus' => 0, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'rejected', 'sıfır tutarlı gider bir olay değildir');

        $sayi = $this->asOwner(fn () => LedgerEntry::query()->count());
        $this->assertSame(0, $sayi);
    }

    #[Test]
    public function gider_iptali_ters_satirdir_ve_tutari_tam_tersi_olmali(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $giderId = (string) Str::uuid7();
        $this->pushEvents($token, [$this->ledgerEntry([
            'id' => $giderId, 'entry_type' => 'expense',
            'amount_kurus' => self::GIDER, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'applied');

        // FARKLI tutarla iptal REDDEDİLİR: geçseydi bir "iptal" satırı, geri aldığı giderden
        // büyük bir tutarla kasaya para EKLEYEBİLİRDİ ve kayıt append-only olduğu için
        // düzeltmesi ancak üçüncü bir satırla olurdu.
        $this->pushEvents($token, [$this->ledgerEntry([
            'entry_type' => 'expense', 'amount_kurus' => -30000,
            'payment_type' => 'nakit', 'reverses_entry_id' => $giderId,
        ])])->assertJsonPath('results.0.status', 'rejected');

        $this->pushEvents($token, [$this->ledgerEntry([
            'entry_type' => 'expense', 'amount_kurus' => -self::GIDER,
            'payment_type' => 'nakit', 'reverses_entry_id' => $giderId,
        ])])->assertJsonPath('results.0.status', 'applied');

        // ORİJİNAL DURUYOR (append-only, kırmızı çizgi #2) ve kasa net sıfırdır.
        $sayi = $this->asOwner(fn () => LedgerEntry::query()->count());
        $this->assertSame(2, $sayi, 'iptal SİLMEZ, ikinci bir satır yazar');

        $kasa = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->whereNotNull('payment_type')->sum('amount_kurus'));
        $this->assertSame(0, $kasa, 'para kasaya geri döndü');
    }

    #[Test]
    public function ayni_gider_iki_kez_iptal_edilemez(): void
    {
        // KAPI VERİTABANINDADIR (kısmi unique indeks) ve olması gereken de orasıdır: iki cihaz
        // ÇEVRİMDIŞIYKEN aynı gideri iptal edebilir, birbirlerinin istemci kapısını göremezler ve
        // iki ters satır parayı kasaya İKİ KEZ döndürüp append-only olarak kalıcı bozardı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $giderId = (string) Str::uuid7();
        $this->pushEvents($token, [$this->ledgerEntry([
            'id' => $giderId, 'entry_type' => 'expense',
            'amount_kurus' => self::GIDER, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'applied');

        $iptal = fn () => $this->pushEvents($token, [$this->ledgerEntry([
            'entry_type' => 'expense', 'amount_kurus' => -self::GIDER,
            'payment_type' => 'nakit', 'reverses_entry_id' => $giderId,
        ])]);

        $iptal()->assertJsonPath('results.0.status', 'applied');
        $iptal()->assertJsonPath('results.0.status', 'rejected');

        $kasa = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->whereNotNull('payment_type')->sum('amount_kurus'));
        $this->assertSame(0, $kasa, 'para BİR KEZ geri döndü; ikinci iptal kasayı şişiremedi');
    }

    #[Test]
    public function gider_iptali_giderden_baskasini_geri_alamaz(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Tahsilatlı']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        $tahsilatId = (string) Str::uuid7();
        $this->pushEvents($token, [$this->ledgerEntry([
            'id' => $tahsilatId, 'customer_id' => $customerId, 'entry_type' => 'payment',
            'amount_kurus' => -self::GIDER, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'applied');

        // Bir TAHSİLATI "gider iptali" diye geri almak, kasayı gerçekte olmayan bir gider üzerinden
        // düzeltmek olurdu. Tahsilat düzeltmesinin kendi tipi vardır: `correction`.
        $this->pushEvents($token, [$this->ledgerEntry([
            'entry_type' => 'expense', 'amount_kurus' => self::GIDER,
            'payment_type' => 'nakit', 'reverses_entry_id' => $tahsilatId,
        ])])->assertJsonPath('results.0.status', 'rejected');
    }
}
