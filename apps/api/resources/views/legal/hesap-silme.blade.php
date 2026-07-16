{{--
    Hesap ve veri silme talebi sayfası (Faz 6 — Google Play zorunlu). Play Console, hesap sistemi
    olan uygulamalar için genel erişilebilir bir "hesap/veri silme" URL'i şart koşar (data-safety
    formundaki silme talebi bu sayfaya işaret eder). BRIEF ile tutarlı: uygulamada silme butonu YOK
    (bilinçli), talep destek kanalından yürür; veri rehin alınmaz ama talep üzerine silinir; mevzuat
    saklama yükümlülükleri saklıdır. İletişim/süre bilgileri PLACEHOLDER — gerçek değerler insan işidir.
--}}
<x-layouts.app>
    <div class="card" style="max-width: 720px;">
        <h1>Hesap ve Veri Silme Talebi</h1>
        <p class="err" style="margin:.5rem 0 1rem;">
            ⚠️ TASLAK — iletişim bilgileri ve süreler kesinleşmeden (aşağıdaki [köşeli] alanlar) yayına alınmaz.
        </p>

        <div style="line-height:1.6;">
            <h3>Sipario hesabı nasıl açılır ve yönetilir?</h3>
            <p>
                Sipario, mevcut bir hesapla giriş yapılan bir saha uygulamasıdır. Hesaplar
                <strong>sipario.com.tr</strong> üzerinden veya satış/kurulum sürecinde açılır; mobil
                uygulamanın kendisinde kayıt, satın alma veya silme ekranı bulunmaz. Bu nedenle hesap
                ve veri silme talepleri, aşağıdaki destek kanalı üzerinden alınır.
            </p>

            <h3>Silme talebi nasıl yapılır?</h3>
            <p>
                Hesabınızın ve ona bağlı verilerin silinmesini istiyorsanız, hesabınızın kayıtlı
                e-posta adresinden <strong>[destek e-postası — doldurulacak]</strong> adresine
                (veya <strong>[destek telefonu/kanalı — doldurulacak]</strong>) “hesap silme talebi”
                konulu bir bildirim iletmeniz yeterlidir. Kimliğinizi doğruladıktan sonra talebiniz
                işleme alınır.
            </p>

            <h3>Hangi veriler silinir?</h3>
            <p>
                Onaylanan silme talebinde; bayi (abone) hesabınız (giriş bilgileri, kullanıcı ve cihaz
                kayıtları) ile Sipario üzerinde tuttuğunuz iş verileriniz (müşteriler, siparişler,
                veresiye defteri kayıtları, kuponlar) silinir. Kart bilgileri Sipario tarafından hiçbir
                zaman saklanmaz; ödeme bilgileri ödeme kuruluşu (iyzico) nezdindedir.
            </p>

            <h3>Hangi veriler ne kadar süreyle saklanabilir?</h3>
            <p>
                İlgili mevzuat gereği saklanması zorunlu olan kayıtlar (ör. fatura ve ödeme kayıtları),
                yasal saklama süresi boyunca <strong>[saklama süresi — doldurulacak]</strong> tutulmaya
                devam eder ve bu süre sonunda imha edilir. Bunun dışındaki verileriniz, talebiniz
                onaylandıktan sonra <strong>[azami işlem süresi — doldurulacak]</strong> içinde silinir.
            </p>

            <h3>Müşteri verileriniz hakkında</h3>
            <p>
                Sipario üzerinde tuttuğunuz kendi müşterilerinize ait veriler (ad, telefon, adres, konum)
                bakımından KVKK anlamında <strong>veri sorumlusu sizsiniz</strong>; Sipario, sizin adınıza
                ve talimatınızla işleyen <strong>veri işleyen</strong> konumundadır. Bu verilerin silinmesi
                talebiniz, veri işleyen sıfatıyla Sipario tarafından teknik olarak yerine getirilir.
            </p>

            <h3>Verinizi silmeden önce dışa aktarma</h3>
            <p>
                Silme öncesinde verilerinizi yedeklemek isterseniz, aynı destek kanalı üzerinden dışa
                aktarım (export) talep edebilirsiniz. Aboneliğiniz sona ermiş olsa dahi verileriniz
                otomatik silinmez; yalnızca sizin açık talebinizle silinir.
            </p>

            <p style="margin-top:1.5rem; font-size:.9rem;">
                Kişisel verilerin işlenmesine ilişkin ayrıntılı bilgi için
                <a href="{{ route('legal.show', 'kvkk-aydinlatma') }}">KVKK Aydınlatma Metni</a>’ne bakınız.
            </p>
        </div>
    </div>
</x-layouts.app>
