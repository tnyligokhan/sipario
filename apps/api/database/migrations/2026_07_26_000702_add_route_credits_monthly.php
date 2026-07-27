<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Oto sıralama (rota) KONTÖRÜNÜN aylık kotası.
 *
 * Tasarım `s-bilesenler.jsx` çekmecesi iki sayı gösteriyor: "34 hak" (kalan) ve "Aylık 50"
 * (kota), ilerleme çubuğu bu ikisinin oranı. `route_credits` (kalan) 2026_07_25_000605'te
 * eklenmişti; kota alanı eksikti, o yüzden çekmece kartı hiç çizilemiyordu.
 *
 * İkisi de SUNUCU SAHİPLİDİR: istemci yazamaz, subscription bloğuyla iner (modules deseni).
 * Varsayılan 50 tasarımın gösterdiği değerdir; abonelik paketine göre panelden değişir.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->integer('route_credits_monthly')->default(50);
        });
    }

    public function down(): void
    {
        Schema::table('tenants', fn (Blueprint $t) => $t->dropColumn('route_credits_monthly'));
    }
};
