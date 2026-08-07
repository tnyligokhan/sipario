const YOLLAR = {
panel: <><rect x="3" y="3" width="7" height="7" rx="1.5"></rect><rect x="14" y="3" width="7" height="7" rx="1.5"></rect><rect x="3" y="14" width="7" height="7" rx="1.5"></rect><rect x="14" y="14" width="7" height="7" rx="1.5"></rect></>,
uyeler: <><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></>,
odemeler: <><rect x="1" y="4" width="22" height="16" rx="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></>,
gelirgider: <><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"></polyline><polyline points="16 7 22 7 22 13"></polyline></>,
cikis: <><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path><polyline points="16 17 21 12 16 7"></polyline><line x1="21" y1="12" x2="9" y2="12"></line></>,
ara: <><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></>,
arti: <><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></>,
kapat: <><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></>,
geri: <><line x1="19" y1="12" x2="5" y2="12"></line><polyline points="12 19 5 12 12 5"></polyline></>,
sagok: <polyline points="9 18 15 12 9 6"></polyline>,
bilgi: <><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></>,
saat: <><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></>,
uyari: <><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></>,
kutu: <><polyline points="22 12 16 12 14 15 10 15 8 12 2 12"></polyline><path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"></path></>,
damla: <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path>,
takvim: <><rect x="3" y="4" width="18" height="18" rx="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></>,
telefon: <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path>
};
function Ikon({ ad, boy = 18 }) {
  return <svg width={boy} height={boy} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">{YOLLAR[ad]}</svg>;
}
function Rozet({ durum }) { const d = DURUMLAR[durum]; return <span className={'rozet ' + d.cls}>{d.ad}</span>; }
function Bos({ ikon = 'kutu', metin }) {
  return <div className="bos"><div className="bos-ikon"><Ikon ad={ikon} boy={20} /></div><div className="bos-metin">{metin}</div></div>;
}
function Modal({ baslik, onKapat, children, alt }) {
  React.useEffect(() => {
    const f = (e) => { if (e.key === 'Escape') onKapat(); };
    window.addEventListener('keydown', f); return () => window.removeEventListener('keydown', f);
  }, []);
  return (
    <div className="modal-arka" onMouseDown={(e) => { if (e.target === e.currentTarget) onKapat(); }}>
      <div className="modal">
        <div className="modal-baslik">{baslik}<button className="modal-kapat" onClick={onKapat}><Ikon ad="kapat" boy={17} /></button></div>
        <div className="modal-govde">{children}</div>
        {alt && <div className="modal-alt">{alt}</div>}
      </div>
    </div>
  );
}
function Alan({ label, children }) { return <div className="alan"><label>{label}</label>{children}</div>; }
function Radyolar({ secenekler, deger, onSec }) {
  return <div className="radyolar">{secenekler.map(s => <button key={s} type="button" className={'radyo' + (deger === s ? ' secili' : '')} onClick={() => onSec(s)}>{s}</button>)}</div>;
}
function AraKutusu({ deger, onDegis, yertut }) {
  return <div className="ara"><Ikon ad="ara" boy={15} /><input className="girdi" value={deger} onChange={(e) => onDegis(e.target.value)} placeholder={yertut} /></div>;
}
function FirmaCombo({ firmalar, secili, onSec }) {
  const [metin, setMetin] = React.useState(secili ? secili.ad : '');
  const [acik, setAcik] = React.useState(false);
  const liste = firmalar.filter(f => f.durum !== 'iptal' || true).filter(f => f.ad.toLocaleLowerCase('tr').includes(metin.toLocaleLowerCase('tr')));
  return (
    <div className="combo">
      <input className="girdi" value={metin} placeholder="Firma ara…" onFocus={() => setAcik(true)} onBlur={() => setTimeout(() => setAcik(false), 150)}
        onChange={(e) => { setMetin(e.target.value); setAcik(true); onSec(null); }} />
      {acik && liste.length > 0 && (
        <div className="combo-liste">{liste.map(f => (
          <div key={f.id} className="combo-secenek" onMouseDown={() => { onSec(f); setMetin(f.ad); setAcik(false); }}>
            <span style={{ fontWeight: 600 }}>{f.ad}</span><span className="soluk">{f.il}</span>
          </div>))}
        </div>
      )}
    </div>
  );
}
Object.assign(window, { Ikon, Rozet, Bos, Modal, Alan, Radyolar, AraKutusu, FirmaCombo });
