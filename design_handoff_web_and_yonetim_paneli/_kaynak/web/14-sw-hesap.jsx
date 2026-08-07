// sw-hesap.jsx — Hesap ve abonelik yönetimi. → window

const SW_HBOLUM = [
  { k: 'genel', ad: 'Genel bakış', ik: 'grafik' },
  { k: 'abonelik', ad: 'Abonelik', ik: 'rozet' },
  { k: 'hak', ad: 'Oto-sıralama', ik: 'simsek' },
  { k: 'fatura', ad: 'Faturalar', ik: 'belge' },
  { k: 'odeme', ad: 'Ödeme yöntemi', ik: 'kart' },
  { k: 'isletme', ad: 'İşletme bilgileri', ik: 'bina' },
];

function useHesap(){
  const { hesapDurum } = useYon();
  return hesapDurum === 'deneme' ? SW_HESAP_DENEME : SW_HESAP;
}

function HBos({ ikon, baslik, metin, cocuk }){
  return (
    <div className="hb-bos">
      <span className="hb-bos-ik"><Ikon ad={ikon} boy={22} kalin={1.9} renk="var(--sonuk)" /></span>
      <b className="h4">{baslik}</b>
      <p className="kucuk">{metin}</p>
      {cocuk}
    </div>
  );
}

function DurumBandi(){
  const d = useHesap();
  const deneme = d.durum === 'deneme';
  return (
    <div className="hd gece">
      <div className="hd-g">
        <span className="mn">Plan</span>
        <b className="h3">{deneme ? 'Deneme sürümü' : d.plan + ' · ' + (d.donem === 'yil' ? 'Yıllık' : 'Aylık')}</b>
        {deneme ? <Rozet tur="sari" nokta>Ücretsiz · 14 gün</Rozet> : <Rozet tur="yesil" nokta canli>Aktif</Rozet>}
      </div>
      <div className="hd-g">
        <span className="mn">{deneme ? 'Deneme bitişi' : 'Sonraki tahsilat'}</span>
        <b className="h3 tab">{deneme ? d.bitis : tl(d.sonrakiTutar)}</b>
        <span className="kucuk">{deneme ? 'O güne kadar ücret alınmaz' : d.sonrakiTarih}</span>
      </div>
      <div className="hd-g">
        <span className="mn">Kalan süre</span>
        <b className="h3 tab">{d.kalanGun} gün</b>
        <div className="hd-bar"><i className={deneme ? 'sari' : ''} style={{ width: (d.kalanGun / d.toplamGun * 100) + '%' }} /></div>
      </div>
      <div className="hd-g">
        <span className="mn">Firma kodu</span>
        <b className="h3">{d.firmaKodu}</b>
        <span className="kucuk">Ekibiniz uygulamaya bu kodla girer</span>
      </div>
    </div>
  );
}

function HGenel({ setB }){
  const { git, setSepet, bildir, hesapDurum } = useYon();
  const d = SW_HESAP;
  if(hesapDurum === 'deneme') return <HGenelDeneme setB={setB} />;
  return (
    <div className="hb">
      <div className="hb-ikili">
        <Pano etiket="Oto-sıralama hakkı" sag={<button className="dg dg-d gk" onClick={() => setB('hak')}>Yönet</button>}>
          <Kota etiket="Bu ay kullanılan" kullanilan={d.hak.kullanilan} toplam={d.hak.toplam}
            alt={`${d.hak.toplam - d.hak.kullanilan} hak kaldı · ${d.hak.yenileme} tarihinde yenilenir`} />
        </Pano>
        <Pano etiket="Kullanıcılar" sag={<button className="dg dg-d gk" onClick={() => bildir('Kurye hesabı ekleme yakında')}>Ekle</button>}>
          <Kota etiket="Kurye hesabı" kullanilan={d.kurye.kullanilan} toplam={d.kurye.toplam} renk="var(--yesil)"
            alt={`Planınız ${d.kurye.toplam} kurye içerir · ek hesap 99 ₺/ay`} />
        </Pano>
      </div>
      <Pano etiket="Kısayollar" ic={false}>
        <div className="hb-kisa">
          {[['kart', 'Ödeme bilgilerini gör', 'odeme'], ['belge', 'Son faturayı indir', 'fatura'],
            ['simsek', 'Ek oto-sıralama hakkı al', 'hak'], ['bina', 'Fatura bilgilerini düzenle', 'isletme']].map((x, i) => (
            <button className="hb-k" key={i} onClick={() => setB(x[2])}>
              <span className="hb-k-ik"><Ikon ad={x[0]} boy={19} kalin={2} renk="var(--mor)" /></span>
              <span>{x[1]}</span>
              <Ikon ad="sag" boy={17} kalin={2.2} renk="var(--sonuk)" />
            </button>
          ))}
        </div>
      </Pano>
      <Pano etiket="Son işlemler" ic={false} sag={<button className="dg dg-d gk" onClick={() => setB('fatura')}>Tümü</button>}>
        <table className="tbl">
          <tbody>
            {SW_FATURA.slice(0, 3).map((f) => (
              <tr key={f.no}>
                <td><b>{f.a}</b><br /><span className="kucuk">{f.t} · {f.y}</span></td>
                <td className="sag tab"><b>{tl(f.tutar)}</b></td>
                <td className="sag" style={{ width: 60 }}>
                  <button className="hb-ind" onClick={() => bildir('Fatura indiriliyor…')} aria-label="Faturayı indir"><Ikon ad="indir" boy={17} kalin={2} /></button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Pano>
    </div>
  );
}

// ── Deneme sürümü: hiç abone olmamış işletmenin gördüğü ekranlar ──
function PlanSecim({ secili, onSec }){
  return (
    <div className="dn-plan">
      {[{ k: 'yil', ad: 'Yıllık', fiyat: '499 ₺', alt: 'aylık · yılda 5.988 ₺ tek ödeme', rozet: '2 ay hediye' },
        { k: 'ay', ad: 'Aylık', fiyat: '599 ₺', alt: 'aylık · istediğiniz zaman bırakın' }].map((p) => (
        <button key={p.k} className={`dn-p ${secili === p.k ? 'on' : ''}`} onClick={() => onSec(p.k)}>
          {p.rozet && <span className="hak-rzt mn">{p.rozet}</span>}
          <span className="dn-p-ust"><i className="dn-p-r" />{p.ad}</span>
          <b className="h2 tab">{p.fiyat}</b>
          <span className="kucuk">{p.alt}</span>
        </button>
      ))}
    </div>
  );
}

function HGenelDeneme({ setB }){
  const { git, setSepet, bildir } = useYon();
  const d = SW_HESAP_DENEME;
  const bitti = d.kurulum.filter((k) => k.bitti).length;
  return (
    <div className="hb">
      <Pano etiket="Aboneliğe geçiş" sag={<Rozet tur="sari" nokta>{d.kalanGun} gün kaldı</Rozet>}>
        <div className="ab-ust">
          <div>
            <span className="h2">Deneme {d.bitis}’da bitiyor</span>
            <p className="gvd">Bittiğinde hesabınız salt-okunur kipe geçer — kayıtlarınız silinmez. Aboneliği şimdi başlatsanız bile ücret {d.bitis} tarihinde işler.</p>
          </div>
          <div className="ab-fiyat">
            <b className="rakam kucuk-rakam tab">499 ₺</b>
            <span className="kucuk">aylık · yıllık ödemede</span>
          </div>
        </div>
        <div className="dg-grup" style={{ marginTop: 22 }}>
          <button className="dg dg-a" onClick={() => setB('abonelik')}>Aboneliği başlat<Ikon ad="ok" boy={18} kalin={2.2} /></button>
          <button className="dg dg-d" onClick={() => { git('fiyat'); window.scrollTo(0, 0); }}>Planları karşılaştır</button>
        </div>
      </Pano>

      <Pano etiket="Kurulum" ic={false} sag={<span className="mn" style={{ color: 'var(--sonuk)' }}>{bitti}/{d.kurulum.length} tamam</span>}>
        <div className="dn-liste">
          {d.kurulum.map((k, i) => (
            <div className={`dn-s ${k.bitti ? 'ok' : ''}`} key={i}>
              <span className="dn-s-ik">{k.bitti
                ? <Ikon ad="onay" boy={15} kalin={2.6} renk="#fff" />
                : <b className="mn">{i + 1}</b>}</span>
              <span className="dn-s-m"><b>{k.ad}</b><small>{k.alt}</small></span>
              {!k.bitti && <button className="dg dg-d gk" onClick={() => bildir('Uygulamada bu adımı tamamlayın')}>Nasıl?</button>}
            </div>
          ))}
        </div>
      </Pano>

      <div className="hb-ikili">
        <Pano etiket="Oto-sıralama hakkı">
          <Kota etiket="Denemede kullanılan" kullanilan={d.hak.kullanilan} toplam={d.hak.toplam}
            alt={`Deneme boyunca ${d.hak.toplam} hak ücretsiz · ${d.hak.toplam - d.hak.kullanilan} hak kaldı`} />
        </Pano>
        <Pano etiket="Kullanıcılar">
          <Kota etiket="Kurye hesabı" kullanilan={d.kurye.kullanilan} toplam={d.kurye.toplam} renk="var(--yesil)"
            alt={`Denemede ${d.kurye.toplam} kurye hesabı açabilirsiniz`} />
        </Pano>
      </div>

      <Pano etiket="Başlarken yardım" ic={false}>
        <div className="hb-kisa">
          <button className="hb-k" onClick={() => bildir('Talebiniz alındı, bugün arayacağız')}>
            <span className="hb-k-ik"><Ikon ad="telefon" boy={19} kalin={2} renk="var(--mor)" /></span>
            <span><b>Kurulum görüşmesi ayarlayın</b><small>20 dakika · ekranınızı birlikte kuralım</small></span>
            <Ikon ad="sag" boy={17} kalin={2.2} renk="var(--sonuk)" />
          </button>
          <button className="hb-k" onClick={() => bildir('Aktarım talebiniz oluşturuldu, dosya bekliyoruz')}>
            <span className="hb-k-ik"><Ikon ad="katman" boy={19} kalin={2} renk="var(--mor)" /></span>
            <span><b>Mevcut müşteri listemi taşıyın</b><small>Excel veya defter fotoğrafı gönderin, biz gireriz</small></span>
            <Ikon ad="sag" boy={17} kalin={2.2} renk="var(--sonuk)" />
          </button>
          <button className="hb-k" onClick={() => { git('destek'); window.scrollTo(0, 0); }}>
            <span className="hb-k-ik"><Ikon ad="kulaklik" boy={19} kalin={2} renk="var(--mor)" /></span>
            <span><b>Destek merkezi</b><small>Sık sorulanlar ve video anlatımlar</small></span>
            <Ikon ad="sag" boy={17} kalin={2.2} renk="var(--sonuk)" />
          </button>
        </div>
      </Pano>
    </div>
  );
}

function HAbonelikDeneme(){
  const { git, setSepet, bildir } = useYon();
  const d = SW_HESAP_DENEME;
  const [plan, setPlan] = React.useState('yil');
  const basla = () => {
    setSepet({ tur: 'abonelik', plan: plan === 'yil' ? 'Sipario · Yıllık' : 'Sipario · Aylık', tutar: plan === 'yil' ? 5988 : 599 });
    git('odeme'); window.scrollTo(0, 0);
  };
  return (
    <div className="hb">
      <Pano etiket="Mevcut durum" sag={<Rozet tur="sari" nokta>Deneme</Rozet>}>
        <div className="ab-satirlar">
          <div className="ozet-r"><span>Deneme başlangıcı</span><b>{d.baslangic}</b></div>
          <div className="ozet-r"><span>Deneme bitişi</span><b>{d.bitis} · {d.kalanGun} gün kaldı</b></div>
          <div className="ozet-r"><span>Ödeme yöntemi</span><b style={{ color: 'var(--sonuk)' }}>Kayıtlı kart yok</b></div>
          <div className="ozet-r"><span>Otomatik yenileme</span><b style={{ color: 'var(--sonuk)' }}>Kapalı</b></div>
        </div>
        <hr className="ayrac" />
        <p className="kucuk">Deneme kendiliğinden ücretli aboneliğe dönmez. Karar vermezseniz hesap salt-okunur kipe geçer, verileriniz 12 ay saklanır.</p>
      </Pano>

      <Pano etiket="Aboneliği başlat">
        <PlanSecim secili={plan} onSec={setPlan} />
        <div className="ozet-r" style={{ marginTop: 22 }}><span>Bugün ödeyeceğiniz</span><b className="tab">0 ₺</b></div>
        <div className="ozet-r"><span>{d.bitis} tarihinde</span><b className="tab">{plan === 'yil' ? '5.988 ₺' : '599 ₺'}</b></div>
        <button className="dg dg-a tam" style={{ marginTop: 20 }} onClick={basla}>
          {plan === 'yil' ? 'Yıllık aboneliğe geç' : 'Aylık aboneliğe geç'}<Ikon ad="ok" boy={18} kalin={2.2} />
        </button>
        <p className="kucuk" style={{ marginTop: 14 }}>Aboneliği başlattığınızda ödemeyi havale/EFT ya da elden alıyoruz — kart bilgisi istemiyoruz. Kartla online ödeme yakında açılacak.</p>
      </Pano>

      <Pano ince etiket="Denemeyi bırak">
        <p className="gvd">İşinize uygun bulmadıysanız bir şey yapmanız gerekmez — deneme kendiliğinden sona erer. Hesabı şimdi kapatmak isterseniz verilerinizi önce Excel olarak indirin.</p>
        <div className="dg-grup" style={{ marginTop: 18 }}>
          <button className="dg dg-c" onClick={() => bildir('Dışa aktarma hazırlanıyor, e-posta ile göndereceğiz')}><Ikon ad="indir" boy={17} kalin={2.1} />Verilerimi indir</button>
          <button className="dg dg-t" onClick={() => bildir('Hesap kapatma talebi alındı')}>Hesabı kapat</button>
        </div>
      </Pano>
    </div>
  );
}

function HAbonelik(){
  const { bildir, hesapDurum } = useYon();
  const d = SW_HESAP;
  const [dg, setDg] = React.useState(null); // 'aylik' | 'kurumsal' | 'iptal'
  const [iptalSebep, setIptalSebep] = React.useState('');
  if(hesapDurum === 'deneme') return <HAbonelikDeneme />;
  return (
    <div className="hb">
      <Pano etiket="Mevcut plan" sag={<Rozet tur="yesil" nokta>Aktif</Rozet>}>
        <div className="ab-ust">
          <div>
            <span className="h2">{d.plan}</span>
            <p className="gvd">Yıllık ödeme · {d.baslangic} – {d.bitis}</p>
          </div>
          <div className="ab-fiyat">
            <b className="rakam kucuk-rakam tab">{tl(d.sonrakiTutar)}</b>
            <span className="kucuk">yılda bir · KDV dahil</span>
          </div>
        </div>
        <hr className="ayrac" />
        <div className="ab-satirlar">
          <div className="ozet-r"><span>Sonraki tahsilat</span><b>{d.sonrakiTarih}</b></div>
          <div className="ozet-r"><span>Ödeme yöntemi</span><b>{d.odemeYol}</b></div>
          <div className="ozet-r"><span>Otomatik yenileme</span><b style={{ color: 'var(--yesil)' }}>Açık</b></div>
        </div>
      </Pano>

      <Pano etiket="Planı değiştir" ic={false}>
        <div className="ab-sec">
          <button className="hb-k" onClick={() => setDg('aylik')}>
            <span className="hb-k-ik"><Ikon ad="takvim" boy={19} kalin={2} renk="var(--mor)" /></span>
            <span><b>Aylık ödemeye geç</b><small>599 ₺/ay · yıllık indirimden çıkarsınız</small></span>
            <Ikon ad="sag" boy={17} kalin={2.2} renk="var(--sonuk)" />
          </button>
          <button className="hb-k" onClick={() => setDg('kurumsal')}>
            <span className="hb-k-ik"><Ikon ad="katman" boy={19} kalin={2} renk="var(--mor)" /></span>
            <span><b>Kurumsal’a yükselt</b><small>Çok şube, rol yönetimi, kendi sunucunuz</small></span>
            <Ikon ad="sag" boy={17} kalin={2.2} renk="var(--sonuk)" />
          </button>
        </div>
      </Pano>

      <Pano ince etiket="Aboneliği sonlandır">
        <p className="gvd">İptal ettiğinizde dönem sonuna ({d.bitis}) kadar her şey aynı kalır; o tarihte otomatik yenileme durur. Verileriniz silinmez, salt-okunur kipte erişilebilir olur.</p>
        <button className="dg dg-t" style={{ marginTop: 18 }} onClick={() => setDg('iptal')}>Aboneliği iptal et</button>
      </Pano>

      <Diyalog acik={dg === 'aylik'} onKapat={() => setDg(null)} baslik="Aylık ödemeye geçiş"
        alt={<React.Fragment>
          <button className="dg dg-c" onClick={() => setDg(null)}>Vazgeç</button>
          <button className="dg dg-a" onClick={() => { setDg(null); bildir('Değişiklik 30 Mart 2027’de geçerli olacak'); }}>Değişikliği onayla</button>
        </React.Fragment>}>
        <p className="gvd">Değişiklik dönem sonunda geçerli olur — bugün ek ücret alınmaz.</p>
        <Pano ince duz sikIc stil={{ margin: '18px 0' }}>
          <div className="ozet-r"><span>Şu an</span><b className="tab">499 ₺ / ay</b></div>
          <div className="ozet-r"><span>30 Mart 2027’den sonra</span><b className="tab">599 ₺ / ay</b></div>
          <div className="ozet-r"><span>Yıllık fark</span><b className="tab" style={{ color: 'var(--kirmizi)' }}>+1.200 ₺</b></div>
        </Pano>
        <Kutu tur="sari" ikon="bilgi">Yıllık ödemedeki 2 ay hediye avantajını kaybedersiniz. İstediğiniz zaman yıllığa geri dönebilirsiniz.</Kutu>
      </Diyalog>

      <Diyalog acik={dg === 'kurumsal'} onKapat={() => setDg(null)} baslik="Kurumsal’a yükseltme"
        alt={<React.Fragment>
          <button className="dg dg-c" onClick={() => setDg(null)}>Kapat</button>
          <button className="dg dg-a" onClick={() => { setDg(null); bildir('Talebiniz alındı, bugün arayacağız'); }}>Beni arayın</button>
        </React.Fragment>}>
        <p className="gvd">Kurumsal fiyat şube ve kullanıcı sayısına göre belirlenir; bu yüzden panelden tek tıkla geçiş yapılmıyor.</p>
        <Pano ince duz sikIc stil={{ margin: '18px 0' }}>
          <div className="ozet-r"><span>Başlangıç fiyatı</span><b className="tab">1.499 ₺ / ay</b></div>
          <div className="ozet-r"><span>Kalan yıllık krediniz</span><b className="tab" style={{ color: 'var(--yesil)' }}>3.936 ₺ mahsup</b></div>
          <div className="ozet-r"><span>Geçiş süresi</span><b>2 iş günü</b></div>
        </Pano>
        <Kutu tur="mor" ikon="bilgi">Mevcut aboneliğinizden kalan {SW_HESAP.kalanGun} gün, yeni plandan düşülür. İki kez ödeme yapmazsınız.</Kutu>
      </Diyalog>

      <Diyalog acik={dg === 'iptal'} onKapat={() => setDg(null)} baslik="Aboneliği iptal et"
        alt={<React.Fragment>
          <button className="dg dg-c" onClick={() => setDg(null)}>Vazgeç</button>
          <button className="dg dg-t" onClick={() => { setDg(null); bildir('Aboneliğiniz 30 Mart 2027’de sonlanacak'); }}>İptali onayla</button>
        </React.Fragment>}>
        <p className="gvd"><b>{d.bitis}</b> tarihine kadar hiçbir şey değişmez. O tarihte yenileme durur ve hesap salt-okunur kipe geçer — kayıtlarınızı görmeye ve dışa aktarmaya devam edersiniz.</p>
        <Alan etiket="Neden ayrılıyorsunuz?" not="isteğe bağlı" id="ip-s">
          <select id="ip-s" className="gir" value={iptalSebep} onChange={(e) => setIptalSebep(e.target.value)} style={{ marginTop: 16 }}>
            <option value="">Belirtmek istemiyorum</option>
            <option>Fiyat yüksek geldi</option>
            <option>İhtiyacım olan özellik yok</option>
            <option>Başka bir uygulamaya geçtim</option>
            <option>İşletmeyi kapatıyorum</option>
            <option>Kullanmayı öğrenemedim</option>
          </select>
        </Alan>
        {iptalSebep === 'Fiyat yüksek geldi' && (
          <Kutu tur="mor" ikon="bilgi">Aylık ödemeye geçmek yerine aboneliği <b>3 ay dondurabilirsiniz</b> — veri kaybı olmaz, ücret işlemez. İsterseniz destek hattından ayarlayalım.</Kutu>
        )}
      </Diyalog>
    </div>
  );
}

function HHak(){
  const { git, setSepet, hesapDurum } = useYon();
  const d = useHesap();
  const deneme = hesapDurum === 'deneme';
  const al = (h) => { setSepet({ tur: 'hak', adet: h.adet, tutar: h.fiyat }); git('odeme'); window.scrollTo(0, 0); };
  return (
    <div className="hb">
      <Pano etiket={deneme ? 'Denemede kullanım' : 'Bu ayki kullanım'}>
        <Kota etiket="Oto-sıralama hakkı" kullanilan={d.hak.kullanilan} toplam={d.hak.toplam}
          alt={`${d.hak.toplam - d.hak.kullanilan} hak kaldı · ${deneme ? 'deneme boyunca geçerli' : d.hak.yenileme + ' tarihinde 50 hakka sıfırlanır'}`} />
        <hr className="ayrac" />
        <p className="gvd">Bir rota sıralaması çalıştırdığınızda bir hak düşer. Sıralamayı elle sürüklemek hak harcamaz. Kullanılmayan aylık haklar devretmez; satın aldığınız ek paketlerin süresi ise dolmaz.</p>
      </Pano>
      <Pano etiket="Ek paket al" ic={false}>
        {deneme && <div style={{ padding: '22px 22px 0' }}><Kutu tur="mor" ikon="bilgi">Denemede 50 hak zaten yüklü geliyor. Ek paketleri aboneliği başlattıktan sonra satın alabilirsiniz.</Kutu></div>}
        <div className="hak-grid hb-hak">
          {SW_HAKPAKET.map((h) => (
            <div className={`hak ${h.iyi && !deneme ? 'iyi' : ''}`} key={h.k}>
              {h.iyi && !deneme && <span className="hak-rzt mn">En avantajlı</span>}
              <span className="rakam">{h.adet}</span>
              <span className="hak-l mn">hak</span>
              <span className="hak-f">{tl(h.fiyat)}</span>
              <span className="kucuk">hak başına {(h.fiyat / h.adet).toFixed(2).replace('.', ',')} ₺</span>
              <button className="dg dg-c tam gk" disabled={deneme} onClick={() => al(h)}>Satın al</button>
            </div>
          ))}
        </div>
      </Pano>
    </div>
  );
}

function HFatura(){
  const { bildir, hesapDurum } = useYon();
  if(hesapDurum === 'deneme') return (
    <div className="hb">
      <Pano etiket="Fatura geçmişi" ic={false}>
        <HBos ikon="belge" baslik="Henüz fatura yok" metin="Deneme sürümü ücretsiz olduğu için fatura kesilmez. İlk faturanız aboneliği başlattığınızda, ilk tahsilat gününde oluşur." />
      </Pano>
      <Kutu tur="mor" ikon="bilgi">Faturalar e-arşiv olarak düzenlenir ve e-posta adresinize gönderilir. Unvan, VKN ve adres bilgilerinizi şimdiden <b>İşletme bilgileri</b> bölümünden girebilirsiniz.</Kutu>
    </div>
  );
  return (
    <div className="hb">
      <Pano etiket="Fatura geçmişi" ic={false}
        sag={<button className="dg dg-d gk" onClick={() => bildir('Tüm faturalar ZIP olarak indiriliyor…')}><Ikon ad="indir" boy={15} kalin={2} />Tümünü indir</button>}>
        <div className="tbl-sar">
          <table className="tbl">
            <thead><tr><th>Fatura</th><th>Tarih</th><th>Yöntem</th><th className="sag">Tutar</th><th className="sag">Durum</th><th /></tr></thead>
            <tbody>
              {SW_FATURA.map((f) => (
                <tr key={f.no}>
                  <td><b>{f.no}</b><br /><span className="kucuk">{f.a}</span></td>
                  <td className="tab">{f.t}</td>
                  <td className="kucuk">{f.y}</td>
                  <td className="sag tab"><b>{tl(f.tutar)}</b></td>
                  <td className="sag"><Rozet tur="yesil">Ödendi</Rozet></td>
                  <td className="sag" style={{ width: 60 }}>
                    <button className="hb-ind" onClick={() => bildir(`${f.no} indiriliyor…`)} aria-label="İndir"><Ikon ad="indir" boy={17} kalin={2} /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Pano>
      <Kutu tur="mor" ikon="bilgi">Faturalar e-arşiv olarak düzenlenir ve ödeme gününde e-posta adresinize de gönderilir. Unvan veya adres hatalıysa <b>İşletme bilgileri</b> bölümünden düzeltin; düzeltme sonraki faturaya yansır.</Kutu>
    </div>
  );
}

function HOdeme(){
  const { bildir, hesapDurum } = useYon();
  const d = useHesap();
  const deneme = hesapDurum === 'deneme';
  return (
    <div className="hb">
      <Pano etiket="Havale / EFT" sag={<Rozet tur="yesil" nokta>Kullanımda</Rozet>}>
        <p className="gvd">{deneme
          ? 'Aboneliği başlattığınızda ödemeyi banka havalesiyle alabilirsiniz. Dekont ulaştığı gün hesabınız açılır.'
          : 'Yenileme tarihinden önce aşağıdaki hesaba ödeme yapın. Açıklama alanına referans kodunuzu yazın; dekont ulaştığı gün dönem uzatılır.'}</p>
        <hr className="ayrac" />
        <div className="ab-satirlar">
          <div className="ozet-r"><span>Alıcı ünvanı</span><b>{SW_KUNYE.unvan}</b></div>
          <div className="ozet-r"><span>IBAN</span><b className="tab">TR12 0001 0000 0000 0000 0000 01</b></div>
          <div className="ozet-r"><span>Referans kodu</span><b className="tab">SIP-{d.firmaKodu.toLocaleUpperCase('tr')}</b></div>
        </div>
        <div className="dg-grup" style={{ marginTop: 20 }}>
          <button className="dg dg-c" onClick={() => bildir('Hesap bilgileri kopyalandı')}><Ikon ad="kopyala" boy={17} kalin={2.1} />Bilgileri kopyala</button>
          <button className="dg dg-d" onClick={() => bildir('Havale bilgileri e-postanıza gönderildi')}><Ikon ad="posta" boy={17} kalin={2.1} />E-posta ile gönder</button>
        </div>
      </Pano>

      <Pano etiket="Elden ödeme" sag={<Rozet tur="yesil" nokta>Kullanımda</Rozet>}>
        <p className="gvd">Ankara, Antalya ve İzmir’de ödemeyi elden alıyoruz. Talebinizi bırakın, aynı gün arayarak saat ayarlayalım; makbuzunuz teslimde verilir.</p>
        <button className="dg dg-c" style={{ marginTop: 18 }} onClick={() => bildir('Talebiniz alındı, bugün arayacağız')}><Ikon ad="telefon" boy={17} kalin={2.1} />Beni arayın</button>
      </Pano>

      <Pano ince etiket="Kart ile ödeme" sag={<Rozet tur="notr">Yakında</Rozet>}>
        <HBos ikon="kart" baslik="Kartla ödeme henüz açık değil"
          metin="Kredi ve banka kartıyla online ödeme üzerinde çalışıyoruz. Açıldığında kartınızı buradan kaydedip otomatik yenilemeye geçebileceksiniz."
          cocuk={<button className="dg dg-d k" style={{ marginTop: 14 }} onClick={() => bildir('Açıldığında size haber vereceğiz')}>Açılınca haber ver</button>} />
      </Pano>
    </div>
  );
}

function HIsletme(){
  const { bildir, setOturum, git } = useYon();
  const d = useHesap();
  const [f, setF] = React.useState({ ...d, ...d.fatura });
  const y = (k, v) => setF((x) => ({ ...x, [k]: v }));
  return (
    <div className="hb">
      <Pano etiket="İşletme">
        <Alan etiket="İşletme adı" id="i-a"><input id="i-a" className="gir" value={f.isletme} onChange={(e) => y('isletme', e.target.value)} /></Alan>
        <Alan etiket="Firma kodu" id="i-k" ipucu="Ekibiniz mobil uygulamaya bu kodla girer. Değiştirirseniz herkesin yeniden giriş yapması gerekir.">
          <div className="kod-gir">
            <span className="kod-on mn">sipario.com.tr /</span>
            <input id="i-k" className="gir" value={f.firmaKodu} onChange={(e) => y('firmaKodu', e.target.value.toLowerCase().replace(/[^a-z0-9]/g, ''))} />
          </div>
        </Alan>
        <div className="alan-ikili">
          <Alan etiket="Yetkili" id="i-y"><input id="i-y" className="gir" value={f.yetkili} onChange={(e) => y('yetkili', e.target.value)} /></Alan>
          <Alan etiket="Telefon" id="i-t"><input id="i-t" className="gir" type="tel" inputMode="tel" value={f.telefon} onChange={(e) => y('telefon', e.target.value)} /></Alan>
        </div>
        <Alan etiket="E-posta" id="i-e" ipucu="Fatura ve hesap bildirimleri bu adrese gider."><input id="i-e" className="gir" type="email" inputMode="email" value={f.eposta} onChange={(e) => y('eposta', e.target.value)} /></Alan>
      </Pano>

      <Pano etiket="Fatura bilgileri">
        <Kutu tur="mor" ikon="bilgi">Buradaki bilgiler e-arşiv faturanızda görünür. Değişiklik sonraki faturadan itibaren geçerli olur.</Kutu>
        <div style={{ height: 20 }} />
        <Alan etiket="Ünvan" id="f-u"><input id="f-u" className="gir" value={f.unvan} onChange={(e) => y('unvan', e.target.value)} /></Alan>
        <div className="alan-ikili">
          <Alan etiket="VKN / TCKN" id="f-v"><input id="f-v" className="gir" inputMode="numeric" value={f.vkn} onChange={(e) => y('vkn', e.target.value.replace(/\D/g, '').slice(0, 11))} /></Alan>
          <Alan etiket="Vergi dairesi" id="f-d"><input id="f-d" className="gir" value={f.daire} onChange={(e) => y('daire', e.target.value)} /></Alan>
        </div>
        <Alan etiket="Adres" id="f-a"><input id="f-a" className="gir" value={f.adres} onChange={(e) => y('adres', e.target.value)} /></Alan>
        <div className="alan-ikili">
          <Alan etiket="İlçe" id="f-i"><input id="f-i" className="gir" value={f.ilce} onChange={(e) => y('ilce', e.target.value)} /></Alan>
          <Alan etiket="İl" id="f-l"><input id="f-l" className="gir" value={f.il} onChange={(e) => y('il', e.target.value)} /></Alan>
        </div>
        <button className="dg dg-a" style={{ marginTop: 6 }} onClick={() => bildir('İşletme bilgileri kaydedildi')}>Değişiklikleri kaydet</button>
      </Pano>

      <Pano ince etiket="Veri ve hesap">
        <div className="hb-kisa">
          <button className="hb-k" onClick={() => bildir('Dışa aktarma hazırlanıyor, e-posta ile göndereceğiz')}>
            <span className="hb-k-ik"><Ikon ad="indir" boy={19} kalin={2} renk="var(--mor)" /></span>
            <span><b>Verilerimi dışa aktar</b><small>Müşteri, sipariş ve defter kayıtları · Excel</small></span>
            <Ikon ad="sag" boy={17} kalin={2.2} renk="var(--sonuk)" />
          </button>
          <button className="hb-k" onClick={() => { setOturum(false); git('ana'); window.scrollTo(0, 0); bildir('Çıkış yapıldı'); }}>
            <span className="hb-k-ik"><Ikon ad="cikis" boy={19} kalin={2} renk="var(--kirmizi)" /></span>
            <span><b>Çıkış yap</b><small>Bu tarayıcıdaki oturumu kapat</small></span>
            <Ikon ad="sag" boy={17} kalin={2.2} renk="var(--sonuk)" />
          </button>
        </div>
      </Pano>
    </div>
  );
}

const H_BOLUM = { genel: HGenel, abonelik: HAbonelik, hak: HHak, fatura: HFatura, odeme: HOdeme, isletme: HIsletme };

function HesapSayfa(){
  const { hesapDurum, setHesapDurum } = useYon();
  const [b, setB] = React.useState('genel');
  const d = hesapDurum === 'deneme' ? SW_HESAP_DENEME : SW_HESAP;
  const B = H_BOLUM[b];
  const bas = SW_HBOLUM.find((x) => x.k === b);
  return (
    <main className="ic hesap">
      <div className="kap">
        <div className="hs-bas">
          <div>
            <span className="blm-kulak mn"><i />Hesap</span>
            <h1 className="h1 ic-h1">{d.isletme}</h1>
            <p className="kucuk">{d.yetkili} · {d.eposta}</p>
          </div>
          <div className="hs-onizle">
            <span className="mn">Önizleme</span>
            <button className={hesapDurum === 'deneme' ? 'on' : ''} onClick={() => setHesapDurum('deneme')}>Deneme</button>
            <button className={hesapDurum === 'aktif' ? 'on' : ''} onClick={() => setHesapDurum('aktif')}>Abone</button>
          </div>
        </div>
        <DurumBandi />
        <div className="hs-ic">
          <nav className="hs-nav">
            {SW_HBOLUM.map((x) => (
              <button key={x.k} className={`hs-l ${b === x.k ? 'on' : ''}`} onClick={() => setB(x.k)}>
                <Ikon ad={x.ik} boy={18} kalin={2} />{x.ad}
              </button>
            ))}
          </nav>
          <div className="hs-govde">
            <h2 className="h2 hs-h2">{bas.ad}</h2>
            <B setB={setB} />
          </div>
        </div>
      </div>
    </main>
  );
}

Object.assign(window, { HesapSayfa, SW_HBOLUM });
