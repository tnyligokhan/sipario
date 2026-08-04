// sw-ana.jsx — Ana sayfa. → window

function HeroBlm(){
  const { git } = useYon();
  return (
    <section className="hero gece">
      <div className="hero-isik" />
      <div className="kap hero-ic">
        <div className="hero-sol">
          <span className="blm-kulak mn"><i />Bayiler · esnaf · yerel teslimat</span>
          <h1 className="h-dev">Telefon çaldığında<br />müşteriniz<br /><em>ekranda.</em></h1>
          <p className="gvd b hero-alt">Sipario, gelen numarayı müşteri defterinizle eşleştirir: kim aradı, nerede oturuyor, ne kadar borcu var, en son ne almıştı — daha “alo” demeden ekranda.</p>
          <div className="dg-grup hero-dg">
            <button className="dg dg-a dev" onClick={() => git('kayit')}>14 gün ücretsiz dene<Ikon ad="ok" boy={19} kalin={2.2} /></button>
            <button className="dg dg-c dev" onClick={() => git('ozellik')}>Nasıl çalıştığını gör</button>
          </div>
          <ul className="hero-guvence">
            <li><Ikon ad="onay" boy={16} kalin={2.6} renk="#4FD69C" />Kart bilgisi istemiyoruz</li>
            <li><Ikon ad="onay" boy={16} kalin={2.6} renk="#4FD69C" />Kurulum 10 dakika</li>
            <li><Ikon ad="onay" boy={16} kalin={2.6} renk="#4FD69C" />Müşteri aktarımı bizden</li>
          </ul>
        </div>
        <div className="hero-sag"><TelefonCanli oran={0.72} /></div>
      </div>
      <div className="hero-serit">
        <div className="kap hero-serit-ic">
          <span className="mn">Her gün kullanan işletmeler</span>
          <div className="hero-sektor">
            {SW_SEKTOR.map((s) => <span key={s}>{s}</span>)}
          </div>
        </div>
      </div>
    </section>
  );
}

function KanitBlm(){
  return (
    <section className="blm kisa kanit-blm">
      <div className="kap kanit-grid">
        {SW_KANIT.map((k, i) => (
          <div className="kanit" key={i}>
            <span className="rakam">{k.v}</span>
            <span className="kanit-b mn">{k.b}</span>
            <p className="kucuk">{k.a}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function DertBlm(){
  return (
    <section className="blm kagit2">
      <div className="kap">
        <BlmBas kulak="Sorun" baslik="Kâğıt defter iyi bir defterdir. Kötü bir sistemdir."
          aciklama="Üç yerde sızdırır: alacakta, telefonda ve akşam kasada. Sipario tam bu üç yeri kapatmak için var." />
        <div className="dert-grid">
          {SW_DERT.map((d, i) => (
            <div className="dert" key={i}>
              <div className="dert-ust">
                <span className="dert-no mn">{String(i + 1).padStart(2, '0')}</span>
                <span className="dert-ik"><Ikon ad={d.ik} boy={22} kalin={1.9} /></span>
              </div>
              <h3 className="h3">{d.t}</h3>
              <p className="gvd dert-a">{d.a}</p>
              <div className="dert-c">
                <Ikon ad="ok" boy={16} kalin={2.4} renk="var(--mor)" />
                <span>{d.c}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function TurBlm(){
  const [k, setK] = React.useState('cagri');
  const t = SW_TUR.find((x) => x.k === k);
  const ekran = { cagri: 'ana', veresiye: 'musteri', siparis: 'siparis', kurye: 'kurye', gunsonu: 'gunsonu' }[k];
  return (
    <section className="blm tur-blm">
      <div className="kap">
        <BlmBas kulak="Ürün turu" baslik="Ekranın kendisi. Ekran görüntüsü değil."
          aciklama="Aşağıdaki telefon çalışan arayüzün ta kendisi — uygulamadaki ölçüler, renkler ve yerleşimle birebir." />
        <Sekmeler liste={SW_TUR.map((x) => ({ k: x.k, ad: x.ad, ik: x.ik }))} secili={k} onSec={setK} />
        <div className="tur-ic">
          <div className="tur-tel">
            <Telefon key={k} ekran={ekran} oran={0.66} cagri={k === 'cagri'} />
          </div>
          <div className="tur-metin" key={k + '-m'}>
            <h3 className="h2">{t.bas}</h3>
            <p className="gvd b">{t.a}</p>
            <ul className="tur-liste">
              {t.ozet.map((o, i) => (
                <li key={i}><span className="tur-tik"><Ikon ad="onay" boy={13} kalin={3} renk="#fff" /></span>{o}</li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}

function AdimBlm(){
  const { git } = useYon();
  return (
    <section className="blm kagit2">
      <div className="kap">
        <BlmBas kulak="Kurulum" baslik="Bugün başlayın, bugün kullanın."
          aciklama="Bilgisayar, kablo, teknik ekip yok. Telefonunuzdaki uygulamayı indirip firma kodunuzla giriyorsunuz." />
        <div className="adim-grid">
          {SW_ADIM.map((a) => (
            <div className="adim" key={a.n}>
              <div className="adim-ust">
                <span className="adim-no">{a.n}</span>
                <Rozet tur="mor">{a.s}</Rozet>
              </div>
              <h3 className="h3">{a.t}</h3>
              <p className="gvd">{a.a}</p>
            </div>
          ))}
        </div>
        <div className="adim-alt">
          <button className="dg dg-b" onClick={() => git('kayit')}>İşletmenizi açın<Ikon ad="ok" boy={18} kalin={2.2} /></button>
          <span className="kucuk">Müşteri listenizi biz aktarıyoruz — Excel ya da rehber, fark etmez.</span>
        </div>
      </div>
    </section>
  );
}

function GuvenceBlm(){
  return (
    <section className="blm gece guvence-blm">
      <div className="kap">
        <BlmBas kulak="Güvence" baslik="İşin durursa defter de durur. O yüzden durmuyor." />
        <div className="guvence-grid">
          {SW_GUVENCE.map((g, i) => (
            <div className="guvence" key={i}>
              <span className="guvence-ik"><Ikon ad={g.ik} boy={22} kalin={1.9} renk="#B3A6FF" /></span>
              <h3 className="h3">{g.t}</h3>
              <p className="gvd">{g.a}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function YorumBlm(){
  return (
    <section className="blm">
      <div className="kap">
        <BlmBas kulak="Kullananlar" baslik="Rakamı değişen işletmeler." />
        <div className="yorum-grid">
          {SW_YORUM.map((y, i) => (
            <figure className="yorum" key={i}>
              <span className="yorum-t"><Ikon ad="tirnak" boy={22} kalin={1.8} renk="var(--mor)" /></span>
              <blockquote className="h3 yorum-s">{y.s}</blockquote>
              <figcaption>
                <b>{y.k}</b>
                <span className="kucuk">{y.r}</span>
                <span className="mn k yorum-m">{y.m}</span>
              </figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}

function FiyatOzetBlm(){
  const { git } = useYon();
  const p = SW_PLAN[0], q = SW_PLAN[1];
  return (
    <section className="blm kagit2">
      <div className="kap">
        <BlmBas kulak="Fiyat" baslik="Tek plan. Gizli kalem yok."
          aciklama="Kaç müşteriniz olduğuna, kaç sipariş girdiğinize bakmıyoruz. Fiyat aşağıda yazan fiyat." />
        <div className="fo-grid">
          <Pano sinif="fo fo-vurgu" etiket="En çok seçilen" sag={<Rozet tur="mor" nokta>{p.rozet}</Rozet>} genisIc>
            <div className="fo-bas">
              <span className="h2">{p.ad}</span>
              <p className="gvd">{p.ozet}</p>
            </div>
            <div className="fo-fiyat">
              <span className="rakam">{tl(p.yil)}</span>
              <span className="fo-donem">/ ay<br /><small>yıllık ödemede · {p.hediye}</small></span>
            </div>
            <p className="kucuk fo-not">Aylık ödemede {tl(p.ay)}/ay. Yıllık {tl(p.yilToplam)}, kartla 12 taksite kadar.</p>
            <ul className="fo-liste">
              {p.kapsam.slice(0, 5).map((x, i) => (
                <li key={i}><Ikon ad="onay" boy={16} kalin={2.6} renk="var(--yesil)" />{x.t}</li>
              ))}
              <li className="fo-daha">+ {p.kapsam.length - 5} özellik daha</li>
            </ul>
            <button className="dg dg-a tam" onClick={() => git('kayit')}>{p.cta}</button>
            <span className="kucuk fo-alt">{p.ctaAlt}</span>
          </Pano>
          <Pano sinif="fo" ince etiket="Çok şubeli" genisIc>
            <div className="fo-bas">
              <span className="h2">{q.ad}</span>
              <p className="gvd">{q.ozet}</p>
            </div>
            <div className="fo-fiyat">
              <span className="rakam kucuk-rakam">{q.ozelFiyat}</span>
            </div>
            <p className="kucuk fo-not">Şube ve kullanıcı sayısına göre. Kendi sunucunuzda kurulum dahil.</p>
            <ul className="fo-liste">
              {q.kapsam.slice(0, 5).map((x, i) => (
                <li key={i}><Ikon ad="onay" boy={16} kalin={2.6} renk="var(--yesil)" />{x.t}</li>
              ))}
              <li className="fo-daha">+ {q.kapsam.length - 5} özellik daha</li>
            </ul>
            <button className="dg dg-c tam" onClick={() => git('iletisim')}>{q.cta}</button>
            <span className="kucuk fo-alt">{q.ctaAlt}</span>
          </Pano>
        </div>
        <div className="fo-link">
          <button className="dg dg-d" onClick={() => { git('fiyat'); window.scrollTo(0, 0); }}>Paketleri karşılaştır<Ikon ad="sag" boy={18} kalin={2.2} /></button>
        </div>
      </div>
    </section>
  );
}

function SssOzetBlm(){
  const { git } = useYon();
  const liste = [...SW_SSS[0].l.slice(0, 2), ...SW_SSS[1].l.slice(0, 2)];
  return (
    <section className="blm">
      <div className="kap sss-kap">
        <BlmBas kulak="Sık sorulanlar" baslik="Akla ilk gelenler." />
        <SssListe liste={liste} acikVar />
        <button className="dg dg-d sss-daha" onClick={() => { git('destek'); window.scrollTo(0, 0); }}>Tüm soruları gör<Ikon ad="sag" boy={18} kalin={2.2} /></button>
      </div>
    </section>
  );
}

function SonCagri(){
  const { git } = useYon();
  return (
    <section className="son gece">
      <div className="kap son-ic">
        <div>
          <h2 className="h1">Bu akşam kasayı<br />Sipario ile kapatın.</h2>
          <p className="gvd b son-alt">14 gün ücretsiz. Kart bilgisi yok, taahhüt yok. Beğenmezseniz verinizi Excel olarak alıp gidersiniz.</p>
        </div>
        <div className="son-dg">
          <button className="dg dg-a dev" onClick={() => git('kayit')}>İşletmenizi açın<Ikon ad="ok" boy={19} kalin={2.2} /></button>
          <button className="dg dg-c dev" onClick={() => git('iletisim')}>Önce konuşalım</button>
        </div>
      </div>
    </section>
  );
}

function AnaSayfa(){
  return (
    <main>
      <HeroBlm /><KanitBlm /><DertBlm /><TurBlm /><AdimBlm />
      <GuvenceBlm /><YorumBlm /><FiyatOzetBlm /><SssOzetBlm /><SonCagri />
    </main>
  );
}

Object.assign(window, { AnaSayfa });
