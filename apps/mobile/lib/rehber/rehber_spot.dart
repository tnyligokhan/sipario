// TURUN SAHNESİ — karartma · nabız atan spot · balon · perde.
//
// `rehber_sahne.dart`tan AYRILDI (500 satır kuralı): orası turu NE ZAMAN oynatacağına karar
// verir, burası NASIL göründüğünü çizer.
//
// ── DELİK GERÇEKTEN DELİKTİR ──────────────────────────────────────────────────────────────
// Karartma tek parça bir dokunuş yutucu DEĞİLDİR: çizim `IgnorePointer` içindedir ve dokunuşu
// deliğin ÇEVRESİNDEKİ dört perde parçası yutar. Etkileşimli adımda (`RehberAdim.dene`) deliğin
// üstüne hiçbir şey konmaz, yani kullanıcı gerçek düğmeye kendi eliyle basar ve tur o dokunuşla
// ilerler (`RehberKayit.sonDokunus`).
//
// NEDEN TEK PARÇA KARARTMA + "geçirgen dinleyici" DEĞİL: Flutter'ın isabet testi bir katman
// kendini hedef olarak eklediğinde alttaki rotaya inmeyi bırakır. Overlay'de "hem gör hem
// geçir" mümkün değildir; bu yüzden geçirme işi YERLEŞİMLE (delik boş bırakılarak), görme işi
// hedefin kendi ağacındaki `Listener` ile çözülür.
//
// ── NABIZ SINIRLIDIR ──────────────────────────────────────────────────────────────────────
// Halka üç kez atıp durur, sonsuza kadar dönmez. Gerekçe teknik: bu depoda 77 test
// `pumpAndSettle` çağırıyor ve hiç durmayan bir animasyon o çağrıları sonsuz döngüye sokar.
// Yan fayda ürün tarafında: sürekli atan bir nabız birkaç saniye sonra dikkat çekmeyi bırakır,
// yalnız rahatsız eder.

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'rehber_hedef.dart';
import 'rehber_balon.dart';
import 'rehber_modeli.dart';

/// Spotun deliğe eklediği pay ve köşe yarıçapı.
const double _pay = 6;
const double _kose = SipRadius.r2;

class RehberSahnesi extends StatefulWidget {
  const RehberSahnesi({
    super.key,
    required this.adimlar,
    required this.onBitti,
    required this.onAtla,
  });

  final List<RehberAdim> adimlar;

  /// Tur sonuna kadar oynadı.
  final VoidCallback onBitti;

  /// Kullanıcı "Rehberi kapat" dedi.
  final VoidCallback onAtla;

  @override
  State<RehberSahnesi> createState() => _RehberSahnesiState();
}

class _RehberSahnesiState extends State<RehberSahnesi>
    with SingleTickerProviderStateMixin {
  int _i = 0;
  bool _gorunur = false;

  late final AnimationController _nabiz = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  /// Nabzın kaç kez gidip geldiği — üçte durur (bkz. dosya başlığı).
  int _tur = 0;

  @override
  void initState() {
    super.initState();
    _nabiz.addStatusListener(_nabizDurumu);
    RehberKayit.sonDokunus.addListener(_hedefeDokunuldu);
    // Sönümlenerek girsin: karartma bir karede sertçe düşünce ekran "hata verdi" gibi duruyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _gorunur = true);
      _nabziBaslat();
    });
  }

  @override
  void dispose() {
    RehberKayit.sonDokunus.removeListener(_hedefeDokunuldu);
    _nabiz.removeStatusListener(_nabizDurumu);
    _nabiz.dispose();
    super.dispose();
  }

  void _nabizDurumu(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      _nabiz.reverse();
    } else if (s == AnimationStatus.dismissed && ++_tur < 3) {
      _nabiz.forward();
    }
  }

  void _nabziBaslat() {
    _tur = 0;
    _nabiz
      ..value = 0
      ..forward();
  }

  /// Etkileşimli adımda kullanıcı GERÇEK hedefe dokundu mu.
  void _hedefeDokunuldu() {
    final id = RehberKayit.sonDokunus.value;
    if (id == null || !mounted) return;
    final adim = widget.adimlar[_i];
    if (!adim.etkilesimli || adim.hedef != id) return;
    // Dokunuşun kendi işini (sekme değişimi, süzgeç) yapmasına izin ver, sonra ilerle —
    // aynı karede ilerlemek, balonu eski ekranın üstünde bir kare boyunca gösterirdi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ileri();
    });
  }

  void _ileri() {
    if (_i >= widget.adimlar.length - 1) {
      widget.onBitti();
      return;
    }
    setState(() => _i++);
    _nabziBaslat();
  }

  void _geri() {
    if (_i == 0) return;
    setState(() => _i--);
    _nabziBaslat();
  }

  @override
  Widget build(BuildContext context) {
    final adim = widget.adimlar[_i];
    final ekran = MediaQuery.sizeOf(context);
    // Hedef tur BAŞLADIKTAN SONRA da kaybolabilir (liste tazelemesi, kaydırma). O anda adım
    // bağsıza döner — spot kaybolur ama anlatı ekranda kalır.
    final kutu = adim.bagsiz ? null : RehberKayit.kutu(adim.hedef);
    final delik = (kutu != null && _gorunurAlanda(kutu, ekran)) ? kutu.inflate(_pay) : null;
    final etkilesim = adim.etkilesimli && delik != null;

    return AnimatedOpacity(
      opacity: _gorunur ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // ÇİZİM DOKUNUŞ ALMAZ — yutma işi aşağıdaki perde parçalarının.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _nabiz,
                  builder: (_, _) => CustomPaint(
                    painter: _KarartmaBoyaci(delik: delik, nabiz: _nabiz.value),
                  ),
                ),
              ),
            ),
            ..._perde(ekran, delik, etkilesim),
            _balon(ekran, delik, adim, etkilesim),
          ],
        ),
      ),
    );
  }

  /// Deliğin çevresini kapatan parçalar. Delik yoksa tek parça tam ekran.
  ///
  /// Etkileşimli adımda deliğin ÜSTÜ BOŞ BIRAKILIR: dokunuş oradan gerçek widget'a iner.
  /// Değilse delik de kapatılır ve dokunmak adımı ilerletir (bağışlayıcı davranış: düğmeye
  /// nişan alamayan parmak turu kilitlemesin).
  List<Widget> _perde(Size ekran, Rect? delik, bool etkilesim) {
    Widget yutucu(Rect r) => Positioned.fromRect(
          rect: r,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _ileri,
            child: const SizedBox.expand(),
          ),
        );

    if (delik == null) {
      return [yutucu(Offset.zero & ekran)];
    }
    return [
      yutucu(Rect.fromLTRB(0, 0, ekran.width, delik.top)),
      yutucu(Rect.fromLTRB(0, delik.bottom, ekran.width, ekran.height)),
      yutucu(Rect.fromLTRB(0, delik.top, delik.left, delik.bottom)),
      yutucu(Rect.fromLTRB(delik.right, delik.top, ekran.width, delik.bottom)),
      if (!etkilesim) yutucu(delik),
    ];
  }

  /// Balonu deliğin altına ya da üstüne yerleştirir; delik yoksa ekranın ortasına.
  ///
  /// YÜKSEKLİK ÖLÇÜLMEZ: üstte konumlanırken `top` yerine `bottom` verilir, böylece kartın kaç
  /// piksel olduğunu önceden bilmek gerekmez (metin uzunluğuna göre değişir).
  Widget _balon(Size ekran, Rect? delik, RehberAdim adim, bool etkilesim) {
    final genislik = ekran.width - 2 * SipSpace.govde;
    final en = genislik > 360 ? 360.0 : genislik;

    RehberBalon kur({RehberOk? ok, double okYeri = 0}) => RehberBalon(
          adim: adim,
          sira: _i + 1,
          toplam: widget.adimlar.length,
          etkilesim: etkilesim,
          onIleri: _ileri,
          onGeri: _i == 0 ? null : _geri,
          onAtla: widget.onAtla,
          okYonu: ok,
          okYeri: okYeri,
        );

    if (delik == null) {
      return Center(child: SizedBox(width: en, child: kur()));
    }

    final ustSinir = (ekran.width - en - SipSpace.govde).clamp(SipSpace.govde, double.infinity);
    final sol = (delik.center.dx - en / 2).clamp(SipSpace.govde, ustSinir).toDouble();
    // Delik ekranın üst yarısındaysa balon ALTINA, alt yarısındaysa ÜSTÜNE gelir.
    final alta = delik.bottom < ekran.height * 0.55;
    return Positioned(
      left: sol,
      width: en,
      top: alta ? delik.bottom + SipSpace.lg : null,
      bottom: alta ? null : ekran.height - delik.top + SipSpace.lg,
      // Ok YEREL koordinatta verilir (hedefin ortası eksi balonun sol kenarı): balon ekran
      // kenarında kaydırıldığında uç yine hedefe bakar.
      child: kur(ok: alta ? RehberOk.yukari : RehberOk.asagi, okYeri: delik.center.dx - sol),
    );
  }

  /// Hedef görünür alanın içinde mi (kaydırılıp ekrandan çıkmamış).
  static bool _gorunurAlanda(Rect r, Size ekran) =>
      r.bottom > 0 && r.top < ekran.height && r.right > 0 && r.left < ekran.width;
}

// ── Çizim ────────────────────────────────────────────────────────────────────────────────

/// Ekranı karartır, [delik] varsa oraya yuvarlatılmış bir pencere açar ve çevresine
/// [nabiz] ilerledikçe genişleyip sönen bir halka çizer.
class _KarartmaBoyaci extends CustomPainter {
  const _KarartmaBoyaci({required this.delik, required this.nabiz});

  final Rect? delik;
  final double nabiz;

  @override
  void paint(Canvas canvas, Size size) {
    final boya = Paint()..color = SipTokens.scrim;
    final tam = Path()..addRect(Offset.zero & size);
    final d = delik;
    if (d == null) {
      canvas.drawPath(tam, boya);
      return;
    }
    final pencere = Path()
      ..addRRect(RRect.fromRectAndRadius(d, const Radius.circular(_kose)));
    canvas.drawPath(Path.combine(PathOperation.difference, tam, pencere), boya);

    // Nabız halkası: dışa doğru büyür ve sönür. Deliğin KENDİSİ karartılmadığı için halka
    // dışarıda kalır, hedefin üstünü örtmez.
    if (nabiz > 0) {
      final buyume = 14 * nabiz;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          d.inflate(buyume),
          Radius.circular(_kose + buyume),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = SipTokens.onHero.withValues(alpha: 0.55 * (1 - nabiz)),
      );
    }

    // Sabit kenarlık: koyu temada delik ile karartma arasındaki sınır kayboluyordu.
    canvas.drawRRect(
      RRect.fromRectAndRadius(d, const Radius.circular(_kose)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = SipTokens.onHeroStrong,
    );
  }

  @override
  bool shouldRepaint(_KarartmaBoyaci eski) =>
      eski.delik != delik || eski.nabiz != nabiz;
}

