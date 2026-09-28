// MAPLIBRE TUVALİ — sipariş haritasının yerel vektör motoru (2026-09-28).
//
// NEDEN: önceki harita resim karolarla çiziliyordu (flutter_map + CARTO). İki parmakla
// yakınlaştırınca bir sonraki seviyenin karoları gelene dek eldeki resim BÜYÜTÜLÜYOR ve harita
// pikselleşiyordu — bu, resim karonun doğasıdır, sağlayıcı ya da önbellekle giderilemez. MapLibre
// yolları ve yazıları telefonda, ekran kartıyla çizer: her yakınlıkta keskin, kaydırması akıcı.
//
// PİNLER DE VEKTÖR: duraklar, rota çizgisi, cihaz ve kuryeler Flutter widget'ı değil, motorun
// kendi katmanlarıdır (GeoJSON kaynağı + daire/metin katmanı). Böylece haritayla birlikte
// kayar, hiç titremez ve seçili durak gibi durumlar veri üzerinden (ifadeyle) çizilir.
//
// SIRA KORUNUR: motor çağrıları eşzamansızdır ve tema değişince stil baştan yüklenir. Stil
// yüklenirken gelen bir veri güncellemesi eski stile yazılıp kaybolmasın diye her stil yüklemesi
// yeni bir [_Katmanlar] nesnesi doğurur ve işlemler onun içinde tek sıraya dizilir.

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../theme/svg_path.dart';
import '../../theme/tokens.dart';
import 'harita_icerigi.dart';
import 'harita_kurye_katmani.dart' show kKuryeMotorYolu;
import 'harita_stili.dart';
import 'harita_tuvali.dart';

/// Üretim tuvali. Stil hazır olana dek düz zemin çizer (boş beyaz ekran yerine temanın rengi).
class MapLibreTuvali extends StatefulWidget {
  const MapLibreTuvali(this.ayar, {super.key});

  final HaritaTuvaliAyari ayar;

  @override
  State<MapLibreTuvali> createState() => _MapLibreTuvaliState();
}

class _MapLibreTuvaliState extends State<MapLibreTuvali> {
  String? _stil;
  bool? _stilKoyu;
  MapLibreMapController? _kontrolcu;
  _Katmanlar? _katmanlar;
  _MapLibreKamerasi? _kamera;
  bool _hazirBildirildi = false;

  @override
  void initState() {
    super.initState();
    _stiliGetir();
  }

  @override
  void didUpdateWidget(MapLibreTuvali eski) {
    super.didUpdateWidget(eski);
    if (widget.ayar.koyu != _stilKoyu) _stiliGetir();
    _kamera?.kenarBoslugu = widget.ayar.kenarBoslugu;
    _katmanlar?.icerikYaz(widget.ayar.icerik);
  }

  @override
  void dispose() {
    _kontrolcu?.onFeatureTapped.remove(_dokunuldu);
    super.dispose();
  }

  /// Tema değişince stil yeniden alınır; motor `styleString` değişimini görüp stili baştan
  /// yükler ve [_stilYuklendi] katmanları yeni renklerle yeniden kurar.
  void _stiliGetir() {
    final koyu = widget.ayar.koyu;
    _stilKoyu = koyu;
    unawaited(HaritaStilDeposu.varsayilan.getir(koyu: koyu).then((stil) {
      if (!mounted || _stilKoyu != koyu) return;
      setState(() => _stil = stil);
    }));
  }

  void _haritaKuruldu(MapLibreMapController k) {
    _kontrolcu = k;
    _kamera = _MapLibreKamerasi(k, widget.ayar.kenarBoslugu);
    k.onFeatureTapped.add(_dokunuldu);
  }

  void _dokunuldu(
    Point<double> _,
    LatLng _,
    String id,
    String _,
    Annotation? _,
  ) {
    final dokunus = HaritaDokunusu.coz(id);
    if (dokunus != null) widget.ayar.onDokunus(dokunus);
  }

  Future<void> _stilYuklendi() async {
    final k = _kontrolcu;
    final kamera = _kamera;
    if (k == null || kamera == null || !mounted) return;
    final katmanlar = _Katmanlar(k, _KatmanRenkleri.temadan(context.sip));
    // Önceki stilin katmanları SÖNER: sırada bekleyen eski yazımları yeni stile bayat veri
    // yazmasın.
    _katmanlar?.birak();
    _katmanlar = katmanlar;
    await katmanlar.kur(widget.ayar.icerik);
    if (!mounted || _hazirBildirildi) return;
    // İlk yüklemede kadraja ANİMASYONSUZ oturulur (kullanıcı açılışta kayan bir harita
    // görmesin); kamera ekrana ondan SONRA verilir.
    final kadraj = widget.ayar.icerik.kadraj;
    if (kadraj != null) await kamera.kadrajla(kadraj, animasyon: false);
    _hazirBildirildi = true;
    if (mounted) widget.ayar.onHazir(kamera);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final stil = _stil;
    if (stil == null) return ColoredBox(color: t.surface2);
    final orta = widget.ayar.icerik.kadraj?.orta;
    return MapLibreMap(
      styleString: stil,
      initialCameraPosition: CameraPosition(
        target: orta == null ? const LatLng(39, 35) : LatLng(orta.lat, orta.lng),
        zoom: orta == null ? 5 : 12,
      ),
      onMapCreated: _haritaKuruldu,
      onStyleLoadedCallback: () => unawaited(_stilYuklendi()),
      minMaxZoomPreference: const MinMaxZoomPreference(3, 18.5),
      // Döndürme ve eğme KAPALI: kuzey hep yukarıda. Kurye haritayı yol bulmak için değil
      // "sıradaki durak nerede" diye okur; dönmüş bir harita bu soruyu zorlaştırır.
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      // Annotation yöneticileri kullanılmıyor (pinler GeoJSON katmanı) — boş liste Android'de
      // belirgin bir performans kazancıdır.
      annotationOrder: const [],
      // Yerel atıf düğmesi sağ ÜSTTE: sağ alt kontrol sütununa ve sol alttaki atıf şeridine
      // binmesin. Görünür atıf şeridi (`HaritaAtfi`) ayrıca durur.
      attributionButtonPosition: AttributionButtonPosition.topRight,
      attributionButtonMargins: const Point(8, 8),
      attributionButtonColor: t.muted,
      foregroundLoadColor: t.surface2,
    );
  }
}

/// Katmanların renkleri — temadan okunur; tema değişince stil yeniden yüklenir ve katmanlar
/// yeni renklerle baştan kurulur.
class _KatmanRenkleri {
  const _KatmanRenkleri({
    required this.vurgu,
    required this.vurguUstu,
    required this.tamam,
    required this.sonuk,
    required this.yuzey,
    required this.metin,
  });

  factory _KatmanRenkleri.temadan(SipTokens t) => _KatmanRenkleri(
        vurgu: t.accent.toHexStringRGB(),
        vurguUstu: t.accentInk.toHexStringRGB(),
        tamam: t.ok.toHexStringRGB(),
        sonuk: t.muted.toHexStringRGB(),
        yuzey: t.surface.toHexStringRGB(),
        metin: t.ink.toHexStringRGB(),
      );

  final String vurgu, vurguUstu, tamam, sonuk, yuzey, metin;
}

/// Bir stil yüklemesine ait katmanlar. Durum (son yazılan içerik, işlem sırası) ve davranış
/// (kur, yaz) tek nesnede; stil yeniden yüklenince yenisi doğar, eskisi sessizce söner.
class _Katmanlar {
  _Katmanlar(this._k, this._r);

  final MapLibreMapController _k;
  final _KatmanRenkleri _r;

  static const _rota = 'sip-rota';
  static const _cihaz = 'sip-cihaz';
  static const _duraklar = 'sip-duraklar';
  static const _kuryeler = 'sip-kuryeler';
  static const _motor = 'sip-motor';

  /// Kaynak başına son yazılan GeoJSON metni — aynı veri ikinci kez motora gitmez.
  final Map<String, String> _son = {};
  Future<void> _sira = Future.value();
  bool _kuruldu = false;
  bool _birakildi = false;
  HaritaIcerigi? _bekleyen;

  /// Stil yeniden yüklendi: bu nesnenin sırada bekleyen işleri artık koşmaz.
  void birak() => _birakildi = true;

  /// İşlemi sıraya ekler. Motor hatası (ör. stil tam o anda değişti) YUTULUR: harita kırılmaz,
  /// bir sonraki stil yüklemesi her şeyi baştan kurar.
  Future<void> _sirala(Future<void> Function() is_) {
    _sira = _sira.then((_) => _birakildi ? null : is_()).catchError((Object e) {
      debugPrint('Harita katmanı güncellenemedi: $e');
    });
    return _sira;
  }

  Future<void> kur(HaritaIcerigi icerik) => _sirala(() async {
        await _k.addImage(_motor, await _motorGorseli());
        for (final kaynak in [_rota, _cihaz, _duraklar, _kuryeler]) {
          await _k.addGeoJsonSource(kaynak, _kaynakVerisi(kaynak, icerik));
          _son[kaynak] = jsonEncode(_kaynakVerisi(kaynak, icerik));
        }
        await _rotaKatmani();
        await _cihazKatmanlari();
        await _durakKatmanlari();
        await _kuryeKatmanlari();
        _kuruldu = true;
        final bekleyen = _bekleyen;
        _bekleyen = null;
        if (bekleyen != null) await _yaz(bekleyen);
      });

  /// Yeni içeriği yazar; kurulum bitmediyse en sonuncusunu saklar (aradakiler önemsiz).
  void icerikYaz(HaritaIcerigi icerik) {
    if (!_kuruldu) {
      _bekleyen = icerik;
      return;
    }
    unawaited(_sirala(() => _yaz(icerik)));
  }

  Future<void> _yaz(HaritaIcerigi icerik) async {
    for (final kaynak in [_rota, _cihaz, _duraklar, _kuryeler]) {
      final veri = _kaynakVerisi(kaynak, icerik);
      final metin = jsonEncode(veri);
      if (_son[kaynak] == metin) continue;
      await _k.setGeoJsonSource(kaynak, veri);
      _son[kaynak] = metin;
    }
  }

  static Map<String, dynamic> _kaynakVerisi(String kaynak, HaritaIcerigi i) => switch (kaynak) {
        _rota => i.rotaGeoJson,
        _cihaz => i.cihazGeoJson,
        _duraklar => i.duraklarGeoJson,
        _ => i.kuryelerGeoJson,
      };

  static const _secili = ['get', 'secili'];
  static const _taze = ['get', 'taze'];

  /// Kuş uçuşu rota — KESİKLİ, çünkü yol değil SIRA anlatır.
  Future<void> _rotaKatmani() => _k.addLineLayer(
        _rota,
        _rota,
        LineLayerProperties(
          lineColor: _r.vurgu,
          lineWidth: 3,
          lineOpacity: 0.55,
          lineDasharray: const [1.4, 1.6],
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );

  /// Cihaz: yumuşak hale + içi dolu nokta (numarasız — kurye bir durak değildir).
  Future<void> _cihazKatmanlari() async {
    await _k.addCircleLayer(
      _cihaz,
      '$_cihaz-hale',
      CircleLayerProperties(circleRadius: 16, circleColor: _r.tamam, circleOpacity: 0.18),
      enableInteraction: false,
    );
    await _k.addCircleLayer(
      _cihaz,
      _cihaz,
      CircleLayerProperties(
        circleRadius: 7,
        circleColor: _r.tamam,
        circleStrokeWidth: 3,
        circleStrokeColor: '#ffffff',
      ),
      enableInteraction: false,
    );
  }

  Future<void> _durakKatmanlari() async {
    // Seçili durağın halesi — özet sayfası açıkken hangi pine dokunulduğu haritada da görünür.
    await _k.addCircleLayer(
      _duraklar,
      '$_duraklar-hale',
      CircleLayerProperties(circleRadius: 27, circleColor: _r.vurgu, circleOpacity: 0.22),
      filter: const ['==', _secili, true],
      enableInteraction: false,
    );
    await _k.addCircleLayer(
      _duraklar,
      _duraklar,
      CircleLayerProperties(
        circleRadius: const ['case', _secili, 19, 15],
        circleColor: _r.vurgu,
        circleStrokeWidth: const ['case', _secili, 3, 2],
        circleStrokeColor: _r.vurguUstu,
        circleSortKey: const ['get', 'sira'],
      ),
    );
    await _k.addSymbolLayer(
      _duraklar,
      '$_duraklar-no',
      SymbolLayerProperties(
        textField: const ['to-string', ['get', 'no']],
        textFont: HaritaStili.yaziTipi,
        textSize: const ['case', _secili, 15, 13],
        textColor: _r.vurguUstu,
        // Numara HER ZAMAN çizilir (allow-overlap) ama çakışma hesabına KATILIR (ignore-placement
        // kapalı) ve dolgusu pinin dairesi kadardır: taban haritanın yer adları pinin altına
        // girmek yerine çekilir (emülatörde "Yıldırım" 2 numaranın altında kalıyordu).
        textAllowOverlap: true,
        textIgnorePlacement: false,
        textPadding: 12,
        symbolSortKey: const ['get', 'sira'],
      ),
    );
    // Müşteri adı YAKINLAŞINCA çıkar (sokak ölçeği): uzak ölçekte adlar birbirine biner ve
    // haritayı okunmaz kılar. Çakışan ad düşer, pin ve numara her zaman kalır.
    await _k.addSymbolLayer(
      _duraklar,
      '$_duraklar-ad',
      SymbolLayerProperties(
        textField: const ['get', 'ad'],
        textFont: HaritaStili.yaziTipi,
        textSize: 11.5,
        textColor: _r.metin,
        textHaloColor: _r.yuzey,
        textHaloWidth: 1.6,
        textAnchor: 'top',
        textOffset: const [0, 1.45],
        textMaxWidth: 9,
        symbolSortKey: const ['get', 'sira'],
      ),
      minzoom: 13.5,
      enableInteraction: false,
    );
  }

  /// Kurye: motor ikonlu daire + adı. Bayat konum SÖNÜK çizilir ve altına "X dk önce" yazar.
  Future<void> _kuryeKatmanlari() async {
    await _k.addCircleLayer(
      _kuryeler,
      _kuryeler,
      CircleLayerProperties(
        circleRadius: 15,
        circleColor: ['case', _taze, _r.vurgu, _r.sonuk],
        circleStrokeWidth: 2,
        circleStrokeColor: _r.vurguUstu,
      ),
    );
    await _k.addSymbolLayer(
      _kuryeler,
      '$_kuryeler-ikon',
      const SymbolLayerProperties(
        iconImage: _motor,
        iconSize: 0.25,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );
    await _k.addSymbolLayer(
      _kuryeler,
      '$_kuryeler-ad',
      SymbolLayerProperties(
        textField: const ['get', 'etiket'],
        textFont: HaritaStili.yaziTipi,
        textSize: 11,
        textColor: ['case', _taze, _r.metin, _r.sonuk],
        textHaloColor: _r.yuzey,
        textHaloWidth: 1.6,
        textAnchor: 'top',
        textOffset: const [0, 1.45],
        textAllowOverlap: true,
      ),
      enableInteraction: false,
    );
  }

  /// Lucide `bike` ikonunu PNG'ye çizer (72 px — 0.25 ölçekle ~18 dp). Kurye pininin eski
  /// widget hâliyle aynı şekil: ikon dili değişmez.
  static Future<Uint8List> _motorGorseli() async {
    const boyut = 72.0;
    final kaydedici = ui.PictureRecorder();
    final tuval = Canvas(kaydedici)..scale(boyut / 24);
    final firca = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (final d in kKuryeMotorYolu.split('|')) {
      tuval.drawPath(svgYoluCoz(d), firca);
    }
    final gorsel =
        await kaydedici.endRecording().toImage(boyut.toInt(), boyut.toInt());
    final veri = await gorsel.toByteData(format: ui.ImageByteFormat.png);
    gorsel.dispose();
    return veri!.buffer.asUint8List();
  }
}

/// [HaritaKamerasi]nın MapLibre karşılığı.
class _MapLibreKamerasi implements HaritaKamerasi {
  _MapLibreKamerasi(this._k, this.kenarBoslugu);

  final MapLibreMapController _k;
  EdgeInsets kenarBoslugu;

  static const _sure = Duration(milliseconds: 450);

  @override
  Future<void> yakinlastir(double fark) =>
      _k.animateCamera(CameraUpdate.zoomBy(fark), duration: const Duration(milliseconds: 250));

  @override
  Future<void> kadrajla(HaritaKadraji kadraj, {bool animasyon = true}) {
    final CameraUpdate hedef;
    if (kadraj.kutuMu) {
      final b = kenarBoslugu;
      hedef = CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(kadraj.guneyBati!.lat, kadraj.guneyBati!.lng),
          northeast: LatLng(kadraj.kuzeyDogu!.lat, kadraj.kuzeyDogu!.lng),
        ),
        left: b.left,
        top: b.top,
        right: b.right,
        bottom: b.bottom,
      );
    } else {
      hedef = CameraUpdate.newLatLngZoom(
        LatLng(kadraj.merkez!.lat, kadraj.merkez!.lng),
        kadraj.zoom!,
      );
    }
    return animasyon ? _k.animateCamera(hedef, duration: _sure) : _k.moveCamera(hedef);
  }

  @override
  Future<void> odakla(HaritaNoktasi nokta, double zoom) => _k.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(nokta.lat, nokta.lng), zoom),
        duration: _sure,
      );
}
