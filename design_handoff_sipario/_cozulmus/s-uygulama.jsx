// s-uygulama.jsx — Sipario kök: state, routing, rol bazlı menü, ekran durumları, tweaks. → window

const { useState, useRef, useEffect } = React;

const S_TWEAKS = /*EDITMODE-BEGIN*/{
  "rol": "patron",
  "durum": "normal"
}/*EDITMODE-END*/;

function App() {
  const t = (window.__omGetTweaks && window.__omGetTweaks()) || S_TWEAKS;
  const [girisli, setGirisli] = useState(false);
  const [sihirbazAcik, setSihirbazAcik] = useState(false);
  const [tab, setTab] = useState('siparis');
  const [cekmeceAcik, setCekmece] = useState(false);
  const [alt, setAlt] = useState(null); // {ekran, veri}
  const [musteriler, setMusteriler] = useState(MUSTERILER);
  const [siparisler, setSiparisler] = useState(SIPARISLER);
  const [urunler, setUrunler] = useState(URUNLER);
  const [kuryeler, setKuryeler] = useState([{ id: 'k1', ad: 'Ben', tel: '0532 000 00 00', aktif: true }, { id: 'k2', ad: 'Kurye 1', tel: '0533 111 11 11', aktif: true }, { id: 'k3', ad: 'Kurye 2', tel: '', aktif: false }]);
  const [tema, setTema] = useState(() => { try { return localStorage.getItem('sipario_tema') || 'acik'; } catch (e) { return 'acik'; } });
  const [arsiv, setArsiv] = useState([]);
  const [yeniMusteri, setYeniMusteri] = useState(null); // null | {tel}
  const [isletme, setIsletme] = useState(ISLETME);
  const temaDegis = () => setTema((t) => { const y = t === 'koyu' ? 'acik' : 'koyu'; try { localStorage.setItem('sipario_tema', y); } catch (e) {} return y; });
  const [cagri, setCagri] = useState(null);
  const [toast, setToast] = useState(null);
  const [onay, setOnay] = useState(null);
  const [yeniSip, setYeniSip] = useState(null); // {musteri}
  const [muaflar, setMuaflar] = useState([{ id: 'mf1', ad: 'Kurye 1', no: '0533 111 11 11' }]);
  const [sipDetay, setSipDetay] = useState(null); // sipariş objesi (id ile canlı çözülür)
  const toastRef = useRef(null);

  const rol = t.rol || 'patron';
  const durum = t.durum || 'normal';
  const kilit = durum === 'kilit';
  const cevrimdisi = durum === 'cevrimdisi';

  const ping = (msg) => { setToast(msg); clearTimeout(toastRef.current); toastRef.current = setTimeout(() => setToast(null), 2200); };

  const teslimEt = (o, odeme, kurye) => {
    setSiparisler((prev) => prev.map((x) => x.id === o.id ? { ...x, durum: 'teslim', odeme, kurye } : x));
    setSipDetay(null); ping('Sipariş teslim edildi');
  };
  const iptalEt = (o) => setOnay({ baslik: 'Sipariş iptal edilsin mi?', mesaj: 'Sipariş iptal olarak işaretlenecek.', onayLabel: 'İptal Et', tehlike: true, fn: () => { setSiparisler((prev) => prev.map((x) => x.id === o.id ? { ...x, durum: 'iptal' } : x)); setSipDetay(null); setOnay(null); ping('Sipariş iptal edildi'); } });
  const konumKaydet = (mId, k) => { setMusteriler((prev) => prev.map((x) => x.id === mId ? { ...x, adresler: x.adresler.map((a, i) => i === 0 ? { ...a, konum: k } : a) } : x)); ping('Konum kaydedildi'); };
  const musGuncelle = (id, f) => { setMusteriler((prev) => prev.map((x) => x.id === id ? { ...x, ad: f.ad, not: f.not, telefonlar: f.telefonlar, adresler: f.adres ? [{ ...(x.adresler || [])[0], metin: f.adres, bolge: f.bolge, etiket: 'Ev', konum: ((x.adresler || [])[0] || {}).konum || null }, ...(x.adresler || []).slice(1)] : (x.adresler || []) } : x)); ping('Müşteri bilgileri güncellendi'); };
  const siparisKaydet = (mus, data) => {
    const yeni = { id: 's' + Date.now(), musteriId: mus.id, musteriAd: mus.ad, durum: 'acik', saat: 'şimdi', kurye: 'Ben', odeme: null, ...data };
    setSiparisler((prev) => [yeni, ...prev]); setYeniSip(null); setTab('siparis'); ping('Sipariş oluşturuldu');
  };
  const urunKaydet = (u) => { setUrunler((prev) => u.id ? prev.map((x) => x.id === u.id ? { ...x, ...u } : x) : [...prev, { ...u, id: 'u' + Date.now() }]); ping('Ürün kaydedildi'); };

  if (!girisli) return (
    <div className={`app ${tema === 'koyu' ? 'koyu' : ''}`}>
      <GirisEkran onGiris={() => { setGirisli(true); setSihirbazAcik(true); }} />
      <SistemCubuklari beyaz={true} />
    </div>
  );

  if (sihirbazAcik) return <div className={`app ${tema === 'koyu' ? 'koyu' : ''}`}><Sihirbaz onBitti={() => { setSihirbazAcik(false); ping('Kurulum tamamlandı'); }} onKapat={() => setSihirbazAcik(false)} /><SistemCubuklari beyaz={tema === 'koyu'} /></div>;

  // Alt ekranlar (tam sayfa)
  let altEkran = null;
  if (alt) {
    if (alt.ekran === 'musteriDetay') { const m = musteriler.find((x) => x.id === alt.veri.id) || alt.veri; altEkran = <MusteriDetay m={m} onGeri={() => setAlt(null)} onSiparis={(mm) => { setAlt(null); setYeniSip({ musteri: mm }); }} onPing={ping}
      onTahsilatKaydet={(mm, tutar, odeme) => { setMusteriler((prev) => prev.map((x) => x.id === mm.id ? { ...x, bakiye: x.bakiye - tutar, hareketler: [{ tip: 'tahsilat', odeme, tutar, saat: 'şimdi', not: '' }, ...(x.hareketler || [])] } : x)); ping(`Tahsilat kaydedildi · ${fmtTL(tutar)}`); }}
      onDuzeltKaydet={(mm, delta, not) => { setMusteriler((prev) => prev.map((x) => x.id === mm.id ? { ...x, bakiye: x.bakiye + delta, hareketler: [{ tip: 'duzeltme', odeme: null, tutar: Math.abs(delta), yon: delta < 0 ? 'eksi' : 'arti', saat: 'şimdi', not }, ...(x.hareketler || [])] } : x)); ping('Düzeltme deftere işlendi'); }}
      tumMusteriler={musteriler}
      onMusteriGuncelle={musGuncelle}
      onKonumSec={(mm, k) => konumKaydet(mm.id, k)} />; }
    else if (alt.ekran === 'kuryeler') altEkran = <KuryelerEkran kuryeler={kuryeler} onGeri={() => setAlt(null)} onKaydet={(k) => { setKuryeler((prev) => k.id ? prev.map((x) => x.id === k.id ? { ...x, ...k } : x) : [...prev, { ...k, id: 'k' + Date.now() }]); ping('Kurye kaydedildi'); }} />;
    else if (alt.ekran === 'muaf') altEkran = <MuafEkran muaflar={muaflar} onGeri={() => setAlt(null)} onPing={ping}
      onEkle={(m) => { setMuaflar((prev) => [m, ...prev]); ping('Muaf listeye eklendi — artık çağrı kartı çıkmaz'); }}
      onSil={(m) => { setMuaflar((prev) => prev.filter((x) => x.id !== m.id)); ping('Muaf listeden çıkarıldı'); }} />;
    else if (alt.ekran === 'urunler') altEkran = <UrunlerEkran urunler={urunler} onGeri={() => setAlt(null)} onKaydet={urunKaydet} onPing={ping} />;
    else if (alt.ekran === 'ayarlar') altEkran = <AyarlarEkran tema={tema} onTema={temaDegis} onGeri={() => setAlt(null)} onPing={ping} isletme={isletme} onIsletme={() => setAlt({ ekran: 'isletme' })} onSihirbaz={() => setSihirbazAcik(true)} onCagriSim={(no) => setCagri(no || '0532 415 22 90')} />;
    else if (alt.ekran === 'isletme') altEkran = <IsletmeProfil isletme={isletme} onGeri={() => setAlt({ ekran: 'ayarlar' })} onPing={ping} onKaydet={(f) => { setIsletme(f); setAlt({ ekran: 'ayarlar' }); ping('İşletme bilgileri kaydedildi'); }} />;
    else if (alt.ekran === 'profil') altEkran = <div className="ekran"><Ust baslik="İşletme Profili" onGeri={() => setAlt(null)} /><div className="ekran-govde"><div className="md-not"><Icon name="settings" size={16} sw={2} color="var(--accent)" /><span>{ISLETME.ad} · {ISLETME.sahip} · {ISLETME.telefon}</span></div></div></div>;
  }

  // Ana sekme içeriği
  let icerik;
  const cekmeceAc = (k) => { setCekmece(false); if (k === 'sihirbaz') setSihirbazAcik(true); else if (k === 'gunsonu') setTab('gunsonu'); else setTimeout(() => setAlt({ ekran: k }), 60); };

  if (yeniSip) icerik = <YeniSiparis musteriler={musteriler} presetMusteri={yeniSip.musteri} urunler={urunler} onGeri={() => setYeniSip(null)} onKaydet={(m, d) => siparisKaydet(m, d)} onPing={ping} onMusteriEkle={(m) => { setMusteriler((prev) => [m, ...prev]); ping('Müşteri kaydedildi'); }} />;
  else if (kilit) icerik = <div className="ekran"><Ust baslik="Sipario" onMenu={() => setCekmece(true)} /><div className="ekran-govde"><AbonelikKilidi /></div></div>;
  else if (tab === 'ana') icerik = <AnaEkran siparisler={siparisler} musteriler={musteriler} onMenu={() => setCekmece(true)}
    onGit={(k, veri) => { if (k === 'siparisDetay') { setTab('siparis'); setSipDetay(veri); } else setTab(k); }}
    onYeniSiparis={() => setYeniSip({ musteri: null })} onAramaAc={(a) => { if (a.musteriId) { const m = musteriler.find((x) => x.id === a.musteriId); setTab('musteri'); setAlt({ ekran: 'musteriDetay', veri: m }); } else setCagri(a.no); }} />;
  else if (tab === 'musteri') icerik = <MusterilerEkran musteriler={durum === 'bos' ? [] : musteriler} durum={durum} onMenu={() => setCekmece(true)} onYeni={() => setYeniMusteri({ tel: '' })} onAc={(m) => setAlt({ ekran: 'musteriDetay', veri: m })} />;
  else if (tab === 'siparis') icerik = <SiparislerEkran siparisler={durum === 'bos' ? [] : siparisler} durum={durum} rol={rol} onMenu={() => setCekmece(true)} onAc={(o) => setSipDetay(o)} onPing={ping}
    kuryeAdlari={kuryeler.filter((k) => k.aktif).map((k) => k.ad)} onKuryeDegis={(id, ad) => setSiparisler((prev) => prev.map((x) => x.id === id ? { ...x, kurye: ad } : x))}
    onMove={(id, hedefId) => setSiparisler((prev) => { const a = [...prev]; const i = a.findIndex((x) => x.id === id); const j = a.findIndex((x) => x.id === hedefId); if (i < 0 || j < 0) return prev; [a[i], a[j]] = [a[j], a[i]]; return a; })} />;
  else if (tab === 'gunsonu') icerik = <GunSonuEkran siparisler={siparisler} musteriler={musteriler} kuryeler={kuryeler} arsiv={arsiv} onMenu={() => setCekmece(true)} onPing={ping} onKapat={(a) => { setArsiv((prev) => [a, ...prev]); ping(a.kurye === 'Tümü' ? 'Gün kapatıldı ve arşivlendi' : `${a.kurye} hesabı kapatıldı ve arşivlendi`); }} />;

  return (
    <div className={`app ${tema === 'koyu' ? 'koyu' : ''}`}>
      {cevrimdisi && <CevrimdisiBant />}
      <div className="app-icerik">
        {altEkran || icerik}
      </div>
      {!yeniSip && !alt && <AltNav aktif={tab} onSec={(k) => setTab(k)} onYeniSiparis={() => setYeniSip({ musteri: null })} onMenu={() => setCekmece(true)} />}

      <Cekmece acik={cekmeceAcik} onKapat={() => setCekmece(false)} rol={rol} isletme={isletme}
        aktif={tab} onTab={(k) => { setCekmece(false); setAlt(null); setYeniSip(null); setTab(k); }}
        onAc={cekmeceAc} onDestek={() => { setCekmece(false); ping('Destek sohbeti · yakında'); }}
        onCikis={() => { setCekmece(false); setOnay({ baslik: 'Çıkış yapılsın mı?', onayLabel: 'Çıkış', tehlike: true, fn: () => { setGirisli(false); setOnay(null); } }); }} />

      {cagri && !muaflar.some((m) => m.no.replace(/\D/g, '').slice(-10) === String(cagri).replace(/\D/g, '').slice(-10)) && <CagriKarti numara={cagri} onKapat={() => setCagri(null)}
        onSiparis={(m) => { setCagri(null); setYeniSip({ musteri: m }); }}
        onDefter={(m) => { setCagri(null); setTab('musteri'); setAlt({ ekran: 'musteriDetay', veri: m }); }}
        onKaydet={(no) => { setCagri(null); setYeniMusteri({ tel: no }); }} />}

      <YeniMusteri acik={!!yeniMusteri} onTel={yeniMusteri ? yeniMusteri.tel : ''} mevcutlar={musteriler} onKapat={() => setYeniMusteri(null)}
        onKaydet={(m) => { setMusteriler((prev) => [m, ...prev]); setYeniMusteri(null); setTab('musteri'); setAlt({ ekran: 'musteriDetay', veri: m }); ping('Müşteri kaydedildi'); }} />

      {(() => { const o = sipDetay ? (siparisler.find((x) => x.id === sipDetay.id) || null) : null; return (
      <SiparisDetay o={o} onKapat={() => setSipDetay(null)}
        musteri={o && o.musteriId ? musteriler.find((x) => x.id === o.musteriId) : null}
        gecmis={o && o.musteriId ? siparisler.filter((x) => x.musteriId === o.musteriId && x.id !== o.id) : []}
        kuryeAdlari={kuryeler.filter((k) => k.aktif).map((k) => k.ad)} urunler={urunler}
        tumMusteriler={musteriler} onMusteriGuncelle={musGuncelle}
        onTeslim={teslimEt} onIptal={iptalEt} onPing={ping}
        onKuryeDegis={(id, ad) => setSiparisler((prev) => prev.map((x) => x.id === id ? { ...x, kurye: ad } : x))}
        onNotKaydet={(id, not) => { setSiparisler((prev) => prev.map((x) => x.id === id ? { ...x, not } : x)); ping(not ? 'Not kaydedildi' : 'Not silindi'); }}
        onSiparisGuncelle={(id, satirlar, serbest) => { setSiparisler((prev) => prev.map((x) => x.id === id ? { ...x, satirlar, serbest } : x)); ping('Sipariş güncellendi'); }}
        onKonumSec={(mId, k) => konumKaydet(mId, k)} />); })()}

      {toast && <div className="toast">{toast}</div>}
      <SistemCubuklari beyaz={tema === 'koyu'} />
      <Onay acik={!!onay} baslik={onay?.baslik} mesaj={onay?.mesaj} onayLabel={onay?.onayLabel} tehlike={onay?.tehlike} onIptal={() => setOnay(null)} onOnay={() => onay?.fn?.()} />
    </div>
  );
}

const kok = ReactDOM.createRoot(document.getElementById('root'));
kok.render(<App />);
