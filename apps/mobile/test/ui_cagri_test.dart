// Çağrı kartı + çağrı günlüğü UI testleri.
// Tasarım kaynağı: tasarım s-cagri.jsx (kart varyantları), s-veri.jsx (ARAMALAR),
// s-uygulama.jsx (muaf numara kuralı).
//
// KAPSAM NOTU: gerçek cihazda çağrı anında çizilen kart saf Kotlin'dir
// (android/.../CallerCard.kt) ve buradan test EDİLEMEZ. Bu dosya Flutter karşılığını
// (uygulama önplandayken ve Ayarlar'daki simülasyonda kullanılan kart) doğrular.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/cagri/cagri_karti.dart';
import 'package:sipario/screens/cagri/cagri_model.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/components/atoms.dart';

Widget _kabuk(Widget govde, {bool koyu = false}) => MaterialApp(
      theme: koyu ? SipTheme.koyu() : SipTheme.acik(),
      home: Scaffold(body: govde),
    );

/// Kartın canlı noktası sonsuz nabız atar, yani ağaç HİÇ oturmaz — `pumpAndSettle`
/// zaman aşımına düşer. Geçişleri elle ilerletiyoruz.
Future<void> _gecis(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

const _ahmet = CagriKisi(
  numara: '0532 415 22 90',
  musteriId: 'm1',
  ad: 'Ahmet Yılmaz',
  bakiyeKurus: 34000,
  adres: 'Cumhuriyet Mah. 5. Sk. No:12/4',
  konumVar: true,
  not: 'Zil çalışmıyor, gelince arayın.',
  sonHareket: 'Son sipariş: Damacana 19 L ×2 (10:24)',
);

const _selin = CagriKisi(
  numara: '0533 220 78 41',
  musteriId: 'm2',
  ad: 'Selin Kaya',
);

const _murat = CagriKisi(
  numara: '0542 907 63 22',
  musteriId: 'm3',
  ad: 'Murat Öz',
  bakiyeKurus: -12000,
);

/// ÇAĞRI KARTI — kayıtlı müşteri · kayıtsız numara · muaf numara.
///
/// DOSYA İKİYE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 709 satırdı): çağrı günlüğü ve saf
/// kurallar `ui_cagri_gunlugu_test.dart`ta.
void main() {
  group('sonOnHane / numaraMuafMi', () {
    test('üç yazım biçimi de aynı son 10 haneye iner', () {
      expect(sonOnHane('+90 532 415 22 90'), '5324152290');
      expect(sonOnHane('0532 415 22 90'), '5324152290');
      expect(sonOnHane('5324152290'), '5324152290');
    });

    test('muaf listesi biçimden bağımsız eşleşir', () {
      expect(numaraMuafMi('+905331111111', ['0533 111 11 11']), isTrue);
      expect(numaraMuafMi('0533 111 11 11', ['5331111111']), isTrue);
      expect(numaraMuafMi('0532 415 22 90', ['0533 111 11 11']), isFalse);
      expect(numaraMuafMi('0532 415 22 90', const []), isFalse);
    });

    test('10 haneden kısa numara asla muaf sayılmaz', () {
      // Gizli numara / kısa servis numarası boş bir muaf kaydıyla eşleşip kartı susturmamalı.
      expect(numaraMuafMi('', ['']), isFalse);
      expect(numaraMuafMi('112', ['112']), isFalse);
    });
  });

  group('CagriKarti — kayıtlı müşteri', () {
    testWidgets('borçluda ad, kod, borç rozeti ve AÇIK BORÇ şeridi görünür', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _ahmet)));

      expect(find.text('GELEN ÇAĞRI'), findsOneWidget);
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('M-001'), findsOneWidget);
      expect(find.text('Borç'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsOneWidget);
      expect(find.text('340,00 ₺'), findsOneWidget);

      // Bilgi satırları: adres bölgeyle birleşir, not sarı satırda durur.
      // Bölge kaldırıldı (2026-07-28): kartta adres metni tek başına yazar.
      expect(find.text('Cumhuriyet Mah. 5. Sk. No:12/4'), findsOneWidget);
      expect(find.text('Son sipariş: Damacana 19 L ×2 (10:24)'), findsOneWidget);
      expect(find.text('Zil çalışmıyor, gelince arayın.'), findsOneWidget);

      // Kayıtlı varyantın eylemleri.
      expect(find.text('Sipariş Oluştur'), findsOneWidget);
      expect(find.text('Defteri Aç'), findsOneWidget);
      expect(find.text('Müşteri Olarak Kaydet'), findsNothing);
    });

    testWidgets('alacaklıda ALACAĞI VAR şeridi ve Alacak rozeti çıkar', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _murat)));

      expect(find.text('Alacak'), findsOneWidget);
      expect(find.text('ALACAĞI VAR'), findsOneWidget);
      expect(find.text('120,00 ₺'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsNothing);
    });

    testWidgets('bakiyesi temiz müşteride şerit hiç çizilmez, rozet Temiz olur', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _selin)));

      expect(find.text('Temiz'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsNothing);
      expect(find.text('ALACAĞI VAR'), findsNothing);
      expect(find.text('0,00 ₺'), findsNothing);
    });

    testWidgets('kartta AVATAR yok (tasarımın .cagri-kim\'i avatar çizmiyor)', (tester) async {
      await tester.pumpWidget(_kabuk(const CagriKarti(kisi: _ahmet)));

      // `.cagri-av` ölü CSS: ne baş harf rozeti ne de kayıtsız varyantın telefon ikon kutusu.
      expect(find.byType(SipAvatar), findsNothing);
      expect(find.text('AY'), findsNothing);
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);

      await tester.pumpWidget(
        _kabuk(const CagriKarti(kisi: CagriKisi.kayitsiz('0216 555 01 88'))),
      );
      expect(find.byType(SipIkonKutu), findsNothing);
    });

    testWidgets('eylemler doğru geri çağrıyı tetikler', (tester) async {
      var siparis = 0;
      var defter = 0;
      await tester.pumpWidget(_kabuk(CagriKarti(
        kisi: _ahmet,
        onSiparis: () => siparis++,
        onDefter: () => defter++,
      )));

      await tester.tap(find.text('Sipariş Oluştur'));
      await tester.tap(find.text('Defteri Aç'));
      await tester.pump();

      expect(siparis, 1);
      expect(defter, 1);
    });
  });

  group('CagriKarti — kayıtsız numara', () {
    testWidgets('numara baskın, Kayıtsız rozeti ve tek kaydetme eylemi', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriKarti(kisi: CagriKisi.kayitsiz('0216 555 01 88'))),
      );

      expect(find.text('0216 555 01 88'), findsOneWidget);
      expect(find.text('Bu numara defterinizde yok'), findsOneWidget);
      expect(find.text('Kayıtsız'), findsOneWidget);
      expect(find.text('Müşteri Olarak Kaydet'), findsOneWidget);

      // Kayıtsızda bakiye/defter dili hiç görünmez.
      expect(find.text('Sipariş Oluştur'), findsNothing);
      expect(find.text('Defteri Aç'), findsNothing);
      expect(find.text('Temiz'), findsNothing);
    });

    testWidgets('koyu temada da aynı içerik çizilir', (tester) async {
      await tester.pumpWidget(
        _kabuk(const CagriKarti(kisi: _ahmet), koyu: true),
      );
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('AÇIK BORÇ'), findsOneWidget);
    });
  });

  group('cagriKartiGoster — muaf numara', () {
    testWidgets('muaf numarada kart HİÇ açılmaz', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_kabuk(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));

      final sonuc = await cagriKartiGoster(
        ctx,
        kisi: const CagriKisi.kayitsiz('0533 111 11 11'),
        muafNumaralar: const ['+90 533 111 11 11'],
      );
      await tester.pumpAndSettle();

      expect(sonuc, isNull);
      expect(find.text('GELEN ÇAĞRI'), findsNothing);
    });

    testWidgets('muaf olmayan numarada kart açılır ve eylemle kapanır', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_kabuk(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));

      final bekleyen = cagriKartiGoster(
        ctx,
        kisi: _ahmet,
        muafNumaralar: const ['0533 111 11 11'],
      );
      await _gecis(tester);
      expect(find.text('GELEN ÇAĞRI'), findsOneWidget);

      await tester.tap(find.text('Defteri Aç'));
      await _gecis(tester);

      expect(await bekleyen, CagriEylemi.defter);
      expect(find.text('GELEN ÇAĞRI'), findsNothing);
    });
  });

}
