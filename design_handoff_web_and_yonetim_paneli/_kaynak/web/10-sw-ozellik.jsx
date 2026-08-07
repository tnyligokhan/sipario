// sw-ozellik.jsx — Özellikler / nasıl çalışır. → window

const SW_EK = [
  { ik: 'elpara', t: 'Muaf müşteriler', a: 'Ücret almadığınız kişiler listede işaretlenir; siparişleri sıfır tutarla deftere düşer, ciroyu bozmaz.' },
  { ik: 'barkod', t: 'Barkodla ürün ekleme', a: 'Kamerayla okutun, ürün sepete düşsün. Barkodu olmayan kalem için serbest satır açın.' },
  { ik: 'pin', t: 'Çoklu adres ve konum', a: 'Bir müşterinin evi, dükkânı, deposu ayrı adres olarak durur. Konum kaydedilirse rota sırasına girer.' },
  { ik: 'fis', t: 'Serbest kalem', a: 'Katalogda olmayan iş için açıklama yazıp tutar girin — merdiven çıkışı, montaj, iade farkı.' },
  { ik: 'takvim', t: 'Gün arşivi', a: 'Kapanan her gün ciro, kasa farkı ve sipariş sayısıyla saklanır. Geriye dönüp bakabilirsiniz.' },
  { ik: 'kurye', t: 'Kurye görünümü', a: 'Kurye hesabı sadece kendi teslimatlarını görür. Fiyat listesi, defter ve ayarlar ona kapalıdır.' },
  { ik: 'cevrimdisi', t: 'Çevrimdışı kip', a: 'Sinyal yoksa kayıt cihazda tutulur, bağlantı gelince sıraya girer. Hiçbir sipariş kaybolmaz.' },
  { ik: 'ay', t: 'Koyu tema', a: 'Akşam saatlerinde ekran yormasın diye. Sistem ayarını takip eder ya da elle sabitlenir.' },
];

const SW_GUN = [
  { s: '08:10', t: 'Gün açılır', a: 'Dünden devreden kasa girilir. Açık siparişler ekranın üstünde.' },
  { s: '09:24', t: 'Telefon çalar', a: 'Ahmet Yılmaz. Kart açılır: adres hazır, 8.550 ₺ borcu var, geçen sefer 2 damacana almış.' },
  { s: '09:25', t: 'Sipariş girilir', a: 'Karttan “Sipariş oluştur”. Ürün seçilir, kuryeye atanır. Üç dokunuş.' },
  { s: '11:40', t: 'Kurye teslim eder', a: 'Kurye kendi telefonundan teslim işaretler, nakit tahsilatı girer. Bakiye anında düşer.' },
  { s: '19:05', t: 'Gün kapanır', a: 'Nakit sayılır, fark kontrol edilir, gün arşive düşer. Yarın sıfırdan başlar.' },
];

function OzellikHero(){
  const { git } = useYon();
  return (
    <section className="blm ic-hero">
      <div className="kap ic-hero-ic">
        <div>
          <span className="blm-kulak mn"><i />Özellikler</span>
          <h1 className="h1 ic-h1">Tezgâhın arkasındaki<br />bütün defterler, tek ekranda.</h1>
          <p className="gvd b ic-lead">Sipario bir “sipariş uygulaması” değil. Telefonu açtığınız andan akşam kasayı kapattığınız ana kadar geçen işin tamamı.</p>
          <div className="dg-grup" style={{ marginTop: 30 }}>
            <button className="dg dg-a" onClick={() => git('kayit')}>14 gün ücretsiz dene<Ikon ad="ok" boy={18} kalin={2.2} /></button>
            <button className="dg dg-c" onClick={() => git('fiyat')}>Fiyatlara bak</button>
          </div>
        </div>
        <div className="ic-hero-sag"><Telefon ekran="ana" oran={0.56} /></div>
      </div>
    </section>
  );
}

function OzellikSplit(){
  const ekran = { cagri: 'ana', veresiye: 'musteri', siparis: 'siparis', kurye: 'kurye', gunsonu: 'gunsonu' };
  return (
    <React.Fragment>
      {SW_TUR.map((t, i) => (
        <section className={`blm ${i % 2 ? 'kagit2' : ''}`} key={t.k}>
          <div className={`kap oz-split ${i % 2 ? 'ters' : ''}`}>
            <div className="oz-metin">
              <span className="blm-kulak mn"><i />{t.ad}</span>
              <h2 className="h1 oz-bas">{t.bas}</h2>
              <p className="gvd b">{t.a}</p>
              <ul className="tur-liste">
                {t.ozet.map((o, j) => (
                  <li key={j}><span className="tur-tik"><Ikon ad="onay" boy={13} kalin={3} renk="#fff" /></span>{o}</li>
                ))}
              </ul>
            </div>
            <div className="oz-tel"><Telefon ekran={ekran[t.k]} oran={0.62} cagri={t.k === 'cagri'} /></div>
          </div>
        </section>
      ))}
    </React.Fragment>
  );
}

function GunBlm(){
  return (
    <section className="blm gece">
      <div className="kap">
        <BlmBas kulak="Bir gün" baslik="Sıradan bir salı, Sipario ile." />
        <ol className="gun">
          {SW_GUN.map((g, i) => (
            <li className="gun-s" key={i}>
              <span className="gun-saat mn">{g.s}</span>
              <span className="gun-nokta"><i /></span>
              <div className="gun-ic">
                <h3 className="h3">{g.t}</h3>
                <p className="gvd">{g.a}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

function EkBlm(){
  return (
    <section className="blm">
      <div className="kap">
        <BlmBas kulak="Ayrıca" baslik="Küçük ama her gün lazım olanlar." />
        <div className="ek-grid">
          {SW_EK.map((e, i) => (
            <div className="ek" key={i}>
              <span className="ek-ik"><Ikon ad={e.ik} boy={20} kalin={1.9} renk="var(--mor)" /></span>
              <h3 className="h4">{e.t}</h3>
              <p className="kucuk">{e.a}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function OzellikSayfa(){
  return (
    <main className="ic">
      <OzellikHero /><OzellikSplit /><GunBlm /><EkBlm /><AdimBlm /><SonCagri />
    </main>
  );
}

Object.assign(window, { OzellikSayfa, SW_EK, SW_GUN });
