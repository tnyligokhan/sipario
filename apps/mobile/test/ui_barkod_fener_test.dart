// Barkod okuyucunun FENER düğmesi (2026-07-31 saha isteği: depo rafı ve akşam servisi loştur).
//
// KAMERA MOUNT EDİLMEZ. `MobileScanner` widget'ı kurulduğu anda kontrolcü platform kanalına
// uzanır ve bu depoda kanala çıkan tek bir çağrı dosyanın TÜM testlerini düşürür (kanıtlı tuzak).
// Bu yüzden düğme, ekrandan BAĞIMSIZ bir widget olarak durur ve burada tek başına sınanır;
// gerçek torch çağrısı ekranın içinde try arkasındadır.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/barkod/barkod_kamera.dart';
import 'package:sipario/theme/app_theme.dart';
import 'package:sipario/theme/icons.dart';
import 'package:sipario/theme/tokens.dart';

void main() {
  Future<void> dugmeyiAc(
    WidgetTester tester, {
    required bool acik,
    bool kullanilabilir = true,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: SipTheme.acik(),
      home: Scaffold(
        body: Center(
          child: BarkodFenerDugmesi(
            acik: acik,
            kullanilabilir: kullanilabilir,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ));
  }

  SipIcon fenerIkonu(WidgetTester tester) => tester.widget<SipIcon>(
        find.descendant(
          of: find.byType(BarkodFenerDugmesi),
          matching: find.byType(SipIcon),
        ),
      );

  Color? dugmeZemini(WidgetTester tester) {
    final kutu = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(BarkodFenerDugmesi),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return (kutu.decoration as BoxDecoration?)?.color;
  }

  testWidgets('düğme durumunu SÖYLER: kapalıyken "Feneri aç", açıkken "Feneri kapat"',
      (tester) async {
    await dugmeyiAc(tester, acik: false);
    expect(find.bySemanticsLabel('Feneri aç'), findsOneWidget);
    expect(find.bySemanticsLabel('Feneri kapat'), findsNothing);

    await dugmeyiAc(tester, acik: true);
    expect(find.bySemanticsLabel('Feneri kapat'), findsOneWidget);
    expect(find.bySemanticsLabel('Feneri aç'), findsNothing);
  });

  testWidgets('AÇIK durum GÖRÜNÜR: zemin accent\'e döner, ikon kalınlaşır', (tester) async {
    // Kullanıcı ışığın yandığını düğmeden anlamalı; kameranın önündeki sahne beyaz da olabilir
    // siyah da, tek başına görüntüye bakarak karar veremez.
    await dugmeyiAc(tester, acik: false);
    final kapaliZemin = dugmeZemini(tester);
    final kapaliKalinlik = fenerIkonu(tester).kalinlik;

    await dugmeyiAc(tester, acik: true);
    await tester.pumpAndSettle();

    expect(dugmeZemini(tester), isNot(kapaliZemin), reason: 'açık hâl dolu çizilmeli');
    expect(dugmeZemini(tester), SipTokens.acik.accent);
    expect(fenerIkonu(tester).kalinlik, greaterThan(kapaliKalinlik),
        reason: 'renk körü kullanıcı da ayırt edebilmeli');
  });

  testWidgets('dokunuş fener çağrısını tetikler', (tester) async {
    var dokunus = 0;
    await dugmeyiAc(tester, acik: false, onTap: () => dokunus++);

    await tester.tap(find.byType(BarkodFenerDugmesi));
    await tester.pump();

    expect(dokunus, 1);
  });

  testWidgets('fenersiz cihazda düğme GİZLENMEZ, soluk çizilir ve dokunulabilir kalır',
      (tester) async {
    // PASİF ≠ GİZLİ (mikrofon düğmesiyle aynı desen): sessizce kaybolan yetenek "uygulama bozuk"
    // hissi verir; soluk düğme dokunulduğunda sebebini söyler.
    var dokunus = 0;
    await dugmeyiAc(tester, acik: false, kullanilabilir: false, onTap: () => dokunus++);

    expect(find.bySemanticsLabel('Feneri aç'), findsOneWidget);
    final saydamlik = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(BarkodFenerDugmesi),
        matching: find.byType(Opacity),
      ),
    );
    expect(saydamlik.opacity, lessThan(1));

    await tester.tap(find.byType(BarkodFenerDugmesi));
    await tester.pump();
    expect(dokunus, 1, reason: 'ölü düğme değil — dokunuş gerekçeyi söyler');
  });

  testWidgets('dokunma hedefi DESIGN_SYSTEM alt sınırında', (tester) async {
    await dugmeyiAc(tester, acik: false);
    final olcu = tester.getSize(find.byType(BarkodFenerDugmesi));
    expect(olcu.width, greaterThanOrEqualTo(44));
    expect(olcu.height, greaterThanOrEqualTo(44));
  });
}
