// Kısmi ödeme + borç tahsilatının EKRAN akışları (saha eksikleri 7 ve 5b). Kural/defter katmanı
// `ui_kismi_odeme_test.dart`te — ikisi tek dosyada 500 satırı aşıyordu.
//
// Burada sınanan üç şey: teslim sheet'inde tahsilat tutarının gerçekten DÜZENLENEBİLİR olması,
// `borcTahsilatiAc`ın yalnız müşteri kimliğiyle açılabilmesi, ve sipariş detayındaki "Tahsilat Al"
// eyleminin görünürlük kuralları (müşterisizde yok, salt-okunurda görünür ama yazmaz).
//
// KOŞUM KURALLARI (Dilim 1-3 dersleri): drift akışları GERÇEK zamanda dolar → her sorgu
// `tester.runAsync` içinde beklenir; akışa abone db widget-testte KAPATILMAZ; sheet açılış
// animasyonu bitirilmeden `tap` ekranın dışına ıskalar.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/customers/customer_sheets.dart';
import 'package:sipario/screens/orders/delivery_sheet.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';

import 'support/ekran_yardimcilari.dart';
import 'support/siparis_yardimci.dart';

Future<Customer> _musteri(AppDatabase db, String id) =>
    (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();

Future<List<LedgerEntry>> _defter(AppDatabase db, String customerId) =>
    (db.select(db.ledgerEntries)..where((t) => t.customerId.equals(customerId))).get();

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Teslim sheet — widget akışı
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('teslimSheetAc (tahsil edilen tutar DÜZENLENEBİLİR)', () {
    testWidgets('tutar sipariş toplamıyla ön dolu gelir; elle azaltılınca kısmi sonuç döner',
        (tester) async {
      TeslimSonucu? sonuc;
      await ekranaKoy(
        tester,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () async {
                  sonuc = await teslimSheetAc(ctx, toplamKurus: 20000, musteriVar: true);
                },
                child: const Text('teslim-ac'),
              ),
            ),
          ),
        ),
      );

      await dokun(tester, find.text('teslim-ac'));
      await sheetAnimasyonu(tester);

      // Ön dolgu tam tutardır: teslimlerin çoğu tam tahsilat, kısmi olan istisnadır.
      expect(find.widgetWithText(TextField, '200,00'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '120');
      await akislariBekle(tester);
      expect(find.textContaining('borcuna yazılacak'), findsOneWidget,
          reason: 'kısmi tahsilatta kalanın borca yazılacağı kullanıcıya söylenir');

      await dokun(tester, find.text('Teslim Et ve Kaydet'));
      await sheetAnimasyonu(tester);

      expect(sonuc, isNotNull);
      expect(sonuc!.odemeTipi, 'nakit');
      expect(sonuc!.tahsilKurus, 12000);
      await kapat(tester);
    });

    testWidgets('tutar 0 yazılırsa kayıt VERESİYE düşer (nakit karosu seçili olsa bile)',
        (tester) async {
      TeslimSonucu? sonuc;
      await ekranaKoy(
        tester,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () async {
                  sonuc = await teslimSheetAc(ctx, toplamKurus: 20000, musteriVar: true);
                },
                child: const Text('teslim-ac'),
              ),
            ),
          ),
        ),
      );

      await dokun(tester, find.text('teslim-ac'));
      await sheetAnimasyonu(tester);
      await tester.enterText(find.byType(TextField).first, '0');
      await akislariBekle(tester);
      await dokun(tester, find.text('Teslim Et ve Kaydet'));
      await sheetAnimasyonu(tester);

      expect(sonuc!.tahsilKurus, 0);
      expect(sonuc!.odemeTipi, 'veresiye',
          reason: 'sıfır tahsilatlı "nakit" kaydı kasa özetiyle sipariş listesini çelişkiye düşürür');
      await kapat(tester);
    });

    testWidgets('tezgâh satışında (müşterisiz) tahsilat alanı kilitlidir', (tester) async {
      await ekranaKoy(
        tester,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => teslimSheetAc(ctx, toplamKurus: 20000, musteriVar: false),
                child: const Text('teslim-ac'),
              ),
            ),
          ),
        ),
      );

      await dokun(tester, find.text('teslim-ac'));
      await sheetAnimasyonu(tester);

      final alan = tester.widget<TextField>(find.byType(TextField).first);
      expect(alan.enabled, isFalse,
          reason: 'eksiğini yazacak da fazlasını alacak yazacak bir cari yok');
      await kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Borç tahsilatı — widget akışı (5b giriş noktası)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('borcTahsilatiAc (yalnız customerId ile çağrılabilir giriş noktası)', () {
    testWidgets('borçlu müşteriden kısmi tahsilat deftere payment olarak düşer', (tester) async {
      // Akış-abonelikli drift db'si widget-testte KAPATILMAZ (Dilim 1 dersi).
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Borçlu Müşteri');
        await LedgerRepository(db).borcEkle(cid, 50000);
      });

      bool? sonuc;
      await ekranaKoy(
        tester,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () async {
                  sonuc = await borcTahsilatiAc(ctx, db: db, customerId: cid);
                },
                child: const Text('tahsilat-ac'),
              ),
            ),
          ),
        ),
      );

      await dokun(tester, find.text('tahsilat-ac'));
      await sheetAnimasyonu(tester);

      // Sheet başlığı müşterinin adıdır: borçlu listesinden gelen kullanıcının arkasında
      // hangi kaydı işlediğini gösteren bir ekran yok.
      expect(find.text('Borçlu Müşteri'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '200');
      await akislariBekle(tester);
      await dokun(tester, find.text('Tahsilatı Kaydet'));
      await sheetAnimasyonu(tester);

      expect(sonuc, isTrue);
      await tester.runAsync(() async {
        expect((await _musteri(db, cid)).balanceKurus, 30000,
            reason: '500 ₺ borcun 200 ₺si tahsil edildi, 300 ₺ borç kaldı');
        final odeme = (await _defter(db, cid)).firstWhere((e) => e.entryType == 'payment');
        expect(odeme.amountKurus, -20000);
      });
      await kapat(tester);
    });

    testWidgets('açık borçtan fazlası uyarı verir ama ENGELLENMEZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Fazla Ödeyen');
        await LedgerRepository(db).borcEkle(cid, 50000);
      });

      await ekranaKoy(
        tester,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => borcTahsilatiAc(ctx, db: db, customerId: cid),
                child: const Text('tahsilat-ac'),
              ),
            ),
          ),
        ),
      );

      await dokun(tester, find.text('tahsilat-ac'));
      await sheetAnimasyonu(tester);
      await tester.enterText(find.byType(TextField).first, '600');
      await akislariBekle(tester);

      expect(find.textContaining('alacaklı duruma geçecek'), findsOneWidget);

      await dokun(tester, find.text('Tahsilatı Kaydet'));
      await sheetAnimasyonu(tester);

      await tester.runAsync(() async {
        expect((await _musteri(db, cid)).balanceKurus, -10000,
            reason: 'fazlası correction ile değil, payment ile deftere girer — kasa doğru kalır');
      });
      await kapat(tester);
    });

    // ═══════════════════════════════════════════════════════════════════════════════════════
    // Sipariş detayındaki "Tahsilat Al" — Borçlu sekmesinin tahsilat yolu
    // ═══════════════════════════════════════════════════════════════════════════════════════

    testWidgets('TESLİM EDİLMİŞ veresiye siparişte "Tahsilat Al" görünür ve borcu tahsil eder',
        (tester) async {
      // Asıl kullanım anı bu: veresiye teslim edilmiş sipariş, müşteri sonradan ödüyor.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      late String oid;
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Veresiyeli Teslim');
        oid = await OrderRepository(db).create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 20000, qty: 1)],
        );
        await OrderRepository(db).deliver(oid, paymentType: 'veresiye');
      });

      await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
      await akisiBekle(tester);

      // Düğme TUTARI DA YAZAR (2026-07-29): eskiden borcu görmenin tek yolu düğmeye basıp
      // sheet'i açmaktı — bayi rakamı öğrenmek için bir para yazma akışına giriyordu.
      expect(find.text('Tahsilat Al (200,00 ₺)'), findsOneWidget,
          reason: 'teslim edilmiş siparişte de görünür — tahsilat sipariş durumundan bağımsız');
      // Kalan borç ayrıca kutuda yazar (`.sd-odendi`nin borç eşi).
      expect(find.text('Bu siparişten kalan borç 200,00 ₺'), findsOneWidget);

      await tester.tap(find.textContaining('Tahsilat Al'));
      await akisiBekle(tester, ms: 300);
      expect(find.text('Veresiyeli Teslim'), findsWidgets, reason: 'sheet başlığı müşteri adı');

      await tester.enterText(find.byType(TextField).first, '120');
      await akisiBekle(tester);
      await tester.tap(find.text('Tahsilatı Kaydet'));
      await akisiBekle(tester, ms: 300);

      await tester.runAsync(() async {
        expect((await _musteri(db, cid)).balanceKurus, 8000,
            reason: '200 ₺ borcun 120 ₺si tahsil edildi');
      });

      await ekraniKapat(tester);
    });

    testWidgets('tezgâh (müşterisiz) siparişte "Tahsilat Al" HİÇ çizilmez', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      late String oid;
      await tester.runAsync(() async {
        oid = await OrderRepository(db).create(
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 20000, qty: 1)],
        );
      });

      await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
      await akisiBekle(tester);

      expect(find.textContaining('Tahsilat Al'), findsNothing,
          reason: 'tahsilatın muhatabı olan cari HİÇ yok — pasif düğme de yanıltıcı olurdu');

      await ekraniKapat(tester);
    });

    testWidgets('salt-okunur kipte "Tahsilat Al" kayıt oluşturmaz ve sebebini söyler',
        (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      late String oid;
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Kilitli Bayi');
        await LedgerRepository(db).borcEkle(cid, 50000);
        oid = await OrderRepository(db).create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 20000, qty: 1)],
        );
      });

      await tester
          .pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: false)));
      await akisiBekle(tester);

      // Düğme GÖRÜNÜR kalır ve kilidin sebebini söyler (Dilim 3 kararı: ana eylemler gizlenmez).
      expect(find.text('Tahsilat Al (500,00 ₺)'), findsOneWidget);
      await tester.tap(find.textContaining('Tahsilat Al'));
      await akisiBekle(tester, ms: 300);

      expect(find.text('Aboneliğiniz sona erdiği için yeni kayıt eklenemiyor'), findsOneWidget);
      expect(find.text('Tahsilatı Kaydet'), findsNothing, reason: 'sheet hiç açılmamalı');

      await tester.runAsync(() async {
        final odemeler = await (db.select(db.ledgerEntries)
              ..where((e) => e.entryType.equals('payment')))
            .get();
        expect(odemeler, isEmpty);
      });

      await ekraniKapat(tester);
    });

    testWidgets('borcu olmayan müşteride tahsilat formu çizilmez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Temiz Müşteri');
      });

      await ekranaKoy(
        tester,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => borcTahsilatiAc(ctx, db: db, customerId: cid),
                child: const Text('tahsilat-ac'),
              ),
            ),
          ),
        ),
      );

      await dokun(tester, find.text('tahsilat-ac'));
      await sheetAnimasyonu(tester);

      expect(find.text('Bu müşterinin açık borcu yok'), findsOneWidget);
      expect(find.text('Tahsilatı Kaydet'), findsNothing);
      await kapat(tester);
    });
  });
}
