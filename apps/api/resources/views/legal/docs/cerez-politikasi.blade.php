{{--
    ÇEREZ POLİTİKASI — 2026-08-19 tam metin.

    ── ESKİ METİN ARTIK DOĞRU DEĞİLDİ ───────────────────────────────────────────────────────
    Önceki sürüm şunu diyordu: "Sitemizde reklam, pazarlama veya analitik amaçlı hiçbir çerez ya
    da üçüncü taraf izleyici bulunmaz." O cümle YAZILDIĞI GÜN doğruydu ve doğru olduğu için de
    değerliydi. Bu vardiyada siteye Google Analytics 4 eklendi — yani cümle, kod değiştiği anda
    YALANA dönüştü. Belge güncellenmeseydi, sitede hem izleyici çalışıyor hem de politika
    "izleyici yok" diyor olacaktı; bu, KVKK açısından yanlış bilgilendirme, reklam mevzuatı
    açısından yanıltıcı beyandır.

    ── KVK KURULU'NUN ÇEREZ YAKLAŞIMI ───────────────────────────────────────────────────────
    Kurul'un çerez uygulamalarına ilişkin rehberi iki grubu ayırır:
      • ZORUNLU (kesinlikle gerekli) çerezler — hizmetin çalışması için şart; açık rıza aranmaz,
        yalnız bilgilendirme yeterlidir.
      • DİĞER çerezler (analitik, reklam, kişiselleştirme) — AÇIK RIZA gerekir ve rıza ÖNCEDEN
        alınmalıdır. "Siteyi kullanmaya devam ederseniz kabul etmiş sayılırsınız" geçerli bir
        rıza değildir.
    Bu yüzden analitik çerez, banner'da ONAY VERİLENE KADAR HİÇ ÇALIŞMAZ (varsayılan: reddedilmiş).
    Uygulaması: components/site/cerez-onay.blade.php + public/js/olcum.js (Consent Mode v2).

    ── TABLODAKİ ÇEREZ ADLARI UYDURMA DEĞİL ─────────────────────────────────────────────────
    `sipario_session` ve `XSRF-TOKEN` Laravel'in gerçek çerezleridir (config/session.php).
    `sipario_cerez_izni` bu vardiyada eklenen tercih çerezidir. `_ga` / `_ga_<id>` Google
    Analytics 4'ün kendi çerezleridir. Süreler de gerçek: oturum çerezi SESSION_LIFETIME
    (120 dakika), GA4 çerezleri 2 yıl varsayılanıyla gelir ve veri saklama 14 aya ayarlıdır.
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">Kısaca</h2>
    <p class="gvd">Sitemiz iki tür çerez kullanır. Birincisi <strong>zorunlu</strong> çerezlerdir: oturumunuzu açık tutar ve formları güvenli hâle getirir; bunlar olmadan giriş yapamazsınız. İkincisi <strong>ölçüm</strong> çerezidir ve <strong>yalnız siz izin verirseniz</strong> çalışır. İzin vermezseniz hiçbir ölçüm isteği gönderilmez.</p>
    <p class="gvd">Reklam çerezi, sosyal medya izleyicisi veya üçüncü taraf reklam ağı <strong>kullanmıyoruz</strong>. Yazı tiplerimiz dahil tüm görsel kaynaklar kendi sunucumuzdan gelir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">1. Çerez nedir?</h2>
    <p class="gvd">Çerezler, ziyaret ettiğiniz internet siteleri tarafından tarayıcınıza kaydedilen küçük metin dosyalarıdır. Sitenin sizi hatırlamasını (ör. giriş yapmış olduğunuzu) sağlar. İşbu politika, <x-legal.deger anahtar="title" ad="ticaret unvanı" /> ("Sipario") tarafından işletilen sipario.com.tr sitesinde kullanılan çerezleri açıklar.</p>
</div>

<div class="ys-b">
    <h2 class="h3">2. Kullandığımız çerezler</h2>

    <h3 class="h4">Zorunlu çerezler — izin gerekmez</h3>
    <p class="gvd">Bu çerezler sitenin çalışması için kesinlikle gereklidir. KVK Kurulu'nun çerez rehberi uyarınca açık rıza aranmaz; yalnız bilgilendirme yapılır. Engellerseniz giriş yapamaz ve form gönderemezsiniz.</p>
    <div class="ys-tablo-sar">
        <table class="ys-tablo">
            <thead><tr><th>Çerez</th><th>Ne işe yarar</th><th>Süre</th><th>Taraf</th></tr></thead>
            <tbody>
                <tr><td><code>sipario_session</code></td><td>Oturumunuzu ayakta tutar; giriş yaptığınızda sizi hatırlar.</td><td>{{ (int) config('session.lifetime') }} dakika</td><td>Birinci taraf</td></tr>
                <tr><td><code>XSRF-TOKEN</code></td><td>Form gönderimlerini sahte istek saldırılarına (CSRF) karşı korur.</td><td>{{ (int) config('session.lifetime') }} dakika</td><td>Birinci taraf</td></tr>
                <tr><td><code>sipario_cerez_izni</code></td><td>Çerez tercihinizi hatırlar; her ziyarette tekrar sorulmasını önler.</td><td>6 ay</td><td>Birinci taraf</td></tr>
            </tbody>
        </table>
    </div>

    <h3 class="h4">Ölçüm (analitik) çerezleri — yalnız izin verirseniz</h3>
    <p class="gvd">Bu çerezler, sitenin hangi bölümünün işe yaradığını anlamamıza yarar: hangi sayfalar okunuyor, ziyaretçi hangi adımda vazgeçiyor, insanlar siteye nereden geliyor. Amaç reklam değil, sitenin kendisini düzeltmektir.</p>
    <div class="ys-tablo-sar">
        <table class="ys-tablo">
            <thead><tr><th>Çerez</th><th>Ne işe yarar</th><th>Süre</th><th>Taraf</th></tr></thead>
            <tbody>
                <tr><td><code>_ga</code></td><td>Ziyaretçiyi ayırt eden rastgele bir kimlik tutar (kim olduğunuzu değil, aynı ziyaretçi olduğunuzu bilir).</td><td>2 yıl</td><td>Google Analytics 4</td></tr>
                <tr><td><code>_ga_&lt;ölçüm kimliği&gt;</code></td><td>Oturum durumunu tutar; bir ziyaretin nerede başlayıp bittiğini belirler.</td><td>2 yıl</td><td>Google Analytics 4</td></tr>
            </tbody>
        </table>
    </div>
    <p class="gvd"><strong>İzin vermezseniz bu çerezler hiç yerleştirilmez</strong> ve Google'a hiçbir istek gönderilmez. Sitede varsayılan durum "reddedilmiş"tir; ölçüm ancak siz açıkça izin verdiğinizde başlar.</p>
    <p class="gvd">Ölçümde adınız, e-postanız ve telefonunuz kullanılmaz. IP adresiniz Google tarafından kısaltılarak işlenir ve tam hâliyle saklanmaz. Ölçüm verilerinin saklama süresi <strong>14 ay</strong> olarak ayarlanmıştır; sürenin sonunda otomatik silinir.</p>
    <p class="gvd">Bu veriler Google altyapısında işlendiğinden yurt dışına aktarım söz konusudur; ayrıntı için <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK Aydınlatma Metni</a>'nin 5. bölümüne bakınız.</p>

    <h3 class="h4">Kullanmadıklarımız</h3>
    <p class="gvd">Reklam ve yeniden hedefleme (retargeting) çerezleri, sosyal medya paylaşım izleyicileri, ısı haritası ve oturum kaydı araçları, üçüncü taraf yazı tipi ve içerik dağıtım ağları — bunların hiçbiri sitemizde bulunmaz. Bu liste, bir gün değişirse bu politika da aynı gün değişecek şekilde tutulmaktadır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">3. Mobil uygulamada çerez yoktur</h2>
    <p class="gvd">Sipario mobil uygulaması bir web sayfası değildir ve çerez kullanmaz. Uygulama içindeki oturum, cihaza bağlı bir güvenlik belirteciyle yürür. Uygulamada reklam kimliği (Advertising ID) okunmaz ve üçüncü taraf analitik/reklam kütüphanesi bulunmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. Tercihinizi nasıl değiştirirsiniz?</h2>
    <p class="gvd">Sayfanın altındaki <strong>"Çerez tercihleri"</strong> bağlantısına tıklayarak izninizi istediğiniz an verebilir veya geri alabilirsiniz. Reddettiğiniz anda ölçüm durur ve ilgili çerezler silinir.</p>
    <p class="gvd">Ayrıca tarayıcınızın ayarlarından tüm çerezleri silebilir veya engelleyebilirsiniz. Zorunlu çerezleri engellerseniz giriş ve form gönderimi gibi işlevler çalışmaz. Tarayıcı yardım sayfaları: Chrome, Safari, Firefox ve Edge için "çerezleri yönetme" başlığına bakınız.</p>
    <p class="gvd">Google Analytics ölçümünü tarayıcı düzeyinde tamamen kapatmak isterseniz, Google'ın <em>Google Analytics Devre Dışı Bırakma</em> tarayıcı eklentisini de kullanabilirsiniz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">5. Hukuki dayanak</h2>
    <p class="gvd">Zorunlu çerezler, KVKK m.5/2-f (veri sorumlusunun meşru menfaati) ve hizmetin sunulabilmesi gerekliliğine dayanır; açık rıza aranmaz.</p>
    <p class="gvd">Ölçüm çerezleri <strong>yalnız KVKK m.5/1 kapsamında açık rızanıza</strong> dayanır. Rıza vermemeniz veya geri almanız hâlinde site tüm işlevleriyle çalışmaya devam eder; hiçbir kısıtlama uygulanmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. Sorularınız</h2>
    <p class="gvd">Çerez uygulamalarımızla ilgili sorularınız için: <x-legal.deger anahtar="support_email" ad="destek e-posta adresi" />, <x-legal.deger anahtar="phone" ad="telefon numarası" />.</p>
    <p class="gvd">Yürürlükteki sürüm: <strong>{{ config('subscription.legal.kvkk_version') }}</strong>.</p>
</div>
