<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 4 — kasa devri için nakit ATFI (DECISIONS "Faz 4 — mimari"). ledger_entries +=
 * collected_by_user_id: tahsilatı/teslimi KİM aldı. Kuryenin beklenen nakiti = collected_by=kurye
 * olan nakit payment toplamı (period_start'tan beri). Nullable + geriye null; kasaOzeti etkilenmez
 * (hâlâ payment_type bazlı). Cross-tenant: yazımdan önce RLS-kapsamlı User::exists() doğrulanır.
 *
 * SERT FK EKLENMEZ (assigned_user_id ile simetrik): kullanıcı silinse de geçmiş defter kaydı kanıt
 * olarak durmalı (append-only felsefesi); izolasyon referans-doğrulamasıyla korunur.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ledger_entries', function (Blueprint $table) {
            $table->uuid('collected_by_user_id')->nullable()->after('payment_type');
        });
    }

    public function down(): void
    {
        Schema::table('ledger_entries', function (Blueprint $table) {
            $table->dropColumn('collected_by_user_id');
        });
    }
};
