// sw-veri.jsx — Sipario Web içerik verisi. Tümü örnek/temsili. → window

const tl = (n) => Number(n).toLocaleString('tr-TR') + ' ₺';
const tlk = (n) => Number(n).toLocaleString('tr-TR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' ₺';

// ── Paketler ────────────────────────────────────────────────
const SW_PLAN = [
  {
    k: 'sipario', ad: 'Sipario', vurgu: true, rozet: 'İşletmelerin %90’ı bunu seçiyor',
    ozet: 'Tek plan, tek fiyat. Tezgâhın arkasındaki her şey içinde.',
    ay: 599, yil: 499, yilToplam: 5988, hediye: '2 ay hediye',
    cta: '14 gün ücretsiz dene', ctaAlt: 'Kart istemiyoruz',
    kapsam: [
      { t: 'Sınırsız müşteri ve sipariş', a: 'Kayıt sayısına göre ücret almıyoruz' },
      { t: 'Arayan tanıma', a: 'Telefon çaldığı anda kart ekrana gelir' },
      { t: 'Veresiye defteri', a: 'Bakiye, tahsilat, hareket geçmişi' },
      { t: 'Gün sonu kasa', a: 'Nakit · kart · veresiye ayrımıyla devir' },
      { t: '3 kurye hesabı', a: 'Ek kurye 99 ₺/ay' },
      { t: 'Ayda 50 oto-sıralama hakkı', a: 'Rota sırasını uygulama kurar' },
      { t: 'Ürün kataloğu ve barkod', a: 'Fotoğraflı, birimli, çok fiyatlı' },
      { t: 'Telefon + WhatsApp destek', a: 'Hafta içi 09:00–19:00, gerçek insan' },
    ],
  },
  {
    k: 'kurumsal', ad: 'Kurumsal', vurgu: false, rozet: null,
    ozet: 'Çok şubeli bayiler, kendi sunucusunda çalışmak isteyen işletmeler.',
    ozelFiyat: '1.499 ₺’den başlar', cta: 'Teklif alın', ctaAlt: 'Aynı gün dönüş',
    kapsam: [
      { t: 'Sipario’daki her şey', a: null },
      { t: 'Sınırsız şube ve kullanıcı', a: 'Şubeler arası konsolide rapor' },
      { t: 'Rol ve yetki yönetimi', a: 'Kim neyi görür, kim neyi siler' },
      { t: 'Kendi sunucunuzda kurulum', a: 'Veri işletmenizin içinde kalır' },
      { t: 'e-Fatura / muhasebe aktarımı', a: 'Logo, Mikro, Paraşüt' },
      { t: 'Öncelikli destek + SLA', a: '4 saat içinde yanıt taahhüdü' },
      { t: 'Yerinde kurulum ve eğitim', a: 'Ekibinizi biz eğitiyoruz' },
    ],
  },
];

// Plan karşılaştırma tablosu
const SW_KARSILASTIR = [
  { g: 'Kullanım', s: [
    ['Müşteri ve sipariş', 'Sınırsız', 'Sınırsız'],
    ['Kurye hesabı', '3 (ek 99 ₺/ay)', 'Sınırsız'],
    ['Şube', '1', 'Sınırsız'],
    ['Oto-sıralama hakkı', '50 / ay', '500 / ay'],
  ]},
  { g: 'Özellikler', s: [
    ['Arayan tanıma', true, true],
    ['Veresiye defteri', true, true],
    ['Gün sonu kasa devri', true, true],
    ['Çevrimdışı çalışma', true, true],
    ['Rol ve yetki yönetimi', false, true],
    ['e-Fatura / muhasebe aktarımı', false, true],
    ['Kendi sunucunuzda kurulum', false, true],
  ]},
  { g: 'Destek', s: [
    ['Telefon + WhatsApp', 'Hafta içi 09–19', '7/24'],
    ['Yanıt süresi', 'Aynı gün', '4 saat (SLA)'],
    ['Kurulum', 'Uzaktan, ücretsiz', 'Yerinde'],
  ]},
];

// Ek oto-sıralama paketleri
const SW_HAKPAKET = [
  { k: 'h100', adet: 100, fiyat: 149 },
  { k: 'h250', adet: 250, fiyat: 299, iyi: true },
  { k: 'h500', adet: 500, fiyat: 499 },
];

// ── Sektörler ───────────────────────────────────────────────
const SW_SEKTOR = ['Su bayii', 'Tüp bayii', 'Manav', 'Kuruyemişçi', 'Market', 'Fırın', 'Kırtasiye', 'Yem bayii', 'Halı yıkama'];

// ── Sayısal kanıt ───────────────────────────────────────────
const SW_KANIT = [
  { v: '1.240', b: 'işletme', a: 'Sipario’yu her gün tezgâhın arkasında kullanıyor' },
  { v: '6 dk', b: 'sipariş başına', a: 'Telefonu açmakla siparişi kaydetmek arasındaki süre kısaldı' },
  { v: '%31', b: 'daha az kayıp', a: 'Tahsil edilemeyen veresiye, ilk altı ayda ortalama bu kadar düştü' },
];

// ── Kâğıt defterin maliyeti ─────────────────────────────────
const SW_DERT = [
  { ik: 'defter', t: 'Defterde kalan alacak', a: 'Kim ne kadar borçlu — sadece defteri tutanın kafasında. Biri izne çıkınca tahsilat durur.', c: 'Her müşterinin bakiyesi, hareketi ve son ödemesi tek ekranda.' },
  { ik: 'cagri', t: 'Her aramada aynı üç soru', a: '“Adınız? Adresiniz? Ne göndermiştik?” Müşteri her seferinde baştan anlatır.', c: 'Telefon çaldığı anda ad, adres, geçmiş sipariş ve bakiye ekranda.' },
  { ik: 'para', t: 'Akşam tutmayan kasa', a: 'Nakit, kart, veresiye birbirine karışır. Fark nereden çıktı, kimse bilmez.', c: 'Gün sonunda üç kalem ayrı ayrı sayılır, fark anında görünür.' },
];

// ── Ürün turu ekranları ─────────────────────────────────────
const SW_TUR = [
  { k: 'cagri', ad: 'Arayan tanıma', ik: 'cagri', bas: 'Telefon çalıyor. Kim aradığını zaten biliyorsunuz.',
    a: 'Numara rehberde varsa kart ekrana gelir: ad, kayıtlı adresler, açık borç, en son ne aldığı. Yoksa tek dokunuşla yeni müşteri açılır — numara hazır gelir.',
    ozet: ['Kayıtlı numara anında eşleşir', 'Borç ve son sipariş kartın üstünde', 'Kayıtsız numara için tek dokunuşla kayıt'] },
  { k: 'veresiye', ad: 'Veresiye defteri', ik: 'defter', bas: 'Defter değil, bakiye. Herkes aynı rakamı görüyor.',
    a: 'Her müşterinin altında borç/alacak hareketi işler. Tahsilat girildiği anda bakiye düşer, kurye de ekranında görür.',
    ozet: ['Borç · alacak · temiz durumu renkle ayrılır', 'Tahsilat girildiği an bakiye güncellenir', 'Hareket geçmişi ödeme tipiyle saklanır'] },
  { k: 'siparis', ad: 'Sipariş akışı', ik: 'fis', bas: 'Sipariş üç dokunuşta kaydolur.',
    a: 'Müşteri seç, ürünleri ekle, teslimatı ata. Serbest kalem gerekiyorsa açıklama yazıp tutar girin — katalog dışı iş de deftere düşer.',
    ozet: ['Katalogdan ya da barkodla ürün ekleme', 'Serbest kalem ve ek ücret satırı', 'Açık · teslim · iptal durumları'] },
  { k: 'kurye', ad: 'Kurye ve rota', ik: 'kurye', bas: 'Kim nereye gidiyor, sıra ne — ekranda.',
    a: 'Siparişler kuryeye atanır. Konumu olan adresler için uygulama sırayı kendi kurar; sıralamayı elle de sürükleyebilirsiniz.',
    ozet: ['Kuryeye atama ve teslim onayı', 'Oto-sıralama ya da elle sürükleme', 'Konumsuz adres uyarısı'] },
  { k: 'gunsonu', ad: 'Gün sonu', ik: 'para', bas: 'Akşam kasayı üç kalemde kapatın.',
    a: 'Nakit, kart ve veresiye ayrı ayrı toplanır. Sayılan nakdi girin, fark anında çıksın. Kapanan gün arşive düşer.',
    ozet: ['Nakit · kart · veresiye ayrımı', 'Sayım farkı anında hesaplanır', 'Kapanan günler arşivde saklanır'] },
];

// ── Kurulum adımları ────────────────────────────────────────
const SW_ADIM = [
  { n: '01', t: 'Hesabınızı açın', s: '2 dakika', a: 'İşletme adı ve telefon numarası yeter. Firma kodunuz bu ekranda üretilir — ekibiniz uygulamaya bu kodla girer.' },
  { n: '02', t: 'Müşterilerinizi aktarın', s: 'Aynı gün', a: 'Rehberinizi ya da Excel listenizi gönderin, biz yükleyelim. Defterdeki açık bakiyeleri de birlikte aktarıyoruz.' },
  { n: '03', t: 'Telefonu bağlayın', s: '5 dakika', a: 'Uygulamaya çağrı iznini verin. İlk çağrıda müşteri kartının ekrana geldiğini görün — kurulum bitti.' },
];

// ── Güvenceler ──────────────────────────────────────────────
const SW_GUVENCE = [
  { ik: 'cevrimdisi', t: 'İnternet gitse de çalışır', a: 'Sipariş ve tahsilat cihazda tutulur, bağlantı gelince kendi senkronlanır.' },
  { ik: 'kalkan', t: 'Veriler Türkiye’de', a: 'İstanbul’daki sunucularda, KVKK kapsamında. Kurumsal planda kendi sunucunuzda.' },
  { ik: 'indir', t: 'Veriniz sizin', a: 'Müşteri, sipariş ve defter kaydınızı istediğiniz an Excel olarak indirin.' },
  { ik: 'kulaklik', t: 'Telefonu insan açıyor', a: 'Bot yok. Hafta içi 09:00–19:00 arası aynı ekip, aynı numara.' },
];

// ── Yorumlar (sonuç odaklı) ─────────────────────────────────
const SW_YORUM = [
  { s: 'Defteri bıraktık. Ay sonunda tahsil edemediğimiz para 12 binden 3 bine düştü.', k: 'Hasan Yıldırım', r: 'Yıldırım Su · Antalya', m: '9 ay Sipario kullanıyor' },
  { s: 'Telefonu açınca adamın adını söylüyoruz, adresi zaten ekranda. Müşteri “beni tanıdınız” diyor.', k: 'Necla Aksoy', r: 'Aksoy Tüp · Konya', m: '1 yıl 2 ay Sipario kullanıyor' },
  { s: 'İki kuryeyle çalışıyoruz. Sıralamayı uygulama kuruyor, günde bir tur azaldı.', k: 'Serkan Demir', r: 'Demir Market · İzmir', m: '5 ay Sipario kullanıyor' },
];

// ── SSS ─────────────────────────────────────────────────────
const SW_SSS = [
  { g: 'Başlangıç', l: [
    { s: 'Deneme için kart bilgisi istiyor musunuz?', c: 'Hayır. 14 gün boyunca hiçbir ödeme bilgisi girmeden tüm özellikleri kullanırsınız. Süre dolduğunda uygulama salt-okunur kipe geçer, kaydınız silinmez.' },
    { s: 'Eski defterimdeki müşterileri nasıl aktarırım?', c: 'Excel listesi ya da telefon rehberi olarak gönderin, biz yükleyelim — ücretsiz. Açık veresiye bakiyelerini de başlangıç bakiyesi olarak taşıyoruz.' },
    { s: 'Kaç kişi kullanabilir?', c: 'Sipario planında işletme sahibi + 3 kurye hesabı vardır. Ek kurye hesabı 99 ₺/ay. Kurumsal planda kullanıcı sınırı yoktur.' },
  ]},
  { g: 'Ödeme', l: [
    { s: 'Hangi ödeme yöntemlerini kabul ediyorsunuz?', c: 'Şu an havale/EFT ve elden ödeme alıyoruz. Kredi kartıyla online ödeme yakında açılacak; hazır olduğunda hesap panelinizden duyuracağız.' },
    { s: 'Fatura kesiyor musunuz?', c: 'Evet. Her ödemede e-arşiv fatura düzenlenir ve hesap panelinizdeki Faturalar sayfasından PDF olarak indirilir.' },
    { s: 'İstediğim zaman iptal edebilir miyim?', c: 'Evet, panelden tek tıkla. Dönem sonuna kadar erişiminiz devam eder, otomatik yenileme durur. Telefon etmenize gerek yok.' },
    { s: 'Yıllık ödedim, iade alabilir miyim?', c: 'İlk 14 gün içinde koşulsuz iade. Sonrasında kullanılmayan aylar oranında iade yapılır.' },
  ]},
  { g: 'Teknik', l: [
    { s: 'İnternet kesilirse ne olur?', c: 'Uygulama çevrimdışı çalışmaya devam eder. Sipariş, tahsilat ve düzenlemeler cihazda tutulur; bağlantı gelince otomatik senkronlanır.' },
    { s: 'Arayan tanıma nasıl çalışıyor?', c: 'Uygulama çağrı bilgisi iznini kullanarak gelen numarayı kendi müşteri listenizle eşleştirir. Numaralar cihazın dışına çıkmaz, üçüncü tarafla paylaşılmaz.' },
    { s: 'iPhone’da çalışıyor mu?', c: 'Android’de tam sürüm. iOS’ta arayan tanıma dışındaki tüm özellikler çalışır; iOS çağrı entegrasyonu üzerinde çalışıyoruz.' },
    { s: 'Verilerim nerede duruyor?', c: 'İstanbul’daki sunucularda, KVKK kapsamında. Kurumsal planda kendi sunucunuza kurulum yapılabilir.' },
  ]},
];

// ── Hesap paneli örnek durumu ───────────────────────────────
const SW_HESAP = {
  isletme: 'Merkez Su Bayii', firmaKodu: 'merkezbayi', yetkili: 'Mehmet Usta',
  eposta: 'mehmet@merkezsubayi.com', telefon: '05xx xxx xx 00',
  plan: 'Sipario', donem: 'yil', durum: 'aktif',
  baslangic: '30 Mart 2026', bitis: '30 Mart 2027', kalanGun: 240, toplamGun: 365,
  sonrakiTutar: 5988, sonrakiTarih: '30 Mart 2027',
  hak: { kullanilan: 16, toplam: 50, yenileme: '1 Eylül 2026' },
  kurye: { kullanilan: 2, toplam: 3 },
  kart: null, odemeYol: 'Havale / EFT',
  fatura: { unvan: 'Merkez Su Bayii Ltd. Şti.', vkn: '1234567890', daire: 'Muratpaşa V.D.',
    adres: 'Şirinyalı Mah. 42. Sk. No:9/A', ilce: 'Muratpaşa', il: 'Antalya' },
};

// Hiç abone olmamış, denemenin 3. gününde yeni işletme
const SW_HESAP_DENEME = {
  isletme: 'Yıldız Su Bayii', firmaKodu: 'yildizsu', yetkili: 'Ahmet Yıldız',
  eposta: 'ahmet@yildizsu.com', telefon: '05xx xxx xx 00',
  plan: 'Deneme', donem: 'yok', durum: 'deneme',
  baslangic: '1 Ağustos 2026', bitis: '15 Ağustos 2026', kalanGun: 11, toplamGun: 14,
  sonrakiTutar: 0, sonrakiTarih: '—',
  hak: { kullanilan: 3, toplam: 50, yenileme: '1 Eylül 2026' },
  kurye: { kullanilan: 1, toplam: 3 },
  kart: null,
  kurulum: [
    { ad: 'İşletme hesabı açıldı', alt: '1 Ağustos', bitti: true },
    { ad: 'Uygulamayı telefonunuza kurdunuz', alt: 'Android · 2 Ağustos', bitti: true },
    { ad: 'İlk müşterinizi ekleyin', alt: 'Şu an 4 müşteri kayıtlı', bitti: true },
    { ad: 'Ürün ve fiyatlarınızı girin', alt: 'Damacana, pet su, tüp…', bitti: false, gitBolum: null },
    { ad: 'Kurye hesabı oluşturun', alt: 'Kurye telefonundan siparişleri görür', bitti: false },
    { ad: 'İlk siparişi kaydedin', alt: 'Telefon çaldığında müşteri ekranda', bitti: false },
  ],
  fatura: { unvan: 'Yıldız Su Bayii', vkn: '', daire: '', adres: '', ilce: '', il: '' },
};

const SW_FATURA = [
  { no: 'SIP-2026-0412', t: '30 Mart 2026', a: 'Sipario · Yıllık (30 Mar 2026 – 30 Mar 2027)', tutar: 5988, d: 'odendi', y: 'Havale' },
  { no: 'SIP-2026-0311', t: '12 Şubat 2026', a: 'Oto-sıralama · 250 hak', tutar: 299, d: 'odendi', y: 'Havale' },
  { no: 'SIP-2025-0288', t: '30 Mart 2025', a: 'Sipario · Yıllık (30 Mar 2025 – 30 Mar 2026)', tutar: 4788, d: 'odendi', y: 'Havale' },
  { no: 'SIP-2025-0154', t: '18 Ocak 2025', a: 'Ek kurye hesabı · 1 kullanıcı · 12 ay', tutar: 1188, d: 'odendi', y: 'Havale' },
  { no: 'SIP-2024-0091', t: '30 Mart 2024', a: 'Sipario · Yıllık (30 Mar 2024 – 30 Mar 2025)', tutar: 3588, d: 'odendi', y: 'Havale' },
];

// ── İletişim / künye ────────────────────────────────────────
const SW_KUNYE = {
  unvan: 'Sipario Yazılım A.Ş.',
  adres: 'Kızılırmak Mah. Dumlupınar Blv. No:3 A/54, Çankaya / Ankara',
  mersis: '0123456789000001', vkn: 'Çankaya V.D. 0123456789',
  telefon: '0850 000 00 00', eposta: 'destek@sipario.com.tr',
  saat: 'Hafta içi 09:00 – 19:00', paraBirimi: 'Türk Lirası (₺)',
};

Object.assign(window, { tl, tlk, SW_PLAN, SW_KARSILASTIR, SW_HAKPAKET, SW_SEKTOR, SW_KANIT, SW_DERT,
  SW_TUR, SW_ADIM, SW_GUVENCE, SW_YORUM, SW_SSS, SW_HESAP, SW_HESAP_DENEME, SW_FATURA, SW_KUNYE });
