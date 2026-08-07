// sw-giris.jsx — Giriş, işletme açma (3 adım), parola sıfırlama. → window

function KimlikKabuk({ kulak, baslik, aciklama, genis, children, altYazi }){
  const { git } = useYon();
  return (
    <main className="kimlik">
      <aside className="kimlik-sol gece">
        <button className="kimlik-marka" onClick={() => { git('ana'); window.scrollTo(0, 0); }}><Marka boy={38} koyu /></button>
        <div className="kimlik-govde">
          <p className="h2 kimlik-soz">“Defteri bıraktık. Ay sonunda tahsil edemediğimiz para 12 binden 3 bine düştü.”</p>
          <div className="kimlik-kim">
            <b>Hasan Yıldırım</b>
            <span className="kucuk">Yıldırım Su · Antalya</span>
          </div>
        </div>
        <div className="kimlik-alt">
          {SW_KANIT.map((k, i) => (
            <div className="kimlik-k" key={i}>
              <b>{k.v}</b><span className="mn k">{k.b}</span>
            </div>
          ))}
        </div>
      </aside>
      <section className="kimlik-sag">
        <div className={`kimlik-form ${genis ? 'genis' : ''}`}>
          {kulak && <span className="blm-kulak mn"><i />{kulak}</span>}
          <h1 className="h1 kimlik-h1">{baslik}</h1>
          {aciklama && <p className="gvd kimlik-lead">{aciklama}</p>}
          {children}
        </div>
        {altYazi && <div className="kimlik-dip kucuk">{altYazi}</div>}
      </section>
    </main>
  );
}

function GirisSayfa(){
  const { git, setOturum, setHesapDurum, bildir } = useYon();
  const [f, setF] = React.useState({ eposta: '', parola: '' });
  const [h, setH] = React.useState({});
  const [gor, setGor] = React.useState(false);
  const [bek, setBek] = React.useState(false);
  const dogrula = (k, v) => {
    if(k === 'eposta') return !v.trim() ? 'E-posta adresinizi girin' : !/^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i.test(v.trim()) ? 'Geçerli bir e-posta girin' : null;
    if(k === 'parola') return !v ? 'Parolanızı girin' : v.length < 6 ? 'Parola en az 6 karakter' : null;
    return null;
  };
  const blur = (k) => setH((x) => ({ ...x, [k]: dogrula(k, f[k]) }));
  const yaz = (k, v) => { setF((x) => ({ ...x, [k]: v })); if(h[k]) setH((x) => ({ ...x, [k]: null })); };
  const gonder = (e) => {
    e.preventDefault();
    const y = { eposta: dogrula('eposta', f.eposta), parola: dogrula('parola', f.parola) };
    setH(y);
    if(y.eposta || y.parola) return;
    setBek(true);
    setTimeout(() => { setBek(false); setOturum(true); setHesapDurum('aktif'); git('hesap'); window.scrollTo(0, 0); bildir('Hoş geldiniz, Mehmet Usta'); }, 700);
  };
  return (
    <KimlikKabuk kulak="Hesap" baslik="Tekrar hoş geldiniz."
      aciklama="Abonelik, fatura ve işletme bilgilerinizi yönetmek için giriş yapın."
      altYazi={<React.Fragment>Kurye ve tezgâh hesapları web’e girmez — onlar mobil uygulamadan firma koduyla giriş yapar.</React.Fragment>}>
      <form onSubmit={gonder} noValidate>
        <Alan etiket="E-posta" hata={h.eposta} id="g-eposta">
          <input id="g-eposta" className={`gir ${h.eposta ? 'yanlis' : ''}`} type="email" inputMode="email"
            autoComplete="email" placeholder="mehmet@merkezsubayi.com" value={f.eposta}
            onChange={(e) => yaz('eposta', e.target.value)} onBlur={() => blur('eposta')} />
        </Alan>
        <Alan etiket="Parola" hata={h.parola} id="g-parola"
          not={<button type="button" className="kimlik-link" onClick={() => { git('sifre'); window.scrollTo(0, 0); }}>Parolamı unuttum</button>}>
          <div className="gir-sarma">
            <input id="g-parola" className={`gir ${h.parola ? 'yanlis' : ''}`} type={gor ? 'text' : 'password'}
              autoComplete="current-password" placeholder="••••••••" value={f.parola}
              onChange={(e) => yaz('parola', e.target.value)} onBlur={() => blur('parola')} />
            <button type="button" className="gir-goz" onClick={() => setGor(!gor)} aria-label="Parolayı göster">
              <Ikon ad={gor ? 'gozKapali' : 'goz'} boy={19} kalin={1.9} />
            </button>
          </div>
        </Alan>
        <label className="onay" style={{ marginBottom: 24 }}>
          <input type="checkbox" defaultChecked /> Bu cihazda oturumumu açık tut
        </label>
        <button className="dg dg-a tam" type="submit" disabled={bek}>{bek ? <span className="donen" /> : 'Giriş yap'}</button>
      </form>
      <div className="kimlik-ayrac"><span>Hesabınız yok mu?</span></div>
      <button className="dg dg-c tam" onClick={() => { git('kayit'); window.scrollTo(0, 0); }}>İşletmenizi açın · 14 gün ücretsiz</button>
    </KimlikKabuk>
  );
}

const SW_SEKTOR_SEC = ['Su bayii', 'Tüp bayii', 'Manav / sebze-meyve', 'Kuruyemişçi', 'Market / bakkal', 'Fırın', 'Kırtasiye', 'Yem bayii', 'Halı yıkama', 'Diğer'];

function slugla(s){
  const h = { 'ç':'c','ğ':'g','ı':'i','İ':'i','ö':'o','ş':'s','ü':'u','Ç':'c','Ğ':'g','Ö':'o','Ş':'s','Ü':'u' };
  return String(s).trim().toLowerCase().replace(/[çğıİöşüÇĞÖŞÜ]/g, (c) => h[c] || c)
    .replace(/[^a-z0-9]+/g, '').slice(0, 18);
}

function KayitSayfa(){
  const { git, setOturum, setHesapDurum, bildir } = useYon();
  const [adim, setAdim] = React.useState(0);
  const [f, setF] = React.useState({ isletme: '', eposta: '', ad: '', parola: '', sektor: '', kod: '', kvkk: false });
  const [h, setH] = React.useState({});
  const [bek, setBek] = React.useState(false);
  const yaz = (k, v) => { setF((x) => ({ ...x, [k]: v })); if(h[k]) setH((x) => ({ ...x, [k]: null })); };
  const dg = {
    isletme: (v) => !v.trim() ? 'İşletme adını girin' : v.trim().length < 3 ? 'En az 3 karakter' : null,
    eposta: (v) => !v.trim() ? 'E-posta adresinizi girin' : !/^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i.test(v.trim()) ? 'Geçerli bir e-posta girin' : null,
    ad: (v) => !v.trim() ? 'Adınızı ve soyadınızı girin' : null,
    parola: (v) => !v ? 'Bir parola belirleyin' : v.length < 8 ? 'Parola en az 8 karakter olmalı' : null,
    kod: (v) => !v.trim() ? 'Firma kodu boş olamaz' : !/^[a-z0-9]{3,18}$/.test(v.trim()) ? 'Sadece küçük harf ve rakam, en az 3 karakter' : null,
  };
  const blur = (k) => setH((x) => ({ ...x, [k]: dg[k] ? dg[k](f[k]) : null }));
  const adimAlan = [['isletme', 'eposta'], ['ad', 'parola'], ['kod']];

  const ileri = (e) => {
    e.preventDefault();
    const y = {}; adimAlan[adim].forEach((k) => { y[k] = dg[k](f[k]); });
    setH((x) => ({ ...x, ...y }));
    if(Object.values(y).some(Boolean)) return;
    if(adim === 0){ if(!f.kod) yaz('kod', slugla(f.isletme)); setAdim(1); return; }
    if(adim === 1){ setAdim(2); return; }
    if(!f.kvkk){ setH((x) => ({ ...x, kvkk: 'Devam etmek için sözleşmeleri onaylayın' })); return; }
    setBek(true);
    setTimeout(() => { setBek(false); setAdim(3); }, 900);
  };

  if(adim === 3) return (
    <KimlikKabuk kulak="Hazır" baslik="İşletmeniz açıldı." genis
      aciklama="Deneme süreniz bugün başladı. Aşağıdaki firma kodunu ekibinize verin — mobil uygulamaya bu kodla girecekler.">
      <Pano etiket="Firma kodunuz" sinif="kod-pano"
        sag={<button className="dg dg-d gk" onClick={() => bildir('Firma kodu kopyalandı')}><Ikon ad="kopyala" boy={15} kalin={2} />Kopyala</button>}>
        <span className="kod-v">{f.kod}</span>
        <p className="kucuk" style={{ marginTop: 10 }}>Bu kod işletmenizin kimliğidir. Uygulamaya giriş ekranında firma kodu + kullanıcı adı + parola istenir.</p>
      </Pano>
      <div className="kayit-sonraki">
        {[['mobil', 'Uygulamayı indirin', 'Android için Play Store’dan “Sipario”yu aratın. iOS sürümü de mağazada.'],
          ['musteriler', 'Müşteri listenizi gönderin', 'Excel ya da telefon rehberi olarak destek@sipario.com.tr adresine iletin; aynı gün yükleyelim.'],
          ['cagri', 'Çağrı iznini verin', 'Uygulama ilk açılışta izin isteyecek. İzin verilmezse arayan tanıma çalışmaz.']].map((x, i) => (
          <div className="kayit-s" key={i}>
            <span className="kayit-s-n">{i + 1}</span>
            <div><h3 className="h4">{x[1]}</h3><p className="kucuk">{x[2]}</p></div>
          </div>
        ))}
      </div>
      <button className="dg dg-a tam" onClick={() => { setOturum(true); setHesapDurum('deneme'); git('hesap'); window.scrollTo(0, 0); }}>Hesap paneline git<Ikon ad="ok" boy={18} kalin={2.2} /></button>
    </KimlikKabuk>
  );

  return (
    <KimlikKabuk kulak="14 gün ücretsiz" baslik="İşletmenizi açalım."
      aciklama="Üç kısa adım, iki dakika. Kart bilgisi istemiyoruz — deneme bitince otomatik ücret alınmaz."
      altYazi="Zaten hesabınız var mı? Sağ üstten giriş yapabilirsiniz.">
      <Ilerleme adimlar={['İşletme', 'Yetkili', 'Firma kodu']} aktif={adim} />
      <form onSubmit={ileri} noValidate key={adim}>
        {adim === 0 && (
          <React.Fragment>
            <Alan etiket="İşletme adı" hata={h.isletme} id="k-isl" ipucu="Müşterilerinizin sizi tanıdığı isim. Sonra değiştirilebilir.">
              <input id="k-isl" className={`gir ${h.isletme ? 'yanlis' : ''}`} autoComplete="organization"
                placeholder="Merkez Su Bayii" value={f.isletme}
                onChange={(e) => yaz('isletme', e.target.value)} onBlur={() => blur('isletme')} />
            </Alan>
            <Alan etiket="E-posta" hata={h.eposta} id="k-eposta" ipucu="Fatura ve hesap bildirimleri buraya gelir.">
              <input id="k-eposta" className={`gir ${h.eposta ? 'yanlis' : ''}`} type="email" inputMode="email"
                autoComplete="email" placeholder="mehmet@merkezsubayi.com" value={f.eposta}
                onChange={(e) => yaz('eposta', e.target.value)} onBlur={() => blur('eposta')} />
            </Alan>
          </React.Fragment>
        )}
        {adim === 1 && (
          <React.Fragment>
            <Alan etiket="Ad soyad" hata={h.ad} id="k-ad">
              <input id="k-ad" className={`gir ${h.ad ? 'yanlis' : ''}`} autoComplete="name"
                placeholder="Mehmet Yılmaz" value={f.ad}
                onChange={(e) => yaz('ad', e.target.value)} onBlur={() => blur('ad')} />
            </Alan>
            <Alan etiket="Parola" hata={h.parola} id="k-parola" ipucu="En az 8 karakter. Ekibinizle paylaşmayın — herkesin kendi hesabı olur.">
              <input id="k-parola" className={`gir ${h.parola ? 'yanlis' : ''}`} type="password"
                autoComplete="new-password" placeholder="••••••••" value={f.parola}
                onChange={(e) => yaz('parola', e.target.value)} onBlur={() => blur('parola')} />
            </Alan>
            <Alan etiket="Sektör" not="isteğe bağlı" id="k-sek" ipucu="Ürün kataloğunuzu hazır örneklerle başlatmamız için.">
              <select id="k-sek" className="gir" value={f.sektor} onChange={(e) => yaz('sektor', e.target.value)}>
                <option value="">Seçmek istemiyorum</option>
                {SW_SEKTOR_SEC.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </Alan>
          </React.Fragment>
        )}
        {adim === 2 && (
          <React.Fragment>
            <Alan etiket="Firma kodu" hata={h.kod} id="k-kod"
              ipucu="Ekibiniz mobil uygulamaya bu kodla girer. Küçük harf ve rakam; boşluk yok.">
              <div className="kod-gir">
                <span className="kod-on mn">sipario.com.tr /</span>
                <input id="k-kod" className={`gir ${h.kod ? 'yanlis' : ''}`} value={f.kod} autoCapitalize="none"
                  onChange={(e) => yaz('kod', e.target.value.toLowerCase().replace(/[^a-z0-9]/g, ''))} onBlur={() => blur('kod')} />
              </div>
            </Alan>
            <Pano ince duz sinif="ozet-pano" sikIc>
              <div className="ozet-r"><span>İşletme</span><b>{f.isletme}</b></div>
              <div className="ozet-r"><span>Yetkili</span><b>{f.ad}</b></div>
              <div className="ozet-r"><span>E-posta</span><b>{f.eposta}</b></div>
              <div className="ozet-r"><span>Plan</span><b>Sipario · 14 gün ücretsiz</b></div>
            </Pano>
            <label className="onay" style={{ margin: '20px 0 6px' }}>
              <input type="checkbox" checked={f.kvkk} onChange={(e) => { yaz('kvkk', e.target.checked); setH((x) => ({ ...x, kvkk: null })); }} />
              <span><a href="#yasal" onClick={(e) => e.preventDefault()}>Mesafeli satış sözleşmesi</a>, <a href="#yasal" onClick={(e) => e.preventDefault()}>kullanım koşulları</a> ve <a href="#yasal" onClick={(e) => e.preventDefault()}>KVKK aydınlatma metnini</a> okudum, kabul ediyorum.</span>
            </label>
            {h.kvkk && <span className="hata" style={{ marginBottom: 14 }}><Ikon ad="uyari" boy={14} kalin={2.3} />{h.kvkk}</span>}
          </React.Fragment>
        )}
        <div className="kayit-dg">
          {adim > 0 && <button type="button" className="dg dg-c" onClick={() => setAdim(adim - 1)}><Ikon ad="okSol" boy={18} kalin={2.2} />Geri</button>}
          <button className="dg dg-a" type="submit" disabled={bek} style={{ flex: 1 }}>
            {bek ? <span className="donen" /> : adim === 2 ? 'İşletmeyi aç' : 'Devam et'}
            {!bek && <Ikon ad="ok" boy={18} kalin={2.2} />}
          </button>
        </div>
      </form>
    </KimlikKabuk>
  );
}

function SifreSayfa(){
  const { git } = useYon();
  const [asama, setAsama] = React.useState(0);
  const [eposta, setEposta] = React.useState('');
  const [h, setH] = React.useState(null);
  const [bek, setBek] = React.useState(false);
  const gonder = (e) => {
    e.preventDefault();
    if(!/^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i.test(eposta.trim())){ setH('Geçerli bir e-posta girin'); return; }
    setBek(true); setTimeout(() => { setBek(false); setAsama(1); }, 700);
  };
  if(asama === 1) return (
    <KimlikKabuk kulak="Parola" baslik="Bağlantıyı gönderdik."
      aciklama={`${eposta} adresine parola yenileme bağlantısı gitti. Bağlantı 30 dakika geçerli.`}>
      <Kutu tur="mor" ikon="posta">E-posta gelmediyse gereksiz (spam) klasörüne bakın. Hâlâ yoksa 0850 000 00 00 numaradan bize ulaşın.</Kutu>
      <div className="dg-grup" style={{ marginTop: 24 }}>
        <button className="dg dg-c" onClick={() => setAsama(0)}>Adresi değiştir</button>
        <button className="dg dg-a" onClick={() => { git('giris'); window.scrollTo(0, 0); }}>Girişe dön</button>
      </div>
    </KimlikKabuk>
  );
  return (
    <KimlikKabuk kulak="Parola" baslik="Parolanızı sıfırlayalım."
      aciklama="Hesabınızın e-posta adresini yazın; yenileme bağlantısını gönderelim.">
      <form onSubmit={gonder} noValidate>
        <Alan etiket="E-posta" hata={h} id="s-eposta">
          <input id="s-eposta" className={`gir ${h ? 'yanlis' : ''}`} type="email" inputMode="email" autoComplete="email"
            placeholder="mehmet@merkezsubayi.com" value={eposta} onChange={(e) => { setEposta(e.target.value); setH(null); }} />
        </Alan>
        <button className="dg dg-a tam" type="submit" disabled={bek}>{bek ? <span className="donen" /> : 'Bağlantı gönder'}</button>
      </form>
      <button className="dg dg-d tam" style={{ marginTop: 12 }} onClick={() => { git('giris'); window.scrollTo(0, 0); }}>
        <Ikon ad="okSol" boy={17} kalin={2.2} />Girişe dön
      </button>
    </KimlikKabuk>
  );
}

Object.assign(window, { GirisSayfa, KayitSayfa, SifreSayfa, KimlikKabuk, slugla });
