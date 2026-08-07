function App() {
  const [oturum, setOturum] = React.useState(() => localStorage.getItem('yp2_oturum') === '1');
  const [rota, setRota] = React.useState({ ekran: 'panel', id: null });
  const [firmalar, setFirmalar] = React.useState(ILK_FIRMALAR);
  const [odemeler, setOdemeler] = React.useState(ILK_ODEMELER);
  const [masraflar, setMasraflar] = React.useState(ILK_MASRAFLAR);
  const [plan, setPlan] = React.useState(ILK_PLAN);
  const [paketler, setPaketler] = React.useState(ILK_PAKETLER);
  const [tanimlamalar, setTanimlamalar] = React.useState(ILK_TANIMLAMALAR);
  const [tanimModal, setTanimModal] = React.useState(null); // {sabitFirma} | null
  const [odemeModal, setOdemeModal] = React.useState(null); // {sabitFirma} | null
  const [tost, setTost] = React.useState(null);
  const tostGoster = (m) => { setTost(m); clearTimeout(tostGoster.z); tostGoster.z = setTimeout(() => setTost(null), 3200); };

  const girisYap = () => { localStorage.setItem('yp2_oturum', '1'); setOturum(true); };
  const cikis = () => { localStorage.removeItem('yp2_oturum'); setOturum(false); setRota({ ekran: 'panel', id: null }); };
  const uyeAc = (id) => setRota({ ekran: 'uye', id });

  const odemeEkle = (o) => {
    setOdemeler(prev => [{ ...o, id: 'o' + Date.now() }, ...prev]);
    let yeniBitis;
    setFirmalar(prev => prev.map(f => {
      if (f.id !== o.firmaId) return f;
      const taban = f.bitis > isoBugun ? f.bitis : isoBugun;
      yeniBitis = ayEkle(taban, 1);
      return { ...f, durum: 'aktif', bitis: yeniBitis };
    }));
    setOdemeModal(null);
    tostGoster('Ödeme kaydedildi · abonelik bitişi ' + tarihK(yeniBitis) + ' oldu');
  };
  const denemeUzat = (id, tarih) => {
    setFirmalar(prev => prev.map(f => f.id === id ? { ...f, bitis: tarih } : f));
    tostGoster('Deneme ' + tarihK(tarih) + ' tarihine uzatıldı');
  };
  const durumDegistir = (id, durum) => {
    setFirmalar(prev => prev.map(f => f.id === id ? { ...f, durum } : f));
    tostGoster(durum === 'askida' ? 'Üyelik askıya alındı' : 'Üyelik aktifleştirildi');
  };
  const notEkle = (id, metin) => {
    setFirmalar(prev => prev.map(f => f.id === id ? { ...f, notlar: [...f.notlar, { t: isoBugun, m: metin }] } : f));
  };
  const masrafEkle = (m) => {
    setMasraflar(prev => [{ ...m, id: 'm' + Date.now() }, ...prev]);
    tostGoster('Masraf kaydedildi');
  };
  const planKaydet = (p) => { setPlan(p); tostGoster('Plan güncellendi'); };
  const paketKaydet = (p, mevcut) => {
    if (mevcut) { setPaketler(prev => prev.map(x => x.id === mevcut.id ? { ...p, id: mevcut.id } : x)); tostGoster('Paket güncellendi'); }
    else { setPaketler(prev => [...prev, { ...p, id: 'e' + Date.now() }]); tostGoster('Ek paket eklendi'); }
  };
  const paketTanimla = (t) => {
    const paket = paketler.find(p => p.id === t.paketId);
    setTanimlamalar(prev => [{ ...t, id: 't' + Date.now() }, ...prev]);
    if (t.tahsil !== 'Bedelsiz' && t.tutar > 0) {
      setOdemeler(prev => [{ id: 'o' + Date.now(), firmaId: t.firmaId, tarih: t.tarih, tutar: t.tutar, yontem: t.tahsil, donem: 'Ek paket · ' + paket.ad, not: t.not }, ...prev]);
    }
    setTanimModal(null);
    const f = firmalar.find(x => x.id === t.firmaId);
    tostGoster(paket.ad + ' → ' + (f ? f.ad : 'firma') + ' tanımlandı');
  };

  if (!oturum) return <Giris onGiris={girisYap} />;

  const NAV = [['panel','Dashboard','panel'],['uyeler','Üyeler','uyeler'],['odemeler','Ödemeler','odemeler'],['paketler','Paketler','kutu'],['gelirgider','Gelir-Gider','gelirgider']];
  const seciliNav = rota.ekran === 'uye' ? 'uyeler' : rota.ekran;
  const firma = rota.ekran === 'uye' ? firmalar.find(f => f.id === rota.id) : null;

  return (
    <div className="yp">
      <aside className="yk">
        <div className="yk-logo">
          <div className="yk-mark"><Ikon ad="damla" boy={16} /></div>
          <div><div className="yk-ad">Sipario</div><div className="yk-tag">Yönetim</div></div>
        </div>
        <nav className="yk-nav">
          {NAV.map(([k, ad, ikon]) => (
            <button key={k} className={'yk-item' + (seciliNav === k ? ' secili' : '')} onClick={() => setRota({ ekran: k, id: null })}><Ikon ad={ikon} boy={17} /> {ad}</button>))}
        </nav>
        <div className="yk-alt"><button className="yk-item yk-cikis" onClick={cikis}><Ikon ad="cikis" boy={17} /> Çıkış</button></div>
      </aside>
      <main className="yg">
        {rota.ekran === 'panel' && <Dashboard firmalar={firmalar} odemeler={odemeler} masraflar={masraflar} plan={plan} uyeAc={uyeAc} />}
        {rota.ekran === 'uyeler' && <Uyeler firmalar={firmalar} odemeler={odemeler} uyeAc={uyeAc} />}
        {rota.ekran === 'uye' && firma && <UyeDetay firma={firma} odemeler={odemeler} plan={plan} paketler={paketler} tanimlamalar={tanimlamalar}
          geri={() => setRota({ ekran: 'uyeler', id: null })} odemeEkleAc={(f) => setOdemeModal({ sabitFirma: f })} tanimlaAc={(f) => setTanimModal({ sabitFirma: f })}
          denemeUzat={denemeUzat} durumDegistir={durumDegistir} notEkle={notEkle} />}
        {rota.ekran === 'odemeler' && <Odemeler firmalar={firmalar} odemeler={odemeler} odemeEkleAc={() => setOdemeModal({ sabitFirma: null })} uyeAc={uyeAc} />}
        {rota.ekran === 'paketler' && <Paketler plan={plan} paketler={paketler} tanimlamalar={tanimlamalar} firmalar={firmalar}
          planKaydet={planKaydet} paketKaydet={paketKaydet} tanimlaAc={(f) => setTanimModal({ sabitFirma: f })} uyeAc={uyeAc} />}
        {rota.ekran === 'gelirgider' && <GelirGider odemeler={odemeler} masraflar={masraflar} masrafEkle={masrafEkle} />}
      </main>
      {odemeModal && <OdemeEkleModal firmalar={firmalar} sabitFirma={odemeModal.sabitFirma} plan={plan} onKaydet={odemeEkle} onKapat={() => setOdemeModal(null)} />}
      {tanimModal && <TanimlaModal paketler={paketler} firmalar={firmalar} sabitFirma={tanimModal.sabitFirma} plan={plan} onKaydet={paketTanimla} onKapat={() => setTanimModal(null)} />}
      {tost && <div className="tost">{tost}</div>}
    </div>
  );
}
ReactDOM.createRoot(document.getElementById('root')).render(<App />);
