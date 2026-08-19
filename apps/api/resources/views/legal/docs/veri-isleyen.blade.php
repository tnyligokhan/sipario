{{--
    VERİ İŞLEYEN SÖZLEŞMESİ (Ek-1) — 2026-08-19, YENİ BELGE.

    ── NEDEN ZORUNLU, "iyi olur" DEĞİL ──────────────────────────────────────────────────────
    KVKK m.12/1, veri sorumlusunun güvenlik yükümlülüklerini veri işleyenle BİRLİKTE taşıdığını
    söyler ve Kurul uygulaması bu ilişkinin YAZILI bir belgeye dayanmasını arar. Sipario'nun
    durumu tam olarak budur: bayinin kendi müşterilerine ait ad/telefon/adres/konum/borç
    verisinin sorumlusu BAYİDİR, Sipario ise o veriyi bayinin talimatıyla işleyen taraftır.

    Bu belge olmadan iki taraf da açıkta kalıyordu:
      • BAYİ, kullandığı yazılım sağlayıcısıyla arasında hiçbir yazılı veri güvenliği taahhüdü
        olmadan müşteri verisini bir sisteme yüklüyordu. Bir denetimde "veri işleyeninizle
        sözleşmeniz nerede?" sorusunun cevabı yoktu.
      • SIPARIO, "biz sadece yazılımcıyız" diyebileceği sınırları hiçbir yerde yazmamıştı;
        sınırı yazmayan taraf, sınırın dışına düşer.

    ── NEDEN AYRI İMZA İSTENMİYOR ───────────────────────────────────────────────────────────
    Belge, Mesafeli Satış Sözleşmesi'nin EKİ olarak kurulur ve bayi üyelik/ödeme adımında ana
    sözleşmeyi onayladığında bu ek de kabul edilmiş olur (ana sözleşme m.14 ekleri sayar).
    Islak imzalı ayrı bir nüsha isteyen bayiler için kapı açık bırakıldı (madde 12).
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">Bu ek ne için var?</h2>
    <p class="gvd">Sipario'yu kullanarak kendi müşterilerinizin adını, telefonunu, adresini ve borç kaydını sisteme girersiniz. <strong>Bu veriler bakımından KVKK önünde veri sorumlusu sizsiniz</strong> — Sipario değil. Sipario, bu verileri yalnız sizin adınıza ve talimatınızla işleyen "veri işleyen"dir.</p>
    <p class="gvd">KVKK m.12/1, bu ilişkinin yazılı bir belgeye dayanmasını gerektirir. İşbu Ek-1 o belgedir ve iki tarafın da yükümlülüklerini tanımlar.</p>
</div>

<div class="ys-b">
    <h2 class="h3">1. Taraflar ve tanımlar</h2>
    <ul class="ys-liste">
        <li><b>Veri Sorumlusu:</b> Sipario'ya abone olan işletme ("<strong>İşletme</strong>").</li>
        <li><b>Veri İşleyen:</b> <x-legal.deger anahtar="title" ad="ticaret unvanı" /> ("<strong>Sipario</strong>").</li>
        <li><b>İlgili Kişi:</b> İşletme'nin Sipario'ya kaydettiği müşteriler ve İşletme'nin ekip üyeleri.</li>
        <li><b>Kişisel Veri:</b> İşletme tarafından Sipario'ya girilen; ad, telefon, adres, konum, sipariş geçmişi ve cari hesap (veresiye) kayıtları.</li>
    </ul>
    <p class="gvd">Bu Ek, Mesafeli Satış Sözleşmesi ve Kullanım Koşulları'nın ayrılmaz parçasıdır; İşletme ana sözleşmeyi onayladığında bu Ek de kurulmuş olur.</p>
</div>

<div class="ys-b">
    <h2 class="h3">2. İşlemenin konusu, süresi ve amacı</h2>
    <ul class="ys-liste">
        <li><b>Konu:</b> Sipario yazılım hizmetinin sunulması.</li>
        <li><b>Amaç:</b> Sipariş kaydı, teslimat takibi, cari hesap (veresiye) defteri, kasa kapanışı, cihazlar arası senkronizasyon ve isteğe bağlı adres/rota işlevlerinin çalıştırılması.</li>
        <li><b>Süre:</b> Abonelik ilişkisi devam ettiği ve sonrasında verinin silinmesi talep edilmediği sürece.</li>
        <li><b>Veri kategorileri ve ilgili kişi grupları:</b> yukarıdaki 1. maddede sayılanlar.</li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">3. Sipario'nun yükümlülükleri</h2>
    <p class="gvd">Sipario, veri işleyen sıfatıyla şunları taahhüt eder:</p>
    <ul class="ys-liste">
        <li><b>Yalnız talimatla işleme.</b> Kişisel verileri, hizmeti sunmak için gerekli olan dışında hiçbir amaçla işlemez. Kendi ticari amaçları için kullanmaz, üçüncü kişilere satmaz, reklam için paylaşmaz ve <strong>yapay zekâ modeli eğitiminde kullanmaz</strong>.</li>
        <li><b>Gizlilik.</b> Veriye erişimi olan personelin gizlilik yükümlülüğü altında olmasını sağlar; erişimi işini yapmak için gerçekten ihtiyacı olanla sınırlar.</li>
        <li><b>Güvenlik.</b> KVKK m.12 kapsamında gerekli teknik ve idari tedbirleri alır. Alınan tedbirler <a href="{{ route('legal.show', 'gizlilik-politikasi') }}">Gizlilik Politikası</a>'nda sayılmıştır ve bu Ek'in parçası sayılır.</li>
        <li><b>Kiracı izolasyonu.</b> Her işletmenin verisinin diğerlerinden veritabanı düzeyinde ayrılmasını sağlar; bir işletmenin başka bir işletmenin verisine erişmesi teknik olarak engellenir.</li>
        <li><b>Yazma yasağı.</b> Sipario'nun kendi yönetim paneli, İşletme'nin iş verisini <strong>değiştiremez</strong>; bu sınır veritabanı izniyle zorlanır. Yalnız hesap/abonelik yönetimi ve salt-okunur istatistik yapılabilir.</li>
        <li><b>İz bırakma.</b> Verinin dışa aktarılması gibi yüksek etkili işlemler denetim günlüğüne yazılır; kayıt İşletme'nin talebi üzerine paylaşılır.</li>
        <li><b>İlgili kişi taleplerinde yardım.</b> İşletme'ye ulaşan bir ilgili kişi talebinin (bilgi, düzeltme, silme) teknik olarak yerine getirilmesinde makul desteği sağlar.</li>
        <li><b>Sözleşme sonunda.</b> İşletme'nin talebi üzerine veriyi dışa aktarır ve talep edilirse siler. <strong>Kendiliğinden silmez</strong> — abonelik sona erse dahi veri saklanmaya devam eder.</li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">4. İşletme'nin yükümlülükleri</h2>
    <p class="gvd">İşletme, veri sorumlusu sıfatıyla şunları taahhüt eder:</p>
    <ul class="ys-liste">
        <li><b>Hukuki dayanak.</b> Sipario'ya girdiği kişisel verilerin toplanmasının ve işlenmesinin hukuka uygun bir sebebe dayandığını (sözleşme, meşru menfaat veya açık rıza).</li>
        <li><b>Aydınlatma.</b> Kendi müşterilerini KVKK m.10 kapsamında aydınlatmak. <strong>Bu yükümlülük Sipario'ya devredilemez.</strong> Müşterinize "verilerinizi bir yazılımda tutuyorum" demek sizin göreviniz; Sipario sizin adınıza müşterinize aydınlatma yapamaz.</li>
        <li><b>Veri minimizasyonu.</b> Hizmetin gerektirmediği kişisel veriyi (özellikle sağlık, din, siyasi görüş gibi <em>özel nitelikli</em> verileri) serbest metin alanlarına yazmamak.</li>
        <li><b>Ekip yönetimi.</b> Ekip hesaplarını açıp kapatmak, ayrılan çalışanın erişimini derhal kaldırmak, hesapların paylaşılmasını önlemek.</li>
        <li><b>Talep karşılama.</b> Kendi müşterilerinden gelen KVKK taleplerini veri sorumlusu olarak değerlendirmek ve karara bağlamak.</li>
        <li><b>İzinsiz ileti göndermemek.</b> Sistem üzerinden müşterilerine gönderdiği her mesajın 6563 sayılı Kanun'a uygunluğundan sorumlu olmak.</li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">5. Alt veri işleyenler</h2>
    <p class="gvd">Sipario, hizmeti sunabilmek için aşağıdaki alt veri işleyenlerden yararlanır. İşletme, bu Ek'i kabul etmekle bu alt işleyenlerin kullanılmasına genel yetki vermiş olur.</p>
    <div class="ys-tablo-sar">
        <table class="ys-tablo">
            <thead><tr><th>Alt işleyen</th><th>Hizmet</th><th>Veri</th><th>Konum</th></tr></thead>
            <tbody>
                <tr><td><x-legal.deger ad="barındırma sağlayıcısının unvanı" /></td><td>Sunucu barındırma</td><td>Sistemdeki tüm veri</td><td><b>Türkiye</b></td></tr>
                <tr><td><x-legal.deger ad="SMTP/e-posta sağlayıcısının unvanı" /></td><td>E-posta gönderimi</td><td>Alıcı adresi ve ileti içeriği</td><td><x-legal.deger ad="SMTP sağlayıcısının sunucu ülkesi" /></td></tr>
                <tr><td>Google LLC</td><td>Anlık bildirim (FCM)</td><td>Cihaz jetonu, olay adı, kayıt numarası</td><td>Yurt dışı</td></tr>
                <tr><td>Google LLC / Yandex</td><td>Adres → koordinat (isteğe bağlı)</td><td>Yalnız adres metni</td><td>Yurt dışı</td></tr>
                <tr><td>Google LLC</td><td>Rota sıralama (isteğe bağlı)</td><td>Yalnız durak koordinatları</td><td>Yurt dışı</td></tr>
            </tbody>
        </table>
    </div>
    <p class="gvd">Adres arama ve rota sıralama işlevleri <strong>isteğe bağlıdır</strong>; kullanılmadığında ilgili alt işleyene hiçbir veri gitmez.</p>
    <p class="gvd">Sipario yeni bir alt veri işleyen eklemeden veya mevcut birini değiştirmeden önce İşletme'yi en az <strong>30 gün</strong> önce bilgilendirir. İşletme değişikliğe makul gerekçeyle itiraz ederse, taraflar bir çözüm üzerinde anlaşmaya çalışır; anlaşılamazsa İşletme aboneliğini feshedip kalan dönem için oransal iade talep edebilir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. Yurt dışına aktarım</h2>
    <p class="gvd">Kişisel veriler <strong>Türkiye'deki sunucuda saklanır</strong>. Yukarıdaki tabloda "yurt dışı" olarak işaretli alt işleyenlere, yalnız o işlevin çalışması için gereken asgari veri gönderilir; müşterinin adı, telefonu veya borcu bu çağrılarda yer almaz.</p>
    <p class="gvd">Bu aktarımlar KVKK m.9 kapsamındadır. Aktarımın hukuki dayanağının (yeterlilik kararı, standart sözleşme veya taahhütname) tamamlanması ve gerekiyorsa Kurul'a bildirilmesi Sipario'nun sorumluluğundadır: <x-legal.deger ad="yurt dışı aktarım hukuki dayanağı — standart sözleşme metni ve Kurul bildirimi" /></p>
</div>

<div class="ys-b">
    <h2 class="h3">7. Veri ihlali bildirimi</h2>
    <p class="gvd">Sipario, İşletme'nin verisini etkileyen bir ihlal tespit ettiğinde İşletme'ye <strong>gecikmeksizin ve en geç 24 saat içinde</strong> bildirir. Bildirimde; ihlalin niteliği, etkilenen veri kategorileri, tahmini ilgili kişi sayısı, olası sonuçlar ve alınan/alınacak önlemler yer alır.</p>
    <p class="gvd">Bu süre, İşletme'nin veri sorumlusu olarak Kurul'a 72 saat içinde bildirim yapabilmesi için bilerek kısa tutulmuştur. Kurul'a ve ilgili kişilere bildirim yükümlülüğü İşletme'ye aittir; Sipario gerekli teknik bilgiyi sağlayarak destek olur.</p>
</div>

<div class="ys-b">
    <h2 class="h3">8. Denetim</h2>
    <p class="gvd">İşletme, bu Ek'e uygunluğun denetlenmesi için yılda bir kez yazılı bilgi talebinde bulunabilir; Sipario talebi <strong>30 gün</strong> içinde cevaplar. Yerinde denetim talepleri, makul bir süre önceden bildirilmek ve işleyişi aksatmamak kaydıyla değerlendirilir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">9. Sözleşmenin sona ermesi ve verinin akıbeti</h2>
    <p class="gvd">Abonelik sona erdiğinde Sipario, veriyi <strong>kendiliğinden silmez</strong>. Bu bilinçli bir tercihtir: silinen bir veresiye defteri geri getirilemez ve işletmeyi hem ticari hem hukuki olarak açıkta bırakır.</p>
    <p class="gvd">İşletme dilediği zaman (abonelik sona ermiş olsa dahi) verisinin dışa aktarımını talep edebilir. Silme talebi hâlinde veri, yasal saklama yükümlülüğü bulunan kayıtlar hariç, <strong>30 gün içinde</strong> silinir ve İşletme'ye yazılı olarak teyit edilir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">10. Sorumluluk</h2>
    <p class="gvd">Taraflardan her biri, kendi yükümlülüklerine aykırılıktan doğan zararlardan sorumludur. Sipario'nun bu Ek kapsamındaki sorumluluğu, Mesafeli Satış Sözleşmesi'nin sorumluluk sınırlamasına tabidir; KVKK'nın emredici hükümleri ile kast ve ağır ihmal hâlleri saklıdır.</p>
    <p class="gvd">İşletme'nin, hukuki dayanağı olmadan sisteme girdiği kişisel veriler nedeniyle Sipario'ya bir yaptırım uygulanması hâlinde, İşletme bu zararı karşılar.</p>
</div>

<div class="ys-b">
    <h2 class="h3">11. Yürürlük ve değişiklik</h2>
    <p class="gvd">Bu Ek, İşletme'nin Mesafeli Satış Sözleşmesi'ni onayladığı anda yürürlüğe girer ve abonelik ilişkisi boyunca geçerlidir. Değişiklikler yürürlüğe girmeden en az 30 gün önce e-posta ile bildirilir.</p>
    <p class="gvd">Yürürlükteki sürüm: <strong>{{ config('subscription.legal.terms_version') }}</strong>.</p>
</div>

<div class="ys-b">
    <h2 class="h3">12. Ayrı nüsha talebi</h2>
    <p class="gvd">Kendi denetim dosyanız veya müşterinize sunmak için bu Ek'in ıslak imzalı ayrı bir nüshasını isterseniz, <x-legal.deger anahtar="support_email" ad="destek e-posta adresi" /> adresine yazmanız yeterlidir. Talebiniz ücretsiz karşılanır.</p>
</div>
