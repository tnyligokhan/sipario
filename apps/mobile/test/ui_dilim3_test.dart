import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_end_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/theme/components/overlays.dart';
import 'package:sipario/screens/customers/customer_ledger.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/money.dart';
import 'package:sipario/theme/components/bicim.dart';
import 'package:sipario/theme/tokens.dart';

/// Dilim 3 UI testleri: defter (hareket listesi/tahsilat/düzeltme) + gün sonu read-model.
/// Sorgu ve özet mantığı ekrandan bağımsız fonksiyonlarda tutulur ve saf async sınanır
/// (widget-test sahte zamanı drift akışlarında güvenilmez — Dilim 1/2 dersi).
void main() {
  group('imzaliTutarText (para — işaretli gösterim)', () {
    test('+borç, −ödeme; formatKurus negatifi U+2212 ile yazar', () {
      expect(imzaliTutarText(1000), '+10,00 ₺');
      expect(imzaliTutarText(-500), '−5,00 ₺');
      expect(imzaliTutarText(0), '0,00 ₺');
    });
  });

  group('bugunTr (gün sınırı sabit +03:00 TR)', () {
    test('UTC gece yarısı sonrası TR günü ileri kayar', () {
      // 21:00 UTC = 00:00 TR (ertesi gün); 22:00 UTC = 01:00 TR
      expect(bugunTr(now: DateTime.utc(2026, 7, 21, 22)), DateTime(2026, 7, 22));
      expect(bugunTr(now: DateTime.utc(2026, 7, 21, 10)), DateTime(2026, 7, 21));
    });
  });

  group('watchLedger (defter hareketleri — en yeni önce)', () {
    late AppDatabase db;
    late String cid;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      cid = await CustomerRepository(db).create(name: 'Ali Veli');
      final ledger = LedgerRepository(db);
      await ledger.borcEkle(cid, 1000);
      // uuid7 aynı ms'de monoton değil → occurred_at ayrışsın diye bekle (sıralamanın dayanağı).
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await ledger.tahsilat(cid, 500, 'kart');
    });

    tearDown(() => db.close());

    test('en yeni hareket başta gelir', () async {
      final list = await watchLedger(db, cid).first;
      expect(list.length, 2);
      expect(list.first.entryType, 'payment', reason: 'en son tahsilat en üstte');
      expect(list.last.entryType, 'debit');
    });

    test('yalnız o müşterinin hareketleri döner', () async {
      final other = await CustomerRepository(db).create(name: 'Başka');
      final list = await watchLedger(db, other).first;
      expect(list, isEmpty);
    });
  });

  group('tahsilat bakiyeyi düşürür', () {
    test('borç 8000 → tahsilat 3000 → bakiye 5000', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Borçlu');
      final ledger = LedgerRepository(db);
      await ledger.borcEkle(cid, 8000);
      expect((await _musteri(db, cid)).balanceKurus, 8000);
      await ledger.tahsilat(cid, 3000, 'nakit');
      expect((await _musteri(db, cid)).balanceKurus, 5000);
    });
  });

  group('düzeltme ters kayıt üretir (orijinal DEĞİŞMEZ) ve kasayı telafi eder', () {
    test('yanlış nakit tahsilatı düzeltince bakiye geri gelir, kasa sıfırlanır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Düzeltilecek');
      final ledger = LedgerRepository(db);
      await ledger.borcEkle(cid, 10000);
      final payId = await ledger.tahsilat(cid, 10000, 'nakit'); // payment −10000, bakiye 0
      expect((await _musteri(db, cid)).balanceKurus, 0);
      final kasaOnce = await DayEndRepository(db).kasaOzeti(bugunTr());
      expect(kasaOnce.nakit, 10000);

      // Yanlış tahsilat → ters kayıtla düzelt (UI: -e.amountKurus = +10000).
      await ledger.duzeltme(payId, 10000, customerId: cid);

      // Orijinal payment kaydı SİLİNMEDİ/DEĞİŞMEDİ (append-only, kanıt olarak durur).
      final orig = await (db.select(db.ledgerEntries)..where((t) => t.id.equals(payId))).getSingle();
      expect(orig.entryType, 'payment');
      expect(orig.amountKurus, -10000);

      // Correction: ters işaret + reversesEntryId + payment_type KOPYALANDI.
      final corr = await (db.select(db.ledgerEntries)
            ..where((t) => t.entryType.equals('correction')))
          .getSingle();
      expect(corr.amountKurus, 10000);
      expect(corr.reversesEntryId, payId);
      expect(corr.paymentType, 'nakit', reason: 'kasa da düzelsin diye tip kopyalanır');

      // Bakiye borca döndü, kasa nakit sıfırlandı (bakiye + kasa birlikte telafi).
      expect((await _musteri(db, cid)).balanceKurus, 10000);
      final kasaSonra = await DayEndRepository(db).kasaOzeti(bugunTr());
      expect(kasaSonra.nakit, 0);
    });
  });

  group('gün sonu rakamları defterle tutarlıdır', () {
    test('kasa/borç defterden türer ve tutar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Gün Özeti');
      final orders = OrderRepository(db);

      // Nakit teslim: debit +9000, payment −9000 (nakit).
      final o1 = await orders.create(
          customerId: cid, lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2)]);
      await orders.deliver(o1, paymentType: 'nakit');

      // Veresiye teslim: debit +4500 (kasaya girmez).
      final o2 = await orders.create(
          customerId: cid, lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1)]);
      await orders.deliver(o2, paymentType: 'veresiye');

      // Elle tahsilat: payment −10000 (nakit) — kasaya girer, borcu düşürür.
      await LedgerRepository(db).borcEkle(cid, 10000);
      await LedgerRepository(db).tahsilat(cid, 10000, 'nakit');

      final ozet = await gunSonuOzeti(db, bugunTr());

      // Kasa nakit = o1 tahsilatı (9000) + elle tahsilat (10000).
      expect(ozet.kasa.nakit, 19000);
      expect(ozet.kasa.kart, 0);
      expect(ozet.kasa.havale, 0);
      expect(ozet.kasa.toplam, 19000);

      // Açık borç = yalnız veresiye teslimin borcu (nakit teslim ve tahsil edilen borç net 0).
      expect(ozet.borc.toplamAcikBorc, 4500);
      expect(ozet.borc.borclular.single.customerId, cid);
    });
  });

  group('defterHareketEtiketi (Türkçe etiket — DB değeri değişmez)', () {
    test('debit/payment/correction ve sipariş borcu doğru etiketlenir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Etiket');
      final ledger = LedgerRepository(db);
      await ledger.borcEkle(cid, 1000); // manuel borç
      await ledger.tahsilat(cid, 500, 'havale');

      // Sipariş borcu (relatedOrderId dolu) — veresiye teslim.
      final oid = await OrderRepository(db)
          .create(customerId: cid, lines: [LineInput(productName: 'D', unitPriceKurus: 4500, qty: 1)]);
      await OrderRepository(db).deliver(oid, paymentType: 'veresiye');

      final rows = await watchLedger(db, cid).first;
      final etiketler = rows.map(defterHareketEtiketi).toSet();
      expect(etiketler.contains('Borç'), isTrue);
      expect(etiketler.contains('Tahsilat · Havale'), isTrue);

      // Tasarımın (`HAREKET_META`) dört sözcüğü var: Borç · Tahsilat · Alacak · Düzeltme.
      // "Sipariş borcu" ayrı bir etiket DEĞİL — sipariş bağı etikette değil `relatedOrderId`
      // kolonunda yaşar; iki debit satırı da aynı sözcükle okunur.
      expect(etiketler.contains('Sipariş borcu'), isFalse,
          reason: 'sipariş borcu ayrı etiket taşımaz (tasarımda o sözcük yok)');
      final siparisBorcu = rows.where((e) => e.relatedOrderId != null).toList();
      expect(siparisBorcu, hasLength(1), reason: 'veresiye teslim deftere bir debit yazar');
      expect(defterHareketEtiketi(siparisBorcu.single), 'Borç');
      expect(siparisBorcu.single.relatedOrderId, oid,
          reason: 'etiket birleşti ama siparişe giden bağ KAYBOLMADI');
    });
  });

  group('DayEndScreen (widget — salt-okunur özet)', () {
    testWidgets('kasa/borç kartlarını çizer', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Ayşe');
        final orders = OrderRepository(db);
        final o = await orders.create(
            customerId: cid, lines: [LineInput(productName: 'D', unitPriceKurus: 4500, qty: 2)]);
        await orders.deliver(o, paymentType: 'nakit');
      });

      await tester.pumpWidget(MaterialApp(home: DayEndScreen(db: db)));
      // İKİ tur bekleme ŞART: `gunSonuGorunumu` 2026-07-26'da kurye kapanış sorgularını da
      // (`acikKuryeAdlari` + aktif kurye sayısı) bekliyor, tek 150 ms'de future tamamlanmıyor
      // ve ekran hâlâ İSKELET çiziyor — aranan tutar hiç bulunmuyordu. Dosyadaki DÖRT gün-sonu
      // testinin hepsi aynı kırılganlığı taşıyordu; biri düşünce dördü birlikte düzeltildi.
      for (var i = 0; i < 2; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump();
      }

      expect(find.text('Kasa Özeti'), findsOneWidget);
      expect(find.text('Açık Veresiye'), findsOneWidget);
      // Kupon üründen kaldırıldı (2026-07-26): gün sonunda kupon bölümü OLMAMALI.
      expect(find.textContaining('Kupon'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('mağaza-kuralı ihlali yok (satın alma/abonelik metni)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(MaterialApp(home: DayEndScreen(db: db)));
      // İKİ tur bekleme ŞART: `gunSonuGorunumu` 2026-07-26'da kurye kapanış sorgularını da
      // (`acikKuryeAdlari` + aktif kurye sayısı) bekliyor, tek 150 ms'de future tamamlanmıyor
      // ve ekran hâlâ İSKELET çiziyor — aranan tutar hiç bulunmuyordu. Dosyadaki DÖRT gün-sonu
      // testinin hepsi aynı kırılganlığı taşıyordu; biri düşünce dördü birlikte düzeltildi.
      for (var i = 0; i < 2; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump();
      }

      for (final yasak in ['Abone', 'Satın al', 'Üye ol', 'Kaydol', 'Ödeme yap']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('AppBar yok; ekran başlığı "Gün Sonu" görünür', (tester) async {
      // SİPARİO 3.0: AppBar hiçbir ekranda kullanılmaz — başlık `SipUst` ile çizilir.
      //
      // Başlığın TAM stilini burada sınamıyoruz. Stil kimliği (`baslik.style == SipText.x`)
      // kırılgan bir iddiaydı: tasarım sistemi her dokunulduğunda bu dosya da kırılıyordu,
      // üstelik hiçbir davranışı korumuyordu. Tipografi sözleşmesi artık merkezî olarak
      // `test/ui_temel_test.dart` içinde sınanıyor; burada ekranın SÖZLEŞMESİ kalıyor:
      // AppBar yok, başlık metni doğru.
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(home: DayEndScreen(db: db)));
      // İKİ tur bekleme ŞART: `gunSonuGorunumu` 2026-07-26'da kurye kapanış sorgularını da
      // (`acikKuryeAdlari` + aktif kurye sayısı) bekliyor, tek 150 ms'de future tamamlanmıyor
      // ve ekran hâlâ İSKELET çiziyor — aranan tutar hiç bulunmuyordu. Dosyadaki DÖRT gün-sonu
      // testinin hepsi aynı kırılganlığı taşıyordu; biri düşünce dördü birlikte düzeltildi.
      for (var i = 0; i < 2; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump();
      }

      expect(find.byType(AppBar), findsNothing,
          reason: 'SİPARİO 3.0 tasarımında AppBar yok; başlık SipUst ile çizilir');
      expect(find.text('Gün Özeti'), findsWidgets);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('açık borç > 0 → toplam tutar borç rengiyle (danger) vurgulanır', (tester) async {
      // VIEWPORT YÜKSELTİLİYOR (400 → 2400): `SipGovde` bir `ListView`, yani TEMBEL — katlamanın
      // altındaki çocuk hiç BUILD edilmez ve `find.text` boş döner (aynı tuzak bu dosyanın
      // müşteri-detay testinde de yazılı). Varsayılan 800×600 yüzeyde "Açık Veresiye" başlığı
      // görünüyor ama kartın içindeki toplam satırı fold'un altında kalıyor: kapsam segmenti
      // 2026-07-26'da KOŞULSUZ çizilmeye başlayınca (tasarım `s-gunsonu.jsx:37-41`) gövde ~50 px
      // aşağı kaydı ve bu test o yüzden düştü. Ürün kodunda gerileme YOK — kasa/borç hâlâ
      // defterden türetiliyor; kırılan şey testin görünür alan varsayımıydı.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final orders = OrderRepository(db);
        // İki veresiye teslim → toplam açık borç 4500+12000=16500 (benzersiz; tekil satırlarla karışmaz).
        final a = await CustomerRepository(db).create(name: 'Veresiyeci A');
        final oa = await orders.create(
            customerId: a, lines: [LineInput(productName: 'D', unitPriceKurus: 4500, qty: 1)]);
        await orders.deliver(oa, paymentType: 'veresiye');
        final b = await CustomerRepository(db).create(name: 'Veresiyeci B');
        final ob = await orders.create(
            customerId: b, lines: [LineInput(productName: 'D', unitPriceKurus: 12000, qty: 1)]);
        await orders.deliver(ob, paymentType: 'veresiye');
      });

      await tester.pumpWidget(MaterialApp(home: DayEndScreen(db: db)));
      // İKİ tur bekleme ŞART: `gunSonuGorunumu` 2026-07-26'da kurye kapanış sorgularını da
      // (`acikKuryeAdlari` + aktif kurye sayısı) bekliyor, tek 150 ms'de future tamamlanmıyor
      // ve ekran hâlâ İSKELET çiziyor — aranan tutar hiç bulunmuyordu. Dosyadaki DÖRT gün-sonu
      // testinin hepsi aynı kırılganlığı taşıyordu; biri düşünce dördü birlikte düzeltildi.
      for (var i = 0; i < 2; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump();
      }

      // Bu iddia DAVRANIŞSAL: "borç kırmızı görünür" tasarımın bakiye dilinin çekirdeği
      // (+borç danger · −alacak ok · 0 temiz). Stil kimliği değil, RENK sınanıyor — tasarım
      // sistemi değişse bile bu kural değişmemeli.
      final toplamTutar = tester.widget<Text>(find.text(formatKurus(16500)));
      expect(toplamTutar.style?.color, SipTokens.acik.danger,
          reason: 'açık borç > 0 iken toplam tutar borç rengiyle çizilir (bakiye dili)');

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('CustomerLedgerSection (widget — salt-okunur kapısı)', () {
    // SİPARİO 3.0 — YÜZEY DEĞİŞTİ, KURAL DEĞİŞMEDİ:
    // Tahsilat ve düzeltme eylemleri defter bölümünden çıkıp müşteri detayının hızlı-eylem
    // ızgarasına (`.md-akslar`) taşındı; uyarı da SnackBar yerine `SipToast`. Bu yüzden
    // salt-okunur kapısı artık `CustomerDetailScreen` üzerinden sınanıyor. Kırmızı çizgi aynı:
    // salt-okunur kipte YENİ KAYIT oluşmaz ve kullanıcı bunu görür.
    testWidgets('salt-okunur kipte tahsilat engellenir ve kullanıcı uyarılır', (tester) async {
      // Akış-abonelikli drift db'si widget-testte KAPATILMAZ (Dilim 1 dersi: asılı kalıyor).
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Salt Okunur');
      });

      await tester.pumpWidget(MaterialApp(
        home: CustomerDetailScreen(db: db, customerId: cid, writable: false),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      await tester.tap(find.text('Tahsilat'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      expect(find.text('Tahsilat kaydedildi'), findsNothing,
          reason: 'sheet hiç açılmamalı, kayıt oluşmamalı');

      await tester.pump(const Duration(seconds: 5));
      SipToast.temizle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    // Kapı TEK bir eyleme değil, ızgaradaki HER yazma eylemine uygulanır. İkinci eylemi de
    // sınamak bu yüzden ayrı bir testtir (eskiden bu test "Kupon"u sınıyordu; kupon 2026-07-26'da
    // üründen kalktı, sıra "Düzeltme"ye geçti — kural aynı kaldı).
    testWidgets('salt-okunur kipte defter düzeltmesi DE engellenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Salt Okunur Düzeltme');
      });

      await tester.pumpWidget(MaterialApp(
        home: CustomerDetailScreen(db: db, customerId: cid, writable: false),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      // SİPARİO 3.0: düzeltme artık hızlı eylem ızgarasında DEĞİL, defter başlığının sağındaki
      // "± Bakiye Düzeltme" bağlantısında (tasarım s-musteriler.jsx:125). Kapı yer değiştirdi,
      // kural değişmedi.
      await tester.tap(find.text('± Bakiye Düzeltme'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Salt-okunur kip: yeni kayıt eklenemez.'), findsOneWidget);
      expect(find.text('Düzeltme deftere işlendi'), findsNothing,
          reason: 'salt-okunurda düzeltme sheet\'i hiç açılmamalı');

      await tester.pump(const Duration(seconds: 5));
      SipToast.temizle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('salt-okunur kipte var olan hareketin "Ters kayıtla düzelt" menüsü GÖRÜNMEZ', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Salt Okunur Defter');
        await LedgerRepository(db).borcEkle(cid, 4500);
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CustomerLedgerSection(db: db, customerId: cid, writable: false)),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      // SİPARİO 3.0: düzeltme artık bir açılır menüde (PopupMenuButton) değil — hareket
      // satırına DOKUNMAK onay diyaloğunu açıyor. Salt-okunurda `onDuzelt` null verildiği için
      // dokunma hiçbir şey yapmaz; kanıtı diyaloğun açılmamasıdır.
      expect(find.text('Borç'), findsOneWidget, reason: 'hareket listelenir');
      await tester.tap(find.text('Borç'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Ters kayıtla düzelt'), findsNothing,
          reason: 'salt-okunurda düzeltme diyaloğu açılmamalı (onDuzelt null)');

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    // NOT — "yazılabilir kipte harekete dokunmak düzeltme onayını AÇAR" testi KALDIRILDI
    // (2026-07-26): defter SATIRINA dokunma diye bir jest artık YOK, tasarımda `.dhar`
    // tıklanabilir değil (düz bir div). Düzeltmenin tek girişi başlığın sağındaki
    // "± Bakiye Düzeltme" bağlantısı; onun salt-okunur kapısı yukarıdaki testte kanıtlanıyor.
    // Yukarıdaki "GÖRÜNMEZ" testi de aynı gerçeği ters yönden koruyor: satıra dokunmak hiçbir
    // diyalog açmaz.
  });

  group('CustomerLedgerSection mağaza-kuralı (day_end deseniyle simetri)', () {
    testWidgets('mağaza-kuralı ihlali yok (satın alma/abonelik metni)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Mağaza Kural');
        await LedgerRepository(db).borcEkle(cid, 4500);
        await LedgerRepository(db).tahsilat(cid, 4500, 'nakit');
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CustomerLedgerSection(db: db, customerId: cid, writable: true)),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      for (final yasak in ['Abone', 'Satın al', 'Üye ol', 'Kaydol', 'Ödeme yap']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('ekran-repo tutarlılığı: defterde gösterilen tutar repo\'nun yazdığıyla birebir aynı', () {
    testWidgets('küsuratlı bir borç repo\'da ne yazdıysa ekranda AYNI metinle çıkar', (tester) async {
      // İlke: ekran ile repo aynı kaynağı konuşmalı.
      // 12345 kuruş bilerek küsuratlı seçildi (yuvarlama/kesme hatası varsa yakalasın).
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Küsuratlı');
        await LedgerRepository(db).borcEkle(cid, 12345);
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CustomerLedgerSection(db: db, customerId: cid, writable: false)),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      // Repo'nun yazdığı gerçek satırdan (DB'den okunarak) beklenen metni kur — ekrandaki sabit
      // bir string'i tahmin etmiyoruz, repo'nun ürettiği değeri imzaliTutarText'e sokup karşılaştırıyoruz.
      // NOT (Dilim 1 dersi — genişletildi): drift sorgusu watch() akışı OLMASA bile gerçek async'tir;
      // widget-test sahte zaman diliminde runAsync DIŞINDA await edilirse asılı kalır.
      late LedgerEntry yazilan;
      await tester.runAsync(() async {
        yazilan = await (db.select(db.ledgerEntries)..where((t) => t.customerId.equals(cid))).getSingle();
      });
      expect(find.text(imzaliTutarText(yazilan.amountKurus)), findsOneWidget);
      expect(find.text('+123,45 ₺'), findsOneWidget, reason: 'küsurat kaybolmadan 12345 kuruş göründü');

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('müşteri bakiye kartı repo\'nun yazdığı önbellekle birebir aynı gösterilir',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String cid;
      await tester.runAsync(() async {
        cid = await CustomerRepository(db).create(name: 'Bakiye Ekran');
        await LedgerRepository(db).borcEkle(cid, 63000);
      });

      // Varsayılan 800×600 test yüzeyi bu ekran için kısa: gövde kaydırılabilir ve bakiye kartı
      // görünür alanın dışında kalabiliyor; ListView tembel çizdiği için find.text boş dönerdi.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: CustomerDetailScreen(db: db, customerId: cid, writable: false),
      ));
      // Ekran İÇ İÇE akışlar dinliyor (müşteri → telefon/adres). Tek tur yetmiyor: dıştaki akış
      // çözülmeden içteki StreamBuilder ağaca hiç girmiyor.
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump();
      }

      // Ekrandaki sabit bir string tahmin edilmiyor: repo'nun defterden türettiği önbellek
      // okunup aynı biçimleyiciden geçiriliyor (watch() gerçek async — runAsync İÇİNDE).
      late int gercekBakiye;
      await tester.runAsync(() async {
        gercekBakiye = await (db.select(db.customers)..where((t) => t.id.equals(cid)))
            .getSingle()
            .then((c) => c.balanceKurus);
      });
      expect(gercekBakiye, 63000);
      // SİPARİO 3.0: bakiye 34 px'lik hero kartından `.md-bakiye` İNCE şeridine indi ve tutarla
      // durumu TEK metinde yazıyor ("630,00 ₺ Borç"; 0 bakiyede "Temiz"). Tutar tek başına bir
      // Text değil, o yüzden `find.text(sipTutar(...))` artık eşleşmez.
      expect(find.text('${sipTutar(gercekBakiye)} Borç'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('tahsilat: bakiye ve kasa AYNI tutarda birlikte değişir', () {
    test('borç 8000 → havale tahsilat 3000 → bakiye 5000 düşer VE kasa havale gözü 3000 artar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Havaleci');
      final ledger = LedgerRepository(db);

      await ledger.borcEkle(cid, 8000);
      final kasaOnce = await DayEndRepository(db).kasaOzeti(bugunTr());
      expect(kasaOnce.havale, 0, reason: 'yalnız borç yazıldı, kasaya henüz para girmedi');

      await ledger.tahsilat(cid, 3000, 'havale');

      expect((await _musteri(db, cid)).balanceKurus, 5000, reason: '8000 borç − 3000 tahsilat');
      final kasaSonra = await DayEndRepository(db).kasaOzeti(bugunTr());
      expect(kasaSonra.havale, 3000, reason: 'bakiyeden düşen tutarla kasaya giren tutar AYNI (3000)');
      expect(kasaSonra.nakit, 0);
      expect(kasaSonra.kart, 0);
    });
  });

  group('düzeltme append-only kanıt: kayıt sayısı artar, orijinal satır hiçbir alanıyla değişmez', () {
    test('correction eklenince satır SAYISI +1 olur; orijinal satır (tüm alanlarıyla) AYNEN durur', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cid = await CustomerRepository(db).create(name: 'Kanıt');
      final ledger = LedgerRepository(db);
      final payId = await ledger.tahsilat(cid, 7500, 'kart');

      final oncekiSatirlar = await db.select(db.ledgerEntries).get();
      expect(oncekiSatirlar, hasLength(1));
      final orijinalOnce = oncekiSatirlar.single;

      await ledger.duzeltme(payId, 7500, customerId: cid);

      final sonrakiSatirlar = await db.select(db.ledgerEntries).get();
      expect(sonrakiSatirlar, hasLength(2), reason: 'düzeltme YENİ satırdır, mevcut satır yerine geçmez');

      // Orijinal satır UPDATE edilmediyse drift veri sınıfı (tüm alanlar) hâlâ birebir eşit olmalı.
      final orijinalSonra = sonrakiSatirlar.firstWhere((e) => e.id == payId);
      expect(orijinalSonra, equals(orijinalOnce),
          reason: 'append-only: kaynak satırın TEK bir alanı bile değişmemiş olmalı');
    });
  });

  group("gün sonu: kasa/borç rakamları BAĞIMSIZ hesapla doğrulanır", () {
    test('çok müşterili/çok ödeme tipli karışık senaryoda elle kurulan beklenti repository çıktısıyla eşleşir',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final orders = OrderRepository(db);
      final ledger = LedgerRepository(db);

      // Ayşe: nakit peşin teslim → debit+payment nakit, net borç 0, kasa nakit +4500.
      final ayseId = await CustomerRepository(db).create(name: 'Ayşe');
      final o1 = await orders.create(customerId: ayseId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 4500, qty: 1)]);
      await orders.deliver(o1, paymentType: 'nakit');

      // Bora: kart peşin teslim → kasa kart +9000; sonra elle borç açıp kartla tahsil → +8000 daha.
      final boraId = await CustomerRepository(db).create(name: 'Bora');
      final o2 = await orders.create(customerId: boraId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 9000, qty: 1)]);
      await orders.deliver(o2, paymentType: 'kart');
      await ledger.borcEkle(boraId, 8000);
      await ledger.tahsilat(boraId, 8000, 'kart');

      // Cem: 5000 borcu var, 2000 havale tahsilat yapılır → kalan borç 3000, kasa havale +2000.
      final cemId = await CustomerRepository(db).create(name: 'Cem');
      await ledger.borcEkle(cemId, 5000);
      await ledger.tahsilat(cemId, 2000, 'havale');

      // Derya: veresiye teslim → borç 12000, kasaya HİÇ dokunmaz.
      final deryaId = await CustomerRepository(db).create(name: 'Derya');
      final o3 = await orders.create(customerId: deryaId,
          lines: [LineInput(productName: 'D', unitPriceKurus: 12000, qty: 1)]);
      await orders.deliver(o3, paymentType: 'veresiye');

      final ozet = await gunSonuOzeti(db, bugunTr());

      // --- Aşağıdaki beklenti rakamları girdilerden ELLE çıkarıldı (repository kodunu tekrar
      // ETMİYORUZ) — DayEndRepository'nin ürettiğiyle karşılaştırıyoruz. ---
      expect(ozet.kasa.nakit, 4500, reason: 'yalnız Ayşe\'nin peşin nakit teslimi');
      expect(ozet.kasa.kart, 9000 + 8000, reason: 'Bora\'nın peşin teslimi + kartla tahsilatı');
      expect(ozet.kasa.havale, 2000, reason: 'Cem\'in tahsilatı');
      expect(ozet.kasa.toplam, 4500 + 17000 + 2000);

      expect(ozet.borc.toplamAcikBorc, 3000 + 12000,
          reason: 'Cem 3000 + Derya 12000; peşin ödeyen müşteriler borçsuz');
      expect(ozet.borc.borclular.map((b) => b.name).toSet(), {'Cem', 'Derya'});
    });
  });
}

Future<Customer> _musteri(AppDatabase db, String id) =>
    (db.select(db.customers)..where((t) => t.id.equals(id))).getSingle();
