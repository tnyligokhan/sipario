// s-giris.jsx — Giriş (KAYIT YOK) + s-kilit.jsx birleşik: abonelik kilidi (nötr). → window

function GirisEkran({ onGiris }) {
  const [firma, setFirma] = React.useState('');
  const [kullanici, setKullanici] = React.useState('');
  const [parola, setParola] = React.useState('');
  const [gelismis, setGelismis] = React.useState(false);
  const [sunucu, setSunucu] = React.useState('');
  const [yukleniyor, setYukleniyor] = React.useState(false);
  const [hata, setHata] = React.useState(null);
  const gonder = (e) => {
    e.preventDefault();
    const h = {};
    if (!firma.trim()) h.firma = 'Firma kodu boş bırakılamaz';
    else if (!/^[a-z0-9-]{3,}$/i.test(firma.trim())) h.firma = 'Geçersiz firma kodu (en az 3 harf/rakam)';
    if (!kullanici.trim()) h.kullanici = 'Kullanıcı adı boş bırakılamaz';
    else if (!/^[a-z0-9._-]{3,}$/i.test(kullanici.trim())) h.kullanici = 'Geçersiz kullanıcı adı (en az 3 harf/rakam)';
    if (parola.length < 4) h.parola = parola ? 'Parola en az 4 karakter' : 'Parola boş bırakılamaz';
    if (gelismis && sunucu && !/^[a-z0-9.-]+$/i.test(sunucu.trim())) h.sunucu = 'Geçersiz sunucu adresi';
    if (Object.keys(h).length) { setHata(h); return; }
    setHata(null); setYukleniyor(true); setTimeout(() => onGiris({ kullanici, firma }), 700);
  };

  return (
    <div className="giris">
      <div className="giris-marka">
        <span className="giris-logo"><Icon name="phoneCall" size={26} sw={2.2} color="var(--accent-ink)" /></span>
        <div className="giris-wordmark">Sipario</div>
        <div className="giris-slogan">Telefon çaldığında müşteriniz ekranda</div>
      </div>
      <form className="giris-form" onSubmit={gonder} noValidate>
        <label className="s-flabel">Firma Kodu</label>
        <input className={`s-input ${hata && hata.firma ? 'err' : ''}`} value={firma} onChange={(e) => { setFirma(e.target.value); setHata(null); }} placeholder="ornek: merkezbayi" autoCapitalize="none" autoComplete="organization" />
        {hata && hata.firma && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.firma}</div>}
        <label className="s-flabel">Kullanıcı Adı</label>
        <input className={`s-input ${hata && hata.kullanici ? 'err' : ''}`} value={kullanici} onChange={(e) => { setKullanici(e.target.value); setHata(null); }} placeholder="ornek: mehmet.usta" autoCapitalize="none" autoComplete="username" />
        {hata && hata.kullanici && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.kullanici}</div>}
        <label className="s-flabel">Parola</label>
        <input className={`s-input ${hata && hata.parola ? 'err' : ''}`} type="password" value={parola} onChange={(e) => { setParola(e.target.value); setHata(null); }} placeholder="••••••••" autoComplete="current-password" />
        {hata && hata.parola && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.parola}</div>}
        {gelismis && (
          <React.Fragment>
            <label className="s-flabel">Sunucu adresi</label>
            <input className={`s-input ${hata && hata.sunucu ? 'err' : ''}`} value={sunucu} onChange={(e) => { setSunucu(e.target.value); setHata(null); }} placeholder="sipario.local" />
            {hata && hata.sunucu && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.sunucu}</div>}
          </React.Fragment>
        )}
        <button type="button" className="giris-gelismis" onClick={() => setGelismis((v) => !v)}>{gelismis ? '− Gelişmiş' : '+ Gelişmiş (sunucu adresi)'}</button>
        <button className="btn btn-p giris-btn" type="submit" disabled={yukleniyor}>
          {yukleniyor ? <span className="spinner" /> : 'Giriş Yap'}
        </button>
        <div className="giris-alt">Firma kodunuzu ve hesabınızı işletme yöneticiniz oluşturur.</div>
      </form>
    </div>
  );
}

// Abonelik kilidi — NÖTR bilgi, satın almaya çağrı YOK
function AbonelikKilidi({ onGeri }) {
  return (
    <div className="kilit">
      <div className="kilit-ic"><Icon name="info" size={38} sw={1.6} color="var(--accent)" /></div>
      <div className="kilit-baslik">Aboneliğiniz sona erdi</div>
      <div className="kilit-metin">
        Uygulama şu an salt-okunur kipte. Mevcut kayıtlarınızı görüntüleyebilir, ancak yeni sipariş,
        tahsilat veya değişiklik yapamazsınız. Erişiminizi sürdürmek için işletme yöneticinizle görüşün.
      </div>
      <div className="kilit-durum"><Icon name="clock" size={15} sw={2} color="var(--muted)" />Bitiş: 30 Haziran 2026</div>
      {onGeri && <button className="btn btn-s" style={{ marginTop: 20 }} onClick={onGeri}>Kayıtları Görüntüle</button>}
    </div>
  );
}

Object.assign(window, { GirisEkran, AbonelikKilidi });
