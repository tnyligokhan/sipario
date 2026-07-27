// Çağrı kartının YAN BOŞLUĞU — 2026-07-27 saha bildiriminin regresyon kilidi.
//
// Bayi: "CallerId açıldığında sağ ve sol kenarlarda boşluk olmalı, ekran sınırına dayanıyor."
//
// Ölçü tasarımın kendisinden: `.cagri-overlay { padding: 0 16px }`
// (`design_handoff_sipario/_cozulmus/_sayfa.html:774`), kart o kabın içinde `width: 100%`.
// Kod tarafında `SipSpace.x3` (=16) ve native `CallerCard.YAN_BOSLUK_DP` (=16) aynı ölçüdür.
//
// KAPSAM: burada YALNIZ Flutter yüzeyi (uygulama içinden açılan kart) sınanabiliyor. Asıl hata
// iki NATIVE yüzeydeydi (overlay penceresi + kilit ekranı Activity'si) ve orada Kotlin birim
// testi altyapısı yok; bu dosya üçüncü yüzeyin sessizce ayrışmamasını garanti eder.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/cagri/cagri_karti.dart';
import 'package:sipario/screens/cagri/cagri_model.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/tokens.dart';

const _kisi = CagriKisi(
  numara: '0532 415 22 90',
  musteriId: 'm1',
  ad: 'Ahmet Yılmaz',
  bakiyeKurus: 34000,
  adres: 'Cumhuriyet Mah. 5. Sk. No:12/4',
);

/// Kartın canlı noktası sonsuz nabız atar — `pumpAndSettle` asılır, geçişi elle ilerletiyoruz.
Future<void> _gecis(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('kart ekran kenarına DAYANMAZ, iki yanda 16 boşluk kalır', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: SipTheme.acik(),
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })),
    ));

    cagriKartiGoster(ctx, kisi: _kisi);
    await _gecis(tester);

    final ekranGenisligi = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final sol = tester.getTopLeft(find.byType(CagriKarti)).dx;
    final sag = tester.getBottomRight(find.byType(CagriKarti)).dx;

    expect(sol, SipSpace.x3, reason: 'sol kenarda tasarımın 16\'lık boşluğu olmalı');
    expect(sag, ekranGenisligi - SipSpace.x3, reason: 'sağ kenarda da aynı boşluk');
    expect(sol, greaterThan(0), reason: 'kart ekran sınırına dayanmamalı');
  });

  testWidgets('dar kartta uzun ad, uzun adres ve son sipariş satırı TAŞMAZ', (tester) async {
    // Taşma testi dar bir ekranda yapılır: 320dp, desteklenen en dar telefon sınıfı.
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: SipTheme.acik(),
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })),
    ));

    cagriKartiGoster(
      ctx,
      kisi: const CagriKisi(
        numara: '+90 532 415 22 90',
        musteriId: 'm1',
        ad: 'Abdurrahman Muhammedoğlu Karahisarlıoğulları',
        bakiyeKurus: 1234567,
        adres: 'Cumhuriyet Mahallesi 5. Sokak Numara 12 Daire 4 Zemin Kat Sarı Bina',
        bolge: 'Kepez',
        not: 'Zil çalışmıyor, gelince arayın; köpek var, bahçe kapısından girmeyin.',
        sonHareket: 'Son sipariş: Damacana 19 L ×2 · Pet Su 0,5 L ×24 · 10:24',
        sonSiparisDurumu: 'Teslim edildi',
      ),
    );
    await _gecis(tester);

    // Taşma, Flutter'da çizim sırasında istisna olarak raporlanır (`RenderFlex overflowed`).
    expect(tester.takeException(), isNull);
    expect(find.byType(CagriKarti), findsOneWidget);
    // Uzun içerik kartı ekran dışına da taşırmamalı.
    final sag = tester.getBottomRight(find.byType(CagriKarti)).dx;
    expect(sag, lessThanOrEqualTo(320 - SipSpace.x3));
  });
}
