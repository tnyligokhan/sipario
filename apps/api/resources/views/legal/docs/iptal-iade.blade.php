{{--
    İPTAL, CAYMA VE İADE KOŞULLARI — 2026-08-19 tam metin.

    Eski metin üç ayrı yerde "[doldurulacak]" diyordu: iade değerlendirme süresi, iade süresi,
    orantılı iade yapılıp yapılmayacağı, otomatik yenileme koşulları. Bunlar bir avukatın
    dolduracağı alanlar DEĞİL, İŞLETMENİN VERECEĞİ KARARLARDI — ve karar verilmediği için metin
    hiçbir soruya cevap vermiyordu. Bu sürüm kararları veriyor ve mevzuatın izin verdiği
    sınırların içinde kalıyor:

      • İade süresi 14 gün: MSY m.12/1, cayma bildiriminden itibaren 14 gün içinde iade
        zorunluluğu getirir. Aynı süreyi taahhüde de uyguladık — iki ayrı süre tutmak, hangi
        hâlde hangisinin işlediğini kimsenin bilememesi demekti.
      • Orantılı iade: mevzuat zorunlu kılmıyor; işletme kararı olarak VERİLDİ (dönem ortasında
        bırakan bayiden kalan ayların parasını tutmak, tahsil edilebilir ama savunulabilir değil).
      • Otomatik yenileme YOK: bu zaten ürünün davranışı (abonelik kendiliğinden yenilenmiyor,
        `valid_until` dolunca yazma kilitleniyor). Metnin ürüne uyması gerekiyordu, tersi değil.

    ⚠️ Ödeme altyapısı bugün havale/EFT ve elden ödeme. "iyzico üzerinden aynı yönteme iade"
    cümlesi eski metinde vardı ve YANLIŞTI — iyzico henüz devrede değil. İade yolu, ödemenin
    hangi yolla alındığına bağlanarak yazıldı.
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">Kısaca</h2>
    <p class="gvd">Aboneliğinizi istediğiniz zaman iptal edebilirsiniz — panelden, tek tıkla, gerekçesiz. İlk 14 gün içinde vazgeçerseniz paranızın tamamını geri alırsınız. Sonrasında bırakırsanız kullanmadığınız aylar oranında iade yaparız. Hiçbir hâlde verileriniz silinmez.</p>
    <p class="gvd">Aşağıdaki bölümler bu üç cümlenin ayrıntısıdır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">1. Ücretsiz deneme</h2>
    <p class="gvd">{{ (int) config('subscription.trial_days') }} günlük deneme süresi için ödeme bilgisi istenmez ve süre sonunda kendiliğinden ücret tahsil edilmez. Deneme, siz ödeme yapmadıkça ücretli aboneliğe dönüşmez. Dolayısıyla denemeyi "iptal etmeniz" gerekmez — hiçbir şey yapmazsanız süre dolar ve hesap yazmaya kapanır.</p>
    <p class="gvd">Deneme süresi dolduğunda verileriniz durur. Daha sonra abone olduğunuzda, denemede girdiğiniz her kayıt olduğu gibi geri gelir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">2. Cayma hakkı</h2>
    <p class="gvd">Tüketici sıfatıyla alım yapıyorsanız, mesafeli sözleşmelerde kural olarak 14 günlük cayma hakkınız vardır (Mesafeli Sözleşmeler Yönetmeliği m.9). Ancak aynı Yönetmeliğin m.15/1-ğ hükmü, <strong>elektronik ortamda anında ifa edilen hizmetleri</strong> bu haktan istisna tutar. Sipario ödemenin teyidiyle derhal aktive edildiğinden bu istisna kapsamındadır ve ödeme adımında bunu bilerek onay verirsiniz.</p>
    <p class="gvd">Ticari veya mesleki amaçla alım yapan tacir/esnaf alıcılar bakımından kanundan doğan bir cayma hakkı zaten bulunmaz; sözleşmeye Türk Borçlar Kanunu'nun genel hükümleri uygulanır.</p>
    <p class="gvd"><strong>Bu istisnaya rağmen aşağıdaki iade taahhüdü her iki alıcı tipi için de geçerlidir.</strong> Cayma hakkının kullanılamıyor olması, paranızın iade edilmeyeceği anlamına gelmez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">3. 14 gün koşulsuz iade taahhüdü</h2>
    <p class="gvd">Aboneliğinizin başladığı tarihten itibaren <strong>14 gün içinde</strong> vazgeçtiğinizi bildirirseniz, ödediğiniz bedelin <strong>tamamı</strong> iade edilir. Gerekçe sormayız, kullandığınız gün sayısını düşmeyiz.</p>
    <p class="gvd">Bu, kanunun zorunlu kıldığı bir hak değil, Sipario'nun sözleşmeyle üstlendiği bir taahhüttür. Taahhüdün tek koşulu, talebin 14 gün içinde ve hesabınızın kayıtlı e-posta adresinden iletilmiş olmasıdır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. 14 günden sonra iptal ve orantılı iade</h2>
    <p class="gvd">14 günlük süre geçtikten sonra aboneliğinizi iptal ederseniz iki seçeneğiniz olur:</p>
    <ul class="ys-liste">
        <li><b>Dönem sonuna kadar kullanmak.</b> İptal, cari dönemin sonunda hüküm doğurur; o güne kadar hizmete erişiminiz aynen devam eder. İade söz konusu olmaz, ek ücret de alınmaz.</li>
        <li><b>Hemen ayrılıp kalan süreyi geri almak.</b> Bu yönde talep ederseniz, aboneliğinizin kalan <strong>tam ay</strong> sayısı oranında iade yapılır. Hesap, iade işlendiği anda yazmaya kapanır.</li>
    </ul>
    <p class="gvd">Örnek: 12 aylık aboneliğin 4. ayında ayrılmak isteyen bir aboneye, kalan 8 tam ay oranında iade yapılır. Başlamış olan ay tam ay sayılır ve iadeye konu edilmez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">5. İade nasıl talep edilir?</h2>
    <p class="gvd">İade talebinizi, hesabınızın kayıtlı e-posta adresinden <x-legal.deger anahtar="support_email" ad="destek e-posta adresi" /> adresine "iade talebi" konusuyla iletmeniz yeterlidir. Talebinizde işletme adınızı ve firma kodunuzu belirtmeniz işlemi hızlandırır.</p>
    <p class="gvd">Talebiniz <strong>en geç 3 iş günü içinde</strong> değerlendirilir ve sonucu size yazılı olarak bildirilir. Talebin reddedilmesi hâlinde gerekçesi ayrıca yazılır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. İade ne zaman ve nasıl yapılır?</h2>
    <p class="gvd">Onaylanan iadeler, talebin tarafımıza ulaşmasından itibaren <strong>en geç 14 gün içinde</strong> gerçekleştirilir. İade, ödemenin alındığı yönteme göre yapılır:</p>
    <ul class="ys-liste">
        <li><b>Havale / EFT ile ödendiyse:</b> ödemenin geldiği hesaba veya Alıcı'nın yazılı olarak bildirdiği kendi adına kayıtlı IBAN'a.</li>
        <li><b>Elden ödendiyse:</b> Alıcı'nın yazılı olarak bildirdiği kendi adına kayıtlı IBAN'a havale ile.</li>
        <li><b>Kartla ödendiyse (bu yöntem devreye alındığında):</b> ödeme kuruluşu üzerinden aynı karta iade edilir. Tutarın kart ekstrenize yansıma süresi bankanıza bağlıdır ve Sipario'nun denetiminde değildir.</li>
    </ul>
    <p class="gvd">İade tutarından işlem masrafı, komisyon veya kesinti yapılmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">7. Otomatik yenileme yoktur</h2>
    <p class="gvd">Sipario aboneliği dönem sonunda kendiliğinden yenilenmez ve kartınızdan kendiliğinden ücret çekilmez. Dönem bitmeden önce size hatırlatma e-postası gönderilir; yenilemek isterseniz ödemeyi kendiniz yaparsınız. Bu nedenle "yenilemeyi durdurmak" için ayrıca bir işlem yapmanız gerekmez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">8. Süre dolduğunda ne olur?</h2>
    <p class="gvd">Deneme ya da abonelik süresi dolduğunda hesabınıza yeni kayıt girilemez. Var olan kayıtlarınız silinmez, Türkiye'deki sunucuda durmaya devam eder. Cihazınızda sunucuya gönderilmemiş bekleyen kayıtlarınız varsa bunlar yine sunucuya aktarılır — kilit yazmayı durdurur, veri kaybettirmez.</p>
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
