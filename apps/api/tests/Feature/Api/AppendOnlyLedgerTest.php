<?php

namespace Tests\Feature\Api;

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * KIRMIZI ÇİZGİ #2 — para/hareket kayıtları silinmez/ezilmez. Bu değişmez KODA değil VERİTABANI
 * İZNİNE bağlıdır (reviewer bulgusu): app rolü append-only tablolarda UPDATE/DELETE yapamaz.
 * FORCE RLS "yanlışlıkla owner ile bağlanılsa bile" felsefesiyle simetrik savunma-derinliği.
 *
 * Testler app rolü (sipario_app) bağlantısında koşar; yetki reddi (SQLSTATE 42501) satır/tenant
 * bağlamından ÖNCE gelir, bu yüzden veri seed etmeye gerek yok.
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
