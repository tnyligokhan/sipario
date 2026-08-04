// sw-kabuk.jsx — yönlendirme bağlamı, üst menü, alt bilgi. → window

const Yon = React.createContext({ sayfa: 'ana', git: () => {}, oturum: false });
const useYon = () => React.useContext(Yon);

function Marka({ boy = 34, koyu }){
  return (
    <span className="marka">
      <span className="marka-ik" style={{ width: boy, height: boy, borderRadius: boy * .3 }}>
        <Ikon ad="cagri" boy={boy * .56} kalin={2.3} renk="#fff" />
      </span>
      <span className="marka-ad" style={{ color: koyu ? '#F3F0EC' : undefined }}>Sipario</span>
    </span>
  );
}

const SW_MENU = [
  { k: 'ozellik', ad: 'Özellikler' },
  { k: 'fiyat', ad: 'Fiyatlandırma' },
  { k: 'destek', ad: 'Destek' },
  { k: 'iletisim', ad: 'İletişim' },
];

function UstMenu(){
  const { sayfa, git, oturum } = useYon();
  const [kaydi, setKaydi] = React.useState(false);
  const [acik, setAcik] = React.useState(false);
  React.useEffect(() => {
    const f = () => setKaydi(window.scrollY > 12);
    f(); window.addEventListener('scroll', f, { passive: true });
    return () => window.removeEventListener('scroll', f);
  }, []);
  React.useEffect(() => { setAcik(false); }, [sayfa]);
  const nav = (k) => { git(k); window.scrollTo(0, 0); };
  return (
    <header className={`ust ${kaydi ? 'kaydi' : ''} ${acik ? 'acik' : ''}`}>
      <div className="kap ust-ic">
        <button className="ust-marka" onClick={() => nav('ana')} aria-label="Sipario ana sayfa"><Marka /></button>
        <nav className="ust-nav">
          {SW_MENU.map((m) => (
            <button key={m.k} className={`ust-l ${sayfa === m.k ? 'on' : ''}`} onClick={() => nav(m.k)}>{m.ad}</button>
          ))}
        </nav>
        <div className="ust-sag">
          {oturum
            ? <button className="dg dg-b k" onClick={() => nav('hesap')}><Ikon ad="musteri" boy={17} kalin={2.1} />Hesabım</button>
            : <React.Fragment>
                <button className="dg dg-d k" onClick={() => nav('giris')}>Giriş yap</button>
                <button className="dg dg-a k" onClick={() => nav('kayit')}>Ücretsiz dene</button>
              </React.Fragment>}
        </div>
        <button className="ust-acar" onClick={() => setAcik(!acik)} aria-label="Menü">
          <Ikon ad={acik ? 'kapat' : 'menu'} boy={22} kalin={2.1} />
        </button>
      </div>
      {acik && (
        <div className="ust-mobil">
          {SW_MENU.map((m) => <button key={m.k} className="ust-ml" onClick={() => nav(m.k)}>{m.ad}<Ikon ad="sag" boy={18} kalin={2} /></button>)}
          <div className="ust-mobil-alt">
            {oturum
              ? <button className="dg dg-b tam" onClick={() => nav('hesap')}>Hesabım</button>
              : <React.Fragment>
                  <button className="dg dg-c tam" onClick={() => nav('giris')}>Giriş yap</button>
                  <button className="dg dg-a tam" onClick={() => nav('kayit')}>Ücretsiz dene</button>
                </React.Fragment>}
          </div>
        </div>
      )}
    </header>
  );
}

function AltBilgi(){
  const { git } = useYon();
  const nav = (k) => { git(k); window.scrollTo(0, 0); };
  const grup = [
    { b: 'Ürün', l: [['Özellikler','ozellik'],['Fiyatlandırma','fiyat'],['Kurulum','ozellik'],['Sürüm notları','destek']] },
    { b: 'Destek', l: [['Yardım merkezi','destek'],['Sık sorulanlar','destek'],['İletişim','iletisim'],['Demo talebi','iletisim']] },
    { b: 'Hesap', l: [['Giriş yap','giris'],['İşletme aç','kayit'],['Abonelik','hesap'],['Faturalar','hesap']] },
    { b: 'Yasal', l: [['Mesafeli satış sözleşmesi','yasal'],['İptal ve iade','yasal'],['Gizlilik ve KVKK','yasal'],['Çerez politikası','yasal']] },
  ];
  return (
    <footer className="alt gece">
      <div className="kap">
        <div className="alt-ust">
          <div className="alt-marka">
            <Marka boy={38} koyu />
            <p className="alt-slogan">Telefon çaldığında müşteriniz ekranda. Bayiler ve esnaf için sipariş, veresiye ve kurye defteri.</p>
            <div className="alt-rzt">
              <Rozet tur="yesil" nokta>Tüm sistemler çalışıyor</Rozet>
              <Rozet tur="notr">Veriler Türkiye’de</Rozet>
            </div>
          </div>
          <div className="alt-baglanti">
            {grup.map((g) => (
              <div className="alt-sutun" key={g.b}>
                <span className="mn">{g.b}</span>
                {g.l.map((l, i) => <button key={i} onClick={() => nav(l[1])}>{l[0]}</button>)}
              </div>
            ))}
          </div>
        </div>
        <div className="alt-kunye">
          <div className="alt-k-blok">
            <span className="mn k">Ünvan</span>
            <p>{SW_KUNYE.unvan}<br />{SW_KUNYE.adres}</p>
          </div>
          <div className="alt-k-blok">
            <span className="mn k">Kayıt</span>
            <p>MERSİS {SW_KUNYE.mersis}<br />{SW_KUNYE.vkn}</p>
          </div>
          <div className="alt-k-blok">
            <span className="mn k">İletişim</span>
            <p><a href={`tel:${SW_KUNYE.telefon.replace(/\s/g,'')}`}>{SW_KUNYE.telefon}</a><br /><a href={`mailto:${SW_KUNYE.eposta}`}>{SW_KUNYE.eposta}</a></p>
          </div>
          <div className="alt-k-blok">
            <span className="mn k">Ödeme</span>
            <p>{SW_KUNYE.paraBirimi} · Havale / EFT<br />ve elden ödeme</p>
          </div>
        </div>
        <div className="alt-son">
          <span className="kucuk">© 2026 {SW_KUNYE.unvan}. Tüm hakları saklıdır.</span>
          <span className="kucuk">{SW_KUNYE.saat} · Bu sayfadaki rakamlar örnektir.</span>
        </div>
      </div>
    </footer>
  );
}

Object.assign(window, { Yon, useYon, Marka, UstMenu, AltBilgi, SW_MENU });
