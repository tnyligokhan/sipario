<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * FAVORİ ÜRÜNLER — customers.favorite_product_ids (kullanıcı isteği 2026-08-11).
 *
 * Müşterinin sık aldığı ürünlerin kimlik listesi; sipariş ekranında "hızlı seçim" olarak sunulur.
 * Biçim: `["urun-id-1","urun-id-2"]` — DÜZ bir string dizisi, sırası bayinin tercihidir.
 *
 * NEDEN AYRI TABLO DEĞİL, MÜŞTERİ SATIRINDA JSON DİZİ (lead kararı, tartışılmaz): müşteri satırı
 * zaten LWW ile senkronlanıyor. Yeni bir senkron VARLIĞI açmak üç maliyeti birden getirirdi —
 * uygulayıcı + delta günlüğü kaydı + tombstone/cascade kuralları — ve 1–3 kişilik bir bayide bu
 * maliyet karşılığını vermez. Liste küçüktür (azami 20), tek parça okunur, tek parça yazılır;
 * ilişkisel sorgulanacak bir şey yoktur.
 *
 * NEDEN `text`, `jsonb` DEĞİL: sunucu bu alanın İÇİNE hiç sorgu atmaz — bütün olarak taşır.
 * `jsonb` sorgulanabilirlik satın alırdı ama karşılığında senkron yolunda İKİ ayrıştırıcı
 * (Eloquent cast'i + Postgres json tipi) doğardı; bu depoda "iki ayrıştırıcı" tam olarak zehirli
 * hap kapısıdır (bkz. SyncService::CLIENT_DATA_SQLSTATES, 22007 dersi). Doğrulama sunucu KODUNDA
 * yapılır (ChangeApplier::favoriUrunler), tip sisteminde değil — çünkü red bir SQLSTATE ile değil,
 * savepoint'le izole edilen bir InvalidArgumentException ile gelmelidir.
 *
 * NULLABLE ve BOŞ DİZİ = NULL: "favorisi yok" TEK bir hâl olmalı. `[]` ile `null` iki ayrı değer
 * olsaydı istemcinin "liste boş mu" kapısı iki dala ayrılır, ikisinden biri er geç unutulurdu.
 * Uygulayıcı boş diziyi null'a indirger.
 *
 * SUNUCU ÜRÜN VARLIĞINI DOĞRULAMAZ (bilinçli): ürün silinebilir, senkron sırası garanti değildir
 * (favori listesi ürünün kendisinden ÖNCE gelebilir) ve yarım kalmış bir sipariş partisini favori
 * listesindeki ölü bir id yüzünden düşürmek orantısız olurdu. İstemci çözemediği id'yi ATLAR.
 * Sunucudaki tek kurallar biçim, tekillik ve sayıdır (azami 20 — kırpma değil RED).
 *
 * SÜRÜM ÇARPIKLIĞI (ZORUNLU, bu depoda bu sınıf hata İKİ KEZ yaşandı — 2026-08-05 kararı
 * "anahtar YOK ≠ anahtar null"): alanı bilmeyen eski bir build müşterinin ADINI düzelttiğinde
 * favori listesi SİLİNMEMELİ. Kapı `SyncPayload::gonderilenler`dedir ve `ChangeApplier`ın müşteri
 * kolonları o filtreden geçer; anahtar payload'da HİÇ YOKSA mevcut değer korunur, AÇIKÇA null
 * gelirse temizlenir. Aynı kapı panelin müşteri formunu da (PanelWriteService/PanelImportService,
 * bu anahtarı hiç göndermezler) kendiliğinden korur.
 *
 * GERİYE DÖNÜK SENKRON YAYINI GEREKMEZ: hiçbir satırın DEĞERİ değişmiyor, yalnız null bir sütun
 * ekleniyor (migration 802'nin dersi burada tetiklenmiyor).
 *
 * RLS: customers Faz 2'den beri ENABLE+FORCE RLS (migration 000210); policy ve GRANT tablo
 * düzeyindedir, yeni sütun otomatik kapsanır.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->text('favorite_product_ids')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('customers', fn (Blueprint $t) => $t->dropColumn('favorite_product_ids'));
    }
};
