// Kabuk UI testlerinin ortak yardımcıları (`ui_kabuk_test.dart` + `ui_kabuk_ana_test.dart`).
//
// Widget-test sahte zamanında gerçek drift çağrıları `tester.runAsync` içinde beklenir
// (Dilim 1-3 dersi: düz Future sorgular da asılır). Akışa abone db KAPATILMAZ — bellek-içi db
// süreç sonunda gider. Tasarımın hap navigasyonu ve hero blokları uzun olduğundan viewport
// dar telefon yerine 800×2400 kurulur; yoksa taşma hatası testi kirletir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/theme/app_theme.dart';

/// Test ağacı: gerçek tema (jetonlar ThemeExtension'dan gelsin) + geniş viewport.
Future<void> ekranaKoy(WidgetTester tester, Widget ekran) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: SipTheme.acik(), home: ekran));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump();
}

/// Kapanış: ağacı boşalt + bekleyen zamanlayıcılar (toast/animasyon) sönsün.
Future<void> kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

/// `Semantics(button: true, label: …)` ile işaretlenmiş dokunma hedefi.
/// (Sekme ve FAB metin taşımadığından — seçili sekme dışında — ikonla değil semantikle bulunur.)
Finder semantikDugme(String etiket) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.button == true && w.properties.label == etiket,
      description: 'Semantics(button, "$etiket")',
    );
