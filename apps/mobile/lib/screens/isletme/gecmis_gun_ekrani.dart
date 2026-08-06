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
// GEZİNME ŞERİDİ ORTAKTIR: `SiparisTarihSeridi` teslim sekmesinden İMPORT edilir, kopyalanmaz.
// İkinci bir şerit yazmak iki gezinmenin zamanla ayrışmasına yol açardı (biri "Dün" yazarken
// diğeri "03.08"). İleri okun bugünü geçmeme kuralı da o dosyada TEK yerde tanımlı.
//
// DÜNDE AÇILIR, bugünde değil: bugünün özeti zaten bir önceki ekrandır ve bu ekranın sorusu
// geçmiştir. Bugüne dönmek yine mümkün (şeridin ortasına dokunmak ya da ileri ok).
//
// SALT OKUNUR: bu ekran hiçbir kayıt YAZMAZ — ne kapatma ne ara tahsilat. Geçmiş bir günün
// rakamını düzeltmenin yolu defterdir (düzeltme kaydı), arşivi elle değiştirmek değil
// (kırmızı çizgi #2). Bu yüzden alt çubuk da yoktur.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../sync/yenileme.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../orders/siparis_tarih_seridi.dart';
import '../team.dart';
import 'gun_arsivi.dart';
import 'gun_kapatma_sheet.dart' show KapaliSerit, arsivDetaySheet;
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
  });

  final AppDatabase db;

  /// Oturumdaki rol `patron|operator|kurye`. Kapsam segmentini süzer (K2: kurye başka
  /// kuryenin kasasını okuyamaz) — Gün Özeti ekranındaki kuralın AYNISI.
  final String? rol;

  final String? kullaniciId;

  /// Test dikişi — "bugün"ün ne olduğu dışarıdan verilebilir. İleri okun sınırı buna bağlı.
  final DateTime? bugun;

  @override
  State<GecmisGunEkrani> createState() => _GecmisGunEkraniState();
}

class _GecmisGunEkraniState extends State<GecmisGunEkrani> {
  late final DateTime _bugun = widget.bugun ?? bugunTr();

  late DateTime _gun = _bugun.subtract(const Duration(days: 1));

  /// null = "Tümü"; aksi hâlde kuryenin kullanıcı kimliği.
  late String? _kuryeId = widget.rol == 'kurye' ? widget.kullaniciId : null;

  late Future<_GunVerisi> _veri = _yukle();
  late Future<List<UrunSatisi>> _urunler = satilanUrunler(widget.db, _gun);

  /// Görünüm ve "o gün hiç kayıt var mı" TEK future'da toplanır: ikisi ayrı olsaydı gövde bir
  /// kare boyunca kartları çizip sonra boş duruma atlardı (ya da tersi) — geçmiş bir günde bu
  /// titreme, bayiye rakamların oynadığını düşündürürdü.
  Future<_GunVerisi> _yukle() async => _GunVerisi(
        gorunum: await gunSonuGorunumu(widget.db, _gun, kuryeId: _kuryeId),
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

  void _kapsamSec(String? kuryeId) {
    setState(() {
      _kuryeId = kuryeId;
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

  String _kapsamAdi(List<User> kuryeler) =>
      _kuryeId == null ? 'Gün hesabı' : (kullaniciAdi(kuryeler, _kuryeId) ?? 'Kurye');

  /// Kurye YALNIZ kendini görür (K2) — Gün Özeti ekranıyla aynı süzgeç.
  List<User> _gorunurKuryeler(List<User> kuryeler) => widget.rol == 'kurye'
      ? kuryeler.where((k) => k.id == widget.kullaniciId).toList()
      : kuryeler;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<User>>(
          stream: watchAktifKuryeler(widget.db),
          builder: (context, kuryeSnap) {
            final kuryeler = kuryeSnap.data ?? const <User>[];
            final gorunur = _gorunurKuryeler(kuryeler);
            final secenekler = ['Tümü', for (final k in gorunur) k.name];

            // Seçili kapsam segmentte YOKSA seçenek olarak eklenir; aksi hâlde şerit "Tümü"yü
            // işaretlerken gövde kurye kapsamını gösterirdi (Gün Özeti ekranındaki aynı dal).
            var seciliDizin = 0;
            if (_kuryeId != null) {
              final i = gorunur.indexWhere((k) => k.id == _kuryeId);
              if (i >= 0) {
                seciliDizin = i + 1;
              } else {
                secenekler.add(_kapsamAdi(kuryeler));
                seciliDizin = secenekler.length - 1;
              }
            }

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
                  child: SipSegment(
                    secenekler: secenekler,
                    secili: seciliDizin,
                    onSec: (i) => _kapsamSec(i == 0
                        ? null
                        : (i - 1 < gorunur.length ? gorunur[i - 1].id : _kuryeId)),
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
                        onYenile: _yenile,
                      );
                    },
                  ),
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
    required this.onYenile,
  });

  final GunSonuGorunumu gorunum;

  /// O GÜNDE (kapsamdan bağımsız) herhangi bir kayıt var mı.
  final bool kayitVar;

  final String kapsamAdi;
  final bool gunKapsami;
  final List<User> ekip;
  final Future<List<UrunSatisi>> urunler;
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
          const KapaliSerit(metin: 'Bu günün hesabı kapatıldı ve arşivlendi.')
        else
          SipNotKutusu(
            tur: SipNotTuru.uyari,
            ikon: SipIcons.info,
            metin: 'Bu gün kapatılmadı — rakamlar defterden okunuyor, kasa sayımı yapılmamış.',
          ),

        // İKİ AYRI BOŞLUK, İKİ AYRI CÜMLE: "o gün hiç çalışılmadı" ile "o gün bu kurye çalışmadı"
        // aynı şey değil. Tek cümleyle geçilseydi bayi, kuryesi izinliyken günün tamamının boş
        // olduğunu sanırdı. Sıfırlarla dolu bir kasa kartı çizmek ise daha kötüsü — kasayı eksik
        // sandırırdı.
        if (!kayitVar)
          const SipBosDurum(
            ikon: SipIcons.takvim,
            baslik: 'Bu güne ait hareket yok',
            aciklama: 'Bu gün teslimat yapılmamış ve kasaya para girmemiş.',
          )
        else if (_kapsamBos)
          SipBosDurum(
            ikon: SipIcons.takvim,
            baslik: '$kapsamAdi bu gün çalışmamış',
            aciklama: 'Bu günde başka hareketler var — "Tümü"ye geçerek görebilirsiniz.',
          )
        else ...[
          SipBolumBaslik(
            gunKapsami ? 'Kasa Özeti' : 'Kasa Özeti · $kapsamAdi',
            ustBosluk: 18,
          ),
          DegerKarti(
            satirlar: [
              DegerSatiri(etiket: 'Nakit', deger: sipTutar(kasa.nakit)),
              DegerSatiri(etiket: 'Kart', deger: sipTutar(kasa.kart)),
              DegerSatiri(etiket: 'Havale', deger: sipTutar(kasa.havale)),
              DegerSatiri(
                etiket: 'Toplam Tahsilat · ${g.kapsam.teslimat} teslimat',
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
            AraTahsilatKarti(kayitlar: g.araTahsilatlar, kuryeAdiYaz: gunKapsami),
          ],

          if (kapanislar.isNotEmpty) ...[
            const SipBolumBaslik('Kapanış Kayıtları', ustBosluk: 18),
            for (var i = 0; i < kapanislar.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: ArsivSatiri(
                  kapanis: kapanislar[i],
                  kapsamAdi: _kapanisAdi(kapanislar[i]),
                  onTap: () => arsivDetaySheet(
                    context,
                    kapanislar[i],
                    kapsamAdi: _kapanisAdi(kapanislar[i]),
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
                  return const _BosNot('Bu gün teslim edilmiş sipariş yok.');
                }
                return DegerKarti(
                  satirlar: [
                    for (final u in liste)
                      DegerSatiri(
                          etiket: '${u.ad} ×${u.adet}', deger: sipTutar(u.tutar)),
                    DegerSatiri(
                      etiket: 'Toplam · '
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
