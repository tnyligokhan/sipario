{{--
    KimlikKabuk — giriş/kayıt/parola sıfırlama sayfalarının iki panelli kabuğu. site-ciplak
    layout'u içinde kullanılır (menüsüz).

    ── ⚠️ UYDURMA VERİ BURADA DA VARDI VE BİR TUR GÖZDEN KAÇTI (2026-08-19) ─────────────────
    Sol panel şunları basıyordu: "Defteri bıraktık. Ay sonunda tahsil edemediğimiz para 12
    binden 3 bine düştü." — Hasan Yıldırım, Yıldırım Su · Antalya; ve altında "1.240 işletme /
    6 dk sipariş başına / %31 daha az kayıp".

    Bunlar ana sayfadan silinen uydurma verinin TA KENDİSİYDİ. Silme işlemi
    `site/parca/_temsili-veri.php` dizilerini boşaltarak yapılmıştı; ama bu bileşen o dosyayı
    HİÇ OKUMUYOR — kendi içine gömülü bir kopya taşıyordu (yukarıdaki eski belge başlığı bunu
    açıkça yazıyordu: "bileşenin kendi içine gömülü tasarım verisidir"). Sonuç: ana sayfa
    temizlendi, ama uydurma yorum ve rakamlar KAYIT ve GİRİŞ ekranlarında yaşamaya devam etti —
    yani satın alma hunisinin tam ortasında, en kritik iki ekranda.

    DERS: "veriyi tek kaynaktan sil" yeterli değil; aynı içeriğin ELLE KOPYALANMIŞ ikinci bir
    örneği olabilir. Silme sonrası doğrulama, veri dosyasında değil EKRANDA yapılmalı.

    Yerine ne kondu: uydurma sosyal kanıt yerine, sahibi olduğumuz ve doğrulanabilir üç söz.
    Bunlar bir "istatistik" gibi görünmüyor çünkü değiller — ürünün kendi kuralları.
--}}
@props(['kulak' => null, 'baslik', 'aciklama' => null, 'genis' => false, 'altYazi' => null])
<main class="kimlik">
    <aside class="kimlik-sol gece">
        <a class="kimlik-marka" href="{{ Route::has('site.ana') ? route('site.ana') : url('/') }}">
            <x-site.marka boy="38" koyu />
        </a>
        <div class="kimlik-govde">
            <p class="h2 kimlik-soz">Telefon çaldığında müşteriniz ekranda: adı, adresi, borcu ve en son ne aldığı.</p>
            <div class="kimlik-kim">
                <span class="kucuk">Paket servisi yapan işletmeler için sipariş, kurye ve veresiye defteri.</span>
            </div>
        </div>
        <div class="kimlik-alt">
            {{-- Üçü de doğrulanabilir ve bizim elimizde: kart istemiyoruz (ödeme akışı
                 havale/elden), veri silinmiyor (sözleşmede yazılı), otomatik yenileme yok
                 (sözleşmede yazılı). Uydurma bir orana benzemesinler diye yüzde/adet
                 biçiminde DEĞİL, düz ifade olarak yazıldılar.

                 ⚠️ ORTADAKİ KUTU DEĞİŞTİ (2026-09-01): "Türkiye / veriler burada durur"
                 yazıyordu ve YANLIŞTI — sunucu Hostinger'da, Frankfurt'ta (ölçüldü). Yerine
                 aynı korkuya cevap veren ama doğru olan bir söz kondu: veri silinmiyor.
                 Barındırmanın nerede olduğu bir giriş ekranı rozetine sığmaz; yeri hukuk
                 metinleri ve Hakkımızda sayfası. --}}
            @foreach ([['Kart yok', 'denemede istemiyoruz'], ['Veri silinmez', 'abonelik bitse de durur'], ['Taahhüt yok', 'istediğinizde bırakın']] as [$v, $b])
                <div class="kimlik-k">
                    <b>{{ $v }}</b><span class="mn k">{{ $b }}</span>
                </div>
            @endforeach
        </div>
    </aside>
    <section class="kimlik-sag">
        <div class="kimlik-form {{ $genis ? 'genis' : '' }}">
            @if($kulak)<span class="blm-kulak mn"><i></i>{{ $kulak }}</span>@endif
            <h1 class="h1 kimlik-h1">{{ $baslik }}</h1>
            @if($aciklama)<p class="gvd kimlik-lead">{{ $aciklama }}</p>@endif
            {{ $slot }}
        </div>
        @if($altYazi)<div class="kimlik-dip kucuk">{{ $altYazi }}</div>@endif
    </section>
</main>
