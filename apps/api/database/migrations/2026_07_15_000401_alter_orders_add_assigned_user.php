<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 4 — sipariş ATAMA (DECISIONS "Faz 4 — mimari"). orders += assigned_user_id: hangi kuryeye
 * atandığı. Bu bir ÖNBELLEK sütunudur (orders.status/total gibi); kaynağı assigned/unassigned
 * order_events'idir, sunucu recomputeOrder ile en son olaydan türetir.
 *
 * SERT bileşik FK EKLENMEZ (customers/products'taki gibi (tenant_id,id) referansı): atama-alma bir
 * kullanıcı silinse bile geçmiş atamayı kırmamalı; kiracı izolasyonu yazımdan ÖNCE RLS-kapsamlı
 * User::exists() doğrulamasıyla korunur (customer/product referans deseni). index tenant içi filtre.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->uuid('assigned_user_id')->nullable()->after('customer_id');
            $table->index(['tenant_id', 'assigned_user_id']);
        });

        // order_events.event_type CHECK'ine atama olaylarını ekle (atama olay-kaynaklı: assigned/
        // unassigned birer order olayıdır; CHECK bunları içermezse INSERT 23514 ile reddedilirdi).
        DB::statement('ALTER TABLE order_events DROP CONSTRAINT order_events_type_check');
        DB::statement(
            'ALTER TABLE order_events ADD CONSTRAINT order_events_type_check '.
            "CHECK (event_type IN ('created','line_added','line_removed','delivered','cancelled','payment_set','note_set','assigned','unassigned'))"
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE order_events DROP CONSTRAINT order_events_type_check');
        DB::statement(
            'ALTER TABLE order_events ADD CONSTRAINT order_events_type_check '.
            "CHECK (event_type IN ('created','line_added','line_removed','delivered','cancelled','payment_set','note_set'))"
        );

        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'assigned_user_id']);
            $table->dropColumn('assigned_user_id');
        });
    }
};
