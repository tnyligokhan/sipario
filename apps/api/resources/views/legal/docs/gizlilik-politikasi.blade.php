{{--
    GİZLİLİK POLİTİKASI — 2026-08-19, YENİ BELGE.

    ── AYDINLATMA METNİNDEN FARKI (ikisi de gerekli, biri diğerinin yerine geçmez) ──────────
    Aydınlatma metni KVKK m.10'un ZORUNLU kıldığı bilgilendirmedir: hangi veri, hangi amaç,
    hangi hukuki sebep, kime aktarılır, haklarınız neler. Biçimi mevzuatça belirlenmiştir.

    Gizlilik politikası ise mevzuatın zorunlu tutmadığı, ama okuyanın asıl merak ettiği soruyu
    cevaplar: "Peki bu veriyi nasıl KORUYORSUNUZ?" Aydınlatma metnine güvenlik tedbirlerini
    yığmak o metni okunamaz uzunluğa çıkarır ve zorunlu kalemlerin arasında kaybeder.

    ── HER İDDİA ÖLÇÜLDÜ ────────────────────────────────────────────────────────────────────
    Aşağıdaki tedbirlerin hiçbiri "olması gereken" listesinden alınmadı; her biri bu depoda
    çalışan bir mekanizmadır ve nerede yaşadığı bellidir:
      • Satır düzeyi güvenlik (RLS FORCE) — migration'larda, kiracı izolasyon testleriyle kanıtlı.
      • CSP + güvenlik başlıkları — app/Http/Middleware/SecurityHeaders.php.
      • Panel denetim günlüğü — her dışa aktarım ve yedek indirme `panel_audit`e düşer.
      • Panelin salt-okunur olması — `sipario_panel` veritabanı kullanıcısının izniyle zorlanır.
      • Günlük yedek — `yedek:baglanti-gonder` komutu.
      • Loglara kişisel veri yazılmaması — PushGondericisi ve günlük çağrılarında uygulanır.
    Ölçülmemiş hiçbir güvenlik iddiası (penetrasyon testi, ISO 27001, şifreleme standardı adı)
    yazılmadı. Sahip olunmayan bir sertifikayı ima etmek, bu belgenin bütününü şüpheli kılar.
--}}

<x-legal.uyari />

<div class="ys-b">
    <h2 class="h3">Kısaca</h2>
    <p class="gvd">Verileriniz Almanya'daki (Frankfurt) sunucularımızda durur ve KVKK kapsamında işlenir. Her işletmenin verisi veritabanı seviyesinde birbirinden ayrılmıştır — bir bayi diğerinin kaydını teknik olarak göremez. Biz de göremeyiz: destek ekibimizin panelinde işletmenizin iş verisini <em>değiştirme</em> yetkisi yoktur, bakılan her kayıt iz bırakır. Veriniz satılmaz, reklam için paylaşılmaz, yapay zekâ eğitiminde kullanılmaz.</p>
    <p class="gvd">Aşağıdaki bölümler bunun nasıl sağlandığını anlatır. Hangi verinin hangi amaçla işlendiğini öğrenmek için <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK Aydınlatma Metni</a>'ne bakın.</p>
</div>

<div class="ys-b">
    <h2 class="h3">1. Verileriniz nerede duruyor?</h2>
    <p class="gvd">Sipario'nun veritabanı ve dosyaları <strong>Almanya'nın Frankfurt şehrindeki bir veri merkezinde</strong>, Hostinger International Ltd. altyapısında barındırılır. Burası Avrupa Birliği veri koruma rejiminin geçerli olduğu bir ülkedir; barındırma KVKK anlamında bir yurt dışı aktarımdır ve <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">Aydınlatma Metni'nin 5. bölümünde</a> böyle gösterilmiştir.</p>
    <p class="gvd">Barındırmanın dışında bazı işlevler de çalışabilmek için yurt dışındaki servislere sınırlı veri gönderir (adres arama, rota sıralama, anlık bildirim, isteğe bağlı site ölçümü). Bunların her biri, ne gönderdiği ve ne göndermediğiyle birlikte aynı bölümde tek tek sayılmıştır. Bu çağrılarda müşterinizin adı, telefonu veya borcu hiçbir zaman yer almaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">2. İşletmeler birbirinin verisini göremez</h2>
    <p class="gvd">Sipario çok kiracılı bir sistemdir: aynı veritabanında yüzlerce işletmenin kaydı durur. Bu kayıtların birbirine karışmaması, uygulama kodundaki bir "unutmayalım" kuralına bırakılmamıştır.</p>
    <p class="gvd">Ayrım <strong>veritabanının kendi katmanında</strong>, satır düzeyi güvenlik (row-level security) ile zorlanır. Bir sorgu yanlışlıkla kiracı filtresini unutsa bile veritabanı başka işletmenin satırını döndürmez — sorgu boş sonuç alır. Bu izolasyon, her sürümde otomatik testlerle yeniden kanıtlanır.</p>
</div>

<div class="ys-b">
    <h2 class="h3">3. Sipario çalışanları ne görebilir?</h2>
    <p class="gvd">Destek ve satış ekibimizin kullandığı yönetim paneli, sizin iş verinizi <strong>değiştiremez</strong>. Bu bir yetki ayarı değil, veritabanı izniyle zorlanan bir sınırdır: panelin bağlandığı veritabanı kullanıcısının iş verisi tablolarında yazma izni yoktur. Panel yalnız hesap/abonelik yönetimi ve salt-okunur istatistik yapar.</p>
    <p class="gvd">Sipariş, müşteri ve para kayıtları yalnız <strong>sizin</strong> uygulamanızdan girilir.</p>
    <p class="gvd">Verinizin dışa aktarılması (export) veya yedek indirilmesi gibi yüksek etkili işlemlerin her biri <strong>denetim günlüğüne</strong> yazılır: kim, ne zaman, hangi işletme için. Yedek indirme yetkisi yalnız en üst düzey yöneticidedir; destek personeli bu işlemi yapamaz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">4. Teknik tedbirler</h2>
    <ul class="ys-liste">
        <li><b>Aktarımda şifreleme:</b> site, hesap paneli ve mobil uygulama ile sunucu arasındaki tüm trafik TLS (HTTPS) ile şifrelenir.</li>
        <li><b>Parolalar geri döndürülemez şekilde saklanır:</b> parolalarınız şifrelenmiş özet (hash) olarak tutulur. Sipario çalışanları dahil hiç kimse parolanızı okuyamaz; unuttuğunuzda "hatırlatılamaz", ancak sıfırlanabilir.</li>
        <li><b>Oturum ve cihaz kontrolü:</b> mobil oturumlar cihaza bağlı belirteçlerle yürür. Yeni bir cihazdan giriş yapıldığında ve parola değiştiğinde e-posta ile bilgilendirilirsiniz.</li>
        <li><b>Tarayıcı güvenlik başlıkları:</b> site ve panel, içerik güvenliği politikası (CSP) ile korunur; sayfaya dışarıdan kod enjekte edilmesi ve sayfanın başka bir sitede çerçevelenmesi engellenir.</li>
        <li><b>Kart verisi hiç bize gelmez:</b> kartlı ödeme devreye alındığında kart bilgileri lisanslı ödeme kuruluşunda tutulur; Sipario kart numarasını görmez ve saklamaz.</li>
        <li><b>Günlük yedek:</b> veritabanının her gün yedeği alınır ve yetkili kişiye iletilir. Yedek dosyalarına erişim kısıtlı ve izlenebilirdir.</li>
        <li><b>Loglarda kişisel veri yok:</b> uygulama günlükleri ve hata kayıtları yalnız olay adı, kayıt numarası ve sayısal bilgi taşır. Müşteri adı, adresi ve tutar log'a yazılmaz — bu kural kod düzeyinde uygulanır.</li>
        <li><b>Silinmeyen para kayıtları:</b> para ve hareket kayıtları üzerine yazılmaz; düzeltme, yeni bir kayıtla yapılır. Bu, hem defterin doğruluğu hem de kötüye kullanımın izlenebilirliği içindir.</li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">5. İdari tedbirler</h2>
    <ul class="ys-liste">
        <li>Kişisel veriye erişim, işini yapmak için gerçekten ihtiyacı olan kişiyle sınırlıdır.</li>
        <li>Yönetim paneline erişim rollere ayrılmıştır; en riskli işlemler (yedek indirme, hesap yönetimi) yalnız en üst yetkidedir.</li>
        <li>Hizmet aldığımız tedarikçilerle veri güvenliği ve gizlilik yükümlülüğü içeren sözleşmeler yapılır.</li>
        <li>Yeni bir tedarikçi eklendiğinde Aydınlatma Metni'ndeki alıcı listesi güncellenir ve size bildirilir.</li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">6. Veri ihlali olursa ne yaparız?</h2>
    <p class="gvd">Kişisel verilerin hukuka aykırı olarak başkaları tarafından elde edildiğini tespit edersek:</p>
    <ul class="ys-liste">
        <li>Durumu <strong>en kısa sürede ve her hâlde 72 saat içinde</strong> Kişisel Verileri Koruma Kurulu'na bildiririz (KVKK m.12/5).</li>
        <li>Etkilenen ilgili kişilere makul en kısa sürede, olayın niteliğini ve alınabilecek önlemleri açıklayarak bildirim yaparız.</li>
        <li>İhlal işletmenizin müşteri verisini etkiliyorsa, <strong>size derhal haber veririz</strong> — çünkü o veri bakımından bildirim yükümlülüğü veri sorumlusu olarak sizdedir ve süreye yetişmeniz gerekir.</li>
    </ul>
</div>

<div class="ys-b">
    <h2 class="h3">7. Veriniz rehin alınmaz</h2>
    <p class="gvd">Abonelik süresi dolduğunda veya iptal edildiğinde verileriniz <strong>silinmez</strong>. Hesap yazmaya kapanır, kayıtlar sunucuda durmaya devam eder ve abonelik yenilendiğinde eksiksiz geri gelir.</p>
    <p class="gvd">Aboneliğiniz sona ermiş olsa dahi destek kanalı üzerinden verinizin dışa aktarımını her zaman talep edebilirsiniz. Bu kapıyı kapatmıyoruz: kendi müşterilerinizin verisinden KVKK önünde siz sorumlusunuz ve o veriye erişemez hâle gelmeniz sizi yükümlülüğünüzü yerine getiremez duruma düşürürdü.</p>
</div>

<div class="ys-b">
    <h2 class="h3">8. Çocukların verileri</h2>
    <p class="gvd">Sipario bir işletme yazılımıdır ve 18 yaşından küçüklere yönelik değildir. Bilerek çocuk verisi toplamayız. Böyle bir verinin sisteme girdiğini fark edersek sileriz.</p>
</div>

<div class="ys-b">
    <h2 class="h3">9. İletişim</h2>
    <p class="gvd">Gizlilik ve veri güvenliğiyle ilgili sorularınız için: <x-legal.deger anahtar="support_email" ad="destek e-posta adresi" />. KVKK haklarınızı kullanmak için <a href="{{ route('legal.show', 'kvkk-basvuru') }}">İlgili Kişi Başvuru Formu</a>'ndaki yolu izleyin.</p>
    <p class="gvd">Yürürlükteki sürüm: <strong>{{ config('subscription.legal.kvkk_version') }}</strong>.</p>
</div>
