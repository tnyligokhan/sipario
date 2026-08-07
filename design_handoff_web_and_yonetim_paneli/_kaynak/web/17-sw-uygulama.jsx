// sw-uygulama.jsx — kök: yönlendirme, oturum, sepet, bildirim. → window

const SW_SAYFA = {
  ana: { c: () => <AnaSayfa />, baslik: 'Sipario — Telefon çaldığında müşteriniz ekranda' },
  ozellik: { c: () => <OzellikSayfa />, baslik: 'Özellikler · Sipario' },
  fiyat: { c: () => <FiyatSayfa />, baslik: 'Fiyatlandırma · Sipario' },
  destek: { c: () => <DestekSayfa />, baslik: 'Destek · Sipario' },
  iletisim: { c: () => <IletisimSayfa />, baslik: 'İletişim · Sipario' },
  yasal: { c: () => <YasalSayfa />, baslik: 'Yasal · Sipario' },
  hesap: { c: () => <HesapSayfa />, baslik: 'Hesabım · Sipario' },
  giris: { c: () => <GirisSayfa />, baslik: 'Giriş · Sipario', ciplak: true },
  kayit: { c: () => <KayitSayfa />, baslik: 'İşletme aç · Sipario', ciplak: true },
  sifre: { c: () => <SifreSayfa />, baslik: 'Parola sıfırlama · Sipario', ciplak: true },
  odeme: { c: () => <OdemeSayfa />, baslik: 'Ödeme · Sipario', ciplak: true },
};

function Uygulama(){
  const ilk = (window.location.hash || '').replace('#', '');
  const [sayfa, setSayfa] = React.useState(SW_SAYFA[ilk] ? ilk : 'ana');
  const [oturum, setOturum] = React.useState(false);
  const [hesapDurum, setHesapDurum] = React.useState('aktif'); // 'aktif' | 'deneme'
  const [sepet, setSepet] = React.useState(null);
  const [mesaj, setMesaj] = React.useState(null);

  const bildir = React.useCallback((m) => {
    setMesaj(m);
    window.clearTimeout(window.__swT);
    window.__swT = window.setTimeout(() => setMesaj(null), 2600);
  }, []);

  const git = React.useCallback((k) => {
    if(!SW_SAYFA[k]) return;
    setSayfa(k);
    try { window.history.replaceState(null, '', '#' + k); } catch(e) {}
  }, []);

  React.useEffect(() => {
    const s = SW_SAYFA[sayfa];
    document.title = s.baslik;
    document.body.dataset.koyu = sayfa === 'ana' ? '1' : '';
  }, [sayfa]);

  React.useEffect(() => {
    const f = () => { const k = (window.location.hash || '').replace('#', ''); if(SW_SAYFA[k]) setSayfa(k); };
    window.addEventListener('hashchange', f);
    return () => window.removeEventListener('hashchange', f);
  }, []);

  const s = SW_SAYFA[sayfa];
  const deger = React.useMemo(() => ({ sayfa, git, oturum, setOturum, sepet, setSepet, bildir, hesapDurum, setHesapDurum }),
    [sayfa, git, oturum, sepet, bildir, hesapDurum]);

  return (
    <Yon.Provider value={deger}>
      {!s.ciplak && <UstMenu />}
      <div key={sayfa} className="sayfa-gecis">{s.c()}</div>
      {!s.ciplak && <AltBilgi />}
      <Bildirim metin={mesaj} />
    </Yon.Provider>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Uygulama />);
