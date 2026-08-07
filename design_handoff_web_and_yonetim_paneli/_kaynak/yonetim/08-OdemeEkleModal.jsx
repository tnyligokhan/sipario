function OdemeEkleModal({ firmalar, sabitFirma, plan, onKaydet, onKapat }) {
  const [firma, setFirma] = React.useState(sabitFirma || null);
  const [tutar, setTutar] = React.useState(plan.ucret);
  const [tarih, setTarih] = React.useState(isoBugun);
  const [yontem, setYontem] = React.useState('IBAN');
  const [donem, setDonem] = React.useState('Ağustos 2026');
  const [not, setNot] = React.useState('');
  const donemler = AYLAR.map(a => a + ' 2026');
  return (
    <Modal baslik="Ödeme Ekle" onKapat={onKapat}
      alt={<><button className="btn" onClick={onKapat}>Vazgeç</button>
        <button className="btn birincil" disabled={!firma || !(tutar > 0)} onClick={() => onKaydet({ firmaId: firma.id, tutar: +tutar, tarih, yontem, donem, not: not.trim() })}>Kaydet</button></>}>
      <Alan label="Firma">{sabitFirma ? <input className="girdi" value={sabitFirma.ad} disabled /> : <FirmaCombo firmalar={firmalar} secili={firma} onSec={setFirma} />}</Alan>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <Alan label="Tutar (₺)"><input className="girdi tab" type="number" min="0" value={tutar} onChange={(e) => setTutar(e.target.value)} /></Alan>
        <Alan label="Tarih"><input className="girdi tab" type="date" value={tarih} onChange={(e) => setTarih(e.target.value)} /></Alan>
      </div>
      <Alan label="Yöntem"><Radyolar secenekler={['IBAN', 'Elden']} deger={yontem} onSec={setYontem} /></Alan>
      <Alan label="Kapsadığı dönem"><select className="girdi" value={donem} onChange={(e) => setDonem(e.target.value)}>{donemler.map(d => <option key={d}>{d}</option>)}</select></Alan>
      <Alan label="Not (isteğe bağlı)"><input className="girdi" value={not} onChange={(e) => setNot(e.target.value)} placeholder="örn. Ofiste elden alındı" /></Alan>
      <div className="modal-bilgi"><Ikon ad="bilgi" boy={15} /><span>Kaydedildiğinde firmanın abonelik bitişi 1 ay uzatılır.</span></div>
    </Modal>
  );
}

function Odemeler({ firmalar, odemeler, odemeEkleAc, uyeAc }) {
  const [ay, setAy] = React.useState('tumu');
  const [arama, setArama] = React.useState('');
  const firmaAd = (id) => (firmalar.find(f => f.id === id) || {}).ad || '?';
  const aylar = [...new Set(odemeler.map(o => ayAnahtar(o.tarih)))].sort().reverse();
  const liste = odemeler
    .filter(o => ay === 'tumu' || ayAnahtar(o.tarih) === ay)
    .filter(o => firmaAd(o.firmaId).toLocaleLowerCase('tr').includes(arama.toLocaleLowerCase('tr')))
    .sort((a,b) => b.tarih.localeCompare(a.tarih));
  const toplam = liste.reduce((t,o) => t + o.tutar, 0);
  return (
    <div className="yg-ic">
      <div className="ust">
        <div><h1>Ödemeler</h1><div className="ust-alt">{liste.length} kayıt · toplam {para(toplam)}</div></div>
        <div className="ust-sag">
          <select className="girdi" style={{ width: 'auto' }} value={ay} onChange={(e) => setAy(e.target.value)}>
            <option value="tumu">Tüm aylar</option>{aylar.map(a => <option key={a} value={a}>{ayAdi(a)}</option>)}
          </select>
          <AraKutusu deger={arama} onDegis={setArama} yertut="Firma ara…" />
          <button className="btn birincil" onClick={() => odemeEkleAc(null)}><Ikon ad="arti" boy={15} /> Ödeme Ekle</button>
        </div>
      </div>
      <div className="kart">
        {liste.length === 0 ? <Bos metin={odemeler.length === 0 ? 'Henüz ödeme kaydı yok. İlk ödemeyi sağ üstteki butonla ekleyebilirsin.' : 'Bu filtreyle eşleşen ödeme yok.'} /> : (
          <table className="tablo">
            <thead><tr><th>Tarih</th><th>Firma</th><th className="sag">Tutar</th><th>Yöntem</th><th>Dönem</th><th>Not</th></tr></thead>
            <tbody>{liste.map(o => (
              <tr key={o.id}>
                <td className="tab" style={{ whiteSpace: 'nowrap' }}>{tarihK(o.tarih)}</td>
                <td><button className="link-btn" style={{ color: 'var(--ink)', fontWeight: 600 }} onClick={() => uyeAc(o.firmaId)}>{firmaAd(o.firmaId)}</button></td>
                <td className="sag kalin tab">{para(o.tutar)}</td>
                <td>{o.yontem}</td>
                <td>{o.donem}</td>
                <td className="soluk">{o.not || '—'}</td>
              </tr>))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
Object.assign(window, { OdemeEkleModal, Odemeler });
