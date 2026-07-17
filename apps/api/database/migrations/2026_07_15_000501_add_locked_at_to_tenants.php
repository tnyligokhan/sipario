<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * FAZ 5a — abonelik kilidi (DECISIONS "Faz 5 — mimari"). tenants += locked_at: kilit anı damgası.
 * Panelden suspend/lock edilince (5c) o an yazılır; süre dolunca (valid_until geçince) push sırasında
 * LAZY olarak `locked_at = valid_until` set edilir (ilk tespit eden push). `occurred_at <= locked_at`
 * sınırının çıpasıdır: kilitliyken bekleyen (offline birikmiş) yazımlar akar, kilit-sonrası yeni yazım
 * reddedilir — kilit yazmayı durdurur ama bekleyen kaydı yutmaz (kırmızı çizgi #5, veri rehin alınmaz).
 *
 * tenants RLS'i zaten var; yeni kolon politikayı değiştirmez.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->timestampTz('locked_at')->nullable()->after('valid_until');
        });
    }

    public function down(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->dropColumn('locked_at');
        });
    }
};
