// GEÇMİŞ GÜN EKRANI — Gün Özeti'nin başlığındaki takvim düğmesiyle açılır.
//
// NEDEN AYRI EKRAN (kullanıcı kararı 2026-08-06): "gün sonu mantığı gün özeti mantığına dönüp
// ilk ekranda mevcut günü göstersin, geçmişte de kapalı veya açık olan geçmiş günlere bakabilsin.
// Geçmişi gün sonu içinden ayrı bir şekilde açalım — aynı teslim edilen siparişlerde yaptığımız
// gibi tarihten ileri geri yaparak günlere bakmak daha pratik."
//
// ÖNCEKİ HÂLİ: Gün Özeti'nin GÖVDESİNDE "Geçmiş" başlıklı bir liste vardı (hareket olan her gün
// alt alta) ve bir güne dokunmak `GunDetayEkrani`ni açıyordu. İki katman (liste → detay) yerine
// tek katman (gezinme) kaldı: bayi listede tarih aramıyor, "dün ne oldu" diye soruyor.
//
// GEZİNME ŞERİDİ ORTAKTIR: `SiparisTarihSeridi` teslim sekmesinden (`../orders/`) İMPORT edilir,
// kopyalanmaz. İkinci bir şerit yazmak iki gezinmenin zamanla ayrışmasına yol açardı (biri "Dün"
// yazarken diğeri "03.08"). İleri okun bugünü geçmeme kuralı da o dosyada TEK yerde tanımlı.
//
// PEKİ NEDEN ORTAK BİR KLASÖRE TAŞINMADI? Taşımak `orders/` dosyalarını (import satırları, sınıf
// adı) değiştirmek demekti ve bu tur o dosyalar başka bir sahibindeydi — paralel çalışan iki
// ajanın aynı dosyaya yazması çakışma üretir. `isletme` → `orders` yönünde TEK YÖNLÜ bir import
// doğuyor; kabul edildi (lead onayı 2026-08-06). Şerit üçüncü bir ekranda daha gerekirse taşıma
// zamanı gelmiş demektir — İKİ kullanıcı taşımayı haklı çıkarmıyor, ÜÇ çıkarır.
// BU SATIRLAR UYARIDIR: sonraki vardiya bunu "yanlış katman bağımlılığı" sanıp kopyalamasın.
//
// DÜNDE AÇILIR, bugünde değil: bugünün özeti zaten bir önceki ekrandır ve bu ekranın sorusu
// geçmiştir. Bugüne dönmek yine mümkün (şeridin ortasına dokunmak ya da ileri ok).
//
// ⚠️ ARTIK TAM SALT OKUNUR DEĞİL (2026-08-21): ekran TEK bir kayıt yazabilir — GÜN KAPANIŞI.
// Kullanıcı isteği: "kapatılmayan günleri kapatabilmeli işletme sahibi". Sınırlar dar ve
// gerekçeleri `_gunuKapat` üzerinde yazılı:
//   • yalnız GÜN kapsamı (kurye kapanışı geçmişe yazılamaz — mutabakat penceresini kaydırır),
//   • SAYIM İSTENMEZ (geçmiş bir günün kasası bugün sayılamaz; fark uydurulmaz),
//   • yalnız `gunuKapatma` yetkisi olan kullanıcı.
// Ara tahsilat, defter düzeltme ve arşiv düzenleme YİNE YOKTUR: geçmiş bir günün RAKAMINI
// düzeltmenin yolu defterdir (düzeltme kaydı), arşivi elle değiştirmek değil (kırmızı çizgi #2).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../sync/yenileme.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/siparis_tarih_seridi.dart';
import '../team.dart';
import 'gun_arsivi.dart';
import 'gun_kapsami.dart';
import '../../repo/day_closing_repository.dart';
import 'gun_kapatma_sheet.dart' show KapaliSerit, arsivDetaySheet, gunKapatmaSheet;
import 'gun_sonu_kartlari.dart';
import 'gun_sonu_ozet.dart';
import 'isletme_atomlari.dart';

class GecmisGunEkrani extends StatefulWidget {
  const GecmisGunEkrani({
    super.key,
    required this.db,
    this.rol,
    this.kullaniciId,
    this.bugun,
    this.acilisGunu,
  });

  final AppDatabase db;

  /// Oturumdaki rol `patron|operator|kurye`. Kapsam segmentini süzer (K2: kurye başka
  /// kuryenin kasasını okuyamaz) — Gün Özeti ekranındaki kuralın AYNISI.
  final String? rol;

  final String? kullaniciId;

  /// Test dikişi — "bugün"ün ne olduğu dışarıdan verilebilir. İleri okun sınırı buna bağlı.
  final DateTime? bugun;

  /// Ekranın AÇILACAĞI gün. Verilmezse DÜN (bu ekranın olağan girişi).
  ///
  /// "Kapanmamış günler" listesinden gelen kullanıcı üç gün öncesini seçmiş olabilir; onu dünde
  /// açıp oklarla geri saydırmak, listeye dokunmanın anlamını yok ederdi.
  final DateTime? acilisGunu;

  @override
  State<GecmisGunEkrani> createState() => _GecmisGunEkraniState();
}

class _GecmisGunEkraniState extends State<GecmisGunEkrani> {
  /// İleri okun sınırı. Cihaz saatiyle başlar, sonra DÜZELTİLMİŞ sunucu saatiyle tazelenir
  /// ([initState]) — telefon ileri kurulmuşsa ok bir gün fazla açılır ve bayi boş bir güne bakıp
  /// "veri mi kayboldu" diye düşünürdü. İlk kareyi beklemiyoruz: bu ekran SALT OKUNURDUR, yanlış
  /// bir sınır en fazla bir kare sürer ve hiçbir kayda dokunmaz.
  late DateTime _bugun = widget.bugun ?? bugunTr();

  late DateTime _gun = widget.acilisGunu ?? _bugun.subtract(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    // Test dikişi verilmişse ona saygı duyulur; aksi hâlde gün sınırı düzeltilir.
    if (widget.bugun != null) return;
    bugunTrDuzeltilmis(widget.db).then((duzeltilmis) {
      if (!mounted || duzeltilmis == _bugun) return;
      setState(() {
        _bugun = duzeltilmis;
        // AÇILIŞ GÜNÜ ÇAĞIRANDAN GELDİYSE KORUNUR: saat düzeltmesi "bugün"ü kaydırabilir ama
        // kullanıcının listeden seçtiği günü kaydırmaz. Ezseydik, üç gün öncesini seçen bayi
        // bir kare sonra kendini dünde bulurdu.
        if (widget.acilisGunu == null) _gun = duzeltilmis.subtract(const Duration(days: 1));
        _veri = _yukle();
        _urunler = satilanUrunler(widget.db, _gun);
      });
    });
  }

  /// SEÇİLİ KAPSAM — Gün Özeti ekranıyla AYNI tip ve AYNI seçenek üreticisi (`gunKapsamlari`).
  /// İki ekran ayrı listeler kursaydı bayi aynı ekibi iki yerde iki farklı düzende görürdü ve
  /// "kurye yalnız kendini görür" kapısı iki kez yazılmış olurdu.
  late GunKapsamSecenegi _secili = widget.rol == 'kurye' && widget.kullaniciId != null
      ? GunKapsamSecenegi(etiket: 'Kendi hesabım', userId: widget.kullaniciId, rol: 'kurye')
      : const GunKapsamSecenegi(etiket: 'Tümü');

  String? get _kuryeId => _secili.userId;
  String? get _haric => _secili.haric;

  late Future<_GunVerisi> _veri = _yukle();
  late Future<List<UrunSatisi>> _urunler = satilanUrunler(widget.db, _gun);

  /// Görünüm ve "o gün hiç kayıt var mı" TEK future'da toplanır: ikisi ayrı olsaydı gövde bir
  /// kare boyunca kartları çizip sonra boş duruma atlardı (ya da tersi) — geçmiş bir günde bu
  /// titreme, bayiye rakamların oynadığını düşündürürdü.
  Future<_GunVerisi> _yukle() async => _GunVerisi(
        gorunum: await gunSonuGorunumu(widget.db, _gun, kuryeId: _kuryeId, haric: _haric),
        kayitVar: await gunKayitVarMi(widget.db, _gun),
      );

  void _gunSec(DateTime gun) {
    setState(() {
      _gun = DateTime(gun.year, gun.month, gun.day);
      _veri = _yukle();
      // Ürün dökümü kapsamdan BAĞIMSIZDIR (gün geneli) — yalnız gün değişince tazelenir.
      _urunler = satilanUrunler(widget.db, _gun);
    });
  }

  void _kapsamSec(GunKapsamSecenegi secim) {
    setState(() {
      _secili = secim;
      _veri = _yukle();
    });
  }

  /// Aşağı çekerek yenile: önce senkron, sonra ekranın kendi future'ları. Geçmiş bir gün de
  /// tazelenebilir olmalı — kuryenin telefonundaki teslimat ya da düzeltme kaydı senkronla
  /// sonradan gelebilir ve o gün "kapanmış" olsa bile RAKAMI değişir.
  Future<void> _yenile() async {
    await yenile();
    if (!mounted) return;
    setState(() {
      _veri = _yukle();
      _urunler = satilanUrunler(widget.db, _gun);
    });
  }

  String _kapsamAdi(List<User> kuryeler) => _kuryeId == null
      ? (_secili.gunHesabi ? 'Gün hesabı' : _secili.etiket)
      : (kullaniciAdi(kuryeler, _kuryeId) ?? 'Kurye');

  // "Kurye YALNIZ kendini görür" (K2) süzgeci BURADAN TAŞINDI (2026-08-20): kural artık
  // seçeneklerin ÜRETİLDİĞİ yerde (`gunKapsamlari`) duruyor ve iki ekran onu paylaşıyor. İki
  // yerde durması, birinin bir gün diğerini yakalayamaması demekti.

  /// Kapatma alt çubuğu bu ekranda çizilir mi? (Koşulun rol/kapsam yarısı; günün durumu
  /// verinin kendisinden okunur.)
  bool get _kapatmaCubuguCizilir =>
      _secili.gunHesabi &&
      yetkiler(rol: widget.rol, atamaHedefiVar: true).gunuKapatma;

  /// GEÇMİŞ BİR GÜNÜ KAPATIR — sayım İSTENMEDEN (kullanıcı isteği 2026-08-21).
  ///
  /// ══ NEDEN YALNIZ GÜN KAPSAMI ═══════════════════════════════════════════════════════════
  /// Kurye kapanışı bir MUTABAKAT PENCERESİNİ kapatır (`CashHandoverRepository._pencere` son
  /// kurye kapanışından başlar). Geçmiş bir güne kurye kapanışı yazmak pencereyi o güne taşır
  /// ve o günden bugüne kadar toplanmış ama teslim edilmemiş para BEKLENENDEN DÜŞER — yani
  /// kuryenin cebindeki gerçek nakit sessizce silinir. Kurye mutabakatı her zaman BUGÜN yapılır;
  /// orada pencere ile cepteki para aynı şeyi anlatır.
  ///
  /// ══ NEDEN SAYIM YOK ════════════════════════════════════════════════════════════════════
  /// Üç gün önceki kasa bugün sayılamaz. Sayım alınsaydı `diff` arşive KALICI olarak yanlış
  /// donardı (append-only). Kayıt "sayım yapılmadı" (counted=null, fark 0) olarak geçer.
  ///
  /// ══ NEDEN GÜN ENGELİ YOK ═══════════════════════════════════════════════════════════════
  /// `gunEngeli` "bugün yarım kalmış bir kurye devrini tamamla" demektir. Geçmiş bir günde o
  /// devir zaten tamamlanamaz (yukarıdaki sebep); engeli uygulamak, kapatılması İMKÂNSIZ bir
  /// gün üretir ve "kapanmamış günler" listesi hiç boşalmazdı.
  ///
  /// AÇIK SİPARİŞ ENGELİ DURUYOR ve durmalı: o sipariş hâlâ gerçekten açıktır ve kullanıcı onu
  /// teslim edip ya da iptal edip günü kapatabilir. Aşılabilir olduğu için ölü bir engel değil.
  Future<void> _gunuKapat() async {
    if (!_kapatmaCubuguCizilir) return; // çift kapı (K2 pazarlıksız)

    final onizleme =
        await DayClosingRepository(widget.db).onizle(ClosingScope.day, localDate: _gun);
    if (!mounted) return;

    final sonuc = await gunKapatmaSheet(
      context,
      kapsamAdi: gunTamBasligi(_gun),
      gunHesabi: true,
      beklenen: onizleme.expectedCashKurus,
      tamNakit: onizleme.gunNakitKurus,
      teslimat: onizleme.deliveryCount,
      ortaEtiket: onizleme.dusulenKurus < 0 ? 'Kuryelerden devir' : 'Kuryelerde kalan',
      ortaTutar: onizleme.dusulenKurus,
      sayimIstenmiyor: true,
    );
    if (sonuc == null || !mounted) return;

    try {
      await DayClosingRepository(widget.db).kapat(
        scope: ClosingScope.day,
        countedCashKurus: null, // sayım YOK — sheet de istemedi
        note: sonuc.not.isEmpty ? null : sonuc.not,
        localDate: _gun,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      SipToast.goster(context, e.message);
      setState(() => _veri = _yukle());
      return;
    }
    if (!mounted) return;
    SipToast.goster(context, '${gunTamBasligi(_gun)} kapatıldı');
    setState(() => _veri = _yukle());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<User>>(
          // EKİP = TÜM AKTİF PERSONEL (2026-08-20) — Gün Özeti ekranıyla aynı akış. Dar bir
          // liste, patronun teslim ettiği siparişi "Kurye" diye yazardı.
          stream: watchAtamaHedefleri(widget.db),
          builder: (context, kuryeSnap) {
            final kuryeler = kuryeSnap.data ?? const <User>[];
            final kapsamlar = gunKapsamlari(
              rol: widget.rol,
              benimId: widget.kullaniciId,
              ekip: kuryeler,
            );
            // Seçili kapsam listede YOKSA seçenek olarak eklenir; aksi hâlde seçici bir kapsamı
            // yazarken gövde başkasını gösterirdi (Gün Özeti ekranındaki aynı dal).
            if (!kapsamlar.any((k) => k.ayniMi(_secili))) kapsamlar.insert(0, _secili);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SipUst(
                  baslik: 'Geçmiş',
                  alt: gunTamBasligi(_gun),
                  onGeri: () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SipSpace.govde, 0, SipSpace.govde, SipSpace.lg),
                  child: SiparisTarihSeridi(
                    gun: _gun,
                    bugun: _bugun,
                    onDegis: _gunSec,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SipSpace.govde, 0, SipSpace.govde, SipSpace.xl),
                  child: GunKapsamSecici(
                    secenekler: kapsamlar,
                    secili: _secili,
                    onSec: _kapsamSec,
                  ),
                ),
                Expanded(
                  child: FutureBuilder<_GunVerisi>(
                    future: _veri,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return SipHataEkran(
                            onTekrar: () => setState(() => _veri = _yukle()));
                      }
                      final v = snap.data;
                      if (v == null) {
                        return const SipGovde(children: [SipIskelet(adet: 3)]);
                      }
                      return _Govde(
                        gorunum: v.gorunum,
                        kayitVar: v.kayitVar,
                        kapsamAdi: _kapsamAdi(kuryeler),
                        gunKapsami: _kuryeId == null,
                        ekip: kuryeler,
                        urunler: _urunler,
                        // "Bugün/Dün" etiketi de düzeltilmiş günden okunur: `_bugun` zaten
                        // [initState] içinde `bugunTrDuzeltilmis` ile tazeleniyor.
                        bugun: _bugun,
                        onYenile: _yenile,
                      );
                    },
                  ),
                ),
                // GEÇMİŞ GÜNÜ KAPATMA (kullanıcı isteği 2026-08-21) — bu ekran artık salt okunur
                // DEĞİL. Alt çubuk YALNIZ şu üçü birlikteyken çizilir:
                //  • kapsam GÜN hesabı (kurye kapsamı geçmişte kapatılamaz — gerekçe [_gunuKapat]),
                //  • kullanıcının `gunuKapatma` yetkisi var,
                //  • gün henüz kapanmamış.
                // Üçü de sağlanmıyorsa çubuk HİÇ çizilmez: geçmişe bakan kurye için bu ekran
                // eskisi gibi salt okunurdur.
                if (_kapatmaCubuguCizilir)
                  FutureBuilder<_GunVerisi>(
                    future: _veri,
                    builder: (context, snap) {
                      final v = snap.data;
                      if (v == null || v.gorunum.gunKapali || !v.kayitVar) {
                        return const SizedBox.shrink();
                      }
                      return GunOzetiAltCubugu(
                        kapsamKapali: false,
                        gunKapali: false,
                        kuryeAdi: null,
                        kapatabilir: true,
                        acikSiparis: v.gorunum.kapsam.acikSiparis,
                        // GÜN ENGELİ GEÇMİŞTE UYGULANMAZ (bkz. [_gunuKapat] doc'u).
                        gunEngeli: false,
                        acikKuryeAdlari: const [],
                        toplam: v.gorunum.kapsam.kasa.toplam,
                        onKapat: _gunuKapat,
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Gövdenin tek atışta ihtiyaç duyduğu iki cevap: seçili kapsamın görünümü + o GÜNDE hiç kayıt
/// olup olmadığı. İkincisi kapsamdan bağımsızdır ve boş durumun HANGİ cümleyi yazacağını belirler.
@immutable
class _GunVerisi {
  const _GunVerisi({required this.gorunum, required this.kayitVar});

  final GunSonuGorunumu gorunum;
  final bool kayitVar;
}

class _Govde extends StatelessWidget {
  const _Govde({
    required this.gorunum,
    required this.kayitVar,
    required this.kapsamAdi,
    required this.gunKapsami,
    required this.ekip,
    required this.urunler,
    required this.bugun,
    required this.onYenile,
  });

  final GunSonuGorunumu gorunum;

  /// O GÜNDE (kapsamdan bağımsız) herhangi bir kayıt var mı.
  final bool kayitVar;

  final String kapsamAdi;
  final bool gunKapsami;
  final List<User> ekip;
  final Future<List<UrunSatisi>> urunler;

  /// "Bugün/Dün" kelimesinin referans günü (DÜZELTİLMİŞ saatten). Geçmiş bir güne bakarken bile
  /// gerekir: arşiv satırı o günün kapanışını "Dün 18:05" diye yazar ve o "dün" BUGÜNE göredir.
  final DateTime bugun;

  final Future<void> Function() onYenile;

  String _kapanisAdi(DayClosing k) =>
      k.userId == null ? 'Gün hesabı' : (kullaniciAdi(ekip, k.userId) ?? 'Kurye');

  /// Seçili kapsamda hiç hareket var mı? Üç kaynağa birden bakılır — yalnız tahsilata bakmak,
  /// parası ertesi gün alınan bir teslimat gününü "boş" gösterirdi.
  bool get _kapsamBos =>
      gorunum.kapsam.kasa.toplam == 0 &&
      gorunum.kapsam.teslimat == 0 &&
      gorunum.gunKapanislari.isEmpty &&
      gorunum.araTahsilatlar.isEmpty;

  @override
  Widget build(BuildContext context) {
    final g = gorunum;
    final kasa = g.kapsam.kasa;
    final kapanislar = g.gunKapanislari;

    return SipGovde(
      onYenile: onYenile,
      children: [
        // DURUM BANDI — kapalı gün yeşil, açık gün nötr uyarı. Kapatılmamış bir günün rakamları
        // gösterilmeye DEVAM eder (kullanıcı kararı 2026-07-29: bayi kapatmayı unuttuğunda o
        // günün cirosu okunamaz hâle gelmemeli), ama sayım yapılmadığı SÖYLENİR — yoksa ekran
        // mutabık bir gün gibi okunurdu.
        if (g.gunKapali)
          const KapaliSerit(metin: 'Bu günün hesabı kapatıldı')
        else
          SipNotKutusu(
            tur: SipNotTuru.uyari,
            ikon: SipIcons.info,
            metin: 'Bu günün hesabı kapatılmadı',
          ),

        // İKİ AYRI BOŞLUK, İKİ AYRI CÜMLE: "o gün hiç çalışılmadı" ile "o gün bu kurye çalışmadı"
        // aynı şey değil. Tek cümleyle geçilseydi bayi, kuryesi izinliyken günün tamamının boş
        // olduğunu sanırdı. Sıfırlarla dolu bir kasa kartı çizmek ise daha kötüsü — kasayı eksik
        // sandırırdı.
        if (!kayitVar)
          const SipBosDurum(
            ikon: SipIcons.takvim,
            baslik: 'Bu güne ait hareket yok',
            aciklama: 'Bu gün sipariş, tahsilat ya da gider kaydedilmemiş',
          )
        else if (_kapsamBos)
          SipBosDurum(
            ikon: SipIcons.takvim,
            baslik: '$kapsamAdi bu gün çalışmamış',
            aciklama: 'Bu günün diğer kayıtlarını görmek için kapsamı "Tümü" yapın',
          )
        else ...[
          SipBolumBaslik(
            gunKapsami ? 'Kasa Özeti' : '$kapsamAdi için kasa özeti',
            ustBosluk: 18,
          ),
          DegerKarti(
            satirlar: [
              DegerSatiri(etiket: 'Nakit', deger: sipTutar(kasa.nakit)),
              DegerSatiri(etiket: 'Kart', deger: sipTutar(kasa.kart)),
              DegerSatiri(etiket: 'Havale', deger: sipTutar(kasa.havale)),
              DegerSatiri(
                etiket: 'Toplam tahsilat (${g.kapsam.teslimat} teslimat)',
                deger: sipTutar(kasa.toplam),
                toplam: true,
              ),
              // Gün Özeti ekranıyla AYNI kural: iskonto toplamın ALTINDA ve yalnız varsa.
              // Geçmiş günde daha da gereklidir — o günü kapatan kişi ortada olmayabilir ve
              // "ciro 420 ama kasa 400" sorusunun cevabı başka hiçbir yerde yazmaz.
              if (g.kapsam.iskonto > 0)
                DegerSatiri(
                  etiket: 'İskonto (kasaya girmedi)',
                  deger: sipTutar(g.kapsam.iskonto),
                  degerRengi: context.sip.warn,
                ),
            ],
          ),

          // Gün Özeti ekranıyla AYNI yer: kasa kartının hemen altı. Geçmiş bir günde bu satırlar
          // daha da gereklidir — o gün ara tahsilat alan kişi ortada olmayabilir ve "nakit 12.000
          // yazıyor ama kapanışta 7.000 sayılmış" sorusunun cevabı başka hiçbir yerde yazmaz.
          if (g.araTahsilatlar.isNotEmpty) ...[
            const SipBolumBaslik('Ara Tahsilatlar', ustBosluk: 18),
            AraTahsilatKarti(
            kayitlar: g.araTahsilatlar,
            toplamKurus: g.araTahsilatToplamiKurus,
            kuryeAdiYaz: gunKapsami,
          ),
          ],

          if (kapanislar.isNotEmpty) ...[
            const SipBolumBaslik('Kapanış Kayıtları', ustBosluk: 18),
            for (var i = 0; i < kapanislar.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: ArsivSatiri(
                  kapanis: kapanislar[i],
                  kapsamAdi: _kapanisAdi(kapanislar[i]),
                  bugun: bugun,
                  onTap: () => arsivDetaySheet(
                    context,
                    kapanislar[i],
                    kapsamAdi: _kapanisAdi(kapanislar[i]),
                    bugun: bugun,
                  ),
                ),
              ),
          ],

          // ÜRÜN DÖKÜMÜ GÜN GENELİDİR ve yalnız "Tümü" kapsamında çizilir: `satilanUrunler`
          // kurye süzgeci almıyor, kurye kapsamında basılsaydı ekran o kuryenin sattıklarını
          // gösteriyormuş gibi okunurdu — kasa kartı kuryeye ait, döküm günün tamamına.
          if (gunKapsami) ...[
            const SipBolumBaslik('Satılan Ürünler', ustBosluk: 18),
            FutureBuilder<List<UrunSatisi>>(
              future: urunler,
              builder: (context, snap) {
                final liste = snap.data;
                if (liste == null) return const SipIskelet(adet: 1);
                if (liste.isEmpty) {
                  return const _BosNot('Bu gün teslim edilmiş sipariş yok');
                }
                return DegerKarti(
                  satirlar: [
                    for (final u in liste)
                      DegerSatiri(
                          etiket: '${u.ad} ×${u.adet}', deger: sipTutar(u.tutar)),
                    DegerSatiri(
                      etiket: 'Toplam, '
                          '${liste.fold<int>(0, (s, u) => s + u.adet)} adet',
                      deger: sipTutar(liste.fold<int>(0, (s, u) => s + u.tutar)),
                      toplam: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ],
    );
  }
}

class _BosNot extends StatelessWidget {
  const _BosNot(this.metin);
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 14),
      child: Text(metin, style: SipText.yardimci.copyWith(color: t.muted)),
    );
  }
}
