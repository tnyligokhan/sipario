// sw-parca.jsx — paylaşılan arayüz parçaları. → window

// Panel: mürekkep konturlu kutu, isteğe bağlı mono başlık bandı
function Pano({ etiket, sag, ince, duz, ic = true, sikIc, genisIc, sinif = '', cocuk, children, stil }){
  return (
    <div className={`pano ${ince ? 'ince' : ''} ${duz ? 'duz' : ''} ${sinif}`} style={stil}>
      {etiket && (
        <div className="pano-bas">
          <span className="mn">{etiket}</span>
          {sag && <span className="pano-bas-sag">{sag}</span>}
        </div>
      )}
      {ic ? <div className={`pano-ic ${sikIc ? 'sik' : ''} ${genisIc ? 'genis' : ''}`}>{children || cocuk}</div> : (children || cocuk)}
    </div>
  );
}

// Bölüm başlığı — mono kulak + sola dayalı başlık + açıklama
function BlmBas({ kulak, baslik, aciklama, seviye = 'h1', genis, children }){
  const B = seviye === 'h2' ? 'h2' : 'h2';
  return (
    <div className="blm-bas" style={genis ? { maxWidth: 780 } : undefined}>
      {kulak && <span className="blm-kulak mn"><i />{kulak}</span>}
      <B className={seviye}>{baslik}</B>
      {aciklama && <p className="gvd b">{aciklama}</p>}
      {children}
    </div>
  );
}

// Form alanı: etiket üstte ve hep görünür, hata alanın altında
function Alan({ etiket, not, ipucu, hata, cocuk, children, id }){
  return (
    <div className="alan">
      {etiket && <label className="etk" htmlFor={id}>{etiket}{not && <small>{not}</small>}</label>}
      {children || cocuk}
      {hata ? <span className="hata"><Ikon ad="uyari" boy={14} kalin={2.3} />{hata}</span>
        : ipucu ? <span className="yardim">{ipucu}</span> : null}
    </div>
  );
}

function Rozet({ tur = 'notr', nokta, canli, children }){
  return <span className={`rzt rzt-${tur} ${canli ? 'canli' : ''}`}>{(nokta || canli) && <i />}{children}</span>;
}

function Kutu({ tur = 'mor', ikon, children }){
  return <div className={`kutu kutu-${tur}`}>{ikon !== false && <Ikon ad={ikon || 'bilgi'} boy={17} kalin={2.1} />}<span>{children}</span></div>;
}

// Kota çubuğu — kullanım / toplam
function Kota({ kullanilan, toplam, renk = 'var(--mor)', etiket, alt }){
  const y = Math.min(100, Math.round((kullanilan / toplam) * 100));
  return (
    <div className="kota">
      <div className="kota-ust">
        <span className="h4">{etiket}</span>
        <span className="kota-v tab">{kullanilan}<span className="kota-bol">/{toplam}</span></span>
      </div>
      <div className="kota-bar"><i style={{ width: y + '%', background: renk }} /></div>
      {alt && <span className="kucuk">{alt}</span>}
    </div>
  );
}

// SSS akordiyonu
function SssListe({ liste, acikVar }){
  const [acik, setAcik] = React.useState(acikVar ? 0 : -1);
  return (
    <div className="sss">
      {liste.map((x, i) => (
        <div key={i} className={`sss-satir ${acik === i ? 'on' : ''}`}>
          <button className="sss-bas" onClick={() => setAcik(acik === i ? -1 : i)} aria-expanded={acik === i}>
            <span className="h4">{x.s}</span>
            <span className="sss-isaret"><Ikon ad={acik === i ? 'eksi' : 'arti'} boy={17} kalin={2.4} /></span>
          </button>
          {acik === i && <div className="sss-govde gvd">{x.c}</div>}
        </div>
      ))}
    </div>
  );
}

// Sekme çubuğu
function Sekmeler({ liste, secili, onSec, tam }){
  return (
    <div className={`sekme-bar ${tam ? 'tam' : ''}`} role="tablist">
      {liste.map((x) => (
        <button key={x.k} role="tab" aria-selected={secili === x.k}
          className={`sekme ${secili === x.k ? 'on' : ''}`} onClick={() => onSec(x.k)}>
          {x.ik && <Ikon ad={x.ik} boy={17} kalin={2} />}{x.ad}
        </button>
      ))}
    </div>
  );
}

// Adım göstergesi — çok adımlı formlarda ilerleme görünür olmalı
function Ilerleme({ adimlar, aktif }){
  return (
    <ol className="ilerle">
      {adimlar.map((a, i) => (
        <li key={a} className={`ilerle-adim ${i < aktif ? 'ok' : ''} ${i === aktif ? 'on' : ''}`}>
          <span className="ilerle-no">{i < aktif ? <Ikon ad="onay" boy={13} kalin={3} /> : i + 1}</span>
          <span className="ilerle-ad">{a}</span>
        </li>
      ))}
    </ol>
  );
}

// Yer tutucu görsel — gerçek fotoğraf gelene kadar
function Gorsel({ etiket, oran = '4 / 3', stil }){
  return (
    <div className="gorsel" style={{ aspectRatio: oran, ...stil }}>
      <span className="gorsel-c mn">{etiket}</span>
    </div>
  );
}

// Diyalog — document.body'ye portal ile basılır: sayfa sarmalayıcısının
// opaklık/dönüşüm animasyonu bir içeren blok yaratsa bile viewport'a oturur.
function Diyalog({ acik, onKapat, baslik, alt, genis, children }){
  React.useEffect(() => {
    if(!acik) return;
    const f = (e) => { if(e.key === 'Escape') onKapat(); };
    window.addEventListener('keydown', f); return () => window.removeEventListener('keydown', f);
  }, [acik, onKapat]);
  if(!acik) return null;
  return ReactDOM.createPortal(
    <div className="diyalog-fon" onClick={onKapat}>
      <div className="diyalog" style={genis ? { maxWidth: 620 } : undefined} onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
        <div className="diyalog-bas">
          <span className="h3">{baslik}</span>
          <button className="diyalog-x" onClick={onKapat} aria-label="Kapat"><Ikon ad="kapat" boy={19} kalin={2.2} /></button>
        </div>
        <div className="diyalog-ic">{children}</div>
        {alt && <div className="diyalog-alt">{alt}</div>}
      </div>
    </div>, document.body);
}

function Bildirim({ metin }){
  if(!metin) return null;
  return <div className="bildirim"><Ikon ad="tamam" boy={17} kalin={2.2} />{metin}</div>;
}

Object.assign(window, { Pano, BlmBas, Alan, Rozet, Kutu, Kota, SssListe, Sekmeler, Ilerleme, Gorsel, Diyalog, Bildirim });
