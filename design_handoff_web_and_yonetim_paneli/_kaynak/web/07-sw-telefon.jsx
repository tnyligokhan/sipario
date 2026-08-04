// sw-telefon.jsx — Sipario mobil arayüzünün canlı, gerçek ölçekli kopyası (412×892, CSS ile ölçeklenir). → window

function TelDurum({ beyaz }){
  return (
    <div className={`t-sys ${beyaz ? 'byz' : ''}`}>
      <span>09:41</span>
      <span className="t-sys-sag">
        <Ikon ad="global" boy={13} kalin={2.2} /><Ikon ad="simsek" boy={13} kalin={2.2} />
        <span className="t-pil"><i /></span>
      </span>
    </div>
  );
}

function TelNav({ aktif = 'ana' }){
  const b = [ { k:'ana', ik:'ev', ad:'Ana' }, { k:'mus', ik:'musteriler', ad:'Müşteri' },
    { k:'sip', ik:'liste', ad:'Sipariş' }, { k:'urn', ik:'kutu', ad:'Ürün' } ];
  return (
    <div className="t-nav">
      <div className="t-nav-g">
        {b.map((x) => (
          <button key={x.k} className={`t-nav-b ${aktif === x.k ? 'on' : ''}`}>
            <Ikon ad={x.ik} boy={20} kalin={aktif === x.k ? 2.3 : 1.9} renk="#fff" />
            <span>{x.ad}</span>
          </button>
        ))}
      </div>
      <button className="t-fab"><Ikon ad="arti" boy={23} kalin={2.4} renk="#fff" /></button>
    </div>
  );
}

function TelAna({ ciro = '12.480', acik = 7, bildirim, isletme = 'Merkez Su Bayii' }){
  return (
    <div className="t-ekran">
      <TelDurum beyaz />
      <div className="t-hero">
        <div className="t-hero-ust">
          <div>
            <div className="t-selam">Günaydın</div>
            <div className="t-isletme">{isletme}</div>
          </div>
          <span className="t-menu"><Ikon ad="menu" boy={19} kalin={2.1} renk="#fff" /></span>
        </div>
        <div className="t-sync"><i />senkron <b>09:38</b></div>
      </div>
      <div className="t-govde">
        <div className="t-bento">
          <div className="t-bk mor">
            <span className="t-bk-l">Bugünkü ciro</span>
            <span className="t-bk-v tab">{ciro}<small> ₺</small></span>
          </div>
          <div className="t-bk">
            <span className="t-bk-l">Açık sipariş</span>
            <span className="t-bk-v tab">{acik}</span>
          </div>
          <div className="t-bk">
            <span className="t-bk-l">Veresiye</span>
            <span className="t-bk-v kucuk tab">48.250 ₺</span>
            <span className="t-bk-a">23 müşteri</span>
          </div>
          <div className="t-bk">
            <span className="t-bk-l">Yolda</span>
            <span className="t-bk-v kucuk tab">2 kurye</span>
            <span className="t-bk-a">5 teslimat</span>
          </div>
        </div>
        <button className="t-cta">
          <span className="t-cta-ic"><Ikon ad="arti" boy={19} kalin={2.5} renk="#fff" /></span>
          <span className="t-cta-t">Yeni sipariş</span>
          <Ikon ad="sag" boy={18} kalin={2.2} renk="rgba(255,255,255,.55)" />
        </button>
        <div className="t-bas">Son hareketler</div>
        <div className="t-akt">
          {[['Selin Kaya','Kasa Domates ×1 · kart','160,00 ₺'],['Tezgâh Satışı','Kuruyemiş 1 kg · nakit','320,00 ₺'],['Murat Öz','Damacana ×1 · nakit','45,00 ₺']].map((x,i)=>(
            <div className="t-akt-r" key={i}>
              <span className="t-akt-ic"><Ikon ad="onay" boy={14} kalin={2.8} renk="#1E9E6A" /></span>
              <span className="t-akt-m"><b>{x[0]}</b><small>{x[1]}</small></span>
              <span className="t-akt-t tab">{x[2]}</span>
            </div>
          ))}
        </div>
      </div>
      <TelNav aktif="ana" />
      {bildirim && <div className="t-toast">{bildirim}</div>}
    </div>
  );
}

function TelCagri(){
  return (
    <div className="t-cagri-fon">
      <div className="t-cagri">
        <div className="t-cagri-ust">
          <span className="t-cagri-live"><i />GELEN ÇAĞRI</span>
          <span className="t-cagri-sn"><Ikon ad="saat" boy={12} kalin={2.2} renk="#8B8794" />00:03</span>
        </div>
        <div className="t-cagri-kim">
          <span className="t-cagri-av">AY</span>
          <span className="t-cagri-mid">
            <b>Ahmet Yılmaz</b>
            <small>05xx xxx xx 08</small>
          </span>
        </div>
        <div className="t-cagri-bal">
          <span>AÇIK BORÇ</span>
          <b className="tab">8.550,00 ₺</b>
        </div>
        <div className="t-cagri-bilgi">
          <div className="t-cagri-b"><Ikon ad="konum" boy={15} kalin={2} renk="#47434F" /><span>Şirinyalı Mah. 42. Sk. No:9 · Muratpaşa</span></div>
          <div className="t-cagri-b"><Ikon ad="geri" boy={15} kalin={2} renk="#47434F" /><span>Son sipariş: Damacana 19 L ×2 · dün 10:24</span></div>
          <div className="t-cagri-b uy"><Ikon ad="uyari" boy={15} kalin={2.2} renk="#C08415" /><span>Zil çalışmıyor — arayın</span></div>
        </div>
        <div className="t-cagri-akt">
          <button className="t-btn mor"><Ikon ad="arti" boy={17} kalin={2.5} renk="#fff" />Sipariş oluştur</button>
          <button className="t-btn gri">Kartı kapat</button>
        </div>
      </div>
    </div>
  );
}

function TelMusteri(){
  const hareket = [
    ['borc','Damacana 19 L ×2','Bugün 10:24','+90,00 ₺','veresiye'],
    ['odeme','Tahsilat · nakit','Dün 18:02','−250,00 ₺',null],
    ['borc','Paket Su ×3 koli','12 Tem 09:15','+270,00 ₺','veresiye'],
    ['borc','Kuruyemiş 1 kg','8 Tem 16:40','+320,00 ₺','veresiye'],
  ];
  return (
    <div className="t-ekran">
      <TelDurum />
      <div className="t-ust">
        <span className="t-ust-ik"><Ikon ad="sol" boy={19} kalin={2.2} /></span>
        <span className="t-ust-m"><b>Ahmet Yılmaz</b><small>05xx xxx xx 08</small></span>
        <span className="t-ust-ik"><Ikon ad="duzenle" boy={17} kalin={2} /></span>
      </div>
      <div className="t-govde">
        <div className="t-md-bal">
          <span className="t-md-bal-l">AÇIK BORÇ</span>
          <span className="t-md-bal-v tab">8.550,00 ₺</span>
          <span className="t-md-bal-t">BORÇLU</span>
          <span className="t-md-kupon"><Ikon ad="saat" boy={13} kalin={2} renk="rgba(255,255,255,.7)" />Son ödeme 14 gün önce</span>
        </div>
        <div className="t-md-akt">
          {[['elpara','Tahsilat'],['arti','Sipariş'],['telefon','Ara'],['konum','Adres']].map((x,i)=>(
            <button className="t-mda" key={i}><Ikon ad={x[0]} boy={19} kalin={2} renk="#5A45F0" /><span>{x[1]}</span></button>
          ))}
        </div>
        <div className="t-bas">Defter</div>
        <div className="t-defter">
          {hareket.map((h,i)=>(
            <div className="t-dh" key={i}>
              <span className="t-dh-ic" style={{background: h[0]==='odeme' ? '#E3F4EC' : '#FCE9EA'}}>
                <Ikon ad={h[0]==='odeme' ? 'okYukari' : 'ok'} boy={14} kalin={2.4} renk={h[0]==='odeme' ? '#1E9E6A' : '#DF3F45'} />
              </span>
              <span className="t-dh-m"><b>{h[1]}{h[4] && <em>{h[4]}</em>}</b><small>{h[2]}</small></span>
              <span className="t-dh-t tab" style={{color: h[0]==='odeme' ? '#1E9E6A' : '#17141F'}}>{h[3]}</span>
            </div>
          ))}
        </div>
      </div>
      <TelNav aktif="mus" />
    </div>
  );
}

function TelSiparis(){
  const sip = [
    { k:'#1043', ad:'Ahmet Yılmaz', s:'10:24', u:['Damacana 19 L ×2'], adr:'Şirinyalı Mah. 42. Sk. No:9', kur:'Kurye 1', tut:'90,00 ₺', not:'Zil çalışmıyor' },
    { k:'#1042', ad:'Hatice Demir', s:'10:02', u:['Paket Su 0.5L ×1 koli','Merdiven çıkışı'], adr:'Meltem Mah. 3. Cd. No:14/B', kur:'Ben', tut:'110,00 ₺', not:null },
  ];
  return (
    <div className="t-ekran">
      <TelDurum />
      <div className="t-ust">
        <span className="t-ust-m tek"><b>Siparişler</b><small>7 açık · 12 teslim</small></span>
        <span className="t-ust-ik"><Ikon ad="filtre" boy={17} kalin={2} /></span>
      </div>
      <div className="t-seg">
        {['Açık','Teslim','İptal'].map((x,i)=>(<button key={x} className={`t-seg-b ${i===0?'on':''}`}>{x}</button>))}
      </div>
      <div className="t-govde">
        <div className="t-sliste">
          {sip.map((s)=>(
            <div className="t-srow" key={s.k}>
              <div className="t-srow-h">
                <span className="t-srow-k">{s.k}</span>
                <span className="t-srow-n">{s.ad}</span>
                <span className="t-srow-s"><Ikon ad="saat" boy={12} kalin={2.1} renk="#8B8794" />{s.s}</span>
              </div>
              <div className="t-srow-u">
                {s.u.map((u,i)=><span key={i}><i />{u}</span>)}
              </div>
              <div className="t-srow-a"><Ikon ad="konum" boy={14} kalin={2} />{s.adr}</div>
              {s.not && <div className="t-srow-not"><Ikon ad="uyari" boy={13} kalin={2.2} renk="#C08415" /><b>Not:</b> {s.not}</div>}
              <div className="t-srow-alt">
                <span className="t-srow-kur"><Ikon ad="kurye" boy={13} kalin={2} />{s.kur}</span>
                <span className="t-srow-t tab">{s.tut}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
      <TelNav aktif="sip" />
    </div>
  );
}

// Rota haritası — veri görselleştirmesi
function TelKurye(){
  const duraklar = [
    { n:1, x:62, y:58, ad:'Ahmet Yılmaz', adr:'Şirinyalı 42. Sk.', d:'ok' },
    { n:2, x:128, y:112, ad:'Hatice Demir', adr:'Meltem 3. Cd.', d:'ok' },
    { n:3, x:196, y:96, ad:'Selin Kaya', adr:'Fener Mah. 18. Sk.', d:'yolda' },
    { n:4, x:246, y:162, ad:'Murat Öz', adr:'Çağlayan 27. Sk.', d:'bekle' },
    { n:5, x:172, y:196, ad:'İbrahim Şahin', adr:'Bahçelievler 9. Sk.', d:'bekle' },
  ];
  const yol = 'M62 58 L128 112 L196 96 L246 162 L172 196';
  return (
    <div className="t-ekran">
      <TelDurum />
      <div className="t-ust">
        <span className="t-ust-ik"><Ikon ad="sol" boy={19} kalin={2.2} /></span>
        <span className="t-ust-m"><b>Kurye 1 · Rota</b><small>5 durak · 2 teslim edildi</small></span>
      </div>
      <div className="t-harita">
        <svg viewBox="0 0 320 240" className="t-harita-svg">
          <rect width="320" height="240" fill="#E8E5EF" />
          <path d="M0 200 Q80 186 150 200 T320 192 L320 240 L0 240Z" fill="#CFE0E8" />
          <rect x="28" y="24" width="74" height="52" rx="4" fill="#DFDCE8" />
          <rect x="120" y="18" width="96" height="44" rx="4" fill="#DFDCE8" />
          <rect x="236" y="34" width="62" height="66" rx="4" fill="#DFDCE8" />
          <rect x="36" y="104" width="66" height="70" rx="4" fill="#DFDCE8" />
          <rect x="150" y="118" width="60" height="52" rx="4" fill="#D6E7D2" />
          <rect x="228" y="126" width="70" height="48" rx="4" fill="#DFDCE8" />
          <g stroke="#F6F5F9" strokeWidth="11" strokeLinecap="round">
            <path d="M0 88 H320" /><path d="M0 182 H320" /><path d="M112 0 V240" /><path d="M222 0 V240" />
          </g>
          <path d={yol} fill="none" stroke="#5A45F0" strokeWidth="4.5" strokeLinecap="round" strokeLinejoin="round" strokeDasharray="1000" className="t-rota" />
          {duraklar.map((d)=>(
            <g key={d.n}>
              <circle cx={d.x} cy={d.y} r="13" fill={d.d==='ok'?'#1E9E6A':d.d==='yolda'?'#5A45F0':'#17141F'} />
              <text x={d.x} y={d.y+4.5} textAnchor="middle" fill="#fff" fontSize="12" fontWeight="800" fontFamily="Sora">{d.n}</text>
            </g>
          ))}
        </svg>
        <div className="t-harita-rzt"><i />Kurye 1 · 3. durakta</div>
      </div>
      <div className="t-govde t-govde-k">
        <div className="t-durak">
          {duraklar.map((d)=>(
            <div className={`t-dur ${d.d}`} key={d.n}>
              <span className="t-dur-n">{d.d==='ok' ? <Ikon ad="onay" boy={13} kalin={3} renk="#fff" /> : d.n}</span>
              <span className="t-dur-m"><b>{d.ad}</b><small>{d.adr}</small></span>
              <span className="t-dur-d">{d.d==='ok'?'Teslim':d.d==='yolda'?'Yolda':'Sırada'}</span>
            </div>
          ))}
        </div>
      </div>
      <TelNav aktif="sip" />
    </div>
  );
}

function TelGunsonu(){
  return (
    <div className="t-ekran">
      <TelDurum />
      <div className="t-ust">
        <span className="t-ust-ik"><Ikon ad="sol" boy={19} kalin={2.2} /></span>
        <span className="t-ust-m"><b>Gün sonu</b><small>2 Ağustos · 19 sipariş</small></span>
      </div>
      <div className="t-govde">
        <div className="t-bas">Kasa</div>
        <div className="t-kasa">
          {[['Nakit','6.240,00 ₺'],['Kart','4.120,00 ₺'],['Veresiye','2.120,00 ₺']].map((x,i)=>(
            <div className="t-kr" key={i}><span>{x[0]}</span><b className="tab">{x[1]}</b></div>
          ))}
          <div className="t-kr top"><span>Toplam ciro</span><b className="tab">12.480,00 ₺</b></div>
        </div>
        <div className="t-bas">Sayım</div>
        <div className="t-sayim">
          <div className="t-kr"><span>Kasada sayılan nakit</span><b className="tab">6.240,00 ₺</b></div>
          <div className="t-fark tam"><span>FARK YOK</span><b className="tab">0,00 ₺</b></div>
        </div>
        <div className="t-bas">Veresiye</div>
        <div className="t-kasa">
          <div className="t-kr"><span>Yeni açılan</span><b className="tab">2.120,00 ₺</b></div>
          <div className="t-kr"><span>Tahsil edilen</span><b className="tab" style={{color:'#1E9E6A'}}>−1.850,00 ₺</b></div>
        </div>
        <button className="t-btn mor genis"><Ikon ad="kilit" boy={17} kalin={2.2} renk="#fff" />Günü kapat</button>
      </div>
      <TelNav aktif="ana" />
    </div>
  );
}

const TEL_EKRAN = { ana: TelAna, musteri: TelMusteri, siparis: TelSiparis, kurye: TelKurye, gunsonu: TelGunsonu };

// Çerçeve — 412×892 içerik, `oran` ile ölçeklenir
function Telefon({ ekran = 'ana', oran = 0.72, cagri, bildirim, ciro, acik, isletme, stil }){
  const E = TEL_EKRAN[ekran] || TelAna;
  return (
    <div className="t-cerceve" style={{ '--s': oran, ...stil }}>
      <div className="t-ekranlik">
        <div className="t-ic">
          <E bildirim={bildirim} ciro={ciro} acik={acik} isletme={isletme} />
          {cagri && <TelCagri />}
        </div>
      </div>
      <span className="t-cizgi" />
    </div>
  );
}

// Hero için kendi kendine oynayan gösterim
function TelefonCanli({ oran = 0.72 }){
  const [f, setF] = React.useState(0); // 0 bekleme · 1 çağrı · 2 sipariş oluştu
  React.useEffect(() => {
    const sure = [2200, 4200, 3000][f];
    const t = setTimeout(() => setF((f + 1) % 3), sure);
    return () => clearTimeout(t);
  }, [f]);
  return <Telefon oran={oran} cagri={f === 1}
    bildirim={f === 2 ? 'Sipariş #1043 oluşturuldu' : null}
    ciro={f === 2 ? '12.570' : '12.480'} acik={f === 2 ? 8 : 7} />;
}

Object.assign(window, { Telefon, TelefonCanli });
