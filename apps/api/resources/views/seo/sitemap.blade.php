{{--
    Site haritası. Rota: /sitemap.xml (routes/web.php · seo.sitemap).

    ⚠️ İLK KARAKTER ÖNEMLİ: XML bildirimi dosyanın EN BAŞINDA, bir bayt boşluk bile olmadan
    durmalı; yoksa ayrıştırıcı "XML declaration allowed only at the start" der ve Search
    Console haritayı reddeder. Blade yorumu çıktıya hiç basılmaz, o yüzden bu başlık
    güvenlidir — bir HTML yorumu olsaydı basılır ve haritayı kırardı.

    ⚠️ BU YORUMUN İÇİNDE BLADE YORUM SINIRLAYICISI YAZILAMAZ. Blade yorumları iç içe geçmez:
    ayrıştırıcı ilk kapanış dizisini gördüğü yerde bu bloğu kapatır ve kalan satırlar XML'in
    ÖNÜNE düz metin olarak basılır — haritayı bozan tam olarak budur (bizzat yaşandı,
    2026-08-19; aynı tuzağa components/legal/deger.blade.php'de de düşülmüştü).

    XML açılış etiketi düz yazılamaz: PHP'nin short_open_tag ayarı açıksa bir PHP açılışı
    sanılır. Aşağıdaki dize kaçışı bu belirsizliği tamamen kaldırır.
--}}
{!! '<?xml version="1.0" encoding="UTF-8"?>' !!}
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
@foreach ($adresler as $a)
    <url>
        <loc>{{ $a['loc'] }}</loc>
        <changefreq>{{ $a['changefreq'] }}</changefreq>
        <priority>{{ $a['priority'] }}</priority>
    </url>
@endforeach
</urlset>
