// s-cagri.jsx — Gelen çağrı kartı (Android overlay). Varyantlar: kayıtlı (borçlu/temiz/alacaklı) + kayıtsız. → window

function CagriKarti({ numara, onKapat, onSiparis, onDefter, onKaydet }) {
  const norm = String(numara || '').replace(/\D/g, '').slice(-10);
  const mus = MUSTERILER.find((m) => (m.telefonlar || []).some((t) => t.no.replace(/\D/g, '').slice(-10) === norm));
  const kayitli = !!mus;
  const bd = mus ? bakiyeDurum(mus.bakiye) : null;
  const adres = mus ? birincilAdres(mus) : null;
  const sonH = mus && (mus.hareketler || [])[0];
  const sonSip = mus ? SIPARISLER.find((o) => o.musteriId === mus.id) : null;

  return (
    <div className="cagri-overlay" onClick={onKapat}>
      <div className="cagri-kart" onClick={(e) => e.stopPropagation()}>
        <div className="cagri-top">
          <span className="cagri-live"><i />Gelen Çağrı</span>
          <span className="cagri-since tabular"><Icon name="clock" size={12} sw={2} color="var(--muted)" />şimdi</span>
          <button className="sheet-x" onClick={onKapat} aria-label="Kapat"><Icon name="x" size={20} sw={2.2} color="var(--muted)" /></button>
        </div>

        {kayitli ? (
          <React.Fragment>
            <div className="cagri-kim">
              <span className="cagri-kim-mid">
                <span className="cagri-name">{mus.ad}</span>
                <span className="cagri-num tabular"><span className="srow-kod tabular">{'M-' + String(mus.id).replace(/\D/g, '').padStart(3, '0')}</span>{numara}</span>
              </span>
              {mus.bakiye === 0
                ? <span className="pill" style={{ background: 'var(--ok-soft)', color: 'var(--ok)' }}>Temiz</span>
                : <span className="pill" style={{ background: mus.bakiye > 0 ? 'var(--danger-soft)' : 'var(--ok-soft)', color: bd.renk }}>{bd.tag}</span>}
            </div>

            {mus.bakiye !== 0 &&
            <div className="cagri-bal" style={{ background: mus.bakiye > 0 ? 'var(--danger-soft)' : 'var(--ok-soft)' }}>
              <span className="cagri-bal-l" style={{ color: bd.renk }}>{mus.bakiye > 0 ? 'Açık Borç' : 'Alacağı Var'}</span>
              <span className="cagri-bal-v tabular" style={{ color: bd.renk }}>{fmtTL(Math.abs(mus.bakiye))}</span>
            </div>}

            <div className="cagri-bilgi">
              {adres && <div className="cagri-brow"><Icon name="pin" size={14} sw={2.1} color={adres.konum ? 'var(--ok)' : 'var(--muted)'} /><span>{[adres.metin, adres.bolge].filter((x) => x && x !== '—').join(' — ')}</span>{adres.konum && <Icon name="check" size={12} sw={3} color="var(--ok)" />}</div>}
              {sonSip && <div className="cagri-brow"><Icon name="box" size={14} sw={2.1} color="var(--muted)" /><span>Son sipariş: {siparisOzet(sonSip)} · <span className="tabular">{sonSip.saat}</span></span></div>}
              {!sonSip && sonH && <div className="cagri-brow"><Icon name="book" size={14} sw={2.1} color="var(--muted)" /><span>Son hareket: {sonH.not || (sonH.tip === 'tahsilat' ? 'Tahsilat' : 'Borç')} · <span className="tabular">{sonH.saat}</span></span></div>}
              {mus.not && <div className="cagri-brow warn"><Icon name="info" size={14} sw={2.1} color="var(--warn)" /><span>{mus.not}</span></div>}
            </div>

            <div className="cagri-acts">
              <button className="btn btn-p" onClick={() => onSiparis(mus)}><Icon name="plus" size={18} sw={2.4} color="#fff" />Sipariş Oluştur</button>
              <button className="btn btn-s" onClick={() => onDefter(mus)}><Icon name="book" size={17} sw={2} color="var(--ink)" />Defteri Aç</button>
            </div>
          </React.Fragment>
        ) : (
          <React.Fragment>
            <div className="cagri-kim">
              <span className="cagri-kim-mid">
                <span className="cagri-name tabular">{numara}</span>
                <span className="cagri-num">Bu numara defterinizde yok</span>
              </span>
              <span className="pill" style={{ background: 'var(--surface-2)', color: 'var(--ink-2)' }}>Kayıtsız</span>
            </div>
            <div className="cagri-acts">
              <button className="btn btn-p" onClick={() => onKaydet(numara)}><Icon name="userPlus" size={18} sw={2.2} color="#fff" />Müşteri Olarak Kaydet</button>
            </div>
          </React.Fragment>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { CagriKarti });
