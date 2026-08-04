function Uyeler({ firmalar, odemeler, uyeAc }) {
  const [arama, setArama] = React.useState('');
  const [filtre, setFiltre] = React.useState('tumu');
  const FILTRELER = [['tumu','Tümü'],['deneme','Deneme'],['aktif','Aktif'],['askida','Askıda'],['iptal','İptal']];
  const liste = firmalar
    .filter(f => filtre === 'tumu' || f.durum === filtre)
    .filter(f => (f.ad + ' ' + f.yetkili + ' ' + f.il).toLocaleLowerCase('tr').includes(arama.toLocaleLowerCase('tr')))
    .sort((a,b) => a.ad.localeCompare(b.ad, 'tr'));
  return (
    <div className="yg-ic">
      <div className="ust">
        <div><h1>Üyeler</h1><div className="ust-alt">{firmalar.length} kayıtlı firma</div></div>
        <div className="ust-sag"><AraKutusu deger={arama} onDegis={setArama} yertut="Firma, yetkili veya il ara…" /></div>
      </div>
      <div className="cipler" style={{ marginBottom: 14 }}>
        {FILTRELER.map(([k, ad]) => <button key={k} className={'cip' + (filtre === k ? ' secili' : '')} onClick={() => setFiltre(k)}>{ad}</button>)}
      </div>
      <div className="kart">
        {liste.length === 0 ? <Bos ikon="ara" metin={arama ? 'Aramanla eşleşen üye yok.' : 'Bu durumda üye yok.'} /> : (
          <table className="tablo">
            <thead><tr><th>Firma</th><th>Telefon</th><th>Durum</th><th>Bitiş</th><th>Son Ödeme</th><th className="sag">İşlem</th></tr></thead>
            <tbody>
              {liste.map(f => { const so = sonOdemeBul(odemeler, f.id); return (
                <tr key={f.id} className="satir-tik" onClick={() => uyeAc(f.id)}>
                  <td><div className="kalin">{f.ad}</div><div className="soluk" style={{ fontSize: 12.5 }}>{f.il} / {f.ilce}</div></td>
                  <td className="tab">{f.tel}</td>
                  <td><Rozet durum={f.durum} /></td>
                  <td className="tab">{tarihK(f.bitis)}</td>
                  <td className="tab">{so ? tarihK(so) : <span className="soluk">—</span>}</td>
                  <td className="sag"><button className="link-btn" onClick={(e) => { e.stopPropagation(); uyeAc(f.id); }}>Detay</button></td>
                </tr>); })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

function DenemeUzatModal({ firma, onKaydet, onKapat }) {
  const [gun, setGun] = React.useState(7);
  const [ozel, setOzel] = React.useState('');
  const yeni = ozel || gunEkle(firma.bitis, gun);
  return (
    <Modal baslik={'Denemeyi Uzat — ' + firma.ad} onKapat={onKapat}
      alt={<><button className="btn" onClick={onKapat}>Vazgeç</button><button className="btn birincil" onClick={() => onKaydet(yeni)}>Kaydet</button></>}>
      <Alan label="Hızlı seçim">
        <div className="hizli-gunler">{[7,15,30].map(g => (
          <button key={g} type="button" className={'radyo' + (!ozel && gun === g ? ' secili' : '')} style={{ flex: 1 }} onClick={() => { setGun(g); setOzel(''); }}>+{g} gün</button>))}
        </div>
      </Alan>
      <Alan label="veya özel tarih"><input className="girdi" type="date" value={ozel} min={isoBugun} onChange={(e) => setOzel(e.target.value)} /></Alan>
      <div className="uzat-onizleme">Yeni deneme bitişi: <b>{tarihK(yeni)}</b></div>
    </Modal>
  );
}

function UyeDetay({ firma, odemeler, plan, paketler, tanimlamalar, geri, odemeEkleAc, tanimlaAc, denemeUzat, durumDegistir, notEkle }) {
  const [uzatAcik, setUzatAcik] = React.useState(false);
  const [notMetin, setNotMetin] = React.useState('');
  const gecmis = odemeler.filter(o => o.firmaId === firma.id).sort((a,b) => b.tarih.localeCompare(a.tarih));
  const tanim = tanimlamalar.filter(t => t.firmaId === firma.id).sort((a,b) => b.tarih.localeCompare(a.tarih));
  const paketBul = (id) => paketler.find(p => p.id === id) || {};
  const ekHak = tanim.reduce((t,x) => t + (paketBul(x.paketId).tur === 'hak' ? x.adet : 0), 0);
  const ekKurye = tanim.reduce((t,x) => t + (paketBul(x.paketId).tur === 'kurye' ? x.adet : 0), 0);
  const kalan = gunFarki(firma.bitis);
  const bitisEtiket = firma.durum === 'deneme' ? 'Deneme bitişi' : 'Abonelik bitişi';
  return (
    <div className="yg-ic">
      <button className="geri" onClick={geri}><Ikon ad="geri" boy={15} /> Üyeler</button>
      <div className="ust" style={{ marginBottom: 16 }}>
        <div><h1>{firma.ad}</h1><div className="ust-alt">{firma.il} / {firma.ilce} · kayıt {tarihK(firma.kayit)}</div></div>
        <div className="ust-sag"><Rozet durum={firma.durum} /></div>
      </div>
      <div className="detay-yerlesim">
        <div className="dikey">
          <div className="kart">
            <div className="kart-baslik">Firma Bilgileri</div>
            <div className="bilgi-satirlar">
              <div className="bilgi-satir"><span className="k">Firma adı</span><span className="v">{firma.ad}</span></div>
              <div className="bilgi-satir"><span className="k">Yetkili</span><span className="v">{firma.yetkili}</span></div>
              <div className="bilgi-satir"><span className="k">Telefon</span><span className="v tab">{firma.tel}</span></div>
              <div className="bilgi-satir"><span className="k">İl / İlçe</span><span className="v">{firma.il} / {firma.ilce}</span></div>
              <div className="bilgi-satir"><span className="k">Kayıt tarihi</span><span className="v tab">{tarihK(firma.kayit)}</span></div>
            </div>
          </div>
          <div className="kart">
            <div className="kart-baslik">Abonelik</div>
            <div className="bilgi-satirlar">
              <div className="bilgi-satir"><span className="k">Durum</span><span className="v"><Rozet durum={firma.durum} /></span></div>
              <div className="bilgi-satir"><span className="k">Plan</span><span className="v">{plan.ad} — {para(plan.ucret)}/ay</span></div>
              <div className="bilgi-satir"><span className="k">{bitisEtiket}</span>
                <span className="v tab">{tarihK(firma.bitis)}{firma.durum !== 'iptal' && <span style={{ color: kalan < 0 ? 'var(--danger)' : 'var(--muted)', fontWeight: 500, marginLeft: 6 }}>({kalan < 0 ? -kalan + ' gün gecikti' : kalan + ' gün kaldı'})</span>}</span></div>
            </div>
            <div className="aksiyonlar">
              {firma.durum === 'deneme' && <button className="btn" onClick={() => setUzatAcik(true)}>Denemeyi Uzat</button>}
              <button className="btn birincil" onClick={() => odemeEkleAc(firma)}><Ikon ad="arti" boy={15} /> Ödeme Ekle</button>
              {(firma.durum === 'aktif' || firma.durum === 'deneme') && <button className="btn tehlike" onClick={() => durumDegistir(firma.id, 'askida')}>Askıya Al</button>}
              {firma.durum === 'askida' && <button className="btn" onClick={() => durumDegistir(firma.id, 'aktif')}>Aktifleştir</button>}
            </div>
          </div>
          <div className="kart">
            <div className="kart-baslik">Ek Paketler<span className="adet">{tanim.length} tanımlama</span></div>
            <div className="bilgi-satirlar">
              <div className="bilgi-satir"><span className="k">Oto-sıralama hakkı</span><span className="v tab">{plan.hakAy}/ay{ekHak > 0 && <span style={{ color: 'var(--accent)' }}> + {ekHak} ek</span>}</span></div>
              <div className="bilgi-satir"><span className="k">Kurye hesabı</span><span className="v tab">{plan.kurye}{ekKurye > 0 && <span style={{ color: 'var(--accent)' }}> + {ekKurye} ek</span>}</span></div>
            </div>
            {tanim.length > 0 && (
              <table className="tablo"><tbody>{tanim.map(t => (
                <tr key={t.id}>
                  <td><div className="kalin">{paketBul(t.paketId).ad || 'Silinmiş paket'}</div>{t.not && <div className="soluk" style={{ fontSize: 12.5 }}>{t.not}</div>}</td>
                  <td className="soluk tab" style={{ whiteSpace: 'nowrap' }}>{tarihK(t.tarih)}</td>
                  <td className="sag kalin tab">{t.tahsil === 'Bedelsiz' ? <span className="soluk">Bedelsiz</span> : para(t.tutar)}</td>
                </tr>))}
              </tbody></table>
            )}
            <div className="aksiyonlar"><button className="btn" onClick={() => tanimlaAc(firma)}><Ikon ad="arti" boy={15} /> Ek Paket Tanımla</button></div>
          </div>
        </div>
        <div className="dikey">
          <div className="kart">
            <div className="kart-baslik">Ödeme Geçmişi<span className="adet">{gecmis.length} kayıt</span></div>
            {gecmis.length === 0 ? <Bos metin="Henüz ödeme kaydı yok." /> : (
              <table className="tablo">
                <thead><tr><th>Tarih</th><th className="sag">Tutar</th><th>Yöntem</th><th>Dönem</th><th>Not</th></tr></thead>
                <tbody>{gecmis.map(o => (
                  <tr key={o.id}><td className="tab">{tarihK(o.tarih)}</td><td className="sag kalin tab">{para(o.tutar)}</td><td>{o.yontem}</td><td>{o.donem}</td><td className="soluk">{o.not || '—'}</td></tr>))}
                </tbody>
              </table>
            )}
          </div>
          <div className="kart">
            <div className="kart-baslik">Notlar</div>
            {firma.notlar.length === 0 ? <Bos metin="Henüz not yok." /> : (
              <div className="not-liste">{[...firma.notlar].reverse().map((n, i) => (
                <div key={i} className="not-satir"><div className="not-tarih tab">{tarihK(n.t)}</div><div className="not-metin">{n.m}</div></div>))}
              </div>
            )}
            <div className="not-form">
              <textarea className="girdi" rows="2" placeholder='örn. "Telefonla arandı, haftaya ödeyecek."' value={notMetin} onChange={(e) => setNotMetin(e.target.value)}></textarea>
              <button className="btn" disabled={!notMetin.trim()} onClick={() => { notEkle(firma.id, notMetin.trim()); setNotMetin(''); }}>Not Ekle</button>
            </div>
          </div>
        </div>
      </div>
      {uzatAcik && <DenemeUzatModal firma={firma} onKapat={() => setUzatAcik(false)} onKaydet={(t) => { denemeUzat(firma.id, t); setUzatAcik(false); }} />}
    </div>
  );
}
Object.assign(window, { Uyeler, UyeDetay, DenemeUzatModal });
