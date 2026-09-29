// YANDEX HARİTA NESNELERİ — pinler, rota çizgileri, pin görselleri (2026-09-29'da bölündü).
//
// `harita_yandex.dart` 500 satır sınırını aştığı için ayrıldı: orası motorun kurulumu, yaşam
// döngüsü, tuval ve kamera; burası haritadaki NESNELERİN içerikle eşitlenmesi.
//
// ⚠️ DİNLEYİCİLER GÜÇLÜ REFERANSLA TUTULUR: MapKit dokunuş ve kamera dinleyicilerini ZAYIF
// referansla saklar. Yerel bir değişkene verilen dinleyici çöp toplayıcıyla silinir ve dokunuşlar
// sessizce çalışmayı bırakır — bu yüzden dinleyiciler alanlarda durur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/image.dart' as yimg;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as y;

import '../../theme/tokens.dart';
import 'harita_ad_cipi.dart';
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
    required this.cizgi,
  });

  factory YandexRenkler.temadan(SipTokens t) => YandexRenkler(
        vurgu: t.accent,
        vurguUstu: t.accentInk,
        tamam: t.ok,
        sonuk: t.muted,
        yuzey: t.surface,
        metin: t.ink,
        cizgi: t.line,
      );

  final Color vurgu, vurguUstu, tamam, sonuk, yuzey, metin, cizgi;

  DurakCipRenkleri get durak => DurakCipRenkleri(
        vurgu: vurgu,
        vurguUstu: vurguUstu,
        yuzey: yuzey,
        metin: metin,
        cizgi: cizgi,
      );

  /// Önbellek anahtarı — aynı renklerle çizilmiş görsel yeniden üretilmez. Ad çipinin zemini
  /// ve yazısı da anahtardadır: koyu temaya geçince çip yeniden çizilmeli.
  String get anahtar => [vurgu, vurguUstu, tamam, sonuk, yuzey, metin, cizgi]
      .map((c) => c.toARGB32().toRadixString(16))
      .join('-');
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
  /// birbirine biner ve haritayı okunmaz kılar. 14,5: ad artık zeminli bir çiptir ve çıplak
  /// yazıdan geniştir; 13,5'te yoğun mahallelerde çipler üst üste biniyordu.
  static const double adEsigi = 14.5;

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

  /// Gruplu haritada kişi başına kesikli rota çizgileri. Değişince hepsi yeniden kurulur
  /// (birkaç çizgidir; tek tek eşlemek kazandırmaz).
  final List<y.PolylineMapObject> _grupRotalari = [];
  String _grupRotalariSon = '';
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
    _grupRotalariSon = '';
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
    _grupRotalariniCiz(icerik);
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
    cizgi.setStrokeColor((icerik.rotaRengi ?? _renkler.vurgu).withValues(alpha: 0.8));
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
    r
      ..geometry = geometri
      ..setStrokeColor((icerik.rotaRengi ?? _renkler.vurgu).withValues(alpha: 0.6));
  }

  /// Gruplu haritada her kişinin rotası KENDİ RENGİNDE: gerçek yol düz, başlangıç bacağı (ya da
  /// yol gelmediyse bütün rota) kesikli. Pinlerin ALTINDA.
  void _grupRotalariniCiz(HaritaIcerigi icerik) {
    String nk(List<HaritaNoktasi>? l) => (l ?? const []).map((n) => '${n.lat},${n.lng}').join(';');
    final anahtar = [
      for (final r in icerik.rotalar) '${r.renk?.toARGB32()}:${nk(r.noktalar)}:${nk(r.yol)}',
    ].join('|');
    if (anahtar == _grupRotalariSon) return;
    _grupRotalariSon = anahtar;
    for (final eski in _grupRotalari) {
      _kok.remove(eski);
    }
    _grupRotalari.clear();
    for (final r in icerik.rotalar) {
      final renk = r.renk ?? _renkler.vurgu;
      // GERÇEK YOL: düz ve kalın, kesikliden üstte (tek kişilik haritanın yol çizgisiyle aynı).
      if (r.yolVar) {
        _grupRotalari.add(_kok.addPolylineWithGeometry(
            y.Polyline([for (final n in r.yol!) _nokta(n)]))
          ..style = const y.LineStyle(strokeWidth: 4)
          ..zIndex = 1
          ..setStrokeColor(renk.withValues(alpha: 0.8)));
      }
      if (r.noktalar.length < 2) continue;
      _grupRotalari.add(_kok.addPolylineWithGeometry(
          y.Polyline([for (final n in r.noktalar) _nokta(n)]))
        ..style = const y.LineStyle(strokeWidth: 3, dashLength: 8, gapLength: 6)
        ..zIndex = 0
        ..setStrokeColor((r.renk ?? _renkler.vurgu).withValues(alpha: 0.7)));
    }
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
      // Ad, MapKit yazısı olarak DEĞİL pin görselinin parçası olarak çizilir
      // (`harita_ad_cipi.dart`). Çapa her iki hâlde de pinin merkezidir; ad açılıp kapanınca
      // pin yerinden oynamaz.
      final ad = _adlarAcik ? d.ad.trim() : '';
      final ikon = '${d.no}-$secili-$ad-${d.renk?.toARGB32()}';
      if (_durakIkonu[d.id] != ikon) {
        final (gorsel, capa) = _ikonlar.durak(d.no, secili: secili, ad: ad, renk: d.renk);
        p.setIconWithStyle(gorsel, y.IconStyle(anchor: capa));
        _durakIkonu[d.id] = ikon;
      }
    }
    for (final id in kalan) {
      _kok.remove(_duraklar.remove(id)!);
      _durakIkonu.remove(id);
    }
  }

  /// Kurye: motor ikonlu daire + ad çipi (durakla aynı dil). Bayat konum SÖNÜK çizilir ve
  /// çipte "X dk önce" yazar. Ad yakınlığa bakmaksızın HEP yazar: kurye az sayıdadır ve patron
  /// haritaya çoğu zaman "kim nerede" sorusuyla gelir.
  void _kuryeleriCiz(HaritaIcerigi icerik) {
    final kalan = {..._kuryeler.keys};
    for (final k in icerik.kuryeler) {
      kalan.remove(k.id);
      final p = _kuryeler[k.id] ??= _kok.addPlacemark()
        ..userData = '${HaritaDokunusu.kuryeOneki}${k.id}'
        // Kurye duraklardan ÜSTTE: hareket eden nokta daha acil bir bilgidir.
        ..zIndex = 2000000;
      p.geometry = _nokta(k.nokta);
      final ek = k.taze ? '' : k.bayatlik;
      final ikon = '${k.taze}-${k.ad}-$ek-${k.renk?.toARGB32()}';
      if (_kuryeIkonu[k.id] != ikon) {
        final (gorsel, capa) = _ikonlar.kurye(taze: k.taze, ad: k.ad, ek: ek, renk: k.renk);
        p.setIconWithStyle(gorsel, y.IconStyle(anchor: capa));
        _kuryeIkonu[k.id] = ikon;
      }
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

  /// Numaralı durak; [ad] doluysa sağında ad çipiyle. Seçiliyken büyür ve yarı saydam bir hale
  /// alır. Görselle birlikte ÇAPASI döner (pinin merkezi) — çip görseli sağa genişletir.
  /// [renk] grup rengidir (gruplu harita); null = temanın vurgusu.
  (yimg.ImageProvider, math.Point<double>) durak(int no,
      {required bool secili, String ad = '', Color? renk}) {
    final cizim = DurakAdCipi(
        no: no, secili: secili, ad: ad, renkler: _r.durak.pinRengiyle(renk), dpr: dpr);
    final anahtar = 'durak-$no-$secili-$ad-${renk?.toARGB32() ?? 0}';
    return (_saglayici(anahtar, cizim.ciz), cizim.capa);
  }

  /// Cihaz: yumuşak hale + içi dolu nokta (numarasız — kurye bir durak değildir).
  yimg.ImageProvider cihaz() => _saglayici('cihaz', () {
        const dp = 32.0;
        return _resim(dp, (c, o) {
          final m = Offset(dp * o / 2, dp * o / 2);
          _daire(c, m, 16 * o, _r.tamam.withValues(alpha: 0.18));
          _daire(c, m, 9 * o, _r.tamam, kenar: Colors.white, kenarKalinlik: 3 * o);
        });
      });

  /// Kurye: motor ikonlu daire + sağında ad çipi (duraklarla AYNI dil, 2026-09-29). Bayat
  /// konumda pin ve ad soluk, "X dk önce" çipin içinde soluk ikinci parça.
  (yimg.ImageProvider, math.Point<double>) kurye(
      {required bool taze, required String ad, String ek = '', Color? renk}) {
    final cizim = KuryeAdCipi(
      taze: taze,
      motorYolu: kKuryeMotorYolu,
      ad: ad,
      ek: ek,
      renkler: _r.durak.pinRengiyle(renk),
      dpr: dpr,
    );
    final anahtar = 'kurye-$taze-$ad-$ek-${renk?.toARGB32() ?? 0}';
    return (_saglayici(anahtar, cizim.ciz), cizim.capa);
  }
}
