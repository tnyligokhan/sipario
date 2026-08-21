// BORÇ GÖRÜNÜRLÜĞÜ — saha bulgusu 2026-07-29.
//
// İki şikâyet, tek kök: borç RAKAMI hiçbir listede yazmıyordu.
//  1. "Borçlu sekmesinde sipariş teslim edildikten sonra borç rakamı görünmüyor; tahsil et
//     diyene kadar borcu göremiyoruz."
//  2. Ana ekrandaki "Açık Veresiye" kutusu toplam bir rakam yazıp müşteriler sekmesine
//     gidiyordu — borçlusu olmayan yüzlerce kaydın arasına.
//
// Saf kurallar (`siparisKalanBorcu`, `borcluListesiKur`) widget kurmadan sınanır; ekran testleri
// yalnız o kuralların YÜZEYE çıktığını doğrular.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/customers/borclular_ekrani.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/order_queries.dart';

import 'support/kabuk_yardimcilari.dart';
import 'support/siparis_yardimci.dart';
import 'support/yetki_yardimcilari.dart';

void main() {
  group('siparisKalanBorcu — saf kural', () {
    test('teslim edilmemiş sipariş borç DEĞİLDİR', () {
      // Deftere borç teslim anında yazılır; açık siparişi borç saymak henüz doğmamış bir
      // alacağı raporlamak olurdu (2026-07-27 kararının aynısı).
      expect(
        siparisKalanBorcu(durum: 'open', toplamKurus: 20000, tahsilKurus: 0),
        0,
      );
      expect(
        siparisKalanBorcu(durum: 'cancelled', toplamKurus: 20000, tahsilKurus: 0),
        0,
      );
    });

    test('veresiye teslimde tutarın tamamı borçtur', () {
      expect(
        siparisKalanBorcu(durum: 'delivered', toplamKurus: 20000, tahsilKurus: 0),
        20000,
      );
    });

    test('kısmi ödemede yalnız KALAN borçtur — sipariş tutarı değil', () {
      // Şikâyetin özü: satır 200 ₺ yazarken borç 80 ₺ olabiliyor.
      expect(
        siparisKalanBorcu(durum: 'delivered', toplamKurus: 20000, tahsilKurus: 12000),
        8000,
      );
    });

    test('fazla tahsilat siparişin borcunu EKSİYE çevirmez', () {
      // Fazlası müşterinin önceki borcunu kapatır ve müşteri bakiyesinde görünür; siparişe
      // "−50 ₺ borç" yazmak yanlış yerde doğru sayı göstermek olurdu.
      expect(
        siparisKalanBorcu(durum: 'delivered', toplamKurus: 20000, tahsilKurus: 25000),
        0,
      );
    });
  });

  group('borcluListesiKur — saf kural', () {
    Order siparis(String id, String musteriId, int tutar, {String durum = 'delivered'}) => Order(
          id: id,
          customerId: musteriId,
          status: durum,
          totalKurus: tutar,
          occurredAt: '2026-07-29T10:00:00Z',
        );

    Customer musteri(String id, String ad, int bakiye) => Customer(
          id: id,
          name: ad,
          balanceKurus: bakiye,
          updatedOccurredAt: '2026-07-29T10:00:00Z',
        );

    test('ödenmiş ve teslim edilmemiş siparişler listeye girmez', () {
      final liste = borcluListesiKur(
        [musteri('m1', 'Ayşe', 8000)],
        [
          siparis('o1', 'm1', 20000), // 120 ₺ tahsil → 80 ₺ kalan
          siparis('o2', 'm1', 5000), // tamamı ödenmiş
          siparis('o3', 'm1', 9000, durum: 'open'), // henüz borç değil
        ],
        {'o1': 12000, 'o2': 5000},
      );

      expect(liste, hasLength(1));
      expect(liste.single.siparisler.map((s) => s.order.id), ['o1']);
      expect(liste.single.siparisler.single.kalanKurus, 8000);
    });

    test('borcu sipariş dışı olan müşteri LİSTEDE KALIR', () {
      // Elle düzeltme/sipariş dışı borç: kartı düşürmek borcu görünmez yapardı.
      final liste = borcluListesiKur([musteri('m1', 'Ayşe', 5000)], const [], const {});
      expect(liste.single.siparisler, isEmpty);
      expect(liste.single.borcKurus, 5000);
    });

    test('siparişlere bağlanamayan fark AYRI hesaplanır', () {
      final liste = borcluListesiKur(
        [musteri('m1', 'Ayşe', 30000)],
        [siparis('o1', 'm1', 20000)],
        const {},
      );
      expect(liste.single.siparisToplami, 20000);
      expect(liste.single.farkKurus, 10000, reason: '100 ₺ sipariş dışı borç');
    });

    test('bakiye sipariş toplamından küçükse fark 0 sayılır (negatif yazılmaz)', () {
      final liste = borcluListesiKur(
        [musteri('m1', 'Ayşe', 5000)],
        [siparis('o1', 'm1', 20000)],
        const {},
      );
      expect(liste.single.farkKurus, 0);
    });
  });

  group('Sipariş listesi — kalan borç pili', () {
    testWidgets('veresiye teslim edilmiş siparişte borç TUTARI satırda yazar', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Veresiyeli');
        final oid = await OrderRepository(db).create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 20000, qty: 1)],
        );
        await OrderRepository(db).deliver(oid, paymentType: 'veresiye');
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.text('Borçlu'));
      await akisiBekle(tester);

      expect(find.text('Borç 200,00 ₺'), findsOneWidget,
          reason: 'teslimden sonra borç rakamı satırda görünmeli (saha şikâyeti)');

      await ekraniKapat(tester);
    });

    testWidgets('kısmi ödemede pil SİPARİŞ TUTARINI değil kalanı yazar', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Yarım Ödeyen');
        final oid = await OrderRepository(db).create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 20000, qty: 1)],
        );
        await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: 12000);
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Borçlu'));
      await akisiBekle(tester);

      expect(find.text('Borç 80,00 ₺'), findsOneWidget);
      expect(find.text('Borç 200,00 ₺'), findsNothing,
          reason: 'sipariş tutarı ile borç ayrı büyüklüklerdir');

      await ekraniKapat(tester);
    });
  });

  group('Borçlular ekranı', () {
    testWidgets('yalnız borçlu müşteriler ve ödenmemiş siparişleri listelenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final borclu = await CustomerRepository(db).create(name: 'Borçlu Bayi');
        final temiz = await CustomerRepository(db).create(name: 'Temiz Hesap');
        final oid = await OrderRepository(db).create(
          customerId: borclu,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 20000, qty: 1)],
        );
        await OrderRepository(db).deliver(oid, paymentType: 'veresiye');
        // Temiz müşteri teslim alıp ödedi — listeye HİÇ girmemeli.
        final oid2 = await OrderRepository(db).create(
          customerId: temiz,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 5000, qty: 1)],
        );
        await OrderRepository(db).deliver(oid2, paymentType: 'nakit', tahsilKurus: 5000);
      });

      await ekranaKoy(tester, BorclularEkrani(db: db, writable: true, yetki: tamYetki));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();

      expect(find.text('Borçlu Bayi'), findsOneWidget);
      expect(find.text('Temiz Hesap'), findsNothing,
          reason: 'ekranın tamamı borçlulara ayrılmıştır');
      expect(find.text('1 müşteri, toplam 200,00 ₺'), findsOneWidget);
      expect(find.text('Tahsilat Al (200,00 ₺)'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('borcu sipariş dışı olan müşteride sebep YAZILIR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Defter Borcu');
        await LedgerRepository(db).borcEkle(cid, 7500);
      });

      await ekranaKoy(tester, BorclularEkrani(db: db, writable: true, yetki: tamYetki));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();

      expect(find.text('Ödenmemiş sipariş yok — borç defter kaydından geliyor.'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('borçlu yokken nötr boş durum çizilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(tester, BorclularEkrani(db: db, writable: true, yetki: tamYetki));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();

      expect(find.text('Borçlu yok'), findsOneWidget);

      await kapat(tester);
    });
  });
}
