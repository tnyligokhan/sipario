// HARİTA DURAK PİNİ + AD ÇİPİ — yakınlaşınca müşterinin adı pinin SAĞINDA, zeminli bir çipte
// (kullanıcı geri bildirimi 2026-09-29: "haritada yakınlaşınca müşterinin adı gözüküyor fakat
// konumlandırması ve görünümü hoşuma gitmedi").
//
// ══ ESKİSİ NEDEN KÖTÜYDÜ ════════════════════════════════════════════════════════════════════
// Ad, MapKit'in yerleşik yazısıyla pinin ALTINA, zeminsiz ve yalnız ince bir dış çizgiyle
// yazılıyordu. Üç kusuru vardı: (1) yazı pinden kopuk duruyor, hangi pine ait olduğu komşu
// pinler arasında belirsizleşiyordu, (2) sokak adları ve bina yazılarıyla aynı görsel dili
// konuştuğu için haritanın kendi yazısına karışıyordu, (3) 11 punto ve zeminsizdi, güneşte
// okunmuyordu.
//
// ══ YENİSİ ══════════════════════════════════════════════════════════════════════════════════
// Pin ve ad TEK GÖRSELDİR: çip pinin merkezinden başlar ve sağa uzanır, pin çipin sol ucunu
// örter. Böylece ad pine YAPIŞIKTIR (hangi pine ait olduğu tartışmasızdır), yüzey renginde
// zemin ve ince kenar haritanın yazısından ayrışır. Görselin çapası pinin MERKEZİDİR — ad
// açılıp kapanırken pin yerinden oynamaz.
//
// SAF ÇİZİM: MapKit'e bağlı değildir; ölçü ve çapa eşzamanlı hesaplanır (görsel tembel çizilir
// ama çapa ondan önce gerekir), `flutter test` içinde gerçek resim olarak üretilip sınanır.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart' show sipFontBody;

/// Çizimin renkleri — temadan gelir, çağıran verir.
class DurakCipRenkleri {
  const DurakCipRenkleri({
    required this.vurgu,
    required this.vurguUstu,
    required this.yuzey,
    required this.metin,
    required this.cizgi,
  });

  final Color vurgu, vurguUstu, yuzey, metin, cizgi;
}

/// Numaralı durak pini; [ad] verilirse sağında ad çipiyle birlikte. Ölçüler mantıksal
/// pikseldir (dp), görsel [dpr] yoğunluğunda çizilir.
class DurakAdCipi {
  DurakAdCipi({
    required this.no,
    required this.secili,
    required this.renkler,
    required this.dpr,
    String? ad,
  }) : ad = (ad ?? '').trim();

  final int no;
  final bool secili;
  final DurakCipRenkleri renkler;
  final double dpr;

  /// Boşsa çip çizilmez, yalnız pin.
  final String ad;

  /// Çipin boyu ve adın en fazla kaplayacağı genişlik. 150 dp: iki kelimelik bir ad sığar,
  /// uzun unvanlar kısaltılır — çip komşu pinin üstüne uzanmamalı.
  static const double cipYuksekligi = 24;
  static const double azamiAdGenisligi = 150;

  /// Gölge taşması için sağ ve alt pay.
  static const double _golgePayi = 3;

  bool get cipVar => ad.isNotEmpty;

  /// Pinin kare kutusu — seçiliyken hale sığsın diye büyür.
  double get pinKutusu => secili ? 56 : 32;
  double get pinYaricapi => secili ? 19 : 15;

  late final TextPainter _yazi = TextPainter(
    text: TextSpan(
      text: ad,
      style: TextStyle(
        fontFamily: sipFontBody,
        fontSize: 12.5,
        fontVariations: const [FontVariation('wght', 700)],
        color: renkler.metin,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: azamiAdGenisligi);

  /// Adın başladığı yer: pinin sağ kenarından 7 dp sonra.
  double get _adSol => pinKutusu / 2 + pinYaricapi + 7;

  double get genislik =>
      cipVar ? math.max(pinKutusu, _adSol + _yazi.width + 11 + _golgePayi) : pinKutusu;
  double get yukseklik => pinKutusu;

  /// Görselin haritadaki noktaya oturan yeri (0..1) — daima PİNİN MERKEZİ.
  math.Point<double> get capa => math.Point((pinKutusu / 2) / genislik, 0.5);

  /// Görseli üretir.
  Future<ui.Image> ciz() {
    final kaydedici = ui.PictureRecorder();
    final c = Canvas(kaydedici)..scale(dpr);
    final m = Offset(pinKutusu / 2, pinKutusu / 2);
    if (cipVar) _cipCiz(c, m);
    _pinCiz(c, m);
    return kaydedici
        .endRecording()
        .toImage((genislik * dpr).ceil(), (yukseklik * dpr).ceil());
  }

  void _cipCiz(Canvas c, Offset m) {
    final kutu = RRect.fromLTRBR(
      m.dx,
      m.dy - cipYuksekligi / 2,
      genislik - _golgePayi,
      m.dy + cipYuksekligi / 2,
      const Radius.circular(cipYuksekligi / 2),
    );
    // Yumuşak gölge: çip haritanın üstünde duran bir kart gibi okunur, harita yazısı gibi değil.
    c.drawRRect(
      kutu.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0x2E000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        ..isAntiAlias = true,
    );
    c.drawRRect(kutu, Paint()..color = renkler.yuzey..isAntiAlias = true);
    c.drawRRect(
      kutu.deflate(0.5),
      Paint()
        ..color = renkler.cizgi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );
    _yazi.paint(c, Offset(_adSol, m.dy - _yazi.height / 2));
  }

  void _pinCiz(Canvas c, Offset m) {
    if (secili) {
      c.drawCircle(m, 28, Paint()..color = renkler.vurgu.withValues(alpha: 0.22)..isAntiAlias = true);
    }
    c.drawCircle(m, pinYaricapi, Paint()..color = renkler.vurgu..isAntiAlias = true);
    final kenar = secili ? 3.0 : 2.0;
    c.drawCircle(
      m,
      pinYaricapi - kenar / 2,
      Paint()
        ..color = renkler.vurguUstu
        ..style = PaintingStyle.stroke
        ..strokeWidth = kenar
        ..isAntiAlias = true,
    );
    final numara = TextPainter(
      text: TextSpan(
        text: '$no',
        style: TextStyle(
          fontFamily: sipFontBody,
          color: renkler.vurguUstu,
          fontSize: (secili ? 15.0 : 13.0) * (no >= 100 ? 0.82 : 1),
          fontVariations: const [FontVariation('wght', 800)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    numara.paint(c, m - Offset(numara.width / 2, numara.height / 2));
  }
}
