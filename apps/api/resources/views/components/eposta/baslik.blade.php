{{--
    Pano içi ana başlık — sitedeki `.h2`nin posta karşılığı (Sora 700, sıkı harf aralığı).
    `clamp()` KULLANILMADI: posta istemcilerinin bir bölümü CSS işlevlerini ayrıştıramaz ve
    kural tümden düşer; sabit boy güvenli tarafta kalır.
--}}
<h1 class="e-murekkep" style="margin:0 0 14px 0;font-family:'Sora','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:25px;line-height:1.18;font-weight:700;letter-spacing:-0.026em;color:#16131C;">{{ $slot }}</h1>
