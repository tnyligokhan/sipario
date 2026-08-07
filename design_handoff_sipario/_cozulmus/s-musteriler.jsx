// s-musteriler.jsx — Müşteriler listesi + Müşteri detayı (veresiye defteri). → window

function MusteriSatir({ m, onAc }) {
  const d = bakiyeDurum(m.bakiye);
  const adres = birincilAdres(m);
  return (
    <button className="mrow" onClick={() => onAc(m)}>
      <span className="mrow-mid">
        <span className="mrow-nm">{m.ad}</span>
        <span className="mrow-tel tabular"><Icon name="phone" size={13} sw={2} color="var(--muted)" />{birincilTel(m)}</span>
        {adres && <span className="mrow-adres"><Icon name="pin" size={13} sw={2.2} color={adres.konum ? 'var(--ok)' : 'var(--muted)'} /><span>{[adres.metin, adres.bolge].filter((x) => x && x !== '—').join(' — ')}</span></span>}
      </span>
      {m.bakiye !== 0 && (
        <span className={`mrow-bal ${d.cls}`} style={{ color: d.renk }}>
          <span className="mrow-dot" style={{ background: d.renk }} />
          <span className="mrow-amt tabular">{fmtTL(Math.abs(m.bakiye))}</span>
        </span>
      )}
    </button>
  );
}

function MusterilerEkran({ musteriler, onAc, durum, onMenu, onYeni }) {
  const [q, setQ] = React.useState('');
  const borc = borcluSayisi(musteriler);
  const ql = q.trim().toLocaleLowerCase('tr');
  const list = ql
    ? musteriler.filter((m) => m.ad.toLocaleLowerCase('tr').includes(ql) || birincilTel(m).replace(/\D/g, '').includes(ql.replace(/\D/g, '')))
    : musteriler;

  return (
    <div className="ekran">
      <Ust baslik="Müşteriler" alt={borc > 0 ? `${borc} borçlu müşteri` : 'Tüm hesaplar temiz'} onMenu={onMenu}
        sag={<button className="ust-sirala" onClick={onYeni}><Icon name="plus" size={15} sw={2.4} color="var(--accent)" />Yeni</button>} />
      <div className="arama">
        <Icon name="search" size={19} sw={2} color="var(--muted)" />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Ad veya telefon ara" />
        {q && <button className="arama-x" onClick={() => setQ('')}><Icon name="x" size={18} sw={2.2} color="var(--muted)" /></button>}
      </div>
      <div className="ekran-govde">
        {durum === 'yukleniyor' ? <Iskelet /> :
         durum === 'hata' ? <HataEkran onTekrar={() => {}} /> :
         list.length === 0 ? (
           ql
             ? <BosDurum ikon="search" baslik="Sonuç yok" aciklama={`"${q}" için müşteri bulunamadı.`} />
             : <BosDurum ikon="users" baslik="Henüz müşteri yok" aciklama="Gelen çağrıdan ya da + Yeni ile ilk müşterini ekle." aksiyon="Yeni Müşteri" onAksiyon={onYeni} />
         ) : (
           <div className="mliste">
             {list.map((m) => <MusteriSatir key={m.id} m={m} onAc={onAc} />)}
           </div>
         )}
      </div>
    </div>
  );
}

// ── Müşteri detayı (defter) ───────────────────────────────
const HAREKET_META = {
  borc:     { label: 'Borç',     renk: 'var(--danger)', isaret: '+', ikon: 'box' },
  tahsilat: { label: 'Tahsilat', renk: 'var(--ok)',     isaret: '−', ikon: 'wallet' },
  alacak:   { label: 'Alacak',   renk: 'var(--ok)',     isaret: '−', ikon: 'wallet' },
  duzeltme: { label: 'Düzeltme', renk: 'var(--muted)',  isaret: '±', ikon: 'edit' },
};

// Adres → API aday listesi (mock): kullanıcı doğrusunu seçer, otomatik atanmaz
function adresAdaylari(metin, bolge) {
  const b = (bolge || 'Muratpaşa').trim();
  const m = metin.trim();
  return [
    { id: 1, metin: `${m}, ${b} / Antalya`, lat: 36.8969, lng: 30.7133 },
    { id: 2, metin: `${m.replace(/no:?\s*\d+.*/i, '').trim().replace(/,$/, '')} Sk., ${b} / Antalya`, lat: 36.9014, lng: 30.7221 },
    { id: 3, metin: `${m} (yakın: ${b} Pazar Yeri), Antalya`, lat: 36.8891, lng: 30.7042 },
  ];
}

function MusteriDetay({ m, onGeri, onSiparis, onTahsilatKaydet, onDuzeltKaydet, onMusteriGuncelle, tumMusteriler, onPing, onKonumSec }) {
  const [kAday, setKAday] = React.useState(null); // null | aday[]
  const [tahAcik, setTahAcik] = React.useState(false);
  const [tahTutar, setTahTutar] = React.useState('');
  const [tahOdeme, setTahOdeme] = React.useState('nakit');
  const [tahHata, setTahHata] = React.useState(null);
  const [duzAcik, setDuzAcik] = React.useState(false);
  const [duzYon, setDuzYon] = React.useState('ekle');
  const [duzTutar, setDuzTutar] = React.useState('');
  const [duzNot, setDuzNot] = React.useState('');
  const [duzHata, setDuzHata] = React.useState(null);
  const borc = Math.max(0, m.bakiye);
  const tahAc = () => { setTahTutar(borc ? String(Math.round(borc / 100)) : ''); setTahOdeme('nakit'); setTahHata(null); setTahAcik(true); };
  const duzAc = () => { setDuzYon('ekle'); setDuzTutar(''); setDuzNot(''); setDuzHata(null); setDuzAcik(true); };
  const tahKurus = (Number(tahTutar) || 0) * 100;
  const duzKurus = (Number(duzTutar) || 0) * 100;
  const [bilgiAcik, setBilgiAcik] = React.useState(false);
  const d = bakiyeDurum(m.bakiye);
  const tel = birincilTel(m);
  const adres = birincilAdres(m);
  return (
    <div className="ekran">
      <Ust baslik={m.ad} alt={tel} onGeri={onGeri}
        sag={<button className="ust-ikon" onClick={() => setBilgiAcik(true)} aria-label="Müşteriyi düzenle"><Icon name="edit" size={17} sw={2} color="var(--ink)" /></button>} />
      <div className="ekran-govde">
        <div className="md-kart">
          {adres && <div className="md-kart-adres"><Icon name="pin" size={17} sw={2} color="rgba(255,255,255,.6)" /><span>{[adres.metin, adres.bolge].filter((x) => x && x !== '—').join(' — ')}</span></div>}
          {adres && (adres.konum
            ? <div className="md-konum var"><Icon name="check" size={13} sw={2.6} color="#7EE2A8" />Konum kayıtlı · <span className="tabular">{adres.konum.lat.toFixed(4)}, {adres.konum.lng.toFixed(4)}</span></div>
            : <button className="md-konum yok" onClick={() => setKAday(adresAdaylari(adres.metin, adres.bolge))}>Konum alınmamış — <b>Konum Al</b></button>)}
          <div className="md-kart-tel tabular">{tel}</div>
          <div className="md-ilet">
            <button onClick={() => onPing && onPing(`${m.ad} aranıyor…`)}><Icon name="phone" size={16} sw={2.1} color="#fff" />Ara</button>
            <button onClick={() => onPing && onPing('WhatsApp açılıyor…')}><Icon name="wa" size={16} sw={1.9} color="#fff" />WhatsApp</button>
            <button onClick={() => onPing && onPing(adres && adres.konum ? `Konum haritada açılıyor (${adres.konum.lat.toFixed(4)}, ${adres.konum.lng.toFixed(4)})…` : 'Konum kayıtlı değil — önce Adresten Konum Al')}><Icon name="pin" size={16} sw={2.1} color="#fff" />Konum</button>
          </div>
        </div>
        <div className="md-bakiye" style={{ background: m.bakiye === 0 ? 'var(--ok-soft)' : m.bakiye > 0 ? 'var(--danger-soft)' : 'var(--ok-soft)' }}>
          <span>Bakiye</span>
          <b className="tabular" style={{ color: d.renk }}>{m.bakiye === 0 ? 'Temiz' : `${fmtTL(Math.abs(m.bakiye))} ${d.tag}`}</b>
        </div>

        <div className="md-akslar" style={{ gridTemplateColumns: '1fr 1fr' }}>
          <button className="mdakt" onClick={() => onSiparis(m)}><Icon name="plus" size={20} sw={2.3} color="var(--accent)" /><span>Sipariş</span></button>
          <button className="mdakt" onClick={tahAc}><Icon name="wallet" size={20} sw={2} color="var(--accent)" /><span>Tahsilat</span></button>
        </div>

        {m.not && <div className="md-not"><Icon name="info" size={16} sw={2} color="var(--warn)" /><span>{m.not}</span></div>}

        <div className="md-baslik" style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>Defter Hareketleri<button className="md-duzelt-link" onClick={duzAc}>± Bakiye Düzeltme</button></div>
        <div className="defter">
          {(m.hareketler || []).length === 0
            ? <BosDurum ikon="book" baslik="Hareket yok" aciklama="Bu müşteriyle henüz kayıt oluşmadı." />
            : m.hareketler.map((h, i) => {
              const meta = HAREKET_META[h.tip] || HAREKET_META.borc;
              return (
                <div key={i} className="dhar">
                  <span className="dhar-ic" style={{ background: 'color-mix(in srgb, ' + meta.renk + ' 12%, transparent)' }}>
                    <Icon name={meta.ikon} size={17} sw={2} color={meta.renk} />
                  </span>
                  <span className="dhar-mid">
                    <span className="dhar-t">{meta.label}{h.odeme && <span className="dhar-odeme">{ODEME_TIPLERI[h.odeme]?.label}</span>}</span>
                    <span className="dhar-sub">{h.saat}{h.not ? ` · ${h.not}` : ''}</span>
                  </span>
                  <span className="dhar-amt tabular" style={{ color: meta.renk }}>{h.tip === 'duzeltme' ? (h.yon === 'eksi' ? '−' : '+') : meta.isaret}{fmtTL(h.tutar)}</span>
                </div>
              );
            })}
        </div>
      </div>

      <MusteriDuzenle acik={bilgiAcik} m={m} digerleri={tumMusteriler} onKapat={() => setBilgiAcik(false)} onKaydet={(f) => { onMusteriGuncelle(m.id, f); setBilgiAcik(false); }} />

      <Sheet open={tahAcik} onClose={() => setTahAcik(false)} baslik="Tahsilat Al">
        <div className="sb-form">
          <div className="kd-row"><span>Açık borç</span><b className="tabular" style={{ color: borc > 0 ? 'var(--danger)' : 'var(--ok)' }}>{fmtTL(borc)}</b></div>
          {borc === 0 ? (
            <div className="gs-kapali" style={{ marginTop: 4 }}><Icon name="check" size={15} sw={2.4} color="var(--ok)" />Bu müşterinin açık borcu yok.</div>
          ) : (
            <React.Fragment>
              <label className="s-flabel">Tahsil edilecek tutar (₺)</label>
              <input className={`s-input tabular kd-input ${tahHata ? 'err' : ''}`} inputMode="numeric" value={tahTutar} onChange={(e) => { setTahTutar(e.target.value.replace(/\D/g, '')); setTahHata(null); }} placeholder="0" autoFocus />
              {tahHata && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{tahHata}</div>}
              <div className="th-chips">
                <button className={`th-chip ${tahKurus === borc ? 'on' : ''}`} onClick={() => { setTahTutar(String(Math.round(borc / 100))); setTahHata(null); }}>Tamamı · {fmtTL(borc)}</button>
                {borc >= 200 && <button className="th-chip" onClick={() => { setTahTutar(String(Math.round(borc / 200))); setTahHata(null); }}>Yarısı</button>}
              </div>
              <label className="s-flabel">Ödeme tipi</label>
              <div className="odeme-grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
                {['nakit', 'kart', 'havale'].map((k) => (
                  <button key={k} className={`odeme-b ${tahOdeme === k ? 'on' : ''}`} onClick={() => setTahOdeme(k)}>{ODEME_TIPLERI[k].label}</button>
                ))}
              </div>
              <button className="btn btn-p" style={{ marginTop: 18 }} onClick={() => {
                if (tahKurus <= 0) { setTahHata('Tutar girin'); return; }
                if (tahKurus > borc) { setTahHata(`Tutar açık borçtan (${fmtTL(borc)}) fazla olamaz`); return; }
                onTahsilatKaydet(m, tahKurus, tahOdeme); setTahAcik(false);
              }}><Icon name="check" size={17} sw={2.4} color="#fff" />Tahsilatı Kaydet</button>
            </React.Fragment>
          )}
        </div>
      </Sheet>

      <Sheet open={duzAcik} onClose={() => setDuzAcik(false)} baslik="Bakiye Düzeltme">
        <div className="sb-form">
          <div className="kd-row"><span>Mevcut bakiye</span><b className="tabular" style={{ color: bakiyeDurum(m.bakiye).renk }}>{m.bakiye === 0 ? 'Temiz' : `${fmtTL(Math.abs(m.bakiye))} ${bakiyeDurum(m.bakiye).tag}`}</b></div>
          <label className="s-flabel">İşlem</label>
          <div className="odeme-grid" style={{ gridTemplateColumns: '1fr 1fr' }}>
            <button className={`odeme-b ${duzYon === 'ekle' ? 'on' : ''}`} onClick={() => { setDuzYon('ekle'); setDuzHata(null); }}>Borç Ekle (+)</button>
            <button className={`odeme-b ${duzYon === 'eksi' ? 'on' : ''}`} onClick={() => { setDuzYon('eksi'); setDuzHata(null); }}>Borç Azalt (−)</button>
          </div>
          <label className="s-flabel">Tutar (₺)</label>
          <input className={`s-input tabular ${duzHata && duzHata.t ? 'err' : ''}`} inputMode="numeric" value={duzTutar} onChange={(e) => { setDuzTutar(e.target.value.replace(/\D/g, '')); setDuzHata(null); }} placeholder="0" />
          {duzHata && duzHata.t && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{duzHata.t}</div>}
          <label className="s-flabel">Açıklama (zorunlu)</label>
          <input className={`s-input ${duzHata && duzHata.n ? 'err' : ''}`} value={duzNot} onChange={(e) => { setDuzNot(e.target.value); setDuzHata(null); }} placeholder="Ör. eksik yazılan tutar, iade, pazarlık…" />
          {duzHata && duzHata.n && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />{duzHata.n}</div>}
          {duzYon === 'eksi' && duzKurus > Math.max(0, m.bakiye) && duzKurus > 0 && <div className="ym-err" style={{ marginTop: 8 }}><Icon name="info" size={13} sw={2.2} color="var(--warn)" /><span style={{ color: 'var(--warn)' }}>Bu düzeltmeyle müşteri alacaklı duruma geçecek.</span></div>}
          <button className="btn btn-p" style={{ marginTop: 18 }} onClick={() => {
            const h = {};
            if (duzKurus <= 0) h.t = 'Tutar 0’dan büyük olmalı';
            if (duzNot.trim().length < 2) h.n = 'Açıklama girin — düzeltmenin nedeni deftere yazılır';
            if (Object.keys(h).length) { setDuzHata(h); return; }
            onDuzeltKaydet(m, duzYon === 'ekle' ? duzKurus : -duzKurus, duzNot.trim()); setDuzAcik(false);
          }}><Icon name="check" size={17} sw={2.4} color="#fff" />Düzeltmeyi Kaydet</button>
        </div>
      </Sheet>

      <Sheet open={!!kAday} onClose={() => setKAday(null)} baslik="Konum Seç · API Sonuçları">
        <div className="aday-info"><Icon name="info" size={14} sw={2} color="var(--accent)" />Adres bazen yanlış algılanabilir — doğru olanı seçin.</div>
        <div className="aday-list">
          {(kAday || []).map((a) => (
            <button key={a.id} className="aday-row" onClick={() => { onKonumSec(m, { lat: a.lat, lng: a.lng }); setKAday(null); }}>
              <span className="aday-ic"><Icon name="pin" size={16} sw={2.1} color="var(--accent)" /></span>
              <span className="aday-mid"><span className="aday-t">{a.metin}</span><span className="aday-s tabular">{a.lat.toFixed(4)}, {a.lng.toFixed(4)}</span></span>
              <Icon name="chevR" size={16} sw={2} color="var(--line-2)" />
            </button>
          ))}
        </div>
      </Sheet>
    </div>
  );
}
function YeniMusteri({ acik, onKapat, onKaydet, onTel, mevcutlar }) {
  const [ad, setAd] = React.useState('');
  const [teller, setTeller] = React.useState(['']);
  const [adres, setAdres] = React.useState('');
  const [bolge, setBolge] = React.useState('');
  const [not, setNot] = React.useState('');
  const [hata, setHata] = React.useState(null);
  const [konum, setKonum] = React.useState(null); // null | {lat,lng}
  const [adaylar, setAdaylar] = React.useState(null); // null | aday[]
  React.useEffect(() => { if (acik) { setAd(''); setTeller([onTel || '']); setAdres(''); setBolge(''); setNot(''); setHata(null); setKonum(null); setAdaylar(null); } }, [acik, onTel]);
  const konumAl = () => {
    if (!adres.trim()) { setHata({ adres: true }); setAdaylar(null); return; }
    setKonum(null); setAdaylar(adresAdaylari(adres, bolge));
  };
  const telDegis = (i, v) => { setTeller((p) => p.map((x, k) => k === i ? v : x)); setHata(null); };
  const kaydet = () => {
    const e = {};
    if (ad.trim().length < 2) e.ad = true;
    const h0 = teller[0].replace(/\D/g, '');
    if (h0.length < 10 || h0.length > 11) e.tel = true;
    // Ek telefonlar: doluysa geçerli olmalı (sessizce atılmaz)
    teller.forEach((t, i) => { if (i > 0 && t.trim()) { const h = t.replace(/\D/g, ''); if (h.length < 10 || h.length > 11) e['tel' + i] = true; } });
    // Mükerrer numara: kayıtlı müşterilerde aynı numara var mı?
    if (!e.tel && mevcutlar) {
      const sahip = mevcutlar.find((mm) => (mm.telefonlar || []).some((t) => t.no.replace(/\D/g, '') === h0));
      if (sahip) e.mukerrer = sahip.ad;
    }
    if (Object.keys(e).length) { setHata(e); return; }
    const telefonlar = teller.map((t) => t.trim()).filter((t) => t.replace(/\D/g, '').length >= 10)
      .map((no, i) => ({ no, etiket: i === 0 ? 'Cep' : 'Telefon ' + (i + 1), birincil: i === 0 }));
    onKaydet({ id: 'm' + Date.now(), ad: ad.trim(), not: not.trim(), bakiye: 0, hareketler: [],
      telefonlar,
      adresler: adres.trim() ? [{ metin: adres.trim(), etiket: 'Ev', bolge: bolge.trim(), konum: konum || null }] : [] });
  };
  return (
    <Sheet open={acik} onClose={onKapat} baslik="Yeni Müşteri">
      <div className="sb-form">
        <label className="s-flabel">Ad Soyad *</label>
        <input className="s-input" style={hata && hata.ad ? { borderColor: 'var(--danger)', background: 'var(--danger-soft)' } : null} value={ad} onChange={(e) => { setAd(e.target.value); setHata(null); }} placeholder="Ör. Ayşe Kaya" autoFocus />
        {hata && hata.ad && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Ad soyad girin</div>}
        {teller.map((t, i) => (
          <React.Fragment key={i}>
            <label className="s-flabel">{i === 0 ? 'Telefon *' : `Telefon ${i + 1}`}</label>
            <div className="ym-telrow">
              <input className={`s-input tabular ${(i === 0 && hata && (hata.tel || hata.mukerrer)) || (hata && hata['tel' + i]) ? 'err' : ''}`} inputMode="tel" value={t} onChange={(e) => telDegis(i, e.target.value)} placeholder="05XX XXX XX XX" />
              {i > 0 && <button className="ym-telsil" onClick={() => setTeller((p) => p.filter((_, k) => k !== i))} aria-label="Telefonu sil"><Icon name="x" size={17} sw={2.2} color="var(--muted)" /></button>}
            </div>
            {i === 0 && hata && hata.tel && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Geçerli telefon girin (10-11 hane)</div>}
            {i === 0 && hata && hata.mukerrer && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Bu numara zaten kayıtlı: <b>{hata.mukerrer}</b></div>}
            {i > 0 && hata && hata['tel' + i] && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Geçerli telefon girin ya da boş bırakın</div>}
          </React.Fragment>
        ))}
        {teller.length < 3 && <button className="ym-telekle" onClick={() => setTeller((p) => [...p, ''])}>+ Telefon ekle ({teller.length}/3)</button>}
        <div className="ym-lblrow">
          <label className="s-flabel" style={{ margin: 0 }}>Adres</label>
          {konum
            ? <span className="ym-konumtag"><Icon name="check" size={12} sw={2.8} color="var(--ok)" />Konum alındı · <span className="tabular">{konum.lat.toFixed(4)}, {konum.lng.toFixed(4)}</span></span>
            : <button className="ym-konumlink" onClick={konumAl}><Icon name="pin" size={13} sw={2.2} color="var(--accent)" />Konum Al</button>}
        </div>
        <input className="s-input" value={adres} onChange={(e) => { setAdres(e.target.value); setKonum(null); setAdaylar(null); if (hata) setHata(null); }} placeholder="Mahalle, sokak, no" />
        {hata && hata.adres && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Önce adresi yazın</div>}
        {adaylar && !konum && (
          <div className="aday-blok">
            <div className="aday-info"><Icon name="info" size={14} sw={2} color="var(--accent)" />API sonuçları — adres bazen yanlış algılanır, doğrusunu seçin.</div>
            {adaylar.map((a) => (
              <button key={a.id} className="aday-row" onClick={() => { setKonum({ lat: a.lat, lng: a.lng }); setAdaylar(null); }}>
                <span className="aday-ic"><Icon name="pin" size={15} sw={2.1} color="var(--accent)" /></span>
                <span className="aday-mid"><span className="aday-t">{a.metin}</span><span className="aday-s tabular">{a.lat.toFixed(4)}, {a.lng.toFixed(4)}</span></span>
              </button>
            ))}
          </div>
        )}
        <label className="s-flabel">Bölge</label>
        <input className="s-input" value={bolge} onChange={(e) => setBolge(e.target.value)} placeholder="Ör. Kepez" />
        <label className="s-flabel">Not</label>
        <textarea className="s-textarea" value={not} onChange={(e) => setNot(e.target.value)} rows={2} placeholder="Zil, kapı kodu, özel durum…" />
        <button className="btn btn-p" style={{ marginTop: 16 }} onClick={kaydet}>Müşteriyi Kaydet</button>
      </div>
    </Sheet>
  );
}

// ── Müşteri bilgilerini düzenle (sheet) ──
function MusteriDuzenle({ acik, m, digerleri, onKapat, onKaydet }) {
  const [ad, setAd] = React.useState('');
  const [teller, setTeller] = React.useState(['']);
  const [adres, setAdres] = React.useState('');
  const [bolge, setBolge] = React.useState('');
  const [not, setNot] = React.useState('');
  const [hata, setHata] = React.useState(null);
  React.useEffect(() => {
    if (acik && m) {
      setAd(m.ad || '');
      setTeller((m.telefonlar || []).length ? m.telefonlar.map((t) => t.no) : ['']);
      const a = (m.adresler || [])[0];
      setAdres(a ? a.metin : ''); setBolge(a && a.bolge !== '—' ? a.bolge : '');
      setNot(m.not || ''); setHata(null);
    }
  }, [acik, m]);
  const telDegis = (i, v) => { setTeller((p) => p.map((x, k) => k === i ? v : x)); setHata(null); };
  const kaydet = () => {
    const e = {};
    if (ad.trim().length < 2) e.ad = true;
    const h0 = teller[0].replace(/\D/g, '');
    if (h0.length < 10 || h0.length > 11) e.tel = true;
    teller.forEach((t, i) => { if (i > 0 && t.trim()) { const h = t.replace(/\D/g, ''); if (h.length < 10 || h.length > 11) e['tel' + i] = true; } });
    if (!e.tel && digerleri) {
      const sahip = digerleri.find((mm) => mm.id !== m.id && (mm.telefonlar || []).some((t) => t.no.replace(/\D/g, '') === h0));
      if (sahip) e.mukerrer = sahip.ad;
    }
    if (Object.keys(e).length) { setHata(e); return; }
    const telefonlar = teller.map((t) => t.trim()).filter((t) => t.replace(/\D/g, '').length >= 10)
      .map((no, i) => ({ no, etiket: i === 0 ? 'Cep' : 'Telefon ' + (i + 1), birincil: i === 0 }));
    onKaydet({ ad: ad.trim(), telefonlar, adres: adres.trim(), bolge: bolge.trim(), not: not.trim() });
  };
  return (
    <Sheet open={acik} onClose={onKapat} baslik="Müşteriyi Düzenle">
      <div className="sb-form">
        <label className="s-flabel">Ad Soyad *</label>
        <input className={`s-input ${hata && hata.ad ? 'err' : ''}`} value={ad} onChange={(e) => { setAd(e.target.value); setHata(null); }} />
        {hata && hata.ad && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Ad soyad girin</div>}
        {teller.map((t, i) => (
          <React.Fragment key={i}>
            <label className="s-flabel">{i === 0 ? 'Telefon *' : `Telefon ${i + 1}`}</label>
            <div className="ym-telrow">
              <input className={`s-input tabular ${(i === 0 && hata && (hata.tel || hata.mukerrer)) || (hata && hata['tel' + i]) ? 'err' : ''}`} inputMode="tel" value={t} onChange={(e) => telDegis(i, e.target.value)} placeholder="05XX XXX XX XX" />
              {i > 0 && <button className="ym-telsil" onClick={() => setTeller((p) => p.filter((_, k) => k !== i))} aria-label="Telefonu sil"><Icon name="x" size={17} sw={2.2} color="var(--muted)" /></button>}
            </div>
            {i === 0 && hata && hata.tel && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Geçerli telefon girin (10-11 hane)</div>}
            {i === 0 && hata && hata.mukerrer && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Bu numara zaten kayıtlı: <b>{hata.mukerrer}</b></div>}
            {i > 0 && hata && hata['tel' + i] && <div className="ym-err"><Icon name="alert" size={13} sw={2.2} color="var(--danger)" />Geçerli telefon girin ya da boş bırakın</div>}
          </React.Fragment>
        ))}
        {teller.length < 3 && <button className="ym-telekle" onClick={() => setTeller((p) => [...p, ''])}>+ Telefon ekle ({teller.length}/3)</button>}
        <label className="s-flabel">Adres</label>
        <input className="s-input" value={adres} onChange={(e) => setAdres(e.target.value)} placeholder="Mahalle, sokak, no" />
        <label className="s-flabel">Bölge</label>
        <input className="s-input" value={bolge} onChange={(e) => setBolge(e.target.value)} placeholder="Ör. Kepez" />
        <label className="s-flabel">Not</label>
        <textarea className="s-textarea" value={not} onChange={(e) => setNot(e.target.value)} rows={2} placeholder="Zil, kapı kodu, özel durum…" />
        <button className="btn btn-p" style={{ marginTop: 16 }} onClick={kaydet}>Değişiklikleri Kaydet</button>
      </div>
    </Sheet>
  );
}

Object.assign(window, { MusterilerEkran, MusteriDetay, YeniMusteri, MusteriDuzenle, adresAdaylari });
