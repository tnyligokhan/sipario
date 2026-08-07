// s-urunler.jsx — Ürünler listesi + ekle/düzenle (birim serbest metin, aktif/pasif, silme yok). → window

function UrunlerEkran({ urunler, onGeri, onKaydet, onPing }) {
  const [duz, setDuz] = React.useState(null); // {id?,ad,fiyat,birim,aktif}
  const [ad, setAd] = React.useState(''); const [fiyat, setFiyat] = React.useState(''); const [birim, setBirim] = React.useState('adet'); const [aktif, setAktif] = React.useState(true);
  const [gorsel, setGorsel] = React.useState(null);
  const [barkod, setBarkod] = React.useState('');
  const dosyaRef = React.useRef(null);
  const [hata, setHata] = React.useState(null);

  const ac = (u) => { setDuz(u || { id: null }); setAd(u ? u.ad : ''); setFiyat(u ? String(Math.round(u.fiyat / 100)) : ''); setBirim(u ? u.birim : 'adet'); setAktif(u ? u.aktif : true); setGorsel(u ? u.gorsel : null); setBarkod(u && u.barkod ? u.barkod : ''); setHata(null); };
  const dosyaSec = (e) => { const f = e.target.files && e.target.files[0]; if (!f) return; const r = new FileReader(); r.onload = () => setGorsel(r.result); r.readAsDataURL(f); e.target.value = ''; };
  const kaydet = () => {
    const h = {};
    if (ad.trim().length < 2) h.ad = 'Urün adı girin (en az 2 karakter)';
    else if (urunler.some((u) => u.id !== duz.id && u.ad.toLocaleLowerCase('tr') === ad.trim().toLocaleLowerCase('tr'))) h.ad = 'Bu adla kayıtlı ürün zaten var';
    if (!fiyat || Number(fiyat) <= 0) h.fiyat = 'Fiyat 0’dan büyük olmalı';
    const bk = barkod.trim();
    if (bk && bk.length < 8) h.barkod = 'Barkod en az 8 hane olmalı';
    else if (bk && urunler.some((u) => u.id !== duz.id && u.barkod === bk)) h.barkod = 'Bu barkod başka üründe kayıtlı';
    if (Object.keys(h).length) { setHata(h); return; }
    onKaydet({ id: duz.id, ad: ad.trim(), fiyat: Number(fiyat) * 100, birim: birim.trim() || 'adet', aktif, gorsel, barkod: barkod.trim() || null }); setDuz(null);
  };

  return (
    <div className="ekran">
      <Ust baslik="Ürünler" alt={`${urunler.filter((u) => u.aktif).length} aktif · ${urunler.length} toplam`} onGeri={onGeri} />
      <div className="ekran-govde">
        <button className="ys-ekle" onClick={() => ac(null)}><Icon name="plus" size={20} sw={2.3} color="var(--accent)" />Yeni ürün ekle</button>
        <div className="uliste">
          {urunler.map((u) => (
            <button key={u.id} className={`urow ${u.aktif ? '' : 'pasif'}`} onClick={() => ac(u)}>
              <UrunGorsel u={u} cls="urow-thumb" />
              <span className="urow-mid">
                <span className="urow-nm">{u.ad}{!u.aktif && <span className="urow-pasif">Pasif</span>}</span>
                <span className="urow-birim">{u.birim}{u.barkod && <span className="urow-bk tabular"> · {u.barkod}</span>}</span>
              </span>
              <span className="urow-fiyat tabular">{fmtTL(u.fiyat)}</span>
              <Icon name="chevR" size={18} sw={2} color="var(--line-2)" />
            </button>
          ))}
        </div>
      </div>

      <Sheet open={!!duz} onClose={() => setDuz(null)} baslik={duz && duz.id ? 'Ürünü Düzenle' : 'Yeni Ürün'}>
        <div className="sb-form">
          <label className="s-flabel">Ürün görseli</label>
          <div className="uf-gorsel">
            {gorsel ? <img className="uf-gorsel-img" src={gorsel} alt="" /> : <span className="uf-gorsel-img ph">{(ad.trim().charAt(0) || '+').toLocaleUpperCase('tr')}</span>}
            <div className="uf-gorsel-mid">
              <span className="uf-gorsel-not">{gorsel ? 'Görsel yüklendi' : 'POS katalogda karo üzerinde görünür'}</span>
              <div className="uf-gorsel-btns">
                <button type="button" className="ust-metin" onClick={() => dosyaRef.current && dosyaRef.current.click()}>{gorsel ? 'Değiştir' : 'Görsel Ekle'}</button>
                {gorsel && <button type="button" className="ust-metin" style={{ color: 'var(--danger)' }} onClick={() => setGorsel(null)}>Kaldır</button>}
              </div>
            </div>
            <input ref={dosyaRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={dosyaSec} />
          </div>
          <label className="s-flabel">Ürün adı</label>
          <input className={`s-input ${hata && hata.ad ? 'err' : ''}`} value={ad} onChange={(e) => { setAd(e.target.value); setHata(null); }} placeholder="Ör. Damacana 19 L" autoFocus />
          {hata && hata.ad && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.ad}</div>}
          <div style={{ display: 'flex', gap: 12 }}>
            <div style={{ flex: 1 }}>
              <label className="s-flabel">Birim fiyat (₺)</label>
              <input className={`s-input tabular ${hata && hata.fiyat ? 'err' : ''}`} inputMode="numeric" value={fiyat} onChange={(e) => { setFiyat(e.target.value.replace(/\D/g, '')); setHata(null); }} placeholder="0" />
            </div>
            <div style={{ flex: 1 }}>
              <label className="s-flabel">Birim</label>
              <input className="s-input" value={birim} onChange={(e) => setBirim(e.target.value)} placeholder="adet / kg / koli…" />
            </div>
          </div>
          {hata && hata.fiyat && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.fiyat}</div>}
          <label className="s-flabel">Barkod <span style={{ textTransform: 'none', letterSpacing: 0 }}>· opsiyonel</span></label>
          <div className="sdx-sb">
            <input className={`s-input tabular ${hata && hata.barkod ? 'err' : ''}`} style={{ flex: 1 }} inputMode="numeric" value={barkod} onChange={(e) => { setBarkod(e.target.value.replace(/\D/g, '')); setHata(null); }} placeholder="Barkodu yazın ya da okutun" />
            <button type="button" className="pos-barkod" onClick={() => { const d = urunler.find((x) => x.id !== duz.id && x.barkod); onPing && onPing('Okuyucu simülasyonu: alan klavye girişini bekliyor'); }} aria-label="Okuyucu"><Icon name="barkod" size={20} sw={2} color="var(--accent)" /></button>
          </div>
          {hata && hata.barkod && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{hata.barkod}</div>}
          <div className="silme-notu" style={{ textAlign: 'left', marginTop: 6 }}>Barkodsuz ürünler katalogda aramayla seçilir; barkodlular POS'ta okutarak eklenir.</div>
          <button className={`aktif-toggle ${aktif ? 'on' : ''}`} onClick={() => setAktif((v) => !v)}>
            <span className="aktif-knob" />
            <span>{aktif ? 'Aktif — siparişte görünür' : 'Pasif — siparişte gizli'}</span>
          </button>
          <button className="btn btn-p" style={{ marginTop: 16 }} onClick={kaydet}>Kaydet</button>
          {duz && duz.id && <div className="silme-notu">Ürünler silinmez; kullanılmayanı Pasif yap.</div>}
        </div>
      </Sheet>
    </div>
  );
}

Object.assign(window, { UrunlerEkran });
