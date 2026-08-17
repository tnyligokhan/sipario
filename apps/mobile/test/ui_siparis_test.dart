// Sipariş ekranları (yeniden tasarım) — liste, yeni sipariş, teslim & ödeme, elle sıralama.
// Tasarım kaynağı: tasarım s-siparisler.jsx + Sipario.html `.srow*`/`.ys-*`/`.odeme-*`.
//
// DESEN: sorgu/hesap mantığı ekrandan bağımsız saf fonksiyonlarda sınanır (drift akışları
// widget-test sahte zamanında güvenilmez — Dilim 1 dersi); yalnız GÖRÜNÜM sözleşmesi ve
// dokunma akışları widget testine kalır. Widget testlerinde drift'in gerçek zamanı gerektiği
// için `tester.runAsync` kullanılır ve akışa abone DB `close()` EDİLMEZ (abone stream hata atar).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/orders/gecen_sure_pili.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/siparis_yardimci.dart';

/// SİPARİŞ — LİSTE ve DETAY.
///
/// DOSYA ÜÇE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 862 satırdı): yeni sipariş formu
/// `ui_siparis_form_test.dart`ta, teslim/ödeme ve elle sıralama `ui_siparis_teslim_test.dart`ta.
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

}
