// HARİTA PİNİ + AD ÇİPİ — yakınlaşınca müşterinin adı pinin SAĞINDA, zeminli bir çipte
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
// KURYE DE AYNI DİLİ KONUŞUR (kullanıcı geri bildirimi 2026-09-29: "müşteri adını güncelledin
// fakat kuryeyi yapmamışsın"): kurye pini motor ikonlu dairedir, adı aynı çipte yazar. Konumu
// bayatsa pin ve ad soluklaşır, "7 dk önce" çipin içinde ikinci, soluk bir parça olarak durur.
// İki çizim TEK TABANI paylaşır ([PinCipi]) — biri güncellenip öteki unutulmasın diye.
//
// SAF ÇİZİM: MapKit'e bağlı değildir; ölçü ve çapa eşzamanlı hesaplanır (görsel tembel çizilir
// ama çapa ondan önce gerekir), `flutter test` içinde gerçek resim olarak üretilip sınanır.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/svg_path.dart';
import '../../theme/tokens.dart' show sipFontBody;

/// Çizimin renkleri — temadan gelir, çağıran verir.
class DurakCipRenkleri {
  const DurakCipRenkleri({
    required this.vurgu,
    required this.vurguUstu,
    required this.yuzey,
    required this.metin,
    required this.cizgi,
    this.sonuk = const Color(0xFF8A8894),
  });

  final Color vurgu, vurguUstu, yuzey, metin, cizgi, sonuk;

  /// Aynı renkler, yalnız pinin rengi [renk] (grup rengi). null = değişmez.
  DurakCipRenkleri pinRengiyle(Color? renk) => renk == null
      ? this
      : DurakCipRenkleri(
          vurgu: renk,
          vurguUstu: vurguUstu,
          yuzey: yuzey,
          metin: metin,
          cizgi: cizgi,
          sonuk: sonuk,
        );
}

/// Pin + (varsa) sağındaki ad çipi. Ölçüler mantıksal pikseldir (dp), görsel [dpr]
/// yoğunluğunda çizilir. Alt sınıf yalnız pinin kendisini çizer.
abstract class PinCipi {
  PinCipi({required this.renkler, required this.dpr, String? ad, this.ek = ''})
      : ad = (ad ?? '').trim();

  final DurakCipRenkleri renkler;
  final double dpr;

  /// Boşsa çip çizilmez, yalnız pin.
  final String ad;

  /// Adın ardından SOLUK yazılan ikinci parça ("7 dk önce"); boşsa yok.
  final String ek;

  /// Çipin boyu ve adın en fazla kaplayacağı genişlik. 150 dp: iki kelimelik bir ad sığar,
  /// uzun unvanlar kısaltılır — çip komşu pinin üstüne uzanmamalı.
  static const double cipYuksekligi = 24;
  static const double azamiAdGenisligi = 150;

  /// Gölge taşması için sağ pay.
  static const double _golgePayi = 3;

  bool get cipVar => ad.isNotEmpty;

  /// Pinin kare kutusu ve dairesinin yarıçapı.
  double get pinKutusu;
  double get pinYaricapi;

  /// Ad soluk mu (bayat konum)?
  bool get sonuk => false;

  /// Pini [m] merkezine çizer (dp birimleri; tuval zaten [dpr] ile ölçeklenmiş).
  void pinCiz(Canvas c, Offset m);

  TextStyle _stil(Color renk, double agirlik) => TextStyle(
        fontFamily: sipFontBody,
        fontSize: 12.5,
        fontVariations: [FontVariation('wght', agirlik)],
        color: renk,
        height: 1.1,
      );

  late final TextPainter _yazi = TextPainter(
    text: TextSpan(
      text: ad,
      style: _stil(sonuk ? renkler.sonuk : renkler.metin, 700),
      children: [
        if (ek.isNotEmpty) TextSpan(text: '  $ek', style: _stil(renkler.sonuk, 600)),
      ],
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
    pinCiz(c, m);
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

  /// Dolgu + kenar halkası.
  static void daire(Canvas c, Offset m, double r, Color dolgu, Color kenar, double kalinlik) {
    c.drawCircle(m, r, Paint()..color = dolgu..isAntiAlias = true);
    c.drawCircle(
      m,
      r - kalinlik / 2,
      Paint()
        ..color = kenar
        ..style = PaintingStyle.stroke
        ..strokeWidth = kalinlik
        ..isAntiAlias = true,
    );
  }
}

/// Numaralı durak pini; [ad] verilirse sağında ad çipiyle birlikte.
///
/// SEÇİLİ HÂLİ YOKTUR (2026-09-30): seçim ayrı bir görsel olarak çizildiğinde MapKit onu
/// eşzamansız yüklüyor, özet kapanırken geç gelen büyük görsel yanlış çapayla boş bir yere
/// düşüyordu. Pine dokunmak artık yalnız özeti açar ve kamerayı pine yaklaştırır.
class DurakAdCipi extends PinCipi {
  DurakAdCipi({
    required this.no,
    required super.renkler,
    required super.dpr,
    super.ad,
  });

  final int no;

  @override
  double get pinKutusu => 32;
  @override
  double get pinYaricapi => 15;

  @override
  void pinCiz(Canvas c, Offset m) {
    PinCipi.daire(c, m, pinYaricapi, renkler.vurgu, renkler.vurguUstu, 2);
    final numara = TextPainter(
      text: TextSpan(
        text: '$no',
        style: TextStyle(
          fontFamily: sipFontBody,
          color: renkler.vurguUstu,
          fontSize: 13.0 * (no >= 100 ? 0.82 : 1),
          fontVariations: const [FontVariation('wght', 800)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    numara.paint(c, m - Offset(numara.width / 2, numara.height / 2));
  }
}

/// Kurye pini: motor ikonlu daire + adı; konum bayatsa soluk ve "X dk önce" ekiyle.
class KuryeAdCipi extends PinCipi {
  KuryeAdCipi({
    required this.taze,
    required this.motorYolu,
    required super.renkler,
    required super.dpr,
    super.ad,
    super.ek,
  });

  final bool taze;

  /// Motor ikonunun SVG yolları (`|` ile ayrılmış, 24 birimlik kutu).
  final String motorYolu;

  @override
  double get pinKutusu => 36;
  @override
  double get pinYaricapi => 16;
  @override
  bool get sonuk => !taze;

  @override
  void pinCiz(Canvas c, Offset m) {
    // Dış yüzey halkası: kurye pini durak pininden AYRIŞMALI (hareket eden bir kişidir).
    c.drawCircle(m, pinYaricapi + 2, Paint()..color = renkler.yuzey..isAntiAlias = true);
    PinCipi.daire(c, m, pinYaricapi, taze ? renkler.vurgu : renkler.sonuk, renkler.vurguUstu, 2);
    const ikon = 17.0;
    c
      ..save()
      ..translate(m.dx - ikon / 2, m.dy - ikon / 2)
      ..scale(ikon / 24);
    final firca = Paint()
      ..style = PaintingStyle.stroke
      ..color = renkler.vurguUstu
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (final d in motorYolu.split('|')) {
      c.drawPath(svgYoluCoz(d), firca);
    }
    c.restore();
  }
}
