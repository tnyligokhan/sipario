function MasrafEkleModal({ onKaydet, onKapat }) {
  const [tarih, setTarih] = React.useState(isoBugun);
  const [kategori, setKategori] = React.useState(MASRAF_KATEGORI[0]);
  const [tutar, setTutar] = React.useState('');
  const [not, setNot] = React.useState('');
  return (
    <Modal baslik="Masraf Ekle" onKapat={onKapat}
      alt={<><button className="btn" onClick={onKapat}>Vazgeç</button>
        <button className="btn birincil" disabled={!(+tutar > 0)} onClick={() => onKaydet({ tarih, kategori, tutar: +tutar, not: not.trim() })}>Kaydet</button></>}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <Alan label="Tarih"><input className="girdi tab" type="date" value={tarih} onChange={(e) => setTarih(e.target.value)} /></Alan>
        <Alan label="Tutar (₺)"><input className="girdi tab" type="number" min="0" value={tutar} onChange={(e) => setTutar(e.target.value)} autoFocus /></Alan>
      </div>
      <Alan label="Kategori"><select className="girdi" value={kategori} onChange={(e) => setKategori(e.target.value)}>{MASRAF_KATEGORI.map(k => <option key={k}>{k}</option>)}</select></Alan>
      <Alan label="Not (isteğe bağlı)"><input className="girdi" value={not} onChange={(e) => setNot(e.target.value)} placeholder="örn. Hetzner aylık" /></Alan>
    </Modal>
  );
}

function GelirGider({ odemeler, masraflar, masrafEkle }) {
  const [modal, setModal] = React.useState(false);
  const aylar = [...new Set([...odemeler.map(o => ayAnahtar(o.tarih)), ...masraflar.map(m => ayAnahtar(m.tarih))])].sort().reverse();
  const [seciliAy, setSeciliAy] = React.useState(aylar[0] || isoBugun.slice(0,7));
  const ozet = aylar.map(a => ({
    ay: a,
    gelir: odemeler.filter(o => ayAnahtar(o.tarih) === a).reduce((t,o) => t + o.tutar, 0),
    gider: masraflar.filter(m => ayAnahtar(m.tarih) === a).reduce((t,m) => t + m.tutar, 0)
  }));
  const kalemler = masraflar.filter(m => ayAnahtar(m.tarih) === seciliAy).sort((a,b) => b.tarih.localeCompare(a.tarih));
  return (
    <div className="yg-ic">
      <div className="ust">
        <div><h1>Gelir-Gider</h1><div className="ust-alt">Gelir ödemelerden otomatik hesaplanır</div></div>
        <div className="ust-sag"><button className="btn birincil" onClick={() => setModal(true)}><Ikon ad="arti" boy={15} /> Masraf Ekle</button></div>
      </div>
      <div className="gg-yerlesim">
        <div className="kart">
          <div className="kart-baslik">Aylık Özet</div>
          {ozet.length === 0 ? <Bos metin="Henüz kayıt yok. Ödemeler ve masraflar girildikçe aylık özet burada oluşur." /> : (
            <table className="tablo">
              <thead><tr><th>Ay</th><th className="sag">Gelir</th><th className="sag">Gider</th><th className="sag">Net</th></tr></thead>
              <tbody>{ozet.map(s => (
                <tr key={s.ay} className={'satir-tik ay-satir' + (s.ay === seciliAy ? ' secili' : '')} onClick={() => setSeciliAy(s.ay)}>
                  <td className="kalin">{ayAdi(s.ay)}</td>
                  <td className="sag tab">{para(s.gelir)}</td>
                  <td className="sag tab">{para(s.gider)}</td>
                  <td className="sag kalin tab" style={{ color: s.gelir - s.gider < 0 ? 'var(--danger)' : 'var(--ok)' }}>{paraNet(s.gelir - s.gider)}</td>
                </tr>))}
              </tbody>
            </table>
          )}
        </div>
        <div className="kart">
          <div className="kart-baslik">{ayAdi(seciliAy)} masrafları<span className="adet">{para(kalemler.reduce((t,m) => t + m.tutar, 0))}</span></div>
          {kalemler.length === 0 ? <Bos metin="Bu ay masraf kaydı yok." /> : (
            <table className="tablo"><tbody>
              {kalemler.map(m => (
                <tr key={m.id}>
                  <td><div className="kalin">{m.kategori}</div>{m.not && <div className="soluk" style={{ fontSize: 12.5 }}>{m.not}</div>}</td>
                  <td className="soluk tab" style={{ whiteSpace: 'nowrap' }}>{tarihK(m.tarih)}</td>
                  <td className="sag kalin tab">{para(m.tutar)}</td>
                </tr>))}
            </tbody></table>
          )}
        </div>
      </div>
      {modal && <MasrafEkleModal onKapat={() => setModal(false)} onKaydet={(m) => { masrafEkle(m); setModal(false); }} />}
    </div>
  );
}
Object.assign(window, { MasrafEkleModal, GelirGider });
