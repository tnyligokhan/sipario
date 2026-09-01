{{--
    İPTAL, CAYMA VE İADE KOŞULLARI.

    ── 2026-09-01: İADE TAAHHÜDÜ KALDIRILDI (kullanıcı kararı) ─────────────────────────────
    Kullanıcının sözü: *"İptal ve iade diye bir şey yok zaten 30 günlük deneme süresi var."*

    2026-08-19 sürümü iki taahhüt taşıyordu ve ikisi de KANUNEN ZORUNLU DEĞİLDİ, işletme kararı
    olarak verilmişti: (a) ilk 14 gün koşulsuz tam iade, (b) sonrasında kullanılmayan aylar
    oranında iade. İkisi de geri alındı. Belge SİLİNMEDİ — mesafeli satışta iptal/iade
    koşullarının ilan edilmesi zorunludur (MSY m.5) ve "iade yok" da bir koşuldur; ilan
    edilmemiş olması, olmadığı anlamına gelmez, belirsiz olduğu anlamına gelir.

    KARARIN DAYANDIĞI YAPI: para ÖNCE alınmıyor. Deneme süresi boyunca kart bilgisi bile
    istenmeden tam sürüm kullanılıyor ve otomatik yenileme yok — yani ödeme kararı ürünü
    gördükten sonra, her dönem yeniden veriliyor. "Denemeden ödeyip pişman olmak" diye bir hâl
    üretmeyen bir akışta, iade taahhüdü kapatmayı üstlendiği riski zaten kapatmıyordu.

    ⚠️ İADENİN TAMAMEN KALKMADIĞI ÜÇ HÂL BİLEREK DURUYOR ve bunlar müşterinin vazgeçmesiyle
    ilgili değil, BİZDEN kaynaklanan durumlarla:
      • hatalı/mükerrer tahsilat (alınmaması gereken para — iadesi bir taahhüt değil borçtur),
      • Sipario'nun hizmeti tamamen durdurması (60 gün önce bildirim + oransal iade),
      • satın alma sırasında var olan bir işlevin kaldırılması (mesafeli-satis md. 6).
    Bunları da kaldırmak, kendi kusurumuzun bedelini müşteriye yıkmak olurdu.

    ⚠️ CAYMA HAKKI BÖLÜMÜ DEĞİŞMEDİ: MSY m.15/1-ğ istisnası hukuki bir tespittir, işletme
    tercihi değil. Değişen tek şey, o istisnanın üstüne konan gönüllü iade taahhüdünün artık
    olmaması.

    ⚠️ Ödeme altyapısı bugün havale/EFT ve elden ödeme; kartlı ödeme henüz devrede değil.
    İade yolu, ödemenin hangi yolla alındığına bağlanarak yazıldı.
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">Kısaca</h2>
    <p class="gvd">Sipario'yu <strong>{{ (int) config('subscription.trial_days') }} gün ücretsiz</strong> denersiniz; bu süre için kart bilgisi bile istenmez. Ödeme kararını ancak ürünü gördükten sonra verirsiniz. Abonelik kendiliğinden yenilenmez, kartınızdan kendiliğinden para çekilmez — bırakmak için bir şey yapmanız gerekmez, ödemezsiniz ve dönem sonunda hesap yeni kayıt almayı durdurur.</p>
    <p class="gvd"><strong>Ödenmiş dönem için iade yapılmaz.</strong> Bunun istisnası, bizden kaynaklanan hâllerdir: hatalı ya da mükerrer tahsilat, hizmetin tamamen durdurulması, satın alma sırasında var olan bir işlevin kaldırılması. Hiçbir hâlde verileriniz silinmez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">1. Ücretsiz deneme — ödemeden önceki karar noktası</h2>
    <p class="gvd">{{ (int) config('subscription.trial_days') }} günlük deneme süresi için ödeme bilgisi istenmez ve süre sonunda kendiliğinden ücret tahsil edilmez. Deneme, siz ödeme yapmadıkça ücretli aboneliğe dönüşmez. Dolayısıyla denemeyi "iptal etmeniz" gerekmez — hiçbir şey yapmazsanız süre dolar ve hesap yazmaya kapanır.</p>
    <p class="gvd">Deneme sürümü kısıtlı değildir: ürünün tamamını, kendi müşterilerinizle ve kendi verinizle kullanırsınız. Bu, bu belgedeki iade düzeninin dayanağıdır — ödeme, ürün görülmeden yapılan bir taahhüt değil, denendikten sonra verilen bir karardır.</p>
    <p class="gvd">Deneme süresi dolduğunda verileriniz durur. Daha sonra abone olduğunuzda, denemede girdiğiniz her kayıt olduğu gibi geri gelir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">2. Cayma hakkı</h2>
    <p class="gvd">Tüketici sıfatıyla alım yapıyorsanız, mesafeli sözleşmelerde kural olarak 14 günlük cayma hakkınız vardır (Mesafeli Sözleşmeler Yönetmeliği m.9). Ancak aynı Yönetmeliğin m.15/1-ğ hükmü, <strong>elektronik ortamda anında ifa edilen hizmetleri</strong> bu haktan istisna tutar. Sipario ödemenin teyidiyle derhal aktive edildiğinden bu istisna kapsamındadır ve ödeme adımında bunu bilerek onay verirsiniz.</p>
    <p class="gvd">Ticari veya mesleki amaçla alım yapan tacir/esnaf alıcılar bakımından kanundan doğan bir cayma hakkı zaten bulunmaz; sözleşmeye Türk Borçlar Kanunu'nun genel hükümleri uygulanır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">3. Ödenmiş dönem için iade yapılmaz</h2>
    <p class="gvd">Ücretli aboneliğin bedeli, dönem başında ve peşin tahsil edilir. Dönem başladıktan sonra vazgeçmeniz hâlinde, kullanılmayan süre için iade yapılmaz.</p>
    <p class="gvd">Bunun sebebi, ödemeden önce ürünü tam olarak deneme imkânının verilmiş olmasıdır: {{ (int) config('subscription.trial_days') }} gün boyunca hiçbir ödeme bilgisi vermeden hizmetin tamamını kullanırsınız. Ayrıca abonelik kendiliğinden yenilenmediği için, ödeme her dönem yeniden ve bilerek yapılan bir işlemdir.</p>
    <p class="gvd">Dönem bedelini ödemiş olmanız, dönem sonuna kadar hizmete erişiminizi güvence altına alır: iptal ettiğinizi bildirseniz dahi ödediğiniz dönemin sonuna kadar hesabınız aynen çalışmaya devam eder, ek ücret alınmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. İadenin yapıldığı hâller</h2>
    <p class="gvd">Aşağıdaki durumlar müşterinin vazgeçmesiyle ilgili değildir; Sipario'dan kaynaklanır ve bu hâllerde iade yapılır:</p>
    <ul class="ys-liste">
        <li><b>Hatalı veya mükerrer tahsilat.</b> Alınmaması gereken ya da iki kez alınan bir tutar, tespit edildiği anda tamamen iade edilir. Bu bir taahhüt değil, sebepsiz zenginleşmeden doğan bir borçtur.</li>
        <li><b>Hizmetin tamamen durdurulması.</b> Sipario hizmeti sunmayı bırakırsa, kullanılmayan dönem bedeli oransal olarak iade edilir (bkz. 8. bölüm).</li>
        <li><b>Satın alma sırasında var olan bir işlevin kaldırılması.</b> Böyle bir hâlde aboneliğinizi feshedip kalan dönem için oransal iade talep edebilirsiniz (<a href="{{ route('legal.show', 'mesafeli-satis') }}">Mesafeli Satış Sözleşmesi</a> md. 6).</li>
    </ul>
    <p class="gvd">Hizmetin Sipario'ya atfedilebilecek bir sebeple uzun süre kullanılamaz olması hâlinde de, kullanılamayan süreye karşılık gelen bedel talebiniz üzerine değerlendirilir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">5. Talep nasıl iletilir?</h2>
    <p class="gvd">Talebinizi, hesabınızın kayıtlı e-posta adresinden <x-legal.deger anahtar="support_email" ad="destek e-posta adresi" /> adresine iletmeniz yeterlidir. Talebinizde işletme adınızı ve firma kodunuzu belirtmeniz işlemi hızlandırır.</p>
    <p class="gvd">Talebiniz <strong>en geç 3 iş günü içinde</strong> değerlendirilir ve sonucu size yazılı olarak bildirilir. Talebin reddedilmesi hâlinde gerekçesi ayrıca yazılır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. İade ne zaman ve nasıl yapılır?</h2>
    <p class="gvd">4. bölüm kapsamında onaylanan iadeler, talebin tarafımıza ulaşmasından itibaren <strong>en geç 14 gün içinde</strong> gerçekleştirilir. İade, ödemenin alındığı yönteme göre yapılır:</p>
    <ul class="ys-liste">
        <li><b>Havale / EFT ile ödendiyse:</b> ödemenin geldiği hesaba veya Alıcı'nın yazılı olarak bildirdiği kendi adına kayıtlı IBAN'a.</li>
        <li><b>Elden ödendiyse:</b> Alıcı'nın yazılı olarak bildirdiği kendi adına kayıtlı IBAN'a havale ile.</li>
        <li><b>Kartla ödendiyse (bu yöntem devreye alındığında):</b> ödeme kuruluşu üzerinden aynı karta iade edilir. Tutarın kart ekstrenize yansıma süresi bankanıza bağlıdır ve Sipario'nun denetiminde değildir.</li>
    </ul>
    <p class="gvd">İade tutarından işlem masrafı, komisyon veya kesinti yapılmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">7. Otomatik yenileme yoktur</h2>
    <p class="gvd">Sipario aboneliği dönem sonunda kendiliğinden yenilenmez ve kartınızdan kendiliğinden ücret çekilmez. Dönem bitmeden önce size hatırlatma e-postası gönderilir; yenilemek isterseniz ödemeyi kendiniz yaparsınız. Bu nedenle "yenilemeyi durdurmak" ya da "aboneliği iptal etmek" için ayrıca bir işlem yapmanız gerekmez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">8. Süre dolduğunda ne olur?</h2>
    <p class="gvd">Deneme ya da abonelik süresi dolduğunda hesabınıza yeni kayıt girilemez. Var olan kayıtlarınız silinmez, sunucularımızda durmaya devam eder. Cihazınızda sunucuya gönderilmemiş bekleyen kayıtlarınız varsa bunlar yine sunucuya aktarılır — kilit yazmayı durdurur, veri kaybettirmez.</p>
    <p class="gvd">Abonelik yenilendiği anda bütün veriniz olduğu gibi geri gelir. Ayrıca, aboneliğiniz sona ermiş olsa dahi destek kanalı üzerinden verilerinizin dışa aktarımını her zaman talep edebilirsiniz. <strong>Verinizi tahsilat baskısı için rehin almayız.</strong></p>
</div>

<div class="ys-b">
    <h2 class="h3">9. Satıcı kaynaklı fesih</h2>
    <p class="gvd">Sipario, hizmeti sunmayı tamamen durdurmaya karar verirse aboneleri en az 60 gün önce bilgilendirir, verilerin dışa aktarımı için süre tanır ve kullanılmayan dönem bedelini oransal olarak iade eder.</p>
    <p class="gvd">Sözleşmeye ağır aykırılık nedeniyle yapılan fesihlerde iade, aykırılığın niteliğine göre değerlendirilir; Alıcı'nın kastından kaynaklanan hâllerde iade yapılmaz. Bu hâlde de veri silinmez ve dışa aktarım hakkı saklıdır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">10. İtiraz yolları</h2>
    <p class="gvd">İade ya da iptal talebinize ilişkin sonucu uygun bulmazsanız; tüketici sıfatı taşıyorsanız Ticaret Bakanlığı'nca ilan edilen parasal sınırlar dahilinde yerleşim yerinizdeki <strong>Tüketici Hakem Heyeti'ne</strong>, sınırların üzerinde <strong>Tüketici Mahkemesi'ne</strong> başvurabilirsiniz. Başvurular e-Devlet üzerinden Tüketici Bilgi Sistemi (TÜBİS) ile de yapılabilir.</p>
    <p class="gvd">Tacir sıfatıyla alım yaptıysanız uyuşmazlıklarda <x-legal.deger ad="yetkili mahkeme ve icra daireleri" /> yetkilidir; ticari davalarda dava şartı arabuluculuk hükümleri saklıdır.</p>
</div>
