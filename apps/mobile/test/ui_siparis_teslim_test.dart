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
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/order_row.dart';

import 'support/siparis_yardimci.dart';

/// SİPARİŞ — TESLİM/ÖDEME · adres metni · ELLE SIRALAMA.
///
/// Bölme gerekçesi: `ui_siparis_test.dart` başlığı.
void main() {
  _kartUzerindenTeslim();

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
        find.text('Tezgâh satışında veresiye yazılamaz, kayıtlı müşteri gerekir'),
        findsOneWidget);

    // Dokunuş YUTULUR: uyarı şeridi çıkmaz, seçim nakitte kalır.
    await tester.tap(find.text('Veresiye'));
    await tester.pump();
    expect(find.text('Tutar müşterinin borcuna eklenecek'), findsNothing);

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
    expect(find.text('Tutar müşterinin borcuna eklenecek'), findsOneWidget);
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
        'Atatürk Cad. No:5, Merkez',
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
      expect(find.text('Tutamaçtan sürükleyip bırakın, bitince "Bitti"ye dokunun'), findsOneWidget);
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
      // "Rota sırası" salt-okunur kipte de SUNULUR: seçmek hiçbir şey yazmaz, yalnız kalıcı
      // sırayı gösterir. Elle kipinin kapısını ona da uygulamak, yazmayan bir görünümü
      // gereksiz yere kilitlemek olurdu.
      expect(find.text(siralamaEtiketi(OrderSort.rota)), findsOneWidget);
      // Oto sıralama düğmesi ARTIK BU SHEET'TE DEĞİL (2026-08-01: haritaya taşındı).
      expect(find.textContaining('Oto Sırala'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('"Rota sırası" kalıcı sort_index sırasını TUTAMAÇSIZ gösterir',
        (tester) async {
      // Oto sıralamadan sonra ekran ELLE kipine düşüyordu; kullanıcı sonucu görmek isterken
      // kendini bir düzenleme kipinde buluyordu ("oto sıralamadan sonra tekrar elle sıralama
      // alanı geliyor, mantıksız"). "Rota sırası" aynı sırayı gösterir, hiçbir şey yazmaz.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = OrderRepository(db);
        // Yazılma sırası: Ayşe önce, Mehmet sonra → saat sırasında Mehmet üstte.
        final m1 = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        final ilk = await repo.create(customerId: m1, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final m2 = await CustomerRepository(db).create(name: 'Mehmet Demir');
        final ikinci = await repo.create(customerId: m2, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
        // Rota sırası saat sırasının TERSİ olsun ki gerçekten sort_index okunduğu görülsün.
        await repo.setSortIndex(ilk, 0);
        await repo.setSortIndex(ikinci, 10);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      // Saat sırasında en yeni (Mehmet) üstte.
      expect(tester.getCenter(find.text('Mehmet Demir')).dy,
          lessThan(tester.getCenter(find.text('Ayşe Yılmaz')).dy));

      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);
      await tester.tap(find.text(siralamaEtiketi(OrderSort.rota)));
      await akisiBekle(tester);

      // Rota sırasında sort_index geçerli → Ayşe üstte.
      expect(tester.getCenter(find.text('Ayşe Yılmaz')).dy,
          lessThan(tester.getCenter(find.text('Mehmet Demir')).dy));
      // ASIL SÖZLEŞME: bu bir GÖRÜNÜM, düzenleme kipi değil.
      expect(find.byType(ReorderableDragStartListener), findsNothing,
          reason: 'rota görünümünde tutamaç YOKTUR — kullanıcı düzenlemek istemedi');
      expect(find.text('Tutamaçtan sürükleyip bırakın, bitince "Bitti"ye dokunun'), findsNothing);
      expect(find.text('Bitti'), findsNothing, reason: 'elle kipi açılmadı');

      await ekraniKapat(tester);
    });

    test('siparisleriSirala: rota kipi sürükleme sırasını GÖRMEZDEN gelir', () {
      // `rota` yalnız gösterir: iyimser bir düzenleme durumu taşımaz. Elle kipi ise sürükleme
      // sırası boşken aynı sort_index'ten başlar — rotanın üstünden ince ayar yapılabilsin.
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
        siparisleriSirala(liste, OrderSort.rota, elleSira: ['c', 'a', 'd', 'b'])
            .map((i) => i.order.id),
        ['b', 'd', 'a', 'c'],
        reason: 'sürükleme sırası verilse bile rota kalıcı sort_index\'i gösterir',
      );
      expect(
        siparisleriSirala(liste, OrderSort.elle).map((i) => i.order.id),
        siparisleriSirala(liste, OrderSort.rota).map((i) => i.order.id),
        reason: 'elle kipi rotanın bıraktığı yerden başlar',
      );
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// LİSTE KARTINDAN TESLİM — dördüncü eylem düğmesi (2026-08-18)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Teslim artık İKİ yerden başlıyor: sipariş detayı ve liste kartının eylem şeridi. İkisi de
/// `TeslimAkisi` üzerinden geçer — ama "aynı akışı çağırıyorlar" iddiası, düğmenin GERÇEKTEN
/// çizildiği ve akışı GERÇEKTEN başlattığı doğrulanmadan bir şey ifade etmez. Bu depoda tam
/// olarak bu boşluk bir kez ödendi: kapının kendi testleri yeşilken ekranın ona bağlanmayı
/// unutması sahada yetki arızası olarak göründü (`ui_rol_kapisi_test.dart`).
void _kartUzerindenTeslim() {
  group('liste kartı — "Teslim Et" düğmesi', () {
    testWidgets('AÇIK siparişte şeridin EN SAĞINDA çizilir ve teslim sheet\'ini açar',
        (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      late String orderId;
      await tester.runAsync(() async {
        final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        orderId = await OrderRepository(db).create(customerId: musteriId, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2),
        ]);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      // EN SAĞDA olmak sözleşmenin parçası (kullanıcı isteği: "WhatsApp/Ara butonları gibi
      // teslim et butonu en sağ"). Sıra, düğmelerin ekrandaki yatay konumuyla doğrulanır —
      // widget ağacındaki sıra Row içinde de olsa yeterli kanıt değildir.
      final teslimX = tester.getCenter(find.text('Teslim Et')).dx;
      for (final onceki in ['Ara', 'WhatsApp', 'Konum']) {
        expect(tester.getCenter(find.text(onceki)).dx, lessThan(teslimX),
            reason: '"$onceki" teslim düğmesinin SOLUNDA kalmalı');
      }

      await tester.tap(find.text('Teslim Et'));
      await akisiBekle(tester);
      // Sheet açıldı: kaydetme düğmesi ancak orada var.
      expect(find.text('Teslim Et ve Kaydet'), findsOneWidget);

      await tester.tap(find.text('Teslim Et ve Kaydet'));
      await akisiBekle(tester, ms: 300);

      late Order siparis;
      await tester.runAsync(() async {
        siparis =
            await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
      });
      expect(siparis.status, 'delivered',
          reason: 'liste kartından teslim, detaydakiyle AYNI yazmayı yapmalı');

      await ekraniKapat(tester);
    });

    testWidgets('SALT-OKUNUR kipte düğme HİÇ çizilmez, diğer üçü kalır', (tester) async {
      // Teslim bir YAZMADIR; abonelik kapalıyken hiçbir teslim kaydedilemez. Düğmeyi çizip
      // dokunuşta reddetmek, gerekçeyi zaten söyleyen sipariş detayının işini tekrarlardı.
      // Ara/WhatsApp/Konum ise okuma değil HARİCİ eylemdir — onlar kalmalı.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        await OrderRepository(db).create(customerId: musteriId, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: false)));
      await akisiBekle(tester);

      expect(find.text('Teslim Et'), findsNothing);
      expect(find.text('Ara'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('360 dp telefonda DÖRT düğme yan yana TAŞMAZ', (tester) async {
      // Şerit üçten dörde çıktı ve en dar yaygın Android telefonda düğme başına ~68 px kalıyor.
      // `_EylemDugmesi.sikisik` ikonu, arayı ve puntoyu tam bu yüzden küçültüyor; ölçü yanlışsa
      // `RenderFlex overflow` burada HATA olarak yükselir.
      //
      // ⚠️ WIDGET TEST FONTU GERÇEK CİHAZDAN ~1.8 KAT GENİŞ çizer, yani bu sınama sahadakinden
      // AĞIRDIR: geçtiği takdirde gerçek telefonda da geçer. Tersi doğru değildir — burada
      // etiketin üç noktaya düşmesi tek başına cihaz kanıtı sayılmaz.
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final musteriId = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
        await OrderRepository(db).create(customerId: musteriId, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('Teslim Et'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'dört düğme 360 dp\'de taşmamalı');

      await ekraniKapat(tester);
    });

    testWidgets('MÜŞTERİSİZ (tezgâh) siparişte tek başına çizilir', (tester) async {
      // Eylem şeridi müşterisiz siparişte HİÇ çizilmez (aranacak kimse yok) — ama teslimin
      // müşteriyle işi yoktur. Şeridi çizip üç düğmeyi pasifleştirmek, asla dolmayacak üç boş
      // kutu göstermek olurdu.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await OrderRepository(db).create(lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('Teslim Et'), findsOneWidget);
      expect(find.text('Ara'), findsNothing, reason: 'aranacak müşteri yok');

      await ekraniKapat(tester);
    });
  });
}
