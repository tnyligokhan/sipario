// s-gunsonu.jsx — Gün Sonu: kurye bazlı özet + hesabı kapat (kasa devri içeride) + arşiv. → window

function GunSonuEkran({ siparisler, musteriler, kuryeler, arsiv, onKapat, onMenu, onPing }) {
  const adlar = ['Tümü', ...kuryeler.filter((k) => k.aktif).map((k) => k.ad)];
  const [kurye, setKurye] = React.useState('Tümü');
  const [kapatAcik, setKapatAcik] = React.useState(false);
  const [arsivDetay, setArsivDetay] = React.useState(null);
  const [sayilan, setSayilan] = React.useState('');
  const [not, setNot] = React.useState('');

  const teslim = siparisler.filter((o) => o.durum === 'teslim' && (kurye === 'Tümü' || o.kurye === kurye));
  const kasa = {};
  Object.keys(ODEME_TIPLERI).forEach((k) => kasa[k] = 0);
  teslim.forEach((o) => { if (o.odeme) kasa[o.odeme] += siparisTutar(o); });
  const toplamTahsilat = kasa.nakit + kasa.kart + kasa.havale;
  const acikVeresiye = musteriler.reduce((s, m) => s + Math.max(0, m.bakiye), 0);
  const borclular = musteriler.filter((m) => m.bakiye > 0).sort((a, b) => b.bakiye - a.bakiye);
  // Kapatma mantığı: gün kapalıysa her şey kilitli; kısmi kurye kapanışı varken gün kapanamaz
  const aktifAdlar = kuryeler.filter((k) => k.aktif).map((k) => k.ad);
  const gunKapali = arsiv.some((a) => a.kurye === 'Tümü');
  const kuryeKapali = (ad) => arsiv.some((a) => a.kurye === ad);
  const acikKuryeler = aktifAdlar.filter((ad) => !kuryeKapali(ad));
  const kapali = gunKapali || (kurye !== 'Tümü' && kuryeKapali(kurye));
  const gunEngel = kurye === 'Tümü' && !gunKapali && acikKuryeler.length > 0 && acikKuryeler.length < aktifAdlar.length;

  const s = sayilan === '' ? null : Number(sayilan) * 100;
  const fark = s === null ? 0 : s - kasa.nakit;

  const kapat = () => {
    onKapat({ id: 'ar' + Date.now(), kurye, tarih: 'Bugün 18:05', teslimat: teslim.length, toplam: toplamTahsilat, beklenen: kasa.nakit, sayilan: s, fark, not, kasa: { ...kasa } });
    setKapatAcik(false); setSayilan(''); setNot('');
  };

  return (
    <div className="ekran">
      <Ust baslik="Gün Sonu" alt="Bugün" onMenu={onMenu} />
      <div className="segtab">
        {adlar.map((a) => (
          <button key={a} className={`segtab-b ${kurye === a ? 'on' : ''}`} onClick={() => setKurye(a)}>{a}</button>
        ))}
      </div>
      <div className="ekran-govde">
        {kapali && <div className="gs-kapali"><Icon name="check" size={15} sw={2.4} color="var(--ok)" />{gunKapali ? 'Günün hesabı kapatıldı — tüm hesaplar kilitli.' : `${kurye} hesabı kapatıldı ve arşivlendi.`}</div>}

        <div className="gs-baslik">Kasa Özeti{kurye !== 'Tümü' ? ` · ${kurye}` : ''}</div>
        <div className="gs-kasa">
          {Object.entries(ODEME_TIPLERI).filter(([k]) => k !== 'veresiye').map(([k, v]) => (
            <div key={k} className="gs-krow">
              <span className="gs-krow-l">{v.label}</span>
              <span className="gs-krow-v tabular">{fmtTL(kasa[k])}</span>
            </div>
          ))}
          <div className="gs-krow toplam">
            <span className="gs-krow-l">Toplam Tahsilat · {teslim.length} teslimat</span>
            <span className="gs-krow-v tabular">{fmtTL(toplamTahsilat)}</span>
          </div>
        </div>

        {kurye === 'Tümü' && (
          <React.Fragment>
            <div className="gs-baslik">Açık Veresiye</div>
            <div className="gs-veresiye">
              <div className="gs-vtop"><span>Toplam açık borç</span><b className="tabular" style={{ color: 'var(--danger)' }}>{fmtTL(acikVeresiye)}</b></div>
              {borclular.length === 0
                ? <div className="gs-temiz"><Icon name="check" size={16} sw={2.4} color="var(--ok)" />Borçlu müşteri yok</div>
                : borclular.map((m) => (
                  <div key={m.id} className="gs-brow">
                    <span className="gs-brow-nm">{m.ad}</span>
                    <span className="gs-brow-v tabular" style={{ color: 'var(--danger)' }}>{fmtTL(m.bakiye)}</span>
                  </div>
                ))}
            </div>
          </React.Fragment>
        )}

        {arsiv.length > 0 && (
          <React.Fragment>
            <div className="gs-baslik">Arşiv</div>
            <div className="gs-arsiv">
              {arsiv.map((a) => (
                <button key={a.id} className="gs-arow" onClick={() => setArsivDetay(a)}>
                  <span className="gs-arow-ic"><Icon name="lock" size={15} sw={2} color="var(--muted)" /></span>
                  <span className="gs-arow-mid">
                    <span className="gs-arow-t">{a.kurye === 'Tümü' ? 'Gün hesabı' : a.kurye}</span>
                    <span className="gs-arow-s tabular">{a.tarih} · {a.teslimat} teslimat{a.fark !== 0 && a.sayilan !== null ? ` · fark ${fmtTL(a.fark)}` : ''}</span>
                  </span>
                  <span className="gs-arow-v tabular">{fmtTL(a.toplam)}</span>
                  <Icon name="chevR" size={16} sw={2} color="var(--line-2)" />
                </button>
              ))}
            </div>
          </React.Fragment>
        )}
      </div>

      <div className="ys-alt" style={{ flexWrap: 'wrap' }}>
        {gunEngel && <div className="gs-engel"><Icon name="alert" size={14} sw={2.2} color="var(--warn)" /><span>Önce açık kurye hesaplarını kapatın: <b>{acikKuryeler.join(', ')}</b></span></div>}
        {kapali ? (
          <div className="gs-alt-kapali"><Icon name="check" size={17} sw={2.6} color="var(--ok)" />{gunKapali ? 'Gün kapatıldı — arşivde' : `${kurye} hesabı kapatıldı — arşivde`}</div>
        ) : (
          <React.Fragment>
            <div className="ys-toplam"><span>{kurye === 'Tümü' ? 'Bugün tahsilat' : `${kurye} · tahsilat`}</span><b className="tabular">{fmtTL(toplamTahsilat)}</b></div>
            <button className="btn btn-p" disabled={gunEngel} style={{ opacity: gunEngel ? .55 : 1 }} onClick={() => setKapatAcik(true)}>
              <Icon name="lock" size={17} sw={2.2} color="#fff" />{kurye === 'Tümü' ? 'Günü Kapat' : 'Hesabı Kapat'}
            </button>
          </React.Fragment>
        )}
      </div>

      <Sheet open={kapatAcik} onClose={() => setKapatAcik(false)} baslik="Hesabı Kapat · Kasa Devri">
        <div className="sb-form">
          {teslim.length === 0 && <div className="ym-err" style={{ marginTop: 4 }}><Icon name="info" size={13} sw={2.2} color="var(--warn)" /><span style={{ color: 'var(--warn)' }}>Bu hesapta bugün hiç teslimat yok — yine de kapatabilirsiniz.</span></div>}
          <div className="kd-row"><span>Beklenen nakit{kurye !== 'Tümü' ? ` (${kurye})` : ''}</span><b className="tabular">{fmtTL(kasa.nakit)}</b></div>
          <label className="s-flabel">Sayılan nakit (₺)</label>
          <input className="s-input tabular kd-input" inputMode="numeric" value={sayilan} onChange={(e) => setSayilan(e.target.value.replace(/\D/g, ''))} placeholder="0" autoFocus />
          {s !== null && (
            <div className={`kd-fark ${fark < 0 ? 'eksik' : fark > 0 ? 'fazla' : 'tam'}`}>
              <span>{fark < 0 ? 'Eksik' : fark > 0 ? 'Fazla' : 'Tam'}</span>
              <b className="tabular">{fmtTL(Math.abs(fark))}</b>
            </div>
          )}
          {fark < 0 && s !== null && <div className="teslim-uyari"><Icon name="alert" size={15} sw={2.2} color="var(--danger)" />Eksik tutar kanıt olarak arşive geçer; kapatma engellenmez.</div>}
          <label className="s-flabel">Not (opsiyonel)</label>
          <textarea className="s-textarea" value={not} onChange={(e) => setNot(e.target.value)} rows={2} placeholder="Fark açıklaması, devreden…" />
          <button className="btn btn-p" style={{ marginTop: 16 }} disabled={s === null} onClick={kapat}>
            <Icon name="lock" size={17} sw={2.2} color="#fff" />Kapat ve Arşivle
          </button>
        </div>
      </Sheet>

      <Sheet open={!!arsivDetay} onClose={() => setArsivDetay(null)} baslik={arsivDetay ? (arsivDetay.kurye === 'Tümü' ? 'Gün Hesabı · Arşiv' : `${arsivDetay.kurye} · Arşiv`) : ''}>
        {arsivDetay && (
          <div className="sb-form">
            <div className="gs-kapali" style={{ marginTop: 2 }}><Icon name="lock" size={14} sw={2.2} color="var(--ok)" />{arsivDetay.tarih} · kapatıldı · {arsivDetay.teslimat} teslimat</div>
            <div className="gs-kasa" style={{ marginTop: 12 }}>
              {arsivDetay.kasa && Object.entries(ODEME_TIPLERI).filter(([k]) => k !== 'veresiye').map(([k, v]) => (
                <div key={k} className="gs-krow"><span className="gs-krow-l">{v.label}</span><span className="gs-krow-v tabular">{fmtTL(arsivDetay.kasa[k] || 0)}</span></div>
              ))}
              <div className="gs-krow toplam"><span className="gs-krow-l">Toplam Tahsilat</span><span className="gs-krow-v tabular">{fmtTL(arsivDetay.toplam)}</span></div>
            </div>
            <div className="gs-kasa" style={{ marginTop: 10 }}>
              <div className="gs-krow"><span className="gs-krow-l">Beklenen nakit</span><span className="gs-krow-v tabular">{fmtTL(arsivDetay.beklenen)}</span></div>
              <div className="gs-krow"><span className="gs-krow-l">Sayılan nakit</span><span className="gs-krow-v tabular">{arsivDetay.sayilan === null ? '—' : fmtTL(arsivDetay.sayilan)}</span></div>
              <div className="gs-krow"><span className="gs-krow-l">Fark</span><span className="gs-krow-v tabular" style={{ color: arsivDetay.fark < 0 ? 'var(--danger)' : arsivDetay.fark > 0 ? 'var(--warn)' : 'var(--ok)' }}>{arsivDetay.fark === 0 ? 'Tam' : fmtTL(arsivDetay.fark)}</span></div>
            </div>
            {arsivDetay.not && <div className="md-not" style={{ marginTop: 10 }}><Icon name="info" size={15} sw={2} color="var(--warn)" /><span>{arsivDetay.not}</span></div>}
          </div>
        )}
      </Sheet>
    </div>
  );
}

Object.assign(window, { GunSonuEkran });
