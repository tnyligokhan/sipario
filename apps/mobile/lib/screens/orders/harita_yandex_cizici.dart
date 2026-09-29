// YANDEX HARİTA NESNELERİ — pinler, rota çizgileri, pin görselleri (2026-09-29'da bölündü).
//
// `harita_yandex.dart` 500 satır sınırını aştığı için ayrıldı: orası motorun kurulumu, yaşam
// döngüsü, tuval ve kamera; burası haritadaki NESNELERİN içerikle eşitlenmesi.
//
// ⚠️ DİNLEYİCİLER GÜÇLÜ REFERANSLA TUTULUR: MapKit dokunuş ve kamera dinleyicilerini ZAYIF
// referansla saklar. Yerel bir değişkene verilen dinleyici çöp toplayıcıyla silinir ve dokunuşlar
// sessizce çalışmayı bırakır — bu yüzden dinleyiciler alanlarda durur.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/image.dart' as yimg;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as y;

import '../../theme/svg_path.dart';
import '../../theme/tokens.dart';
import 'harita_icerigi.dart';
import 'harita_kurye_katmani.dart' show kKuryeMotorYolu;

/// Temadan okunan renkler — tema değişince pin görselleri yeniden çizilir.
class YandexRenkler {
  const YandexRenkler({
    required this.vurgu,
    required this.vurguUstu,
    required this.tamam,
    required this.sonuk,
    required this.yuzey,
    required this.metin,
  });

  factory YandexRenkler.temadan(SipTokens t) => YandexRenkler(
        vurgu: t.accent,
        vurguUstu: t.accentInk,
        tamam: t.ok,
        sonuk: t.muted,
        yuzey: t.surface,
        metin: t.ink,
      );

  final Color vurgu, vurguUstu, tamam, sonuk, yuzey, metin;

  /// Önbellek anahtarı — aynı renklerle çizilmiş görsel yeniden üretilmez.
  String get anahtar =>
      [vurgu, vurguUstu, tamam, sonuk].map((c) => c.toARGB32().toRadixString(16)).join('-');
}

/// MapKit dokunuş dinleyicisi — nesnenin `userData`sındaki kimliği bildirir.
class _DokunusDinleyici implements y.MapObjectTapListener {
  _DokunusDinleyici(this._bildir);

  final void Function(String id) _bildir;

  @override
  bool onMapObjectTap(y.MapObject nesne, y.Point nokta) {
    final veri = nesne.userData;
    if (veri is! String) return false;
    _bildir(veri);
    return true;
  }
}

/// Kamera dinleyicisi — yakınlık eşiği aşılınca müşteri adları açılır/kapanır.
class _KameraDinleyici implements y.MapCameraListener {
  _KameraDinleyici(this._zoom);

  final void Function(double zoom) _zoom;

  @override
  void onCameraPositionChanged(
    y.Map map,
    y.CameraPosition konum,
    y.CameraUpdateReason sebep,
    bool bitti,
  ) =>
      _zoom(konum.zoom);
}

/// Haritadaki nesneleri içerikle eşitler. Durum (nesneler, son içerik, dinleyiciler) ve davranış
/// (çiz, tema, bırak) tek nesnede. Değişmeyen nesneye dokunulmaz: her güncellemede her şeyi
/// silip yeniden çizmek pinleri kırpıştırırdı.
class YandexCizici {
  YandexCizici({
    required y.Map harita,
    required YandexRenkler renkler,
    required double dpr,
    required void Function(String id) onDokunus,
  })  : _harita = harita,
        _ikonlar = YandexIkonlar(renkler, dpr),
        _renkler = renkler,
        _kok = harita.mapObjects.addCollection() {
    _dokunus = _DokunusDinleyici(onDokunus);
    _kok.addTapListener(_dokunus);
    _kamera = _KameraDinleyici(_zoomDegisti);
    _harita.addCameraListener(_kamera);
    _adlarAcik = _harita.cameraPosition.zoom >= adEsigi;
  }

  /// Müşteri adları bu yakınlıktan itibaren yazılır (sokak ölçeği) — uzak ölçekte adlar
  /// birbirine biner ve haritayı okunmaz kılar.
  static const double adEsigi = 13.5;

  final y.Map _harita;
  final y.MapObjectCollection _kok;
  YandexIkonlar _ikonlar;
  YandexRenkler _renkler;

  // Güçlü referanslar (bkz. dosya başlığı).
  late final _DokunusDinleyici _dokunus;
  late final _KameraDinleyici _kamera;

  final Map<String, y.PlacemarkMapObject> _duraklar = {};
  final Map<String, String> _durakIkonu = {};
  final Map<String, y.PlacemarkMapObject> _kuryeler = {};
  final Map<String, String> _kuryeIkonu = {};
  y.PlacemarkMapObject? _cihaz;
  y.PolylineMapObject? _rota;
  List<HaritaNoktasi> _rotaSon = const [];
  y.PolylineMapObject? _yol;
  List<HaritaNoktasi> _yolSon = const [];
  HaritaIcerigi _icerik = const HaritaIcerigi();
  bool _adlarAcik = false;
  bool _birakildi = false;

  void birak() {
    if (_birakildi) return;
    _birakildi = true;
    _harita.removeCameraListener(_kamera);
    _kok.removeTapListener(_dokunus);
  }

  void temaDegisti(YandexRenkler renkler) {
    _renkler = renkler;
    _ikonlar = YandexIkonlar(renkler, _ikonlar.dpr);
    _durakIkonu.clear();
    _kuryeIkonu.clear();
    _cihaz?.setIcon(_ikonlar.cihaz());
    _rota?.setStrokeColor(renkler.vurgu.withValues(alpha: 0.6));
    _yol?.setStrokeColor(renkler.vurgu.withValues(alpha: 0.8));
    ciz(_icerik);
  }

  void _zoomDegisti(double zoom) {
    final acik = zoom >= adEsigi;
    if (acik == _adlarAcik) return;
    _adlarAcik = acik;
    _duraklariCiz(_icerik); // yalnız metinler değişir, görseller önbellekten
  }

  static y.Point _nokta(HaritaNoktasi n) => y.Point(latitude: n.lat, longitude: n.lng);

  void ciz(HaritaIcerigi icerik) {
    if (_birakildi) return;
    _icerik = icerik;
    _yoluCiz(icerik);
    _rotayiCiz(icerik);
    _cihaziCiz(icerik);
    _duraklariCiz(icerik);
    _kuryeleriCiz(icerik);
  }

  /// GERÇEK YOL çizgisi (sunucudan) — DÜZ ve kesikliden kalın: kurye gerçekten bu yoldan gider.
  /// Pinlerin ALTINDA.
  void _yoluCiz(HaritaIcerigi icerik) {
    final noktalar = icerik.yolNoktalari;
    if (listEquals(noktalar, _yolSon)) return;
    _yolSon = noktalar;
    if (noktalar.isEmpty) {
      final y0 = _yol;
      if (y0 != null) _kok.remove(y0);
      _yol = null;
      return;
    }
    final geometri = y.Polyline([for (final n in noktalar) _nokta(n)]);
    final cizgi = _yol ??= _kok.addPolylineWithGeometry(geometri)
      ..style = const y.LineStyle(strokeWidth: 4)
      ..zIndex = 1
      ..setStrokeColor(_renkler.vurgu.withValues(alpha: 0.8));
    cizgi.geometry = geometri;
  }

  /// Kuş uçuşu kesikli çizgi — yol varken yalnız cihaz→ilk durak bacağı, yokken bütün sıra
  /// (bkz. `HaritaIcerigi.rotaNoktalari`). KESİKLİ, çünkü yol değil SIRA anlatır. Pinlerin ALTINDA.
  void _rotayiCiz(HaritaIcerigi icerik) {
    final noktalar = icerik.rotaNoktalari;
    if (listEquals(noktalar, _rotaSon)) return;
    _rotaSon = noktalar;
    if (noktalar.isEmpty) {
      final r = _rota;
      if (r != null) _kok.remove(r);
      _rota = null;
      return;
    }
    final geometri = y.Polyline([for (final n in noktalar) _nokta(n)]);
    final r = _rota ??= _kok.addPolylineWithGeometry(geometri)
      ..style = const y.LineStyle(strokeWidth: 3, dashLength: 8, gapLength: 6)
      ..zIndex = 0
      ..setStrokeColor(_renkler.vurgu.withValues(alpha: 0.6));
    r.geometry = geometri;
  }

  void _cihaziCiz(HaritaIcerigi icerik) {
    final c = icerik.cihaz;
    if (c == null) {
      final p = _cihaz;
      if (p != null) _kok.remove(p);
      _cihaz = null;
      return;
    }
    final p = _cihaz ??= _kok.addPlacemark()
      ..setIcon(_ikonlar.cihaz())
      ..zIndex = 5;
    p.geometry = _nokta(c);
  }

  void _duraklariCiz(HaritaIcerigi icerik) {
    final kalan = {..._duraklar.keys};
    for (final d in icerik.duraklar) {
      kalan.remove(d.id);
      final secili = icerik.seciliMi(d);
      final p = _duraklar[d.id] ??= _kok.addPlacemark()
        ..userData = '${HaritaDokunusu.durakOneki}${d.id}';
      p
        ..geometry = _nokta(d.nokta)
        ..zIndex = 10 + icerik.oncelik(d);
      final ikon = '${d.no}-$secili';
      if (_durakIkonu[d.id] != ikon) {
        p.setIcon(_ikonlar.durak(d.no, secili: secili));
        _durakIkonu[d.id] = ikon;
      }
      p.setTextWithStyle(_ikonlar.adStili(), text: _adlarAcik ? d.ad : '');
    }
    for (final id in kalan) {
      _kok.remove(_duraklar.remove(id)!);
      _durakIkonu.remove(id);
    }
  }

  /// Kurye: motor ikonlu daire + adı. Bayat konum SÖNÜK çizilir ve altına "X dk önce" yazar.
  void _kuryeleriCiz(HaritaIcerigi icerik) {
    final kalan = {..._kuryeler.keys};
    for (final k in icerik.kuryeler) {
      kalan.remove(k.id);
      final p = _kuryeler[k.id] ??= _kok.addPlacemark()
        ..userData = '${HaritaDokunusu.kuryeOneki}${k.id}'
        // Kurye duraklardan ÜSTTE: hareket eden nokta daha acil bir bilgidir.
        ..zIndex = 2000000;
      p.geometry = _nokta(k.nokta);
      final ikon = '${k.taze}';
      if (_kuryeIkonu[k.id] != ikon) {
        p.setIcon(_ikonlar.kurye(taze: k.taze));
        _kuryeIkonu[k.id] = ikon;
      }
      p.setTextWithStyle(_ikonlar.adStili(sonuk: !k.taze), text: k.etiket);
    }
    for (final id in kalan) {
      _kok.remove(_kuryeler.remove(id)!);
      _kuryeIkonu.remove(id);
    }
  }
}

/// Pin görselleri — `dart:ui` ile çizilir, anahtarıyla önbelleklenir (MapKit de `id` ile
/// önbellekler: aynı numaralı pin ikinci kez çizilmez).
class YandexIkonlar {
  YandexIkonlar(this._r, this.dpr);

  final YandexRenkler _r;
  final double dpr;

  final Map<String, yimg.ImageProvider> _onbellek = {};

  yimg.ImageProvider _saglayici(String ad, Future<ui.Image> Function() ciz) =>
      _onbellek.putIfAbsent(
        ad,
        () => yimg.ImageProvider(ciz, id: 'sip-$ad-${_r.anahtar}-$dpr'),
      );

  /// Görsel mantıksal piksel (dp) cinsinden tasarlanır, cihaz yoğunluğunda çizilir.
  Future<ui.Image> _resim(double dp, void Function(Canvas c, double olcek) boya) {
    final px = (dp * dpr).ceil();
    final kaydedici = ui.PictureRecorder();
    final tuval = Canvas(kaydedici);
    boya(tuval, dpr);
    return kaydedici.endRecording().toImage(px, px);
  }

  static void _daire(Canvas c, Offset m, double yaricap, Color dolgu,
      {Color? kenar, double kenarKalinlik = 0}) {
    c.drawCircle(m, yaricap, Paint()..color = dolgu..isAntiAlias = true);
    if (kenar != null && kenarKalinlik > 0) {
      c.drawCircle(
        m,
        yaricap - kenarKalinlik / 2,
        Paint()
          ..color = kenar
          ..style = PaintingStyle.stroke
          ..strokeWidth = kenarKalinlik
          ..isAntiAlias = true,
      );
    }
  }

  /// Numaralı durak. Seçiliyken büyür ve yarı saydam bir hale alır.
  yimg.ImageProvider durak(int no, {required bool secili}) =>
      _saglayici('durak-$no-$secili', () {
        final dp = secili ? 56.0 : 32.0;
        return _resim(dp, (c, o) {
          final m = Offset(dp * o / 2, dp * o / 2);
          if (secili) _daire(c, m, 28 * o, _r.vurgu.withValues(alpha: 0.22));
          final yaricap = (secili ? 19.0 : 15.0) * o;
          _daire(c, m, yaricap, _r.vurgu,
              kenar: _r.vurguUstu, kenarKalinlik: (secili ? 3.0 : 2.0) * o);
          final yazi = TextPainter(
            text: TextSpan(
              text: '$no',
              style: TextStyle(
                color: _r.vurguUstu,
                fontSize: (secili ? 15.0 : 13.0) * (no >= 100 ? 0.82 : 1) * o,
                fontWeight: FontWeight.w800,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          yazi.paint(c, m - Offset(yazi.width / 2, yazi.height / 2));
        });
      });

  /// Cihaz: yumuşak hale + içi dolu nokta (numarasız — kurye bir durak değildir).
  yimg.ImageProvider cihaz() => _saglayici('cihaz', () {
        const dp = 32.0;
        return _resim(dp, (c, o) {
          final m = Offset(dp * o / 2, dp * o / 2);
          _daire(c, m, 16 * o, _r.tamam.withValues(alpha: 0.18));
          _daire(c, m, 9 * o, _r.tamam, kenar: Colors.white, kenarKalinlik: 3 * o);
        });
      });

  /// Kurye: motor ikonlu daire; bayatsa sönük renk.
  yimg.ImageProvider kurye({required bool taze}) => _saglayici('kurye-$taze', () {
        const dp = 32.0;
        return _resim(dp, (c, o) {
          final m = Offset(dp * o / 2, dp * o / 2);
          _daire(c, m, 15 * o, taze ? _r.vurgu : _r.sonuk,
              kenar: _r.vurguUstu, kenarKalinlik: 2 * o);
          // Lucide `bike` — 24 birimlik kutu, 17 dp'ye ölçeklenir ve ortalanır.
          const ikon = 17.0;
          c
            ..save()
            ..translate(m.dx - ikon * o / 2, m.dy - ikon * o / 2)
            ..scale(ikon * o / 24);
          final firca = Paint()
            ..style = PaintingStyle.stroke
            ..color = _r.vurguUstu
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true;
          for (final d in kKuryeMotorYolu.split('|')) {
            c.drawPath(svgYoluCoz(d), firca);
          }
          c.restore();
        });
      });

  /// Pinin altındaki ad — yüzey renginde dış çizgiyle, haritanın her renginde okunur.
  y.TextStyle adStili({bool sonuk = false}) => y.TextStyle(
        size: 11,
        color: sonuk ? _r.sonuk : _r.metin,
        outlineColor: _r.yuzey,
        outlineWidth: 2,
        placement: y.TextStylePlacement.Bottom,
        offset: 2,
        // Çakışan ad düşer, pin her zaman kalır.
        textOptional: true,
      );
}
