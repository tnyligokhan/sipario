{{--
    sipario.com.tr · ÖZELLİKLER (tasarım: _kaynak/web/10-sw-ozellik.jsx · OzellikSayfa).
    Hero + beş dönüşümlü anlatı bölümü + "bir gün" zaman çizelgesi + ek özellikler + kurulum + son çağrı.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

{{-- Birincil kelime: "arayan tanıma programı" (docs/seo-anahtar-kelimeler.md). Ürünün varlık
     sebebi ve rakiplerde olmayan tek şey; başlıkta ÖNDE durması bu yüzden. --}}
<x-layouts.site
    baslik="Arayan tanıma programı, veresiye defteri ve kurye takibi · Sipario"
    aciklama="Gelen aramada müşteri kartı ekranda: adı, adresi, borcu, son siparişi. Veresiye defteri, sipariş akışı, kurye ve rota, gün sonu kasa — internet gitse de çalışır.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    {{--
        ── İKİ BÖLÜM ÇIKARILDI (2026-08-19) ────────────────────────────────────────────────

        `ozellik-gun` ("Sıradan bir salı, Sipario ile" — 08:10 gün açılır → 09:24 telefon çalar
        → 09:25 sipariş girilir → 11:40 kurye teslim eder → 19:05 gün kapanır) hemen üstündeki
        `ozellik-split` ile AYNI BEŞ ŞEYİ, AYNI SIRAYLA anlatıyordu. Split bölümleri daha
        ayrıntılı ve ekran maketli; zaman çizelgesi onların özetiydi. Aynı sayfada bir şeyi
        önce uzun sonra kısa anlatmak, okuyana "bunu zaten okudum" dedirtir.

        `adim` (kurulum adımları) ana sayfada zaten var ve orada doğru yerde: kurulumun zor
        olup olmadığı, ürünü daha yeni tanıyan biri için kritik bir sorudur. Özellikler
        sayfasına gelen kişi o soruyu çoktan geçmiştir; burada üçüncü kez okumak zorunda
        kalıyordu (ana sayfa + özellikler + destek SSS).

        Kalan sıra: ne yapıyor (hero) → beş ekran ayrıntılı (split) → küçük işler (ek) → başla.
    --}}
    @include('site.parca.ozellik-hero')
    @include('site.parca.ozellik-split')
    @include('site.parca.ozellik-ek')
    @include('site.parca.son-cagri')
</x-layouts.site>
