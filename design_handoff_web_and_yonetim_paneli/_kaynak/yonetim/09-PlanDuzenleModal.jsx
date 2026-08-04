function PlanDuzenleModal({ plan, onKaydet, onKapat }) {
  const [d, setD] = React.useState(plan);
  const y = (k, v) => setD(p => ({ ...p, [k]: v }));
  return (
    <Modal baslik="Planı Düzenle" onKapat={onKapat}
      alt={<><button className="btn" onClick={onKapat}>Vazgeç</button><button className="btn birincil" disabled={!(+d.ucret > 0)} onClick={() => onKaydet({ ...d, ucret: +d.ucret, denemeGun: +d.denemeGun, hakAy: +d.hakAy, kurye: +d.kurye })}>Kaydet</button></>}>
      <Alan label="Plan adı"><input className="girdi" value={d.ad} onChange={(e) => y('ad', e.target.value)} /></Alan>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <Alan label="Aylık ücret (₺)"><input className="girdi tab" type="number" min="0" value={d.ucret} onChange={(e) => y('ucret', e.target.value)} /></Alan>
        <Alan label="Deneme süresi (gün)"><input className="girdi tab" type="number" min="0" value={d.denemeGun} onChange={(e) => y('denemeGun', e.target.value)} /></Alan>
        <Alan label="Aylık oto-sıralama hakkı"><input className="girdi tab" type="number" min="0" value={d.hakAy} onChange={(e) => y('hakAy', e.target.value)} /></Alan>
        <Alan label="Kurye hesabı"><input className="girdi tab" type="number" min="0" value={d.kurye} onChange={(e) => y('kurye', e.target.value)} /></Alan>
      </div>
      <div className="modal-bilgi"><Ikon ad="bilgi" boy={15} /><span>Yeni ücret bundan sonra girilecek ödemelerde varsayılan olur; geçmiş kayıtlar değişmez.</span></div>
    </Modal>
  );
}

function EkPaketModal({ paket, onKaydet, onKapat }) {
  const [d, setD] = React.useState(paket || { tur: 'hak', ad: '', adet: '', ucret: '', aktif: true });
  const y = (k, v) => setD(p => ({ ...p, [k]: v }));
  const kapsamL = d.tur === 'hak' ? 'Hak adedi' : 'Kurye hesabı adedi';
  return (
    <Modal baslik={paket ? 'Paketi Düzenle' : 'Ek Paket Ekle'} onKapat={onKapat}
      alt={<><button className="btn" onClick={onKapat}>Vazgeç</button>
        <button className="btn birincil" disabled={!d.ad.trim() || !(+d.adet > 0) || !(+d.ucret >= 0)} onClick={() => onKaydet({ ...d, ad: d.ad.trim(), adet: +d.adet, ucret: +d.ucret })}>Kaydet</button></>}>
      <Alan label="Paket türü"><Radyolar secenekler={['hak', 'kurye']} deger={d.tur} onSec={(v) => y('tur', v)} /></Alan>
      <Alan label="Paket adı"><input className="girdi" value={d.ad} onChange={(e) => y('ad', e.target.value)} placeholder={d.tur === 'hak' ? 'örn. 100 oto-sıralama hakkı' : 'örn. +1 kurye hesabı'} /></Alan>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <Alan label={kapsamL}><input className="girdi tab" type="number" min="1" value={d.adet} onChange={(e) => y('adet', e.target.value)} /></Alan>
        <Alan label="Ücret (₺)"><input className="girdi tab" type="number" min="0" value={d.ucret} onChange={(e) => y('ucret', e.target.value)} /></Alan>
      </div>
      <Alan label="Satışta"><Radyolar secenekler={['Aktif', 'Pasif']} deger={d.aktif ? 'Aktif' : 'Pasif'} onSec={(v) => y('aktif', v === 'Aktif')} /></Alan>
    </Modal>
  );
}

function TanimlaModal({ paketler, firmalar, sabitFirma, plan, onKaydet, onKapat }) {
  const aktifler = paketler.filter(p => p.aktif);
  const [firma, setFirma] = React.useState(sabitFirma || null);
  const [paketId, setPaketId] = React.useState(aktifler[0] ? aktifler[0].id : '');
  const [tarih, setTarih] = React.useState(isoBugun);
  const [tahsil, setTahsil] = React.useState('IBAN');
  const [not, setNot] = React.useState('');
  const paket = paketler.find(p => p.id === paketId);
  const [tutar, setTutar] = React.useState(paket ? paket.ucret : 0);
  const paketSec = (id) => { setPaketId(id); const p = paketler.find(x => x.id === id); if (p) setTutar(tahsil === 'Bedelsiz' ? 0 : p.ucret); };
  React.useEffect(() => { if (tahsil === 'Bedelsiz') setTutar(0); else if (paket) setTutar(paket.ucret); }, [tahsil]);
  return (
    <Modal baslik="Ek Paket Tanımla" onKapat={onKapat}
      alt={<><button className="btn" onClick={onKapat}>Vazgeç</button>
        <button className="btn birincil" disabled={!firma || !paket} onClick={() => onKaydet({ firmaId: firma.id, paketId, adet: paket.adet, tarih, tutar: tahsil === 'Bedelsiz' ? 0 : +tutar, tahsil, not: not.trim() })}>Tanımla</button></>}>
      <Alan label="Firma">{sabitFirma ? <input className="girdi" value={sabitFirma.ad} disabled /> : <FirmaCombo firmalar={firmalar} secili={firma} onSec={setFirma} />}</Alan>
      <Alan label="Paket">
        <select className="girdi" value={paketId} onChange={(e) => paketSec(e.target.value)}>
          {aktifler.map(p => <option key={p.id} value={p.id}>{p.ad} — {para(p.ucret)}</option>)}
        </select>
      </Alan>
      <Alan label="Tahsilat"><Radyolar secenekler={TAHSIL_YOLLARI} deger={tahsil} onSec={setTahsil} /></Alan>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <Alan label="Tutar (₺)"><input className="girdi tab" type="number" min="0" value={tutar} disabled={tahsil === 'Bedelsiz'} onChange={(e) => setTutar(e.target.value)} /></Alan>
        <Alan label="Tarih"><input className="girdi tab" type="date" value={tarih} onChange={(e) => setTarih(e.target.value)} /></Alan>
      </div>
      <Alan label="Not (isteğe bağlı)"><input className="girdi" value={not} onChange={(e) => setNot(e.target.value)} placeholder="örn. Üçüncü kuryesini işe aldı" /></Alan>
      <div className="modal-bilgi"><Ikon ad="bilgi" boy={15} /><span>{paket && (paket.tur === 'hak'
        ? `Firmanın hesabına ${paket.adet} oto-sıralama hakkı eklenir. `
        : `Firma ${paket.adet} kurye hesabı daha açabilir hâle gelir. `)}
        {tahsil === 'Bedelsiz' ? 'Bedelsiz tanımlandığı için gelir kaydı oluşmaz.' : 'Tutar ödemeler listesine ve aylık gelire eklenir; abonelik bitişi değişmez.'}</span></div>
    </Modal>
  );
}

function Paketler({ plan, paketler, tanimlamalar, firmalar, planKaydet, paketKaydet, paketSil, tanimlaAc, uyeAc }) {
  const [planModal, setPlanModal] = React.useState(false);
  const [paketModal, setPaketModal] = React.useState(null); // {paket} | {yeni:true}
  const firmaAd = (id) => (firmalar.find(f => f.id === id) || {}).ad || '?';
  const paketAd = (id) => (paketler.find(p => p.id === id) || {}).ad || 'Silinmiş paket';
  const son = [...tanimlamalar].sort((a,b) => b.tarih.localeCompare(a.tarih));
  return (
    <div className="yg-ic">
      <div className="ust">
        <div><h1>Paketler</h1><div className="ust-alt">Abonelik planı, ek paketler ve firmalara tanımlamalar</div></div>
        <div className="ust-sag"><button className="btn birincil" onClick={() => tanimlaAc(null)}><Ikon ad="arti" boy={15} /> Ek Paket Tanımla</button></div>
      </div>
      <div className="kart" style={{ marginBottom: 12 }}>
        <div className="kart-baslik">Abonelik Planı<span className="adet">tek plan</span></div>
        <div className="bilgi-satirlar">
          <div className="bilgi-satir"><span className="k">Plan adı</span><span className="v">{plan.ad}</span></div>
          <div className="bilgi-satir"><span className="k">Aylık ücret</span><span className="v tab">{para(plan.ucret)}</span></div>
          <div className="bilgi-satir"><span className="k">Deneme süresi</span><span className="v tab">{plan.denemeGun} gün</span></div>
          <div className="bilgi-satir"><span className="k">Aylık oto-sıralama hakkı</span><span className="v tab">{plan.hakAy}</span></div>
          <div className="bilgi-satir"><span className="k">Kurye hesabı</span><span className="v tab">{plan.kurye}</span></div>
        </div>
        <div className="aksiyonlar"><button className="btn" onClick={() => setPlanModal(true)}>Planı Düzenle</button></div>
      </div>
      <div className="kart" style={{ marginBottom: 12 }}>
        <div className="kart-baslik">Ek Paketler<span className="adet">{paketler.filter(p => p.aktif).length} aktif</span></div>
        {paketler.length === 0 ? <Bos metin="Henüz ek paket tanımlı değil." /> : (
          <table className="tablo">
            <thead><tr><th>Paket</th><th>Tür</th><th className="sag">Kapsam</th><th className="sag">Ücret</th><th>Durum</th><th className="sag">İşlem</th></tr></thead>
            <tbody>{paketler.map(p => (
              <tr key={p.id}>
                <td className="kalin">{p.ad}</td>
                <td>{p.tur === 'hak' ? 'Oto-sıralama' : 'Ek kurye'}</td>
                <td className="sag tab">{p.tur === 'hak' ? p.adet + ' hak' : p.adet + ' hesap'}</td>
                <td className="sag kalin tab">{para(p.ucret)}</td>
                <td><span className={'rozet ' + (p.aktif ? 'aktif' : 'iptal')}>{p.aktif ? 'Satışta' : 'Pasif'}</span></td>
                <td className="sag"><button className="link-btn" onClick={() => setPaketModal({ paket: p })}>Düzenle</button></td>
              </tr>))}
            </tbody>
          </table>
        )}
        <div className="aksiyonlar"><button className="btn" onClick={() => setPaketModal({ yeni: true })}><Ikon ad="arti" boy={15} /> Ek Paket Ekle</button></div>
      </div>
      <div className="kart">
        <div className="kart-baslik">Son Tanımlamalar<span className="adet">{son.length} kayıt</span></div>
        {son.length === 0 ? <Bos metin="Henüz firmalara ek paket tanımlanmadı." /> : (
          <table className="tablo">
            <thead><tr><th>Tarih</th><th>Firma</th><th>Paket</th><th className="sag">Tutar</th><th>Tahsilat</th><th>Not</th></tr></thead>
            <tbody>{son.map(t => (
              <tr key={t.id}>
                <td className="tab" style={{ whiteSpace: 'nowrap' }}>{tarihK(t.tarih)}</td>
                <td><button className="link-btn" style={{ color: 'var(--ink)', fontWeight: 600 }} onClick={() => uyeAc(t.firmaId)}>{firmaAd(t.firmaId)}</button></td>
                <td>{paketAd(t.paketId)}</td>
                <td className="sag kalin tab">{t.tahsil === 'Bedelsiz' ? <span className="soluk">—</span> : para(t.tutar)}</td>
                <td>{t.tahsil}</td>
                <td className="soluk">{t.not || '—'}</td>
              </tr>))}
            </tbody>
          </table>
        )}
      </div>
      {planModal && <PlanDuzenleModal plan={plan} onKapat={() => setPlanModal(false)} onKaydet={(p) => { planKaydet(p); setPlanModal(false); }} />}
      {paketModal && <EkPaketModal paket={paketModal.paket} onKapat={() => setPaketModal(null)} onKaydet={(p) => { paketKaydet(p, paketModal.paket); setPaketModal(null); }} />}
    </div>
  );
}
Object.assign(window, { Paketler, PlanDuzenleModal, EkPaketModal, TanimlaModal });
