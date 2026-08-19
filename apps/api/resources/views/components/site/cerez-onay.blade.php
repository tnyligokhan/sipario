{{--
    site.cerez-onay — çerez rıza bandı.

    ── NE ZAMAN BASILIR ────────────────────────────────────────────────────────────────────
    Yalnız ölçüm gerçekten kuruluysa (config/analitik.php'nin kimlik + ortam kapıları).
    Ölçüm kapalıyken band basmak, olmayan bir çerez için rıza istemek olurdu — ziyaretçiyi
    boş yere rahatsız eder ve metnin doğruluğunu zedeler.

    ── SUNUCU TARAFI ÖN KAPI ───────────────────────────────────────────────────────────────
    Ziyaretçi daha önce karar verdiyse band `hidden` basılır ve JS onu hiç açmaz. Bu, "sayfa
    yüklenirken band bir an görünüp kayboluyor" titremesini (FOUC) önler: kararı bilen taraf
    sunucudur, çerez isteğin kendisinde zaten var.

    ── KABUL VE RET AYNI AĞIRLIKTA ─────────────────────────────────────────────────────────
    KVK Kurulu'nun çerez rehberi, reddi zorlaştıran tasarımı geçerli rıza saymaz. Bu yüzden iki
    düğme de aynı boyda, aynı satırda ve ret düğmesi ilk sırada. "Yalnız zorunlu çerezler"
    metni, ret seçeneğinin ne anlama geldiğini de söylüyor — "Reddet" tek başına ziyaretçiye
    neyi kaybettiğini sormaya bırakır.

    ── ERİŞİLEBİLİRLİK ─────────────────────────────────────────────────────────────────────
    `role="region"` + `aria-label`: ekran okuyucu bandı gezinilebilir bir bölge olarak duyurur.
    `aria-live` KULLANILMADI — band sayfa yüklendiğinde zaten oradadır, sonradan gelen bir
    duyuru değildir; canlı bölge yapmak okuyucuyu içeriğin ortasında kesip bandı okuturdu.
--}}
@php
    $acik = (bool) config('analitik.enabled') && (string) config('analitik.measurement_id') !== '';
    $kararVerilmis = request()->cookie((string) config('analitik.riza_cerezi')) !== null;
@endphp

@if ($acik)
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
                <button type="button" id="cerez-kabul" class="dg dg-a">Ölçüme izin ver</button>
            </div>
        </div>
    </div>
@endif
