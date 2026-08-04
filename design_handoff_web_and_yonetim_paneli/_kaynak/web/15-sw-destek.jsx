// sw-destek.jsx — Destek / SSS ve İletişim sayfaları. → window

const SW_KANAL = [
  { ik: 'telefon', t: 'Telefon', v: '0850 000 00 00', a: 'Hafta içi 09:00 – 19:00 · sırada ortalama 40 saniye', dg: 'Ara' },
  { ik: 'sohbet', t: 'WhatsApp', v: '05xx xxx xx 00', a: 'Ekran görüntüsü gönderin, birlikte bakalım', dg: 'Yaz' },
  { ik: 'posta', t: 'E-posta', v: 'destek@sipario.com.tr', a: 'Aynı gün içinde yanıt · gece gelenler sabah', dg: 'Gönder' },
];

function DestekSayfa(){
  const { git } = useYon();
  const [q, setQ] = React.useState('');
  const [g, setG] = React.useState('hepsi');
  const ara = q.trim().toLocaleLowerCase('tr-TR');
  const gruplar = SW_SSS
    .filter((x) => g === 'hepsi' || x.g === g)
    .map((x) => ({ ...x, l: x.l.filter((s) => !ara || (s.s + s.c).toLocaleLowerCase('tr-TR').includes(ara)) }))
    .filter((x) => x.l.length);
  const bulunan = gruplar.reduce((a, x) => a + x.l.length, 0);
  return (
    <main className="ic">
      <section className="blm kisa">
        <div className="kap">
          <div className="blm-bas">
            <span className="blm-kulak mn"><i />Destek</span>
            <h1 className="h1">Takıldığınız yerde<br />insan var.</h1>
            <p className="gvd b">Telefonu bot açmıyor. Aynı ekip, aynı numara — çoğu soru ilk aramada çözülüyor.</p>
          </div>
          <div className="kanal-grid">
            {SW_KANAL.map((k, i) => (
              <Pano key={i} sinif="kanal" ince={i > 0}>
                <span className="kanal-ik"><Ikon ad={k.ik} boy={21} kalin={2} renk="var(--mor)" /></span>
                <span className="mn">{k.t}</span>
                <b className="h3 kanal-v">{k.v}</b>
                <p className="kucuk">{k.a}</p>
              </Pano>
            ))}
          </div>
        </div>
      </section>

      <section className="blm kagit2">
        <div className="kap">
          <BlmBas kulak="Sık sorulanlar" baslik="Aradığınızı yazın." />
          <div className="sss-arac">
            <div className="gir-sarma sss-ara">
              <span className="sss-ara-ik"><Ikon ad="ara" boy={19} kalin={2} renk="var(--sonuk)" /></span>
              <input className="gir" placeholder="Örn. iptal, fatura, çevrimdışı…" value={q} onChange={(e) => setQ(e.target.value)} />
              {q && <button className="gir-goz" onClick={() => setQ('')} aria-label="Temizle"><Ikon ad="kapat" boy={17} kalin={2.2} /></button>}
            </div>
            <div className="sss-filtre">
              {['hepsi', ...SW_SSS.map((x) => x.g)].map((x) => (
                <button key={x} className={`sss-f ${g === x ? 'on' : ''}`} onClick={() => setG(x)}>{x === 'hepsi' ? 'Hepsi' : x}</button>
              ))}
            </div>
          </div>
          {bulunan === 0 ? (
            <Pano ince sinif="sss-bos">
              <span className="h3">“{q}” için sonuç yok.</span>
              <p className="gvd">Aradığınızı bulamadıysanız yazmayın, arayın — 0850 000 00 00.</p>
              <button className="dg dg-a" onClick={() => { git('iletisim'); window.scrollTo(0, 0); }}>Bize ulaşın</button>
            </Pano>
          ) : gruplar.map((gr) => (
            <div className="sss-grup" key={gr.g}>
              <span className="mn sss-g">{gr.g}</span>
              <SssListe liste={gr.l} acikVar={false} />
            </div>
          ))}
        </div>
      </section>

      <section className="blm">
        <div className="kap">
          <Pano sinif="destek-cta" genisIc>
            <div className="destek-cta-ic">
              <div>
                <h2 className="h2">Cevabı bulamadınız mı?</h2>
                <p className="gvd">Numaranızı bırakın, biz arayalım. Ekran paylaşımıyla birlikte bakabiliriz.</p>
              </div>
              <button className="dg dg-a dev" onClick={() => { git('iletisim'); window.scrollTo(0, 0); }}>Bize ulaşın<Ikon ad="ok" boy={19} kalin={2.2} /></button>
            </div>
          </Pano>
        </div>
      </section>
    </main>
  );
}

function IletisimSayfa(){
  const { bildir } = useYon();
  const [f, setF] = React.useState({ ad: '', isletme: '', telefon: '', konu: 'Demo talebi', mesaj: '' });
  const [h, setH] = React.useState({});
  const [bek, setBek] = React.useState(false);
  const [ok, setOk] = React.useState(false);
  const y = (k, v) => { setF((x) => ({ ...x, [k]: v })); if(h[k]) setH((x) => ({ ...x, [k]: null })); };
  const gonder = (e) => {
    e.preventDefault();
    const yy = {
      ad: !f.ad.trim() ? 'Adınızı girin' : null,
      telefon: !f.telefon.trim() ? 'Size ulaşabileceğimiz bir numara girin'
        : f.telefon.replace(/\D/g, '').length < 10 ? 'Numara eksik görünüyor' : null,
    };
    setH(yy);
    if(Object.values(yy).some(Boolean)) return;
    setBek(true); setTimeout(() => { setBek(false); setOk(true); bildir('Talebiniz alındı'); }, 800);
  };
  return (
    <main className="ic">
      <section className="blm">
        <div className="kap il-ic">
          <div className="il-sol">
            <span className="blm-kulak mn"><i />İletişim</span>
            <h1 className="h1 ic-h1">Önce konuşalım.</h1>
            <p className="gvd b">İşletmenizi anlatın; Sipario size uyar mı, dürüstçe söyleyelim. Uymuyorsa satmıyoruz.</p>
            <div className="il-kanal">
              {SW_KANAL.map((k, i) => (
                <div className="il-k" key={i}>
                  <span className="il-k-ik"><Ikon ad={k.ik} boy={19} kalin={2} renk="var(--mor)" /></span>
                  <div><b>{k.v}</b><span className="kucuk">{k.a}</span></div>
                </div>
              ))}
            </div>
            <Pano ince duz sinif="il-adres" sikIc>
              <span className="mn">Merkez</span>
              <p className="gvd" style={{ fontSize: 15.5, marginTop: 10 }}>{SW_KUNYE.unvan}<br />{SW_KUNYE.adres}</p>
              <p className="kucuk" style={{ marginTop: 8 }}>MERSİS {SW_KUNYE.mersis} · {SW_KUNYE.vkn}</p>
            </Pano>
          </div>
          <div className="il-sag">
            {ok ? (
              <Pano etiket="Alındı" sinif="il-form">
                <span className="od-tik kucuk-tik"><Ikon ad="onay" boy={26} kalin={2.6} renk="#fff" /></span>
                <h2 className="h2" style={{ marginTop: 20 }}>Teşekkürler, {f.ad.split(' ')[0]}.</h2>
                <p className="gvd">Talebiniz ekibimize düştü. <b>{f.telefon}</b> numarasından bugün içinde arayacağız.</p>
                <hr className="ayrac" />
                <p className="kucuk">Acilse beklemeyin: 0850 000 00 00 · hafta içi 09:00 – 19:00.</p>
                <button className="dg dg-c tam" style={{ marginTop: 18 }} onClick={() => { setOk(false); setF({ ad: '', isletme: '', telefon: '', konu: 'Demo talebi', mesaj: '' }); }}>Yeni bir talep gönder</button>
              </Pano>
            ) : (
              <Pano etiket="Bize yazın" sinif="il-form">
                <form onSubmit={gonder} noValidate>
                  <Alan etiket="Ad soyad" hata={h.ad} id="il-ad">
                    <input id="il-ad" className={`gir ${h.ad ? 'yanlis' : ''}`} autoComplete="name" placeholder="Mehmet Yılmaz"
                      value={f.ad} onChange={(e) => y('ad', e.target.value)} />
                  </Alan>
                  <div className="alan-ikili">
                    <Alan etiket="İşletme" not="isteğe bağlı" id="il-is">
                      <input id="il-is" className="gir" autoComplete="organization" placeholder="Merkez Su Bayii"
                        value={f.isletme} onChange={(e) => y('isletme', e.target.value)} />
                    </Alan>
                    <Alan etiket="Telefon" hata={h.telefon} id="il-tel">
                      <input id="il-tel" className={`gir ${h.telefon ? 'yanlis' : ''}`} type="tel" inputMode="tel"
                        autoComplete="tel" placeholder="05xx xxx xx 00" value={f.telefon} onChange={(e) => y('telefon', e.target.value)} />
                    </Alan>
                  </div>
                  <Alan etiket="Konu" id="il-konu">
                    <select id="il-konu" className="gir" value={f.konu} onChange={(e) => y('konu', e.target.value)}>
                      <option>Demo talebi</option>
                      <option>Kurumsal teklif</option>
                      <option>Fiyat ve paket sorusu</option>
                      <option>Teknik destek</option>
                      <option>Fatura / ödeme</option>
                      <option>Diğer</option>
                    </select>
                  </Alan>
                  <Alan etiket="Mesajınız" not="isteğe bağlı" id="il-m">
                    <textarea id="il-m" className="gir" placeholder="Kaç kurye ile çalışıyorsunuz, günde kaç sipariş giriyorsunuz?"
                      value={f.mesaj} onChange={(e) => y('mesaj', e.target.value)} />
                  </Alan>
                  <button className="dg dg-a tam" type="submit" disabled={bek}>{bek ? <span className="donen" /> : 'Gönder, beni arayın'}</button>
                  <p className="od-kucuk">Bilgileriniz yalnızca bu talebe dönmek için kullanılır. <a href="#y" onClick={(e) => e.preventDefault()}>KVKK aydınlatma metni</a>.</p>
                </form>
              </Pano>
            )}
          </div>
        </div>
      </section>
    </main>
  );
}

Object.assign(window, { DestekSayfa, IletisimSayfa, SW_KANAL });
