{{--
    Ana sayfa · Fiyat özeti (09-sw-ana.jsx · FiyatOzetBlm).

    Fiyatların tamamı PlanDeposu'dan gelir (bkz. site/parca/_kur.php) — sabit yazılmaz.

    TEK PAKET (2026-08-05): tasarımın ikinci kartı ("Kurumsal") kaldırıldı — `plans` tablosu tek
    satırlıdır. Kart kapsamın TAMAMINI basıyor.

    ── YATAY LEVHAYA GEÇİLDİ (2026-09-01, kullanıcı kararı) ────────────────────────────────
    Dar dikey plan kartı (`.fo`) yerini `x-site.plan-yatay` bileşenine bıraktı; gerekçe ve ek
    kurye ipucunun neden burada değil satırın içinde olduğu o bileşenin belge başlığında.
    ⚠️ `.fo*` CSS sınıfları site.css'te DURUYOR ve kaldırılmadı: hesap panelindeki abonelik
    ekranı aynı sözlüğü kullanıyor. Silmek bu vardiyanın kapsamı dışında bir yüzeyi kırardı.

    KAYNAKTAN AYRILAN TEK CÜMLE: tasarımın "Yıllık … kartla 12 taksite kadar" notu, kartla ödemenin
    henüz AÇIK OLMADIĞI kararıyla çelişiyordu (OKU-BENI çelişki tablosu: iyzico ertelendi). Aynı
    tasarımın fiyat sayfasındaki karşılığı ("havale veya elden · KDV dahil") kullanıldı.
--}}
@php($p = $sw['plan']['sipario'])
{{-- `id="fiyat"`: ana sayfa içinden gelen "fiyata bak" çağrıları buraya çapalanıyor. Menüdeki
     "Fiyatlar" ise artık /fiyatlar SAYFASINA gider (2026-09-01 kararı, bkz. ust-menu). --}}
<section class="blm kagit2" id="fiyat">
    <div class="kap">
        <x-site.blm-bas baslik="Tek plan, tek fiyat."
            aciklama="Kaç müşteriniz olduğuna ya da kaç sipariş girdiğinize bakmıyoruz. Ek kalem çıkmaz." />

        <x-site.plan-yatay :plan="$p" :fiyat="$fiyat" kimlik="ana" />

        <p class="kucuk yplan-kopru">
            Aylık ödeme, ek paketler ve ödeme yöntemlerinin tamamı
            <a href="{{ route('site.fiyatlar') }}">fiyat sayfasında</a>.
        </p>
    </div>
</section>
