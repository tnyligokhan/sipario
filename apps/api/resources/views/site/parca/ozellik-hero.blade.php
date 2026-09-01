{{--
    Özellikler · hero. Deneme süresi PlanDeposu'dan.

    ── TELEFON MAKETİ KALDIRILDI (2026-09-01, kullanıcı kararı) ────────────────────────────
    Kullanıcının sözü: *"Özellikler sayfası da hiç hoşuma gitmiyor. Sayfa tasarım olarak baştan
    sona rezalet. Uygulama içinden görüntülerin sürekli gösteriliyor olması çok kötü."*

    Sayfada ALTI telefon maketi vardı: hero'da bir, beş anlatı bölümünün her birinde bir. Hepsi
    aynı çerçeve, aynı ölçek, aynı sahte veri — yani sayfa boyunca göz aynı nesneyi altı kez
    görüyordu ve hiçbirinde yeni bir şey öğrenmiyordu. Maket bir kez, ANA SAYFANIN HERO'SUNDA
    anlamlı: orada iddianın kanıtı (telefon çalıyor, kart ekranda). Beşinci tekrarında dekor.

    Yeni hero ortalanmış ve tek işi var: sayfanın ne anlatacağını söylemek, sonra okuru beş
    alanın üstünden geçirmek. Alt şerit çapa bağlantılarıdır — sayfa uzun, giriş noktası lazım.
--}}
<section class="blm kisa oz-hero">
    <div class="kap oz-hero-ic">
        <span class="blm-kulak mn"><i></i>Ne yapıyor</span>
        <h1 class="h1">Tezgâhın arkasındaki<br>bütün defterler, tek ekranda.</h1>
        <p class="gvd b oz-hero-alt">Telefon çaldığı andan akşam kasayı kapattığınız ana kadar ne oluyorsa, aşağıda beş başlıkta yazıyor.</p>
        <div class="dg-grup oz-hero-dg">
            <a class="dg dg-a" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="ozellik-hero">{{ $fiyat['deneme'] }} gün ücretsiz dene<x-site.ikon ad="ok" boy="18" kalin="2.2" /></a>
            <a class="dg dg-c" href="{{ route('site.fiyatlar') }}">Fiyata bak</a>
        </div>
        <nav class="oz-capa" aria-label="Sayfa içi bölümler">
            @foreach ($sw['tur'] as $t)
                <a href="#{{ $t['k'] }}"><x-site.ikon :ad="$t['ik']" boy="16" kalin="2" />{{ $t['ad'] }}</a>
            @endforeach
        </nav>
    </div>
</section>
