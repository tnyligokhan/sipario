// sw-odeme.jsx — Ödeme akışı: özet → kart/havale → 3D Secure → sonuç. → window

const luhn = (s) => {
  const d = String(s).replace(/\D/g, '');
  if(d.length < 13) return false;
  let t = 0, a = false;
  for(let i = d.length - 1; i >= 0; i--){ let n = +d[i]; if(a){ n *= 2; if(n > 9) n -= 9; } t += n; a = !a; }
  return t % 10 === 0;
};
const kartMarka = (s) => {
  const d = String(s).replace(/\D/g, '');
  if(/^4/.test(d)) return 'Visa';
  if(/^(5[1-5]|2[2-7])/.test(d)) return 'Mastercard';
  if(/^9/.test(d)) return 'Troy';
  if(/^3[47]/.test(d)) return 'Amex';
  return null;
};
const kartBicim = (s) => String(s).replace(/\D/g, '').slice(0, 16).replace(/(.{4})/g, '$1 ').trim();

function OdemeUst({ onGeri }){
  return (
    <header className="od-ust">
      <div className="kap od-ust-ic">
        <button className="od-geri" onClick={onGeri}><Ikon ad="okSol" boy={18} kalin={2.2} />Vazgeç</button>
        <Marka boy={32} />
        <span className="od-guvenli"><Ikon ad="kilit" boy={15} kalin={2.2} />Güvenli ödeme</span>
      </div>
    </header>
  );
}

function OdemeOzet({ s, taksit }){
  const kalem = s.tur === 'hak'
    ? [{ ad: `Oto-sıralama · ${s.adet} hak`, alt: 'Tek seferlik · süresiz geçerli', tutar: s.tutar }]
    : [{ ad: s.donem === 'yil' ? 'Sipario · Yıllık abonelik' : 'Sipario · Aylık abonelik',
         alt: s.donem === 'yil' ? '30 Mar 2026 – 30 Mar 2027 · 12 ay (2 ay hediye)' : '30 Mar 2026 – 30 Nis 2026 · 1 ay',
         tutar: s.tutar }];
  const ara = kalem.reduce((a, k) => a + k.tutar, 0);
  const kdv = Math.round(ara - ara / 1.2);
  return (
    <Pano etiket="Sipariş özeti" sinif="od-ozet">
      {kalem.map((k, i) => (
        <div className="od-kalem" key={i}>
          <div><b>{k.ad}</b><span className="kucuk">{k.alt}</span></div>
          <b className="tab">{tl(k.tutar)}</b>
        </div>
      ))}
      <hr className="ayrac" />
      <div className="od-r"><span>Ara toplam</span><span className="tab">{tl(ara - kdv)}</span></div>
      <div className="od-r"><span>KDV (%20)</span><span className="tab">{tl(kdv)}</span></div>
      <div className="od-toplam">
        <span className="h4">Ödenecek tutar</span>
        <b className="rakam kucuk-rakam tab">{tl(ara)}</b>
      </div>
      {taksit > 1 && <div className="od-taksit"><Ikon ad="kart" boy={16} kalin={2} />{taksit} × <b className="tab">{tlk(ara / taksit)}</b> · taksit farkı yok</div>}
      <div className="od-guven">
        <Ikon ad="kalkan" boy={17} kalin={2} renk="var(--yesil)" />
        <span>Ödemenizi havale/EFT ya da elden alıyoruz. Kartla online ödeme yakında açılacak.</span>
      </div>
    </Pano>
  );
}

function OdemeSayfa(){
  const { git, sepet, bildir, setOturum } = useYon();
  const s = sepet || { tur: 'plan', plan: 'sipario', donem: 'yil', tutar: 5988 };
  const [asama, setAsama] = React.useState('form');
  const [yol, setYol] = React.useState('havale');
  const [taksit, setTaksit] = React.useState(1);
  const [f, setF] = React.useState({ sahip: '', no: '', tarih: '', cvc: '' });
  const [h, setH] = React.useState({});
  const [bek, setBek] = React.useState(false);
  const [fd, setFd] = React.useState(false);
  const [fat, setFat] = React.useState(SW_HESAP.fatura);
  const marka = kartMarka(f.no);
  const yillik = s.donem === 'yil' && s.tur === 'plan';

  const dg = {
    sahip: (v) => !v.trim() ? 'Kart üzerindeki ismi girin' : v.trim().length < 5 ? 'Ad soyad eksik görünüyor' : null,
    no: (v) => { const d = v.replace(/\D/g, ''); return !d ? 'Kart numarasını girin' : d.length < 16 ? 'Kart numarası 16 hane olmalı' : !luhn(d) ? 'Kart numarası hatalı, kontrol edin' : null; },
    tarih: (v) => { const m = v.match(/^(\d{2})\s*\/\s*(\d{2})$/); if(!v.trim()) return 'Son kullanma tarihini girin';
      if(!m) return 'AA/YY biçiminde yazın'; const a = +m[1]; if(a < 1 || a > 12) return 'Ay 01–12 arasında olmalı';
      if(+m[2] < 26) return 'Kartın süresi dolmuş'; return null; },
    cvc: (v) => !v ? 'Kartın arkasındaki 3 haneyi girin' : v.length < 3 ? 'CVC 3 hane olmalı' : null,
  };
  const blur = (k) => setH((x) => ({ ...x, [k]: dg[k](f[k]) }));
  const yaz = (k, v) => { setF((x) => ({ ...x, [k]: v })); if(h[k]) setH((x) => ({ ...x, [k]: null })); };

  const ode = (e) => {
    e.preventDefault();
    const y = {}; Object.keys(dg).forEach((k) => { y[k] = dg[k](f[k]); });
    setH(y);
    if(Object.values(y).some(Boolean)) return;
    setBek(true);
    setTimeout(() => { setBek(false); setAsama('3ds'); }, 800);
  };

  const geri = () => { git(s.tur === 'hak' ? 'hesap' : 'fiyat'); window.scrollTo(0, 0); };

  if(asama === '3ds') return (
    <main className="od">
      <OdemeUst onGeri={() => setAsama('form')} />
      <div className="kap ensiz od-3ds">
        <Pano etiket="3D Secure doğrulama" sag={<Rozet tur="yesil" nokta canli>Güvenli</Rozet>}>
          <div className="od-3ds-ic">
            <span className="od-3ds-ik"><Ikon ad="mobil" boy={30} kalin={1.8} renk="var(--mor)" /></span>
            <h2 className="h2">Bankanızdan gelen kodu girin</h2>
            <p className="gvd">{marka || 'Kart'} •••• {f.no.replace(/\D/g, '').slice(-4)} numaralı kartın kayıtlı cep telefonuna 6 haneli doğrulama kodu gönderildi.</p>
            <div className="od-kod">
              {[0,1,2,3,4,5].map((i) => <input key={i} className="gir od-kod-h" inputMode="numeric" maxLength="1" aria-label={`Hane ${i+1}`}
                onChange={(e) => { const n = e.target.parentNode.children[i+1]; if(e.target.value && n) n.focus(); }} />)}
            </div>
            <div className="od-3ds-alt">
              <span className="kucuk">Kod gelmediyse <button className="kimlik-link">tekrar gönder</button> · 02:00</span>
            </div>
            <button className="dg dg-a tam" onClick={() => { setAsama('basari'); window.scrollTo(0, 0); }}>Doğrula ve öde<Ikon ad="kilit" boy={17} kalin={2.2} /></button>
            <button className="dg dg-d tam" onClick={() => setAsama('form')}>İptal et, karta dön</button>
          </div>
        </Pano>
        <p className="kucuk od-3ds-not">Bu ekran bankanızın güvenlik katmanıdır. Sipario bu adımda kart bilgilerinizi görmez.</p>
      </div>
    </main>
  );

  if(asama === 'basari') return (
    <main className="od">
      <OdemeUst onGeri={() => { git('ana'); window.scrollTo(0, 0); }} />
      <div className="kap ensiz od-basari">
        <span className="od-tik"><Ikon ad="onay" boy={34} kalin={2.6} renk="#fff" /></span>
        <h1 className="h1">Ödemeniz alındı.</h1>
        <p className="gvd b">{tl(s.tutar)} tutarındaki ödeme onaylandı. E-arşiv faturanız birkaç dakika içinde e-posta adresinize gelecek.</p>
        <Pano ince duz sinif="ozet-pano" sikIc stil={{ margin: '30px 0', textAlign: 'left' }}>
          <div className="ozet-r"><span>İşlem no</span><b className="tab">SIP-2026-0412</b></div>
          <div className="ozet-r"><span>Tutar</span><b className="tab">{tl(s.tutar)}</b></div>
          <div className="ozet-r"><span>Yöntem</span><b>{marka || 'Kart'} •••• {f.no.replace(/\D/g, '').slice(-4)}{taksit > 1 ? ` · ${taksit} taksit` : ''}</b></div>
          <div className="ozet-r"><span>Sonraki tahsilat</span><b>{s.tur === 'hak' ? 'Yok · tek seferlik' : '30 Mart 2027'}</b></div>
        </Pano>
        <div className="dg-grup" style={{ justifyContent: 'center' }}>
          <button className="dg dg-a" onClick={() => { setOturum(true); git('hesap'); window.scrollTo(0, 0); }}>Hesap paneline git<Ikon ad="ok" boy={18} kalin={2.2} /></button>
          <button className="dg dg-c" onClick={() => bildir('Fatura indiriliyor…')}><Ikon ad="indir" boy={17} kalin={2.1} />Faturayı indir</button>
        </div>
      </div>
    </main>
  );

  return (
    <main className="od">
      <OdemeUst onGeri={geri} />
      <div className="kap od-basl">
        <h1 className="h1 od-h1">Ödeme</h1>
        <p className="gvd od-lead">Aşağıdaki tutar tektir; ödeme adımında ek ücret çıkmaz.</p>
      </div>
      <div className="kap od-ic">
        <div className="od-sol">
          <div className="od-yol">
            <button className={`sec ${yol === 'havale' ? 'on' : ''}`} onClick={() => setYol('havale')}>
              <span className="sec-nokta" />
              <span className="sec-orta">
                <span className="sec-bas">Havale / EFT</span>
                <span className="sec-alt">Dekont ulaştığı gün hesabınız açılır</span>
              </span>
            </button>
            <button className={`sec ${yol === 'elden' ? 'on' : ''}`} onClick={() => setYol('elden')}>
              <span className="sec-nokta" />
              <span className="sec-orta">
                <span className="sec-bas">Elden ödeme</span>
                <span className="sec-alt">Bölgenizdeysek uğrayıp alıyoruz · makbuz yerinde</span>
              </span>
            </button>
            <div className="sec yakinda">
              <span className="sec-nokta" />
              <span className="sec-orta">
                <span className="sec-bas">Kredi / banka kartı<Rozet tur="notr">Yakında</Rozet></span>
                <span className="sec-alt">Online kart ödemesi üzerinde çalışıyoruz</span>
              </span>
            </div>
          </div>

          {yol === 'kart' ? (
            <form onSubmit={ode} noValidate className="od-form">
              <Alan etiket="Kart üzerindeki isim" hata={h.sahip} id="o-sahip">
                <input id="o-sahip" className={`gir ${h.sahip ? 'yanlis' : ''}`} autoComplete="cc-name"
                  placeholder="MEHMET YILMAZ" value={f.sahip}
                  onChange={(e) => yaz('sahip', e.target.value.toLocaleUpperCase('tr-TR'))} onBlur={() => blur('sahip')} />
              </Alan>
              <Alan etiket="Kart numarası" hata={h.no} id="o-no">
                <div className="gir-sarma">
                  <input id="o-no" className={`gir ${h.no ? 'yanlis' : ''}`} inputMode="numeric" autoComplete="cc-number"
                    placeholder="0000 0000 0000 0000" value={f.no}
                    onChange={(e) => yaz('no', kartBicim(e.target.value))} onBlur={() => blur('no')} />
                  {marka && <span className="kart-marka">{marka}</span>}
                </div>
              </Alan>
              <div className="alan-ikili">
                <Alan etiket="Son kullanma" hata={h.tarih} id="o-tarih">
                  <input id="o-tarih" className={`gir ${h.tarih ? 'yanlis' : ''}`} inputMode="numeric" autoComplete="cc-exp"
                    placeholder="AA/YY" maxLength="5" value={f.tarih}
                    onChange={(e) => { let v = e.target.value.replace(/\D/g, '').slice(0, 4); if(v.length > 2) v = v.slice(0, 2) + '/' + v.slice(2); yaz('tarih', v); }}
                    onBlur={() => blur('tarih')} />
                </Alan>
                <Alan etiket="CVC" hata={h.cvc} id="o-cvc" ipucu={h.cvc ? null : 'Kartın arkasındaki 3 hane'}>
                  <input id="o-cvc" className={`gir ${h.cvc ? 'yanlis' : ''}`} inputMode="numeric" autoComplete="cc-csc"
                    placeholder="000" maxLength="4" value={f.cvc}
                    onChange={(e) => yaz('cvc', e.target.value.replace(/\D/g, ''))} onBlur={() => blur('cvc')} />
                </Alan>
              </div>

              {yillik && (
                <Alan etiket="Taksit" not="taksit farkı yok" id="o-taksit">
                  <div className="taksit-grid">
                    {[1, 3, 6, 9, 12].map((t) => (
                      <button type="button" key={t} className={`taksit ${taksit === t ? 'on' : ''}`} onClick={() => setTaksit(t)}>
                        <b>{t === 1 ? 'Tek çekim' : t + ' taksit'}</b>
                        <span className="tab">{tlk(s.tutar / t)}{t > 1 ? ' × ' + t : ''}</span>
                      </button>
                    ))}
                  </div>
                </Alan>
              )}

              <div className="od-fatura">
                <div className="od-fatura-b">
                  <span className="mn">Fatura bilgileri</span>
                  <button type="button" className="kimlik-link" onClick={() => setFd(!fd)}>{fd ? 'Kapat' : 'Düzenle'}</button>
                </div>
                {fd ? (
                  <div className="od-fatura-f">
                    <Alan etiket="Ünvan" id="fa-u"><input id="fa-u" className="gir" value={fat.unvan} onChange={(e) => setFat({ ...fat, unvan: e.target.value })} /></Alan>
                    <div className="alan-ikili">
                      <Alan etiket="VKN / TCKN" id="fa-v"><input id="fa-v" className="gir" inputMode="numeric" value={fat.vkn} onChange={(e) => setFat({ ...fat, vkn: e.target.value.replace(/\D/g, '').slice(0, 11) })} /></Alan>
                      <Alan etiket="Vergi dairesi" id="fa-d"><input id="fa-d" className="gir" value={fat.daire} onChange={(e) => setFat({ ...fat, daire: e.target.value })} /></Alan>
                    </div>
                    <Alan etiket="Adres" id="fa-a"><input id="fa-a" className="gir" value={fat.adres} onChange={(e) => setFat({ ...fat, adres: e.target.value })} /></Alan>
                  </div>
                ) : (
                  <p className="od-fatura-o">{fat.unvan}<br />{fat.vkn} · {fat.daire}<br />{fat.adres}, {fat.ilce} / {fat.il}</p>
                )}
              </div>

              <button className="dg dg-a tam dev" type="submit" disabled={bek}>
                {bek ? <span className="donen" /> : <React.Fragment><Ikon ad="kilit" boy={18} kalin={2.2} />{tl(s.tutar)} öde</React.Fragment>}
              </button>
              <p className="od-kucuk">Devam ederek <a href="#y" onClick={(e) => e.preventDefault()}>mesafeli satış sözleşmesini</a> ve <a href="#y" onClick={(e) => e.preventDefault()}>ön bilgilendirme formunu</a> kabul etmiş olursunuz. Ödeme sonrası 14 gün içinde koşulsuz iade hakkınız vardır.</p>
            </form>
          ) : yol === 'elden' ? (
            <div className="od-form">
              <Kutu tur="sari" ikon="bilgi">Elden ödeme şu an Ankara, Antalya ve İzmir’de geçerli. Talebinizi bırakın, aynı gün içinde arayarak saat ayarlayalım.</Kutu>
              <Pano ince duz sinif="havale" sikIc>
                {[['Tutar', tl(s.tutar)], ['İşletme', SW_HESAP.isletme], ['Telefon', SW_HESAP.telefon], ['Makbuz', 'Teslimde elden verilir']].map((r, i) => (
                  <div className="ozet-r" key={i}><span>{r[0]}</span><b className={i === 0 ? 'tab' : ''}>{r[1]}</b></div>
                ))}
              </Pano>
              <div className="dg-grup" style={{ marginTop: 20 }}>
                <button className="dg dg-a" onClick={() => bildir('Talebiniz alındı, bugün arayacağız')}><Ikon ad="telefon" boy={17} kalin={2.1} />Beni arayın</button>
              </div>
              <p className="od-kucuk">Tahsilat yapıldığı anda hesabınız açılır ve e-arşiv faturanız e-posta ile gönderilir.</p>
            </div>
          ) : (
            <div className="od-form">
              <Kutu tur="sari" ikon="bilgi">Havale/EFT ödemelerinde hesabınız, dekont bize ulaştıktan sonra <b>aynı iş günü içinde</b> açılır. Açıklama alanına referans kodunu yazmayı unutmayın.</Kutu>
              <Pano ince duz sinif="havale" sikIc>
                {[['Alıcı ünvanı', SW_KUNYE.unvan], ['Banka', 'Ziraat Bankası · Kızılay / Ankara'],
                  ['IBAN', 'TR12 0001 0000 0000 0000 0000 01'], ['Tutar', tl(s.tutar)],
                  ['Referans kodu', 'SIP-MERKEZBAYI-0412']].map((r, i) => (
                  <div className="ozet-r" key={i}><span>{r[0]}</span><b className={i === 2 || i === 3 ? 'tab' : ''}>{r[1]}</b></div>
                ))}
              </Pano>
              <div className="dg-grup" style={{ marginTop: 20 }}>
                <button className="dg dg-a" onClick={() => bildir('Hesap bilgileri kopyalandı')}><Ikon ad="kopyala" boy={17} kalin={2.1} />Bilgileri kopyala</button>
                <button className="dg dg-c" onClick={() => bildir('Talimat e-postanıza gönderildi')}><Ikon ad="posta" boy={17} kalin={2.1} />E-posta ile gönder</button>
              </div>
            </div>
          )}
        </div>
        <div className="od-sag"><OdemeOzet s={s} taksit={taksit} /></div>
      </div>
    </main>
  );
}

Object.assign(window, { OdemeSayfa, luhn, kartMarka, kartBicim });
