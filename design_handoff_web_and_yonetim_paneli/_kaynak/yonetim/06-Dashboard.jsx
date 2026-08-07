function Dashboard({ firmalar, odemeler, masraflar, plan, uyeAc }) {
  const aktif = firmalar.filter(f => f.durum === 'aktif');
  const deneme = firmalar.filter(f => f.durum === 'deneme');
  const buAy = isoBugun.slice(0,7);
  const ayOdeme = odemeler.filter(o => ayAnahtar(o.tarih) === buAy);
  const tahsilat = ayOdeme.reduce((t,o) => t + o.tutar, 0);
  const gider = masraflar.filter(m => ayAnahtar(m.tarih) === buAy).reduce((t,m) => t + m.tutar, 0);
  const net = tahsilat - gider;
  const bitenler = deneme.map(f => ({ f, kalan: gunFarki(f.bitis) })).filter(x => x.kalan <= 7 && x.kalan >= 0).sort((a,b) => a.kalan - b.kalan);
  const gecikenler = firmalar.filter(f => (f.durum === 'aktif' || f.durum === 'askida') && gunFarki(f.bitis) < 0)
    .map(f => ({ f, gun: -gunFarki(f.bitis) })).sort((a,b) => b.gun - a.gun);
  return (
    <div className="yg-ic">
      <div className="ust"><div><h1>Dashboard</h1><div className="ust-alt">4 Ağustos 2026 Salı</div></div></div>
      <div className="skartlar">
        <div className="skart"><div className="skart-l">Aktif Abone</div><div className="skart-v tab">{aktif.length}</div><div className="skart-alt">{para(plan.ucret)}/ay plan</div></div>
        <div className="skart"><div className="skart-l">Deneme Sürümünde</div><div className="skart-v tab">{deneme.length}</div><div className="skart-alt">{bitenler.length} tanesi bu hafta bitiyor</div></div>
        <div className="skart"><div className="skart-l">Bu Ay Tahsilat</div><div className="skart-v tab">{para(tahsilat)}</div><div className="skart-alt">{ayOdeme.length} ödeme</div></div>
        <div className="skart"><div className="skart-l">Bu Ay Net</div><div className={'skart-v tab ' + (net < 0 ? 'eksi' : 'arti')}>{paraNet(net)}</div><div className="skart-alt">Gelir {para(tahsilat)} · Gider {para(gider)}</div></div>
      </div>
      <div className="iki-kolon">
        <div className="kart">
          <div className="kart-baslik"><Ikon ad="saat" boy={15} /> Denemesi bitmek üzere<span className="adet">7 gün içinde</span></div>
          {bitenler.length === 0 ? <Bos ikon="saat" metin="Bu hafta denemesi biten firma yok." /> : (
            <table className="tablo"><tbody>
              {bitenler.map(({ f, kalan }) => (
                <tr key={f.id}>
                  <td><div className="kalin">{f.ad}</div><div className="soluk" style={{ fontSize: 12.5 }}>{f.tel}</div></td>
                  <td className="sag"><span className="rozet deneme">{kalan === 0 ? 'Bugün bitiyor' : kalan + ' gün kaldı'}</span></td>
                  <td className="sag" style={{ width: 60 }}><button className="link-btn" onClick={() => uyeAc(f.id)}>Detay</button></td>
                </tr>))}
            </tbody></table>
          )}
        </div>
        <div className="kart">
          <div className="kart-baslik"><Ikon ad="uyari" boy={15} /> Ödemesi geciken<span className="adet">{gecikenler.length} firma</span></div>
          {gecikenler.length === 0 ? <Bos ikon="kutu" metin="Geciken ödeme yok. Her şey yolunda." /> : (
            <table className="tablo"><tbody>
              {gecikenler.map(({ f, gun }) => (
                <tr key={f.id}>
                  <td><div className="kalin">{f.ad}</div><div className="soluk" style={{ fontSize: 12.5 }}>{gun} gün gecikti</div></td>
                  <td className="sag kalin tab">{para(plan.ucret)}</td>
                  <td className="sag" style={{ width: 60 }}><button className="link-btn" onClick={() => uyeAc(f.id)}>Detay</button></td>
                </tr>))}
            </tbody></table>
          )}
        </div>
      </div>
    </div>
  );
}
window.Dashboard = Dashboard;
