<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * ŞİRKET MASRAFLARI — BİZİM giderimiz (sunucu, domain, reklam, komisyon). Tasarım: `GelirGider`
 * ekranının gider tarafı.
 *
 * `tenant_id` YOKTUR VE OLMAYACAKTIR. Bu tablo bayi verisi değildir; Hetzner faturası hiçbir
 * bayiye ait değildir. Kolonu "belki lazım olur" diye eklemek, ileride birinin masrafı bir bayiye
 * bağlamasına ve gelir-gider raporunun sessizce bayi bazlı bir kârlılık raporuna dönüşmesine
 * davetiye olurdu. RLS de bu yüzden YOKTUR (izole edilecek kiracı yok) — koruma, sipario_app'in
 * bu tabloya HİÇBİR izninin olmamasıdır (005010).
 *
 * PARA: imzasız int KURUŞ, bigint. Negatif tutar YOK (CHECK) — "eksi masraf" muhasebe değil kaza.
 *
 * NEDEN UPDATE/DELETE İZNİ VERİLMEDİ (005010): tasarımda yalnız "Masraf Ekle" vardır, düzeltme
 * akışı yoktur. İzni bugünden vermek, yarın yazılacak bir ekranın gider geçmişini sessizce
 * değiştirebilmesi demekti. Düzeltme gerekirse ayrı bir karar + ayrı bir migration + denetim izi
 * ister. (Gerekirse `GRANT UPDATE, DELETE ON expenses TO sipario_panel` tek satırdır.)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('expenses', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->date('spent_on');
            $table->string('category', 40);      // Sunucu/Altyapı · Domain/Lisans · Reklam · Komisyon · Diğer
            $table->bigInteger('amount_kurus');
            $table->text('note')->nullable();
            $table->uuid('admin_user_id')->nullable();
            $table->timestampTz('created_at')->useCurrent();

            $table->index('spent_on');
        });

        DB::statement(
            'ALTER TABLE expenses ADD CONSTRAINT expenses_amount_check CHECK (amount_kurus >= 0)'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('expenses');
    }
};
