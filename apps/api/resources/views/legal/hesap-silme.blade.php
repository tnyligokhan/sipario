{{--
    Hesap ve veri silme talebi sayfası (Faz 6 — Google Play zorunlu). Play Console, hesap sistemi
    olan uygulamalar için genel erişilebilir bir "hesap/veri silme" URL'i şart koşar (data-safety
    formundaki silme talebi bu sayfaya işaret eder). BRIEF ile tutarlı: uygulamada silme butonu YOK
    (bilinçli), talep destek kanalından yürür; veri rehin alınmaz ama talep üzerine silinir; mevzuat
    saklama yükümlülükleri saklıdır. İletişim/süre bilgileri PLACEHOLDER — gerçek değerler insan işidir.

    Bu dalgada YALNIZ GÖRÜNÜM yeni tasarım diline taşındı (x-layouts.app + .card yerine
    x-layouts.site + .ys-b panosu). METİNLERE DOKUNULMADI.
--}}
<x-layouts.site
    baslik="Hesap ve veri silme talebi · Sipario"
    aciklama="Sipario hesabınızın ve verilerinizin silinmesini nasıl talep edersiniz, hangi veriler silinir, hangileri mevzuat gereği saklanır.">
    @push('bas')<link rel="canonical" href="{{ url()->current() }}">@endpush
    <section class="blm">
        <div class="kap sss-kap">
            <div class="blm-bas">
                <span class="blm-kulak mn"><i></i>Yasal</span>
                <h1 class="h1">Hesap ve Veri Silme Talebi</h1>
            </div>

            <x-site.pano etiket="Hesap ve Veri Silme Talebi" genis-ic>
                <x-site.kutu tur="sari" ikon="uyari">
                    TASLAK — iletişim bilgileri ve süreler kesinleşmeden (aşağıdaki [köşeli] alanlar) yayına alınmaz.
                </x-site.kutu>

                <div class="ys-b">
                    <h2 class="h3">Sipario hesabı nasıl açılır ve yönetilir?</h2>
                    <p class="gvd">Sipario, mevcut bir hesapla giriş yapılan bir saha uygulamasıdır. Hesaplar <strong>sipario.com.tr</strong> üzerinden veya satış/kurulum sürecinde açılır; mobil uygulamanın kendisinde kayıt, satın alma veya silme ekranı bulunmaz. Bu nedenle hesap ve veri silme talepleri, aşağıdaki destek kanalı üzerinden alınır.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Silme talebi nasıl yapılır?</h2>
                    <p class="gvd">Hesabınızın ve ona bağlı verilerin silinmesini istiyorsanız, hesabınızın kayıtlı e-posta adresinden <strong>[destek e-postası — doldurulacak]</strong> adresine (veya <strong>[destek telefonu/kanalı — doldurulacak]</strong>) “hesap silme talebi” konulu bir bildirim iletmeniz yeterlidir. Kimliğinizi doğruladıktan sonra talebiniz işleme alınır.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Hangi veriler silinir?</h2>
                    <p class="gvd">Onaylanan silme talebinde; bayi (abone) hesabınız (giriş bilgileri, kullanıcı ve cihaz kayıtları) ile Sipario üzerinde tuttuğunuz iş verileriniz (müşteriler, siparişler, veresiye defteri kayıtları) silinir. Kart bilgileri Sipario tarafından hiçbir zaman saklanmaz; ödeme bilgileri ödeme kuruluşu (iyzico) nezdindedir.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Hangi veriler ne kadar süreyle saklanabilir?</h2>
                    <p class="gvd">İlgili mevzuat gereği saklanması zorunlu olan kayıtlar (ör. fatura ve ödeme kayıtları), yasal saklama süresi boyunca <strong>[saklama süresi — doldurulacak]</strong> tutulmaya devam eder ve bu süre sonunda imha edilir. Bunun dışındaki verileriniz, talebiniz onaylandıktan sonra <strong>[azami işlem süresi — doldurulacak]</strong> içinde silinir.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Müşteri verileriniz hakkında</h2>
                    <p class="gvd">Sipario üzerinde tuttuğunuz kendi müşterilerinize ait veriler (ad, telefon, adres, konum) bakımından KVKK anlamında <strong>veri sorumlusu sizsiniz</strong>; Sipario, sizin adınıza ve talimatınızla işleyen <strong>veri işleyen</strong> konumundadır. Bu verilerin silinmesi talebiniz, veri işleyen sıfatıyla Sipario tarafından teknik olarak yerine getirilir.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Verinizi silmeden önce dışa aktarma</h2>
                    <p class="gvd">Silme öncesinde verilerinizi yedeklemek isterseniz, aynı destek kanalı üzerinden dışa aktarım (export) talep edebilirsiniz. Aboneliğiniz sona ermiş olsa dahi verileriniz otomatik silinmez; yalnızca sizin açık talebinizle silinir.</p>
                </div>

                <p class="kucuk">
                    Kişisel verilerin işlenmesine ilişkin ayrıntılı bilgi için
                    <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK Aydınlatma Metni</a>’ne bakınız.
                </p>
            </x-site.pano>
        </div>
    </section>
</x-layouts.site>
