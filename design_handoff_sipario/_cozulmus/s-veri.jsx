// s-veri.jsx — Sipario mock verisi (sektör-bağımsız). → window
// Para: kuruş bazında tamsayı sakla, fmtTL ile göster.

const ODEME_TIPLERI = {
  nakit:   { label: 'Nakit',   kod: 'NKT' },
  kart:    { label: 'Kart',    kod: 'KRT' },
  havale:  { label: 'Havale',  kod: 'HVL' },
  veresiye:{ label: 'Veresiye',kod: 'VRS' },
};

const SIP_DURUM = {
  acik:   { key: 'acik',   label: 'Açık',   renk: 'var(--brand)',  tint: 'var(--brand-soft)' },
  teslim: { key: 'teslim', label: 'Teslim', renk: 'var(--ok)',     tint: 'var(--ok-soft)' },
  iptal:  { key: 'iptal',  label: 'İptal',  renk: 'var(--muted)',  tint: 'var(--line)' },
};

// Çok sektörlü katalog — hiçbir sektöre kilitlenmez
const URUNLER = [
  { id: 'u1', ad: 'Damacana 19 L',        fiyat: 4500,  birim: 'adet',   aktif: true,  gorsel: null, barkod: '8690521000117' },
  { id: 'u2', ad: 'Paket Su 0.5L (12li)', fiyat: 9000,  birim: 'koli',   aktif: true, gorsel: null, barkod: '8690521000124' },
  { id: 'u3', ad: 'Tüp 12 kg',            fiyat: 78000, birim: 'adet',   aktif: true, gorsel: null },
  { id: 'u4', ad: 'Kasa Domates',         fiyat: 16000, birim: 'kasa',   aktif: true, gorsel: null, barkod: '8690521000148' },
  { id: 'u5', ad: 'Karışık Kuruyemiş',    fiyat: 32000, birim: 'kg',     aktif: true, gorsel: null },
  { id: 'u6', ad: 'Temizlik Seti',        fiyat: 24000, birim: 'paket',  aktif: true, gorsel: null, barkod: '8690521000162' },
  { id: 'u7', ad: 'Ekmek',                fiyat: 1500,  birim: 'adet',   aktif: false, gorsel: null },
];

// Müşteriler — bakiye (+borç / −alacak / 0 temiz), kupon (eksiye düşebilir), defter hareketleri
const MUSTERILER = [
  {
    id: 'm1', ad: 'Ahmet Yılmaz', not: 'Zil çalışmıyor, gelince arayın.',
    telefonlar: [{ no: '0532 415 22 90', etiket: 'Cep', birincil: true }, { no: '0242 344 11 05', etiket: 'İş', birincil: false }],
    adresler: [{ metin: 'Cumhuriyet Mah. 5. Sk. No:12/4', etiket: 'Ev', bolge: 'Kepez', konum: { lat: 36.9125, lng: 30.6689 } }],
    bakiye: 34000,
    hareketler: [
      { tip: 'borc',     odeme: 'veresiye', tutar: 9000,  saat: '2s önce', not: 'Damacana ×2' },
      { tip: 'tahsilat', odeme: 'nakit',    tutar: 5000,  saat: 'Dün 17:20', not: '' },
      { tip: 'borc',     odeme: 'veresiye', tutar: 30000, saat: '3 gün önce', not: 'Tüp 12 kg' },
    ],
  },
  {
    id: 'm2', ad: 'Selin Kaya', not: '',
    telefonlar: [{ no: '0533 220 78 41', etiket: 'Cep', birincil: true }],
    adresler: [{ metin: 'Bahçelievler Mah. 118. Sk. No:3', etiket: 'Ev', bolge: 'Muratpaşa', konum: { lat: 36.8841, lng: 30.7056 } }],
    bakiye: 0,
    hareketler: [
      { tip: 'borc',     odeme: 'veresiye', tutar: 16000, saat: 'Dün 11:00', not: 'Kasa domates' },
      { tip: 'tahsilat', odeme: 'kart',     tutar: 16000, saat: 'Dün 11:05', not: 'Teslimde' },
    ],
  },
  {
    id: 'm3', ad: 'Murat Öz', not: 'Kapıda kart geçmiyor.',
    telefonlar: [{ no: '0542 907 63 22', etiket: 'Cep', birincil: true }],
    adresler: [{ metin: 'Fener Mah. Deniz Cad. No:44/2', etiket: 'İş', bolge: 'Lara' }],
    bakiye: -12000,
    hareketler: [
      { tip: 'alacak',   odeme: 'havale', tutar: 12000, saat: 'Bugün 09:10', not: 'Fazla ödeme' },
      { tip: 'borc',     odeme: 'veresiye', tutar: 4500, saat: 'Bugün 09:00', not: 'Damacana' },
    ],
  },
  {
    id: 'm4', ad: 'Hatice Demir', not: '',
    telefonlar: [{ no: '0505 118 40 77', etiket: 'Cep', birincil: true }],
    adresler: [{ metin: 'Şirinyalı Mah. 42. Sk. No:9', etiket: 'Ev', bolge: 'Muratpaşa' }],
    bakiye: 8550,
    hareketler: [{ tip: 'borc', odeme: 'veresiye', tutar: 8550, saat: 'Bugün 08:30', not: 'Paket su ×1 + kuruyemiş' }],
  },
  {
    id: 'm5', ad: 'İbrahim Şahin', not: 'Sabah 9 öncesi aramayın.',
    telefonlar: [{ no: '0555 632 09 18', etiket: 'Cep', birincil: true }],
    adresler: [{ metin: 'Güzeloba Mah. 2312. Sk. No:1', etiket: 'Ev', bolge: 'Lara', konum: { lat: 36.8632, lng: 30.7809 } }],
    bakiye: 0,
    hareketler: [{ tip: 'tahsilat', odeme: 'nakit', tutar: 22500, saat: '2 gün önce', not: '' }],
  },
];

// Siparişler — satirlar (katalog) + serbest (tek seferlik iş) + kurye
const SIPARISLER = [
  { id: 's1', musteriId: 'm1', musteriAd: 'Ahmet Yılmaz', durum: 'acik', saat: '10:24', kurye: 'Kurye 1', odeme: null,
    satirlar: [{ ad: 'Damacana 19 L', adet: 2, birim: 'adet', fiyat: 4500 }], serbest: [], not: 'Zil çalışmıyor' },
  { id: 's2', musteriId: 'm4', musteriAd: 'Hatice Demir', durum: 'acik', saat: '10:02', kurye: 'Ben', odeme: null,
    satirlar: [{ ad: 'Paket Su 0.5L (12li)', adet: 1, birim: 'koli', fiyat: 9000 }],
    serbest: [{ aciklama: 'Merdiven çıkışı', tutar: 2000 }], not: '' },
  { id: 's3', musteriId: 'm2', musteriAd: 'Selin Kaya', durum: 'teslim', saat: '09:15', kurye: 'Ben', odeme: 'kart',
    satirlar: [{ ad: 'Kasa Domates', adet: 1, birim: 'kasa', fiyat: 16000 }], serbest: [], not: '' },
  { id: 's4', musteriId: null, musteriAd: 'Tezgâh Satışı', durum: 'teslim', saat: '08:40', kurye: 'Ben', odeme: 'nakit',
    satirlar: [{ ad: 'Karışık Kuruyemiş', adet: 1, birim: 'kg', fiyat: 32000 }], serbest: [], not: '' },
  { id: 's5', musteriId: 'm3', musteriAd: 'Murat Öz', durum: 'teslim', saat: '09:05', kurye: 'Kurye 1', odeme: 'nakit',
    satirlar: [{ ad: 'Damacana 19 L', adet: 1, birim: 'adet', fiyat: 4500 }], serbest: [], not: '' },
  { id: 's6', musteriId: 'm5', musteriAd: 'İbrahim Şahin', durum: 'iptal', saat: 'Dün', kurye: 'Ben', odeme: null,
    satirlar: [{ ad: 'Tüp 12 kg', adet: 1, birim: 'adet', fiyat: 78000 }], serbest: [], not: 'Müşteri vazgeçti' },
];

const ISLETME = { ad: 'Merkez Bayi', sahip: 'Mehmet Usta', telefon: '0242 344 11 00', sunucu: 'sipario.local', kod: 'merkezbayi', whatsapp: '0532 344 11 00', adres: 'Yeşilbahçe Mah. Portakal Çiçeği Blv. No:21/A, Muratpaşa / Antalya', vergiDairesi: '', vergiNo: '', acilis: '08:00', kapanis: '19:00', fisNotu: '' };

const KURYELER = ['Ben', 'Kurye 1', 'Kurye 2'];

function siparisTutar(o) {
  const a = (o.satirlar || []).reduce((s, r) => s + r.adet * r.fiyat, 0);
  const b = (o.serbest || []).reduce((s, r) => s + (r.tutar || 0), 0);
  return a + b;
}
function siparisOzet(o) {
  const parts = (o.satirlar || []).map((r) => `${r.ad} ×${r.adet}`);
  (o.serbest || []).forEach((r) => parts.push(r.aciklama));
  return parts.join(' · ') || '—';
}
function musteriGetir(id) { return MUSTERILER.find((m) => m.id === id) || null; }
function birincilTel(m) { const t = (m.telefonlar || []).find((x) => x.birincil) || (m.telefonlar || [])[0]; return t ? t.no : ''; }
function birincilAdres(m) { const a = (m.adresler || [])[0]; return a ? a : null; }
function borcluSayisi(list) { return list.filter((m) => m.bakiye > 0).length; }

// Son aramalar — Bugün ekranı çağrı günlüğü
const ARAMALAR = [
  { id: 'a1', musteriId: 'm1', ad: 'Ahmet Yılmaz', no: '0532 415 22 90', saat: '10:24', tip: 'gelen', sonuc: 'Sipariş alındı' },
  { id: 'a2', musteriId: 'm4', ad: 'Hatice Demir', no: '0505 118 40 77', saat: '10:02', tip: 'gelen', sonuc: 'Sipariş alındı' },
  { id: 'a3', musteriId: null, ad: null, no: '0216 555 01 88', saat: '09:47', tip: 'cevapsiz', sonuc: 'Kayıtsız numara' },
  { id: 'a4', musteriId: 'm3', ad: 'Murat Öz', no: '0542 907 63 22', saat: '09:05', tip: 'gelen', sonuc: 'Teslim edildi' },
  { id: 'a5', musteriId: 'm2', ad: 'Selin Kaya', no: '0533 220 78 41', saat: 'Dün', tip: 'giden', sonuc: '' },
];

Object.assign(window, {
  ODEME_TIPLERI, SIP_DURUM, URUNLER, MUSTERILER, SIPARISLER, ISLETME, KURYELER, ARAMALAR,
  siparisTutar, siparisOzet, musteriGetir, birincilTel, birincilAdres, borcluSayisi,
});
