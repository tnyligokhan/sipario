// sw-fiyat.jsx — Fiyatlandırma ve paketler. → window

function DonemAnahtar({ donem, onDegis }){
  return (
    <div className="donem">
      <button className={`donem-b ${donem === 'yil' ? 'on' : ''}`} onClick={() => onDegis('yil')}>
        Yıllık<span className="donem-rzt">2 ay hediye</span>
      </button>
      <button className={`donem-b ${donem === 'ay' ? 'on' : ''}`} onClick={() => onDegis('ay')}>Aylık</button>
    </div>
  );
}

function PlanKart({ p, donem, onSec }){
  const yil = donem === 'yil';
  return (
    <Pano sinif={`plan ${p.vurgu ? 'plan-vurgu' : ''}`} ince={!p.vurgu} genisIc
      etiket={p.vurgu ? 'Standart plan' : 'Çok şubeli'}
      sag={p.vurgu ? <Rozet tur="mor" nokta>{p.rozet}</Rozet> : null}>
      <div className="plan-bas">
        <span className="h2">{p.ad}</span>
        <p className="gvd">{p.ozet}</p>
      </div>
      <div className="plan-fiyat">
        {p.ozelFiyat
          ? <span className="rakam kucuk-rakam">{p.ozelFiyat}</span>
          : <React.Fragment>
              <span className="rakam">{tl(yil ? p.yil : p.ay)}</span>
              <span className="fo-donem">/ ay<br /><small>{yil ? 'yıllık ödemede' : 'aylık ödemede'}</small></span>
            </React.Fragment>}
      </div>
      <p className="kucuk plan-not">
        {p.ozelFiyat
          ? 'Şube ve kullanıcı sayısına göre belirlenir. Kendi sunucunuzda kurulum ve yerinde eğitim dahildir.'
          : yil ? `Yılda bir kez ${tl(p.yilToplam)} tahsil edilir · havale veya elden · KDV dahil`
                : `Her ay ${tl(p.ay)} tahsil edilir · istediğiniz zaman iptal · KDV dahil`}
      </p>
      <ul className="plan-liste">
        {p.kapsam.map((x, i) => (
          <li key={i}>
            <Ikon ad="onay" boy={16} kalin={2.6} renk="var(--yesil)" />
            <span><b>{x.t}</b>{x.a && <small>{x.a}</small>}</span>
          </li>
        ))}
      </ul>
      <button className={`dg ${p.vurgu ? 'dg-a' : 'dg-c'} tam`} onClick={() => onSec(p)}>{p.cta}</button>
      <span className="kucuk fo-alt">{p.ctaAlt}</span>
    </Pano>
  );
}

function HakBlm(){
  const { git } = useYon();
  return (
    <section className="blm kagit2">
      <div className="kap">
        <BlmBas kulak="Ek paket" baslik="Oto-sıralama hakkı bitince."
          aciklama="Planınızda ayda 50 hak var. Yoğun aylarda tükenirse tek seferlik paket alın — süresi dolmaz, devreder." />
        <div className="hak-grid">
          {SW_HAKPAKET.map((h) => (
            <div className={`hak ${h.iyi ? 'iyi' : ''}`} key={h.k}>
              {h.iyi && <span className="hak-rzt mn">En avantajlı</span>}
              <span className="rakam">{h.adet}</span>
              <span className="hak-l mn">hak</span>
              <span className="hak-f">{tl(h.fiyat)}</span>
              <span className="kucuk">hak başına {(h.fiyat / h.adet).toFixed(2).replace('.', ',')} ₺</span>
              <button className="dg dg-c tam gk" onClick={() => git('odeme')}>Satın al</button>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function KarsilastirBlm(){
  const H = ({ v }) => v === true ? <Ikon ad="onay" boy={18} kalin={2.6} renk="var(--yesil)" />
    : v === false ? <span className="yok">—</span> : <span>{v}</span>;
  return (
    <section className="blm">
      <div className="kap">
        <BlmBas kulak="Karşılaştırma" baslik="İki plan yan yana." />
        <Pano ince ic={false} sinif="krs">
          <table className="tbl krs-tbl">
            <thead>
              <tr><th /><th>Sipario</th><th>Kurumsal</th></tr>
            </thead>
            <tbody>
              {SW_KARSILASTIR.map((g) => (
                <React.Fragment key={g.g}>
                  <tr className="krs-g"><td colSpan="3"><span className="mn">{g.g}</span></td></tr>
                  {g.s.map((s, i) => (
                    <tr key={i}>
                      <td className="krs-ad">{s[0]}</td>
                      <td className="krs-v"><H v={s[1]} /></td>
                      <td className="krs-v"><H v={s[2]} /></td>
                    </tr>
                  ))}
                </React.Fragment>
              ))}
            </tbody>
          </table>
        </Pano>
      </div>
    </section>
  );
}

function OdemeGuvenBlm(){
  const k = [
    { ik: 'para', t: 'Havale / EFT', a: 'Banka havalesiyle ödeyin; dekont ulaştığı gün hesabınız açılır. IBAN ve referans kodu ödeme adımında çıkar.' },
    { ik: 'elpara', t: 'Elden ödeme', a: 'Bölgenizdeyse uğrayıp elden alıyoruz. Makbuzu yerinde veriyoruz, hesap aynı gün açılıyor.' },
    { ik: 'kart', t: 'Kartla ödeme yakında', a: 'Kredi ve banka kartıyla online ödeme üzerinde çalışıyoruz. Açıldığında panelinizden duyuracağız.' },
    { ik: 'geri', t: '14 gün koşulsuz iade', a: 'İlk iki hafta içinde vazgeçerseniz tutarın tamamı iade edilir. Sebep sormuyoruz.' },
  ];
  return (
    <section className="blm gece">
      <div className="kap">
        <BlmBas kulak="Ödeme" baslik="Para konusunda sürpriz olmaz." />
        <div className="guvence-grid">
          {k.map((x, i) => (
            <div className="guvence" key={i}>
              <span className="guvence-ik"><Ikon ad={x.ik} boy={22} kalin={1.9} renk="#B3A6FF" /></span>
              <h3 className="h3">{x.t}</h3>
              <p className="gvd">{x.a}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function FiyatSayfa(){
  const { git, setSepet } = useYon();
  const [donem, setDonem] = React.useState('yil');
  const sec = (p) => {
    if(p.ozelFiyat){ git('iletisim'); window.scrollTo(0, 0); return; }
    setSepet({ tur: 'plan', plan: p.k, donem, tutar: donem === 'yil' ? p.yilToplam : p.ay });
    git('odeme'); window.scrollTo(0, 0);
  };
  return (
    <main className="ic">
      <section className="blm fiyat-hero">
        <div className="kap">
          <div className="blm-bas fiyat-bas">
            <span className="blm-kulak mn"><i />Fiyatlandırma</span>
            <h1 className="h1">Tek plan, açık fiyat.<br />Büyüdükçe cezalandırmıyoruz.</h1>
            <p className="gvd b">Müşteri, sipariş ya da veri sınırı yok. Ne kadar çalışırsanız çalışın fiyat aynı kalır — sadece kaç kişinin kullandığı değişir.</p>
          </div>
          <DonemAnahtar donem={donem} onDegis={setDonem} />
          <div className="plan-grid">
            {SW_PLAN.map((p) => <PlanKart key={p.k} p={p} donem={donem} onSec={sec} />)}
          </div>
          <div className="fiyat-ek">
            <Kutu tur="mor" ikon="bilgi">
              <b>Ek kurye hesabı 99 ₺/ay.</b> Sipario planı 3 kurye hesabı içerir; dördüncüden itibaren kullanıcı başına aylık 99 ₺ eklenir. Panelden istediğiniz zaman ekleyip çıkarabilirsiniz.
            </Kutu>
          </div>
        </div>
      </section>
      <HakBlm /><KarsilastirBlm /><OdemeGuvenBlm />
      <section className="blm">
        <div className="kap sss-kap">
          <BlmBas kulak="Ödeme soruları" baslik="Faturayı kim keser, iptal nasıl olur?" />
          <SssListe liste={SW_SSS[1].l} acikVar />
        </div>
      </section>
      <SonCagri />
    </main>
  );
}

Object.assign(window, { FiyatSayfa, DonemAnahtar, PlanKart });
