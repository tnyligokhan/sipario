/**
 * Google Kişiler dışa aktarımını (contacts.csv) Sipario panel içe aktarım biçimine çevirir.
 *
 * NEDEN AYRI BİR BETİK, PHP TARAFINDA DEĞİL: bu tek seferlik bir TAŞIMA'dır, ürünün bir
 * özelliği değil. Panel içe aktarıcısı Sipario'nun kendi sütunlarını okur; buradaki iş bir
 * başka sistemin bozuk dışa aktarımını o sütunlara çevirmektir ve kuralları o bayiye özgüdür
 * (İPAP, MADRAN, isme yapışmış "16" su fiyatı...). Ürün kodu bu kurallarla kirlenmemeli.
 *
 * Kullanım:  node scripts/musteri-donustur.js <girdi.csv> <cikti-dizini>
 */
const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------- CSV okuma/yazma

function csvAyikla(metin) {
  const satirlar = []; let satir = []; let hucre = ''; let tirnak = false;
  for (let i = 0; i < metin.length; i++) {
    const ch = metin[i];
    if (tirnak) {
      if (ch === '"') { if (metin[i + 1] === '"') { hucre += '"'; i++; } else tirnak = false; }
      else hucre += ch;
    } else if (ch === '"') tirnak = true;
    else if (ch === ',') { satir.push(hucre); hucre = ''; }
    else if (ch === '\r') { /* yok say */ }
    else if (ch === '\n') { satir.push(hucre); satirlar.push(satir); satir = []; hucre = ''; }
    else hucre += ch;
  }
  if (hucre !== '' || satir.length) { satir.push(hucre); satirlar.push(satir); }
  return satirlar;
}

const csvHucre = (d) => /[",\n\r]/.test(d) ? '"' + d.replace(/"/g, '""') + '"' : d;
const csvSatir = (a) => a.map((x) => csvHucre(String(x === null || x === undefined ? '' : x))).join(',');

// ---------------------------------------------------------------- sabitler

const BUYUK = (s) => String(s || '').toLocaleUpperCase('tr-TR');
const HARF = 'A-Za-zÇĞİIÖŞÜçğıöşü';

/** Çok değerli hücrelerin ayracı (telefon, adres, favori). Gerçek veride ASLA geçmez. */
const AYRAC = ' ::: ';

/** Ad alanının başındaki sayıdan SONRA gelirse o sayı müşteri kodu DEĞİL sokak/kapı numarasıdır. */
const SOKAK_EKI = new RegExp('^(sk|sok|sokak|no|nolu|cad|cd|blv|bulv|blok|apt|kat|sit|mh|mah)(?![' + HARF + '])', 'i');

/**
 * ÜRÜNLER (kullanıcı kararı 2026-09-11): 5 tüp + MADRAN. Diğer su markaları (SIRMA, SAFİR,
 * HAYAT, EYLÜL, SAKA) ürün DEĞİLDİR — müşterinin notunda metin olarak kalırlar.
 *
 * SIRA ÖNEMLİDİR: uzun desen kısa desenden önce denenir, yoksa "GENİŞ PİKNİK" içindeki
 * "PİKNİK" ya da "UZUN TÜP" içindeki "UZUN" yanlış ürüne bağlanır.
 */
const URUNLER = [
  { ad: 'Geniş Piknik Tüp', desenler: [/GEN[İI]Ş\s*P[İI]KN[İI]K/, /GEN[İI]Ş\s*P[İI]K\.?(?![A-ZÇĞİÖŞÜ])/, /GNŞ\s*P[İI]K\.?(?![A-ZÇĞİÖŞÜ])/] },
  { ad: 'Dar Piknik Tüp', desenler: [/DAR\s*P[İI]KN[İI]K/, /DAR\s*P[İI]K\.?(?![A-ZÇĞİÖŞÜ])/] },
  // "TÜP" sonrası harf gelmemeli: "UZUN TÜPTE KULLANIYOR" notunda ürün "UZUN"dur, "TÜPTE"
  // serbest metindir ve kelimenin ortasından kesilirse not bozulur (ölçüldü, 2 kayıt).
  { ad: 'Uzun Tüp', desenler: [/S[İI]BOBLU\s*UZUN\s*TÜP(?![A-ZÇĞİÖŞÜa-zçğıöşü])/, /UZUN\s*S[İI]BOBLU/, /UZUN\s*TÜP(?![A-ZÇĞİÖŞÜa-zçğıöşü])/, /\bUZUN\b/] },
  { ad: 'Gri Şişman Tüp', desenler: [/GR[İI]\s*Ş[İI]ŞMAN/] },
  { ad: 'Tombul Tüp', desenler: [/\bTOMBUL\b/, /\bTOMBU\b(?![A-ZÇĞİÖŞÜ])/] },
  { ad: 'Madran Su', desenler: [/\bB\s*MADRAN\b/, /\bMADRAN\b/] },
];

/** Adresin ilk kelimesinden bölge (mahalle). Yazım hataları eşlenir; ADRES METNİ DEĞİŞTİRİLMEZ. */
const MAHALLE = {
  'ÇAĞLAYAN': 'Çağlayan', 'FENER': 'Fener', 'FENERMH': 'Fener', 'FERNER': 'Fener',
  'GÜZELOLUK': 'Güzeloluk', 'GÜZELOBA': 'Güzeloba', 'GÜELOBA': 'Güzeloba',
  'ZÜMRÜTOVA': 'Zümrütova', 'ZÜMTÜTOVA': 'Zümrütova', 'ŞİRİNYALI': 'Şirinyalı',
  'GÜZELBAĞ': 'Güzelbağ', 'KIRCAMİ': 'Kırcami',
};

// ---------------------------------------------------------------- alan çıkarıcılar

/** Ad alanının başındaki müşteri kodu. Sokak numarasıysa null döner. */
function kodAyir(adAlani) {
  const f = String(adAlani || '').trim();
  const m = f.match(/^(\d{1,6})(\s+|$)/);
  if (!m) return { kod: null, kalan: f };
  const kalan = f.slice(m[0].length).trim();
  if (kalan && SOKAK_EKI.test(kalan)) return { kod: null, kalan: f };
  return { kod: m[1], kalan };
}

/**
 * Müşteri adı. Kullanıcı kararı (2026-09-11): "**" işaretleri ve isme yapışmış sayılar
 * (su fiyatı: "BİLAL 16") ATILIR, hiçbir yere taşınmaz. BEY/HANIM korunur.
 *
 * Sayı ayıklaması YALNIZ orta ada ve soyada uygulanır. İlk alanda kalan sayı, kodu olmayan
 * kayıtlarda adresin parçasıdır ("1803 Sk Gökhan Demir") — silinirse adres bozulur.
 */
function adKur(ilkKalan, orta, soyad) {
  const sayisiz = (s) => String(s || '').split(/\s+/).filter((t) => t && !/^\d+$/.test(t)).join(' ');
  return [
    String(ilkKalan || '').replace(/\*+/g, ' '),
    sayisiz(String(orta || '').replace(/\*+/g, ' ')),
    sayisiz(String(soyad || '').replace(/\*+/g, ' ')),
  ].join(' ').replace(/\s+/g, ' ').trim();
}

/** Telefonlar: tüm sütunlar + ":::" ile ayrılmış çoklu değerler, son 10 haneye göre tekilleştirilir. */
function telefonlar(satir) {
  const ham = ['Phone 1 - Value', 'Phone 2 - Value', 'Phone 3 - Value']
    .map((k) => satir[k] || '').join(':::').split(':::');
  const cikti = []; const gorulen = new Set();
  for (const t of ham) {
    const temiz = t.trim(); if (!temiz) continue;
    const rakamlar = temiz.replace(/\D/g, '');
    if (rakamlar.length < 7) continue;
    const anahtar = rakamlar.slice(-10);
    if (gorulen.has(anahtar)) continue;
    gorulen.add(anahtar);
    cikti.push(temiz.replace(/\s+/g, ' '));
  }
  return cikti;
}

/**
 * Adres. YALNIZ "Address 1/2 - Formatted" kullanılır: Google'ın Street/Region/Postal Code
 * parçalaması 3.689 kayıtta kelime SIRASINI bozmuştur ("A.BLK KAT:2 DA:4 DÜDENPARK EVL
 * 2045 SK" ← doğrusu "ÇAĞLAYAN 2045 SK DÜDENPARK EVL. A.BLK KAT:2 DA:4"). Formatted alanı
 * ham girdiyi olduğu gibi taşır; ölçüldü, tek doğru kaynak odur.
 */
function adresler(satir) {
  const cikti = []; const gorulen = new Set();
  for (const alan of ['Address 1 - Formatted', 'Address 2 - Formatted']) {
    for (const parca of String(satir[alan] || '').split(':::')) {
      const a = parca.replace(/\r/g, '').split('\n')
        .map((x) => x.trim()).filter((x) => x && x !== 'TR')
        .join(' ').replace(/\s+/g, ' ').trim();
      if (!a || gorulen.has(a)) continue;
      gorulen.add(a); cikti.push(a);
    }
  }
  return cikti;
}

function bolgeBul(adres) {
  const ilk = BUYUK(String(adres || '').split(/[\s.,]+/)[0] || '');
  return MAHALLE[ilk] || '';
}

/**
 * Notu ürünlere ve kalan nota böler. Ürün adı nottan ÇIKARILIR (favorilere taşındı); geri
 * kalan HER ŞEY — İPAP/KREDİ/KK/GÖREVLİ etiketleri, diğer su markaları, serbest metin,
 * ikinci ve sonraki satırlar — AYNEN korunur. Bu fonksiyondan veri kaybı çıkmaz.
 */
function notVeUrunler(hamNot) {
  const satirlar = String(hamNot || '').replace(/\r/g, '').split('\n');
  let ilk = satirlar[0] || '';
  const favoriler = [];

  for (const urun of URUNLER) {
    for (const desen of urun.desenler) {
      const re = new RegExp(desen.source, 'gi');
      if (!re.test(ilk)) continue;
      ilk = ilk.replace(new RegExp(desen.source, 'gi'), ' ');
      favoriler.push(urun.ad);
      break;
    }
  }

  // Ürünler çıkınca geriye kalan ayraç kalıntılarını topla ("- - KK" → "KK").
  const temizIlk = ilk.split(/\s*[-–—]\s*/)
    .map((p) => p.replace(/\s+/g, ' ').trim()).filter(Boolean).join(' - ');

  const kalan = [temizIlk, ...satirlar.slice(1).map((s) => s.replace(/\s+/g, ' ').trim())]
    .filter(Boolean).join('\n').trim();

  return { not: kalan, favoriler };
}

// ---------------------------------------------------------------- birleştirme

/** Aynı kodu taşıyan iki kaydın AYNI müşteri olup olmadığı. */
function ayniMusteri(a, b) {
  const sade = (s) => BUYUK(s).replace(/[^A-ZÇĞİÖŞÜ0-9]/g, '');
  if (sade(a.ad) && sade(a.ad) === sade(b.ad)) return true;
  const son10 = (t) => t.replace(/\D/g, '').slice(-10);
  const aTel = new Set(a.telefonlar.map(son10));
  if (b.telefonlar.some((t) => aTel.has(son10(t)))) return true;
  const aAdr = new Set(a.adresler.map(sade));
  return b.adresler.some((x) => aAdr.has(sade(x)));
}

function birlestir(hedef, kaynak) {
  const son10 = (t) => t.replace(/\D/g, '').slice(-10);
  const telVar = new Set(hedef.telefonlar.map(son10));
  for (const t of kaynak.telefonlar) if (!telVar.has(son10(t))) { telVar.add(son10(t)); hedef.telefonlar.push(t); }
  const sade = (s) => BUYUK(s).replace(/[^A-ZÇĞİÖŞÜ0-9]/g, '');
  const adrVar = new Set(hedef.adresler.map(sade));
  for (const a of kaynak.adresler) if (!adrVar.has(sade(a))) { adrVar.add(sade(a)); hedef.adresler.push(a); }
  for (const f of kaynak.favoriler) if (!hedef.favoriler.includes(f)) hedef.favoriler.push(f);
  if (kaynak.not && kaynak.not !== hedef.not) hedef.not = [hedef.not, kaynak.not].filter(Boolean).join('\n');
  if (!hedef.ad) hedef.ad = kaynak.ad;
  if (!hedef.bolge) hedef.bolge = kaynak.bolge;
}

// ---------------------------------------------------------------- ana akış

function donustur(kayitlar) {
  const hepsi = kayitlar.map((r) => {
    const { kod, kalan } = kodAyir(r['First Name']);
    const { not, favoriler } = notVeUrunler(r['Notes']);
    const adr = adresler(r);
    const tel = telefonlar(r);

    /**
     * `customers.name` NOT NULL'dur; adı hiç olmayan 2 kayıtta (rehberde yalnız numara var)
     * ad yerine NUMARANIN KENDİSİ yazılır. Uydurma değildir — kaydın taşıdığı tek tanımlayıcı
     * odur; bayi listede numarayı görüp kimin olduğunu bilir. Boş bırakmak satırı düşürürdü.
     */
    const gercekAd = adKur(kalan, r['Middle Name'], r['Last Name']);

    return {
      kod, ad: gercekAd || tel[0] || '', adYok: gercekAd === '',
      telefonlar: tel, adresler: adr, bolge: bolgeBul(adr[0] || ''), not, favoriler,
    };
  });

  // Kod çakışmaları: aynı müşteriyse BİRLEŞTİR, farklı kişiyse kodu ilk kayıtta bırak ve
  // ötekinin kodunu nota yaz (kod tekildir — ikisine birden verilemez, ama kaybolmamalı).
  const kodHarita = new Map();
  const sonuc = []; const catisma = [];
  for (const m of hepsi) {
    if (!m.kod) { sonuc.push(m); continue; }
    const onceki = kodHarita.get(m.kod);
    if (!onceki) { kodHarita.set(m.kod, m); sonuc.push(m); continue; }
    if (ayniMusteri(onceki, m)) {
      birlestir(onceki, m);
      catisma.push({ kod: m.kod, karar: 'birleştirildi', ad: m.ad, digerAd: onceki.ad });
    } else {
      catisma.push({ kod: m.kod, karar: 'kod ilk kayıtta kaldı', ad: m.ad, digerAd: onceki.ad });
      m.not = [m.not, 'Eski müşteri kodu: ' + m.kod].filter(Boolean).join('\n');
      m.kod = null;
      sonuc.push(m);
    }
  }
  // ÇIPLAK KAYIT TEMİZLİĞİ: rehberde adı, adresi, notu ve kodu olmayan — yalnız bir numara
  // taşıyan — kayıtlar var. Numara başka bir kayıtta da geçiyorsa bu, o müşterinin ikinci kez
  // kaydedilmiş çıplak hâlidir; ayrı bir müşteri olarak yazılırsa listede numarası ad diye
  // görünen bir hayalet doğar. ÖLÇÜLDÜ: ayrıştırmadan gidildiğinde içe aktarıcı telefon
  // tekrarından ZENGİN olanı (adresi olanı) atlıyor, çıplak olanı tutuyordu — tam tersi.
  //
  // Numarası başka hiçbir yerde geçmeyen çıplak kayıt KORUNUR: elde ondan başka bir şey yok.
  const telSahibi = new Map();
  for (const m of sonuc) {
    if (m.adYok && !m.adresler.length && !m.not && !m.kod) continue;
    for (const t of m.telefonlar) telSahibi.set(t.replace(/\D/g, '').slice(-10), m);
  }

  const temiz = [];
  for (const m of sonuc) {
    const ciplak = m.adYok && !m.adresler.length && !m.not && !m.kod;
    const sahip = ciplak && m.telefonlar.map((t) => t.replace(/\D/g, '').slice(-10))
      .map((k) => telSahibi.get(k)).find(Boolean);
    if (sahip) {
      birlestir(sahip, m);
      catisma.push({ kod: '', karar: 'çıplak kayıt birleştirildi', ad: m.telefonlar[0] || '', digerAd: sahip.ad });
      continue;
    }
    temiz.push(m);
  }

  return { musteriler: temiz, catisma };
}

function main() {
  const girdi = process.argv[2];
  const ciktiDizin = process.argv[3];
  if (!girdi || !ciktiDizin) {
    console.error('Kullanım: node scripts/musteri-donustur.js <girdi.csv> <cikti-dizini>');
    process.exit(1);
  }

  let metin = fs.readFileSync(girdi, 'utf8');
  if (metin.charCodeAt(0) === 0xFEFF) metin = metin.slice(1);
  const tablo = csvAyikla(metin);
  const baslik = tablo[0];
  const kayitlar = tablo.slice(1)
    .filter((r) => r.some((h) => h && h.trim()))
    .map((r) => { const o = {}; baslik.forEach((h, i) => { o[h] = r[i] || ''; }); return o; });

  const { musteriler, catisma } = donustur(kayitlar);

  fs.mkdirSync(ciktiDizin, { recursive: true });

  // Panel içe aktarım dosyası. Sütun sırası PanelImportService::SUTUNLAR ile birebir aynıdır.
  const satirlar = [csvSatir(['ad', 'telefon', 'adres', 'bolge', 'not', 'kod', 'favoriler'])];
  for (const m of musteriler) {
    satirlar.push(csvSatir([
      m.ad, m.telefonlar.join(AYRAC), m.adresler.join(AYRAC),
      m.bolge, m.not, m.kod || '', m.favoriler.join(AYRAC),
    ]));
  }
  fs.writeFileSync(path.join(ciktiDizin, 'musteriler.csv'), '﻿' + satirlar.join('\r\n') + '\r\n', 'utf8');

  // Ürün listesi (bilgi amaçlı; içe aktarıcı favoriler sütunundan zaten kendisi oluşturur).
  const urunSatir = [csvSatir(['ad', 'birim'])];
  for (const u of URUNLER) urunSatir.push(csvSatir([u.ad, 'adet']));
  fs.writeFileSync(path.join(ciktiDizin, 'urunler.csv'), '﻿' + urunSatir.join('\r\n') + '\r\n', 'utf8');

  // Kod çakışmaları — hangi kayda ne yapıldığı, elle denetlenebilsin diye.
  const catSatir = [csvSatir(['kod', 'karar', 'ad', 'cakistigi_ad'])];
  for (const c of catisma) catSatir.push(csvSatir([c.kod, c.karar, c.ad, c.digerAd]));
  fs.writeFileSync(path.join(ciktiDizin, 'kod-cakismalari.csv'), '﻿' + catSatir.join('\r\n') + '\r\n', 'utf8');

  const say = (f) => musteriler.filter(f).length;
  console.log('Kayıt (girdi)      :', kayitlar.length);
  console.log('Müşteri (çıktı)    :', musteriler.length);
  console.log('  kodu olan        :', say((m) => m.kod));
  console.log('  kodu olmayan     :', say((m) => !m.kod));
  console.log('  adı boş          :', say((m) => !m.ad));
  console.log('  telefonu olmayan :', say((m) => !m.telefonlar.length));
  console.log('  adresi olmayan   :', say((m) => !m.adresler.length));
  console.log('  favorisi olan    :', say((m) => m.favoriler.length));
  console.log('Toplam telefon     :', musteriler.reduce((s, m) => s + m.telefonlar.length, 0));
  console.log('Toplam adres       :', musteriler.reduce((s, m) => s + m.adresler.length, 0));
  console.log('Kod çakışması      :', catisma.length,
    '(birleştirilen ' + catisma.filter((c) => c.karar === 'birleştirildi').length + ')');
}

module.exports = { kodAyir, adKur, telefonlar, adresler, bolgeBul, notVeUrunler, donustur, csvAyikla, csvSatir, URUNLER, AYRAC };

if (require.main === module) main();
