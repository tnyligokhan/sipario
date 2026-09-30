// HARİTA AD ÇİPİ — yakınlaşınca müşteri adı pinin sağında zeminli bir çipte (kullanıcı geri
// bildirimi 2026-09-29: "konumlandırması ve görünümü hoşuma gitmedi").
//
// Kilitlenen iki sözleşme: (1) ÇAPA DAİMA PİNİN MERKEZİDİR — ad açılıp kapanınca pin haritada
// yerinden oynamamalı, (2) uzun ad çipi komşu pinlerin üstüne uzatmaz, kısaltılır.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/orders/harita_ad_cipi.dart';
import 'package:sipario/screens/orders/harita_kurye_katmani.dart' show kKuryeMotorYolu;
import 'package:sipario/theme/tokens.dart';

/// Çizim fikstürü: temanın renkleri + yazı tipi yüklü bir ortamda pin/çip üretir.
class _CipOrtami {
  static const renkler = DurakCipRenkleri(
    vurgu: Color(0xFF3D5AFE),
    vurguUstu: Colors.white,
    yuzey: Colors.white,
    metin: Color(0xFF16151A),
    cizgi: Color(0xFFE6E4EC),
  );

  static Future<void> yaziTipiniYukle() async {
    final dosya = File('assets/fonts/HankenGrotesk.ttf');
    final yukleyici = FontLoader(sipFontBody)
      ..addFont(Future.value(dosya.readAsBytesSync().buffer.asByteData()));
    await yukleyici.load();
  }

  DurakAdCipi pin({int no = 3, String? ad, double dpr = 3}) =>
      DurakAdCipi(no: no, ad: ad, renkler: renkler, dpr: dpr);

  KuryeAdCipi kurye({bool taze = true, String ad = 'Ali', String ek = '', Color? renk}) =>
      KuryeAdCipi(
        taze: taze,
        motorYolu: kKuryeMotorYolu,
        ad: ad,
        ek: ek,
        renkler: renkler.pinRengiyle(renk),
        dpr: 3,
      );
}

void main() {
  final o = _CipOrtami();
  setUpAll(_CipOrtami.yaziTipiniYukle);

  group('ölçü ve çapa', () {
    test('adsız pin kare kalır, çapa ortadadır', () {
      final p = o.pin();
      expect(p.cipVar, isFalse);
      expect(p.genislik, p.pinKutusu);
      expect(p.capa.x, 0.5);
      expect(p.capa.y, 0.5);
    });

    test('boşluktan ibaret ad çip açmaz', () {
      expect(o.pin(ad: '   ').cipVar, isFalse);
    });

    test('⭐ adlı pinde çapa yine PİNİN MERKEZİ — görsel sağa genişler', () {
      final p = o.pin(ad: 'Ahmet Yılmaz');
      expect(p.genislik, greaterThan(p.pinKutusu));
      expect(p.capa.x * p.genislik, closeTo(p.pinKutusu / 2, 0.001),
          reason: 'ad açılıp kapanırken pin haritada kaymamalı');
      expect(p.capa.y, 0.5);
    });

    test('uzun ad kısaltılır, çip sınırsız uzamaz', () {
      final kisa = o.pin(ad: 'Ali');
      final uzun = o.pin(ad: 'Anadolu Su ve Tüp Dağıtım Sanayi Ticaret Limited Şirketi');
      expect(uzun.genislik, greaterThan(kisa.genislik));
      expect(uzun.genislik,
          lessThanOrEqualTo(16 + 15 + 7 + PinCipi.azamiAdGenisligi + 11 + 3 + 0.01));
    });
  });

  // 2026-09-29: "müşteri adını güncelledin fakat kuryeyi yapmamışsın" — kurye de aynı çipte.
  group('kurye çipi', () {
    test('kurye adı pinin sağında çipte, çapa pinin merkezi', () {
      final k = o.kurye(ad: 'Ali Kurye');
      expect(k.cipVar, isTrue);
      expect(k.capa.x * k.genislik, closeTo(k.pinKutusu / 2, 0.001));
    });

    test('bayat konumda süre çipin İÇİNDE, çip süre kadar uzar', () {
      final taze = o.kurye(ad: 'Veli');
      final bayat = o.kurye(ad: 'Veli', taze: false, ek: '12 dk önce');
      expect(bayat.sonuk, isTrue);
      expect(bayat.genislik, greaterThan(taze.genislik));
    });

    test('grup rengi yalnız pini boyar', () {
      final k = o.kurye(renk: const Color(0xFF0EA5E9));
      expect(k.renkler.vurgu, const Color(0xFF0EA5E9));
      expect(k.renkler.yuzey, _CipOrtami.renkler.yuzey);
    });
  });

  group('görsel', () {
    test('görsel ölçüsü yoğunlukla çarpılır', () async {
      final p = o.pin(ad: 'Ayşe Demir', dpr: 2.5);
      final resim = await p.ciz();
      expect(resim.width, (p.genislik * 2.5).ceil());
      expect(resim.height, (p.yukseklik * 2.5).ceil());
    });

    test('çipin gövdesi dolu, pinin solundaki boşluk saydam', () async {
      final p = o.pin(ad: 'Ayşe Demir', dpr: 1);
      final resim = await p.ciz();
      final veri = (await resim.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int alfa(double x, double y) =>
          veri.getUint8(((y.round() * resim.width) + x.round()) * 4 + 3);

      final orta = p.yukseklik / 2;
      expect(alfa(p.genislik - 8, orta), greaterThan(200), reason: 'çipin sağ ucu çizilmeli');
      expect(alfa(1, 1), 0, reason: 'pin kutusunun köşesi saydam kalmalı');
    });

    // Gözle inceleme (ekranı golden PNG ile gözle incele): SIPARIO_PNG ortam değişkeni
    // verilirse pin çeşitleri o klasöre yazılır. CI'da koşmaz.
    test('PNG dökümü (isteğe bağlı)', () async {
      final klasor = Platform.environment['SIPARIO_PNG'];
      if (klasor == null) return;
      final ornekler = {
        'adsiz': o.pin(),
        'adli': o.pin(ad: 'Ahmet Yılmaz'),
        'uzun': o.pin(ad: 'Anadolu Su ve Tüp Dağıtım Sanayi Ticaret', no: 104),
        'kurye': o.kurye(ad: 'Ali Kurye', renk: const Color(0xFF0EA5E9)),
        'kurye_bayat': o.kurye(ad: 'Veli', taze: false, ek: '12 dk önce'),
      };
      for (final e in ornekler.entries) {
        final resim = await e.value.ciz();
        final png = await resim.toByteData(format: ui.ImageByteFormat.png);
        File('$klasor/pin_${e.key}.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  });
}
