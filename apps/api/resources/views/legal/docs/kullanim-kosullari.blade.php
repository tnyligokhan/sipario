{{--
    KULLANIM KOŞULLARI VE ÜYELİK SÖZLEŞMESİ — 2026-08-19, YENİ BELGE.

    ── NEDEN VARDI OLMASI GEREKİYORDU ───────────────────────────────────────────────────────
    Bu belge daha önce YOKTU ve yokluğu görünür bir ize de sahipti: kayıt ekranının onay
    satırında bir zamanlar "kullanım koşulları" yazıyordu, sonra "ön bilgilendirme formu"na
    çevrilmişti — çünkü bağlanacak bir belge yoktu (bkz. register.blade.php'nin kendi notu,
    sapma 3). Yani ihtiyaç tespit edilmiş, belge yazılamadığı için METİN kısılmıştı.

    Mesafeli satış sözleşmesi SATIŞI düzenler: bedel, ifa, cayma, iade. Hesabın nasıl
    KULLANILACAĞINI düzenlemez — kimin hesap açabileceğini, parola sorumluluğunu, kurye
    hesaplarının bayiye bağlılığını, hangi kullanımın yasak olduğunu, hizmetin kesilebileceği
    hâlleri. Bunlar satış sözleşmesine sıkıştırılırsa sözleşme okunmaz uzunluğa çıkar ve
    mevzuatın istediği ön bilgilendirme kalemleri kalabalıkta kaybolur.

    ── ÜRÜNE UYGUNLUK ───────────────────────────────────────────────────────────────────────
    Metindeki her kural ürünün GERÇEK davranışına bakılarak yazıldı:
      • Mobil uygulamada kayıt ekranı yoktur, yalnız giriş vardır (mağaza kuralı, BRIEF).
      • Kurye/operatör hesapları web'e girmez; firma kodu + kullanıcı adı + parola ile mobilden
        girer (login.blade.php'nin alt yazısı da bunu söylüyor).
      • Para ve hareket kayıtları silinmez, düzeltme kaydıyla düzeltilir (BRIEF kırmızı çizgi 2).
      • Oto-sıralama aylık kontörlüdür (`route_credits_monthly`).
    Ürünün yapmadığı hiçbir şey burada vaat edilmedi — özellikle bir ÇALIŞMA SÜRESİ GARANTİSİ
    (SLA) verilmedi. Ölçülmeyen bir oranı sözleşmeye yazmak, ilk kesintide ihlal edilmiş bir
    taahhüt üretir.
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">1. Taraflar ve kapsam</h2>
    <p class="gvd">İşbu Kullanım Koşulları ve Üyelik Sözleşmesi ("<strong>Koşullar</strong>"), <x-legal.deger anahtar="title" ad="ticaret unvanı" /> ("<strong>Sipario</strong>") tarafından sunulan Sipario yazılım hizmetinin kullanımına ilişkin kuralları belirler. Hizmeti kullanan herkes — abone işletme, işletmenin yetkilisi, operatörü ve kuryesi — bu Koşulları kabul etmiş sayılır.</p>
    <p class="gvd">Bu belge, Mesafeli Satış Sözleşmesi'nin ayrılmaz ekidir. Satışa ilişkin hükümler (bedel, ifa, cayma, iade) o sözleşmede; kullanıma ilişkin hükümler burada düzenlenmiştir. İki metin çelişirse, satışa ilişkin konularda Mesafeli Satış Sözleşmesi esas alınır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">2. Tanımlar</h2>
    <ul class="ys-liste">
        <li><b>İşletme (Abone):</b> Sipario'ya abone olan gerçek veya tüzel kişi. Hesabın ve içindeki verinin sahibi.</li>
        <li><b>Firma kodu:</b> İşletmeye özel, mobil uygulamaya girişte kullanılan kimlik.</li>
        <li><b>Patron hesabı:</b> İşletmenin yetkilisine ait, tüm yetkilere sahip kullanıcı. Web hesap paneline yalnız bu hesap girer.</li>
        <li><b>Ekip hesabı:</b> İşletmenin açtığı operatör ve kurye kullanıcıları. Mobil uygulamadan, firma koduyla giriş yapar; web paneline erişemez.</li>
        <li><b>İş verisi:</b> İşletmenin hizmete girdiği müşteri, sipariş, teslimat ve defter kayıtları.</li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">3. Hesap açma ve kullanma ehliyeti</h2>
    <p class="gvd">Hesap yalnız sipario.com.tr üzerinden veya Sipario ile yapılan satış/kurulum süreciyle açılır. <strong>Mobil uygulamada kayıt ekranı yoktur</strong>; uygulama, mevcut bir hesapla giriş yapılarak kullanılır.</p>
    <p class="gvd">Hesap açan kişi, 18 yaşını doldurmuş ve işletmeyi temsile yetkili olduğunu beyan eder. Tüzel kişi adına hesap açan kişi, o tüzel kişiyi temsile yetkili olduğunu kabul eder.</p>
    <p class="gvd">Beyan edilen bilgilerin doğruluğundan İşletme sorumludur. Sipario, gerçeğe aykırı beyanla açıldığı anlaşılan hesabı askıya alma hakkını saklı tutar.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. Hesap güvenliği</h2>
    <p class="gvd">Parolanın ve firma kodunun gizliliğinden İşletme sorumludur. Sipario hiçbir zaman telefonla, e-postayla veya mesajla parolanızı istemez; böyle bir talep gelirse dolandırıcılıktır, lütfen bize bildirin.</p>
    <p class="gvd">Her kullanıcının kendi hesabı olmalıdır. Aynı hesabın birden çok kişiyle paylaşılması, kimin hangi kaydı girdiğinin izlenmesini imkânsız kılar ve doğacak sonuçlardan İşletme sorumlu olur.</p>
    <p class="gvd">Hesabınızın yetkisiz kullanıldığını fark ederseniz derhal parolanızı değiştirin ve destek kanalına bildirin. Bildirim öncesinde hesabınızdan yapılan işlemlerden Sipario sorumlu tutulamaz.</p>
    <p class="gvd">Sipario, hesabınıza yeni bir cihazdan giriş yapıldığında ve parolanız değiştirildiğinde sizi e-posta ile bilgilendirir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">5. Ekip hesapları</h2>
    <p class="gvd">İşletme, plan kapsamındaki sayı kadar kurye hesabı açabilir; ek hesaplar ücretli paketlerle tanımlanır. Ekip hesapları İşletme'ye bağlıdır ve İşletme tarafından açılır, kapatılır, yetkilendirilir.</p>
    <p class="gvd">Kurye hesabı yalnız kendisine atanan teslimatları görür; fiyat listesi, veresiye defteri ve ayarlar bu hesaba kapalıdır. İşletme, ekip üyelerinin bu Koşullara uygun davranmasından sorumludur.</p>
    <p class="gvd">İşletme, ekip üyelerini kendi kişisel verilerinin işlendiği konusunda bilgilendirmekle yükümlüdür. Ekip üyelerinin verileri bakımından veri sorumlusu İşletme'dir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. Kabul edilebilir kullanım</h2>
    <p class="gvd">Hizmeti kullanırken aşağıdakileri yapmamayı kabul edersiniz:</p>
    <ul class="ys-liste">
        <li>Hizmeti hukuka aykırı bir faaliyette kullanmak veya suç teşkil eden içerik kaydetmek.</li>
        <li>Kendinize ait olmayan kişisel verileri, hukuki bir dayanağınız olmaksızın sisteme girmek.</li>
        <li>Sisteme yetkisiz erişmeye çalışmak, güvenlik önlemlerini aşmaya teşebbüs etmek, otomatik araçlarla aşırı yük bindirmek.</li>
        <li>Yazılımı kopyalamak, tersine mühendislik yapmak, kiralamak, üçüncü kişilere kullandırmak veya hizmeti kendi adınıza yeniden satmak.</li>
        <li>Başka bir işletmenin verisine erişmeye çalışmak. Sistem bunu teknik olarak engeller; teşebbüs, sözleşmeye ağır aykırılıktır.</li>
        <li>Hizmet üzerinden izinsiz toplu ticari elektronik ileti göndermek. Müşterilerinize gönderdiğiniz her mesajın hukuki sorumluluğu size aittir (6563 sayılı Kanun).</li>
    </ul>
    <p class="gvd">Bu kurallara aykırılık hâlinde Sipario, aykırılığın ağırlığına göre uyarı yapabilir, ilgili işlevi kısıtlayabilir, hesabı askıya alabilir veya sözleşmeyi feshedebilir. Askıya alma hâlinde gerekçe yazılı olarak bildirilir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">7. Gelen arama tanıma özelliği</h2>
    <p class="gvd">Gelen arama tanıma, Android işletim sisteminin çağrı tarama servisi kullanılarak çalışır. Gelen numara, <strong>yalnız cihaz üzerinde</strong> sizin müşteri listenizle karşılaştırılır; numaralar bu amaçla Sipario sunucularına veya üçüncü taraflara gönderilmez.</p>
    <p class="gvd">Özelliğin çalışması, cihazın izin ayarlarına ve üreticinin pil yönetimi davranışına bağlıdır. Bazı cihaz markalarının agresif pil yönetimi arka plan servislerini durdurabilir; bu durum işletim sisteminden kaynaklanır ve Sipario'nun denetiminde değildir. Kurulum sırasında gerekli ayarlar için yönlendirme yapılır.</p>
    <p class="gvd">iOS'ta işletim sistemi çağrı yakalamaya izin vermediğinden bu özellik bulunmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">8. Çevrimdışı çalışma ve senkronizasyon</h2>
    <p class="gvd">Uygulama internet bağlantısı olmadan da çalışır; sipariş, teslimat ve tahsilat kayıtları cihazda tutulur ve bağlantı geldiğinde sunucuya aktarılır. Bu tasarım veri kaybını önlemek içindir.</p>
    <p class="gvd">Aynı kaydın iki cihazda birbirinden habersiz değiştirilmesi hâlinde sistem, çakışmayı veri kaybetmeden çözer. Ancak <strong>cihazınızı senkronizasyon tamamlanmadan siler, biçimlendirir veya uygulamayı kaldırırsanız</strong>, o cihazda bekleyen kayıtlar geri getirilemez. Uygulamayı kaldırmadan önce bağlantının açık olduğundan emin olun.</p>
</div>

<div class="ys-b">
    <h2 class="h3">9. Para kayıtlarının değiştirilemezliği</h2>
    <p class="gvd">Sipario'da para ve hareket kayıtları silinmez ve üzerine yazılmaz. Bir hata düzeltilecekse, düzeltme kaydı eklenerek düzeltilir; hatalı kayıt görünür kalır. Bakiyeler bu kayıtlardan hesaplanır.</p>
    <p class="gvd">Bu, ürünün bilinçli bir tasarım kararıdır: eksik veya fazla bir tahsilat, sonradan silinebilir olsaydı deftere güvenilemezdi. İşletme bu davranışı kabul eder ve "kaydı tamamen sil" gibi bir talebin karşılanamayacağını bilir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">10. Kotalar ve ek paketler</h2>
    <p class="gvd">Müşteri ve sipariş sayısında sınır yoktur. Rota oto-sıralama özelliği aylık kontör esasına tabidir; plan kapsamındaki aylık kontör her ayın başında yenilenir ve devretmez. Kontör bittiğinde sıralamayı elle yapmaya devam edebilirsiniz — hizmetin hiçbir temel işlevi kontöre bağlı değildir.</p>
    <p class="gvd">Ek kurye hesabı ve ek kontör paketleri, hesap panelinizde güncel fiyatlarıyla listelenir. Ek paket bedelleri abonelik bedelinden ayrı tahsil edilir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">11. Hizmetin sürekliliği ve bakım</h2>
    <p class="gvd">Sipario, hizmetin kesintisiz çalışması için makul teknik tedbirleri alır ve düzenli yedek alır. <strong>Belirli bir çalışma süresi (uptime) oranı garanti edilmemektedir.</strong> Böyle bir oran ölçülüp taahhüt edilene kadar, ölçülmemiş bir sayı bu metne yazılmayacaktır.</p>
    <p class="gvd">Planlı bakım çalışmaları mümkün olduğunca yoğun olmayan saatlerde yapılır ve önceden duyurulur. Acil güvenlik müdahaleleri önceden duyurulmadan yapılabilir.</p>
    <p class="gvd">Uygulamanın çevrimdışı çalışabilmesi sayesinde, sunucu tarafındaki kısa kesintiler saha işini durdurmaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">12. Destek</h2>
    <p class="gvd">Destek, <x-legal.deger anahtar="hours" ad="destek saatleri" /> aralığında telefon, WhatsApp ve e-posta ile verilir. Talepler aynı gün içinde yanıtlanmaya çalışılır; mesai dışında gelenler ertesi iş günü karşılanır.</p>
    <p class="gvd">Kurulum ve müşteri listesi aktarımı desteği ücretsizdir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">13. Verinin sahipliği ve dışa aktarım</h2>
    <p class="gvd">İş verisi İşletme'ye aittir. Sipario bu veriyi yalnız hizmeti sunmak için işler; kendi ticari amaçları için kullanmaz, üçüncü kişilere satmaz, reklam amacıyla paylaşmaz ve yapay zekâ modeli eğitiminde kullanmaz.</p>
    <p class="gvd">İşletme, destek kanalı üzerinden her zaman verisinin dışa aktarımını talep edebilir. Bu talep, abonelik sona ermiş olsa dahi karşılanır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">14. Fikri mülkiyet</h2>
    <p class="gvd">Sipario yazılımı, arayüzü, marka ve logosu üzerindeki tüm haklar Sipario'ya aittir ve 5846 sayılı Fikir ve Sanat Eserleri Kanunu ile ilgili mevzuat kapsamında korunur. Abonelik, yazılım üzerinde bir mülkiyet hakkı değil; süreyle sınırlı, devredilemez ve münhasır olmayan bir kullanım hakkı verir.</p>
</div>

<div class="ys-b">
    <h2 class="h3">15. Koşullardaki değişiklikler</h2>
    <p class="gvd">Sipario bu Koşulları güncelleyebilir. Aleyhe olan esaslı değişiklikler yürürlüğe girmeden en az 30 gün önce e-posta ile bildirilir. Bildirimden sonra hizmeti kullanmaya devam etmeniz yeni sürümü kabul ettiğiniz anlamına gelir; kabul etmiyorsanız aboneliğinizi feshedip kalan dönem için oransal iade talep edebilirsiniz.</p>
    <p class="gvd">Her sürümün tarihi belgenin üstünde yazılıdır. Bu sürüm: <strong>{{ config('subscription.legal.terms_version') }}</strong>.</p>
</div>

<div class="ys-b">
    <h2 class="h3">16. Uygulanacak hukuk ve yetki</h2>
    <p class="gvd">Bu Koşullara Türk hukuku uygulanır. Uyuşmazlıklarda; İşletme tüketici sıfatı taşıyorsa Tüketici Hakem Heyetleri ve Tüketici Mahkemeleri, aksi hâlde <x-legal.deger ad="yetkili mahkeme ve icra daireleri" /> yetkilidir.</p>
</div>
