// s-isletme.jsx — İşletme Profili: kimlik, iletişim, adres, vergi, çalışma saatleri, firma kodu. → window

function IsletmeProfil({ isletme, onGeri, onKaydet, onPing }) {
  const [f, setF] = React.useState({ ad: '', sahip: '', telefon: '', whatsapp: '', adres: '', vergiDairesi: '', vergiNo: '', acilis: '08:00', kapanis: '19:00', fisNotu: '', ...isletme });
  const [hata, setHata] = React.useState(null);
  const d = (k) => (e) => { setF((p) => ({ ...p, [k]: e.target.value })); setHata(null); };
  const kaydet = () => {
    const h = {};
    if (f.ad.trim().length < 2) h.ad = 'İşletme adı girin (en az 2 karakter)';
    if (f.sahip.trim().length < 2) h.sahip = 'Yetkili adı girin';
    const t = f.telefon.replace(/\D/g, '');
    if (t.length < 10 || t.length > 11) h.telefon = 'Geçerli telefon girin (10-11 hane)';
    const w = f.whatsapp.replace(/\D/g, '');
    if (f.whatsapp.trim() && (w.length < 10 || w.length > 11)) h.whatsapp = 'Geçerli numara girin ya da boş bırakın';
    if (f.vergiNo.trim() && !/^\d{10,11}$/.test(f.vergiNo.trim())) h.vergiNo = 'Vergi no 10-11 rakam olmalı';
    if (!/^\d{2}:\d{2}$/.test(f.acilis) || !/^\d{2}:\d{2}$/.test(f.kapanis)) h.saat = 'Saatleri SS:DD biçiminde girin';
    if (Object.keys(h).length) { setHata(h); return; }
    onKaydet({ ...f, ad: f.ad.trim(), sahip: f.sahip.trim() });
  };
  const Err = ({ k }) => hata && hata[k] ? <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata[k]}</div> : null;
  return (
    <div className="ekran">
      <Ust baslik="İşletme Profili" onGeri={onGeri} />
      <div className="ekran-govde">
        <div className="fk-kart">
          <span className="fk-mid"><span className="fk-l">Firma Kodu</span><span className="fk-kod tabular">{isletme.kod || 'merkezbayi'}</span></span>
          <button className="ust-metin" onClick={() => onPing('Firma kodu kopyalandı')}>Kopyala</button>
        </div>
        <div className="ym-err" style={{ marginTop: 6 }}><Icon name="info" size={13} sw={2.2} color="var(--muted)" /><span style={{ color: 'var(--muted)' }}>Kullanıcılarınız bu kodla giriş yapar; değiştirilemez.</span></div>

        <div className="gs-baslik">Kimlik</div>
        <label className="s-flabel">İşletme adı *</label>
        <input className={`s-input ${hata && hata.ad ? 'err' : ''}`} value={f.ad} onChange={d('ad')} placeholder="Ör. Merkez Bayi" />
        <Err k="ad" />
        <label className="s-flabel">Yetkili *</label>
        <input className={`s-input ${hata && hata.sahip ? 'err' : ''}`} value={f.sahip} onChange={d('sahip')} placeholder="Ad Soyad" />
        <Err k="sahip" />

        <div className="gs-baslik">İletişim</div>
        <label className="s-flabel">Telefon *</label>
        <input className={`s-input tabular ${hata && hata.telefon ? 'err' : ''}`} inputMode="tel" value={f.telefon} onChange={d('telefon')} placeholder="0242 XXX XX XX" />
        <Err k="telefon" />
        <label className="s-flabel">WhatsApp hattı</label>
        <input className={`s-input tabular ${hata && hata.whatsapp ? 'err' : ''}`} inputMode="tel" value={f.whatsapp} onChange={d('whatsapp')} placeholder="Boş bırakılabilir" />
        <Err k="whatsapp" />
        <label className="s-flabel">Adres</label>
        <textarea className="s-textarea" value={f.adres} onChange={d('adres')} rows={2} placeholder="Dükkân adresi (fişte görünür)" />

        <div className="gs-baslik">Vergi</div>
        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ flex: 1 }}>
            <label className="s-flabel">Vergi dairesi</label>
            <input className="s-input" value={f.vergiDairesi} onChange={d('vergiDairesi')} placeholder="Ör. Muratpaşa" />
          </div>
          <div style={{ flex: 1 }}>
            <label className="s-flabel">Vergi no</label>
            <input className={`s-input tabular ${hata && hata.vergiNo ? 'err' : ''}`} inputMode="numeric" value={f.vergiNo} onChange={d('vergiNo')} placeholder="10-11 rakam" />
          </div>
        </div>
        <Err k="vergiNo" />

        <div className="gs-baslik">Çalışma Saatleri</div>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <input className={`s-input tabular ${hata && hata.saat ? 'err' : ''}`} style={{ flex: 1, textAlign: 'center' }} value={f.acilis} onChange={d('acilis')} placeholder="08:00" />
          <span style={{ color: 'var(--muted)', fontWeight: 700 }}>—</span>
          <input className={`s-input tabular ${hata && hata.saat ? 'err' : ''}`} style={{ flex: 1, textAlign: 'center' }} value={f.kapanis} onChange={d('kapanis')} placeholder="19:00" />
        </div>
        <Err k="saat" />
        <div className="ym-err" style={{ marginTop: 6 }}><Icon name="info" size={13} sw={2.2} color="var(--muted)" /><span style={{ color: 'var(--muted)' }}>Saat dışında gelen çağrılar yine kaydedilir, bildirim sessiz kalır.</span></div>

        <div className="gs-baslik">Fiş Alt Notu</div>
        <textarea className="s-textarea" value={f.fisNotu} onChange={d('fisNotu')} rows={2} placeholder="Ör. Bizi tercih ettiğiniz için teşekkürler." />

        <button className="btn btn-p" style={{ margin: '18px 0 6px' }} onClick={kaydet}>Kaydet</button>
      </div>
    </div>
  );
}

Object.assign(window, { IsletmeProfil });
