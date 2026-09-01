{{--
    MESAFELİ SATIŞ SÖZLEŞMESİ — 2026-08-19 tam metin.

    Bu belge 2026-08-19'da BAŞTAN YAZILDI. Öncesinde bir iskeletti: başlıklar vardı, gövde
    "avukat onayı beklenmektedir" cümleleriyle doluydu ve sayfanın en üstünde "PLACEHOLDER"
    yazan sarı bir kutu duruyordu. O kutu bir uyarı gibi görünüyordu ama işlevi başkaydı: ödeme
    ekranındaki onay kutusu bu belgeye bağlıdır, yani bayi "okudum, kabul ediyorum" derken
    kabul ettiği şey PLACEHOLDER yazan bir sayfaydı. Onay kaydı (`subscription_payments.
    consent_version`) o hâliyle hiçbir şeyin kanıtı değildi.

    ── DAYANAK ──────────────────────────────────────────────────────────────────────────────
    6502 sayılı Tüketicinin Korunması Hakkında Kanun (TKHK) ve Mesafeli Sözleşmeler Yönetmeliği
    (MSY). Yönetmelik m.5 ön bilgilendirmenin, m.6 sözleşmenin kurulmasının, m.9 cayma hakkının,
    m.15 cayma hakkı istisnalarının kaynağıdır.

    ── ALICI TACİRSE? — bu belgenin en zor sorusu ve saklanmıyor ────────────────────────────
    TKHK yalnız TÜKETİCİ işlemlerini kapsar; "tüketici", ticari veya mesleki olmayan amaçla
    hareket eden kişidir (TKHK m.3/k). Sipario'nun alıcısı paket servisi yapan bir işletmedir —
    yani ezici çoğunlukla ESNAF/TACİR ve aldığı hizmeti işinde kullanıyor. Böyle bir alıcı tüketici
    değildir; sözleşmeye TKHK değil, 6098 sayılı TBK'nın genel hükümleri uygulanır.

    İki yol vardı. (a) Sözleşmeyi yalnız TBK'ya göre yazmak — o zaman gerçek kişi olarak
    kaydolan az sayıdaki alıcı, TKHK'nın emredici korumasından mahrum bırakılmaya çalışılmış
    olurdu ki bu hüküm zaten geçersiz sayılır. (b) İki hâli de metnin İÇİNDE ayırmak.
    (b) seçildi: madde 6 cayma hakkını iki alıcı tipi için ayrı ayrı düzenliyor ve tacir alıcıya
    SÖZLEŞMEDEN DOĞAN (kanundan değil) bir cayma imkânı tanıyor. Bu, tacire kanunun vermediği
    bir hakkı sözleşmeyle vermektir — serbesttir ve satışı kolaylaştırır.

    ── KÜNYE ────────────────────────────────────────────────────────────────────────────────
    Satıcı künyesi `config('subscription.company')`den okunur ve `x-legal.deger` ile basılır.
    Değer yer tutucuysa ekranda "DOLDURULACAK: …" işareti çıkar; sayfa başlığı bu işaretleri
    sayıp uyarır. Uydurma unvan/MERSİS/IBAN YAZILMAZ — yanlış künyeli bir mesafeli satış
    sözleşmesi, hiç olmayandan daha kötüdür (MSY m.5/1-a satıcı kimliğini zorunlu kılar).
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">1. Taraflar ve konu</h2>
    <p class="gvd">İşbu Mesafeli Satış Sözleşmesi ("<strong>Sözleşme</strong>"), aşağıda künyesi yazılı Satıcı ile Sipario internet sitesi üzerinden abonelik satın alan Alıcı arasında, elektronik ortamda kurulmuştur. Sözleşme, Alıcı'nın Sipario yazılım hizmetine abone olmasına ilişkin tarafların hak ve yükümlülüklerini düzenler.</p>

    <h3 class="h4">Satıcı</h3>
    <ul class="ys-liste">
        <li><b>Unvan:</b> <x-legal.deger anahtar="title" ad="ticaret unvanı" /></li>
        <li><b>Adres:</b> <x-legal.deger anahtar="address" ad="açık adres" /></li>
        <li><b>MERSİS No:</b> <x-legal.deger anahtar="mersis" ad="MERSİS numarası" /></li>
        <li><b>Vergi dairesi / no:</b> <x-legal.deger anahtar="tax_office" ad="vergi dairesi ve numarası" /></li>
        <li><b>Telefon:</b> <x-legal.deger anahtar="phone" ad="telefon numarası" /></li>
        <li><b>E-posta:</b> <x-legal.deger anahtar="email" ad="e-posta adresi" /></li>
        <li><b>KEP adresi:</b> <x-legal.deger ad="KEP adresi" /></li>
        <li><b>İnternet sitesi:</b> sipario.com.tr</li>
    </ul>
    <p class="gvd">Bundan sonra "<strong>Satıcı</strong>" veya "<strong>Sipario</strong>" olarak anılacaktır.</p>

    <h3 class="h4">Alıcı</h3>
    <p class="gvd">Sipario internet sitesinde üyelik oluşturarak abonelik başlatan gerçek veya tüzel kişi ("<strong>Alıcı</strong>"). Alıcı'nın kimlik, iletişim ve fatura bilgileri, üyelik ve ödeme adımlarında kendisinin beyan ettiği bilgilerdir. Alıcı, beyan ettiği bilgilerin doğru ve güncel olduğunu kabul eder; bu bilgilerdeki değişikliği Sipario'ya bildirmemesinden doğan sonuçlar Alıcı'ya aittir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">2. Sözleşmenin kurulması</h2>
    <p class="gvd">Sözleşme, Alıcı'nın internet sitesindeki ödeme adımında Ön Bilgilendirme Formu'nu ve işbu Sözleşme'yi okuyup elektronik ortamda onaylaması ile kurulur. Onay anı, sözleşmenin kuruluş anıdır. Alıcı, onaydan önce Ön Bilgilendirme Formu'na ve bu Sözleşme'ye eriştiğini, ikisini de okuduğunu ve toplam bedeli gördüğünü kabul eder.</p>
    <p class="gvd">Sipario, kabul edilen belgelerin sürüm numaralarını ve onay zamanını kayıt altına alır. Bu kayıt, uyuşmazlık hâlinde hangi metnin kabul edildiğinin delilidir. Kayıtta kart bilgisi tutulmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">3. Hizmetin temel nitelikleri</h2>
    <p class="gvd">Sipario; eve servis yapan işletmeler için sipariş kaydı, veresiye (cari hesap) defteri, kurye atama ve teslim takibi, gün sonu kasa kapanışı ve gelen aramada müşteri tanıma işlevlerini sunan, internet üzerinden erişilen bir yazılım hizmetidir (SaaS). Hizmet; Android ve iOS mobil uygulaması ile sipario.com.tr üzerindeki hesap paneli aracılığıyla kullanılır.</p>
    <p class="gvd">Hizmetin güncel kapsamı, işlev listesi ve teknik gereksinimleri Sipario'nun internet sitesinde yayımlanır. Sipario, hizmetin işlevlerini geliştirebilir, iyileştirebilir ve teknik olarak değiştirebilir. Aboneliğin satın alındığı sırada var olan bir işlevin tamamen kaldırılması hâlinde Alıcı'ya en az 30 gün önce bildirim yapılır; Alıcı bu hâlde aboneliğini feshedip kalan dönem için oransal iade talep edebilir.</p>
    <p class="gvd">Gelen arama tanıma özelliği işletim sistemi kısıtları nedeniyle yalnız Android 10 ve üzeri cihazlarda çalışır; iOS'ta bu özellik bulunmaz, diğer tüm işlevler çalışır. Bu sınır bir ayıp değil, platformun kendi kısıtıdır ve satın alma öncesinde açıkça beyan edilmiştir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. Bedel, ödeme ve fatura</h2>
    <p class="gvd">Abonelik bedeli, sipariş anında internet sitesinde gösterilen tutardır. Gösterilen tutar Türk Lirası cinsindendir ve <x-legal.deger ad="KDV dahil/hariç ifadesi ve KDV oranı" /> şeklindedir. Alıcı, ödemeyi onaylamadan önce toplam bedeli, ödeme yöntemini ve abonelik süresini görür.</p>
    <p class="gvd">Ödeme, Alıcı'nın seçimine göre şu yollardan biriyle yapılır:</p>
    <ul class="ys-liste">
        <li><b>Havale / EFT:</b> Ödeme adımında görüntülenen banka hesabına, yine o adımda verilen referans kodu açıklamaya yazılarak yapılır. Ödeme, Satıcı hesabına geçtiğinin teyidiyle tamamlanmış sayılır.</li>
        <li><b>Elden ödeme:</b> Satıcı'nın hizmet verdiği bölgelerde, yerinde tahsilat ve makbuz karşılığında yapılır.</li>
        <li><b>Kredi / banka kartı:</b> Bu yöntem <x-legal.deger ad="kartlı ödemenin açılacağı tarih — açılmadan bu satır yayında kalmamalı" /> tarihinde devreye alınacaktır. Devreye alındığında ödeme, lisanslı ödeme kuruluşu iyzico altyapısı üzerinden alınır; kart bilgileri iyzico nezdinde tutulur, Satıcı kart verisini görmez ve saklamaz.</li>
    </ul>
    <p class="gvd">Satıcı, tahsil edilen her bedel için mevzuata uygun fatura düzenler ve Alıcı'nın hesabına elektronik ortamda iletir. Fatura, hesap panelindeki Faturalar bölümünden de indirilebilir.</p>
    <p class="gvd">Fiyat değişikliği yürürlükteki dönemi etkilemez. Yenilenen dönemde uygulanacak yeni bedel, dönem bitiminden en az 30 gün önce Alıcı'ya bildirilir; Alıcı bildirimden sonra yenilemeyi durdurabilir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">5. İfa ve aktivasyon</h2>
    <p class="gvd">Hizmet dijitaldir; fiziksel teslimat söz konusu değildir. Abonelik, ödemenin Satıcı tarafından teyit edilmesiyle birlikte derhal aktive edilir ve <strong>{{ (int) config('subscription.period_days') }} günlük</strong> abonelik süresi bu anda başlar.</p>
    <p class="gvd">Ödeme öncesinde Alıcı'ya <strong>{{ (int) config('subscription.trial_days') }} günlük ücretsiz deneme</strong> tanınır. Deneme süresi için ödeme bilgisi istenmez ve süre sonunda kendiliğinden ücret tahsil edilmez; deneme, Alıcı ödeme yapmadıkça aboneliğe dönüşmez.</p>
    <p class="gvd">Mücbir sebep veya Satıcı'dan kaynaklanmayan teknik engeller dışında aktivasyon, ödemenin teyidinden itibaren en geç 1 iş günü içinde tamamlanır. Mevzuatın öngördüğü azami ifa süresi olan 30 gün her hâlükârda aşılamaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. Cayma hakkı</h2>
    <p class="gvd">Cayma hakkı, Alıcı'nın tüketici sıfatı taşıyıp taşımadığına göre değişir. Bu ayrım metinde bilerek açık bırakılmıştır; Alıcı hangi hâlde olduğunu bilerek onay verir.</p>

    <h3 class="h4">6.1. Alıcı tüketici ise</h3>
    <p class="gvd">Alıcı, hizmeti ticari veya mesleki amaç dışında satın alıyorsa TKHK anlamında tüketicidir. Tüketici, sözleşmenin kurulduğu tarihten itibaren <strong>14 (on dört) gün</strong> içinde hiçbir gerekçe göstermeden ve cezai şart ödemeden sözleşmeden cayabilir (MSY m.9).</p>
    <p class="gvd">Ancak Mesafeli Sözleşmeler Yönetmeliği m.15/1-ğ uyarınca, <strong>elektronik ortamda anında ifa edilen hizmetlere</strong> ilişkin sözleşmelerde cayma hakkı kullanılamaz. Sipario, ödemenin teyidiyle derhal aktive edilen bir hizmettir ve bu istisnanın kapsamına girer. Bu nedenle Alıcı, ödeme adımında <strong>hizmetin derhal ifasına başlanmasını talep ettiğini ve bu hâlde cayma hakkını kaybedeceğini bildiğini</strong> ayrıca onaylar. Bu onay alınmadan hizmet aktive edilmez.</p>
    <p class="gvd">Satıcı, ödemeden önce hizmetin tamamının denenmesini sağlar: <strong>{{ (int) config('subscription.trial_days') }} günlük ücretsiz deneme</strong> süresince ödeme bilgisi istenmez ve süre sonunda kendiliğinden tahsilat yapılmaz. Buna karşılık <strong>ödenmiş dönem için iade yapılmaz</strong>; iadenin yapıldığı hâller (hatalı/mükerrer tahsilat, hizmetin durdurulması, satın alma sırasında var olan bir işlevin kaldırılması) <a href="{{ route('legal.show', 'iptal-iade') }}">İptal, Cayma ve İade Koşulları</a> belgesinde sayılmıştır.</p>

    <h3 class="h4">6.2. Alıcı tacir veya esnaf ise</h3>
    <p class="gvd">Alıcı hizmeti ticari ya da mesleki faaliyeti kapsamında satın alıyorsa TKHK anlamında tüketici değildir; sözleşmeye 6098 sayılı Türk Borçlar Kanunu'nun genel hükümleri uygulanır ve kanundan doğan bir cayma hakkı bulunmaz. Ücretsiz deneme ve iade düzeni her iki alıcı tipi için aynıdır — Satıcı bu koşulları alıcı tipine göre ayırmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">7. Süre, yenileme ve fesih</h2>
    <p class="gvd">Abonelik, aktivasyon tarihinden itibaren {{ (int) config('subscription.period_days') }} gün süreyle geçerlidir. Süre sonunda abonelik kendiliğinden ve otomatik olarak yenilenmez; yenileme, Alıcı'nın yeni dönem bedelini ödemesiyle gerçekleşir. Satıcı, dönem bitiminden önce Alıcı'yı e-posta ile hatırlatarak bilgilendirir.</p>
    <p class="gvd">Alıcı, aboneliğini dilediği zaman hesap panelinden veya destek kanalından iptal edebilir. İptal, cari dönemin sonunda hüküm doğurur; dönem sonuna kadar hizmete erişim devam eder. İptal için gerekçe göstermek veya telefon etmek gerekmez.</p>
    <p class="gvd">Satıcı, Alıcı'nın işbu Sözleşme'ye veya Kullanım Koşulları'na ağır şekilde aykırı davranması hâlinde aboneliği askıya alabilir ya da feshedebilir. Fesih hâlinde Alıcı'ya durum gerekçesiyle bildirilir ve kalan döneme ilişkin bedel oransal olarak iade edilir; aykırılık Alıcı'nın kastından kaynaklanıyorsa iade yapılmaz.</p>
    <p class="gvd"><strong>Süre dolduğunda veri silinmez.</strong> Abonelik süresi dolan veya iptal edilen hesapta veri girişi (yazma) durur; mevcut kayıtlar sunucularımızda saklanmaya devam eder. Abonelik yenilendiğinde tüm veri eksiksiz geri gelir. Alıcı, aboneliği sona ermiş olsa dahi destek kanalı üzerinden verisinin dışa aktarımını her zaman talep edebilir. Sipario, tahsilat baskısı amacıyla Alıcı'nın verisini erişilmez kılmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">8. Tarafların yükümlülükleri</h2>
    <p class="gvd"><strong>Satıcı</strong>, hizmeti işbu Sözleşme ve internet sitesinde tanımlandığı şekilde sunmayı, hizmetin sürekliliği için makul teknik tedbirleri almayı, düzenli yedek almayı ve kişisel verileri KVKK'ya uygun işlemeyi taahhüt eder. Planlı bakım çalışmaları, mümkün olduğunca yoğun olmayan saatlerde ve önceden bildirimle yapılır.</p>
    <p class="gvd"><strong>Alıcı</strong>, hesap ve giriş bilgilerinin güvenliğini sağlamayı, bu bilgileri yetkisiz kişilerle paylaşmamayı, hizmeti hukuka aykırı amaçlarla kullanmamayı ve kendi müşterilerine ait kişisel veriler bakımından veri sorumlusu sıfatıyla doğan yükümlülüklerini yerine getirmeyi kabul eder. Ayrıntılı kurallar "Kullanım Koşulları ve Üyelik Sözleşmesi" ile "Veri İşleyen Sözleşmesi (Ek-1)" belgelerinde düzenlenmiştir; her ikisi de işbu Sözleşme'nin ayrılmaz ekidir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">9. Sorumluluk</h2>
    <p class="gvd">Sipario, hizmeti mevcut hâliyle ve makul özenle sunar. Alıcı'nın veri girişinden, girdiği verilerin doğruluğundan ve bu verilere dayanarak aldığı ticari kararlardan Sipario sorumlu değildir. Sipario'nun sorumluluğu her hâlükârda, sorumluluğu doğuran olayın gerçekleştiği tarihten geriye doğru 12 ay içinde Alıcı'dan tahsil edilmiş abonelik bedeli ile sınırlıdır.</p>
    <p class="gvd">Bu sınırlama; Sipario'nun kastından veya ağır ihmalinden doğan zararlar ile mevzuatın sınırlandırılmasına izin vermediği sorumluluk hâlleri bakımından uygulanmaz. Alıcı tüketici ise, tüketici mevzuatının emredici hükümleri saklıdır.</p>
    <p class="gvd">İnternet altyapısındaki kesintiler, elektrik kesintileri, cihaz arızaları, işletim sistemi veya uygulama mağazası kaynaklı kısıtlar ile mücbir sebepler nedeniyle oluşan erişim sorunlarından Sipario sorumlu tutulamaz. Uygulamanın çevrimdışı çalışabildiği hâllerde veri kaybı yaşanmaması için gerekli teknik tasarım yapılmıştır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">10. Fikri mülkiyet</h2>
    <p class="gvd">Sipario yazılımı, kaynak kodu, arayüz tasarımı, marka, logo ve tüm içeriği üzerindeki haklar Satıcı'ya aittir ve 5846 sayılı Fikir ve Sanat Eserleri Kanunu ile ilgili mevzuat kapsamında korunur. Alıcı'ya, abonelik süresiyle sınırlı, devredilemez ve münhasır olmayan bir kullanım hakkı tanınır. Alıcı yazılımı kopyalayamaz, tersine mühendislik yapamaz, kiralayamaz veya üçüncü kişilere kullandıramaz.</p>
    <p class="gvd">Alıcı'nın hizmete girdiği veriler (müşteri kayıtları, siparişler, defter kayıtları) Alıcı'ya aittir. Sipario bu veriler üzerinde, hizmeti sunmak için gereken işlemler dışında hiçbir hak iddia etmez ve bu verileri kendi ticari amaçları için kullanmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">11. Kişisel verilerin korunması</h2>
    <p class="gvd">Kişisel verilerin işlenmesine ilişkin ayrıntılı bilgi "KVKK Aydınlatma Metni", "Gizlilik Politikası" ve "Çerez Politikası" belgelerinde yer alır. Alıcı'nın kendi müşterilerine ait verilere ilişkin veri sorumlusu–veri işleyen ilişkisi "Veri İşleyen Sözleşmesi (Ek-1)" ile kurulmuştur.</p>
</div>

<div class="ys-b">
    <h2 class="h3">12. Bildirimler</h2>
    <p class="gvd">Taraflar arasındaki bildirimler, Alıcı'nın üyelik sırasında beyan ettiği e-posta adresi ile Satıcı'nın yukarıda yazılı e-posta ve KEP adresi üzerinden yapılır. Alıcı'nın beyan ettiği adrese yapılan bildirim geçerli sayılır; adres değişikliği Satıcı'ya bildirilmedikçe eski adrese yapılan bildirim hüküm doğurur.</p>
</div>

<div class="ys-b">
    <h2 class="h3">13. Uyuşmazlıkların çözümü</h2>
    <p class="gvd">Alıcı'nın tüketici olduğu hâllerde; Ticaret Bakanlığı'nca her yıl ilan edilen parasal sınırlar dahilinde Alıcı'nın yerleşim yerindeki veya işlemin yapıldığı yerdeki <strong>Tüketici Hakem Heyetleri</strong>, bu sınırların üzerindeki uyuşmazlıklarda <strong>Tüketici Mahkemeleri</strong> yetkilidir. Alıcı, şikâyetlerini Ticaret Bakanlığı'nın e-Devlet üzerinden erişilen Tüketici Bilgi Sistemi (TÜBİS) aracılığıyla da iletebilir.</p>
    <p class="gvd">Alıcı'nın tacir olduğu hâllerde, taraflar arasındaki uyuşmazlıklarda <x-legal.deger ad="yetkili mahkeme ve icra daireleri (ör. şirket merkezinin bulunduğu yer)" /> yetkilidir. Ticari davalarda dava şartı olan arabuluculuk hükümleri (6325 sayılı Kanun m.18/A) saklıdır.</p>
    <p class="gvd">İşbu Sözleşme'ye Türk hukuku uygulanır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">14. Yürürlük ve ekler</h2>
    <p class="gvd">İşbu Sözleşme 14 maddeden ibaret olup, Alıcı'nın elektronik ortamda onaylaması ile yürürlüğe girer. Sözleşme'nin bir örneği Alıcı'nın erişimine açık tutulur ve hesap panelinden her zaman görüntülenebilir.</p>
    <p class="gvd">Aşağıdaki belgeler Sözleşme'nin ayrılmaz ekidir ve Alıcı bunları da okuyup kabul etmiş sayılır:</p>
    <ul class="ys-liste">
        <li><a href="{{ route('legal.show', 'on-bilgilendirme') }}">Ön Bilgilendirme Formu</a></li>
        <li><a href="{{ route('legal.show', 'iptal-iade') }}">İptal, Cayma ve İade Koşulları</a></li>
        <li><a href="{{ route('legal.show', 'kullanim-kosullari') }}">Kullanım Koşulları ve Üyelik Sözleşmesi</a></li>
        <li><a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK Aydınlatma Metni</a></li>
        <li><a href="{{ route('legal.show', 'veri-isleyen') }}">Veri İşleyen Sözleşmesi (Ek-1)</a></li>
    </ul>
</div>
