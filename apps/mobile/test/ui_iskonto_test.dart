// KAPIDA İSKONTO — "420 liralık siparişte 400 lira ödeme alınabilir; 'borçlu gösterme' kutusu
// olması gerekiyor" (kullanıcı isteği 2026-07-30).
//
// Kısmi tahsilat bu depoda zaten yazılabiliyordu ama TEK anlamı vardı: kalan BORÇTUR. İskonto
// aynı farkın İKİNCİ anlamıdır (kırıldı, kimse borçlu değil) ve ikisini ayıran şey kullanıcının
// işaretlediği anahtardır. Bu dosya o ayrımın DÖRT katmanda birden tuttuğunu kanıtlar:
//   1. saf kural       — anahtar ne zaman sorulur, ne kadar iskonto yazılır,
//   2. defter          — debit(+420) · payment(−400) · discount(−20), bakiye 0, append-only,
//   3. muhasebe        — kasa 400 görür (iskonto `payment_type` taşımaz), gün sonu 20 iskonto,
//   4. ekran           — anahtarın metni ve görünme koşulu, gün sonu kartındaki satır.
//
// ÜÇÜNCÜSÜ ÖZELLİĞİN BÜTÜN SEBEBİDİR: kırılan 20 ₺ kasaya HİÇ girmedi. `payment` yazsaydık kasa
// her iskontoda 20 ₺ şişer, bayi sayımda eksik bulur ve o fark KANIT olmaktan çıkıp gürültüye
// dönerdi (DECISIONS: gün sonu farkı append-only kanıttır).
//
// KOŞUM KURALLARI (Dilim 1-3 dersleri): drift sorguları `tester.runAsync` içinde beklenir; akışa
// abone db widget-testte KAPATILMAZ; sheet açılış animasyonu bitmeden `tap` ekranın dışına ıskalar.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/isletme/gun_arsivi.dart';
import 'package:sipario/screens/orders/delivery_sheet.dart';
import 'package:sipario/screens/orders/order_queries.dart';

import 'support/ekran_yardimcilari.dart';

/// Kullanıcının verdiği örnek: 420 ₺lik sipariş, 400 ₺ tahsilat, 20 ₺ iskonto.
const _siparis = 42000;
const _tahsil = 40000;
const _iskonto = 2000;

Future<Customer> _musteri(AppDatabase db, String id) =>
    (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();

Future<List<LedgerEntry>> _defter(AppDatabase db, String customerId) =>
    (db.select(db.ledgerEntries)..where((t) => t.customerId.equals(customerId))).get();

/// 420 ₺lik siparişi olan bir müşteri kurar.
Future<(AppDatabase, String, String)> _kur({int tutar = _siparis}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final cid = await CustomerRepository(db).create(name: 'İskontolu Müşteri');
  final oid = await OrderRepository(db).create(
    customerId: cid,
    lines: [LineInput(productName: 'Damacana', unitPriceKurus: tutar, qty: 1)],
  );
  return (db, cid, oid);
}

/// Teslim sheet'ini tek başına açan iskele (arkadaki ekranın alanları TextField sırasına karışmasın).
Future<void> _sheetiAc(
  WidgetTester tester,
  void Function(TeslimSonucu?) al, {
  int toplam = _siparis,
  bool musteriVar = true,
}) async {
  await ekranaKoy(
    tester,
    Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: TextButton(
            onPressed: () async =>
                al(await teslimSheetAc(ctx, toplamKurus: toplam, musteriVar: musteriVar)),
            child: const Text('teslim-ac'),
          ),
        ),
      ),
    ),
  );
  await dokun(tester, find.text('teslim-ac'));
  await sheetAnimasyonu(tester);
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 1) Saf kurallar — widget kurmadan
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('teslimIskontoSorulur (anahtar yalnız EKSİK tahsilatta belirir)', () {
    bool sorulur(int? tahsil) =>
        teslimIskontoSorulur(tahsilKurus: tahsil, toplamKurus: _siparis);

    test('tutar sipariş tutarının altındaysa sorulur', () => expect(sorulur(_tahsil), isTrue));

    test('tam tahsilatta sorulmaz — kırılan bir şey yok', () {
      expect(sorulur(_siparis), isFalse);
    });

    test('fazla tahsilatta sorulmaz — fazlası önceki borcu kapatır, iskonto değildir', () {
      expect(sorulur(50000), isFalse);
    });

    test('sıfır tahsilatta sorulur — tamamı kırılabilir (ikram)', () {
      expect(sorulur(0), isTrue);
    });

    test('okunamayan yazımda sorulmaz — bilinmeyen tutara iskonto kararı verilemez', () {
      expect(sorulur(null), isFalse);
    });
  });

  group('teslimIskontoKurus (kapalı anahtar mevcut davranıştır)', () {
    test('anahtar kapalıyken DAİMA 0 — kalan borç olarak yazılır', () {
      expect(
          teslimIskontoKurus(
              toplamKurus: _siparis, tahsilKurus: _tahsil, borcYazma: false),
          0);
    });

    test('anahtar açıkken iskonto tam olarak kırılan farktır', () {
      expect(
          teslimIskontoKurus(toplamKurus: _siparis, tahsilKurus: _tahsil, borcYazma: true),
          _iskonto);
    });

    test('fark pozitif değilse 0 — görünmeyen bir işaret deftere kayıt düşüremez', () {
      expect(
          teslimIskontoKurus(toplamKurus: _siparis, tahsilKurus: _siparis, borcYazma: true), 0);
      expect(
          teslimIskontoKurus(toplamKurus: _siparis, tahsilKurus: 50000, borcYazma: true), 0);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 2) Defter — üç satır, bakiye 0, append-only
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('deliver(iskontoKurus:) — 420 ₺ siparişin 400 ₺si alınır, 20 ₺ kırılır', () {
    test('debit(+420) · payment(−400) · discount(−20) yazılır; bakiye 0 kalır', () async {
      final (db, cid, oid) = await _kur();
      addTearDown(db.close);

      await OrderRepository(db)
          .deliver(oid, paymentType: 'nakit', tahsilKurus: _tahsil, iskontoKurus: _iskonto);

      final kayitlar = await _defter(db, cid);
      expect(kayitlar.length, 3, reason: 'satış · tahsilat · iskonto üç AYRI gerçektir');
      expect(kayitlar.firstWhere((e) => e.entryType == 'debit').amountKurus, _siparis,
          reason: 'satışın borcu TAM tutardır — iskonto debit`i düzeltmez, kendi satırını yazar');
      expect(kayitlar.firstWhere((e) => e.entryType == 'payment').amountKurus, -_tahsil);

      final iskonto = kayitlar.firstWhere((e) => e.entryType == 'discount');
      expect(iskonto.amountKurus, -_iskonto);
      expect(iskonto.paymentType, isNull,
          reason: 'kasanın değişmezi "payment_type taşıyan kayıt kasaya dokundu"dur; '
              'iskonto kasaya DOKUNMAZ');
      expect(iskonto.relatedOrderId, oid);

      expect((await _musteri(db, cid)).balanceKurus, 0,
          reason: 'müşteri BORÇLU GÖSTERİLMEZ — istenen davranış tam olarak budur');
    });

    test('iskontosuz kısmi ödeme AYNEN eskisi gibi çalışır (kalan borç yazılır)', () async {
      final (db, cid, oid) = await _kur();
      addTearDown(db.close);

      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: _tahsil);

      expect((await _defter(db, cid)).length, 2, reason: 'discount satırı YOK');
      expect((await _musteri(db, cid)).balanceKurus, _iskonto,
          reason: 'anahtar işaretsizken kalan borçtur — mevcut akış korunur');
    });

    test('iskonto kalan borçla SINIRLANIR — müşteri alacaklıya geçirilmez', () async {
      final (db, cid, oid) = await _kur();
      addTearDown(db.close);

      await OrderRepository(db)
          .deliver(oid, paymentType: 'nakit', tahsilKurus: _tahsil, iskontoKurus: 999999);

      expect((await _musteri(db, cid)).balanceKurus, 0);
      expect((await _defter(db, cid)).firstWhere((e) => e.entryType == 'discount').amountKurus,
          -_iskonto, reason: 'üst sınır total − alınan; "kırdım" demek alacaklı yapmaz');
    });

    test('tam tahsilatta iskonto istense bile satır yazılmaz', () async {
      final (db, cid, oid) = await _kur();
      addTearDown(db.close);

      await OrderRepository(db)
          .deliver(oid, paymentType: 'nakit', tahsilKurus: _siparis, iskontoKurus: _iskonto);

      expect((await _defter(db, cid)).any((e) => e.entryType == 'discount'), isFalse);
      expect((await _musteri(db, cid)).balanceKurus, 0);
    });

    test('iskonto teslim idempotensini BOZMAZ (id sipariş kimliğinden türer)', () async {
      final (db, cid, oid) = await _kur();
      addTearDown(db.close);
      final repo = OrderRepository(db);

      await repo.deliver(oid,
          paymentType: 'nakit', tahsilKurus: _tahsil, iskontoKurus: _iskonto);
      await repo.deliver(oid,
          paymentType: 'nakit', tahsilKurus: _tahsil, iskontoKurus: _iskonto);

      expect((await _defter(db, cid)).length, 3, reason: 'ikinci dokunma erken döner');
      expect((await _musteri(db, cid)).balanceKurus, 0);
    });

    test('iskonto ÖNCEKİ borcu kapatmaz — yalnız bu siparişin kalanını kırar', () async {
      final (db, cid, oid) = await _kur();
      addTearDown(db.close);
      await LedgerRepository(db).borcEkle(cid, 30000); // eski borç

      await OrderRepository(db)
          .deliver(oid, paymentType: 'nakit', tahsilKurus: _tahsil, iskontoKurus: 999999);

      expect((await _musteri(db, cid)).balanceKurus, 30000,
          reason: 'kapıda kırılan tutar bu siparişin kalanıdır; eski borç yerinde durur');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 3) Muhasebe — kasa · gün sonu · borçlu listesi
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('iskonto muhasebeye TUTARLI akar', () {
    Future<(AppDatabase, String, String)> teslimEt() async {
      final (db, cid, oid) = await _kur();
      await OrderRepository(db)
          .deliver(oid, paymentType: 'nakit', tahsilKurus: _tahsil, iskontoKurus: _iskonto);
      return (db, cid, oid);
    }

    test('kasa 400 ₺ görür, 420 değil — sayılan nakit iskontoyla şişmez', () async {
      final (db, _, _) = await teslimEt();
      addTearDown(db.close);
      final gun = DayEndRepository.bugunTr();

      final kasa = await DayEndRepository(db).kasaOzeti(gun);
      expect(kasa.nakit, _tahsil);
      expect(kasa.toplam, _tahsil,
          reason: 'iskonto `payment_type` taşımadığı için kasa kodu DEĞİŞMEDEN doğru kalır');
    });

    test('gün sonu iskontoyu AYRI rakam olarak gösterir', () async {
      final (db, _, _) = await teslimEt();
      addTearDown(db.close);

      expect(await DayEndRepository(db).iskontoOzeti(DayEndRepository.bugunTr()), _iskonto);
    });

    test('iskontosuz günde iskonto 0 — satır ekranda hiç çizilmesin', () async {
      final (db, _, oid) = await _kur();
      addTearDown(db.close);
      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: _tahsil);

      expect(await DayEndRepository(db).iskontoOzeti(DayEndRepository.bugunTr()), 0);
    });

    test('gün sonu bildirimi VERESİYE yazmaz — kırılan tutar borç değildir', () async {
      final (db, _, _) = await teslimEt();
      addTearDown(db.close);

      final veri =
          await DayEndRepository(db).gunSonuBildirimVerisi(DayEndRepository.bugunTr());
      expect(veri.tahsilatKurus, _tahsil);
      expect(veri.veresiyeKurus, 0,
          reason: 'iskonto edilen 20 ₺ bugün yazılmış bir veresiye DEĞİLDİR');
    });

    test('gün arşivi (geçmiş gün dökümü) iskontoyu taşır', () async {
      final (db, _, _) = await teslimEt();
      addTearDown(db.close);

      final detay = await gunDetayi(db, DayEndRepository.bugunTr());
      expect(detay.iskonto, _iskonto);
      expect(detay.kasa.toplam, _tahsil, reason: 'arşiv de kasayı şişirmez');
    });

    test('iskontolu sipariş "Borçlu" sekmesinde ÇIKMAZ', () async {
      final (db, _, _) = await teslimEt();
      addTearDown(db.close);

      expect(await watchOrders(db, OrderFilter.borclu).first, isEmpty,
          reason: 'kullanıcının istediği "borçlu gösterme" tam olarak bu sorgudur');
    });

    test('iskontolu siparişte kalan borç 0 yazar (detay kutusu)', () async {
      final (db, _, oid) = await teslimEt();
      addTearDown(db.close);
      final siparis = await (db.select(db.orders)..where((t) => t.id.equals(oid))).getSingle();

      final kapanan = await watchSiparisTahsilati(db, oid).first;
      expect(kapanan, _siparis, reason: 'payment + discount siparişi TAM kapatır');
      expect(
          siparisKalanBorcu(
              durum: siparis.status, toplamKurus: siparis.totalKurus, tahsilKurus: kapanan),
          0);
    });

    test('iskontosuz kısmi ödeme HÂLÂ "Borçlu" sekmesinde çıkar', () async {
      final (db, _, oid) = await _kur();
      addTearDown(db.close);
      await OrderRepository(db).deliver(oid, paymentType: 'nakit', tahsilKurus: _tahsil);

      expect((await watchOrders(db, OrderFilter.borclu).first).length, 1,
          reason: 'iskonto eklemek mevcut kısmi ödeme davranışını değiştirmez');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // 4) Ekran — anahtarın metni SÖZLEŞMEDİR
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('teslim sheet — "Kalanı borç yazma (iskonto)"', () {
    testWidgets('tutar düşürülünce anahtar belirir; işaretlenince sonuç iskonto taşır',
        (tester) async {
      TeslimSonucu? sonuc;
      await _sheetiAc(tester, (s) => sonuc = s);

      expect(find.text('Kalanı borç yazma (iskonto)'), findsNothing,
          reason: 'tam tahsilatta soru sorulmaz — teslimlerin çoğu tamdır');

      await tester.enterText(find.byType(TextField).first, '400');
      await akislariBekle(tester);
      expect(find.text('Kalanı borç yazma (iskonto)'), findsOneWidget);

      await dokun(tester, find.text('Kalanı borç yazma (iskonto)'));
      expect(find.textContaining('borç yazılmayacak'), findsOneWidget,
          reason: 'ne kaydedileceği alanın altında YAZILI olmalı');

      await dokun(tester, find.text('Teslim Et ve Kaydet'));
      await sheetAnimasyonu(tester);

      expect(sonuc!.tahsilKurus, _tahsil);
      expect(sonuc!.iskontoKurus, _iskonto);
      expect(sonuc!.odemeTipi, 'nakit');
      await kapat(tester);
    });

    testWidgets('anahtara DOKUNULMAZSA iskonto 0 döner (varsayılan borç yazmaktır)',
        (tester) async {
      TeslimSonucu? sonuc;
      await _sheetiAc(tester, (s) => sonuc = s);

      await tester.enterText(find.byType(TextField).first, '400');
      await akislariBekle(tester);
      expect(find.textContaining('borcuna yazılacak'), findsOneWidget,
          reason: 'anahtar kapalıyken şerit hâlâ KALAN BORCU anlatır');

      await dokun(tester, find.text('Teslim Et ve Kaydet'));
      await sheetAnimasyonu(tester);

      expect(sonuc!.iskontoKurus, 0);
      await kapat(tester);
    });

    testWidgets('anahtar işaretlendikten SONRA tutar tama çıkarılırsa iskonto yazılmaz',
        (tester) async {
      // Sessiz-yazma koruması: ekranda görünmeyen bir işaret deftere kayıt düşürmemeli.
      TeslimSonucu? sonuc;
      await _sheetiAc(tester, (s) => sonuc = s);

      await tester.enterText(find.byType(TextField).first, '400');
      await akislariBekle(tester);
      await dokun(tester, find.text('Kalanı borç yazma (iskonto)'));

      await tester.enterText(find.byType(TextField).first, '420');
      await akislariBekle(tester);
      expect(find.text('Kalanı borç yazma (iskonto)'), findsNothing);

      await dokun(tester, find.text('Teslim Et ve Kaydet'));
      await sheetAnimasyonu(tester);

      expect(sonuc!.iskontoKurus, 0);
      expect(sonuc!.tahsilKurus, _siparis);
      await kapat(tester);
    });

    testWidgets('VERESİYE karosunda anahtar HİÇ çıkmaz', (tester) async {
      // "Tamamı borç" ile "kalanı borç yazma" birbirinin zıddıdır; orada tutar 0`a kilitli
      // olduğu için anahtar tek dokunuşla siparişin TAMAMINI kıran bir yol açardı.
      await _sheetiAc(tester, (_) {});

      await dokun(tester, find.text('Veresiye'));
      expect(find.text('Kalanı borç yazma (iskonto)'), findsNothing);
      await kapat(tester);
    });
  });

  group('gün sonu ekranı — iskonto satırı', () {
    testWidgets('iskonto varsa "İskonto (kasaya girmedi)" yazar, kasa toplamı şişmez',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Kapıda Kırıldı');
        final oid = await OrderRepository(db).create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: _siparis, qty: 1)],
        );
        await OrderRepository(db)
            .deliver(oid, paymentType: 'nakit', tahsilKurus: _tahsil, iskontoKurus: _iskonto);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.text('İskonto (kasaya girmedi)'), findsOneWidget);
      expect(find.text('20,00 ₺'), findsOneWidget);
      expect(find.text('400,00 ₺'), findsWidgets,
          reason: 'sayılan nakitle karşılaştırılan rakam tahsilattır, ciro değil');

      await kapat(tester);
    });

    testWidgets('iskontosuz günde satır HİÇ çizilmez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Tam Ödeyen');
        final oid = await OrderRepository(db).create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: _siparis, qty: 1)],
        );
        await OrderRepository(db).deliver(oid, paymentType: 'nakit');
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.text('İskonto (kasaya girmedi)'), findsNothing,
          reason: '"İskonto 0,00 ₺" satırı her gün cevapsız bir soru eklerdi');

      await kapat(tester);
    });
  });
}
