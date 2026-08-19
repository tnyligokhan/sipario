{{--
    KVKK AYDINLATMA METNİ — 2026-08-19 tam metin.

    Dayanak: 6698 sayılı KVKK m.10 ve "Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak
    Usul ve Esaslar Hakkında Tebliğ". Tebliğ, aydınlatmanın ilgili kişiye AYRI AYRI ve AÇIKÇA
    yapılmasını, genel geçer ifadelerden kaçınılmasını ister; bu yüzden metin veri kategorisi →
    amaç → hukuki sebep üçlüsünü tablo hâlinde veriyor, tek paragrafa yığmıyor.

    ── ÜÇ ESASLI DÜZELTME (eski metin bunları YANLIŞ söylüyordu) ────────────────────────────

    1) "AÇIK RIZA" AYRILDI. Eski metnin başlığı "KVKK Aydınlatma Metni ve Açık Rıza"ydı ve
       ödeme ekranındaki onay kutusu bu belgeye bağlıydı. Aydınlatma ile açık rızayı aynı
       belgede birleştirip tek kutuyla onaylatmak, KVKK'nın ayrı tuttuğu iki şeyi karıştırır:
       aydınlatma bir BİLGİLENDİRMEDİR, onay gerektirmez; açık rıza ise özgür iradeyle,
       BELİRLİ bir konuya ilişkin ve AYRI verilmelidir. Hizmetin sunulması için rıza zaten
       gerekmiyor (m.5/2-c sözleşme şartı) — rızayı hizmetin önkoşulu gibi göstermek rızayı
       geçersiz kılar. Açık rıza artık ayrı bir belgedir ve YALNIZ pazarlama iletileri ile
       ölçüm çerezlerini kapsar.

    2) YURT DIŞINA AKTARIM İTİRAF EDİLDİ. Eski metin "Verileriniz Türkiye dışına çıkmaz"
       diyordu. Bu DOĞRU DEĞİLDİ ve kodu okuyunca görülüyor: coğrafi kodlama adres metnini
       Yandex/Google'a yolluyor (config/geocoding.php), rota sıralaması koordinatları Google
       Routes'a yolluyor (config/rota.php), anlık bildirim cihaz jetonunu Google FCM'e yolluyor
       (app/Bildirim/FcmIstemcisi.php) ve bu vardiyada siteye Google Analytics eklendi.
       SAKLAMA Türkiye'dedir — bu doğru ve kırmızı çizgi olarak duruyor — ama saklama ile
       aktarım aynı şey değildir. Metin artık her çıkışı tek tek sayıyor ve ne gitmediğini de
       yazıyor (ad, telefon, tutar hiçbir çağrıda yok — ölçüldü).

    3) SAKLAMA SÜRELERİ SAYIYA BAĞLANDI. "İlgili mevzuattaki zamanaşımı süreleri" cümlesi
       hiçbir soruyu cevaplamıyordu. Süreler artık kanun maddesine bağlı olarak yazılı.
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">1. Veri sorumlusu</h2>
    <p class="gvd">İşbu Aydınlatma Metni, 6698 sayılı Kişisel Verilerin Korunması Kanunu ("<strong>KVKK</strong>") m.10 uyarınca, veri sorumlusu sıfatıyla <x-legal.deger anahtar="title" ad="ticaret unvanı" /> ("<strong>Sipario</strong>") tarafından hazırlanmıştır.</p>
    <ul class="ys-liste">
        <li><b>Adres:</b> <x-legal.deger anahtar="address" ad="açık adres" /></li>
        <li><b>MERSİS No:</b> <x-legal.deger anahtar="mersis" ad="MERSİS numarası" /></li>
        <li><b>Telefon:</b> <x-legal.deger anahtar="phone" ad="telefon numarası" /></li>
        <li><b>E-posta:</b> <x-legal.deger anahtar="email" ad="e-posta adresi" /></li>
        <li><b>KEP adresi:</b> <x-legal.deger ad="KEP adresi" /></li>
        <li><b>VERBİS kaydı:</b> <x-legal.deger ad="VERBİS kayıt durumu — kayıt yükümlülüğü doğduysa sicil numarası, doğmadıysa muafiyet dayanağı" /></li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">2. Sipario iki farklı sıfat taşır — hangisi sizin için geçerli?</h2>
    <p class="gvd">Bu metnin en önemli ayrımı budur. Sipario, kimin verisinden söz ettiğimize göre farklı bir hukuki sıfat taşır:</p>
    <ul class="ys-liste">
        <li><b>Abone işletmeye ve çalışanlarına ait veriler bakımından Sipario VERİ SORUMLUSUDUR.</b> Yani hesabı açan işletme yetkilisinin, operatörün ve kuryenin verilerini kendi belirlediği amaçlarla işler. Bu metin bu verileri anlatır.</li>
        <li><b>İşletmenin kendi müşterilerine ait veriler bakımından Sipario VERİ İŞLEYENDİR.</b> Su alan komşunun adı, adresi, telefonu ve borcu... Bunların veri sorumlusu, o kaydı giren <strong>işletmenin kendisidir</strong>. Sipario bu verileri yalnız işletmenin talimatıyla ve hizmeti çalıştırmak için işler; kendi amaçları için kullanmaz.</li>
    </ul>
    <p class="gvd">İkinci gruptaki ilişki <a href="{{ route('legal.show', 'veri-isleyen') }}">Veri İşleyen Sözleşmesi (Ek-1)</a> ile yazılı olarak kurulmuştur (KVKK m.12/1). <strong>Sipario'yu kullanan işletme, kendi müşterilerini KVKK kapsamında aydınlatmakla yükümlüdür</strong>; bu yükümlülüğü Sipario üstlenmez ve üstlenemez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">3. İşlenen kişisel veriler, amaçları ve hukuki sebepleri</h2>
    <p class="gvd">Aşağıdaki tablo, abone işletme ve kullanıcıları bakımından işlenen verileri gösterir.</p>
    <div class="ys-tablo-sar">
        <table class="ys-tablo">
            <thead>
                <tr><th>Veri kategorisi</th><th>Neler</th><th>İşleme amacı</th><th>Hukuki sebep (KVKK m.5)</th></tr>
            </thead>
            <tbody>
                <tr>
                    <td>Kimlik</td>
                    <td>ad, soyad</td>
                    <td>Hesabın açılması, yetkilinin tanınması, faturanın düzenlenmesi</td>
                    <td>m.5/2-c — sözleşmenin kurulması ve ifası</td>
                </tr>
                <tr>
                    <td>İletişim</td>
                    <td>e-posta, telefon, işletme adresi</td>
                    <td>Hesap bildirimleri, destek, fatura ve abonelik hatırlatmaları</td>
                    <td>m.5/2-c — sözleşmenin ifası</td>
                </tr>
                <tr>
                    <td>Müşteri işlem / finans</td>
                    <td>abonelik dönemi, ödeme tutarı ve tarihi, havale referansı, fatura bilgileri</td>
                    <td>Tahsilat, faturalandırma, muhasebe ve yasal saklama</td>
                    <td>m.5/2-ç — hukuki yükümlülük; m.5/2-c — sözleşmenin ifası</td>
                </tr>
                <tr>
                    <td>İşlem güvenliği</td>
                    <td>giriş kayıtları, IP adresi, oturum ve cihaz kimliği, uygulama sürümü, anlık bildirim jetonu</td>
                    <td>Hesap güvenliği, yetkisiz erişimin tespiti, senkronizasyonun çalışması, arıza giderme</td>
                    <td>m.5/2-f — meşru menfaat; m.5/2-ç — hukuki yükümlülük (5651 sayılı Kanun)</td>
                </tr>
                <tr>
                    <td>Talep / şikâyet</td>
                    <td>destek yazışmaları, iletişim formu içeriği</td>
                    <td>Talebin karşılanması, uyuşmazlığın çözümü, hizmet kalitesinin izlenmesi</td>
                    <td>m.5/2-f — meşru menfaat</td>
                </tr>
                <tr>
                    <td>Pazarlama</td>
                    <td>ticari elektronik ileti izni, ileti gönderim kaydı</td>
                    <td>Yeni özellik ve kampanya duyurusu</td>
                    <td><b>m.5/1 — açık rıza</b> (verilmezse hizmet aynen sunulur)</td>
                </tr>
                <tr>
                    <td>Site kullanımı</td>
                    <td>ziyaret edilen sayfa, oturum süresi, cihaz/tarayıcı türü, yaklaşık konum (şehir düzeyinde)</td>
                    <td>Sitenin hangi bölümünün işe yaradığını ölçmek</td>
                    <td><b>m.5/1 — açık rıza</b> (çerez izni verilmezse hiç toplanmaz)</td>
                </tr>
            </tbody>
        </table>
    </div>
    <p class="gvd"><strong>Özel nitelikli kişisel veri (KVKK m.6) işlenmez.</strong> Sağlık, din, üyelik, biyometri gibi veriler ne istenir ne de kaydedilir. Böyle bir veriyi serbest metin alanına yazmamanızı rica ederiz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. Toplama yöntemi</h2>
    <p class="gvd">Kişisel veriler; sipario.com.tr üzerindeki üyelik ve ödeme formları, mobil uygulama arayüzleri, e-posta ve telefon/WhatsApp destek kanalları ile sistemin otomatik ürettiği güvenlik ve senkronizasyon kayıtları aracılığıyla, tamamen veya kısmen otomatik yollarla, elektronik ortamda toplanır.</p>
    <p class="gvd">Uygulama ve sunucu günlüklerine (log) ve hata/çökme raporlarına <strong>kişisel veri yazılmaz</strong>. Bu, kod düzeyinde uygulanan bir kuraldır: bildirim ve günlük kayıtları yalnız olay adı, kayıt numarası ve sayısal bilgi taşır; müşteri adı, adresi veya tutarı taşımaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">5. Kimlere aktarılıyor?</h2>
    <p class="gvd">Kişisel veriler, aşağıda sayılanlar ve kanunen yetkili kamu kurum ve kuruluşları dışında hiç kimseyle paylaşılmaz. Veriler satılmaz, reklam amacıyla paylaşılmaz ve yapay zekâ modeli eğitiminde kullanılmaz.</p>
    <div class="ys-tablo-sar">
        <table class="ys-tablo">
            <thead>
                <tr><th>Alıcı</th><th>Ne aktarılıyor</th><th>Neden</th><th>Nerede</th></tr>
            </thead>
            <tbody>
                <tr>
                    <td>Barındırma (hosting) sağlayıcısı</td>
                    <td>Sunucuda saklanan tüm veri (şifreli disk üzerinde)</td>
                    <td>Uygulamanın çalışması</td>
                    <td><b>Türkiye</b></td>
                </tr>
                <tr>
                    <td>E-posta gönderim sağlayıcısı</td>
                    <td>Alıcı e-posta adresi ve ileti içeriği</td>
                    <td>Hesap, fatura ve destek e-postaları</td>
                    <td><x-legal.deger ad="SMTP sağlayıcısının adı ve sunucu ülkesi" /></td>
                </tr>
                <tr>
                    <td>Google (Firebase Cloud Messaging)</td>
                    <td>Cihaz bildirim jetonu, olay adı ve kayıt numarası. <b>Ad, adres, tutar gönderilmez.</b></td>
                    <td>Anlık bildirim iletimi</td>
                    <td>Yurt dışı</td>
                </tr>
                <tr>
                    <td>Google / Yandex (adres → koordinat)</td>
                    <td>Yalnız aranan <b>adres metni</b>. Müşteri adı, telefonu veya kimliği gönderilmez.</td>
                    <td>Adresin haritada bulunması</td>
                    <td>Yurt dışı</td>
                </tr>
                <tr>
                    <td>Google (Routes API)</td>
                    <td>Yalnız durak <b>koordinatları</b>. Kime ait olduğu bilgisi gönderilmez.</td>
                    <td>Kurye rotasının sıralanması</td>
                    <td>Yurt dışı</td>
                </tr>
                <tr>
                    <td>Google (Analytics 4)</td>
                    <td>Site kullanım olayları, çerez kimliği, IP (kısaltılmış)</td>
                    <td>Site ölçümü — <b>yalnız açık rıza verilirse</b></td>
                    <td>Yurt dışı</td>
                </tr>
                <tr>
                    <td>iyzico Ödeme Hizmetleri A.Ş.</td>
                    <td>Ad, e-posta, tutar, sipariş numarası. Kart bilgisi yalnız iyzico'da tutulur, Sipario görmez.</td>
                    <td>Kartlı ödemenin alınması (bu yöntem devreye alındığında)</td>
                    <td><b>Türkiye</b></td>
                </tr>
                <tr>
                    <td>Mali müşavir / muhasebe</td>
                    <td>Fatura ve ödeme kayıtları</td>
                    <td>Yasal defter ve beyan yükümlülükleri</td>
                    <td><b>Türkiye</b></td>
                </tr>
            </tbody>
        </table>
    </div>

    <h3 class="h4">Yurt dışına aktarım hakkında açık söz</h3>
    <p class="gvd"><strong>Verileriniz Türkiye'deki sunucuda saklanır.</strong> Bu bir tercihe değil, ürünün kırmızı çizgisine dayanır ve değişmeyecektir. Ancak "saklama" ile "aktarım" farklı şeylerdir: yukarıdaki tabloda görüldüğü gibi bazı işlevler, çalışabilmek için yurt dışındaki servislere sınırlı veri gönderir. Bu çağrılarda gönderilen veri, işlevin çalışması için gereken en az veriyle sınırlı tutulmuştur — adres metni gider, o adresin kime ait olduğu gitmez.</p>
    <p class="gvd">Yurt dışına aktarımlar KVKK m.9 kapsamında değerlendirilir. Bu aktarımların hukuki dayanağının (yeterlilik kararı, standart sözleşme veya taahhütname) tamamlanması <x-legal.deger ad="yurt dışı aktarım hukuki dayanağı — standart sözleşme imzalanacak ve KVK Kurulu'na 5 iş günü içinde bildirilecek" /> ile sağlanacaktır.</p>
    <p class="gvd"><strong>Bu işlevleri kullanmak zorunda değilsiniz.</strong> Adres arama ve rota sıralama isteğe bağlıdır; kullanmadığınızda hiçbir veri yurt dışına çıkmaz. Analitik çerezler için ise çerez izniniz alınmadan hiçbir veri gönderilmez.</p>
</div>

<div class="ys-b">
    <h2 class="h3">6. Saklama süreleri</h2>
    <div class="ys-tablo-sar">
        <table class="ys-tablo">
            <thead><tr><th>Veri</th><th>Süre</th><th>Dayanak</th></tr></thead>
            <tbody>
                <tr><td>Hesap ve iletişim bilgileri</td><td>Hesap açık olduğu sürece; kapanma/silme talebinden sonra 6 ay</td><td>Sözleşme ilişkisi ve olası talepler</td></tr>
                <tr><td>Fatura, ödeme ve muhasebe kayıtları</td><td>5 yıl</td><td>213 sayılı VUK m.253</td></tr>
                <tr><td>Ticari defter niteliğindeki kayıtlar</td><td>10 yıl</td><td>6102 sayılı TTK m.82</td></tr>
                <tr><td>Sözleşme ve onay kayıtları</td><td>10 yıl (sözleşmenin sona ermesinden itibaren)</td><td>6098 sayılı TBK m.146 — genel zamanaşımı</td></tr>
                <tr><td>Trafik ve erişim kayıtları (log)</td><td>2 yıl</td><td>5651 sayılı Kanun ve ikincil mevzuatı</td></tr>
                <tr><td>Destek yazışmaları</td><td>3 yıl</td><td>Meşru menfaat — uyuşmazlık takibi</td></tr>
                <tr><td>Ticari elektronik ileti onayı</td><td>Onayın geri alınmasından itibaren 3 yıl</td><td>Ticari İletişim ve Ticari Elektronik İletiler Hakkında Yönetmelik</td></tr>
                <tr><td>Analitik çerez verisi</td><td>En fazla 14 ay</td><td>Açık rıza — süre dolduğunda otomatik silinir</td></tr>
            </tbody>
        </table>
    </div>
    <p class="gvd">Süresi dolan veriler, Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik uyarınca periyodik imha ile silinir, yok edilir veya anonim hâle getirilir.</p>
    <p class="gvd"><strong>Not:</strong> abonelik süresinin dolması bir imha sebebi değildir. Süre dolduğunda hesap yazmaya kapanır, veri saklanmaya devam eder ve abonelik yenilendiğinde geri gelir. Verinin silinmesi yalnız sizin açık talebinizle olur.</p>
</div>

<div class="ys-b">
    <h2 class="h3">7. Haklarınız (KVKK m.11)</h2>
    <p class="gvd">İlgili kişi olarak Sipario'ya başvurarak şunları talep edebilirsiniz:</p>
    <ul class="ys-liste">
        <li>Kişisel verinizin işlenip işlenmediğini öğrenme,</li>
        <li>İşlenmişse buna ilişkin bilgi talep etme,</li>
        <li>İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,</li>
        <li>Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,</li>
        <li>Eksik veya yanlış işlenmişse düzeltilmesini isteme,</li>
        <li>KVKK m.7'deki şartlar çerçevesinde silinmesini veya yok edilmesini isteme,</li>
        <li>Düzeltme, silme ve yok etme işlemlerinin verinin aktarıldığı üçüncü kişilere bildirilmesini isteme,</li>
        <li>Münhasıran otomatik sistemlerle analiz edilmesi suretiyle aleyhinize bir sonuç doğmasına itiraz etme,</li>
        <li>Kanuna aykırı işleme nedeniyle zarara uğramanız hâlinde zararın giderilmesini talep etme.</li>
    </ul>
    <p class="gvd">Başvuru yolu, zorunlu bilgiler ve süreler <a href="{{ route('legal.show', 'kvkk-basvuru') }}">İlgili Kişi Başvuru Formu</a> belgesinde ayrıntılı olarak açıklanmıştır. Başvurular en geç <strong>30 gün</strong> içinde ücretsiz sonuçlandırılır (KVKK m.13/2).</p>
    <p class="gvd">Başvurunuz reddedilir, verilen cevabı yetersiz bulursanız veya süresinde cevap verilmezse, cevabı öğrendiğiniz tarihten itibaren 30 ve her hâlde başvuru tarihinden itibaren 60 gün içinde <strong>Kişisel Verileri Koruma Kurulu'na</strong> şikâyette bulunabilirsiniz (KVKK m.14).</p>
</div>

<div class="ys-b">
    <h2 class="h3">8. Güvenlik</h2>
    <p class="gvd">Kişisel verilerin hukuka aykırı işlenmesini ve erişilmesini önlemek için alınan teknik ve idari tedbirler <a href="{{ route('legal.show', 'gizlilik-politikasi') }}">Gizlilik Politikası</a> belgesinde ayrıntılı olarak sayılmıştır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">9. Değişiklikler</h2>
    <p class="gvd">Bu metin güncellenebilir. Esaslı değişiklikler yürürlüğe girmeden önce e-posta ile bildirilir. Yürürlükteki sürüm: <strong>{{ config('subscription.legal.kvkk_version') }}</strong>.</p>
</div>
