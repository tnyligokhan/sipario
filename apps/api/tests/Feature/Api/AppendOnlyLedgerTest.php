<?php

namespace Tests\Feature\Api;

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * KIRMIZI ÇİZGİ #2 — para/hareket kayıtları silinmez/ezilmez. Bu değişmez KODA değil VERİTABANI
 * İZNİNE bağlıdır (reviewer bulgusu): app rolü append-only tablolarda UPDATE/DELETE yapamaz.
 * FORCE RLS "yanlışlıkla owner ile bağlanılsa bile" felsefesiyle simetrik savunma-derinliği.
 *
 * İZİN testleri app rolü (sipario_app) bağlantısında koşar; yetki reddi (SQLSTATE 42501)
 * satır/tenant bağlamından ÖNCE gelir, bu yüzden veri seed etmeye gerek yok.
 *
 * KISIT testi (`payment_type` kapsamı) bilerek OWNER ile koşar: CHECK role bakmaz ve sınanan şey
 * "en ayrıcalıklı yol bile kaçamıyor mu"dur — kuralın yanından geçen yol tam olarak oydu (seeder).
 * Aynı dosyada durmalarının sebebi ortak: ikisi de bir değişmezi KODA değil VERİTABANINA bağlıyor.
 */
class AppendOnlyLedgerTest extends ApiTestCase
{
    /** @return list<array{string}> */
    public static function appendOnlyTables(): array
    {
        return [
            ['ledger_entries'],
            ['order_events'],
            ['sync_changes'],
            ['processed_events'],
            ['cash_handovers'],
            // Gün sonu kapanış arşivi (migration 607): "kapatıldı" ifadesi ancak ezilemezse anlam
            // taşır — yanlış kapanış YENİ kapanış kaydıyla düzeltilir.
            ['day_closings'],
        ];
    }

    #[Test]
    #[DataProvider('appendOnlyTables')]
    public function app_rolu_append_only_tabloda_update_yapamaz(string $table): void
    {
        try {
            DB::statement("UPDATE {$table} SET tenant_id = tenant_id");
            $this->fail("{$table} üzerinde UPDATE reddedilmeliydi (append-only).");
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode(), "{$table} UPDATE için 'permission denied' beklenir.");
        }
    }

    #[Test]
    #[DataProvider('appendOnlyTables')]
    public function app_rolu_append_only_tabloda_delete_yapamaz(string $table): void
    {
        try {
            DB::statement("DELETE FROM {$table}");
            $this->fail("{$table} üzerinde DELETE reddedilmeliydi (append-only).");
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode(), "{$table} DELETE için 'permission denied' beklenir.");
        }
    }

    #[Test]
    public function app_rolu_append_only_tabloya_insert_ve_select_yapabilir(): void
    {
        // Append-only INSERT + SELECT'i engellemez; yalnız update/delete kapalıdır.
        // (Boş SELECT yeter — INSERT yolu SyncTest'te uçtan uca kanıtlanıyor.)
        $count = DB::table('ledger_entries')->count();
        $this->assertIsInt($count);
    }

    /**
     * `payment_type` KAPSAM kuralı: yalnız `payment`/`correction` taşıyabilir.
     *
     * Kural 2026-08-06'ya kadar TEK yerde — `ChangeApplier::validateLedgerEntry`de, yani yalnız
     * SENKRON yolunda — yaşıyordu; Eloquent'le doğrudan yazan her yol kapının yanından geçiyordu
     * ve `DemoSeeder` fiilen geçiyordu (`credit` + `payment_type: havale`). Hakem artık DB'de.
     *
     * @return list<array{string, bool}> [entry_type, payment_type taşıyabilir mi]
     */
    public static function paymentTypeKapsami(): array
    {
        return [
            'payment taşır' => ['payment', true],
            // Yanlış tahsilatı ters çeviren correction, kasayı da düzeltebilmek için tipi TAŞIR.
            'correction taşır' => ['correction', true],
            // Para hareketi DEĞİL, borç azaltma jesti — kasaya dokunmaz.
            'credit taşımaz' => ['credit', false],
            'debit taşımaz' => ['debit', false],
            // İSKONTO TEMİNATI: kapıda kırılan tutar kasaya HİÇ girmez; yasak onun teminatıdır.
            'discount taşımaz' => ['discount', false],
        ];
    }

    #[Test]
    #[DataProvider('paymentTypeKapsami')]
    public function payment_type_yalniz_payment_ve_correction_kaydinda_olabilir(
        string $entryType,
        bool $tasiyabilir,
    ): void {
        $tenant = $this->makeTenant('pt');

        // İŞARET kuralına uyan tutar seçiliyor: kısıt sınanırken başka bir kısıt patlarsa test
        // yanlış şeyi kanıtlar (debit ≥ 0, diğerleri ≤ 0 — bkz. validateLedgerEntry).
        $satir = fn (?string $paymentType) => [
            'id' => (string) Str::uuid7(),
            'tenant_id' => $tenant['tenant']->id,
            'entry_type' => $entryType,
            'amount_kurus' => $entryType === 'debit' ? 5000 : -5000,
            'payment_type' => $paymentType,
            'occurred_at' => now(),
            'client_event_id' => (string) Str::uuid7(),
        ];

        // OWNER İLE YAZILIYOR ve bu BİLİNÇLİ: sınanan şey "en ayrıcalıklı yol bile kaçamıyor mu"
        // sorusudur. Seeder de tam olarak böyle yazıyor (owner + doğrudan insert) ve uygulama
        // katmanındaki kural ona hiç değmiyordu. CHECK kısıtı role bakmaz — owner da bağlanır.
        // (app rolüyle yazmak ayrıca RLS oturum bağlamı kurmayı gerektirirdi ve o başka bir testin
        // konusu; burada 42501/RLS gürültüsü kısıt kanıtını gizlerdi.)
        $yaz = fn (?string $paymentType) => $this->asOwner(
            fn () => DB::table('ledger_entries')->insert($satir($paymentType))
        );

        // payment_type'SIZ satır her tipte serbest — kısıt YALNIZ kapsamı daraltmalı.
        $yaz(null);

        if ($tasiyabilir) {
            $yaz('nakit');
            $this->assertSame(2, $this->asOwner(
                fn () => DB::table('ledger_entries')->where('entry_type', $entryType)->count()
            ), "{$entryType} ödeme tipi taşıyabilmeli.");

            return;
        }

        try {
            $yaz('nakit');
            $this->fail("{$entryType} + payment_type DB tarafından reddedilmeliydi.");
        } catch (QueryException $e) {
            // 23514 = check_violation. Kısıt NOT VALID'dir: mevcut satırları taramaz ama YENİ
            // yazımı bağlar — ve 23514 `CLIENT_DATA_SQLSTATES` listesinde olduğu için senkrondan
            // gelirse partiyi düşürmez, olay bazında reddedilir.
            $this->assertSame('23514', $e->getCode(),
                "{$entryType} + payment_type için check ihlali (23514) beklenir.");
            $this->assertStringContainsString('payment_type_scope', $e->getMessage(),
                'Reddi yapan kısıt KAPSAM kısıtı olmalı (değer beyaz listesi değil).');
        }
    }

    #[Test]
    public function app_rolu_bakiye_onbellegini_guncelleyebilir(): void
    {
        // ÖNBELLEK taşıyan tablo append-only DEĞİL: customers.balance_kurus defterden türetilir ve
        // her ledger olayında recompute onu UPDATE eder. Bu tablo yanlışlıkla append-only REVOKE
        // setine girerse tüm defter akışı 42501 ile kırılırdı; bu test o regresyonu yakalar.
        // Boş UPDATE (0 satır) yetki reddi FIRLATMAMALI.
        // (Eskiden aynı değişmez coupon_balances üzerinden sınanıyordu — kupon 2026-07-26'da
        // üründen kalktı, sıra önbelleğin ASIL taşıyıcısına geçti.)
        $affected = DB::update('UPDATE customers SET balance_kurus = balance_kurus');
        $this->assertSame(0, $affected, 'Önbellek tablosu güncellenebilir olmalı (REVOKE setinde değil).');
    }
}
