function Giris({ onGiris }) {
  const [eposta, setEposta] = React.useState('');
  const [sifre, setSifre] = React.useState('');
  const gonder = (e) => { e.preventDefault(); if (eposta && sifre) onGiris(); };
  return (
    <div className="giris-sahne">
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div className="yk-mark" style={{ width: 36, height: 36, borderRadius: 11 }}><Ikon ad="damla" boy={19} /></div>
        <span className="yk-ad" style={{ fontSize: 21 }}>Sipario</span>
      </div>
      <form className="giris-kart" onSubmit={gonder}>
        <div>
          <div className="giris-baslik">Yönetim Paneli</div>
          <div style={{ fontSize: 13, color: 'var(--muted)', marginTop: 4 }}>Kurucu hesabınla giriş yap.</div>
        </div>
        <Alan label="E-posta"><input className="girdi" type="email" value={eposta} onChange={(e) => setEposta(e.target.value)} placeholder="ornek@sipario.app" autoFocus /></Alan>
        <Alan label="Şifre"><input className="girdi" type="password" value={sifre} onChange={(e) => setSifre(e.target.value)} placeholder="••••••••" /></Alan>
        <button className="btn birincil blok" type="submit" disabled={!eposta || !sifre}>Giriş Yap</button>
      </form>
      <div className="giris-not">Sipario iç yönetim aracı · yalnızca kurucular</div>
    </div>
  );
}
window.Giris = Giris;
