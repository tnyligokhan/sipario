// s-sihirbaz.jsx — İzin Sihirbazı: karşılama → her izin AYRI ADIM → deneme çağrısı. → window

const IZINLER = [
  { k: 'tarama',   ad: 'Arama tanıma',        neden: 'Telefon çaldığında arayan numarayı okuyup müşterinizle eşleştirmek için gereklidir.', ikon: 'phone',    zorunlu: true },
  { k: 'rehber',   ad: 'Rehber erişimi',       neden: 'Kayıtlı müşterilerinizi arayan numarayla eşleştirebilmek için rehbere erişiriz.',       ikon: 'users',    zorunlu: false },
  { k: 'overlay',  ad: 'Üste çizim izni',      neden: 'Çağrı kartını başka uygulamaların üzerinde, en üstte gösterebilmek için gereklidir.',   ikon: 'box',      zorunlu: true },
  { k: 'bildirim', ad: 'Bildirimler',          neden: 'Yeni sipariş, senkron ve borç hatırlatmalarını size iletebilmek için.',                 ikon: 'info',     zorunlu: false },
  { k: 'kilit',    ad: 'Kilit ekranında göster',neden: 'Telefon kilitliyken bile çağrı kartının çıkması için.',                                 ikon: 'lock',     zorunlu: false },
  { k: 'pil',      ad: 'Pil optimizasyonu muafiyeti', neden: 'Uygulamanın arka planda kapatılmaması, çağrıları kaçırmaması için.',              ikon: 'bolt',     zorunlu: false },
];

function Sihirbaz({ onBitti, onKapat }) {
  // adim: 0 karşılama · 1..N izinler (her biri ayrı ekran) · N+1 deneme çağrısı
  const [adim, setAdim] = React.useState(0);
  const [durum, setDurum] = React.useState({}); // izin k → 'verildi'|'atlandi'
  const [test, setTest] = React.useState('bekliyor'); // bekliyor|calisiyor|basari|hata

  const N = IZINLER.length;
  const testAdim = N + 1;
  const verilenSayi = IZINLER.filter((i) => durum[i.k] === 'verildi').length;
  const cekirdekTamam = IZINLER.filter((i) => i.zorunlu).every((i) => durum[i.k] === 'verildi');

  // ── Karşılama ──
  if (adim === 0) return (
    <div className="siz">
      <button className="siz-kapat" onClick={onKapat} aria-label="Kapat"><Icon name="x" size={22} sw={2.2} color="var(--muted)" /></button>
      <div className="siz-govde ortala">
        <div className="siz-logo"><Icon name="phoneCall" size={34} sw={2.1} color="var(--accent-ink)" /></div>
        <div className="siz-h1">Telefon çaldığında<br />müşteriniz ekranda</div>
        <div className="siz-p">Bunun çalışması için telefonunuzdan {N} izin isteyeceğiz. Her adımı tek tek, ne işe yaradığını açıklayarak göstereceğiz.</div>
        <div className="siz-guven"><Icon name="lock" size={15} sw={2} color="var(--ok)" />İzinler yalnız arayanı tanımak için kullanılır.</div>
      </div>
      <div className="siz-alt"><button className="btn btn-p" onClick={() => setAdim(1)}>Kuruluma Başla</button></div>
    </div>
  );

  // ── Deneme çağrısı ──
  if (adim === testAdim) return (
    <div className="siz">
      <div className="siz-ilerle"><div className="siz-ilerle-bar" style={{ width: '100%' }} /></div>
      <Ust baslik="Kurulumu Test Et" onGeri={() => setAdim(N)} />
      <div className="siz-govde ortala">
        {test === 'basari' ? (
          <React.Fragment>
            <div className="siz-logo basari"><Icon name="check" size={38} sw={2.6} color="#fff" /></div>
            <div className="siz-h1">Kart çıktı!</div>
            <div className="siz-p">Arama tanıma çalışıyor. Artık telefon çaldığında müşteriniz ekranda belirecek.</div>
          </React.Fragment>
        ) : test === 'hata' ? (
          <React.Fragment>
            <div className="siz-logo hata"><Icon name="alert" size={36} sw={2} color="#fff" /></div>
            <div className="siz-h1">Kart çıkmadı</div>
            <div className="siz-p">Büyük ihtimalle "üste çizim" izni eksik. Adımlara dönüp kontrol edelim.</div>
          </React.Fragment>
        ) : (
          <React.Fragment>
            <div className={`siz-logo ${test === 'calisiyor' ? 'calis' : ''}`}><Icon name="phoneCall" size={34} sw={2.1} color="var(--accent-ink)" /></div>
            <div className="siz-h1">Kendinizi test arayın</div>
            <div className="siz-p">Başka bir hattan kendi numaranızı arayın. Kart ekranda çıkarsa kurulum tamam demektir.</div>
          </React.Fragment>
        )}
      </div>
      <div className="siz-alt">
        {test === 'basari'
          ? <button className="btn btn-p" onClick={onBitti}>Bitir</button>
          : test === 'hata'
          ? <button className="btn btn-p" onClick={() => setAdim(1)}>Adımlara Dön</button>
          : <React.Fragment>
              <button className="btn btn-p" onClick={() => { setTest('calisiyor'); setTimeout(() => setTest(cekirdekTamam ? 'basari' : 'hata'), 1400); }} disabled={test === 'calisiyor'}>
                {test === 'calisiyor' ? <span className="spinner" /> : 'Deneme Çağrısı Yap'}
              </button>
              <button className="siz-atla-btn" onClick={onBitti}>Şimdilik atla</button>
            </React.Fragment>}
      </div>
    </div>
  );

  // ── Tek izin adımı ──
  const iz = IZINLER[adim - 1];
  const bu = durum[iz.k];
  const ilerle = () => setAdim(adim + 1);
  const ver = () => { setDurum((d) => ({ ...d, [iz.k]: 'verildi' })); setTimeout(ilerle, 260); };
  const atla = () => { setDurum((d) => ({ ...d, [iz.k]: 'atlandi' })); ilerle(); };

  return (
    <div className="siz">
      <div className="siz-ilerle"><div className="siz-ilerle-bar" style={{ width: `${(adim / testAdim) * 100}%` }} /></div>
      <Ust baslik={`Adım ${adim}/${N}`} alt={`${verilenSayi} izin verildi`} onGeri={() => setAdim(adim - 1)} />
      <div className="siz-govde ortala">
        <div className={`izb-ic ${bu === 'verildi' ? 'ok' : ''}`}>
          <Icon name={bu === 'verildi' ? 'check' : iz.ikon} size={40} sw={1.9} color={bu === 'verildi' ? '#fff' : 'var(--accent)'} />
        </div>
        <div className="izb-ad">{iz.ad}</div>
        {iz.zorunlu && <span className="izb-zorunlu">Zorunlu</span>}
        <div className="siz-p">{iz.neden}</div>
        {bu === 'verildi' && <div className="izb-verildi"><Icon name="check" size={15} sw={2.6} color="var(--ok)" />İzin verildi</div>}
        {bu === 'atlandi' && <div className="izb-atlandi">Bu izni atladınız — sonra Menü'den tekrar açabilirsiniz.</div>}
      </div>
      <div className="siz-alt">
        {bu === 'verildi'
          ? <button className="btn btn-p" onClick={ilerle}>Devam</button>
          : <React.Fragment>
              <button className="btn btn-p" onClick={ver}>İzin Ver</button>
              {iz.zorunlu
                ? <div className="siz-uyari">Bu izin kartın çalışması için zorunludur.</div>
                : <button className="siz-atla-btn" onClick={atla}>Atla</button>}
            </React.Fragment>}
      </div>
    </div>
  );
}

Object.assign(window, { Sihirbaz });
