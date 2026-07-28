// Sipariş ekranları (yeniden tasarım) — liste, yeni sipariş, teslim & ödeme, elle sıralama.
// Tasarım kaynağı: tasarım s-siparisler.jsx + Sipario.html `.srow*`/`.ys-*`/`.odeme-*`.
//
// DESEN: sorgu/hesap mantığı ekrandan bağımsız saf fonksiyonlarda sınanır (drift akışları
// widget-test sahte zamanında güvenilmez — Dilim 1 dersi); yalnız GÖRÜNÜM sözleşmesi ve
// dokunma akışları widget testine kalır. Widget testlerinde drift'in gerçek zamanı gerektiği
// için `tester.runAsync` kullanılır ve akışa abone DB `close()` EDİLMEZ (abone stream hata atar).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/orders/gecen_sure_pili.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/orders/order_form_screen.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/order_row.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/siparis_yardimci.dart';

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Liste satırı — CSS `.srow*` görünüm sözleşmesi
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('liste satırı: kod rozeti · müşteri · ürün dökümü · tutar · durum pili', (tester) async {
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    late String musteriId;
    await tester.runAsync(() async {
      musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      final urunler = ProductRepository(db);
      // productId VERİLİR: katalog satırı serbest satırdan böyle ayrılır ve döküm "×adet" yazar.
      final damacana = await urunler.create(name: 'Damacana 19 L', unitPriceKurus: 4500);
      final bardak = await urunler.create(name: 'Bardak su', unitPriceKurus: 1250);
      await OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(
            productId: damacana,
            productName: 'Damacana 19 L',
            unitPriceKurus: 4500,
            qty: 2),
        LineInput(
            productId: bardak, productName: 'Bardak su', unitPriceKurus: 1250, qty: 1),
      ]);
    });

    await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
    await akisiBekle(tester);

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    // `.srow-kod` — kod rozeti. 2026-07-29'a kadar burada UUID'den türetilmiş sahte bir
    // "M-007" vardı; artık gerçek sıra kodu SUNUCUDAN gelir ve bu test yerel bir veritabanına
    // koştuğu için kod YOKTUR → rozet hiç çizilmez (uydurma numara basılmaz kuralı).
    expect(find.textContaining('M-'), findsNothing);
    // `.srow-urunler` — madde madde döküm, başlığıyla.
    expect(find.text('SİPARİŞ KALEMLERİ'), findsOneWidget);
    expect(find.text('Damacana 19 L ×2'), findsOneWidget);
    expect(find.text('Bardak su ×1'), findsOneWidget);
    // `.srow-amt` — sipariş toplamı.
    expect(find.text(sipTutar(2 * 4500 + 1250)), findsOneWidget);
    // `.srow-alt` — AÇIK siparişte durum pili yerine BEKLEME SÜRESİ pili (kullanıcı isteği
    // 2026-07-29). "Açık" bilgisi zaten sekmenin adında; satırda merak edilen bekleme süresidir.
    expect(find.byType(GecenSurePili), findsOneWidget);
    expect(find.text('yeni'), findsOneWidget, reason: 'yeni açılan sipariş 1 dk altındadır');
    expect(find.byType(SipDurumPili), findsNothing);
    // Sekme etiketi olarak "Açık" hâlâ vardır — satırda yoktur.
    expect(find.text('Açık'), findsOneWidget);

    await ekraniKapat(tester);
  });

  testWidgets('segment şeridi tasarımın DÖRT sekmesidir — "Benim" yok', (tester) async {
    // "Benim" tasarımda hiç yoktu; atama kullanmayan bayide boş bir sekme karşılıyordu ve
    // kuryenin işini "Açık" sekmesi zaten gösteriyor (2026-07-26 kararı).
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      await OrderRepository(db).create(customerId: m, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
    });

    // Oturum sahibi verilse bile (eskiden "Benim" sekmesini açan tek kip kurye oturumuydu)
    // şerit rolden bağımsızdır — `userRole` alanı da bu temizlikle birlikte kalktı.
    await tester.pumpWidget(
        sipKabuk(OrderListScreen(db: db, writable: true, userId: 'k1')));
    await akisiBekle(tester);

    expect(find.text('Benim'), findsNothing);
    for (final etiket in ['Açık', 'Teslim', 'Borçlu', 'Tümü']) {
      expect(find.text(etiket), findsWidgets, reason: '$etiket sekmesi durmalı');
    }

    await ekraniKapat(tester);
  });

  testWidgets('KAPALI siparişte kurye çipi dokunuşu yutmaz, gerekçe bildirir', (tester) async {
    // Tasarım s-siparisler.jsx:24. Çip tıklanamaz yapıldığında `order_list_screen`deki
    // "Kapalı siparişte kurye değiştirilemez" kontrolü ÖLÜ KODdu; kullanıcı dokunuyor,
    // hiçbir şey olmuyordu.
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k1',
            name: 'Kurye Ali',
            role: 'kurye',
            status: 'active',
          ));
      final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      final id = await OrderRepository(db).create(customerId: m, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      await OrderRepository(db).assign(id, 'k1');
      await OrderRepository(db).deliver(id, paymentType: 'nakit');
    });

    await tester.pumpWidget(sipKabuk(
        OrderListScreen(db: db, writable: true, canAssign: true)));
    await akisiBekle(tester);

    await tester.tap(find.text('Teslim'));
    await akisiBekle(tester);

    await tester.tap(find.text('Kurye Ali'));
    await akisiBekle(tester);

    expect(find.text('Kapalı siparişte kurye değiştirilemez'), findsOneWidget);
    // Sheet başlığı "Kurye Seç · <müşteri>" olurdu — tam eşleşme yerine içerik aranır.
    expect(find.textContaining('Kurye Seç'), findsNothing, reason: 'sheet AÇILMAZ');

    await ekraniKapat(tester);
  });

  testWidgets('segment filtresi listeyi süzer: Teslim sekmesi açık siparişi gizler', (tester) async {
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      final teslimId = await OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      await OrderRepository(db).deliver(teslimId, paymentType: 'nakit');
      await CustomerRepository(db).create(name: 'Mehmet Demir').then((id) =>
          OrderRepository(db).create(customerId: id, lines: [
            LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 3),
          ]));
    });

    await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
    await akisiBekle(tester);

    // Varsayılan sekme "Açık": yalnız Mehmet'in siparişi.
    expect(find.text('Mehmet Demir'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsNothing);

    await tester.tap(find.text('Teslim'));
    await akisiBekle(tester);

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Mehmet Demir'), findsNothing);

    await ekraniKapat(tester);
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Sipariş detayı sheet'i — CSS `.sheet-tut` / `.sheet-title` / `.sheet-x`
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('detay sheet\'i MÜŞTERİ ADI başlığıyla ve KAPAT düğmesiyle açılır', (tester) async {
    // Tasarım `<Sheet tam baslik={o.musteriAd}>` (s-siparisler.jsx:466). Başlık geçmediği
    // sürece `sipSheet` üst şeridi hiç çizmiyor; tutamaç, başlık ve X birlikte kayboluyor ve
    // kullanıcının sheet'i kapatacak GÖRÜNÜR bir düğmesi kalmıyordu.
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      await OrderRepository(db).create(customerId: m, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
    });

    // Sheet, listeden açılır (tasarımdaki gerçek yol) — başlık liste satırından geçirilir.
    await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
    await akisiBekle(tester);
    await tester.tap(find.text('Ayşe Yılmaz'));
    await akisiBekle(tester);

    // Liste satırı + sheet başlığı = ad iki kez görünür.
    expect(find.text('Ayşe Yılmaz'), findsNWidgets(2));
    expect(find.text('Sipariş Kalemleri'), findsOneWidget, reason: 'sheet gerçekten açık');
    expect(find.bySemanticsLabel('Kapat'), findsOneWidget);

    // KAPAT düğmesi işini yapar.
    await tester.tap(find.bySemanticsLabel('Kapat'));
    await akisiBekle(tester);
    expect(find.text('Sipariş Kalemleri'), findsNothing);

    await ekraniKapat(tester);
  });

  testWidgets('geçmiş sipariş satırı KALEM DÖKÜMÜ + saat·ödeme·kurye yazar', (tester) async {
    // Tasarım `.gec-t` = siparisOzet(g), `.gec-s` = saat · ödeme · kurye (:525-526). Önce tam
    // tersi çiziliyordu (üstte saat·ödeme, altta not) — döküm ve kurye hiç görünmüyordu.
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    late String acikId;
    await tester.runAsync(() async {
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k1',
            name: 'Kurye Ali',
            role: 'kurye',
            status: 'active',
          ));
      // productId VERİLİR: döküm "×adet" YALNIZ katalog satırında yazılır — `serbestMi`
      // productId null'ı serbest satır sayar ve adet düşer (satirOzeti sözleşmesi).
      final urunler = ProductRepository(db);
      final damacana =
          await urunler.create(name: 'Damacana 19 L', unitPriceKurus: 4500, unit: 'adet');
      final bardak =
          await urunler.create(name: 'Bardak su', unitPriceKurus: 1250, unit: 'adet');
      final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      final eski = await OrderRepository(db).create(customerId: m, note: 'Kapı kodu 1234', lines: [
        LineInput(
            productId: damacana,
            productName: 'Damacana 19 L',
            unitPriceKurus: 4500,
            unit: 'adet',
            qty: 2),
      ]);
      await OrderRepository(db).assign(eski, 'k1');
      await OrderRepository(db).deliver(eski, paymentType: 'nakit');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      acikId = await OrderRepository(db).create(customerId: m, lines: [
        LineInput(
            productId: bardak,
            productName: 'Bardak su',
            unitPriceKurus: 1250,
            unit: 'adet',
            qty: 1),
      ]);
    });

    await tester.pumpWidget(
        sipKabuk(OrderDetailScreen(db: db, orderId: acikId, writable: true)));
    // İKİ tur ŞART: detay ekranı iç içe DÖRT akış kullanıyor (sipariş · satırlar · ekip ·
    // adresler). Tek tur "Geçmiş Siparişler" başlığını çizmeye yetiyor ama satır akışı henüz
    // boş olduğu için döküm "—" kalıyor ve `×2` bulunamıyordu — kodda değil, beklemede hata.
    await akisiBekle(tester);
    await akisiBekle(tester);

    expect(find.text('Geçmiş Siparişler'), findsOneWidget);
    // Üst satır: kalem dökümü (tasarımın `siparisOzet`i).
    expect(find.text('Damacana 19 L ×2'), findsOneWidget);
    // Alt satır: kurye adı dökümün ALTINDA, not DEĞİL.
    expect(find.textContaining('Nakit · Kurye Ali'), findsOneWidget);
    expect(find.text('Kapı kodu 1234'), findsNothing,
        reason: 'geçmiş satırında NOT yazmaz — yeri kurye adıdır');

    await ekraniKapat(tester);
  });

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
    expect(find.text('Atatürk Cad. No:5 — Merkez'), findsOneWidget);

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
    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);
    await tester.tap(find.text('Sepete Ekle · ${sipTutar(4500)}'));
    await akisiBekle(tester);
    await tester.tap(find.text('Bitti · 1 kalem eklendi'));
    await akisiBekle(tester);

    // Adım 2 — CSS `.ys-birim` YALNIZ birimi yazar, birim fiyatı tekrarlamaz.
    expect(find.text('koli'), findsOneWidget);
    expect(find.text('koli · ${sipTutar(4500)}'), findsNothing);

    await tester.tap(find.text('Devam'));
    await akisiBekle(tester);

    expect(find.text(sipTelefon('+905321234567')), findsOneWidget);
    expect(find.text('Atatürk Cad. No:5 — Merkez'), findsOneWidget);
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

    // Adet sheet'i: bir kez artır → 2 adet, "Sepete Ekle · 90,00 ₺".
    await tester.tap(find.bySemanticsLabel('Artır'));
    await tester.pump();
    expect(find.text('Sepete Ekle · ${sipTutar(2 * 4500)}'), findsOneWidget);
    await tester.tap(find.text('Sepete Ekle · ${sipTutar(2 * 4500)}'));
    await akisiBekle(tester);

    await tester.tap(find.text('Bitti · 1 kalem eklendi'));
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
    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);
    await tester.tap(find.text('Sepete Ekle · ${sipTutar(4500)}'));
    await akisiBekle(tester);
    await tester.tap(find.text('Bitti · 1 kalem eklendi'));
    await akisiBekle(tester);

    // Serbest satır: 150 ₺ nakliye.
    await tester.tap(find.text('+ Serbest satır (katalogda olmayan iş)'));
    await akisiBekle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Ör. Nakliye, montaj, ek iş'), 'Nakliye');
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
    await tester.tap(find.text('Damacana 19 L'));
    await akisiBekle(tester);
    await tester.tap(find.text('Sepete Ekle · ${sipTutar(4500)}'));
    await akisiBekle(tester);
    await tester.tap(find.text('Bitti · 1 kalem eklendi'));
    await akisiBekle(tester);
    await tester.tap(find.text('Devam'));
    await akisiBekle(tester);

    expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
    await tester.tap(find.text('Siparişi Kaydet'));
    await akisiBekle(tester, ms: 250);

    late int siparisSayisi;
    await tester.runAsync(() async {
      siparisSayisi = (await db.select(db.orders).get()).length;
    });
    expect(siparisSayisi, 0, reason: 'salt-okunur kipte hiçbir sipariş yazılmamalı');

    await ekraniKapat(tester);
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Teslim & ödeme sheet'i — CSS `.odeme-grid`, `.teslim-uyari`
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('ödeme tipi NAKİT ön-seçili gelir ve tek dokunuşla teslim yazılır', (tester) async {
    // Tasarım `useState('nakit')` (s-siparisler.jsx:443). Bir dönem "hiçbiri seçili değil +
    // düğme pasif" denendi; nakit teslimlerin ezici çoğunluğu olduğu için her teslime fazladan
    // bir dokunuş bindiriyordu. Tutar ekranda yazılı ve defterde düzeltme yolu var.
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    late String orderId;
    await tester.runAsync(() async {
      final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      orderId = await OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2),
      ]);
    });

    await tester.pumpWidget(
        sipKabuk(OrderDetailScreen(db: db, orderId: orderId, writable: true)));
    await akisiBekle(tester);

    await tester.tap(find.text('Teslim Et'));
    await akisiBekle(tester);

    expect(find.text('Önce ödeme tipi seçin.'), findsNothing,
        reason: 'ön-seçim varken bu uyarı gereksiz — kaldırıldı');
    await tester.tap(find.text('Teslim Et ve Kaydet'));
    await akisiBekle(tester, ms: 300);

    late Order siparis;
    await tester.runAsync(() async {
      siparis = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    });
    expect(siparis.status, 'delivered');
    expect(siparis.paymentType, 'nakit', reason: 'ön-seçili tip nakittir');

    await ekraniKapat(tester);
  });

  testWidgets('müşterisiz siparişte veresiye karosu GİZLENMEZ, pasif çizilir', (tester) async {
    // Tasarım `disabled` + `opacity .45` (s-siparisler.jsx:620). Karoyu listeden düşürmek
    // kullanıcıya "veresiye diye bir şey yok" dedirtiyordu; pasif karo + altındaki açıklama
    // "burada kullanılamaz, çünkü…" der.
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    late String orderId;
    await tester.runAsync(() async {
      orderId = await OrderRepository(db).create(lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
    });

    await tester.pumpWidget(
        sipKabuk(OrderDetailScreen(db: db, orderId: orderId, writable: true)));
    await akisiBekle(tester);
    await tester.tap(find.text('Teslim Et'));
    await akisiBekle(tester);

    expect(find.text('Veresiye'), findsOneWidget, reason: 'karo YERİNDE durur');
    expect(
        find.text('Tezgâh satışında veresiye kullanılamaz — kayıtlı müşteri gerekir.'),
        findsOneWidget);

    // Dokunuş YUTULUR: uyarı şeridi çıkmaz, seçim nakitte kalır.
    await tester.tap(find.text('Veresiye'));
    await tester.pump();
    expect(find.text('Tutar müşterinin borcuna eklenecek.'), findsNothing);

    await tester.tap(find.text('Teslim Et ve Kaydet'));
    await akisiBekle(tester, ms: 300);

    late Order siparis;
    await tester.runAsync(() async {
      siparis = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
    });
    expect(siparis.paymentType, 'nakit',
        reason: 'müşterisiz veresiye kimseye ait olmayan borç kaydı olurdu');

    await ekraniKapat(tester);
  });

  testWidgets('veresiye seçilince uyarı çıkar ve teslimde deftere debit düşer', (tester) async {
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    late String orderId;
    late String musteriId;
    await tester.runAsync(() async {
      musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      orderId = await OrderRepository(db).create(customerId: musteriId, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2),
      ]);
    });

    await tester.pumpWidget(
        sipKabuk(OrderDetailScreen(db: db, orderId: orderId, writable: true)));
    await akisiBekle(tester);
    await tester.tap(find.text('Teslim Et'));
    await akisiBekle(tester);

    await tester.tap(find.text('Veresiye'));
    await tester.pump();
    // `.teslim-uyari`
    expect(find.text('Tutar müşterinin borcuna eklenecek.'), findsOneWidget);
    expect(find.text('Önce ödeme tipi seçin.'), findsNothing);

    await tester.tap(find.text('Teslim Et ve Kaydet'));
    await akisiBekle(tester, ms: 300);

    late List<LedgerEntry> defter;
    late Customer musteri;
    await tester.runAsync(() async {
      defter = await db.select(db.ledgerEntries).get();
      musteri =
          await (db.select(db.customers)..where((t) => t.id.equals(musteriId))).getSingle();
    });
    final borclar = defter.where((e) => e.entryType == 'debit').toList();
    expect(borclar, hasLength(1), reason: 'veresiye teslim TEK borç kaydı yazar');
    expect(borclar.single.amountKurus, 2 * 4500);
    expect(defter.where((e) => e.entryType == 'payment'), isEmpty,
        reason: 'veresiyede tahsilat YOK — borç açık kalır');
    expect(musteri.balanceKurus, 2 * 4500);

    await ekraniKapat(tester);
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Adres yazımı — CSS `.srow-adres` / `.sdx-adres`
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('AdresBilgi.tamMetin', () {
    test('adres ile bölge tire ile birleşir, boş/"—" değerler elenir', () {
      expect(
        const AdresBilgi(metin: 'Atatürk Cad. No:5', bolge: 'Merkez').tamMetin,
        'Atatürk Cad. No:5 — Merkez',
      );
      expect(const AdresBilgi(metin: 'Atatürk Cad. No:5').tamMetin, 'Atatürk Cad. No:5');
      expect(const AdresBilgi(metin: 'Atatürk Cad. No:5', bolge: '').tamMetin,
          'Atatürk Cad. No:5');
      expect(const AdresBilgi(metin: 'Atatürk Cad. No:5', bolge: '—').tamMetin,
          'Atatürk Cad. No:5',
          reason: 'tasarım "—" yer tutucusunu eler — kullanıcı "Adres — —" görmesin');
    });

    test('konum yalnız lat VE lng varken kayıtlı sayılır', () {
      expect(const AdresBilgi(metin: 'x', lat: 41.0082, lng: 28.9784).konumVar, isTrue);
      expect(const AdresBilgi(metin: 'x', lat: 41.0082).konumVar, isFalse);
      expect(const AdresBilgi(metin: 'x').konumMetni, '');
      expect(const AdresBilgi(metin: 'x', lat: 41.0082, lng: 28.9784).konumMetni,
          '41.0082, 28.9784');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Elle sıralama — CSS `.srow-grip`, `.elle-bant`; kalıcılık `orders.sort_index`
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('elle sıralama', () {
    test('elleSiraYazimi yalnız DEĞİŞEN siparişleri seyrek adımlarla döner', () {
      Order o(String id, int? sira) => Order(
            id: id,
            status: 'open',
            totalKurus: 0,
            sortIndex: sira,
            occurredAt: '2026-07-25T10:00:00Z',
          );
      final liste = [
        OrderListItem(order: o('a', 0)),
        OrderListItem(order: o('b', 99)), // yeri değişti
        OrderListItem(order: o('c', null)), // hiç sıralanmamış
      ];
      expect(elleSiraYazimi(liste), {'b': 10, 'c': 20});
    });

    test('siparisleriSirala: sürükleme sırası yoksa kalıcı sort_index geçerlidir', () {
      Order o(String id, int? sira) => Order(
            id: id,
            status: 'open',
            totalKurus: 0,
            sortIndex: sira,
            occurredAt: '2026-07-25T10:00:00Z',
          );
      final liste = [
        OrderListItem(order: o('a', 20)),
        OrderListItem(order: o('b', 0)),
        OrderListItem(order: o('c', null)),
        OrderListItem(order: o('d', 10)),
      ];
      expect(
        siparisleriSirala(liste, OrderSort.elle).map((i) => i.order.id),
        ['b', 'd', 'a', 'c'],
        reason: 'sıralanmamış (null) sipariş SONA gider — rotanın ortasına düşmesin',
      );
      // Sürükleme sırası varken o geçerlidir (iyimser güncelleme).
      expect(
        siparisleriSirala(liste, OrderSort.elle, elleSira: ['c', 'a', 'd', 'b'])
            .map((i) => i.order.id),
        ['c', 'a', 'd', 'b'],
      );
    });

    testWidgets('sürükle-bırak sonrası sıra orders.sortIndex olarak KALICI yazılır',
        (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      late String birinci;
      late String ikinci;
      await tester.runAsync(() async {
        final m1 = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        final m2 = await CustomerRepository(db).create(name: 'Mehmet Demir');
        ikinci = await OrderRepository(db).create(customerId: m2, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        // En yeni önce → başlangıçta birinci üstte.
        birinci = await OrderRepository(db).create(customerId: m1, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      // Sırala → Elle sırala.
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);
      await tester.tap(find.text(siralamaEtiketi(OrderSort.elle)));
      await akisiBekle(tester);

      // `.elle-bant` göründü, tutamaçlar çizildi. (Tutamaç semantik etiketi satırın birleşik
      // düğümüne karışıyor; sürükleme tanıyıcısının TİPİ üzerinden aranır.)
      expect(find.text('Tutamaçtan sürükleyip bırak, bitince “Bitti”ye bas.'), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));

      // İlk satırı ikincinin ALTINA sürükle. `ReorderableListView` hedefi her pointer olayında
      // yeniden hesaplar — tek sıçrayışlı `moveBy` yerine kademeli hareket gerekir.
      final satirlar = find.byType(SiparisSatiri);
      final baslangic = tester.getCenter(find.byType(ReorderableDragStartListener).first);
      final hedefY = tester.getCenter(satirlar.at(1)).dy + 20;

      final hareket = await tester.startGesture(baslangic);
      await tester.pump(const Duration(milliseconds: 300));
      final adim = (hedefY - baslangic.dy) / 10;
      for (var i = 1; i <= 10; i++) {
        await hareket.moveTo(Offset(baslangic.dx, baslangic.dy + adim * i));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await hareket.up();
      await akisiBekle(tester, ms: 600);

      late List<Order> siparisler;
      await tester.runAsync(() async {
        siparisler = await db.select(db.orders).get();
      });
      final sira = {for (final o in siparisler) o.id: o.sortIndex};
      expect(sira[ikinci], 0, reason: 'sürüklenen satır alta indi → diğeri başa geçti');
      expect(sira[birinci], 10);

      // Sıra kalıcı: yeniden okunan listede sort_index sırası geçerli.
      late List<OrderListItem> yeniden;
      await tester.runAsync(() async {
        yeniden = await watchOrders(db, OrderFilter.acik).first;
      });
      expect(siparisleriSirala(yeniden, OrderSort.elle).map((i) => i.order.id),
          [ikinci, birinci]);

      await ekraniKapat(tester);
    });

    testWidgets('salt-okunur kipte elle sıralama hiç sunulmaz', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        await OrderRepository(db).create(customerId: m, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: false)));
      await akisiBekle(tester);
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);

      expect(find.text(siralamaEtiketi(OrderSort.saat)), findsOneWidget);
      expect(find.text(siralamaEtiketi(OrderSort.elle)), findsNothing,
          reason: 'elle sıralama sort_set OLAYI yazar — salt-okunur kipte yasak');
      // `.sr-oto` tasarımda HEP görünür; salt-okunur kipte PASİF olur ve nedeni yazılır.
      // Görünürlük ≠ kullanılabilirlik: kapı korunur, yetenek gizlenmez.
      expect(find.text('Oto Sırala (rota)'), findsOneWidget);
      expect(find.text('Salt-okunur kip: sıra kaydedilemez.'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('hak BİLİNMİYORKEN "Oto Sırala" pasif çizilir, sahte kontör yazmaz',
        (tester) async {
      // Kontör sunucu sahiplidir; token yokken kalan hak bilinemez. Düğmeyi hiç çizmemek
      // yeteneği gizliyordu (kullanıcı böyle bir şeyin varlığını öğrenemiyordu); uydurma bir
      // sayı yazmak ise tıklayınca 409 yiyen bir düğme demekti. Orta yol: düğme görünür,
      // kontör YAZILMAZ, dokunma kapalı ve nedeni altında durur.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        await OrderRepository(db).create(customerId: m, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);

      expect(find.text(siralamaEtiketi(OrderSort.elle)), findsOneWidget,
          reason: 'elle sıralama çevrimdışı çalışır, o hep sunulur');
      // TAM eşleşme: etikette " · N hak" eki YOK — kontör bilinmiyorken sayı yazılmaz.
      expect(find.text('Oto Sırala (rota)'), findsOneWidget);
      expect(find.text('Hak bilgisi bekleniyor — ilk senkrondan sonra kullanılabilir.'),
          findsOneWidget);

      // Pasif düğmeye dokunmak sheet'i kapatmaz (eylem hiç tetiklenmez).
      await tester.tap(find.text('Oto Sırala (rota)'));
      await akisiBekle(tester);
      expect(find.text('Sıralama'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('oturum ve hak varken "Oto Sırala (rota) · N hak" düğmesi çizilir',
        (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        await OrderRepository(db).create(customerId: m, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
        // Sunucu sahipli alanlar senkronla iner; testte doğrudan önbelleğe yazılır.
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
          const SyncMetaCompanion(
            authToken: Value('test-token'),
            routeCredits: Value(34),
            routeCreditsMonthly: Value(50),
          ),
        );
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);

      // Tasarım `.sr-oto`: "Oto Sırala (rota) · 34 hak"
      expect(find.text('Oto Sırala (rota) · 34 hak'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('kontör ekran AÇILDIKTAN SONRA senkronla gelince düğme güncellenir',
        (tester) async {
      // CİHAZDA YAKALANAN GERİLEME: kalan hak `initState`te TEK ATIŞ okunuyordu. Kontör giriş
      // yanıtında GELMEZ, ilk senkron yazar — dolayısıyla ekran girişten hemen sonra 0 görüp
      // sonsuza dek "0 hak" gösteriyordu (sunucuda 34 vardı). Artık akışa abone.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        await OrderRepository(db).create(customerId: m, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
        // Oturum var ama kontör HENÜZ gelmedi (senkron olmadı) → varsayılan 0.
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
            .write(const SyncMetaCompanion(authToken: Value('test-token')));
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      // Senkron GELİR ve sunucu sahipli alanı yazar — ekran açıkken.
      await tester.runAsync(() async {
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
          const SyncMetaCompanion(routeCredits: Value(34), routeCreditsMonthly: Value(50)),
        );
      });
      await akisiBekle(tester);

      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);

      expect(find.text('Oto Sırala (rota) · 34 hak'), findsOneWidget,
          reason: 'kontör senkronla gelince düğme tazelenmeli — "0 hak"ta donmamalı');
      expect(find.textContaining('0 hak'), findsNothing);

      await ekraniKapat(tester);
    });
  });
}
