// POS ÜRÜN KATALOĞU — üç sütunlu ızgaranın TAŞMA sözleşmesi.
//
// NEDEN VAR (2026-08-18): katalog iki sütundan üç sütuna geçti (kullanıcı isteği: "kartlar
// aşırı büyük, bir satıra 3 ürün sığdırabiliriz"). `childAspectRatio` GENİŞLİK/YÜKSEKLİK'tir
// ve karo yüksekliği sabit parçalardan (2 satır ad + fiyat satırı + dolgu) ve genişliğe
// orantılı parçadan (5/4 görsel) oluşur. Sütun sayısı artınca genişlik düşer, sabit parçaların
// payı büyür — oran güncellenmezse karo kısa kalır ve `Expanded`in altındaki fiyat satırı
// taşar.
//
// ⚠️ BU TEST GÖRÜNTÜYÜ DEĞİL TAŞMAYI KİLİTLER: widget testinde `RenderFlex overflow` bir HATA
// olarak yükselir, yani ölçü hatası burada patlar. Estetik yargı testin işi değil.
//
// EN DAR CİHAZ SEÇİLDİ (360 dp): sabit parçaların payı orada en büyüktür. Ayrıca widget test
// fontu gerçek cihazdan ~1.8 kat geniş çizer — bu, ürün adlarının iki satıra taşma olasılığını
// SAHADAKİNDEN AĞIR sınamak demektir, yani geçen bir test gerçek telefonda da geçer.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/orders/pos_catalog.dart';

import 'support/siparis_yardimci.dart';

void main() {
  testWidgets('360 dp genişlikte üç sütunlu ızgara TAŞMAZ', (tester) async {
    // 360×760: piyasadaki en dar yaygın Android telefon.
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final urunler = ProductRepository(db);
      // UZUN AD + UZUN BİRİM + BÜYÜK TUTAR bir arada: karoyu en çok zorlayan üçlü.
      await urunler.create(
          name: 'Damacana Su 19 Litre Cam Şişe', unitPriceKurus: 125000, unit: 'porsiyon');
      await urunler.create(name: 'Bardak su', unitPriceKurus: 1250);
      await urunler.create(name: 'Soda', unitPriceKurus: 900);
      await urunler.create(name: 'Ayran 1 L', unitPriceKurus: 3400);
    });

    await tester.pumpWidget(sipKabuk(Builder(
      builder: (ctx) => TextButton(
        onPressed: () => posKatalogAc(ctx, db: db, onEkle: (_, _, _) {}),
        child: const Text('Katalog'),
      ),
    )));
    await tester.tap(find.text('Katalog'));
    await akisiBekle(tester);

    // Izgara çizildi: dört ürünün dördü de karoda.
    expect(find.text('Bardak su'), findsOneWidget);
    expect(find.text('Ayran 1 L'), findsOneWidget);

    // ÜÇ SÜTUN sözleşmesi — sayı doğrudan okunur, "sığdı" izleniminden değil.
    final izgara = tester.widget<GridView>(find.byType(GridView));
    final delegate = izgara.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);

    // Taşma olsaydı test buraya gelmeden hata ile düşerdi; yine de açıkça yazılır.
    expect(tester.takeException(), isNull);

    await ekraniKapat(tester);
  });
}
