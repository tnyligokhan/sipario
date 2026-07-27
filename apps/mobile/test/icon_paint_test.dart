// İkonların GERÇEKTEN BOYANDIĞINI kanıtlar.
//
// Neden ayrı bir test: `ui_temel_test.dart` yolların AYRIŞTIĞINI (Path uzunluğu > 0) ve
// widget'ın çökmediğini sınıyor. İkisi de doğru olduğu hâlde ekrana tek piksel düşmeyebilir —
// örneğin CustomPaint sıfır boyut alırsa ölçek 0 olur ve çizim sessizce kaybolur. Bu tür bir
// hata testlerden geçer, yalnız cihazda görülür. Burada gerçekten piksel sayıyoruz.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/theme/icons.dart';

/// Widget'ı [boyut] karesine çizip beyaz OLMAYAN piksel sayısını döndürür.
Future<int> _boyananPiksel(WidgetTester tester, Widget widget, double boyut) async {
  final anahtar = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Center(
          child: RepaintBoundary(
            key: anahtar,
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: SizedBox.square(dimension: boyut, child: widget),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final sinir =
      anahtar.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // toImage() GERÇEK async'tir — sahte zaman altında asılı kalır, runAsync şart.
  late Uint8List baytlar;
  await tester.runAsync(() async {
    final resim = await sinir.toImage();
    final veri = await resim.toByteData(format: ui.ImageByteFormat.rawRgba);
    baytlar = veri!.buffer.asUint8List();
  });

  var sayac = 0;
  for (var i = 0; i < baytlar.length; i += 4) {
    final r = baytlar[i], g = baytlar[i + 1], b = baytlar[i + 2], a = baytlar[i + 3];
    // Beyaz zeminden belirgin biçimde ayrışan her piksel "boyanmış" sayılır.
    if (a > 8 && (r < 240 || g < 240 || b < 240)) sayac++;
  }
  return sayac;
}

void main() {
  group('SipIcon gerçekten boyanıyor', () {
    testWidgets('tek ikon beyaz zemine piksel düşürür', (tester) async {
      final piksel = await _boyananPiksel(
        tester,
        const SipIcon(SipIcons.menu, boyut: 48, renk: Color(0xFF000000)),
        48,
      );
      expect(
        piksel,
        greaterThan(50),
        reason: 'menu ikonu (üç yatay çizgi) 48 pikselde en az birkaç yüz piksel '
            'boyamalı. 0 çıkıyorsa CustomPaint boyut alamıyor ve ölçek 0 oluyordur.',
      );
    });

    testWidgets('setteki HER ikon boyanıyor — hem ANAHTAR hem PATH ile çağrılınca',
        (tester) async {
      // Tüm set TEK karede bir ızgaraya çizilir ve hücre hücre denetlenir. İkonu tek tek
      // görüntüye çevirmek (44 × toImage) dakikalar sürüyordu; tek yakalama saniyeler.
      const hucre = 40.0;
      const sutun = 8;
      final adlar = SipIcons.hepsi.keys.toList();

      // Yarısı ANAHTARLA ('menu'), yarısı PATH ile (SipIcons.menu) çağrılır — ikisi de
      // desteklenmeli. Path ile çağrı gerçek kod tabanındaki baskın biçim.
      final cocuklar = <Widget>[
        for (var i = 0; i < adlar.length; i++)
          SizedBox.square(
            dimension: hucre,
            child: Center(
              child: SipIcon(
                i.isEven ? adlar[i] : SipIcons.hepsi[adlar[i]]!,
                boyut: 32,
                kalinlik: 2.4,
                renk: const Color(0xFF000000),
              ),
            ),
          ),
      ];

      final satir = (adlar.length + sutun - 1) ~/ sutun;
      final anahtar = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: anahtar,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: SizedBox(
                  width: hucre * sutun,
                  height: hucre * satir,
                  child: Wrap(children: cocuklar),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final sinir =
          anahtar.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late Uint8List baytlar;
      late int genislik;
      late int yukseklik;
      await tester.runAsync(() async {
        final resim = await sinir.toImage();
        final veri = await resim.toByteData(format: ui.ImageByteFormat.rawRgba);
        baytlar = veri!.buffer.asUint8List();
        genislik = resim.width;
        yukseklik = resim.height;
      });
      final olcek = genislik / (hucre * sutun); // devicePixelRatio

      final bos = <String>[];
      for (var i = 0; i < adlar.length; i++) {
        final sx = ((i % sutun) * hucre * olcek).round();
        final sy = ((i ~/ sutun) * hucre * olcek).round();
        final boy = (hucre * olcek).round();
        var sayac = 0;
        for (var y = sy; y < sy + boy && y < yukseklik; y++) {
          for (var x = sx; x < sx + boy && x < genislik; x++) {
            final p = (y * genislik + x) * 4;
            if (baytlar[p] < 200 && baytlar[p + 1] < 200 && baytlar[p + 2] < 200) {
              sayac++;
            }
          }
        }
        if (sayac < 15) {
          bos.add('${adlar[i]} (${i.isEven ? "anahtar" : "path"}, $sayac px)');
        }
      }
      expect(bos, isEmpty, reason: 'şu ikonlar ekrana çizilmiyor: ${bos.join(", ")}');
    });

    testWidgets('renk gerçekten uygulanıyor (mor ikon mor piksel üretir)', (tester) async {
      final anahtar = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: anahtar,
                child: const ColoredBox(
                  color: Color(0xFFFFFFFF),
                  child: SizedBox.square(
                    dimension: 48,
                    child: SipIcon(SipIcons.check, boyut: 48, renk: Color(0xFF5A45F0)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sinir =
          anahtar.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late Uint8List baytlar;
      await tester.runAsync(() async {
        final veri = await (await sinir.toImage())
            .toByteData(format: ui.ImageByteFormat.rawRgba);
        baytlar = veri!.buffer.asUint8List();
      });

      var morVar = false;
      for (var i = 0; i < baytlar.length; i += 4) {
        final r = baytlar[i], g = baytlar[i + 1], b = baytlar[i + 2];
        // #5A45F0 → mavi baskın, yeşil düşük.
        if (b > 150 && g < 120 && r < 160) {
          morVar = true;
          break;
        }
      }
      expect(morVar, isTrue, reason: 'ikon vurgu renginde çizilmedi');
    });

    testWidgets('DefaultTextStyle renginden miras alır (hero üstünde beyaza döner)',
        (tester) async {
      final anahtar = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: anahtar,
                child: const ColoredBox(
                  color: Color(0xFF17141F), // hero
                  child: DefaultTextStyle(
                    style: TextStyle(color: Color(0xFFFFFFFF)),
                    child: SizedBox.square(
                      dimension: 48,
                      child: SipIcon(SipIcons.menu, boyut: 48),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sinir =
          anahtar.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late Uint8List baytlar;
      await tester.runAsync(() async {
        final veri = await (await sinir.toImage())
            .toByteData(format: ui.ImageByteFormat.rawRgba);
        baytlar = veri!.buffer.asUint8List();
      });

      var acikPiksel = 0;
      for (var i = 0; i < baytlar.length; i += 4) {
        if (baytlar[i] > 200 && baytlar[i + 1] > 200 && baytlar[i + 2] > 200) {
          acikPiksel++;
        }
      }
      expect(acikPiksel, greaterThan(50),
          reason: 'hero üstünde ikon beyaz çizilmeli (renk mirası kopmuş olabilir)');
    });
  });
}
