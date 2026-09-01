{{--
    sipario.com.tr · ANA SAYFA (tasarım: _kaynak/web/09-sw-ana.jsx · AnaSayfa).

    Livewire DEĞİL, düz Blade: içerik statiktir, sunucu durumu taşımaz. Ürün turunun sekmeleri ve
    SSS akordiyonu Alpine ile istemcide çözülür.

    Layout `koyu` kipinde: hero koyu zeminli ve tam genişlikte nav'ın altına akar (<main> "ic"
    sınıfını ALMAZ — bkz. x-layouts.site başlığındaki not).

    Bölümler `site/parca/` altına ayrıldı; sayfa dosyaları 500 satırın altında kalsın diye.
--}}
@inject('planlar', 'App\Abonelik\PlanDeposu')
@inject('ekPaketler', 'App\Abonelik\EkPaketServisi')
@php
    ['sw' => $sw, 'tmsl' => $tmsl, 'tl' => $tl, 'fiyat' => $fiyat]
        = (require resource_path('views/site/parca/_kur.php'))($planlar, $ekPaketler);
@endphp

{{--
    BAŞLIK KALIBI — bütün site aynı: "<Sayfa adı> | Sipario". Ana sayfada sayfa adının yerini
    ürünün tek cümlelik tanımı alır. Başlık bir anahtar kelime listesi DEĞİLDİR: insan gözü arama
    sonucunda virgülle dizilmiş kelimeleri okumaz, tarar ve geçer.
--}}
<x-layouts.site koyu
    baslik="Paket servisi için sipariş, kurye ve veresiye uygulaması | Sipario"
    :aciklama="'Telefon çaldığında müşteriniz ekranda: kim aradı, nerede oturuyor, ne kadar borcu var. Restoran, market, pastane ve bayiler için sipariş, kurye takibi ve veresiye defteri — internet gitse de çalışır. '.$fiyat['deneme'].' gün ücretsiz.'">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    {{--
        ── SAYFA SIRASI, ZİYARETÇİNİN SORU SIRASIDIR (2026-08-19) ──────────────────────────
        Ana sayfa dokuz bölümdü ve iki büyük tekrar taşıyordu:

        1. "Dert" bölümü (Alacak defterde kalıyor · Aynı soruları soruyorsunuz · Kasa tutmuyor)
           ile "Ürün turu" AYNI ÜÇ ŞEYİ anlatıyordu — biri sorun, öbürü çözüm diliyle. Üstelik
           dert kartlarının kendi içinde zaten bir "çözüm" satırı vardı, yani bölüm tek başına
           ikisini de söylüyordu. Ürün turu gelince aynı üç cümle üçüncü kez okunuyordu.
           **Dert bölümü kaldırıldı** (dosya duruyor, sayfadan çıkarıldı).

        2. Ürün turu ANA SAYFADA beş ekranı sekme sekme, ÖZELLİKLER SAYFASINDA aynı beş ekranı
           bir kez daha gezdiriyordu. Ana sayfa üçe indi, beşin tamamı Özellikler'de kaldı.

        Kalan sıra, esnafın kafasındaki soru sırasıdır:
          Bu ne? (hero) → Nasıl görünüyor? (tur) → Kurmak zor mu? (kurulum) → Kaç para? (fiyat)
          → Güvenilir mi? (güvence) → Sorum var (SSS) → Tamam (son çağrı)

        `ana-kanit` ve `ana-yorum` sayfadan ÇIKARILDI, çünkü besledikleri veri boş (uydurma
        kullanım rakamları ve müşteri yorumları 2026-08-19'da silindi). Boş dizide zaten hiçbir
        şey basmıyorlardı; `@include` satırlarını bırakmak, sayfanın gerçekte on bölümü varmış
        gibi görünmesine yol açıyordu. Gerçek veri geldiği gün iki satır geri eklenir.
    --}}
    @include('site.parca.ana-hero')
    @include('site.parca.ana-tur')
    @include('site.parca.adim')
    @include('site.parca.ana-fiyat-ozet')
    @include('site.parca.ana-guvence')
    @include('site.parca.ana-sss-ozet')
    @include('site.parca.son-cagri')
</x-layouts.site>
