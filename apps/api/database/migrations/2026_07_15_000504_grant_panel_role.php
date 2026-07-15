<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * FAZ 5c — sipario_panel rolünün YETKİ MATRİSİ (DECISIONS "Faz 5 — mimari"; BRIEF panel sınırı).
 *
 * KIRMIZI ÇİZGİ: Panel bayinin iş verisini (sipariş/müşteri/para) DEĞİŞTİREMEZ — bu koda değil DB
 * İZNİNE bağlıdır (append-only REVOKE / FORCE RLS felsefesiyle simetrik). İş verisi tablolarına
 * yalnız SELECT verilir; INSERT/UPDATE/DELETE YOKtur → panel bağlantısıyla orders/ledger UPDATE
 * denemesi 42501 (permission denied) ile reddedilir (PanelPermissionTest kanıtlar).
 *
 * Panel BYPASSRLS (rol tanımı) ile cross-tenant OKUR (destek + istatistik); bu bayinin API'sini
 * ETKİLEMEZ (sipario_app hâlâ RLS altında). Yazma yalnızca: tenants (abonelik/durum yönetimi),
 * admin_users (panel hesapları), panel_audit (denetim günlüğü — INSERT, ezme yok).
 *
 * sipario_panel rolü küme düzeyinde docker init (10-roles.sh) ile kurulur; bu migration yalnız
 * grant'ları verir (owner ile koşar). Rol yoksa migration patlar → init/CI SQL rolü kurmalı.
 */
return new class extends Migration
{
    /** İş verisi tabloları — panel yalnız OKUR (yazamaz). */
    private const READ_ONLY_TABLES = [
        'customers', 'customer_phones', 'customer_addresses', 'products',
        'orders', 'order_lines', 'order_events', 'ledger_entries',
        'coupon_movements', 'coupon_balances', 'cash_handovers',
        'devices', 'users',
    ];

    public function up(): void
    {
        $readOnly = implode(', ', self::READ_ONLY_TABLES);

        DB::unprepared(<<<SQL
            -- İş verisi: yalnız SELECT (yazma YOK — panel siparişi/parayı değiştiremez).
            GRANT SELECT ON {$readOnly} TO sipario_panel;

            -- Abonelik/durum yönetimi: tenants SELECT + UPDATE (INSERT yok — elle tenant açma owner ile,
            -- Provisioning; DELETE yok — bayi silinmez).
            GRANT SELECT, UPDATE ON tenants TO sipario_panel;

            -- Panel hesapları + denetim günlüğü.
            GRANT SELECT, INSERT, UPDATE ON admin_users TO sipario_panel;
            GRANT SELECT, INSERT ON panel_audit TO sipario_panel;
        SQL);
    }

    public function down(): void
    {
        $readOnly = implode(', ', self::READ_ONLY_TABLES);

        DB::unprepared(<<<SQL
            REVOKE SELECT ON {$readOnly} FROM sipario_panel;
            REVOKE SELECT, UPDATE ON tenants FROM sipario_panel;
            REVOKE SELECT, INSERT, UPDATE ON admin_users FROM sipario_panel;
            REVOKE SELECT, INSERT ON panel_audit FROM sipario_panel;
        SQL);
    }
};
