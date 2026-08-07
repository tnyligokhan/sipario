// s-bilesenler.jsx — Sipario paylaşılan: Ust, AltNav, Sheet, BosDurum, Iskelet, HataEkran, Cevrimdisi. → window

// Sistem çubukları: üstte durum çubuğu (saat + sinyal/wifi/pil), altta ana ekran göstergesi
function SistemCubuklari({ beyaz }) {
  return (
    <React.Fragment>
      <div className={`sysbar ${beyaz ? 'byz' : ''}`}>
        <span className="tabular">10:32</span>
        <span className="sysbar-sag">
          <Icon name="sinyal" size={15} sw={2} color="currentColor" />
          <Icon name="wifi" size={15} sw={2} color="currentColor" />
          <Icon name="batarya" size={17} sw={1.7} color="currentColor" />
        </span>
      </div>
      <div className={`homeind ${beyaz ? 'byz' : ''}`}></div>
    </React.Fragment>
  );
}

function Ust({ baslik, alt, onGeri, onMenu, sag }) {
  return (
    <header className="ust">
      {onGeri
        ? <button className="ust-ikon" onClick={onGeri} aria-label="Geri"><Icon name="left" size={24} sw={2.1} color="var(--ink)" /></button>
        : onMenu
        ? <button className="ust-ikon" onClick={onMenu} aria-label="Menü"><Icon name="menu" size={23} sw={2.1} color="var(--ink)" /></button>
        : <span style={{ width: 10 }} />}
      <div className="ust-mid">
        <div className="ust-title">{baslik}</div>
        {alt && <div className="ust-sub">{alt}</div>}
      </div>
      <div className="ust-sag">{sag}</div>
    </header>
  );
}

function AltNav({ aktif, onSec, onMenu, onYeniSiparis }) {
  const sekmeler = [
    { k: 'ana', ikon: 'home', label: 'Ana' },
    { k: 'musteri', ikon: 'users', label: 'Müşteri' },
    { k: 'yeni', ikon: 'plus', label: '', fab: true },
    { k: 'siparis', ikon: 'list', label: 'Sipariş' },
    { k: 'gunsonu', ikon: 'wallet', label: 'Gün Sonu' },
  ];
  const sol = sekmeler.slice(0, 2), sag = sekmeler.slice(3);
  const Sekme = (s) => (
    <button key={s.k} className={`altnav-b ${aktif === s.k ? 'on' : ''}`} onClick={() => onSec(s.k)}>
      <Icon name={s.ikon} size={21} sw={aktif === s.k ? 2.3 : 1.9} color={aktif === s.k ? '#fff' : 'rgba(255,255,255,.45)'} />
      <span>{s.label}</span>
    </button>
  );
  return (
    <nav className="altnav">
      <div className="altnav-grup">{sol.map(Sekme)}</div>
      <button className="altnav-fab" onClick={onYeniSiparis} aria-label="Yeni sipariş">
        <Icon name="plus" size={26} sw={2.3} color="var(--accent-ink)" />
      </button>
      <div className="altnav-grup">{sag.map(Sekme)}</div>
    </nav>
  );
}

// Çekmece menü (soldan açılır)
function Cekmece({ acik, onKapat, rol, isletme, aktif, onTab, onAc, onCikis, onDestek }) {
  const [render, setRender] = React.useState(acik);
  const [gor, setGor] = React.useState(false);
  React.useEffect(() => {
    if (acik) setRender(true);
    else { setGor(false); const t = setTimeout(() => setRender(false), 280); return () => clearTimeout(t); }
  }, [acik]);
  React.useEffect(() => {
    if (render && acik) { const id = requestAnimationFrame(() => requestAnimationFrame(() => setGor(true))); return () => cancelAnimationFrame(id); }
  }, [render, acik]);
  if (!render) return null;
  const kurye = rol === 'kurye';
  const rolAd = rol === 'patron' ? 'Yönetici' : kurye ? 'Kurye' : 'Tek kişilik';
  const MENU = [
    { k: 'ana', ikon: 'home', label: 'Ana Sayfa' },
    { k: 'musteri', ikon: 'users', label: 'Müşteriler' },
    { k: 'siparis', ikon: 'list', label: 'Siparişler' },
    { k: 'gunsonu', ikon: 'wallet', label: 'Gün Sonu & Kasa Devri' },
  ];
  const YONETIM = [
    { k: 'urunler', ikon: 'box', label: 'Ürünler', gizli: kurye },
    { k: 'kuryeler', ikon: 'truck', label: 'Kuryeler', gizli: kurye },
    { k: 'muaf', ikon: 'phoneOff', label: 'Muaf Telefonlar', gizli: kurye },
  ];
  const Satir = ({ x, tabMi }) => (
    <button className={`cekr ${tabMi && aktif === x.k ? 'on' : ''}`} onClick={() => tabMi ? onTab(x.k) : onAc(x.k)}>
      <Icon name={x.ikon} size={19} sw={tabMi && aktif === x.k ? 2.3 : 1.9} color="currentColor" />
      <span>{x.label}</span>
      {!tabMi && <Icon name="chevR" size={16} sw={2} color="rgba(255,255,255,.22)" />}
    </button>
  );
  return (
    <div className={`cek-scrim ${gor ? 'on' : ''}`} onClick={onKapat}>
      <aside className={`cek ${gor ? 'on' : ''}`} onClick={(e) => e.stopPropagation()}>
        <div className="cek-head">
          <span className="cek-logo"><Icon name="phoneCall" size={21} sw={2.2} color="var(--accent-ink)" /></span>
          <div className="cek-head-mid"><div className="cek-isletme">{isletme.ad}</div><div className="cek-rol">{rolAd} · <span className="cek-sync-txt">senkron <b className="tabular">10:32</b></span></div></div>
          <button className="cek-x" onClick={onKapat} aria-label="Kapat"><Icon name="x" size={19} sw={2.2} color="rgba(255,255,255,.7)" /></button>
        </div>
        <div className="cek-govde">
          <div className="cek-sec">Menü</div>
          {MENU.map((x) => <Satir key={x.k} x={x} tabMi />)}
          {!kurye && (
            <React.Fragment>
              <div className="cek-sec">Yönetim</div>
              {YONETIM.filter((x) => !x.gizli).map((x) => <Satir key={x.k} x={x} />)}
              <div className="lst-grid">
                <div className="lst-kart">
                  <div className="lst-ust"><span className="lst-ic ok"><Icon name="check" size={13} sw={2.6} color="#3DDC97" /></span><span className="lst-pil ok">Aktif</span></div>
                  <div className="lst-v tabular">248 <small>gün</small></div>
                  <div className="lst-l">Lisans · bitiş <span className="tabular">30 Mar 2027</span></div>
                  <div className="lst-bar"><i style={{ width: '68%', background: '#3DDC97' }} /></div>
                </div>
                <div className="lst-kart">
                  <div className="lst-ust"><span className="lst-ic"><Icon name="bolt" size={13} sw={2.4} color="#B3A6FF" /></span><span className="lst-pil">Aylık 50</span></div>
                  <div className="lst-v tabular">34 <small>hak</small></div>
                  <div className="lst-l">Oto sıralama bakiyesi</div>
                  <div className="lst-bar"><i style={{ width: '68%', background: '#B3A6FF' }} /></div>
                </div>
              </div>
            </React.Fragment>
          )}
          <div className="cek-sec">Uygulama</div>
          <Satir x={{ k: 'ayarlar', ikon: 'settings', label: 'Ayarlar' }} />
        </div>
        <div className="cek-alt">
          <button className="cek-destek" onClick={onDestek}><Icon name="chat" size={17} sw={2} color="currentColor" />Sipario Destek Hattı</button>
          <button className="cek-cikis" onClick={onCikis} aria-label="Çıkış Yap"><Icon name="power" size={18} sw={2.1} color="#FF9FA3" /></button>
        </div>
      </aside>
    </div>
  );
}

// Alttan açılan sayfa
function Sheet({ open, onClose, baslik, children, tam }) {
  const [render, setRender] = React.useState(open);
  const [gorunur, setGorunur] = React.useState(false);
  React.useEffect(() => {
    if (open) setRender(true);
    else { setGorunur(false); const t = setTimeout(() => setRender(false), 260); return () => clearTimeout(t); }
  }, [open]);
  React.useEffect(() => {
    if (render && open) { const id = requestAnimationFrame(() => requestAnimationFrame(() => setGorunur(true))); return () => cancelAnimationFrame(id); }
  }, [render, open]);
  if (!render) return null;
  return (
    <div className={`sheet-scrim ${gorunur ? 'on' : ''}`} onClick={onClose}>
      <div className={`sheet ${tam ? 'tam' : ''} ${gorunur ? 'on' : ''}`} onClick={(e) => e.stopPropagation()}>
        {baslik && (
          <div className="sheet-ust">
            <div className="sheet-tut" />
            <div className="sheet-head">
              <span className="sheet-title">{baslik}</span>
              <button className="sheet-x" onClick={onClose} aria-label="Kapat"><Icon name="x" size={22} sw={2.2} color="var(--muted)" /></button>
            </div>
          </div>
        )}
        <div className="sheet-icerik">{children}</div>
      </div>
    </div>
  );
}

function BosDurum({ ikon = 'box', baslik, aciklama, aksiyon, onAksiyon }) {
  return (
    <div className="bos">
      <div className="bos-ikon"><Icon name={ikon} size={40} sw={1.5} color="var(--accent)" /></div>
      <div className="bos-baslik">{baslik}</div>
      {aciklama && <div className="bos-aciklama">{aciklama}</div>}
      {aksiyon && <button className="btn btn-p" style={{ marginTop: 18 }} onClick={onAksiyon}>{aksiyon}</button>}
    </div>
  );
}

function Iskelet({ adet = 5 }) {
  return (
    <div className="isk-list">
      {Array.from({ length: adet }).map((_, i) => (
        <div key={i} className="isk-row">
          <div className="isk-av sh" />
          <div style={{ flex: 1 }}>
            <div className="isk-l sh" style={{ width: '55%' }} />
            <div className="isk-l sh" style={{ width: '35%', marginTop: 7 }} />
          </div>
          <div className="isk-l sh" style={{ width: 62 }} />
        </div>
      ))}
    </div>
  );
}

function HataEkran({ onTekrar }) {
  return (
    <div className="bos">
      <div className="bos-ikon hata"><Icon name="alert" size={40} sw={1.6} color="var(--danger)" /></div>
      <div className="bos-baslik">Bir şeyler ters gitti</div>
      <div className="bos-aciklama">Liste yüklenemedi. Bağlantını kontrol edip tekrar dene.</div>
      <button className="btn btn-p" style={{ marginTop: 18 }} onClick={onTekrar}>Tekrar Dene</button>
    </div>
  );
}

function CevrimdisiBant() {
  return <div className="cbant"><Icon name="sync" size={15} sw={2.2} color="var(--danger)" />Çevrimdışı · değişiklikler kaydedilip bağlanınca gönderilecek</div>;
}

// Onay diyaloğu
function Onay({ acik, baslik, mesaj, onayLabel = 'Onayla', tehlike, onIptal, onOnay }) {
  if (!acik) return null;
  return (
    <div className="dia-scrim" onClick={onIptal}>
      <div className="dia" onClick={(e) => e.stopPropagation()}>
        <div className="dia-title">{baslik}</div>
        {mesaj && <div className="dia-mesaj">{mesaj}</div>}
        <div className="dia-btns">
          <button className="btn btn-s" onClick={onIptal}>Vazgeç</button>
          <button className={`btn ${tehlike ? 'btn-d' : 'btn-p'}`} onClick={onOnay}>{onayLabel}</button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { Ust, AltNav, Cekmece, Sheet, BosDurum, Iskelet, HataEkran, CevrimdisiBant, Onay });
