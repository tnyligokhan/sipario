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
