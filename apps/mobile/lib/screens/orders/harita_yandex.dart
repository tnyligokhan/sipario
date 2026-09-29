// YANDEX MAPKIT TUVALİ — sipariş haritasının yerel motoru (kullanıcı kararı 2026-09-28).
//
// Resmî `yandex_maps_mapkit_lite` paketi. Harita Yandex'in vektör haritasıdır: her yakınlıkta
// keskin, yer adları Türkçe (`tr_TR` yerel ayarı), koyu temada gece modu.
//
// PİNLER MOTORUN NESNELERİDİR (placemark), Flutter widget'ı değil: haritayla birlikte kayar,
// titremez. Görselleri `dart:ui` ile çizilir ve anahtarıyla önbelleklenir ([_Ikonlar]).
//
// ⚠️ DİNLEYİCİLER GÜÇLÜ REFERANSLA TUTULUR: MapKit dokunuş ve kamera dinleyicilerini ZAYIF
// referansla saklar. Yerel bir değişkene verilen dinleyici çöp toplayıcıyla silinir ve dokunuşlar
// sessizce çalışmayı bırakır — bu yüzden dinleyiciler alanlarda durur.
//
// ⚠️ ANAHTAR: MapKit API anahtarı derlemeye `--dart-define=YANDEX_MAPKIT_KEY=...` ile verilir
// (CI: `secrets.YANDEX_MAPKIT_KEY`). Anahtarsız derlemede harita açılmaz ve ekran SEBEBİ yazar
// — "yükleniyor"da donan bir ekran bu depoda defalarca ödendi.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/image.dart' as yimg;
import 'package:yandex_maps_mapkit_lite/init.dart' as yinit;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as y;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart' as yf;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart' as ymap;

import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/svg_path.dart';
import '../../theme/tokens.dart';
import 'harita_icerigi.dart';
import 'harita_kurye_katmani.dart' show kKuryeMotorYolu;
import 'harita_tuvali.dart';

/// MapKit'in tek seferlik kurulumu ve açık harita sayacı (onStart/onStop).
abstract final class YandexHaritaMotoru {
  /// Derleme anahtarı. Boşsa harita kurulmaz (bkz. dosya başlığı).
  static const String anahtar = String.fromEnvironment('YANDEX_MAPKIT_KEY');

  /// Yer adları ve arayüz Türkçe.
  static const String yerelAyar = 'tr_TR';

  static Future<bool>? _kurulum;
  static int _acik = 0;

  /// MapKit hazır mı? İlk çağrı kurar, sonrakiler aynı sonucu bekler. ASLA fırlatmaz.
  static Future<bool> hazirla() => _kurulum ??= _kur();

  static Future<bool> _kur() async {
    if (anahtar.isEmpty) return false;
    try {
      await yinit.initMapkit(apiKey: anahtar, locale: yerelAyar);
      return true;
    } on Object catch (e) {
      debugPrint('Yandex MapKit kurulamadı: $e');
      return false;
    }
  }

  /// Bir harita görünür oldu. MapKit, onStart çağrılmadan karo yüklemez.
  static void basla() {
    if (_acik++ == 0) yf.mapkit.onStart();
  }

  /// Bir harita gizlendi; son harita da gidince MapKit durur (pil ve veri).
  static void bitir() {
    if (_acik == 0) return;
    if (--_acik == 0) yf.mapkit.onStop();
  }
}

/// Bir haritanın MapKit yaşam döngüsü: kurulum sonucu + görünürlük → onStart/onStop.
///
/// TEK KURAL: "hazır VE görünür VE kapanmamış" ⇔ başlamış. Her olayda bu kurala EŞİTLENİR;
/// olayların sırası sonucu değiştirmez. Saha arızası (2026-09-29, "sadece boş karolar"): önceki
/// kod başlatmayı `_hazir = true` atamasından ÖNCE deniyor, koşul yanlış çıkıyor ve onStart hiç
/// çağrılmıyordu — MapKit onStart görmeden karo indirmez, ekranda boş ızgara kalır.
class HaritaYasami {
  HaritaYasami({required void Function() basla, required void Function() bitir})
      : _basla = basla,
        _bitir = bitir;

  final void Function() _basla;
  final void Function() _bitir;

  bool? _hazir;
  bool _gorunur = true; // harita ekranı açılırken görünürdür
  bool _kapandi = false;
  bool _basladi = false;

  /// null = kuruluyor, false = kurulamadı (anahtar yok), true = hazır.
  bool? get hazir => _hazir;
  bool get basladi => _basladi;

  void hazirlandi(bool ok) {
    _hazir = ok;
    _esitle();
  }

  void gorunurluk(bool acik) {
    _gorunur = acik;
    _esitle();
  }

  void kapat() {
    _kapandi = true;
    _esitle();
  }

  void _esitle() {
    final olmali = _hazir == true && _gorunur && !_kapandi;
    if (olmali && !_basladi) {
      _basla();
      _basladi = true;
    } else if (!olmali && _basladi) {
      _bitir();
      _basladi = false;
    }
  }
}

/// Üretim tuvali.
class YandexTuvali extends StatefulWidget {
  const YandexTuvali(this.ayar, {super.key});

  final HaritaTuvaliAyari ayar;

  @override
  State<YandexTuvali> createState() => _YandexTuvaliState();
}

class _YandexTuvaliState extends State<YandexTuvali> {
  final HaritaYasami _dongu = HaritaYasami(
    basla: YandexHaritaMotoru.basla,
    bitir: YandexHaritaMotoru.bitir,
  );

  /// Uygulama arka plana geçince MapKit durur, öne gelince sürer.
  late final AppLifecycleListener _yasam = AppLifecycleListener(
    onHide: () => _dongu.gorunurluk(false),
    onShow: () => _dongu.gorunurluk(true),
  );

  y.MapWindow? _pencere;
  _Cizici? _cizici;
  _YandexKamerasi? _kamera;
  bool _hazirBildirildi = false;
  late _Renkler _renkler;

  @override
  void initState() {
    super.initState();
    _yasam; // dinleyiciyi kur
    unawaited(YandexHaritaMotoru.hazirla().then((ok) {
      if (!mounted) return;
      setState(() => _dongu.hazirlandi(ok));
    }));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _renkler = _Renkler.temadan(context.sip);
  }

  @override
  void didUpdateWidget(YandexTuvali eski) {
    super.didUpdateWidget(eski);
    final cizici = _cizici;
    if (cizici == null) return;
    if (eski.ayar.koyu != widget.ayar.koyu) {
      _pencere?.map.nightModeEnabled = widget.ayar.koyu;
      cizici.temaDegisti(_renkler);
    }
    _kamera?.kenarBoslugu = widget.ayar.kenarBoslugu;
    cizici.ciz(widget.ayar.icerik);
  }

  @override
  void dispose() {
    _yasam.dispose();
    _dongu.kapat();
    _cizici?.birak();
    super.dispose();
  }

  void _kuruldu(y.MapWindow pencere) {
    _pencere = pencere;
    final harita = pencere.map
      ..nightModeEnabled = widget.ayar.koyu
      // Döndürme ve eğme KAPALI: kuzey hep yukarıda. Kurye haritayı "sıradaki durak nerede"
      // diye okur; dönmüş bir harita bu soruyu zorlaştırır.
      ..rotateGesturesEnabled = false
      ..tiltGesturesEnabled = false;
    // Yandex logosu lisans gereği görünür kalır — SOL ÜSTE alınır: sağ alt köşede kontrol
    // sütunu, alt ortada "Oto Sırala" durur.
    harita.logo
      ..setAlignment(const y.LogoAlignment(
          y.LogoHorizontalAlignment.Left, y.LogoVerticalAlignment.Top))
      ..setPadding(const y.LogoPadding(horizontalPadding: 12, verticalPadding: 12));

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cizici = _Cizici(
      harita: harita,
      renkler: _renkler,
      dpr: dpr,
      onDokunus: (id) {
        final d = HaritaDokunusu.coz(id);
        if (d != null) widget.ayar.onDokunus(d);
      },
    )..ciz(widget.ayar.icerik);
    _cizici = cizici;
    _kamera = _YandexKamerasi(pencere, widget.ayar.kenarBoslugu, dpr);
    _ilkKadraj();
  }

  /// Pencere ölçüsünü almadan kadraj hesaplanamaz (odak dikdörtgeni boş olur) — ölçü gelene
  /// dek kareler beklenir, sonra kadraja ANİMASYONSUZ oturulur ve kamera ekrana verilir.
  void _ilkKadraj([int deneme = 0]) {
    final pencere = _pencere, kamera = _kamera;
    if (!mounted || pencere == null || kamera == null || _hazirBildirildi) return;
    if ((pencere.width() == 0 || pencere.height() == 0) && deneme < 30) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ilkKadraj(deneme + 1));
      return;
    }
    final kadraj = widget.ayar.icerik.kadraj;
    if (kadraj != null) unawaited(kamera.kadrajla(kadraj, animasyon: false));
    _hazirBildirildi = true;
    widget.ayar.onHazir(kamera);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return switch (_dongu.hazir) {
      null => ColoredBox(color: t.surface2),
      false => ColoredBox(
          color: t.surface2,
          child: const Center(
            child: SingleChildScrollView(
              child: SipBosDurum(
                ikon: SipIcons.pin,
                baslik: 'Harita açılamadı',
                aciklama: 'Bu sürümde harita anahtarı tanımlı değil. Uygulamayı güncelleyin; '
                    'sorun sürerse destekle iletişime geçin.',
              ),
            ),
          ),
        ),
      true => ymap.YandexMap(
          onMapCreated: _kuruldu,
          // Harita kendi hareketlerini ALIR: üstündeki düğmeler kardeştir, ata değil.
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
          },
        ),
    };
  }
}

/// Temadan okunan renkler — tema değişince pin görselleri yeniden çizilir.
class _Renkler {
  const _Renkler({
    required this.vurgu,
    required this.vurguUstu,
    required this.tamam,
    required this.sonuk,
    required this.yuzey,
    required this.metin,
  });

  factory _Renkler.temadan(SipTokens t) => _Renkler(
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
class _Cizici {
  _Cizici({
    required y.Map harita,
    required _Renkler renkler,
    required double dpr,
    required void Function(String id) onDokunus,
  })  : _harita = harita,
        _ikonlar = _Ikonlar(renkler, dpr),
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
  _Ikonlar _ikonlar;
  _Renkler _renkler;

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
  HaritaIcerigi _icerik = const HaritaIcerigi();
  bool _adlarAcik = false;
  bool _birakildi = false;

  void birak() {
    if (_birakildi) return;
    _birakildi = true;
    _harita.removeCameraListener(_kamera);
    _kok.removeTapListener(_dokunus);
  }

  void temaDegisti(_Renkler renkler) {
    _renkler = renkler;
    _ikonlar = _Ikonlar(renkler, _ikonlar.dpr);
    _durakIkonu.clear();
    _kuryeIkonu.clear();
    _cihaz?.setIcon(_ikonlar.cihaz());
    _rota?.setStrokeColor(renkler.vurgu.withValues(alpha: 0.6));
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
    _rotayiCiz(icerik);
    _cihaziCiz(icerik);
    _duraklariCiz(icerik);
    _kuryeleriCiz(icerik);
  }

  /// Kuş uçuşu rota — KESİKLİ, çünkü yol değil SIRA anlatır. Pinlerin ALTINDA.
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
class _Ikonlar {
  _Ikonlar(this._r, this.dpr);

  final _Renkler _r;
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

/// [HaritaKamerasi]nın MapKit karşılığı.
class _YandexKamerasi implements HaritaKamerasi {
  _YandexKamerasi(this._pencere, this.kenarBoslugu, this._dpr);

  final y.MapWindow _pencere;
  final double _dpr;
  EdgeInsets kenarBoslugu;

  /// Sığdırma bu yakınlıktan öteye gitmez: iki komşu durak kamerayı kapı ölçeğine sokmasın.
  static const double enYakin = 17;

  static const _yumusak = y.Animation(type: y.AnimationType.Smooth, duration: 0.45);

  y.Map get _harita => _pencere.map;

  static y.CameraPosition _konum(y.Point hedef, double zoom) =>
      y.CameraPosition(hedef, zoom: zoom, azimuth: 0, tilt: 0);

  @override
  Future<void> yakinlastir(double fark) async {
    final simdi = _harita.cameraPosition;
    _harita.move(
      _konum(simdi.target, (simdi.zoom + fark).clamp(3.0, 19.0)),
      animation: const y.Animation(type: y.AnimationType.Smooth, duration: 0.25),
    );
  }

  /// Düğmelerin kapladığı kenarlar dışarıda kalan odak dikdörtgeni (fiziksel piksel).
  y.ScreenRect? _odak() {
    final w = _pencere.width().toDouble(), h = _pencere.height().toDouble();
    final b = kenarBoslugu;
    final sag = w - b.right * _dpr, alt = h - b.bottom * _dpr;
    final sol = b.left * _dpr, ust = b.top * _dpr;
    if (sag - sol < 50 || alt - ust < 50) return null; // pencere çok küçük: tümünü kullan
    return y.ScreenRect(y.ScreenPoint(x: sol, y: ust), y.ScreenPoint(x: sag, y: alt));
  }

  @override
  Future<void> kadrajla(HaritaKadraji kadraj, {bool animasyon = true}) async {
    y.CameraPosition hedef;
    if (kadraj.kutuMu) {
      final gb = kadraj.guneyBati!, kd = kadraj.kuzeyDogu!;
      final hesap = _harita.cameraPositionForGeometry(
        y.Geometry.fromBoundingBox(y.BoundingBox(
          y.Point(latitude: gb.lat, longitude: gb.lng),
          y.Point(latitude: kd.lat, longitude: kd.lng),
        )),
        focusRect: _odak(),
        azimuth: 0,
        tilt: 0,
      );
      hedef = _konum(hesap.target, math.min(hesap.zoom, enYakin));
    } else {
      final m = kadraj.merkez!;
      hedef = _konum(y.Point(latitude: m.lat, longitude: m.lng), kadraj.zoom!);
    }
    _harita.move(hedef, animation: animasyon ? _yumusak : const y.Animation());
  }

  @override
  Future<void> odakla(HaritaNoktasi nokta, double zoom) async => _harita.move(
        _konum(y.Point(latitude: nokta.lat, longitude: nokta.lng), zoom),
        animation: _yumusak,
      );
}
