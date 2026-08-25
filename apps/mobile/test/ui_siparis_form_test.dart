// Sipariş ekranları (yeniden tasarım) — liste, yeni sipariş, teslim & ödeme, elle sıralama.
// Tasarım kaynağı: tasarım s-siparisler.jsx + Sipario.html `.srow*`/`.ys-*`/`.odeme-*`.
//
// DESEN: sorgu/hesap mantığı ekrandan bağımsız saf fonksiyonlarda sınanır (drift akışları
// widget-test sahte zamanında güvenilmez — Dilim 1 dersi); yalnız GÖRÜNÜM sözleşmesi ve
// dokunma akışları widget testine kalır. Widget testlerinde drift'in gerçek zamanı gerektiği
// için `tester.runAsync` kullanılır ve akışa abone DB `close()` EDİLMEZ (abone stream hata atar).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/orders/order_form_screen.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/siparis_yardimci.dart';

/// SİPARİŞ — YENİ SİPARİŞ FORMU (müşteri seçimi · katalog · serbest satır · salt-okunur).
///
/// Bölme gerekçesi: `ui_siparis_test.dart` başlığı.
void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Yeni sipariş — sepet toplamı ve serbest satır
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('adım 1: tezgâh kapısı YOK, "Yeni müşteri ekle" var; satırda telefon + adres',
      (tester) async {
    // Tezgâh satışı GİRİŞ KAPISI kaldırıldı (2026-07-26 kararı); müşterisiz siparişin
    // görüntülenmesi duruyor. Yerini tasarımın `.ys-ekle` + `YeniMusteri` düğmesi aldı.
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        phones: [PhoneInput(phoneE164: '+905321234567', isPrimary: true)],
        addresses: [
          AddressInput(
              addressText: 'Atatürk Cad. No:5', region: 'Merkez', isPrimary: true),
        ],
      );
    });

    await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
    await akisiBekle(tester);

    expect(find.text('Müşterisiz devam et (tezgâh satışı)'), findsNothing);
    expect(find.text('Yeni müşteri ekle'), findsOneWidget);
    expect(find.text('Sipariş kaydedildikten sonra müşteri değiştirilemez.'), findsNothing,
        reason: 'tasarımda olmayan yardımcı metin kaldırıldı');

    // CSS `.mrow-tel` + `.mrow-adres` — ad tek başına yeterli değil (aynı adlı iki müşteri).
    expect(find.text(sipTelefon('+905321234567')), findsOneWidget);
    expect(find.text('Atatürk Cad. No:5, Merkez'), findsOneWidget);

    await ekraniKapat(tester);
  });

  testWidgets('adım 3 özeti müşterinin TELEFONUNU ve ADRESİNİ gösterir (bakiye değil)',
      (tester) async {
    // Tasarım s-siparisler.jsx:382-383. Siparişi kaydetmeden önceki son kontrol "doğru numara,
    // doğru kapı" sorusudur; para teslimde konuşulur (BRIEF).
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500, unit: 'koli');
      await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        phones: [PhoneInput(phoneE164: '+905321234567', isPrimary: true)],
        addresses: [
          AddressInput(
              addressText: 'Atatürk Cad. No:5', region: 'Merkez', isPrimary: true),
        ],
      );
    });

    await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
    await akisiBekle(tester);
    await tester.tap(find.text('Ayşe Yılmaz'));
    await akisiBekle(tester);
    await tester.tap(find.text('Katalogdan ürün ekle'));
    await akisiBekle(tester);
    // SEÇENEKSİZ ÜRÜNDE ADET SHEET'İ AÇILMAZ (2026-08-22): karoya dokunmak bir adedi
    // DOĞRUDAN sepete koyar. Malzemesi olan üründe eski sheet yolu aynen durur.
    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);
    await tester.tap(find.text('1 kalem eklendi'));
    await akisiBekle(tester);

    // Adım 2 — CSS `.ys-birim` YALNIZ birimi yazar, birim fiyatı tekrarlamaz.
    expect(find.text('koli'), findsOneWidget);
    expect(find.text('koli · ${sipTutar(4500)}'), findsNothing);

    await tester.tap(find.text('Devam'));
    await akisiBekle(tester);

    expect(find.text(sipTelefon('+905321234567')), findsOneWidget);
    expect(find.text('Atatürk Cad. No:5, Merkez'), findsOneWidget);
    // CSS `.sd-birim` — `{adet} {birim} × {fiyat}`; birim düşerse 1 koli mi 1 adet mi belirsiz.
    expect(find.text('1 koli × ${sipTutar(4500)}'), findsOneWidget);

    await ekraniKapat(tester);
  });

  testWidgets('katalogdan ürün eklenip adet artırılınca alt toplam doğru hesaplanır', (tester) async {
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500, unit: 'adet');
      await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
    });

    await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
    await akisiBekle(tester);

    await tester.tap(find.text('Ayşe Yılmaz'));
    await akisiBekle(tester);

    await tester.tap(find.text('Katalogdan ürün ekle'));
    await akisiBekle(tester);
    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);

    // KARO ŞERİDİ (2026-08-22): ilk dokunuş "Ekle" şeridini `[−] 1 [+]` hâline çevirir; artı
    // düğmesi ikinci adedi sepete koyar. Şerit ADEDİ DE YAZAR — bayi ne gönderdiğini karodan
    // görmeli, sepeti açmak zorunda kalmamalı.
    await tester.tap(find.bySemanticsLabel('Damacana 19 L adedini artır'));
    await akisiBekle(tester);
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.text('1 kalem eklendi'));
    await akisiBekle(tester);

    // `.ys-alt` alt toplam çubuğu.
    expect(find.text(sipTutar(2 * 4500)), findsWidgets);

    // Sepette bir kez daha artır → 3 adet.
    await tester.tap(find.bySemanticsLabel('Artır').last);
    await tester.pump();
    expect(find.text(sipTutar(3 * 4500)), findsWidgets);

    await ekraniKapat(tester);
  });

  testWidgets('serbest satır toplama girer ve OrderLines\'a isCustom=true yazılır', (tester) async {
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500, unit: 'adet');
      await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
    });

    await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
    await akisiBekle(tester);
    await tester.tap(find.text('Ayşe Yılmaz'));
    await akisiBekle(tester);

    // Önce katalogdan bir kalem (sepet boş kalamaz kuralı devrede kalmasın).
    await tester.tap(find.text('Katalogdan ürün ekle'));
    await akisiBekle(tester);
    // SEÇENEKSİZ ÜRÜNDE ADET SHEET'İ AÇILMAZ (2026-08-22): karoya dokunmak bir adedi
    // DOĞRUDAN sepete koyar. Malzemesi olan üründe eski sheet yolu aynen durur.
    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);
    await tester.tap(find.text('1 kalem eklendi'));
    await akisiBekle(tester);

    // Serbest satır: 150 ₺ nakliye.
    await tester.tap(find.text('Katalogda olmayan iş ekle'));
    await akisiBekle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Ör. nakliye, montaj, ek iş'), 'Nakliye');
    await tester.enterText(find.widgetWithText(TextField, '0'), '150');
    await tester.pump();
    await tester.tap(find.text('Ekle'));
    await akisiBekle(tester);

    // Serbest satır toplama DAHİL (4500 + 15000 kuruş).
    expect(find.text(sipTutar(4500 + 15000)), findsWidgets);
    expect(find.text('tek seferlik'), findsOneWidget);

    // Kaydet → DB'de satırın isCustom bayrağı açık olmalı.
    await tester.tap(find.text('Devam'));
    await akisiBekle(tester);
    await tester.tap(find.text('Siparişi Kaydet'));
    await akisiBekle(tester, ms: 300);

    late List<OrderLine> satirlar;
    await tester.runAsync(() async {
      satirlar = await db.select(db.orderLines).get();
    });
    final serbest = satirlar.firstWhere((l) => l.productName == 'Nakliye');
    expect(serbest.isCustom, isTrue,
        reason: 'serbest satır AÇIK bayrakla yazılır — productId null olması yeterli ayırt edici değil');
    expect(serbest.productId, isNull);
    expect(serbest.lineTotalKurus, 15000);
    final katalog = satirlar.firstWhere((l) => l.productName == 'Damacana 19 L');
    expect(katalog.isCustom, isFalse, reason: 'katalog satırı serbest DEĞİL');

    await ekraniKapat(tester);
  });

  testWidgets('salt-okunur kipte sipariş kaydedilemez (mağaza/abonelik kuralı)', (tester) async {
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    late String musteriId;
    await tester.runAsync(() async {
      await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500, unit: 'adet');
      musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
    });

    await tester.pumpWidget(
        sipKabuk(OrderFormScreen(db: db, initialCustomerId: musteriId, writable: false)));
    await akisiBekle(tester);

    await tester.tap(find.text('Katalogdan ürün ekle'));
    await akisiBekle(tester);
    // SEÇENEKSİZ ÜRÜNDE ADET SHEET'İ AÇILMAZ (2026-08-22): karoya dokunmak bir adedi
    // DOĞRUDAN sepete koyar. Malzemesi olan üründe eski sheet yolu aynen durur.
    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);
    await tester.tap(find.text('1 kalem eklendi'));
    await akisiBekle(tester);
    await tester.tap(find.text('Devam'));
    await akisiBekle(tester);

    expect(find.text('Aboneliğiniz sona erdiği için yeni kayıt eklenemiyor'), findsOneWidget);
    await tester.tap(find.text('Siparişi Kaydet'));
    await akisiBekle(tester, ms: 250);

    late int siparisSayisi;
    await tester.runAsync(() async {
      siparisSayisi = (await db.select(db.orders).get()).length;
    });
    expect(siparisSayisi, 0, reason: 'salt-okunur kipte hiçbir sipariş yazılmamalı');

    await ekraniKapat(tester);
  });

}
