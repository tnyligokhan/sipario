// s-muaf.jsx — Muaf Telefonlar: bu numaralar aradığında Caller ID kartı çıkmaz. → window

function MuafEkran({ muaflar, onGeri, onEkle, onSil, onPing }) {
  const [acik, setAcik] = React.useState(false);
  const [ad, setAd] = React.useState('');
  const [no, setNo] = React.useState('');
  const [hata, setHata] = React.useState(null);
  const ekle = () => {
    const h = {};
    const d = no.replace(/\D/g, '');
    if (d.length < 10) h.no = 'Geçerli telefon girin (10-11 hane)';
    else if (muaflar.some((m) => m.no.replace(/\D/g, '').slice(-10) === d.slice(-10))) h.no = 'Bu numara zaten muaf listesinde';
    if (Object.keys(h).length) { setHata(h); return; }
    onEkle({ id: 'mf' + Date.now(), ad: ad.trim() || 'İsimsiz', no: no.trim() });
    setAcik(false); setAd(''); setNo(''); setHata(null);
  };
  return (
    <div className="ekran">
      <Ust baslik="Muaf Telefonlar" alt={`${muaflar.length} numara · çağrı kartı çıkmaz`} onGeri={onGeri} />
      <div className="ekran-govde">
        <div className="md-not" style={{ marginTop: 10 }}><Icon name="info" size={15} sw={2} color="var(--warn)" /><span>Buradaki numaralar aradığında <b>Caller ID kartı açılmaz</b>. Kurye, tedarikçi, kişisel numaralar için kullanın.</span></div>
        <button className="ys-ekle" onClick={() => { setAd(''); setNo(''); setHata(null); setAcik(true); }}><Icon name="plus" size={20} sw={2.3} color="var(--accent)" />Muaf numara ekle</button>
        {muaflar.length === 0
          ? <div className="ys-bos"><Icon name="phone" size={28} sw={1.6} color="var(--line-2)" />Muaf numara yok</div>
          : <div className="mliste">
              {muaflar.map((m) => (
                <div key={m.id} className="muaf-row">
                  <span className="ara-ic"><Icon name="phone" size={16} sw={2} color="var(--muted)" /></span>
                  <span className="muaf-mid"><span className="muaf-ad">{m.ad}</span><span className="muaf-no tabular">{m.no}</span></span>
                  <button className="ys-sil" onClick={() => onSil(m)} aria-label="Listeden çıkar"><Icon name="x" size={17} sw={2.2} color="var(--danger)" /></button>
                </div>
              ))}
            </div>}
      </div>

      <Sheet open={acik} onClose={() => setAcik(false)} baslik="Muaf Numara Ekle">
        <div className="sb-form">
          <label className="s-flabel">Etiket</label>
          <input className="s-input" value={ad} onChange={(e) => setAd(e.target.value)} placeholder="Ör. Kurye Ali, Tedarikçi" autoFocus />
          <label className="s-flabel">Telefon *</label>
          <input className={`s-input tabular ${hata && hata.no ? 'err' : ''}`} inputMode="tel" value={no} onChange={(e) => { setNo(e.target.value); setHata(null); }} placeholder="05XX XXX XX XX" />
          {hata && hata.no && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.no}</div>}
          <button className="btn btn-p" style={{ marginTop: 16 }} onClick={ekle}>Listeye Ekle</button>
        </div>
      </Sheet>
    </div>
  );
}

Object.assign(window, { MuafEkran });
