// Tasarım sistemi TEMEL katmanı testleri (SİPARİO 3.0).
// Buradaki testler ekranlardan bağımsızdır: jetonlar, tipografi, SVG ikon ayrıştırıcısı ve
// paylaşılan atomlar. Bir ekran bozulduğunda hatanın temelden mi geldiğini bu dosya ayırt eder.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/components/states.dart';
import 'package:sipario/theme/icons.dart';
import 'package:sipario/theme/svg_path.dart';
import 'package:sipario/theme/tokens.dart';
import 'package:sipario/theme/typography.dart';

Widget _sar(Widget child, {bool koyu = false}) => MaterialApp(
      theme: koyu ? SipTheme.koyu() : SipTheme.acik(),
      home: Scaffold(body: child),
    );

void main() {
  group('Jetonlar', () {
    test('açık tema tasarımın :root değerleridir', () {
      const t = SipTokens.acik;
      expect(t.bg, const Color(0xFFF4F3F7));
      expect(t.surface, const Color(0xFFFFFFFF));
      expect(t.accent, const Color(0xFF5A45F0)); // elektrik moru
      expect(t.hero, const Color(0xFF17141F));
      expect(t.koyu, isFalse);
    });

    test('koyu tema kendi paletidir — açık temanın kopyası DEĞİL', () {
      const a = SipTokens.acik;
      const k = SipTokens.koyuTema;
      expect(k.bg, const Color(0xFF161519));
      expect(k.surface, const Color(0xFF212026));
      expect(k.ink, const Color(0xFFDEDDE2));
      // Karar 2026-08-19: vurgu ve durum renkleri koyuda AÇILIR (M3 "tone 80" mantığı).
      // Eskiden dördü de açık temayla aynıydı; doymuş mor koyu zeminde hem okunmuyor
      // hem optik titreşim üretiyordu.
      expect(k.accent, isNot(a.accent));
      expect(k.danger, isNot(a.danger));
      expect(k.ok, isNot(a.ok));
      expect(k.warn, isNot(a.warn));
    });

    // Bu grup jetonun DEĞERİNİ değil NİYETİNİ kilitler: bir gün palet yeniden
    // ayarlanırsa değerler değişebilir, ama koyu temanın göz yormama sözü değişemez.
    // Ölçüm WCAG 2.x bağıl parlaklık formülü (DESIGN_SYSTEM.md'deki tabloyla aynı).
    group('koyu tema — göz yormama sözleşmesi', () {
      const k = SipTokens.koyuTema;

      test('vurgu ve durum renkleri kart üstünde AA geçer (eskiden accent 2,86:1)', () {
        expect(_kontrast(k.accent, k.surface), greaterThanOrEqualTo(4.5));
        expect(_kontrast(k.danger, k.surface), greaterThanOrEqualTo(4.5));
        expect(_kontrast(k.ok, k.surface), greaterThanOrEqualTo(4.5));
        expect(_kontrast(k.warn, k.surface), greaterThanOrEqualTo(4.5));
      });

      test('dolgu üstündeki mürekkep okunur — koyuda durumInk koyudur', () {
        expect(_kontrast(k.accentInk, k.accent), greaterThanOrEqualTo(4.5));
        expect(_kontrast(k.durumInk, k.danger), greaterThanOrEqualTo(4.5));
        expect(_kontrast(k.durumInk, k.ok), greaterThanOrEqualTo(4.5));
        expect(_kontrast(k.durumInk, k.warn), greaterThanOrEqualTo(4.5));
        expect(SipTokens.acik.durumInk, const Color(0xFFFFFFFF)); // açıkta eski davranış
      });

      test('gövde metni AAA üstünde ama halation eşiğinin altında (13,5:1)', () {
        final m = _kontrast(k.ink, k.bg);
        expect(m, greaterThanOrEqualTo(7.0)); // AAA
        expect(m, lessThanOrEqualTo(15.0)); // saf beyaz hale yapar — 16,45'ten indirildi
      });

      test('nötr yüzeylerde mor sis yok — kroma vurgunun çok altında', () {
        // Doygunluk vekili: en yüksek ve en düşük kanal arası fark.
        int doygunluk(Color c) {
          final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
          return [r, g, b].reduce((x, y) => x > y ? x : y) -
              [r, g, b].reduce((x, y) => x < y ? x : y);
        }

        for (final n in [k.bg, k.surface, k.surface2, k.ink, k.ink2, k.muted]) {
          expect(doygunluk(n), lessThanOrEqualTo(10),
              reason: 'nötr yüzey mor tentini geri almış');
        }
        expect(doygunluk(k.accent), greaterThanOrEqualTo(40),
            reason: 'vurgu mor kimliğini kaybetmiş');
      });
    });

    test('bakiye renkleri: +borç danger, −alacak ok, 0 temiz ink', () {
      const t = SipTokens.acik;
      expect(t.bakiyeRenk(34000), t.danger);
      expect(t.bakiyeRenk(-12000), t.ok);
      expect(t.bakiyeRenk(0), t.ink);
      expect(SipTokens.bakiyeEtiket(34000), 'Borç');
      expect(SipTokens.bakiyeEtiket(-12000), 'Alacak');
      expect(SipTokens.bakiyeEtiket(0), 'Temiz');
    });

    testWidgets('context.sip tema ile birlikte değişir', (tester) async {
      late SipTokens okunan;
      await tester.pumpWidget(
        _sar(Builder(builder: (c) {
          okunan = c.sip;
          return const SizedBox();
        }), koyu: true),
      );
      expect(okunan.koyu, isTrue);
      expect(okunan.bg, const Color(0xFF161519));
    });

    testWidgets('tema uzantısı kayıtlı değilse açık temaya düşer (çıplak MaterialApp)',
        (tester) async {
      late SipTokens okunan;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (c) {
            okunan = c.sip;
            return const SizedBox();
          }),
        ),
      );
      expect(okunan.accent, SipTokens.acik.accent);
    });
  });

  group('Tipografi', () {
    test('başlık/rakam stilleri Sora, gövde stilleri Hanken Grotesk kullanır', () {
      expect(SipText.bentoDeger.fontFamily, sipFontDisplay);
      expect(SipText.ustBaslik.fontFamily, sipFontDisplay);
      expect(SipText.tutar22.fontFamily, sipFontDisplay);
      expect(SipText.govde.fontFamily, sipFontBody);
      expect(SipText.satirAd.fontFamily, sipFontBody);
      expect(SipText.buton.fontFamily, sipFontBody);
    });

    test('değişken font ağırlığı wght ekseninden de verilir', () {
      // Yalnız fontWeight verilse Android'de kalınlık kayardı; ikisi birlikte olmalı.
      final v = SipText.bentoDeger.fontVariations;
      expect(v, isNotNull);
      expect(v!.single.axis, 'wght');
      expect(v.single.value, 800);
      expect(SipText.bentoDeger.fontWeight, FontWeight.w800);
    });

    test('rakam taşıyan stiller tabular', () {
      for (final s in [
        SipText.bentoDeger,
        SipText.bakiyeDeger,
        SipText.satirTutar,
        SipText.tutar19,
        SipText.tutar22,
        SipText.adet24,
      ]) {
        expect(s.fontFeatures?.any((f) => f.feature == 'tnum'), isTrue);
      }
    });

    test('stiller RENKSİZ — renk DefaultTextStyle\'dan miras alınır', () {
      expect(SipText.satirAd.color, isNull);
      expect(SipText.bentoDeger.color, isNull);
      expect(SipText.ustBaslik.color, isNull);
    });

    test('CSS em cinsinden letter-spacing piksele çevrilmiştir', () {
      // .bento-v: font-size 40, letter-spacing -.03em → -1.2px
      expect(SipText.bentoDeger.letterSpacing, closeTo(-1.2, 0.001));
      // .cek-sec: font-size 10, letter-spacing .14em → 1.4px
      expect(SipText.cekmeceBolum.letterSpacing, closeTo(1.4, 0.001));
    });
  });

  group('SVG yol ayrıştırıcısı', () {
    test('düz çizgi komutlarını çözer', () {
      final p = svgYoluCoz('M4 6h16');
      expect(p.getBounds().left, 4);
      expect(p.getBounds().right, 20);
    });

    test('bitişik örtük çiftleri çözer (m9 18 6-6-6-6)', () {
      // "6-6-6-6" boşluksuz: 6, −6, −6, −6 olarak ayrışmalı (chevron sağ oku).
      final p = svgYoluCoz('m9 18 6-6-6-6');
      final b = p.getBounds();
      expect(b.left, 9);
      expect(b.right, 15);
      expect(b.top, 6);
      expect(b.bottom, 18);
    });

    test('yay (arc) komutunu çözer — daire ikonları buna bağlı', () {
      // Lucide "clock" dış dairesi: 24 kutuya oturan 20 çaplı çember.
      final p = svgYoluCoz('M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z');
      final b = p.getBounds();
      expect(b.width, closeTo(20, 0.5));
      expect(b.height, closeTo(20, 0.5));
    });

    test('kübik eğri ve kapatma çalışır', () {
      final p = svgYoluCoz('M2 2c4 0 8 4 8 8z');
      expect(p.getBounds().isEmpty, isFalse);
    });

    test('bozuk veri çökmez, boş yol döner', () {
      expect(() => svgYoluCoz('QQQ'), returnsNormally);
      expect(() => svgYoluCoz(''), returnsNormally);
    });
  });

  group('İkon seti', () {
    test('tasarımdaki 44 ikonun tamamı taşındı ve hiçbiri boş değil', () {
      expect(SipIcons.hepsi.length, greaterThanOrEqualTo(44));
      for (final girdi in SipIcons.hepsi.entries) {
        expect(girdi.value, isNotEmpty, reason: '${girdi.key} boş');
      }
    });

    test('her ikonun her alt-yolu gerçek geometri üretiyor', () {
      // Ölçüt uzunluktur, sınır kutusu DEĞİL: `Path.getBounds()` eğrilerde kontrol noktası
      // zarfını döndürür (gerçek sınırı değil), o yüzden yaylı ikonlar 24×24'ü aşıyormuş gibi
      // görünür. Ayrıca "M8 6h13" gibi düz çizgilerin yüksekliği 0'dır ama yol geçerlidir.
      // Sıfırdan büyük çevre uzunluğu, ayrıştırıcının komutu gerçekten çizdiğini kanıtlar.
      for (final girdi in SipIcons.hepsi.entries) {
        for (final d in girdi.value.split('|')) {
          final uzunluk = svgYoluCoz(d)
              .computeMetrics()
              .fold<double>(0, (t, m) => t + m.length);
          expect(
            uzunluk,
            greaterThan(0.0),
            reason: '${girdi.key} alt-yolu çizilemedi: $d',
          );
        }
      }
    });

    testWidgets('SipIcon çizilir ve bilinmeyen ad çökmez', (tester) async {
      await tester.pumpWidget(_sar(const Column(
        children: [
          SipIcon(SipIcons.phone),
          SipIcon('boyle-bir-ikon-yok'),
        ],
      )));
      expect(tester.takeException(), isNull);
    });
  });

  group('Para biçimlendirme', () {
    test('kuruş → tr-TR biçimi', () {
      expect(sipTutar(0), '0,00 ₺');
      expect(sipTutar(4500), '45,00 ₺');
      expect(sipTutar(123450), '1.234,50 ₺');
      expect(sipTutar(100000000), '1.000.000,00 ₺');
      expect(sipTutar(5), '0,05 ₺');
    });

    test('negatifte tipografik eksi (U+2212) kullanılır', () {
      expect(sipTutar(-12000), '−120,00 ₺');
      expect(sipTutar(-12000).codeUnitAt(0), 0x2212);
    });

    test('simge kapatılabilir', () {
      expect(sipTutar(4500, simge: false), '45,00');
    });

    test('telefon yalnız gösterim için biçimlenir', () {
      expect(sipTelefon('+905324152290'), '0532 415 22 90');
      expect(sipTelefon('05324152290'), '0532 415 22 90');
      // Biçimlenemeyen giriş olduğu gibi döner (veri kaybı yok)
      expect(sipTelefon('123'), '123');
    });

    test('binlik ayracı', () {
      expect(sipSayi(1234567), '1.234.567');
      expect(sipSayi(999), '999');
    });
  });

  group('Atomlar', () {
    testWidgets('bakiye çipi: 0 bakiyede çizilmez, borçta danger renginde', (tester) async {
      await tester.pumpWidget(_sar(const Column(
        children: [
          SipBakiyeCipi(kurus: 0),
          SipBakiyeCipi(kurus: 34000),
        ],
      )));
      expect(find.text('0,00 ₺'), findsNothing);
      expect(find.text('340,00 ₺'), findsOneWidget);
      final metin = tester.widget<Text>(find.text('340,00 ₺'));
      expect(metin.style!.color, SipTokens.acik.danger);
    });

    testWidgets('durum pili DB ve tasarım anahtarlarının ikisini de kabul eder',
        (tester) async {
      await tester.pumpWidget(_sar(const Column(
        children: [
          SipDurumPili(durum: 'delivered'),
          SipDurumPili(durum: 'iptal'),
          SipDurumPili(durum: 'open'),
        ],
      )));
      expect(find.text('Teslim'), findsOneWidget);
      expect(find.text('İptal'), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);
    });

    test('avatar baş harfleri TÜRKÇE büyütülür', () {
      expect(SipAvatar.basHarfler('Ahmet Yılmaz'), 'AY');
      expect(SipAvatar.basHarfler('Selin'), 'S');
      expect(SipAvatar.basHarfler('  '), '');
      // Dart'ın toUpperCase()'i burada 'IY' verirdi — müşteri adlarının yarısı Türkçe.
      expect(SipAvatar.basHarfler('irfan yılmaz'), 'İY');
      expect(SipAvatar.basHarfler('ışıl demir'), 'ID');
    });

    testWidgets('devre dışı düğme dokunuşu yutar', (tester) async {
      var sayac = 0;
      await tester.pumpWidget(_sar(Column(
        children: [
          SipButon(etiket: 'Kapalı', onTap: null),
          SipButon(etiket: 'Açık', onTap: () => sayac++),
        ],
      )));
      await tester.tap(find.text('Kapalı'));
      await tester.tap(find.text('Açık'));
      await tester.pump();
      expect(sayac, 1);
    });

    testWidgets('form etiketi TÜRKÇE kurallarına göre büyütülür', (tester) async {
      await tester.pumpWidget(_sar(const SipFormEtiket('Müşteri adı')));
      // Dart'ın toUpperCase()'i "MÜŞTERI ADI" verirdi — noktalı İ Türkçede zorunlu.
      expect(find.text('MÜŞTERİ ADI'), findsOneWidget);
    });

    test('Türkçe büyük/küçük harf dönüşümü noktalı-noktasız i ayrımını korur', () {
      expect(trBuyuk('işletme'), 'İŞLETME');
      expect(trBuyuk('ısırgan'), 'ISIRGAN');
      expect(trBuyuk('telefonlar'), 'TELEFONLAR');
      expect(trKucuk('İSTANBUL'), 'istanbul');
      expect(trKucuk('IRMAK'), 'ırmak');
    });

    testWidgets('segment seçimi bildirilir', (tester) async {
      var secilen = -1;
      await tester.pumpWidget(_sar(SipSegment(
        secenekler: const ['Tümü', 'Açık', 'Teslim'],
        secili: 0,
        onSec: (i) => secilen = i,
      )));
      await tester.tap(find.text('Teslim'));
      expect(secilen, 2);
    });
  });

  group('Durum ekranları', () {
    testWidgets('boş durum başlık + açıklama + eylem gösterir', (tester) async {
      var basildi = false;
      await tester.pumpWidget(_sar(SipBosDurum(
        baslik: 'Henüz müşteri yok',
        aciklama: 'İlk müşterini ekleyerek başla.',
        aksiyon: 'Müşteri Ekle',
        onAksiyon: () => basildi = true,
      )));
      expect(find.text('Henüz müşteri yok'), findsOneWidget);
      expect(find.text('İlk müşterini ekleyerek başla.'), findsOneWidget);
      await tester.tap(find.text('Müşteri Ekle'));
      expect(basildi, isTrue);
    });

    testWidgets('üst başlık: geri oku varken menü çizilmez', (tester) async {
      await tester.pumpWidget(_sar(SipUst(baslik: 'Ürünler', onGeri: () {}, onMenu: () {})));
      expect(find.bySemanticsLabel('Geri'), findsOneWidget);
      expect(find.bySemanticsLabel('Menü'), findsNothing);
      expect(find.text('Ürünler'), findsOneWidget);
    });

    testWidgets('çevrimdışı bandı offline-first sözünü söyler', (tester) async {
      await tester.pumpWidget(_sar(const SipCevrimdisiBant()));
      expect(find.textContaining('bağlantı gelince gönderilecek'), findsOneWidget);
    });

    // Oturum ölmüşken offline-first sözünü VERMEK yalandır: hiçbir şey gönderilmeyecektir.
    // Bant kullanıcıya ne yapması gerektiğini söylemeli (2026-07-27 saha arızası).
    testWidgets('oturum bandı bekleme sözü VERMEZ, yeniden giriş ister', (tester) async {
      await tester.pumpWidget(_sar(const SipCevrimdisiBant(tur: SipBantTuru.oturum)));
      expect(find.textContaining('bağlantı gelince gönderilecek'), findsNothing);
      expect(find.textContaining('yeniden girin'), findsOneWidget);
    });

    testWidgets('veri hatası bandı kayıtların güvende olduğunu söyler', (tester) async {
      await tester.pumpWidget(_sar(const SipCevrimdisiBant(tur: SipBantTuru.hata)));
      expect(find.textContaining('bağlantı gelince gönderilecek'), findsNothing);
      expect(find.textContaining('Telefonda güvende'), findsOneWidget);
    });

    testWidgets('iskelet istenen sayıda satır çizer', (tester) async {
      await tester.pumpWidget(_sar(const SipIskelet(adet: 3)));
      expect(find.byType(SipParilti), findsNWidgets(3 * 4));
    });
  });
}

/// WCAG 2.x bağıl parlaklık — koyu tema sözleşme testleri için.
double _bagilParlaklik(Color c) {
  double kanal(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
}

double _kontrast(Color a, Color b) {
  final x = _bagilParlaklik(a), y = _bagilParlaklik(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}
