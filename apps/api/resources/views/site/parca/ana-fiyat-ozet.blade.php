{{--
    Ana sayfa · Fiyat özeti (09-sw-ana.jsx · FiyatOzetBlm).

    Fiyatların tamamı PlanDeposu'dan gelir (bkz. site/parca/_kur.php) — sabit yazılmaz.

    TEK PAKET (2026-08-05):
      · Tasarımın ikinci kartı ("Kurumsal") kaldırıldı — `plans` tablosu tek satırlıdır.
      · Kart artık kapsamın TAMAMINI basıyor: "+N özellik daha" satırı, okuyucuyu fiyat sayfasına
        göndermek için vardı; o sayfa artık menüde gösterilmiyor, teaser sahipsiz kalırdı.
      · "Paketleri karşılaştır" bağlantısı kaldırıldı (aynı sebep: /fiyatlar gösterilmiyor).
      · Ek kurye paketleri KATALOGDAN basılır; katalog boşsa bölüm hiç görünmez.

    KAYNAKTAN AYRILAN TEK CÜMLE: tasarımın "Yıllık … kartla 12 taksite kadar" notu, kartla ödemenin
    henüz AÇIK OLMADIĞI kararıyla çelişiyordu (OKU-BENI çelişki tablosu: iyzico ertelendi). Aynı
    tasarımın fiyat sayfasındaki karşılığı ("havale veya elden · KDV dahil") kullanıldı.
--}}
@php
    $p = $sw['plan']['sipario'];
    // Metnin İÇİNDE @if kullanılamaz: Blade yönergeyi yalnız kelime sınırında tanır, "ödemede@if"
    // sessizce ham metin olarak basılır (@endif ise derlenir → sözdizimi hatası). Koşul burada kurulur.
    $yillikAlt = 'yıllık ödemede'.($fiyat['hediyeAy'] > 0 ? ' · '.$fiyat['hediyeAy'].' ay hediye' : '');
@endphp
{{-- `id="fiyat"`: /fiyatlar menüden kalktığı için "fiyata bak" çağrıları artık buraya çapalanıyor. --}}
<section class="blm kagit2" id="fiyat">
    <div class="kap">
        <x-site.blm-bas kulak="Fiyat" baslik="Tek plan. Gizli kalem yok."
            aciklama="Kaç müşteriniz olduğuna, kaç sipariş girdiğinize bakmıyoruz. Fiyat aşağıda yazan fiyat." />
        <div class="fo-grid tek">
            <x-site.pano class="fo fo-vurgu" etiket="Tek plan" genis-ic>
                <div class="fo-bas">
                    <span class="h2">{{ $p['ad'] }}</span>
                    <p class="gvd">{{ $p['ozet'] }}</p>
                </div>
                <div class="fo-fiyat">
                    <span class="rakam">{{ $fiyat['yillikAy'] }}</span>
                    <span class="fo-donem">/ ay<br><small>{{ $yillikAlt }}</small></span>
                </div>
                <p class="kucuk fo-not">Aylık ödemede {{ $fiyat['aylik'] }}/ay. Yıllık {{ $fiyat['yillikToplam'] }} · havale veya elden · KDV dahil.</p>
                <ul class="fo-liste">
                    @foreach ($p['kapsam'] as $x)
                        <li><x-site.ikon ad="onay" boy="16" kalin="2.6" renk="var(--yesil)" />{{ $x['t'] }}</li>
                    @endforeach
                </ul>
                <a class="dg dg-a tam" href="{{ route('subscription.register') }}" data-olcum="sipario_deneme_tik" data-olcum-etiket="fiyat-karti">{{ $p['cta'] }}</a>
                <span class="kucuk fo-alt">{{ $p['ctaAlt'] }}</span>
            </x-site.pano>
        </div>

        {{-- Ek kurye paketleri: addon_packages · type=courier · aktif olanlar (EkPaketServisi).
             Hesap panelindeki "Ek paket" ekranı aynı servisten okur — iki yerde iki fiyat olmaz.
             Katalog boşsa bölüm hiç basılmaz; rakam uydurulmaz. --}}
        @if (! empty($fiyat['kuryePaketleri']))
            <div class="fiyat-ek">
                <x-site.kutu tur="mor" ikon="bilgi">
                    <b>Plana {{ $fiyat['kurye'] }} kurye hesabı dahil.</b>
                    Daha fazla kurye çalıştırıyorsanız ek paketle eklersiniz:
                    {{ collect($fiyat['kuryePaketleri'])->map(fn ($k) => '+'.$k['adet'].' kurye '.$k['fiyat'])->join(' · ') }}.
                    Tek seferlik ödenir, hesap hakkınız kalıcı olarak artar — aylık ücret değildir.
                </x-site.kutu>
            </div>
        @endif
    </div>
</section>
