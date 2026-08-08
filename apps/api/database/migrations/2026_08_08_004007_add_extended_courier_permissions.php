<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * KURYE VE ROL YETKİ MATRİSİ — Sipario Genel Yetki Matrisi genişletmesi.
 *
 * Bayinin açıp kapatabildiği dinamik kurye yetkileri:
 *  - courier_can_see_all_orders: false (varsayılan: sadece kendi siparişleri)
 *  - courier_can_view_history: false (varsayılan: geçmiş gün teslimatlarını görme pasif)
 *  - courier_can_expense: false (varsayılan: saha gideri girme pasif)
 *  - courier_phone_mask: true (varsayılan: müşteri telefonlarını 0532***12 maskele)
 *  - courier_can_customer_ledger: false (varsayılan: müşteri geçmiş defterini görme pasif)
 *  - courier_can_debt_reminder: false (varsayılan: SMS/WA borç hatırlatma pasif)
 *  - courier_can_toggle_stock: true (varsayılan: stokta yok işaretleme aktif)
 *  - courier_can_call_log: false (varsayılan: dükkan çağrı günlüğünü görme pasif)
 */
return new class extends Migration {
    private const YENI_KOLONLAR = [
        'courier_can_see_all_orders' => false,
        'courier_can_view_history' => false,
        'courier_can_expense' => false,
        'courier_phone_mask' => true,
        'courier_can_customer_ledger' => false,
        'courier_can_debt_reminder' => false,
        'courier_can_toggle_stock' => true,
        'courier_can_call_log' => false,
    ];

    public function up(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            foreach (self::YENI_KOLONLAR as $kolon => $varsayilan) {
                if (! Schema::hasColumn('tenant_settings', $kolon)) {
                    $table->boolean($kolon)->default($varsayilan);
                }
            }
        });
    }

    public function down(): void
    {
        Schema::table('tenant_settings', function (Blueprint $table) {
            $table->dropColumn(array_keys(self::YENI_KOLONLAR));
        });
    }
};
