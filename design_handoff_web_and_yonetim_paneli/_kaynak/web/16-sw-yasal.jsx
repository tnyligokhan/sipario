// sw-yasal.jsx — Yasal metinler (örnek şablon; hukuki inceleme gerektirir). → window

const SW_YASAL = [
  { k: 'mesafeli', ad: 'Mesafeli satış sözleşmesi', b: [
    ['Taraflar', `SATICI: ${SW_KUNYE.unvan}, ${SW_KUNYE.adres}. MERSİS ${SW_KUNYE.mersis}. Telefon ${SW_KUNYE.telefon}, e-posta ${SW_KUNYE.eposta}.\nALICI: Sipario hesabı oluştururken beyan ettiğiniz işletme ve yetkili bilgileri.`],
    ['Sözleşmenin konusu', 'Bu sözleşme, ALICI’nın sipario.com.tr üzerinden elektronik ortamda satın aldığı Sipario yazılım aboneliğine ilişkin tarafların hak ve yükümlülüklerini düzenler. 6502 sayılı Tüketicinin Korunması Hakkında Kanun ve Mesafeli Sözleşmeler Yönetmeliği hükümleri uygulanır.'],
    ['Hizmetin niteliği', 'Sipario, işletmelerin müşteri, sipariş, cari (veresiye) ve teslimat kayıtlarını yönetmesini sağlayan bir yazılım hizmetidir. Fiziksel bir ürün teslimi yoktur; hizmet, ödemenin onaylandığı anda erişime açılır.'],
    ['Bedel ve ödeme', 'Abonelik bedeli seçilen döneme göre peşin tahsil edilir ve KDV dahildir. Ödeme, banka havalesi/EFT ile ya da SATICI temsilcisine elden yapılır; elden ödemede makbuz yerinde düzenlenir. Kredi/banka kartıyla online ödeme henüz açık değildir, hazır olduğunda bu madde güncellenecektir.'],
    ['Süre ve yenileme', 'Abonelik, seçilen dönem sonunda otomatik olarak yenilenir. Yenileme tarihinden en az 1 gün önce hesap panelinden iptal edilebilir. İptal, yürürlükteki dönemin sonunda geçerli olur.'],
    ['Yürürlük', 'ALICI, ödeme adımında bu sözleşmeyi onaylamakla tüm koşulları kabul etmiş sayılır. Sözleşmenin bir örneği ALICI’nın e-posta adresine gönderilir.'],
  ]},
  { k: 'iade', ad: 'İptal ve iade', b: [
    ['Cayma hakkı', 'İlk ödemenizden itibaren 14 gün içinde, hiçbir gerekçe göstermeden cayabilirsiniz. Bu süre içinde yapılan talepte ödenen bedelin tamamı, talebin ulaşmasından itibaren en geç 14 gün içinde aynı ödeme yöntemiyle iade edilir.'],
    ['14 günden sonra', 'Yıllık aboneliklerde, kullanılmayan tam aylar oranında iade yapılır. Aylık aboneliklerde içinde bulunulan dönem için iade yapılmaz; abonelik dönem sonunda sonlanır.'],
    ['Nasıl talep edilir', `Hesap panelinden “Aboneliği iptal et” adımını izleyin ya da ${SW_KUNYE.eposta} adresine yazın. Telefonla arama zorunluluğu yoktur; iptal için sizi ikna etmeye çalışmıyoruz.`],
    ['Ek paketler', 'Tek seferlik satın alınan oto-sıralama hakları, hiç kullanılmamışsa 14 gün içinde iade edilir. Kısmen kullanılmış paketlerde kalan hak oranında iade uygulanır.'],
    ['İptalden sonra veriler', 'Abonelik sona erdiğinde kayıtlarınız silinmez. Hesap salt-okunur kipe geçer; verilerinizi 12 ay boyunca görüntüleyebilir ve Excel olarak dışa aktarabilirsiniz.'],
  ]},
  { k: 'kvkk', ad: 'Gizlilik ve KVKK', b: [
    ['Veri sorumlusu', `${SW_KUNYE.unvan}, 6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında veri sorumlusudur.`],
    ['İşlenen veriler', 'Hesap bilgileri (işletme adı, yetkili adı, e-posta, telefon), fatura bilgileri (ünvan, VKN, adres) ve hizmetin çalışması için gereken kullanım kayıtları işlenir.'],
    ['Müşteri kayıtlarınız', 'Uygulamaya girdiğiniz kendi müşteri verileriniz size aittir. Bu verilerde Sipario veri işleyen sıfatıyla hareket eder; verileri pazarlama amacıyla kullanmaz, üçüncü taraflara satmaz.'],
    ['Arayan tanıma', 'Gelen çağrı numarası, cihaz üzerinde kendi müşteri listenizle eşleştirilir. Çağrı bilgisi Sipario sunucularına gönderilmez ve üçüncü taraflarla paylaşılmaz.'],
    ['Saklama ve konum', 'Veriler Türkiye’de bulunan sunucularda saklanır. Kurumsal planda kendi sunucunuza kurulum yapılabilir; bu durumda veriler işletmenizin altyapısında kalır.'],
    ['Haklarınız', `KVKK m.11 kapsamındaki taleplerinizi ${SW_KUNYE.eposta} adresine iletebilirsiniz. Başvurular en geç 30 gün içinde yanıtlanır.`],
  ]},
  { k: 'cerez', ad: 'Çerez politikası', b: [
    ['Zorunlu çerezler', 'Oturumunuzu açık tutmak ve güvenlik doğrulaması yapmak için kullanılır. Bu çerezler kapatılamaz; site onlarsız çalışmaz.'],
    ['Tercih çerezleri', 'Dil, görünüm ve son kullandığınız bölüm gibi tercihlerinizi hatırlar. Kapatırsanız site çalışır, ancak tercihleriniz her ziyarette sıfırlanır.'],
    ['Ölçüm çerezleri', 'Hangi sayfaların işe yaradığını anlamak için toplu ve anonim istatistik toplarız. Reklam amaçlı izleme yapmıyor, üçüncü taraf reklam çerezi kullanmıyoruz.'],
    ['Yönetim', 'Tarayıcı ayarlarınızdan çerezleri istediğiniz zaman silebilir veya engelleyebilirsiniz.'],
  ]},
];

function YasalSayfa(){
  const [k, setK] = React.useState('mesafeli');
  const y = SW_YASAL.find((x) => x.k === k);
  return (
    <main className="ic">
      <section className="blm">
        <div className="kap">
          <div className="blm-bas">
            <span className="blm-kulak mn"><i />Yasal</span>
            <h1 className="h1">Sözleşmeler ve politikalar</h1>
            <p className="gvd b">Küçük yazıyı okunur puntoyla yazdık. Anlamadığınız bir madde varsa arayın, açıklayalım.</p>
          </div>
          <div className="ys-ic">
            <nav className="hs-nav ys-nav">
              {SW_YASAL.map((x) => (
                <button key={x.k} className={`hs-l ${k === x.k ? 'on' : ''}`} onClick={() => setK(x.k)}>
                  <Ikon ad="belge" boy={18} kalin={2} />{x.ad}
                </button>
              ))}
            </nav>
            <div className="ys-govde">
              <Pano etiket={y.ad} sag={<span className="kucuk">Son güncelleme: 2 Ağustos 2026</span>} genisIc>
                {y.b.map((b, i) => (
                  <div className="ys-b" key={i}>
                    <h2 className="h3">{b[0]}</h2>
                    <p className="gvd">{b[1]}</p>
                  </div>
                ))}
                <Kutu tur="sari" ikon="uyari">Bu metinler tasarım amaçlı örnek şablonlardır. Yayına almadan önce hukuk danışmanınıza inceletin.</Kutu>
              </Pano>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}

Object.assign(window, { YasalSayfa, SW_YASAL });
