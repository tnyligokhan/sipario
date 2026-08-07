// s-ayarlar.jsx — Ayarlar sayfası: görünüm, kurulum/izinler, işletme, hakkında. → window

function AyarlarEkran({ tema, onTema, onSihirbaz, onCagriSim, onGeri, onPing, isletme, onIsletme }) {
  const [simAcik, setSimAcik] = React.useState(false);
  const SIMLER = [
    { k: 'borclu', ad: 'Kayıtlı · Borçlu', alt: 'Ahmet Yılmaz · 340,00 ₺ borç', no: '0532 415 22 90', renk: 'var(--danger)' },
    { k: 'temiz', ad: 'Kayıtlı · Temiz', alt: 'Selin Kaya · hesap temiz', no: '0533 220 78 41', renk: 'var(--ok)' },
    { k: 'alacak', ad: 'Kayıtlı · Alacaklı', alt: 'Murat Öz · 120,00 ₺ alacak', no: '0542 907 63 22', renk: 'var(--ok)' },
    { k: 'kayitsiz', ad: 'Kayıtsız Numara', alt: 'Defterde olmayan arayan', no: '0216 555 01 88', renk: 'var(--muted)' },
  ];
  return (
    <div className="ekran">
      <Ust baslik="Ayarlar" onGeri={onGeri} />
      <div className="ekran-govde">
        <div className="gs-baslik">Görünüm</div>
        <div className="ayar-kart">
          <button className={`ayar-row ${tema === 'koyu' ? 'on' : ''}`} onClick={onTema}>
            <span className="cek-ic"><Icon name="moon" size={18} sw={1.9} color="var(--accent)" /></span>
            <span className="cek-lbl">Koyu tema</span>
            <span className={`aktif-knob ${tema === 'koyu' ? 'on' : ''}`} data-on={tema === 'koyu'} />
          </button>
        </div>

        <div className="gs-baslik">Arayan Tanıma</div>
        <div className="ayar-kart">
          <button className="ayar-row" onClick={onSihirbaz}>
            <span className="cek-ic"><Icon name="phone" size={18} sw={1.9} color="var(--accent)" /></span>
            <span className="cek-lbl">Kurulum ve izinler</span>
            <Icon name="chevR" size={17} sw={2} color="var(--line-2)" />
          </button>
          <button className="ayar-row" onClick={() => setSimAcik(true)}>
            <span className="cek-ic"><Icon name="phoneCall" size={18} sw={1.9} color="var(--accent)" /></span>
            <span className="cek-lbl">Gelen çağrıyı dene<span className="ayar-alt">4 varyant: borçlu, temiz, alacaklı, kayıtsız</span></span>
            <Icon name="chevR" size={17} sw={2} color="var(--line-2)" />
          </button>
        </div>

        <div className="gs-baslik">İşletme</div>
        <div className="ayar-kart">
          <div className="ayar-row salt">
            <span className="cek-ic"><Icon name="home" size={18} sw={1.9} color="var(--accent)" /></span>
            <span className="cek-lbl">{isletme.ad}<span className="ayar-alt">{isletme.sahip} · <span className="tabular">{isletme.telefon}</span></span></span>
            <button className="ust-metin" onClick={onIsletme}>Düzenle</button>
          </div>
        </div>

        <div className="gs-baslik">Hakkında</div>
        <div className="ayar-kart">
          <div className="ayar-row salt"><span className="cek-lbl" style={{ paddingLeft: 4 }}>Sürüm<span className="ayar-alt">Sipario 3.2</span></span></div>
          <div className="ayar-row salt"><span className="cek-lbl" style={{ paddingLeft: 4 }}>Lisans<span className="ayar-alt tabular">248 gün kaldı · oto sıralama 34 hak</span></span></div>
        </div>
      </div>

      <Sheet open={simAcik} onClose={() => setSimAcik(false)} baslik="Çağrı Simülasyonu">
        <div className="sr-list">
          {SIMLER.map((s) => (
            <button key={s.k} className="aday-row" style={{ marginTop: 0, marginBottom: 6 }} onClick={() => { setSimAcik(false); setTimeout(() => onCagriSim(s.no), 250); }}>
              <span className="aday-ic"><Icon name="phoneCall" size={15} sw={2.1} color={s.renk} /></span>
              <span className="aday-mid"><span className="aday-t">{s.ad}</span><span className="aday-s">{s.alt} · <span className="tabular">{s.no}</span></span></span>
              <Icon name="chevR" size={16} sw={2} color="var(--line-2)" />
            </button>
          ))}
        </div>
      </Sheet>
    </div>
  );
}

Object.assign(window, { AyarlarEkran });
