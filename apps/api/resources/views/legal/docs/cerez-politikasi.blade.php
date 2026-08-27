{{--
    ÇEREZ POLİTİKASI — 2026-08-19 tam metin, 2026-08-28'de listeler envantere bağlandı.

    ── ESKİ METİN ARTIK DOĞRU DEĞİLDİ ───────────────────────────────────────────────────────
    Önceki sürüm şunu diyordu: "Sitemizde reklam, pazarlama veya analitik amaçlı hiçbir çerez ya
    da üçüncü taraf izleyici bulunmaz." O cümle YAZILDIĞI GÜN doğruydu ve doğru olduğu için de
    değerliydi. 2026-08-19'da siteye Google Analytics 4 eklendi — yani cümle, kod değiştiği anda
    YALANA dönüştü. Belge güncellenmeseydi, sitede hem izleyici çalışıyor hem de politika
    "izleyici yok" diyor olacaktı; bu, KVKK açısından yanlış bilgilendirme, reklam mevzuatı
    açısından yanıltıcı beyandır.

    ── TABLOLAR ARTIK ELLE YAZILMIYOR (2026-08-28) ──────────────────────────────────────────
    Aynı hata bir kez daha, daha sessiz biçimde olmuştu: belge `sipario_session` diyordu, gerçek
    çerezin adı `sipario-session`di (config/session.php → APP_NAME slug'ı + "-session"). Yani
    ziyaretçi politikadaki adı tarayıcısında arasa BULAMAZDI. Sebep, listenin iki yerde birden
    (belgede ve rıza penceresinde) elle tutulmasıydı.

    Şimdi tek kaynak var: `config/cerezler.php` → `App\Support\Cerez\CerezEnvanteri`. Çerez adı,
    süresi ve kim tarafından yerleştirildiği çalışma anında çözülür; oturum çerezinin adı ve
    ömrü Laravel'in kendi ayarından okunur. Rıza penceresi (components/site/cerez-onay.blade.php)
    AYNI listeyi basar — ikisinin sapması artık mümkün değil.

    ── KVK KURULU'NUN ÇEREZ YAKLAŞIMI ───────────────────────────────────────────────────────
    Kurul'un çerez uygulamalarına ilişkin rehberi iki grubu ayırır:
      • ZORUNLU (kesinlikle gerekli) çerezler — hizmetin çalışması için şart; açık rıza aranmaz,
        yalnız bilgilendirme yeterlidir.
      • DİĞER çerezler (analitik, reklam, kişiselleştirme) — AÇIK RIZA gerekir ve rıza ÖNCEDEN
        alınmalıdır. "Siteyi kullanmaya devam ederseniz kabul etmiş sayılırsınız" geçerli bir
        rıza değildir.
    Bu yüzden analitik çerez, pencerede ONAY VERİLENE KADAR HİÇ ÇALIŞMAZ (varsayılan: reddedilmiş).
    Uygulaması: components/site/cerez-onay.blade.php + public/js/cerez.js + public/js/olcum.js.

    ── ÖLÇÜM KAPALI KURULUMDA NE OLUR ───────────────────────────────────────────────────────
    Ölçüm kategorisi `kosul => 'analitik'` taşır: ölçüm kapalıysa kategori envanterden düşer ve
    bu belgede DE görünmez. Doğru olan budur — kurulmayan bir çerezi ilan etmek, ziyaretçiye
    olmayan bir riski anlatmaktır. Zorunlu çerezler her hâlükârda listelenir.
--}}
@php
    $envanter = new \App\Support\Cerez\CerezEnvanteri;
    $kategoriler = $envanter->kategoriler();
    $olcumVar = array_key_exists('olcum', $kategoriler);
@endphp

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">Kısaca</h2>
    <p class="gvd">Sitemiz <strong>zorunlu</strong> çerezleri kullanır: oturumunuzu açık tutar ve formları güvenli hâle getirir; bunlar olmadan giriş yapamazsınız.@if ($olcumVar) Bunun dışında bir <strong>ölçüm</strong> çerezi vardır ve <strong>yalnız siz izin verirseniz</strong> çalışır. İzin vermezseniz hiçbir ölçüm isteği gönderilmez.@endif</p>
    <p class="gvd">Reklam çerezi, sosyal medya izleyicisi veya üçüncü taraf reklam ağı <strong>kullanmıyoruz</strong>. Yazı tiplerimiz dahil tüm görsel kaynaklar kendi sunucumuzdan gelir.</p>
    @if ($envanter->rizaGerekiyorMu())
        <p class="gvd">Tercihinizi şu anda değiştirmek isterseniz: <button type="button" class="ys-cerez-ac" data-cerez-ac>çerez tercihleri penceresini açın</button>.</p>
    @endif
</div>

<div class="ys-b">
    <h2 class="h3">1. Çerez nedir?</h2>
    <p class="gvd">Çerezler, ziyaret ettiğiniz internet siteleri tarafından tarayıcınıza kaydedilen küçük metin dosyalarıdır. Sitenin sizi hatırlamasını (ör. giriş yapmış olduğunuzu) sağlar. İşbu politika, <x-legal.deger anahtar="title" ad="ticaret unvanı" /> ("Sipario") tarafından işletilen sipario.com.tr sitesinde kullanılan çerezleri açıklar.</p>
</div>

<div class="ys-b">
    <h2 class="h3">2. Kullandığımız çerezler</h2>
    <p class="gvd">Aşağıdaki listeler sitenin kendi yapılandırmasından üretilir; sitede kullanılan çerezlerin tamamı buradadır. Aynı liste, çerez tercihleri penceresinde de birebir görünür.</p>

    @foreach ($kategoriler as $kategori)
        <h3 class="h4">{{ $kategori['ad'] }} — {{ $kategori['zorunlu'] ? 'izin gerekmez' : 'yalnız izin verirseniz' }}</h3>
        <p class="gvd">{{ $kategori['ozet'] }}</p>
        <div class="ys-tablo-sar">
            <table class="ys-tablo">
                <thead><tr><th>Çerez</th><th>Ne işe yarar</th><th>Süre</th><th>Kim yerleştirir</th></tr></thead>
                <tbody>
                    @foreach ($kategori['cerezler'] as $cerez)
                        <tr>
                            <td><code>{{ $cerez['ad'] }}</code></td>
                            <td>{{ $cerez['ne'] }}</td>
                            <td>{{ $cerez['sure'] }}</td>
                            <td>{{ $cerez['saglayici'] }} ({{ $cerez['taraf'] }})</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        <p class="gvd"><strong>Hukuki dayanak:</strong> {{ $kategori['dayanak'] }}</p>
    @endforeach

    @if ($olcumVar)
        <p class="gvd">Ölçümde adınız, e-postanız ve telefonunuz kullanılmaz. IP adresiniz Google tarafından kısaltılarak işlenir ve tam hâliyle saklanmaz. Ölçüm verilerinin saklama süresi <strong>14 ay</strong> olarak ayarlanmıştır; sürenin sonunda otomatik silinir.</p>
        <p class="gvd">Bu veriler Google altyapısında işlendiğinden yurt dışına aktarım söz konusudur; ayrıntı için <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK Aydınlatma Metni</a>'nin 5. bölümüne bakınız.</p>
    @endif

    <h3 class="h4">Kullanmadıklarımız</h3>
    <p class="gvd">{{ implode(', ', $envanter->kullanilmayanlar()) }} — bunların hiçbiri sitemizde bulunmaz. Bu liste, bir gün değişirse bu politika da aynı gün değişecek şekilde tutulmaktadır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">3. Mobil uygulamada çerez yoktur</h2>
    <p class="gvd">Sipario mobil uygulaması bir web sayfası değildir ve çerez kullanmaz. Uygulama içindeki oturum, cihaza bağlı bir güvenlik belirteciyle yürür. Uygulamada reklam kimliği (Advertising ID) okunmaz ve üçüncü taraf analitik/reklam kütüphanesi bulunmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. Tercihinizi nasıl değiştirirsiniz?</h2>
    <p class="gvd">Sayfanın altındaki <strong>"Çerez tercihleri"</strong> düğmesine tıklayarak tercih penceresini açabilir, kategori kategori izin verebilir veya iznizi geri alabilirsiniz. Pencere aynı zamanda hangi çerezin ne kadar süreyle ne için tutulduğunu da gösterir. Reddettiğiniz anda ölçüm durur ve ilgili çerezler silinir.</p>
    <p class="gvd">Tercihiniz <code>{{ $envanter->cerezAdi() }}</code> adlı çerezde {{ (int) round($envanter->gun() / 30) }} ay boyunca saklanır; bu süre dolduğunda ya da çerezlerinizi sildiğinizde bir kez daha sorulur. Çerezlerin listesi değişirse tercihiniz yenilenir ve size tekrar sorulur — verdiğiniz izin, izin verdiğiniz listeye aittir.</p>
    <p class="gvd">Ayrıca tarayıcınızın ayarlarından tüm çerezleri silebilir veya engelleyebilirsiniz. Zorunlu çerezleri engellerseniz giriş ve form gönderimi gibi işlevler çalışmaz. Tarayıcı yardım sayfaları: Chrome, Safari, Firefox ve Edge için "çerezleri yönetme" başlığına bakınız.</p>
    @if ($olcumVar)
        <p class="gvd">Google Analytics ölçümünü tarayıcı düzeyinde tamamen kapatmak isterseniz, Google'ın <em>Google Analytics Devre Dışı Bırakma</em> tarayıcı eklentisini de kullanabilirsiniz.</p>
    @endif
</div>

<div class="ys-b">
    <h2 class="h3">5. Hukuki dayanak</h2>
    <p class="gvd">Zorunlu çerezler, KVKK m.5/2-f (veri sorumlusunun meşru menfaati) ve hizmetin sunulabilmesi gerekliliğine dayanır; açık rıza aranmaz.</p>
    <p class="gvd">Rızaya bağlı çerezler <strong>yalnız KVKK m.5/1 kapsamında açık rızanıza</strong> dayanır. Rıza vermemeniz veya geri almanız hâlinde site tüm işlevleriyle çalışmaya devam eder; hiçbir kısıtlama uygulanmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. Sorularınız</h2>
    <p class="gvd">Çerez uygulamalarımızla ilgili sorularınız için: <x-legal.deger anahtar="support_email" ad="destek e-posta adresi" />, <x-legal.deger anahtar="phone" ad="telefon numarası" />.</p>
    <p class="gvd">Yürürlükteki sürüm: <strong>{{ config('subscription.legal.kvkk_version') }}</strong>.</p>
</div>
