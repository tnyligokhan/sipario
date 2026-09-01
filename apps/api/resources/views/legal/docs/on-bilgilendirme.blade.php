{{--
    ÖN BİLGİLENDİRME FORMU — 2026-08-19 tam metin.

    Dayanak: Mesafeli Sözleşmeler Yönetmeliği m.5. Bu form, sözleşme kurulmadan ÖNCE alıcıya
    verilmesi zorunlu bilgileri taşır. Yönetmeliğin saydığı asgari kalemlerin her biri aşağıda
    kendi başlığıyla duruyor — sıra yönetmelikteki sırayla değil, okunabilirlik sırasıyla
    dizildi, ama hiçbiri atlanmadı.

    ⚠️ Bu formun mesafeli satış sözleşmesiyle ÇELİŞMEMESİ mevzuat gereğidir (çelişki hâlinde
    tüketici lehine olan uygulanır). İkisi de aynı config değerlerini (süre, deneme, künye)
    okuyor; sabit yazılan bir sayı ikisini ayrı ayrı bayatlatırdı.
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">Bu form ne işe yarar?</h2>
    <p class="gvd">Mesafeli Sözleşmeler Yönetmeliği, internet üzerinden satılan bir hizmette sözleşme kurulmadan önce alıcının belirli bilgileri edinmesini zorunlu kılar. Bu form o bilgileri taşır. Aşağıdakileri okuyup onayladıktan sonra Mesafeli Satış Sözleşmesi'ni onaylayarak aboneliğinizi başlatabilirsiniz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">1. Satıcı bilgileri</h2>
    <ul class="ys-liste">
        <li><b>Unvan:</b> <x-legal.deger anahtar="title" ad="ticaret unvanı" /></li>
        <li><b>Adres:</b> <x-legal.deger anahtar="address" ad="açık adres" /></li>
        <li><b>MERSİS No:</b> <x-legal.deger anahtar="mersis" ad="MERSİS numarası" /></li>
        <li><b>Vergi dairesi / no:</b> <x-legal.deger anahtar="tax_office" ad="vergi dairesi ve numarası" /></li>
        <li><b>Telefon:</b> <x-legal.deger anahtar="phone" ad="telefon numarası" /></li>
        <li><b>E-posta:</b> <x-legal.deger anahtar="email" ad="e-posta adresi" /></li>
        <li><b>KEP adresi:</b> <x-legal.deger ad="KEP adresi" /></li>
        <li><b>Şikâyet ve talepler için:</b> <x-legal.deger anahtar="support_email" ad="destek e-posta adresi" /></li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">2. Hizmetin temel nitelikleri</h2>
    <p class="gvd">Sipario, eve servis yapan işletmeler için sipariş kaydı, veresiye (cari hesap) defteri, kurye atama ve teslim takibi, gün sonu kasa kapanışı ve gelen aramada müşteri tanıma işlevlerini sunan bir yazılım hizmetidir. Hizmete Android/iOS mobil uygulaması ve sipario.com.tr üzerindeki hesap paneli ile erişilir.</p>
    <p class="gvd">Hizmet fiziksel bir ürün içermez; herhangi bir cihaz, donanım veya kurulum medyası gönderilmez.</p>
    <p class="gvd"><strong>Bilinmesi gereken teknik sınır:</strong> gelen arama tanıma özelliği, işletim sistemi kısıtları nedeniyle yalnız Android 10 ve üzeri cihazlarda çalışır. iOS cihazlarda bu özellik bulunmaz; diğer tüm işlevler iOS'ta da çalışır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">3. Toplam bedel ve vergiler</h2>
    <p class="gvd">Abonelik bedeli, sipariş anında internet sitesinde görüntülenen tutardır ve Türk Lirası cinsindendir. Gösterilen tutar <x-legal.deger ad="KDV dahil/hariç ifadesi ve KDV oranı" /> şeklindedir. Bedele ek olarak kargo, teslimat veya kurulum ücreti alınmaz.</p>
    <p class="gvd">Ödeme yönteminin doğurduğu masraflar (ör. bankanızın havale/EFT ücreti) size aittir. Satıcı, ödeme yöntemi nedeniyle ayrıca bir fark ücreti yansıtmaz.</p>
    <p class="gvd">Alıcı, ödemeyi onaylamadan önceki ekranda toplam bedeli, abonelik süresini ve ödeme yöntemini görür.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. Ödeme şekli</h2>
    <p class="gvd">Ödeme; havale/EFT veya elden ödeme yoluyla, tek seferde ve peşin olarak alınır. Kredi ve banka kartıyla online ödeme <x-legal.deger ad="kartlı ödemenin açılacağı tarih" /> tarihinde devreye alınacaktır; devreye alındığında ödeme lisanslı ödeme kuruluşu iyzico altyapısı üzerinden yapılacak, kart bilgileri iyzico nezdinde tutulacak ve Satıcı tarafından saklanmayacaktır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">5. İfa ve süre</h2>
    <p class="gvd">Hizmet, ödemenin teyidiyle birlikte dijital ortamda derhal aktive edilir; aktivasyon en geç 1 iş günü içinde tamamlanır ve mevzuatın öngördüğü 30 günlük azami ifa süresi hiçbir hâlde aşılmaz.</p>
    <p class="gvd">Abonelik süresi <strong>{{ (int) config('subscription.period_days') }} gündür</strong>. Süre sonunda abonelik kendiliğinden yenilenmez ve otomatik ücret tahsil edilmez; yenileme, yeni dönem bedelinin ödenmesiyle olur.</p>
    <p class="gvd">Ödeme öncesinde <strong>{{ (int) config('subscription.trial_days') }} günlük ücretsiz deneme</strong> tanınır. Deneme için ödeme bilgisi istenmez; deneme süresi sonunda kendiliğinden ücretli aboneliğe geçilmez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. Cayma hakkı</h2>
    <p class="gvd">Tüketici sıfatıyla alım yapıyorsanız, kural olarak sözleşmenin kurulmasından itibaren 14 gün içinde cayma hakkınız bulunur. Ancak Mesafeli Sözleşmeler Yönetmeliği m.15/1-ğ uyarınca <strong>elektronik ortamda anında ifa edilen hizmetlerde cayma hakkı kullanılamaz.</strong> Sipario ödemenin teyidiyle derhal aktive edildiğinden bu istisna kapsamındadır.</p>
    <p class="gvd">Bu nedenle ödeme adımında, hizmetin derhal ifasına başlanmasını talep ettiğinizi ve bu hâlde cayma hakkınızı kaybedeceğinizi bildiğinizi ayrıca onaylamanız istenir. Onay vermezseniz hizmet aktive edilmez.</p>
    <p class="gvd"><strong>Ödenmiş dönem için iade yapılmaz.</strong> Bunun yerine ödemeden önce hizmetin tamamı ücretsiz denenir: {{ (int) config('subscription.trial_days') }} gün boyunca ödeme bilgisi istenmez ve süre sonunda kendiliğinden tahsilat yapılmaz. İadenin yapıldığı hâller (hatalı ya da mükerrer tahsilat, hizmetin tamamen durdurulması, satın alma sırasında var olan bir işlevin kaldırılması) <a href="{{ route('legal.show', 'iptal-iade') }}">İptal, Cayma ve İade Koşulları</a> belgesinde sayılmıştır.</p>
    <p class="gvd">Ticari veya mesleki amaçla alım yapan tacir/esnaf alıcılar bakımından kanundan doğan bir cayma hakkı bulunmaz; ücretsiz deneme ve iade düzeni onlar için de aynen geçerlidir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">7. Aboneliğin iptali</h2>
    <p class="gvd">Aboneliğinizi dilediğiniz zaman hesap panelinizden veya destek kanalından iptal edebilirsiniz. İptal, içinde bulunduğunuz dönemin sonunda hüküm doğurur; o güne kadar hizmete erişiminiz devam eder. Gerekçe göstermeniz veya telefon etmeniz gerekmez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">8. Verilerinizin akıbeti</h2>
    <p class="gvd">Abonelik sona erse veya iptal edilse dahi verileriniz silinmez; sunucularımızda saklanmaya devam eder ve abonelik yenilendiğinde eksiksiz geri gelir. Süre dolduğunda yalnız yeni kayıt girişi (yazma) durur.</p>
    <p class="gvd">Destek kanalı üzerinden her zaman verilerinizin dışa aktarımını (export) talep edebilirsiniz. Verilerinizin silinmesini istiyorsanız <a href="{{ route('account.deletion') }}">Hesap ve Veri Silme</a> sayfasındaki yolu izleyebilirsiniz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">9. Şikâyet ve başvuru yolları</h2>
    <p class="gvd">Şikâyet ve taleplerinizi öncelikle yukarıda yazılı destek kanallarına iletebilirsiniz. Çözüme ulaşılamazsa, tüketici sıfatı taşıyorsanız; Ticaret Bakanlığı'nca her yıl ilan edilen parasal sınırlar dahilinde yerleşim yerinizdeki <strong>Tüketici Hakem Heyeti'ne</strong>, sınırların üzerinde ise <strong>Tüketici Mahkemesi'ne</strong> başvurabilirsiniz. Başvurular e-Devlet üzerinden Tüketici Bilgi Sistemi (TÜBİS) ile de yapılabilir.</p>
    <p class="gvd">Tacir sıfatıyla alım yaptıysanız uyuşmazlıklarda <x-legal.deger ad="yetkili mahkeme ve icra daireleri" /> yetkilidir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">10. Kayıt ve saklama</h2>
    <p class="gvd">Bu formu ve Mesafeli Satış Sözleşmesi'ni onayladığınızda, onay zamanı ve onayladığınız belge sürümleri kayıt altına alınır. Bu kayıt uyuşmazlık hâlinde delil niteliğindedir ve talebiniz üzerine size iletilir. Kayıtta kart bilgisi tutulmaz.</p>
    <p class="gvd">Belgelerin bu sürümü <strong>{{ config('subscription.legal.preinfo_version') }}</strong> tarihlidir ve <a href="{{ route('site.hesap') }}">hesap panelinizden</a> her zaman görüntülenebilir.</p>
</div>
