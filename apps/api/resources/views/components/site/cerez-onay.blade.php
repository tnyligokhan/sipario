{{--
    site.cerez-onay — KVKK uyumlu çerez rıza bandı + TERCİH MERKEZİ (2026-08-28'de büyütüldü).

    ── NE DEĞİŞTİ VE NEDEN ─────────────────────────────────────────────────────────────────
    Önceki sürüm iki düğmeli bir banttı: "yalnız zorunlu" / "ölçüme izin ver". Rıza olarak
    geçerliydi ama KVK Kurulu'nun çerez rehberinin AYDINLATMA yükünü karşılamıyordu: ziyaretçi
    neye izin verdiğini göremiyordu — hangi çerez, kim yerleştiriyor, ne kadar duruyor, hangi
    hukuki dayanakla. O bilgi yalnız ayrı bir belgede, ayrı bir sayfada duruyordu; "izin ver"
    düğmesine basan kişinin onu okumuş olma ihtimali ise düşüktü.

    Şimdi ziyaretçi kararı verdiği YERDE listeyi görüyor: kategori kategori açılan bir pencere,
    her kategoride o kategorinin çerez tablosu ve hukuki dayanağı, zorunlu olmayanlarda gerçek
    bir açma/kapama anahtarı.

    ── LİSTE BURADA YAZILI DEĞİL ───────────────────────────────────────────────────────────
    Tablolar `config/cerezler.php`den, `CerezEnvanteri` üzerinden gelir — Çerez Politikası
    belgesiyle AYNI kaynaktan. İkisini elle ayrı ayrı yazmak, ilk değişiklikte pencerede bir
    şey, belgede başka bir şey yazması demekti; KVKK açısından bu, yanlış bilgilendirmedir.

    ── SUNUCU TARAFI ÖN KAPI ───────────────────────────────────────────────────────────────
    Ziyaretçi daha önce karar verdiyse bant `hidden` basılır ve JS onu hiç açmaz. Bu, "sayfa
    yüklenirken bant bir an görünüp kayboluyor" titremesini (FOUC) önler: kararı bilen taraf
    sunucudur, çerez isteğin kendisinde zaten var.
    ⚠️ Bu kapının ÇALIŞMASI, rıza çerezinin `bootstrap/app.php`de şifrelemeden muaf olmasına
    bağlıdır — çerezi tarayıcıdaki JS yazar, Laravel onu çözemez ve muafiyet olmadan `null`
    görürdü (yani kapı sessizce hiç işlemezdi).

    ── KABUL VE RET AYNI AĞIRLIKTA ─────────────────────────────────────────────────────────
    KVK Kurulu'nun çerez rehberi, reddi zorlaştıran tasarımı geçerli rıza saymaz. İki düğme de
    aynı boyda, aynı satırda ve ret düğmesi ilk sırada. "Yalnız zorunlu çerezler" metni, ret
    seçeneğinin ne anlama geldiğini de söylüyor — "Reddet" tek başına ziyaretçiye neyi
    kaybettiğini sormaya bırakır. Üçüncü düğme ("Çerezleri yönet") pencereyi açar ve ne kabulün ne de
    reddin önüne geçer: ikisi de tek tıklık kalır. Rehberin karşı olduğu desen, reddi ayarların
    ARKASINA saklamaktır — burada saklanan bir şey yok.

    ── ERİŞİLEBİLİRLİK ─────────────────────────────────────────────────────────────────────
    Bant: `role="region"` + `aria-label` → ekran okuyucu gezinilebilir bir bölge olarak duyurur.
    `aria-live` KULLANILMADI — bant sayfa yüklendiğinde zaten oradadır, sonradan gelen bir duyuru
    değildir; canlı bölge yapmak okuyucuyu içeriğin ortasında kesip bandı okuturdu.
    Pencere: `role="dialog"` + `aria-modal` + `aria-labelledby`; odak tuzağı ve Esc ile kapatma
    public/js/cerez.js'te.
--}}
@php
    $envanter = new \App\Support\Cerez\CerezEnvanteri;
    $sor = $envanter->rizaGerekiyorMu();
    $kararVerilmis = $sor && $envanter->kararVerilmisMi(request()->cookie($envanter->cerezAdi()));
    $kategoriler = $sor ? $envanter->kategoriler() : [];

    // Dizi `@json`ın İÇİNDE kurulmaz — Blade yönergesi argümanı parantez sayarak keser ve çok
    // satırlı dizi literalini yanlış yerden böler (legal/show.blade.php'de 500'le ölçüldü).
    $cerezAyari = $sor ? $envanter->tarayiciAyari() : [];
@endphp

@if ($sor)
    <div id="cerez-band" class="cerez" role="region" aria-label="Çerez tercihleri" @if($kararVerilmis) hidden @endif>
        <div class="kap cerez-ic">
            <p class="cerez-m">
                Sitenin çalışması için gereken çerezleri kullanıyoruz. Bunun dışında, hangi sayfaların
                işe yaradığını görebilmek için <strong>ölçüm çerezi</strong> kullanmak istiyoruz —
                ama yalnız siz izin verirseniz. İzin vermezseniz site aynen çalışır, hiçbir şey
                eksilmez. Ayrıntı: <a href="{{ route('legal.show', 'cerez-politikasi') }}">Çerez Politikası</a>.
            </p>
            <div class="cerez-dg">
                <button type="button" id="cerez-ret" class="dg dg-c">Yalnız zorunlu çerezler</button>
                <button type="button" id="cerez-yonet" class="dg dg-c">Çerezleri yönet</button>
                <button type="button" id="cerez-kabul" class="dg dg-a">Ölçüme izin ver</button>
            </div>
        </div>
    </div>

    {{--
        TERCİH MERKEZİ. Sunucuda basılır (JS ile kurulmaz) ve üç sebebi var:
          1. Liste sunucu tarafı tek kaynaktan gelir; JS'in ikinci bir kopyasını taşıması
             gerekmez — sapma ihtimali kalmaz.
          2. CSP `script-src 'self'`; DOM'u dizeden kuran bir betik yazmaya gerek yok.
          3. JS çalışmasa bile ziyaretçi listeyi Çerez Politikası'nda AYNI kaynaktan görür;
             burada da HTML olarak vardır, yalnız gizlidir.
    --}}
    <div id="cerez-pencere" class="diyalog-fon cerez-fon" hidden role="dialog" aria-modal="true" aria-labelledby="cerez-pencere-b">
        <div class="diyalog cerez-pencere">
            <div class="diyalog-bas">
                <h2 class="h3" id="cerez-pencere-b">Çerez tercihleri</h2>
                <button type="button" class="diyalog-x" id="cerez-p-kapat" aria-label="Pencereyi kapat">✕</button>
            </div>

            <div class="diyalog-ic cerez-p-ic">
                <p class="gvd cz-giris">Aşağıda bu sitede kullanılan çerezlerin tamamı yazılıdır. Zorunlu olanlar sitenin çalışması için gereklidir ve kapatılamaz; diğerleri <strong>yalnız siz açarsanız</strong> çalışır. Tercihinizi istediğiniz an bu pencereden değiştirebilir veya geri alabilirsiniz.</p>

                @foreach ($kategoriler as $anahtar => $kategori)
                    <section class="cz-kat">
                        <div class="cz-kat-bas">
                            {{--
                                Başlık bir düğmedir (accordion). `aria-expanded` + `aria-controls`
                                çifti olmadan ekran okuyucu, tıklamanın altta bir şey açtığını
                                söyleyemez — "başlık gibi görünen tıklanabilir şey" olarak kalırdı.
                            --}}
                            <button type="button" class="cz-kat-ac" aria-expanded="false" aria-controls="cz-govde-{{ $anahtar }}">
                                <span class="cz-ok" aria-hidden="true"></span>
                                <span class="cz-kat-ad">{{ $kategori['ad'] }}</span>
                                <span class="cz-rozet">{{ count($kategori['cerezler']) }} çerez</span>
                            </button>

                            @if ($kategori['zorunlu'])
                                {{-- Zorunlu kategoride anahtar YOK. Kapatılamayan bir anahtar
                                     göstermek, ziyaretçiye olmayan bir seçim sunmaktır. --}}
                                <span class="cz-sabit">Her zaman açık</span>
                            @else
                                <label class="cz-svc">
                                    <input type="checkbox" class="cz-svc-g" data-cerez-kat="{{ $anahtar }}"
                                           aria-label="{{ $kategori['ad'] }} — aç/kapat">
                                    <span class="cz-svc-y" aria-hidden="true"></span>
                                    <span class="cz-svc-m" data-acik="Açık" data-kapali="Kapalı" aria-hidden="true"></span>
                                </label>
                            @endif
                        </div>

                        <div class="cz-govde" id="cz-govde-{{ $anahtar }}" hidden>
                            <p class="cz-ozet">{{ $kategori['ozet'] }}</p>
                            <p class="cz-dayanak"><b>Hukuki dayanak:</b> {{ $kategori['dayanak'] }}</p>
                            <div class="ys-tablo-sar cz-tablo-sar">
                                <table class="ys-tablo cz-tablo">
                                    <thead><tr><th>Çerez</th><th>Ne işe yarar</th><th>Süre</th><th>Kim yerleştirir</th></tr></thead>
                                    <tbody>
                                        @foreach ($kategori['cerezler'] as $cerez)
                                            <tr>
                                                <td><code>{{ $cerez['ad'] }}</code></td>
                                                <td>{{ $cerez['ne'] }}</td>
                                                <td>{{ $cerez['sure'] }}</td>
                                                <td>{{ $cerez['saglayici'] }} <span class="cz-taraf">({{ $cerez['taraf'] }})</span></td>
                                            </tr>
                                        @endforeach
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </section>
                @endforeach

                <p class="cz-yok"><b>Kullanmadıklarımız:</b> {{ implode(', ', $envanter->kullanilmayanlar()) }}. Bu liste bir gün değişirse aynı gün burası da değişir.</p>
                <p class="cz-alt-baglanti"><a href="{{ route('legal.show', 'cerez-politikasi') }}">Çerez Politikası</a> · <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK Aydınlatma Metni</a></p>
            </div>

            <div class="diyalog-alt cerez-p-alt">
                <button type="button" id="cerez-p-ret" class="dg dg-c k">Yalnız zorunlu</button>
                <button type="button" id="cerez-p-kaydet" class="dg dg-b k">Seçimimi kaydet</button>
                <button type="button" id="cerez-p-kabul" class="dg dg-a k">Tümünü kabul et</button>
            </div>
        </div>
    </div>

    {{--
        Ayar JSON kanalıyla taşınır (depodaki yerleşik desen — bkz. public/js/alpine.js belge
        başlığı). `type="application/json"` bloğu ÇALIŞTIRILMAZ ama CSP onu yine `script-src`
        altında değerlendirir; nonce olmadan blok reddedilir ve betik ayarı hiç okuyamaz.
    --}}
    <script type="application/json" id="cerez-ayar" nonce="{{ \Illuminate\Support\Facades\Vite::cspNonce() }}">
        @json($cerezAyari, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
    </script>
    {{-- `defer`: sayfanın çizilmesini geciktirmez. Ölçüm betiğinden ÖNCE gelmesi zorunludur
         (defer'li betikler belge sırasına göre çalışır) — olcum.js rıza durumunu buradan sorar. --}}
    <script src="{{ asset('js/cerez.js') }}" defer></script>
@endif
