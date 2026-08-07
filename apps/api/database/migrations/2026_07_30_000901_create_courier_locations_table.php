<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * courier_locations — "canlı kurye konumu" (tasarım: patronun haritada ekibini görmesi).
 *
 * GEÇMİŞ TUTULMAZ (KVKK veri minimizasyonu, kırmızı çizgi #4): birincil anahtar `user_id`dir,
 * yani kullanıcı başına TEK satır. Her kalp atışı aynı satırı EZER. Bir iz tablosu olsaydı
 * elimizde her çalışanın gün gün nerede olduğunu gösteren bir takip arşivi birikirdi — özelliğin
 * ihtiyacı "şu an neredeler", "dün nerelerdeydi" DEĞİL. Tutulmayan veri sızdırılamaz.
 *
 * NEDEN SENKRON TABLOSU DEĞİL: bu veri UÇUCUdur (dakikalar içinde değersizleşir) ve çevrimdışı
 * birleştirilecek bir "gerçek" taşımaz. Sync outbox'ına konsaydı her kalp atışı kalıcı bir
 * değişiklik olayı (seq) üretir, bütün cihazlara yayılır ve pull yükünü çöple doldururdu.
 *
 * KOMPOZİT FK (tenant_id, user_id) → users(tenant_id, id) TESADÜF DEĞİL: satırın kiracısı,
 * kullanıcının GERÇEK kiracısı olmak ZORUNDA. Tek başına user_id FK'si, uygulama katmanındaki
 * bir hata yüzünden yanlış tenant_id yazılmasını engellemezdi; bu FK onu DB'de imkânsız kılar
 * (yani upsert'in ON CONFLICT dalı bir satırın kiracısını kaçıramaz).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('courier_locations', function (Blueprint $table) {
            // Surrogate uuid YOK: anahtar kullanıcının kendisidir — "tek satır" kuralı şemanın
            // içinde durur, uygulama disiplinine bırakılmaz.
            $table->uuid('user_id')->primary();
            $table->uuid('tenant_id');
            $table->double('lat');
            $table->double('lng');
            // Cihazın bildirdiği yatay hata payı (metre). Null = cihaz bilmiyor; tazelikten
            // ayrı bir bilgidir (taze ama 500 m hatalı bir konum patronu yanıltmamalı).
            $table->double('accuracy_m')->nullable();
            // Tazelik kararının TEK dayanağı. Sunucu saatidir (istemcinin telefon saati yanlış
            // olabilir — DECISIONS: sunucu her yanıtta kendi saatini döner).
            $table->timestampTz('reported_at')->useCurrent();

            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign(['tenant_id', 'user_id'])
                ->references(['tenant_id', 'id'])->on('users')->cascadeOnDelete();
            // Canlı liste sorgusunun tek erişim yolu: kiracı + tazelik penceresi.
            $table->index(['tenant_id', 'reported_at']);
        });

        // Koordinat aralığı DB'de de kapalı: FormRequest ilk savunmadır, bu ikincisidir. İleride
        // başka bir yazma yolu açılırsa (seed, konsol komutu) sınır yine tutar.
        DB::statement(
            'ALTER TABLE courier_locations ADD CONSTRAINT courier_locations_lat_check '.
            'CHECK (lat BETWEEN -90 AND 90)'
        );
        DB::statement(
            'ALTER TABLE courier_locations ADD CONSTRAINT courier_locations_lng_check '.
            'CHECK (lng BETWEEN -180 AND 180)'
        );
        DB::statement(
            'ALTER TABLE courier_locations ADD CONSTRAINT courier_locations_accuracy_check '.
            'CHECK (accuracy_m IS NULL OR accuracy_m >= 0)'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('courier_locations');
    }
};
