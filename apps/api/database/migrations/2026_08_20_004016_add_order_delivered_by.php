<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * TESLİMİ KİM YAPTI (2026-08-20 kullanıcı kararı: "uygulamada yapılan her işlem giriş yapılan
 * hesaba bağlanır").
 *
 * SORUN: `orders.assigned_user_id` bir NİYETTİR ("bunu Ali götürecek"), bir OLGU değil. Gün özeti
 * teslimat sayısını ve günün veresiyesini o alandan okuyordu; patron, Ali'ye atanmış siparişi
 * kendisi teslim ettiğinde teslimat da veresiye de ALİ'NİN hesabına yazılıyordu. Para doğruydu
 * (`ledger_entries.collected_by_user_id` zaten teslimi yapanı taşıyor), teslimat ve borç yanlıştı —
 * yani aynı olayın iki yarısı iki farklı kişiye gidiyordu.
 *
 * ÇÖZÜM: atama alanına DOKUNULMAZ (rota planı odur ve öyle kalmalı); teslimi kimin yaptığı AYRI
 * bir alanda durur. `assigned_user_id`in birebir ikizidir: bir ÖNBELLEKtir, kaynağı `delivered`
 * order olayının payload'ıdır ve `recomputeOrder` onu en son olaydan türetir.
 *
 * NEDEN OLAYIN İÇİNDE, NEDEN AYRI BİR SÜTUN YAZIMI DEĞİL: iki cihaz aynı siparişi offline teslim
 * edebilir; append-only olay defteri zaten tek doğru kaynaktır ve iki taraf (istemci `_recompute`,
 * sunucu `recomputeOrder`) AYNI olaylardan aynı sonucu türetir. Sütuna doğrudan yazmak, senkron
 * sırasına bağlı bir ıraksama üretirdi.
 *
 * ESKİ SATIRLAR NULL KALIR ve bu doğrudur: o teslimlerin kim tarafından yapıldığı KAYITLI DEĞİLDİR.
 * Okuma katmanı null'da `assigned_user_id`e düşer — yani geçmiş günler bugünkü gibi görünmeye
 * devam eder, uydurulmuş bir atıf üretilmez.
 *
 * SERT FK YOK: `assigned_user_id` ile aynı gerekçe — kullanıcı pasifleştirilse/silinse bile geçmiş
 * teslimat kaydı kırılmamalı; kiracı izolasyonu yazımdan ÖNCE RLS-kapsamlı `User::exists()` ile
 * korunur (OrderChangeApplier).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->uuid('delivered_by_user_id')->nullable()->after('assigned_user_id');
            $table->index(['tenant_id', 'delivered_by_user_id']);
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'delivered_by_user_id']);
            $table->dropColumn('delivered_by_user_id');
        });
    }
};
