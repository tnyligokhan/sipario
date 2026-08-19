{{--
    Hesap ve veri silme talebi sayfası (Faz 6 — Google Play zorunlu). Play Console, hesap sistemi
    olan uygulamalar için genel erişilebilir bir "hesap/veri silme" URL'i şart koşar; data-safety
    formundaki silme talebi bu sayfaya işaret eder.

    ── 2026-08-19 · METİN YENİLENDİ ─────────────────────────────────────────────────────────
    Önceki sürüm dört yerde "[doldurulacak]" yazıyordu ve üçü aslında BİZİM VERECEĞİMİZ karardı,
    avukatın değil: destek adresi (config'te zaten var), saklama süresi (VUK/TTK'da yazılı) ve
    azami işlem süresi (KVKK m.13/2 → 30 gün). Yani sayfa, cevabı elimizde olan soruları
    cevapsız bırakıyordu. Şimdi sürelerin her biri dayanağıyla yazılı; künye ise `x-legal.deger`
    ile config'ten okunuyor, gerçek değer girildiği gün kendiliğinden düzeliyor.

    BRIEF ile tutarlılık korundu: uygulamada silme butonu YOK (bilinçli), talep destek
    kanalından yürür; veri rehin alınmaz ama kendiliğinden de silinmez.
--}}
<x-layouts.site
    baslik="Hesap ve veri silme talebi · Sipario"
    aciklama="Sipario hesabınızın ve verilerinizin silinmesini nasıl talep edersiniz, hangi veriler silinir, hangileri mevzuat gereği saklanır, ne kadar sürer.">
    @push('bas')
        <link rel="canonical" href="{{ url()->current() }}">
        <meta property="og:type" content="article">
        <meta property="og:title" content="Hesap ve veri silme talebi · Sipario">
        <meta property="og:url" content="{{ url()->current() }}">
    @endpush
    <section class="blm">
        <div class="kap sss-kap">
            <div class="blm-bas">
                <span class="blm-kulak mn"><i></i>Yasal</span>
                <h1 class="h1">Hesabınızı ve verilerinizi sildirmek</h1>
                <p class="gvd b">Ayrılmak isterseniz kimseyi ikna etmenize gerek yok. Bir e-posta yeter — aşağıda ne olacağı adım adım yazılı.</p>
            </div>

            <x-site.pano etiket="Hesap ve veri silme talebi" genis-ic>
                {{--
                    Bu sayfa da bir HUKUK METNİDİR (KVKK m.7/m.13 kapsamında silme talebini ve
                    mevzuattan doğan saklama istisnalarını anlatıyor), dolayısıyla diğer on
                    belgeyle aynı avukat onayı kapısına tabidir. Eski "TASLAK — iletişim ve
                    süreler kesinleşmeden yayına alınmaz" kutusu YERİNİ BUNA BIRAKTI: o kutunun
                    işaret ettiği eksikler (destek adresi, saklama süresi, işlem süresi) bu
                    vardiyada gerçek değerleriyle dolduruldu, geriye yalnız hukuk onayı kaldı.
                --}}
                <x-legal.uyari />

                <div class="ys-b">
                    <h2 class="h3">Önce bilmeniz gereken: silmek zorunda değilsiniz</h2>
                    <p class="gvd">Aboneliğiniz bittiğinde verileriniz <strong>kendiliğinden silinmez</strong>. Hesap yeni kayıt almayı durdurur, defteriniz olduğu yerde durur ve abone olduğunuz gün eksiksiz geri gelir. Yani "bir süre ara vermek" için hesabı sildirmenize gerek yok.</p>
                    <p class="gvd">Gerçekten silinmesini istiyorsanız, aşağıdaki yol geçerlidir ve talebiniz sorgusuz uygulanır.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Silmeden önce verinizi yanınıza alın</h2>
                    <p class="gvd">Silme geri alınamaz. Müşteri listenizi, sipariş geçmişinizi ve veresiye defterinizi Excel olarak isteyebilirsiniz; aynı destek adresine "dışa aktarım istiyorum" yazmanız yeterli, ücretsizdir. Aboneliğiniz sona ermiş olsa bile bu kapı açıktır.</p>
                    <p class="gvd">Dosyayı aldıktan sonra silme talebinizi iletmenizi öneririz.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Talebi nasıl iletirsiniz?</h2>
                    <p class="gvd">Hesabınızın <strong>kayıtlı e-posta adresinden</strong> <x-legal.deger anahtar="support_email" ad="destek e-posta adresi" /> adresine "hesap silme talebi" konulu bir e-posta gönderin. İşletme adınızı ve firma kodunuzu yazarsanız işlem hızlanır.</p>
                    <p class="gvd">Kayıtlı adresten göndermeniz kimlik doğrulaması yerine geçer. Başka bir adresten yazarsanız kimliğinizi ayrıca doğrulamamız gerekir; bu, sizin verinizin başka birine teslim edilmemesi içindir.</p>
                    <p class="gvd">Mobil uygulamada silme düğmesi yoktur. Bu bilinçli bir tercihtir: tek bir yanlış dokunuşla bir işletmenin bütün defterinin yok olabilmesi, sahada kaybedilecek en pahalı şeydir.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Neler silinir?</h2>
                    <p class="gvd">Onaylanan talepte; bayi hesabınız (giriş bilgileri, kullanıcı ve cihaz kayıtları) ile Sipario'da tuttuğunuz iş verileriniz (müşteriler, adresler, siparişler, teslimatlar, veresiye defteri ve kasa kayıtları) silinir.</p>
                    <p class="gvd">Kart bilgileri Sipario tarafından hiçbir zaman saklanmaz; kartlı ödeme kullanıldığı hâllerde bu bilgiler ödeme kuruluşu nezdindedir.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Neler silinemez ve neden?</h2>
                    <p class="gvd">Mevzuat, bazı kayıtların belirli süreler boyunca saklanmasını zorunlu kılar. Bunlar talebinize rağmen silinmez, süre dolduğunda imha edilir:</p>
                    <ul class="ys-liste">
                        <li><b>Fatura, ödeme ve muhasebe kayıtları — 5 yıl.</b> Dayanak: 213 sayılı Vergi Usul Kanunu m.253.</li>
                        <li><b>Ticari defter niteliğindeki kayıtlar — 10 yıl.</b> Dayanak: 6102 sayılı Türk Ticaret Kanunu m.82.</li>
                        <li><b>Trafik ve erişim kayıtları (log) — 2 yıl.</b> Dayanak: 5651 sayılı Kanun ve ikincil mevzuatı.</li>
                    </ul>
                    <p class="gvd">Bu kayıtlar iş verinizi değil, aramızdaki ticari ilişkinin izini taşır; müşteri listeniz veya defteriniz bu kapsamda değildir.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Ne kadar sürer?</h2>
                    <p class="gvd">Talebiniz en geç <strong>30 gün</strong> içinde sonuçlandırılır (KVKK m.13/2) ve size yazılı olarak teyit edilir. Uygulamada işlem genellikle birkaç iş günü içinde tamamlanır. İşlem ücretsizdir.</p>
                    <p class="gvd">Yedek ortamlarındaki kopyalar, yedek döngüsünün tamamlanmasıyla birlikte en geç <strong>90 gün</strong> içinde ortadan kalkar. Bu süre boyunca veriye erişim kapalıdır ve yalnız felaket kurtarma amacıyla saklanır.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Müşterilerinizin verisi hakkında</h2>
                    <p class="gvd">Sipario'da tuttuğunuz kendi müşterilerinize ait veriler (ad, telefon, adres, konum) bakımından KVKK önünde <strong>veri sorumlusu sizsiniz</strong>; Sipario, sizin adınıza ve talimatınızla işleyen <strong>veri işleyen</strong> konumundadır. Bu nedenle o verilerin silinmesi kararını siz verirsiniz, biz teknik olarak uygularız.</p>
                    <p class="gvd">Bir müşteriniz size başvurup verisinin silinmesini isterse, talebi veri sorumlusu olarak siz değerlendirirsiniz. Kararınızı bize ilettiğinizde uygularız. Ayrıntı: <a href="{{ route('legal.show', 'veri-isleyen') }}">Veri İşleyen Sözleşmesi (Ek-1)</a>.</p>
                </div>

                <div class="ys-b">
                    <h2 class="h3">Ekip hesaplarını silmek</h2>
                    <p class="gvd">Tek bir kurye veya operatör hesabını kaldırmak için tüm hesabınızı sildirmenize gerek yok — ekip hesaplarını hesap panelinizdeki <a href="{{ route('site.hesap', ['bolum' => 'ekip']) }}">Ekip</a> bölümünden kendiniz kapatabilirsiniz.</p>
                </div>

                <p class="kucuk">
                    Kişisel verilerin işlenmesine ilişkin ayrıntılı bilgi için
                    <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK Aydınlatma Metni</a>'ne,
                    haklarınızı kullanma yolu için
                    <a href="{{ route('legal.show', 'kvkk-basvuru') }}">İlgili Kişi Başvuru Formu</a>'na bakabilirsiniz.
                </p>
            </x-site.pano>
        </div>
    </section>
</x-layouts.site>
