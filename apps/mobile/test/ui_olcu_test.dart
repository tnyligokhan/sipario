// ÖLÇÜ testleri — "çizildi mi" değil, "kaç piksel" sorusunu sorar.
//
// NEDEN VAR: girdi alanlarının altında ~26 px ölü boşluk cihaza kadar geldi, çünkü test
// takımında `getSize`/`getRect` kullanan hiçbir sınama yoktu; her test yalnız widget'ın var
// olduğunu doğruluyordu. Ölçüler `design_handoff_sipario/_cozulmus/_sayfa.html` içindeki CSS
// değerlerinden gelir ve PAZARLIK KONUSU DEĞİLDİR.
//
// ═══ DÜZELTME GERİ ALINIRSA HANGİ ASSERT KIRILIR ═══
// `form.dart` eski hâline (`isDense: true` + dikey dolgu 0 + `constraints: minHeight/maxHeight`)
// döndürülürse:
//   • "yuva yüksekliği 46" assert'i YEŞİL KALIR — dış `ConstrainedBox` yuvayı zaten 46/56 px'e
//     zorlar, `InputDecorator`ın render kutusu bile 46 ölçülür. Naif bir yükseklik sınaması
//     hatayı YAKALAMAZ; bu yüzden tek başına yeterli değildir.
//   • "metin dikeyde ortalı" ve "alt boşluk = üst boşluk" assert'leri KIRILIR. Boyanan kutu
//     `contentPadding.vertical + satırYüksekliği` kadardır ve yuvanın üstüne `Offset(x, 0)` ile
//     yapışır: dikey dolgu 0 iken metin en tepede kalır, ÜSTTE ~0 px / ALTTA ~26 px boşluk
//     olur ve metin merkezi yuva merkezinden ~13 px yukarı sapar. Asıl bekçiler bunlardır.
//
// ═══ NEDEN FONTTAN BAĞIMSIZ ═══
// `flutter test` pubspec'teki Sora/HankenGrotesk dosyalarını yüklemez, yedek test fontuna düşer.
// Bu yüzden sınamalar fontun DOĞAL satır metriğine hiç dayanmaz: [SipInput] tek satırda
// `TextStyle.height` değerini açıkça verdiği için satır yüksekliği `punto × çarpan` olarak
// kesindir, çok satırlıda ise yalnız dolgu farkı (yuva − metin) ölçülür.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/typography.dart';

Widget _sar(Widget child) => MaterialApp(
      theme: SipTheme.acik(),
      home: Scaffold(
        // Girdi kendi yüksekliğini kendi belirlesin: yalnız genişliği sınırlı, ortalanmış yuva.
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    );

/// Girdi yuvası ile içindeki metnin dikey ilişkisi: (yuva, metin).
(Rect, Rect) _kutular(WidgetTester tester) => (
      tester.getRect(find.byType(SipInput)),
      tester.getRect(find.byType(EditableText)),
    );

void main() {
  group('SipInput ölçüleri (CSS .s-input / .kd-input)', () {
    testWidgets('varsayılan 46 px: dolgu 14 + satır 18 + dolgu 14', (tester) async {
      await tester.pumpWidget(_sar(SipInput(ipucu: 'Ad soyad')));
      final (kutu, metin) = _kutular(tester);

      // CSS `.s-input { height: 46px }` — `box-sizing: border-box`, 1.5 px kenarlık dâhil.
      expect(kutu.height, moreOrLessEquals(46, epsilon: 0.5));

      // 15 px punto × 1.2 çarpan = 18,0 px satır. Çarpan açıkça verildiği için font önemsiz.
      expect(metin.height, moreOrLessEquals(18, epsilon: 0.5));

      // (46 − 18) / 2 = 14,0 → ÜSTTE ve ALTTA eşit boşluk. Hatalı kodda 0 / 26,5 idi.
      expect(metin.top - kutu.top, moreOrLessEquals(14, epsilon: 0.5));
      expect(kutu.bottom - metin.bottom, moreOrLessEquals(14, epsilon: 0.5));

      // Ölü boşluğun asıl bekçisi: düzeltme öncesi ~13 px sapıyordu.
      expect(metin.center.dy, moreOrLessEquals(kutu.center.dy, epsilon: 0.5));
    });

    testWidgets('yukseklik 56 + 22 px tutar stili: dolgu 14,8 + satır 26,4 + dolgu 14,8',
        (tester) async {
      await tester.pumpWidget(
        _sar(SipInput(ipucu: '0,00', yukseklik: 56, stil: SipText.tutar(22))),
      );
      final (kutu, metin) = _kutular(tester);

      // CSS `.kd-input { height: 56px; font-size: 22px }` — kasa devri / gün kapatma girdisi.
      expect(kutu.height, moreOrLessEquals(56, epsilon: 0.5));

      // 22 × 1.2 = 26,4 px satır; (56 − 26,4) / 2 = 14,8 px dolgu.
      expect(metin.height, moreOrLessEquals(26.4, epsilon: 0.5));
      expect(metin.top - kutu.top, moreOrLessEquals(14.8, epsilon: 0.5));
      expect(kutu.bottom - metin.bottom, moreOrLessEquals(14.8, epsilon: 0.5));
      expect(metin.center.dy, moreOrLessEquals(kutu.center.dy, epsilon: 0.5));
    });

    testWidgets('ipucu ile metnin satırı aynı — yazmaya başlayınca kutu ZIPLAMAZ',
        (tester) async {
      final kontrolcu = TextEditingController();
      await tester.pumpWidget(_sar(SipInput(controller: kontrolcu, ipucu: 'Ad soyad')));

      final bos = tester.getRect(find.byType(SipInput)).height;

      // Kutu yüksekliği `max(ipucuSatırı, metinSatırı)` ile belirlenir; ipucuna satır çarpanı
      // verilmezse ipucu 19,5 / metin 18,0 olur ve kutu tam burada büyür.
      kontrolcu.text = 'Ayşe Yılmaz';
      await tester.pump();

      expect(tester.getRect(find.byType(SipInput)).height,
          moreOrLessEquals(bos, epsilon: 0.01));
      expect(bos, moreOrLessEquals(46, epsilon: 0.5));
    });

    testWidgets('çok satırlı (.s-textarea): dikey dolgu 11, yükseklik satırdan gelir',
        (tester) async {
      await tester.pumpWidget(_sar(SipInput(ipucu: 'Not', satirlar: 3)));
      final (kutu, metin) = _kutular(tester);

      // CSS `.s-textarea { padding: 11px 14px }` — line-height verilmez, yükseklik satır
      // sayısından gelir. Fontun doğal metriğine dokunulmadığı için yalnız DOLGU ölçülür.
      expect(metin.top - kutu.top, moreOrLessEquals(11, epsilon: 0.5));
      expect(kutu.bottom - metin.bottom, moreOrLessEquals(11, epsilon: 0.5));
      expect(kutu.height - metin.height, moreOrLessEquals(22, epsilon: 0.5));

      // Üç satır tek satırlı girdiden yüksek olmak zorunda.
      expect(kutu.height, greaterThan(46));
    });
  });

  group('SipArama ölçüleri (CSS .arama)', () {
    testWidgets('46 px yüksek, 14,5 px punto', (tester) async {
      await tester.pumpWidget(_sar(SipArama(controller: TextEditingController())));

      // CSS `.arama { height: 46px }`.
      expect(tester.getRect(find.byType(SipArama)).height,
          moreOrLessEquals(46, epsilon: 0.5));

      // CSS `.arama input { font-size: 14.5px }` — `.s-input`in 15 px'i DEĞİL.
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.fontSize,
        14.5,
      );
    });
  });

  group('Dokunma ölçekleri (CSS :active transform)', () {
    test('varsayılan basılı ölçek .btn ile aynı: .98', () {
      // CSS `.btn:active { transform: scale(.98) }` — en yaygın değer, bu yüzden varsayılan.
      // Farklı olanlar (`.pos-tile` .97, `.pos-stepper button` .95, `.altnav-fab` .94) kendi
      // ölçeğini çağrı yerinden verir.
      expect(const SipDokun(child: SizedBox()).basiliOlcek, 0.98);
    });
  });
}
