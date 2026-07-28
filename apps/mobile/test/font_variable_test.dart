// Değişken (variable) font ağırlıklarının GERÇEKTEN uygulandığını doğrular.
//
// Neden ayrı bir test: Sora ve Hanken Grotesk tek dosyada tüm ağırlıkları taşıyan değişken
// fontlardır. `fontWeight` tek başına verilirse Flutter bunu bir DOSYA seçimi olarak yorumlar;
// aile için tek dosya kayıtlı olduğundan hepsi aynı ağırlıkta çizilir ve tipografi tamamen
// düzleşir. Ağırlığın gerçekten değişmesi `fontVariations: [FontVariation('wght', N)]`
// eksenine bağlıdır.
//
// Bu bozukluk widget testlerinde görünmez (test ortamı varsayılan olarak sahte font kullanır) ve
// yalnız cihazda fark edilir. O yüzden burada gerçek TTF'leri yükleyip aynı metni farklı
// ağırlıklarda ölçüyoruz: genişlikler birbirine eşitse eksen uygulanmıyordur.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/theme/tokens.dart';
import 'package:sipario/theme/typography.dart';

Future<void> _fontYukle(String aile, String yol) async {
  final dosya = File(yol);
  if (!dosya.existsSync()) {
    fail('Font bulunamadı: $yol — pubspec.yaml ile assets/fonts uyuşmuyor.');
  }
  final yukleyici = FontLoader(aile)
    ..addFont(Future.value(dosya.readAsBytesSync().buffer.asByteData()));
  await yukleyici.load();
}

double _genislik(String metin, TextStyle stil) {
  final tp = TextPainter(
    text: TextSpan(text: metin, style: stil),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _fontYukle(sipFontDisplay, 'assets/fonts/Sora.ttf');
    await _fontYukle(sipFontBody, 'assets/fonts/HankenGrotesk.ttf');
  });

  TextStyle stil(String aile, int agirlik, {bool eksen = true}) => TextStyle(
        fontFamily: aile,
        fontSize: 40,
        fontWeight: FontWeight.values.firstWhere((w) => w.value == agirlik),
        fontVariations:
            eksen ? [ui.FontVariation('wght', agirlik.toDouble())] : null,
      );

  group('Değişken font ekseni', () {
    test('Sora: wght ekseni harf genişliğini gerçekten değiştiriyor', () {
      const ornek = 'ÖRNEK 1.234,50 ₺';
      final ince = _genislik(ornek, stil(sipFontDisplay, 400));
      final kalin = _genislik(ornek, stil(sipFontDisplay, 800));
      expect(ince, greaterThan(0));
      expect(
        kalin,
        greaterThan(ince),
        reason: 'wght ekseni uygulanmıyor — 800 ağırlık 400 ile aynı genişlikte '
            'çiziliyor. typography.dart içindeki fontVariations kaybolmuş olabilir.',
      );
    });

    test('Hanken Grotesk: wght ekseni harf genişliğini gerçekten değiştiriyor', () {
      const ornek = 'Müşteri defteri';
      final ince = _genislik(ornek, stil(sipFontBody, 400));
      final kalin = _genislik(ornek, stil(sipFontBody, 800));
      expect(kalin, greaterThan(ince), reason: 'wght ekseni uygulanmıyor.');
    });

    test('SipText stilleri wght EKSENİNİ taşır — asıl güvence budur', () {
      // ESKİ TESTİN YERİNE (2026-07-29). Burada bir "kontrol grubu" testi vardı:
      // fontVariations verilmezse 400 ile 800 AYNI genişlikte çıkmalı, çıkmazsa yukarıdaki
      // iki test bir şey kanıtlamıyor demekti. O varsayım ARTIK DOĞRU DEĞİL ve test bu
      // yüzden kırmızıydı (kalite kapısını kilitleyip otomatik commit'i durduruyordu).
      //
      // ÖLÇÜLDÜ (Flutter 3.44.6, Sora.ttf, 40 punto, 'ÖRNEK 1.234,50 ₺'):
      //     eksenli 400: 367,64   ·   eksenli 800: 379,72
      //     eksensiz 400: 367,64  ·   eksensiz 800: 379,72   ·   eksensiz 100: 356,20
      // Yani motor artık `fontWeight`i değişken fontun wght eksenine KENDİ eşliyor; dört
      // ölçüm birebir aynı. Ürün tarafında bozuk bir şey yok — değişen çerçevedir.
      //
      // Ders: bir testin dayanağı ÇERÇEVENİN O ANKİ DAVRANIŞI ise, çerçeve güncellendiğinde
      // ürün sağlamken test kırmızıya döner. Güvence artık DAVRANIŞA değil SÖZLEŞMEYE bakıyor:
      // `fontVariations`ı kaldırmak eski motorlarda (ve mağazadaki eski cihazlarda) tipografiyi
      // düzleştirir, o yüzden eksen stillerde AÇIKÇA durmak zorundadır.
      final stiller = <String, TextStyle>{
        'satirAd': SipText.satirAd,
        'satirTel': SipText.satirTel,
        'bentoDeger': SipText.bentoDeger,
        'satirTutarBuyuk': SipText.satirTutarBuyuk,
        'pil': SipText.pil,
        'metin(13, w:700)': SipText.metin(13, w: 700),
      };
      stiller.forEach((ad, s) {
        expect(s.fontVariations, isNotNull, reason: '$ad: wght ekseni yok');
        final wght = s.fontVariations!.firstWhere((v) => v.axis == 'wght');
        expect(wght.value, s.fontWeight!.value.toDouble(),
            reason: '$ad: eksen değeri fontWeight ile uyuşmuyor');
      });
    });
  });

  group('Gerçek stiller cihazda ayrışıyor', () {
    test('SipText ağırlık basamakları farklı genişlik üretir', () {
      const ornek = 'Ahmet Yılmaz';
      // satirTel (500) < satirAd (700) — tasarımdaki hiyerarşi ölçülebilir olmalı.
      final normal = _genislik(ornek, SipText.satirTel.copyWith(fontSize: 40));
      final kalin = _genislik(ornek, SipText.satirAd.copyWith(fontSize: 40));
      expect(kalin, greaterThan(normal));
    });

    test('tutarlar TABULAR — rakam genişlikleri eşit', () {
      // Tabular rakamda "111,11" ile "888,88" aynı genişlikte olmalı; olmazsa defterdeki
      // kuruş sütunu satır satır kayar.
      final dar = _genislik('111,11 ₺', SipText.satirTutar);
      final genis = _genislik('888,88 ₺', SipText.satirTutar);
      expect(dar, closeTo(genis, 0.01));
    });

    test('rakam stilleri Sora, gövde stilleri Hanken — ölçülebilir fark', () {
      const ornek = '1234567890';
      final sora = _genislik(ornek, SipText.tutar22);
      final hanken =
          _genislik(ornek, SipText.govde.copyWith(fontSize: 22, fontWeight: FontWeight.w800));
      // İki aile aynı metni aynı puntoda farklı genişlikte çizer; eşitse biri yüklenmemiştir.
      expect(sora, isNot(closeTo(hanken, 0.5)));
    });
  });

  group('Yerleşim güvenliği', () {
    test('en uzun gerçekçi tutar bento kutusuna sığar', () {
      // Bento kutusu 412 px ekranda iki sütun, 10 px boşluk, 16 px iç boşluk → ~168 px içerik.
      // 40 punto rakam bu genişliği aşarsa tasarım küçük varyanta düşmeli (bentoDegerKucuk).
      final buyuk = _genislik('99.999,00 ₺', SipText.bentoDeger);
      expect(
        buyuk,
        greaterThan(168),
        reason: 'Beklenti: büyük tutarlar 40 puntoda taşar; bu yüzden ekranlar '
            'bentoDegerKucuk varyantına düşmek zorunda. Taşmıyorsa varsayım değişmiş.',
      );
      final kucuk = _genislik('99.999,00 ₺', SipText.bentoDegerKucuk);
      expect(kucuk, lessThan(168));
    });
  });
}
