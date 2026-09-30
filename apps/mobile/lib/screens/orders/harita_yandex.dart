// YANDEX MAPKIT TUVALİ — sipariş haritasının yerel motoru (kullanıcı kararı 2026-09-28).
//
// Resmî `yandex_maps_mapkit_lite` paketi. Harita Yandex'in vektör haritasıdır: her yakınlıkta
// keskin, yer adları Türkçe (`tr_TR` yerel ayarı), koyu temada gece modu.
//
// PİNLER MOTORUN NESNELERİDİR (placemark), Flutter widget'ı değil: haritayla birlikte kayar,
// titremez. Nesnelerin içerikle eşitlenmesi ve pin görselleri `harita_yandex_cizici.dart`ta;
// bu dosya motorun kurulumu, yaşam döngüsü, tuval ve kamera.
//
// ⚠️ ANAHTAR: MapKit API anahtarı derlemeye `--dart-define=YANDEX_MAPKIT_KEY=...` ile verilir
// (CI: `secrets.YANDEX_MAPKIT_KEY`). Anahtarsız derlemede harita açılmaz ve ekran SEBEBİ yazar
// — "yükleniyor"da donan bir ekran bu depoda defalarca ödendi.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/init.dart' as yinit;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as y;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart' as yf;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart' as ymap;

import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import 'harita_icerigi.dart';
import 'harita_tuvali.dart';
import 'harita_yandex_cizici.dart';

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
  YandexCizici? _cizici;
  _YandexKamerasi? _kamera;
  bool _hazirBildirildi = false;
  late YandexRenkler _renkler;

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
    _renkler = YandexRenkler.temadan(context.sip);
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
    final cizici = YandexCizici(
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

  @override
  Future<void> gorunurAlanaAl(HaritaNoktasi nokta, {required double ortulenOran}) async {
    final w = _pencere.width().toDouble(), h = _pencere.height().toDouble();
    if (w == 0 || h == 0) return;
    // Görünen bölge (fiziksel piksel): üstte kişi şeridi, altta sayfa, kenarlarda pin payı.
    final pay = 40 * _dpr;
    final ust = kenarBoslugu.top * _dpr + pay;
    final alt = h * (1 - ortulenOran) - pay;
    if (alt <= ust) return; // sayfa ekranı neredeyse tümüyle örtüyor: kaydırmak işe yaramaz
    final hedef = y.Point(latitude: nokta.lat, longitude: nokta.lng);
    final ekran = _pencere.worldToScreen(hedef);
    if (ekran != null &&
        ekran.x >= pay &&
        ekran.x <= w - pay &&
        ekran.y >= ust &&
        ekran.y <= alt) {
      return;
    }
    // Kamera hedefi ekranın ortasındadır (pencerede odak dikdörtgeni yok). Pinin görünen
    // bölgenin ortasına oturması için hedef, pinden (h/2 − bölge ortası) piksel AŞAĞIDA olmalı.
    // Piksel başına enlem yerel olarak ölçülür: şehir ölçeğinde doğrusal yaklaşım yeterli.
    final simdi = _harita.cameraPosition;
    final a = _pencere.screenToWorld(y.ScreenPoint(x: w / 2, y: h / 2));
    final b = _pencere.screenToWorld(y.ScreenPoint(x: w / 2, y: h / 2 + 100));
    if (a == null || b == null) return;
    final enlemPiksel = (b.latitude - a.latitude) / 100;
    final kayma = h / 2 - (ust + alt) / 2;
    _harita.move(
      _konum(
        y.Point(latitude: nokta.lat + kayma * enlemPiksel, longitude: nokta.lng),
        simdi.zoom,
      ),
      animation: _yumusak,
    );
  }
}
