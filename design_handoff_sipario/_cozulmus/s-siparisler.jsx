// s-siparisler.jsx — Siparişler listesi + Yeni sipariş + Sipariş detayı/teslim. → window

function musteriKod(id) { return id ? 'M-' + String(id).replace(/\D/g, '').padStart(3, '0') : null; }

function SiparisSatir({ o, onAc, onPing, elle, onKuryeAc, onGrip, dragging, innerRef }) {
  const m = o.musteriId ? musteriGetir(o.musteriId) : null;
  const adres = m ? birincilAdres(m) : null;
  const tel = m ? birincilTel(m) : '';
  const act = (e, msg) => { e.stopPropagation(); onPing && onPing(msg); };
  return (
    <div ref={innerRef} className={`srow ${elle ? 'elle' : ''} ${dragging ? 'dragging' : ''}`} onClick={() => !elle && onAc(o)} role="button" tabIndex={0}>
      <div className="srow-head">
        <div className="srow-ust">
          {elle &&
          <span className="srow-grip" onPointerDown={(e) => onGrip(e, o)} aria-label="Sürükleyerek taşı">
            <Icon name="grip" size={18} sw={2.6} color={dragging ? 'var(--accent)' : 'var(--muted)'} />
          </span>}
          {o.musteriId && <span className="srow-kod tabular">{musteriKod(o.musteriId)}</span>}
          <span className="srow-nm">{o.musteriAd}</span>
          <span className="srow-amt tabular">{fmtTL(siparisTutar(o))}</span>
        </div>
        <div className="srow-alt">
          <DurumPili durum={o.durum} />
          <button className="srow-kurye" onClick={(e) => { e.stopPropagation(); if (o.durum === 'acik') onKuryeAc(o); else onPing && onPing('Kapalı siparişte kurye değiştirilemez'); }}><Icon name="truck" size={13} sw={2.2} color="currentColor" />{o.kurye}{o.odeme && <span className="srow-odeme">· {ODEME_TIPLERI[o.odeme].label}</span>}{o.durum === 'acik' && <Icon name="down" size={12} sw={2.4} color="var(--muted)" />}</button>
          <span className="srow-saat tabular"><Icon name="clock" size={12} sw={2} color="var(--muted)" />{o.saat}</span>
        </div>
      </div>
      {adres && !elle && <div className="srow-adres"><Icon name="pin" size={14} sw={2.2} color="var(--accent)" /><span>{[adres.metin, adres.bolge].filter((x) => x && x !== '—').join(' — ')}</span></div>}
      <div className="srow-urunler">
        <div className="srow-uhead"><Icon name="box" size={14} sw={2.1} color="var(--accent)" /><span>Sipariş Kalemleri</span></div>
        {(o.satirlar || []).map((r, i) => <span key={i} className="srow-uitem"><i />{r.ad} ×{r.adet}</span>)}
        {(o.serbest || []).map((r, i) => <span key={'s' + i} className="srow-uitem"><i />{r.aciklama}</span>)}
      </div>
      {o.not && !elle && <div className="srow-not"><Icon name="edit" size={14} sw={2.1} color="var(--warn)" /><span><b>Sipariş Notu:</b> {o.not}</span></div>}
      {tel && o.durum === 'acik' && !elle &&
      <div className="srow-acts">
        <button onClick={(e) => act(e, `${o.musteriAd} aranıyor…`)}><Icon name="phone" size={15} sw={2.1} color="var(--accent)" />Ara</button>
        <button onClick={(e) => act(e, 'WhatsApp açılıyor…')}><Icon name="wa" size={15} sw={1.9} color="#1FA855" />WhatsApp</button>
        <button onClick={(e) => act(e, adres && adres.konum ? `Konum haritada açılıyor (${adres.konum.lat.toFixed(4)}, ${adres.konum.lng.toFixed(4)})…` : 'Konum kayıtlı değil — müşteri detayından alın')} className={adres && adres.konum ? 'konumlu' : 'konumsuz'}><Icon name="pin" size={15} sw={2.1} color={adres && adres.konum ? 'var(--ok)' : 'var(--muted)'} />Konum{adres && adres.konum && <Icon name="check" size={11} sw={3} color="var(--ok)" />}</button>
      </div>}
    </div>
  );
}

const SIRALA_SECENEK = [
  { k: 'saat', label: 'Saate göre (yeni üstte)' },
  { k: 'tutar', label: 'Tutara göre (büyük üstte)' },
  { k: 'ad', label: 'Müşteri adına göre (A→Z)' },
  { k: 'elle', label: 'Elle sırala (sürükle-bırak)' },
];

function SiparislerEkran({ siparisler, onAc, durum, rol, onMenu, onPing, onMove, kuryeAdlari, onKuryeDegis }) {
  const [filtre, setFiltre] = React.useState('acik');
  const [sirala, setSirala] = React.useState('saat');
  const [srAcik, setSrAcik] = React.useState(false);
  const [kuryeSec, setKuryeSec] = React.useState(null); // null | sipariş
  const elle = sirala === 'elle';
  const [dragId, setDragId] = React.useState(null);
  const dragRef = React.useRef(null);
  const rowRefs = React.useRef({});
  const grip = (e, o) => {
    e.preventDefault(); e.stopPropagation();
    dragRef.current = { id: o.id, last: null };
    setDragId(o.id);
  };
  React.useEffect(() => {
    if (!dragId) return;
    const move = (e) => {
      const d = dragRef.current; if (!d) return;
      const y = e.clientY;
      for (const [id, el] of Object.entries(rowRefs.current)) {
        if (!el || id === d.id) continue;
        const r = el.getBoundingClientRect();
        if (y > r.top && y < r.bottom) {
          if (d.last !== id) { d.last = id; onMove(d.id, id); }
          return;
        }
      }
      d.last = null;
    };
    const up = () => { dragRef.current = null; setDragId(null); };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
    window.addEventListener('pointercancel', up);
    return () => { window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up); window.removeEventListener('pointercancel', up); };
  }, [dragId, onMove]);
  const sekmeler = [
    { k: 'acik', label: 'Açık' },
    { k: 'teslim', label: 'Teslim' },
    { k: 'borclu', label: 'Borçlu' },
    { k: 'tum', label: 'Tümü' },
  ];
  let list = siparisler.filter((o) =>
    filtre === 'tum' ? true :
    filtre === 'borclu' ? (() => { const m = o.musteriId ? musteriGetir(o.musteriId) : null; return m && m.bakiye > 0; })() :
    o.durum === filtre);
  if (sirala === 'tutar') list = [...list].sort((a, b) => siparisTutar(b) - siparisTutar(a));
  else if (sirala === 'ad') list = [...list].sort((a, b) => a.musteriAd.localeCompare(b.musteriAd, 'tr'));

  return (
    <div className="ekran">
      <Ust baslik="Siparişler" alt={`Bugün ${siparisler.filter((o) => o.durum === 'acik').length} açık`} onMenu={onMenu}
        sag={elle
          ? <button className="ust-metin" onClick={() => setSirala('saat')}>Bitti</button>
          : <button className="ust-sirala" onClick={() => setSrAcik(true)}><Icon name="sirala" size={16} sw={2.1} color="var(--accent)" />Sırala</button>} />
      {elle && <div className="elle-bant"><Icon name="info" size={14} sw={2} color="var(--accent)" />Tutamaçtan sürükleyip bırak, bitince “Bitti”ye bas.</div>}
      <div className="segtab">
        {sekmeler.map((s) => (
          <button key={s.k} className={`segtab-b ${filtre === s.k ? 'on' : ''}`} onClick={() => setFiltre(s.k)}>{s.label}</button>
        ))}
      </div>
      <div className="ekran-govde">
        {durum === 'yukleniyor' ? <Iskelet /> :
         durum === 'hata' ? <HataEkran onTekrar={() => {}} /> :
         list.length === 0 ? (
           <BosDurum ikon="list" baslik="Sipariş yok" aciklama={filtre === 'acik' ? 'Açık sipariş yok. Yeni sipariş için + tuşuna bas.' : 'Bu filtrede sipariş bulunmuyor.'} />
         ) : (
           <div className="sliste">{list.map((o) => <SiparisSatir key={o.id} o={o} onAc={onAc} onPing={onPing} onKuryeAc={setKuryeSec}
             elle={elle} dragging={dragId === o.id} onGrip={grip}
             innerRef={(el) => { if (el) rowRefs.current[o.id] = el; else delete rowRefs.current[o.id]; }} />)}</div>
         )}
      </div>

      <Sheet open={!!kuryeSec} onClose={() => setKuryeSec(null)} baslik={kuryeSec ? `Kurye Seç · ${kuryeSec.musteriAd}` : ''}>
        <div className="sr-list">
          {(kuryeAdlari || []).map((ad) => (
            <button key={ad} className={`sr-row ${kuryeSec && kuryeSec.kurye === ad ? 'on' : ''}`}
              onClick={() => { if (kuryeSec.kurye !== ad) { onKuryeDegis(kuryeSec.id, ad); onPing && onPing(`Kurye değiştirildi: ${ad}`); } setKuryeSec(null); }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 9 }}><Icon name="truck" size={16} sw={2} color="var(--muted)" />{ad}</span>
              {kuryeSec && kuryeSec.kurye === ad && <Icon name="check" size={17} sw={2.4} color="var(--accent)" />}
            </button>
          ))}
        </div>
      </Sheet>

      <Sheet open={srAcik} onClose={() => setSrAcik(false)} baslik="Sıralama">
        <div className="sr-list">
          {SIRALA_SECENEK.map((s) => (
            <button key={s.k} className={`sr-row ${sirala === s.k ? 'on' : ''}`} onClick={() => { setSirala(s.k); setSrAcik(false); if (s.k === 'elle') onPing && onPing('Elle sıralama açık — tutamaçtan sürükle'); }}>
              <span>{s.label}</span>
              {sirala === s.k && <Icon name="check" size={17} sw={2.4} color="var(--accent)" />}
            </button>
          ))}
          <button className="sr-oto" onClick={() => { setSrAcik(false); onPing && onPing('Rota otomatik sıralandı · 33 hak kaldı'); }}>
            <Icon name="bolt" size={16} sw={2.1} color="var(--accent-ink)" />Oto Sırala (rota) · 34 hak
          </button>
        </div>
      </Sheet>
    </div>
  );
}

// ── POS katalog: ızgara karolar → karoya tık → adet seçim sheet'i ──
function UrunGorsel({ u, cls }) {
  return u.gorsel
    ? <img className={cls} src={u.gorsel} alt="" />
    : <span className={cls + ' ph'}>{u.ad.trim().charAt(0).toLocaleUpperCase('tr')}</span>;
}

function PosKatalog({ acik, onKapat, onEkle, onPing, urunler }) {
  const [q, setQ] = React.useState('');
  const [sec, setSec] = React.useState(null);
  const [adet, setAdet] = React.useState(1);
  const [eklenen, setEklenen] = React.useState(0);
  const [bkAcik, setBkAcik] = React.useState(false);
  const [bkKod, setBkKod] = React.useState('');
  const [bkHata, setBkHata] = React.useState(null);
  React.useEffect(() => { if (acik) { setQ(''); setSec(null); setEklenen(0); setBkAcik(false); } }, [acik]);
  const tumu = (urunler || URUNLER);
  const okut = (kod) => {
    const k = String(kod).replace(/\D/g, '');
    if (k.length < 8) { setBkHata('Barkod en az 8 hane olmalı'); return; }
    const u = tumu.find((x) => x.aktif && x.barkod === k);
    if (!u) { setBkHata('Bu barkodla kayıtlı ürün yok: ' + k); return; }
    setBkAcik(false); setBkKod(''); setBkHata(null); setSec(u); setAdet(1);
  };
  const list = tumu.filter((u) => u.aktif && u.ad.toLocaleLowerCase('tr').includes(q.trim().toLocaleLowerCase('tr')));
  return (
    <React.Fragment>
      <Sheet open={acik} onClose={onKapat} tam baslik="Ürün Kataloğu">
        <div className="pos-ust">
          <div className="arama" style={{ margin: 0, flex: 1 }}>
            <Icon name="search" size={17} sw={2.1} color="var(--muted)" />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Ürün ara…" />
            {q && <button className="arama-x" onClick={() => setQ('')}><Icon name="x" size={16} sw={2.2} color="var(--muted)" /></button>}
          </div>
          <button className="pos-barkod" onClick={() => { setBkKod(''); setBkHata(null); setBkAcik(true); }} aria-label="Barkod okut"><Icon name="barkod" size={21} sw={2} color="var(--accent)" /></button>
        </div>
        {list.length === 0
          ? <div className="ys-bos"><Icon name="search" size={28} sw={1.6} color="var(--line-2)" />"{q}" için sonuç yok</div>
          : <div className="pos-grid">
              {list.map((u) => (
                <button key={u.id} className="pos-tile" onClick={() => { setSec(u); setAdet(1); }}>
                  <UrunGorsel u={u} cls="pos-img" />
                  <span className="pos-nm">{u.ad}</span>
                  <span className="pos-alt-row"><span className="pos-fiyat tabular">{fmtTL(u.fiyat)}</span><span className="pos-birim">/ {u.birim}</span></span>
                </button>
              ))}
            </div>}
        <div className="pos-alt">
          <button className="btn btn-p" onClick={onKapat}>{eklenen > 0 ? `Bitti · ${eklenen} kalem eklendi` : 'Bitti'}</button>
        </div>
      </Sheet>

      <Sheet open={bkAcik} onClose={() => setBkAcik(false)} baslik="Barkod Okut">
        <div className="sb-form">
          <div className="bk-cam"><Icon name="barkod" size={34} sw={1.5} color="var(--accent)" /><span>Harici okuyucu ya da kamera barkodu buraya yazar</span></div>
          <label className="s-flabel">Barkod</label>
          <div className="sdx-sb">
            <input className={`s-input tabular ${bkHata ? 'err' : ''}`} style={{ flex: 1 }} inputMode="numeric" autoFocus value={bkKod}
              onChange={(e) => { setBkKod(e.target.value.replace(/\D/g, '')); setBkHata(null); }}
              onKeyDown={(e) => { if (e.key === 'Enter') okut(bkKod); }} placeholder="869…" />
            <button className="btn btn-p" style={{ width: 'auto', flex: '0 0 auto', padding: '0 18px', height: 46 }} onClick={() => okut(bkKod)}>Okut</button>
          </div>
          {bkHata && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{bkHata}</div>}
          <label className="s-flabel">Demo · kayıtlı barkodlar</label>
          <div className="bk-demo">
            {tumu.filter((x) => x.aktif && x.barkod).map((x) => (
              <button key={x.id} className="bk-demo-row" onClick={() => okut(x.barkod)}>
                <span className="bk-demo-nm">{x.ad}</span>
                <span className="bk-demo-kod tabular">{x.barkod}</span>
              </button>
            ))}
          </div>
        </div>
      </Sheet>

      <Sheet open={!!sec} onClose={() => setSec(null)} baslik="Sepete Ekle">
        {sec && (
          <div className="pos-sec">
            <div className="pos-sec-head">
              <UrunGorsel u={sec} cls="pos-sec-img" />
              <span className="pos-sec-mid"><span className="pos-sec-nm">{sec.ad}</span><span className="pos-sec-birim tabular">{fmtTL(sec.fiyat)} / {sec.birim}</span>{sec.barkod && <span className="pos-sec-bk tabular"><Icon name="barkod" size={12} sw={1.8} color="var(--muted)" />{sec.barkod}</span>}</span>
              <span className="pos-sec-tt tabular">{fmtTL(sec.fiyat * adet)}</span>
            </div>
            <div className="pos-stepper">
              <button onClick={() => setAdet((a) => Math.max(1, a - 1))} aria-label="Azalt"><Icon name="down" size={20} sw={2.4} color={adet <= 1 ? 'var(--line-2)' : 'var(--ink)'} /></button>
              <span className="tabular">{adet}</span>
              <button onClick={() => setAdet((a) => a + 1)} aria-label="Artır"><Icon name="plus" size={20} sw={2.4} color="var(--ink)" /></button>
            </div>
            <button className="btn btn-p" style={{ marginTop: 14 }} onClick={() => { onEkle(sec, adet); setEklenen((n) => n + 1); setSec(null); onPing && onPing(`${sec.ad} ×${adet} sepete eklendi`); }}>
              <Icon name="plus" size={17} sw={2.4} color="#fff" />Sepete Ekle · {fmtTL(sec.fiyat * adet)}
            </button>
          </div>
        )}
      </Sheet>
    </React.Fragment>
  );
}

// ── Yeni sipariş — 3 adımlı akış: müşteri → kalemler → özet ──
function YeniSiparis({ musteriler, presetMusteri, urunler, onGeri, onKaydet, onPing, onMusteriEkle }) {
  const [adim, setAdim] = React.useState(presetMusteri ? 2 : 1);
  const [mus, setMus] = React.useState(presetMusteri || null);
  const [q, setQ] = React.useState('');
  const [ymAcik, setYmAcik] = React.useState(false);
  const [satirlar, setSatirlar] = React.useState([]);
  const [serbest, setSerbest] = React.useState([]);
  const [not, setNot] = React.useState('');
  const [katalogAcik, setKatalogAcik] = React.useState(false);
  const [sbAcik, setSbAcik] = React.useState(false);
  const [sbAd, setSbAd] = React.useState(''); const [sbTutar, setSbTutar] = React.useState('');
  const [sbHata, setSbHata] = React.useState(null);
  const [ysHata, setYsHata] = React.useState(false);

  const toplam = satirlar.reduce((s, r) => s + r.adet * r.fiyat, 0) + serbest.reduce((s, r) => s + r.tutar, 0);
  const bosMu = satirlar.length === 0 && serbest.length === 0;
  const urunEkle = (u, adet = 1) => {
    setSatirlar((prev) => {
      const v = prev.find((x) => x.id === u.id);
      if (v) return prev.map((x) => x.id === u.id ? { ...x, adet: x.adet + adet } : x);
      return [...prev, { id: u.id, ad: u.ad, adet, birim: u.birim, fiyat: u.fiyat }];
    });
    setYsHata(false);
  };
  const adetDegis = (id, d) => setSatirlar((prev) => prev.flatMap((x) => {
    if (x.id !== id) return [x];
    const a = x.adet + d; return a <= 0 ? [] : [{ ...x, adet: a }];
  }));
  const geriAdim = () => {
    if (adim === 1 || (adim === 2 && presetMusteri)) { onGeri(); return; }
    setAdim((a) => a - 1);
  };
  const list = musteriler.filter((m) => {
    const t = q.trim().toLocaleLowerCase('tr');
    if (!t) return true;
    return m.ad.toLocaleLowerCase('tr').includes(t) || (m.telefonlar || []).some((x) => x.no.replace(/\D/g, '').includes(t.replace(/\D/g, '') || '№'));
  });
  const adresM = mus ? birincilAdres(mus) : null;
  const ADIMLAR = ['Müşteri', 'Kalemler', 'Özet'];

  return (
    <div className="ekran">
      <Ust baslik="Yeni Sipariş" alt={mus ? mus.ad : 'Müşteri seçin'} onGeri={geriAdim} />
      <div className="ys-adimlar">
        {ADIMLAR.map((a, i) => (
          <span key={a} className={`ys-adim ${adim === i + 1 ? 'on' : ''} ${adim > i + 1 ? 'ok' : ''}`}>
            <i className="tabular">{adim > i + 1 ? '' : i + 1}{adim > i + 1 && <Icon name="check" size={11} sw={3} color="#fff" />}</i>{a}
          </span>
        ))}
      </div>

      {adim === 1 && (
        <React.Fragment>
          <div className="arama" style={{ marginTop: 8 }}>
            <Icon name="search" size={17} sw={2.1} color="var(--muted)" />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="İsim ya da telefon ara…" autoFocus />
            {q && <button className="arama-x" onClick={() => setQ('')}><Icon name="x" size={16} sw={2.2} color="var(--muted)" /></button>}
          </div>
          <div className="ekran-govde">
            <button className="ys-ekle" onClick={() => setYmAcik(true)}><Icon name="userPlus" size={19} sw={2.2} color="var(--accent)" />Yeni müşteri ekle</button>
            {list.length === 0
              ? <div className="ys-bos"><Icon name="users" size={28} sw={1.6} color="var(--line-2)" />{q ? `"${q}" için müşteri yok` : 'Henüz müşteri yok — yukarıdan ekleyin'}</div>
              : <div className="mliste">
                  {list.map((m) => { const bd = bakiyeDurum(m.bakiye); const ad2 = birincilAdres(m); return (
                    <button key={m.id} className="mrow" onClick={() => { setMus(m); setAdim(2); }}>
                      <span className="mrow-mid">
                        <span className="mrow-nm">{m.ad}</span>
                        <span className="mrow-tel tabular"><Icon name="phone" size={12.5} sw={2} color="var(--muted)" />{(birincilTel(m) || '—')}</span>
                        {ad2 && <span className="mrow-adres"><Icon name="pin" size={12.5} sw={2} color={ad2.konum ? 'var(--ok)' : 'var(--muted)'} /><span>{[ad2.metin, ad2.bolge].filter((x) => x && x !== '—').join(' — ')}</span></span>}
                      </span>
                      {m.bakiye !== 0 && <span className="mrow-bal"><span className="mrow-amt tabular" style={{ color: bd.renk }}>{fmtTL(Math.abs(m.bakiye))}</span><span className="mrow-tag" style={{ color: bd.renk }}>{bd.tag}</span></span>}
                      <Icon name="chevR" size={17} sw={2} color="var(--line-2)" />
                    </button>
                  ); })}
                </div>}
          </div>
        </React.Fragment>
      )}

      {adim === 2 && (
        <React.Fragment>
          <div className="ekran-govde">
            <div className="ys-secili">
              <Icon name="user" size={15} sw={2.1} color="var(--accent)" />
              <span className="ys-secili-nm">{mus.ad}</span>
              {!presetMusteri && <button className="sdx-link" onClick={() => { setAdim(1); }}>Değiştir</button>}
            </div>
            <button className="ys-ekle" onClick={() => setKatalogAcik(true)}><Icon name="plus" size={20} sw={2.3} color="var(--accent)" />Katalogdan ürün ekle</button>
            {bosMu ? (
              <div className="ys-bos"><Icon name="box" size={30} sw={1.5} color="var(--line-2)" />Sepet boş — katalogdan ürün ekleyin</div>
            ) : (
              <div className="ys-liste">
                {satirlar.map((r) => (
                  <div key={r.id} className="ys-satir">
                    <span className="ys-satir-nm">{r.ad}<span className="ys-birim">{r.birim}</span></span>
                    <div className="ys-stepper">
                      <button onClick={() => adetDegis(r.id, -1)}><Icon name={r.adet <= 1 ? 'x' : 'down'} size={14} sw={2.6} color={r.adet <= 1 ? 'var(--danger)' : 'var(--ink)'} /></button>
                      <span className="tabular">{r.adet}</span>
                      <button onClick={() => adetDegis(r.id, +1)}><Icon name="plus" size={14} sw={2.6} color="var(--ink)" /></button>
                    </div>
                    <span className="ys-satir-tt tabular">{fmtTL(r.adet * r.fiyat)}</span>
                  </div>
                ))}
                {serbest.map((r, i) => (
                  <div key={'sb' + i} className="ys-satir">
                    <span className="ys-satir-nm">{r.aciklama}<span className="ys-birim">tek seferlik</span></span>
                    <button className="ys-sil" onClick={() => setSerbest((p) => p.filter((_, k) => k !== i))}><Icon name="x" size={16} sw={2.2} color="var(--muted)" /></button>
                    <span className="ys-satir-tt tabular">{fmtTL(r.tutar)}</span>
                  </div>
                ))}
              </div>
            )}
            <button className="ys-serbest" onClick={() => { setSbAd(''); setSbTutar(''); setSbHata(null); setSbAcik(true); }}>+ Serbest satır (katalogda olmayan iş)</button>
          </div>
          <div className="ys-alt" style={{ flexWrap: 'wrap' }}>
            {ysHata && bosMu && <div className="ys-uyari"><Icon name="alert" size={15} sw={2.2} color="var(--danger)" />Sepet boş — önce ürün ekleyin.</div>}
            <div className="ys-toplam"><span>Toplam</span><b className="tabular">{fmtTL(toplam)}</b></div>
            <button className="btn btn-p" style={{ opacity: bosMu ? .6 : 1 }} onClick={() => { if (bosMu) { setYsHata(true); return; } setAdim(3); }}>Devam<Icon name="right" size={17} sw={2.4} color="#fff" /></button>
          </div>
        </React.Fragment>
      )}

      {adim === 3 && (
        <React.Fragment>
          <div className="ekran-govde">
            <div className="sdx-sec" style={{ marginTop: 10 }}>Müşteri</div>
            <div className="sdx-adres">
              <Icon name="user" size={15} sw={2.1} color="var(--accent)" />
              <span className="sdx-adres-mid">
                {mus.ad}
                <span style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }} className="tabular">{birincilTel(mus) || 'Telefon yok'}</span>
                {adresM && <span style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 600 }}>{[adresM.metin, adresM.bolge].filter((x) => x && x !== '—').join(' — ')}</span>}
              </span>
            </div>
            <div className="sdx-sec">Kalemler <button className="sdx-link" onClick={() => setAdim(2)}>Düzenle</button></div>
            <div className="sd-kart">
              {satirlar.map((r) => (
                <div key={r.id} className="sd-satir">
                  <span className="sd-nm">{r.ad}<span className="sd-birim tabular">{r.adet} {r.birim} × {fmtTL(r.fiyat)}</span></span>
                  <span className="sd-tt tabular">{fmtTL(r.adet * r.fiyat)}</span>
                </div>
              ))}
              {serbest.map((r, i) => (
                <div key={'sb' + i} className="sd-satir">
                  <span className="sd-nm">{r.aciklama}<span className="sd-birim">tek seferlik</span></span>
                  <span className="sd-tt tabular">{fmtTL(r.tutar)}</span>
                </div>
              ))}
              <div className="sd-toplam"><span>Toplam</span><b className="tabular">{fmtTL(toplam)}</b></div>
            </div>
            <div className="sdx-sec">Sipariş Notu</div>
            <textarea className="s-textarea" value={not} onChange={(e) => setNot(e.target.value)} placeholder="Kapı kodu, teslim saati, özel istek…" rows={2} />
          </div>
          <div className="ys-alt">
            <div className="ys-toplam"><span>Toplam</span><b className="tabular">{fmtTL(toplam)}</b></div>
            <button className="btn btn-p" onClick={() => onKaydet(mus, { satirlar, serbest, not })}><Icon name="check" size={18} sw={2.6} color="#fff" />Siparişi Kaydet</button>
          </div>
        </React.Fragment>
      )}

      <PosKatalog acik={katalogAcik} onKapat={() => setKatalogAcik(false)} onEkle={urunEkle} onPing={onPing} urunler={urunler} />

      <YeniMusteri acik={ymAcik} onTel="" mevcutlar={musteriler} onKapat={() => setYmAcik(false)}
        onKaydet={(m) => { onMusteriEkle(m); setYmAcik(false); setMus(m); setAdim(2); }} />

      <Sheet open={sbAcik} onClose={() => setSbAcik(false)} baslik="Serbest Satır">
        <div className="sb-form">
          <label className="s-flabel">Açıklama</label>
          <input className={`s-input ${sbHata && sbHata.ad ? 'err' : ''}`} value={sbAd} onChange={(e) => { setSbAd(e.target.value); setSbHata(null); }} placeholder="Ör. Nakliye, montaj, ek iş" autoFocus />
          {sbHata && sbHata.ad && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{sbHata.ad}</div>}
          <label className="s-flabel">Tutar (₺)</label>
          <input className={`s-input tabular ${sbHata && sbHata.tutar ? 'err' : ''}`} inputMode="numeric" value={sbTutar} onChange={(e) => { setSbTutar(e.target.value.replace(/\D/g, '')); setSbHata(null); }} placeholder="0" />
          {sbHata && sbHata.tutar && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{sbHata.tutar}</div>}
          <button className="btn btn-p" style={{ marginTop: 16 }}
            onClick={() => {
              const h = {};
              if (sbAd.trim().length < 2) h.ad = 'Açıklama girin (en az 2 karakter)';
              if (!sbTutar || Number(sbTutar) <= 0) h.tutar = 'Tutar 0’dan büyük olmalı';
              if (Object.keys(h).length) { setSbHata(h); return; }
              setSerbest((p) => [...p, { aciklama: sbAd.trim(), tutar: Number(sbTutar) * 100 }]); setSbAcik(false); setYsHata(false);
            }}>Ekle</button>
        </div>
      </Sheet>
    </div>
  );
}

// ── Sipariş detayı — alttan açılan detaylı sheet ──────────
function SiparisDetay({ o, musteri, gecmis, kuryeAdlari, urunler, tumMusteriler, onMusteriGuncelle, onKapat, onTeslim, onIptal, onKuryeDegis, onNotKaydet, onSiparisGuncelle, onKonumSec, onPing }) {
  const [teslimAcik, setTeslimAcik] = React.useState(false);
  const [kuryeAcik, setKuryeAcik] = React.useState(false);
  const [odeme, setOdeme] = React.useState('nakit');
  const [notEdit, setNotEdit] = React.useState(false);
  const [notTaslak, setNotTaslak] = React.useState('');
  const [duzen, setDuzen] = React.useState(false);
  const [tSatir, setTSatir] = React.useState([]);
  const [tSerbest, setTSerbest] = React.useState([]);
  const [kAday, setKAday] = React.useState(null);
  const [bilgiAcik, setBilgiAcik] = React.useState(false);
  const [dAd, setDAd] = React.useState('');
  const [posAcik, setPosAcik] = React.useState(false);
  const [dTutar, setDTutar] = React.useState('');
  React.useEffect(() => { setNotEdit(false); setDuzen(false); setTeslimAcik(false); setKuryeAcik(false); setKAday(null); setBilgiAcik(false); }, [o && o.id]);
  if (!o) return null;
  const acik = o.durum === 'acik';
  const musterili = !!o.musteriId;
  const adres = musteri ? birincilAdres(musteri) : null;
  const adlar = kuryeAdlari && kuryeAdlari.length ? [...new Set([...kuryeAdlari, o.kurye])] : KURYELER;
  const tut = siparisTutar(o);
  const tToplam = tSatir.reduce((a, r) => a + r.adet * r.fiyat, 0) + tSerbest.reduce((a, r) => a + r.tutar, 0);
  const duzenBasla = () => { setTSatir(o.satirlar.map((r) => ({ ...r }))); setTSerbest(o.serbest.map((r) => ({ ...r }))); setDuzen(true); };

  return (
    <React.Fragment>
      <Sheet open={!!o} onClose={onKapat} tam baslik={o.musteriAd}>
        <div className="sdx-head">
          {musterili && <span className="srow-kod tabular">{musteriKod(o.musteriId)}</span>}
          <DurumPili durum={o.durum} />
          <span className="srow-kurye" style={{ cursor: acik ? 'pointer' : 'default' }} onClick={() => acik && setKuryeAcik(true)}><Icon name="truck" size={13} sw={2.2} color="currentColor" />{o.kurye}{acik && <Icon name="down" size={12} sw={2.4} color="var(--muted)" />}</span>
          <span className="srow-saat tabular"><Icon name="clock" size={12} sw={2} color="var(--muted)" />{o.saat}</span>
        </div>

        <div className="sdx-sec">Sipariş Kalemleri{acik && <button className="sdx-link" onClick={duzenBasla}>Düzenle</button>}</div>
        <div className="sd-kart">
          {o.satirlar.map((r, i) => (
            <div key={i} className="sd-satir">
              <span className="sd-nm">{r.ad}<span className="sd-birim tabular">{r.adet} {r.birim} × {fmtTL(r.fiyat)}</span></span>
              <span className="sd-tt tabular">{fmtTL(r.adet * r.fiyat)}</span>
            </div>
          ))}
          {o.serbest.map((r, i) => (
            <div key={'s' + i} className="sd-satir">
              <span className="sd-nm">{r.aciklama}<span className="sd-birim">tek seferlik</span></span>
              <span className="sd-tt tabular">{fmtTL(r.tutar)}</span>
            </div>
          ))}
          <div className="sd-toplam"><span>Toplam</span><b className="tabular">{fmtTL(tut)}</b></div>
        </div>

        <div className="sdx-sec">Sipariş Notu{!notEdit && <button className="sdx-link" onClick={() => { setNotTaslak(o.not || ''); setNotEdit(true); }}>{o.not ? 'Düzenle' : '+ Not Ekle'}</button>}</div>
        {notEdit ? (
          <div className="sb-form" style={{ gap: 0 }}>
            <textarea className="s-textarea" autoFocus rows={2} value={notTaslak} onChange={(e) => setNotTaslak(e.target.value)} placeholder="Kapı kodu, teslim saati, özel istek…" />
            <div className="sdx-duzen-btns">
              <button className="btn btn-s" onClick={() => setNotEdit(false)}>Vazgeç</button>
              <button className="btn btn-p" onClick={() => { onNotKaydet(o.id, notTaslak.trim()); setNotEdit(false); }}>Notu Kaydet</button>
            </div>
          </div>
        ) : o.not
          ? <div className="srow-not" style={{ marginTop: 2 }}><Icon name="edit" size={14} sw={2.1} color="var(--warn)" /><span>{o.not}</span></div>
          : <div className="sdx-bos">Not yok.</div>}

        {musterili && (
          <React.Fragment>
            <div className="sdx-sec">Teslimat Adresi<button className="sdx-link" onClick={() => setBilgiAcik(true)}>Müşteriyi Düzenle</button></div>
            {adres ? (
              <div className="sdx-adres">
                <Icon name="pin" size={15} sw={2.1} color={adres.konum ? 'var(--ok)' : 'var(--muted)'} />
                <span className="sdx-adres-mid">
                  {[adres.metin, adres.bolge].filter((x) => x && x !== '—').join(' — ')}
                  <span className={`sdx-konum ${adres.konum ? 'var' : 'yok'}`}>{adres.konum ? `Konum kayıtlı · ${adres.konum.lat.toFixed(4)}, ${adres.konum.lng.toFixed(4)}` : 'Konum alınmamış'}</span>
                </span>
                <button className="ust-metin" onClick={() => setKAday(adresAdaylari(adres.metin, adres.bolge))}>{adres.konum ? 'Güncelle' : 'Konum Al'}</button>
              </div>
            ) : <div className="sdx-bos">Adres kayıtlı değil — müşteri detayından ekleyin.</div>}

            {(gecmis || []).length > 0 && (
              <React.Fragment>
                <div className="sdx-sec">Geçmiş Siparişler <span className="sdx-adet tabular">{gecmis.length}</span></div>
                <div className="gec-list">
                  {gecmis.map((g) => (
                    <div key={g.id} className="gec-row">
                      <span className="gec-mid">
                        <span className="gec-t">{siparisOzet(g)}</span>
                        <span className="gec-s tabular">{g.saat}{g.odeme ? ` · ${ODEME_TIPLERI[g.odeme].label}` : ''} · {g.kurye}</span>
                      </span>
                      <DurumPili durum={g.durum} />
                      <span className="gec-amt tabular">{fmtTL(siparisTutar(g))}</span>
                    </div>
                  ))}
                </div>
              </React.Fragment>
            )}
          </React.Fragment>
        )}

        {o.odeme && <div className="sd-odendi"><Icon name="check" size={16} sw={2.4} color="var(--ok)" />{ODEME_TIPLERI[o.odeme].label} ile ödendi</div>}

        {acik && !duzen && (
          <div className="sdx-duzen-btns" style={{ marginTop: 18 }}>
            <button className="btn btn-d" style={{ background: 'var(--danger-soft)', color: 'var(--danger)' }} onClick={() => onIptal(o)}>İptal Et</button>
            <button className="btn btn-p" style={{ flex: 2 }} onClick={() => setTeslimAcik(true)}>Teslim Et</button>
          </div>
        )}
      </Sheet>

      <Sheet open={duzen} onClose={() => setDuzen(false)} tam baslik="Siparişi Düzenle">
        <div className="sdx-sec" style={{ marginTop: 2 }}>Kalemler</div>
        <div className="sd-kart">
          {tSatir.map((r, i) => (
            <div key={i} className="sd-satir">
              <span className="sd-nm">{r.ad}<span className="sd-birim tabular">{fmtTL(r.fiyat)} / {r.birim}</span></span>
              <div className="ys-stepper">
                <button onClick={() => setTSatir((p) => p.flatMap((x, k) => k !== i ? [x] : x.adet <= 1 ? [] : [{ ...x, adet: x.adet - 1 }]))}><Icon name={r.adet <= 1 ? 'x' : 'down'} size={14} sw={2.6} color={r.adet <= 1 ? 'var(--danger)' : 'var(--ink)'} /></button>
                <span className="tabular">{r.adet}</span>
                <button onClick={() => setTSatir((p) => p.map((x, k) => k === i ? { ...x, adet: x.adet + 1 } : x))}><Icon name="plus" size={14} sw={2.6} color="var(--ink)" /></button>
              </div>
              <span className="sd-tt tabular">{fmtTL(r.adet * r.fiyat)}</span>
            </div>
          ))}
          {tSerbest.map((r, i) => (
            <div key={'s' + i} className="sd-satir">
              <span className="sd-nm">{r.aciklama}<span className="sd-birim">tek seferlik</span></span>
              <button className="ys-sil" onClick={() => setTSerbest((p) => p.filter((_, k) => k !== i))}><Icon name="x" size={16} sw={2.2} color="var(--muted)" /></button>
              <span className="sd-tt tabular">{fmtTL(r.tutar)}</span>
            </div>
          ))}
          {tSatir.length === 0 && tSerbest.length === 0 && <div className="ym-err" style={{ padding: '10px 0' }}><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Sepet boş kalamaz — en az bir kalem ekleyin</div>}
          <div className="sd-toplam"><span>Yeni toplam</span><b className="tabular">{fmtTL(tToplam)}</b></div>
        </div>
        <button className="ys-ekle" onClick={() => setPosAcik(true)}><Icon name="plus" size={20} sw={2.3} color="var(--accent)" />Katalogdan ürün ekle</button>
        <div className="sdx-sec">Serbest Satır Ekle</div>
        <div className="sdx-sb">
          <input className="s-input" style={{ flex: 2 }} value={dAd} onChange={(e) => setDAd(e.target.value)} placeholder="Açıklama (ör. nakliye)" />
          <input className="s-input tabular" style={{ flex: 1 }} inputMode="numeric" value={dTutar} onChange={(e) => setDTutar(e.target.value.replace(/\D/g, ''))} placeholder="₺" />
          <button className="btn btn-s" style={{ width: 'auto', flex: '0 0 auto', padding: '0 16px', height: 46 }} onClick={() => { if (dAd.trim().length < 2 || !dTutar || Number(dTutar) <= 0) { onPing && onPing('Açıklama ve 0’dan büyük tutar girin'); return; } setTSerbest((p) => [...p, { aciklama: dAd.trim(), tutar: Number(dTutar) * 100 }]); setDAd(''); setDTutar(''); }}>Ekle</button>
        </div>
        <div className="sdx-duzen-btns" style={{ marginTop: 16 }}>
          <button className="btn btn-s" onClick={() => setDuzen(false)}>Vazgeç</button>
          <button className="btn btn-p" disabled={tSatir.length === 0 && tSerbest.length === 0} onClick={() => { onSiparisGuncelle(o.id, tSatir, tSerbest); setDuzen(false); }}>Değişiklikleri Kaydet</button>
        </div>
      </Sheet>

      <PosKatalog acik={posAcik} onKapat={() => setPosAcik(false)} onPing={onPing} urunler={urunler}
        onEkle={(u, adet) => setTSatir((p) => { const v = p.find((x) => x.id === u.id); if (v) return p.map((x) => x.id === u.id ? { ...x, adet: x.adet + adet } : x); return [...p, { id: u.id, ad: u.ad, adet, birim: u.birim, fiyat: u.fiyat }]; })} />

      {musteri && <MusteriDuzenle acik={bilgiAcik} m={musteri} digerleri={tumMusteriler} onKapat={() => setBilgiAcik(false)} onKaydet={(f) => { onMusteriGuncelle(musteri.id, f); setBilgiAcik(false); }} />}

      <Sheet open={kuryeAcik} onClose={() => setKuryeAcik(false)} baslik="Kurye Seç">
        <div className="sr-list">
          {adlar.map((k) => (
            <button key={k} className={`sr-row ${o.kurye === k ? 'on' : ''}`} onClick={() => { if (o.kurye !== k) { onKuryeDegis(o.id, k); onPing && onPing(`Kurye değiştirildi: ${k}`); } setKuryeAcik(false); }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 9 }}><Icon name="truck" size={16} sw={2} color="var(--muted)" />{k}</span>
              {o.kurye === k && <Icon name="check" size={17} sw={2.4} color="var(--accent)" />}
            </button>
          ))}
        </div>
      </Sheet>

      <Sheet open={!!kAday} onClose={() => setKAday(null)} baslik="Konum Seç · API Sonuçları">
        <div className="aday-info"><Icon name="info" size={14} sw={2} color="var(--accent)" />Adres bazen yanlış algılanabilir — doğru olanı seçin.</div>
        <div className="aday-list">
          {(kAday || []).map((a) => (
            <button key={a.id} className="aday-row" onClick={() => { onKonumSec(o.musteriId, { lat: a.lat, lng: a.lng }); setKAday(null); }}>
              <span className="aday-ic"><Icon name="pin" size={16} sw={2.1} color="var(--accent)" /></span>
              <span className="aday-mid"><span className="aday-t">{a.metin}</span><span className="aday-s tabular">{a.lat.toFixed(4)}, {a.lng.toFixed(4)}</span></span>
              <Icon name="chevR" size={16} sw={2} color="var(--line-2)" />
            </button>
          ))}
        </div>
      </Sheet>

      <Sheet open={teslimAcik} onClose={() => setTeslimAcik(false)} baslik="Teslim & Ödeme">
        <div className="teslim">
          <div className="teslim-tut"><span>Tahsil edilecek</span><b className="tabular">{fmtTL(tut)}</b></div>
          <label className="s-flabel">Ödeme tipi</label>
          <div className="odeme-grid">
            {Object.entries(ODEME_TIPLERI).map(([k, v]) => (
              <button key={k} className={`odeme-b ${odeme === k ? 'on' : ''}`} disabled={k === 'veresiye' && !musterili} style={k === 'veresiye' && !musterili ? { opacity: .45, cursor: 'default' } : null} onClick={() => setOdeme(k)}>{v.label}</button>
            ))}
          </div>
          {!musterili && <div className="ym-err" style={{ marginTop: 8 }}><Icon name="info" size={13} sw={2.2} color="var(--muted)" /><span style={{ color: 'var(--muted)' }}>Tezgâh satışında veresiye kullanılamaz — kayıtlı müşteri gerekir.</span></div>}
          {odeme === 'veresiye' && <div className="teslim-uyari"><Icon name="alert" size={15} sw={2.2} color="var(--danger)" />Tutar müşterinin borcuna eklenecek.</div>}
          <button className="btn btn-p" style={{ marginTop: 18 }} onClick={() => { onTeslim(o, odeme, o.kurye); setTeslimAcik(false); }}>Teslim Et ve Kaydet</button>
        </div>
      </Sheet>
    </React.Fragment>
  );
}

Object.assign(window, { SiparislerEkran, YeniSiparis, SiparisDetay, PosKatalog, UrunGorsel });
