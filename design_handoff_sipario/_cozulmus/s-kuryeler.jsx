// s-kuryeler.jsx — Kurye ayarları: liste + ekle/düzenle (ad, telefon, aktif). → window

function KuryelerEkran({ kuryeler, onGeri, onKaydet }) {
  const [duz, setDuz] = React.useState(null);
  const [ad, setAd] = React.useState(''); const [tel, setTel] = React.useState(''); const [aktif, setAktif] = React.useState(true);
  const [hata, setHata] = React.useState(null);
  const ac = (k) => { setDuz(k || { id: null }); setAd(k ? k.ad : ''); setTel(k ? k.tel : ''); setAktif(k ? k.aktif : true); setHata(null); };
  const kaydet = () => {
    const h = {};
    if (ad.trim().length < 2) h.ad = 'Kurye adı girin (en az 2 karakter)';
    else if (kuryeler.some((k) => k.id !== duz.id && k.ad.toLocaleLowerCase('tr') === ad.trim().toLocaleLowerCase('tr'))) h.ad = 'Bu adla kayıtlı kurye zaten var';
    const hane = tel.replace(/\D/g, '');
    if (tel.trim() && (hane.length < 10 || hane.length > 11)) h.tel = 'Geçerli telefon girin (10-11 hane) ya da boş bırakın';
    if (duz.id && !aktif && !kuryeler.some((k) => k.id !== duz.id && k.aktif)) h.aktif = 'Son aktif kurye pasif yapılamaz — sipariş atanacak kimse kalmaz';
    if (Object.keys(h).length) { setHata(h); return; }
    onKaydet({ id: duz.id, ad: ad.trim(), tel: tel.trim(), aktif }); setDuz(null);
  };

  return (
    <div className="ekran">
      <Ust baslik="Kuryeler" alt={`${kuryeler.filter((k) => k.aktif).length} aktif · ${kuryeler.length} kayıtlı`} onGeri={onGeri} />
      <div className="ekran-govde">
        <button className="ys-ekle" onClick={() => ac(null)}><Icon name="plus" size={20} sw={2.3} color="var(--accent)" />Yeni kurye ekle</button>
        <div className="uliste" style={{ marginTop: 10 }}>
          {kuryeler.map((k) => (
            <button key={k.id} className={`urow ${k.aktif ? '' : 'pasif'}`} onClick={() => ac(k)}>
              <span className="krow-ic"><Icon name="truck" size={18} sw={1.9} color="var(--accent)" /></span>
              <span className="urow-mid">
                <span className="urow-nm">{k.ad}{!k.aktif && <span className="urow-pasif">Pasif</span>}</span>
                <span className="urow-birim tabular">{k.tel || 'Telefon yok'}</span>
              </span>
              <Icon name="chevR" size={18} sw={2} color="var(--line-2)" />
            </button>
          ))}
        </div>
      </div>

      <Sheet open={!!duz} onClose={() => setDuz(null)} baslik={duz && duz.id ? 'Kuryeyi Düzenle' : 'Yeni Kurye'}>
        <div className="sb-form">
          <label className="s-flabel">Ad</label>
          <input className={`s-input ${hata && hata.ad ? 'err' : ''}`} value={ad} onChange={(e) => { setAd(e.target.value); setHata(null); }} placeholder="Ör. Emre" autoFocus />
          {hata && hata.ad && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.ad}</div>}
          <label className="s-flabel">Telefon</label>
          <input className={`s-input tabular ${hata && hata.tel ? 'err' : ''}`} inputMode="tel" value={tel} onChange={(e) => { setTel(e.target.value); setHata(null); }} placeholder="05XX XXX XX XX" />
          {hata && hata.tel && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.tel}</div>}
          <button className={`aktif-toggle ${aktif ? 'on' : ''}`} onClick={() => { setAktif((v) => !v); setHata(null); }}>
            <span className="aktif-knob" />
            <span>{aktif ? 'Aktif — sipariş atanabilir' : 'Pasif — atama kapalı'}</span>
          </button>
          {hata && hata.aktif && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.aktif}</div>}
          <button className="btn btn-p" style={{ marginTop: 16 }} onClick={kaydet}>Kaydet</button>
        </div>
      </Sheet>
    </div>
  );
}

Object.assign(window, { KuryelerEkran });
