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
import 'package:sipario/data/urun_secenekleri.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/orders/pos_catalog.dart';
import 'package:sipario/theme/components/bicim.dart';

import 'support/siparis_yardimci.dart';

/// Katalog sheet'ini açan kabuk + [onEkle] çağrılarının dökümü.
///
/// FİKSTÜR SINIFI (depo kuralı 2026-08-17: yeni yazılan her şey OOP): katalog testlerinin
/// üçü de aynı üç şeye ihtiyaç duyuyor — bir veritabanı, bir düğme, ve kataloğun sepete NE
/// gönderdiğinin kaydı. Her testte tekrarlanan kapanışlar yerine tek nesne.
class KatalogTezgahi {
  KatalogTezgahi() : db = AppDatabase(NativeDatabase.memory());

  final AppDatabase db;

  /// Kataloğun sepete gönderdiği her çağrı: (ürün adı, adet).
  ///
  /// ADET NEGATİF OLABİLİR ve testin asıl kanıtladığı şeylerden biri budur: karodaki `−`
  /// düğmesi sepeti azaltır, yani katalog eksi delta bildirir.
  final List<(String, int)> gonderilenler = [];

  Future<void> urun(String ad, int kurus, {List<UrunSecenegi> secenekler = const []}) =>
      ProductRepository(db).create(name: ad, unitPriceKurus: kurus, secenekler: secenekler);

  Future<void> ac(WidgetTester tester) async {
    await tester.pumpWidget(sipKabuk(Builder(
      builder: (ctx) => TextButton(
        onPressed: () => posKatalogAc(
          ctx,
          db: db,
          onEkle: (u, adet, _) => gonderilenler.add((u.name, adet)),
        ),
        child: const Text('Katalog'),
      ),
    )));
    await tester.tap(find.text('Katalog'));
    await akisiBekle(tester);
  }
}

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

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // KARODAN EKLEME (kullanıcı isteği 2026-08-22) — "adet için ekstra alan açılmasın"
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('seçeneksiz üründe karo dokunuşu SHEET AÇMAZ, doğrudan bir adet ekler',
      (tester) async {
    final tezgah = KatalogTezgahi();
    await tester.runAsync(() => tezgah.urun('Damacana 19 L', 4500));
    await tezgah.ac(tester);

    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);

    // SHEET AÇILMADIĞININ KANITI: adet sheet'inin başlığı ekranda YOK.
    expect(find.text('Sepete Ekle'), findsNothing);
    expect(tezgah.gonderilenler, [('Damacana 19 L', 1)]);

    // Şerit artık adedi yazar ve iki yönlü.
    expect(find.bySemanticsLabel('Damacana 19 L adedini artır'), findsOneWidget);
    expect(find.bySemanticsLabel('Damacana 19 L adedini azalt'), findsOneWidget);

    await ekraniKapat(tester);
  });

  testWidgets('karodaki eksi düğmesi sepete NEGATİF adet bildirir', (tester) async {
    // Kritik: katalog sepeti tutmaz, yalnız DELTA bildirir. Sıfıra inen satırı silmek
    // çağıranın işidir (`order_form_screen._urunEkle`) — burada kanıtlanan, deltanın
    // gerçekten eksi gittiğidir.
    final tezgah = KatalogTezgahi();
    await tester.runAsync(() => tezgah.urun('Damacana 19 L', 4500));
    await tezgah.ac(tester);

    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);
    await tester.tap(find.bySemanticsLabel('Damacana 19 L adedini artır'));
    await akisiBekle(tester);
    await tester.tap(find.bySemanticsLabel('Damacana 19 L adedini azalt'));
    await akisiBekle(tester);

    expect(tezgah.gonderilenler, [
      ('Damacana 19 L', 1),
      ('Damacana 19 L', 1),
      ('Damacana 19 L', -1),
    ]);

    // Adet 1'e döndü; sıfıra inince şerit yeniden "Ekle" olur.
    await tester.tap(find.bySemanticsLabel('Damacana 19 L adedini azalt'));
    await akisiBekle(tester);
    expect(find.text('Ekle'), findsOneWidget);
    expect(find.bySemanticsLabel('Damacana 19 L adedini azalt'), findsNothing);

    await ekraniKapat(tester);
  });

  testWidgets('MALZEMESİ OLAN üründe karo yine sheet açar (seçim karoya sığmaz)',
      (tester) async {
    final tezgah = KatalogTezgahi();
    await tester.runAsync(() => tezgah.urun(
          'Tost',
          4000,
          secenekler: const [UrunSecenegi(ad: 'Kaşar'), UrunSecenegi(ad: 'Sucuk')],
        ));
    await tezgah.ac(tester);

    await tester.tap(find.text('Tost'));
    await akisiBekle(tester);

    // Sheet açıldı: malzeme şeridi ve onun düğmesi ekranda.
    expect(find.text('İçindekiler'), findsOneWidget);
    expect(find.text('Sepete Ekle (${sipTutar(4000)})'), findsOneWidget);
    // Sheet kapanmadan sepete hiçbir şey gitmemiş olmalı.
    expect(tezgah.gonderilenler, isEmpty);

    await ekraniKapat(tester);
  });
}
