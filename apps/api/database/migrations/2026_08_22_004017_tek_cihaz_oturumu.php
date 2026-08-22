<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * TEK HESAP = TEK CİHAZ (kullanıcı kararı 2026-08-22).
 *
 * Bir kullanıcı yeni bir telefonda giriş yaptığında eski telefonun oturumu KAPANIR. Bunu
 * yapmanın en kısa yolu eski token satırını silmekti; silmedik. Sebep şu: silinen bir token
 * sonraki istekte "seni tanımıyorum" (401) der ve bayi ekranda SEBEPSİZ bir çıkış görür —
 * destek çağrısının birinci sebebi tam olarak bu olurdu. Satır kalır, üstüne NEDEN yazılır
 * (`revoked_reason`) ve istemci "hesabınız başka bir cihazda açıldı" diyebilir.
 *
 * `expires_at` de AYNI ANDA geçmişe çekilir ve bu ikinci kemer bilinçlidir: Sanctum'un kendi
 * kapısı (`Guard::isValidAccessToken`) süresi geçmiş token'ı zaten reddeder. Yani yarın biri
 * yeni bir korumalı rota grubu açıp `RejectRevokedToken`ı takmayı unutursa, düşürülmüş token
 * yine de İŞE YARAMAZ. Nedeni açıklamak bizim işimiz, kapıyı tutmak Sanctum'un.
 *
 * `device_id`: hangi telefonun token'ı olduğunu bilmeden düşen cihazın push jetonunu
 * temizleyemeyiz — oturumu kapanmış bir telefon o bayinin bildirimlerini almaya DEVAM ederdi.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            // devices.id ile aynı kimlik (istemcide üretilen UUIDv7). FK YOK: cihaz kaydı
            // opsiyoneldir (login `device` bloğu göndermeyebilir) ve silinen bir cihaz satırı
            // token'ı düşürmemeli.
            $table->uuid('device_id')->nullable()->after('tenant_id');
            $table->timestamp('revoked_at')->nullable();
            $table->string('revoked_reason', 40)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->dropColumn(['device_id', 'revoked_at', 'revoked_reason']);
        });
    }
};
