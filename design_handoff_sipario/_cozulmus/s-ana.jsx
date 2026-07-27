// s-ana.jsx — Ana ekran (karşılama): koyu hero + bento özet + hızlı aksiyonlar + son aktivite. → window

function AnaEkran({ siparisler, musteriler, onMenu, onGit, onYeniSiparis, onAramaAc }) {
  const acik = siparisler.filter((o) => o.durum === 'acik');
  const teslim = siparisler.filter((o) => o.durum === 'teslim');
  const kasa = teslim.reduce((s, o) => s + (o.odeme && o.odeme !== 'veresiye' ? siparisTutar(o) : 0), 0);
  const veresiye = musteriler.reduce((s, m) => s + Math.max(0, m.bakiye), 0);
  const borclu = musteriler.filter((m) => m.bakiye > 0).length;
  const saat = 10; // demo
  const selam = saat < 12 ? 'Günaydın' : saat < 18 ? 'İyi günler' : 'İyi akşamlar';

  // Son aktivite: teslim edilen siparişler
  const aktivite = teslim.slice(0, 3);

  return (
    <div className="ekran ana">
      <div className="ana-hero">
        <div className="ana-hero-ust">
          <div>
            <div className="ana-selam">{selam}</div>
            <div className="ana-isletme">{ISLETME.sahip}</div>
          </div>
          <button className="ana-menu" onClick={onMenu} aria-label="Menü"><Icon name="menu" size={20} sw={2} color="#fff" /></button>
        </div>
        <div className="ana-sync"><i />Senkron güncel · <span className="tabular">10:32</span></div>
      </div>

      <div className="ekran-govde ana-govde">
        <div className="bento">
          <button className="bento-k birincil" onClick={() => onGit('siparis')}>
            <span className="bento-l">Açık Sipariş</span>
            <span className="bento-v tabular">{acik.length}</span>
            <span className="bento-alt">{acik.length > 0 ? 'teslim bekliyor' : 'hepsi tamam'}</span>
          </button>
          <button className="bento-k" onClick={() => onGit('gunsonu')}>
            <span className="bento-l">Bugün Kasa</span>
            <span className="bento-v kucuk tabular">{fmtTL(kasa)}</span>
            <span className="bento-alt">{teslim.length} teslimat</span>
          </button>
          <button className="bento-k" onClick={() => onGit('musteri')}>
            <span className="bento-l">Açık Veresiye</span>
            <span className="bento-v kucuk tabular eksi">{fmtTL(veresiye)}</span>
            <span className="bento-alt">{borclu} borçlu müşteri</span>
          </button>
          <button className="bento-k" onClick={() => onAramaAc(ARAMALAR[0])}>
            <span className="bento-l">Son Arama</span>
            <span className="bento-v kucuk" style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '100%' }}>{ARAMALAR[0].ad || ARAMALAR[0].no}</span>
            <span className={`bento-alt ${ARAMALAR[0].tip === 'cevapsiz' ? 'eksi' : ''}`}>{ARAMALAR[0].tip === 'cevapsiz' ? 'cevapsız' : 'gelen'} · <span className="tabular">{ARAMALAR[0].saat}</span></span>
          </button>
        </div>

        <button className="ana-cta" onClick={onYeniSiparis}>
          <span className="ana-cta-ic"><Icon name="plus" size={20} sw={2.4} color="#fff" /></span>
          <span className="ana-cta-t">Yeni Sipariş</span>
          <Icon name="chevR" size={18} sw={2.2} color="rgba(255,255,255,.55)" />
        </button>

        <div className="ana-baslik">Son aktivite</div>
        {aktivite.length === 0
          ? <div className="ana-bos">Bugün henüz hareket yok.</div>
          : <div className="akt-list">
              {aktivite.map((o) => (
                <button key={o.id} className="akt-row" onClick={() => onGit('siparisDetay', o)}>
                  <span className="akt-ic"><Icon name="check" size={15} sw={2.4} color="var(--ok)" /></span>
                  <span className="akt-mid">
                    <span className="akt-t">{o.musteriAd}</span>
                    <span className="akt-s">{siparisOzet(o)} · {ODEME_TIPLERI[o.odeme]?.label || ''}</span>
                  </span>
                  <span className="akt-amt tabular">{fmtTL(siparisTutar(o))}</span>
                </button>
              ))}
            </div>}
      </div>
    </div>
  );
}

Object.assign(window, { AnaEkran });
