<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

/*
 * ABONELİK HATIRLATMALARI — bu deponun İLK zamanlanmış görevi.
 *
 * Zamanlayıcı konteyneri (`docker-compose.prod.yml:332`, `php artisan schedule:work`) aylardır
 * koşuyor ve bugüne kadar "No scheduled commands" basıyordu; yani bu satır yeni bir servis
 * gerektirmez, var olanı ilk kez çalıştırır.
 *
 * SAAT 09:30 SEÇİMİ İŞ SAATİNE GÖRE: alıcı esnaftır, postayı sabah dükkânı açarken okur. Gece
 * yarısı gönderilen bir "3 gün kaldı" postası, sabah gelen kutusunun dibinde kalır. `timezone`
 * AÇIKÇA yazıldı — sunucu UTC koşuyor ve varsayılana güvenmek hatırlatmayı sabaha karşı 12:30'a
 * kaydırırdı.
 *
 * `withoutOverlapping`: koşu uzarsa (çok bayi + yavaş kuyruk) ertesi günün koşusu üstüne binmesin.
 * Postaların kendi tekillik kapısı da var (`Cache::add` işareti), yani bu ikinci emniyet kemeri.
 */
Schedule::command('abonelik:hatirlat')
    ->dailyAt('09:30')
    ->timezone('Europe/Istanbul')
    ->withoutOverlapping()
    ->onOneServer();

/*
 * GÜNLÜK YEDEK BİLDİRİMİ — en yeni yedeğin indirme bağlantısını bize postalar.
 *
 * SAAT 08:00, abonelik hatırlatmasından ÖNCE ve bilerek: bu posta bir İŞ değil bir
 * SAĞLIK RAPORUdur. Güne "yedek dün gece alındı, boyutu şu" bilgisiyle başlamak,
 * yedekleme servisinin durduğunu günler sonra fark etmekten iyidir.
 *
 * `backup` sidecar'ı sabit bir saatte değil, kendi başlangıcından itibaren 24 saatte bir
 * yazar (`docker/backup/backup.sh:110`). Bu yüzden komut "bu sabahki yedeği" değil
 * ARŞİVDEKİ EN YENİSİNİ gönderir ve yaşı eşiği aşarsa postaya uyarı bandı koyar —
 * sidecar durursa bu bant, arızanın tek görünür işareti olur.
 *
 * `withoutOverlapping` + `onOneServer`: yukarıdaki görevle aynı gerekçe.
 */
Schedule::command('yedek:baglanti-gonder')
    ->dailyAt('08:00')
    ->timezone('Europe/Istanbul')
    ->withoutOverlapping()
    ->onOneServer();

/*
 * DÜŞÜRÜLMÜŞ TOKEN'LARIN TEMİZLİĞİ (2026-08-22, tek hesap = tek cihaz).
 *
 * Yeni bir telefonda giriş yapılınca eski token SİLİNMEZ, düşürülür: satır kalır ki eski
 * telefon "neden çıktım" sorusunun cevabını alabilsin (`RejectRevokedToken`). Kalan satır
 * sonsuza kadar durmamalı — 30 gün, çevrimdışı kalabilecek en uzun makul süreden (BRIEF:
 * istisnaen bir gün) kat kat uzun ve bir telefonun o cevabı hâlâ okuyabileceği penceredir.
 *
 * `sanctum:prune-expired` süresi geçmiş token'ları siler; düşürme sırasında `expires_at`
 * geçmişe çekildiği için bu komut düşürülmüşleri de kapsar.
 */
Schedule::command('sanctum:prune-expired --hours=720')
    ->weekly()
    ->timezone('Europe/Istanbul')
    ->withoutOverlapping()
    ->onOneServer();
