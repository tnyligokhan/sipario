<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\LedgerEntry;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * KAPIDA İSKONTO — `entry_type = 'discount'` sunucu sözleşmesi (kullanıcı isteği 2026-07-30:
 * *"420 liralık siparişte 400 lira ödeme alınabilir; 'borçlu gösterme' kutusu olması gerekiyor"*).
 *
 * İSKONTONUN TEK AYIRT EDİCİ ÖZELLİĞİ: borcu payment gibi kapatır ama KASAYA GİRMEZ. Bu dosya o
 * ayrımın sunucuda iki yönlü tuttuğunu kanıtlar — iskonto bakiyeyi kapatıyor mu, ve kasaya
 * sızmasının yolu gerçekten kapalı mı. İkincisi teorik değil: `payment` yazılsaydı gün sonunda
 * sayılan nakit her iskontoda 20 ₺ fazla çıkar, bayi kasayı eksik sanır ve kapanış farkı KANIT
 * olmaktan çıkıp gürültüye dönerdi (DECISIONS: "kasa kuruşuna kuruşuna").
 *
 * Kasa ölçütü ENUM SAYMAZ, değişmezi kullanır: "payment_type taşıyan kayıt kasaya dokundu"
 * (DECISIONS Faz 3). Testler de kasayı o şekilde okur — yarın kasaya dokunan yeni bir tip çıksa
 * bile bu testler doğru soruyu sormayı sürdürsün.
 */
class LedgerDiscountTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /** Kullanıcının verdiği örnek, kuruş cinsinden: 420 ₺ sipariş · 400 ₺ tahsilat · 20 ₺ iskonto. */
    private const SIPARIS = 42000;

    private const TAHSIL = 40000;

    private const ISKONTO = 2000;

    #[Test]
    public function iskonto_borcu_kapatir_ama_kasaya_girmez(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Kapıda Kırıldı']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        // Teslimin üç satırı — mobil `OrderRepository.deliver` bunları tek transaction'da yazar.
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'debit', 'amount_kurus' => self::SIPARIS,
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'payment',
            'amount_kurus' => -self::TAHSIL, 'payment_type' => 'nakit',
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'discount', 'amount_kurus' => -self::ISKONTO,
        ])])->assertJsonPath('results.0.status', 'applied',
            'discount CHECK kısıtında yoksa olay reddedilir ve iskonto sessizce kaybolurdu');

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(0, $balance,
            'Müşteri BORÇLU GÖSTERİLMEZ — istenen davranış tam olarak budur (420 − 400 − 20 = 0).');

        // Kasa = payment_type taşıyan kayıtların toplamı. İskonto orada GÖRÜNMEZ.
        $kasa = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->where('customer_id', $customerId)->whereNotNull('payment_type')->sum('amount_kurus'));
        $this->assertSame(-self::TAHSIL, $kasa,
            'Kasaya 400 ₺ girdi; kırılan 20 ₺ kasayı ŞİŞİRMEZ (sayım tutmalı).');

        // Ciro (debit) TAM tutardır: iskonto satışın kendisini düzeltmez, kendi satırını yazar.
        $ciro = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->where('customer_id', $customerId)->where('entry_type', 'debit')->sum('amount_kurus'));
        $this->assertSame(self::SIPARIS, $ciro, 'Append-only: debit yerinde durur, üstüne yazılmaz.');
    }

    #[Test]
    public function iskonto_pozitif_tutarla_reddedilir(): void
    {
        // discount borç AZALIŞIDIR (payment/credit ile aynı işaret kuralı). Pozitifi kabul etmek,
        // "iskonto" adı altında müşteriye borç yazmanın yolunu açardı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'İşaret Kontrolü']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'discount', 'amount_kurus' => 100,
        ])])->assertJsonPath('results.0.status', 'rejected');

        $sayi = $this->asOwner(fn () => LedgerEntry::query()->where('customer_id', $customerId)->count());
        $this->assertSame(0, $sayi, 'Reddedilen kayıt deftere hiç girmez.');
    }

    #[Test]
    public function iskonto_payment_type_tasiyamaz_kasaya_sizma_yolu_kapali(): void
    {
        // Bu, özelliğin BÜTÜN muhasebe güvencesinin dayandığı kısıt: payment_type taşıyan bir
        // discount, kasa sorgusuna kendiliğinden girer ve sayılan nakitle defteri çeliştirirdi.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Kasa Sınırı']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        foreach (['nakit', 'kart', 'havale'] as $tip) {
            $this->pushEvents($token, [$this->ledgerEntry([
                'customer_id' => $customerId, 'entry_type' => 'discount',
                'amount_kurus' => -self::ISKONTO, 'payment_type' => $tip,
            ])])->assertJsonPath('results.0.status', 'rejected');
        }

        $kasa = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->whereNotNull('payment_type')->count());
        $this->assertSame(0, $kasa, 'Üç ödeme tipinin hiçbiri iskontoya iliştirilemez.');
    }

    #[Test]
    public function iskonto_siparise_bagli_yazilir_ve_bakiye_defterden_yeniden_kurulur(): void
    {
        // İskonto HANGİ siparişte yapıldığı bilinmeden okunamaz: mobil "bu siparişten kalan borç"
        // sorusunu related_order_id üzerinden yanıtlıyor. Ayrıca bakiye önbelleği, iskonto
        // satırından sonra da DEFTERDEN yeniden kurulmalı (ayrıcalıklı dal yok).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Siparişli İskonto']);
        $customerId = $cust['payload']['id'];
        $this->pushEvents($token, [$cust]);

        $order = $this->orderCreated(
            [$this->line(['unit_price_kurus' => self::SIPARIS, 'qty' => 1])],
            ['customer_id' => $customerId],
        );
        $orderId = $order['payload']['order']['id'];
        $this->pushEvents($token, [$order])->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'debit',
            'amount_kurus' => self::SIPARIS, 'related_order_id' => $orderId,
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'payment', 'amount_kurus' => -self::TAHSIL,
            'payment_type' => 'nakit', 'related_order_id' => $orderId,
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $customerId, 'entry_type' => 'discount',
            'amount_kurus' => -self::ISKONTO, 'related_order_id' => $orderId,
        ])])->assertJsonPath('results.0.status', 'applied');

        // Siparişe bağlı toplam (payment + discount) siparişi TAM kapatır → kalan borç 0.
        $kapanan = $this->asOwner(fn () => (int) LedgerEntry::query()
            ->where('related_order_id', $orderId)
            ->whereIn('entry_type', ['payment', 'discount'])->sum('amount_kurus'));
        $this->assertSame(-self::SIPARIS, $kapanan,
            'payment + discount = sipariş tutarı → "Borçlu" listesine girmez.');

        $balance = $this->asOwner(fn () => Customer::query()->find($customerId)?->balance_kurus);
        $this->assertSame(0, $balance, 'Bakiye önbelleği iskonto satırından sonra da defterden kurulur.');
    }
}
