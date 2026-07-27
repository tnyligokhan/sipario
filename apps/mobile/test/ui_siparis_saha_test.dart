// Saha testinden gelen dört sipariş hatasının regresyon kilidi (2026-07-27).
//
//  HATA 3 — Ara / WhatsApp / Konum düğmeleri işlevsizdi (yalnız toast).
//  HATA 4 — sürükle-bırak tutamacı soldaydı; varsayılan SAĞ olmalı, sola alınabilmeli.
//  HATA 5a — "Borçlu" sekmesi TESLİM EDİLMEMİŞ siparişleri de listeliyordu.
//  HATA 6 — patron kuryeye göre süzemiyordu.
//
// DESEN (ui_siparis_test.dart ile aynı): sorgu/saf mantık ekransız sınanır, yalnız görünüm ve
// dokunma akışları widget testine kalır. Harici uygulama açma tek dikiş yerinden (`uriAcici`)
// sahtelenir — widget testinde platform eklentisi YOKTUR.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/orders/musteri_eylemleri.dart';
// Süzgeç/tutamaç yardımcıları ekranın YÜZEYİNDEN gelir (order_list_screen re-export eder) —
// testler tek kapıdan konuşur.
import 'package:sipario/screens/orders/order_list_screen.dart';

import 'support/siparis_yardimci.dart';

/// Testte gerçek `url_launcher` çağrılmaz: hangi URI'nin denendiği kaydedilir, açılıp
/// açılmadığına test karar verir.
class SahteAcici {
  SahteAcici({this.acilir = true});

  final bool acilir;
  final List<Uri> denenen = [];

  Future<bool> ac(Uri u) async {
    denenen.add(u);
    return acilir;
  }
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // HATA 3 — numara normalleştirme ve URI kurma (saf)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('telefonE164', () {
    test('TR yerel yazımların hepsi +90 ile aynı numaraya iner', () {
      // WhatsApp ham "0532…" ile sohbet AÇMAZ; hatanın kökü buydu.
      for (final ham in [
        '05324152290',
        '0532 415 22 90',
        '5324152290',
        '532 415 22 90',
        '+90 532 415 22 90',
        '+905324152290',
        '00905324152290',
        '905324152290',
      ]) {
        expect(telefonE164(ham), '+905324152290', reason: '"$ham" çevrilemedi');
      }
    });

    test('eksik/bozuk girdide null döner — yanlış numarayı aramaktansa hiç arama', () {
      for (final ham in [null, '', '   ', 'telefon yok', '532', '0532415']) {
        expect(telefonE164(ham), isNull, reason: '"$ham" kabul edilmemeliydi');
      }
    });

    test('yabancı ülke kodu korunur', () {
      expect(telefonE164('+1 555 123 4567'), '+15551234567');
    });
  });

  group('URI kurma', () {
    test('tel: şeması numarayı olduğu gibi taşır', () {
      expect(telUri('+905324152290').toString(), 'tel:+905324152290');
    });

    test('WhatsApp önce uygulamayı, sonra wa.me yolunu dener; "+" düşer', () {
      final u = whatsappUriler('+905324152290');
      expect(u.first.toString(), 'whatsapp://send?phone=905324152290');
      expect(u.last.toString(), 'https://wa.me/905324152290');
    });

    test('harita önce geo:, sonra web haritası; koordinat NOKTA ayırıcıyla yazılır', () {
      final u = haritaUriler(36.8969, 30.7133, etiket: 'Ayşe Yılmaz');
      expect(u.first.toString(), startsWith('geo:36.896900,30.713300'));
      expect(u.first.toString(), contains('Ay%C5%9Fe%20Y%C4%B1lmaz'));
      expect(u.last.toString(), contains('query=36.896900,30.713300'));
    });
  });

  group('eylemler gerekçe döner', () {
    tearDown(() => uriAcici = _gercekAciciYerineHicbirSey);

    test('telefonu olmayan müşteride arama denenmez, neden söylenir', () async {
      final sahte = SahteAcici();
      uriAcici = sahte.ac;
      expect(await musteriyiAra(null), 'Müşterinin kayıtlı telefonu yok');
      expect(sahte.denenen, isEmpty, reason: 'boşuna uygulama açılmamalı');
    });

    test('hedef uygulama yoksa ÇÖKMEZ, Türkçe gerekçe döner', () async {
      final sahte = SahteAcici(acilir: false);
      uriAcici = sahte.ac;
      expect(await whatsappAc('05324152290'), 'WhatsApp açılamadı — telefonda yüklü değil');
      expect(sahte.denenen.length, 2, reason: 'iki aday da denenmeli');
    });

    test('ilk aday açılınca ikincisi denenmez', () async {
      final sahte = SahteAcici();
      uriAcici = sahte.ac;
      expect(await whatsappAc('05324152290'), isNull);
      expect(sahte.denenen.single.scheme, 'whatsapp');
    });

    test('konumu olmayan adres haritayı hiç açmaz', () async {
      final sahte = SahteAcici();
      uriAcici = sahte.ac;
      const adres = AdresBilgi(metin: 'Lara Cad. 12');
      expect(await konumuHaritadaAc(adres), 'Konum kayıtlı değil — müşteri detayından alın');
      expect(sahte.denenen, isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // HATA 3 — düğmeler GERÇEKTEN açar (widget)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('Ara düğmesi telefon uygulamasını açar', (tester) async {
    genisYuzey(tester);
    final sahte = SahteAcici();
    uriAcici = sahte.ac;
    addTearDown(() => uriAcici = _gercekAciciYerineHicbirSey);

    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final m = await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        phones: [PhoneInput(phoneE164: '+905324152290', isPrimary: true)],
      );
      await OrderRepository(db).create(customerId: m, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
    });

    await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
    await akisiBekle(tester);

    await tester.tap(find.text('Ara'));
    await akisiBekle(tester);

    expect(sahte.denenen.single.toString(), 'tel:+905324152290',
        reason: 'düğme artık toast değil, çevirici açar');

    await ekraniKapat(tester);
  });

  testWidgets('telefonu olmayan müşteride düğme GİZLENMEZ, nedenini söyler', (tester) async {
    // Görünmez düğme "özellik yok" der; pasif düğme "burada kullanılamaz" der.
    genisYuzey(tester);
    final sahte = SahteAcici();
    uriAcici = sahte.ac;
    addTearDown(() => uriAcici = _gercekAciciYerineHicbirSey);

    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final m = await CustomerRepository(db).create(name: 'Telefonsuz Müşteri');
      await OrderRepository(db).create(customerId: m, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
    });

    await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
    await akisiBekle(tester);

    expect(find.text('Ara'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Konum'), findsOneWidget);

    await tester.tap(find.text('Ara'));
    await akisiBekle(tester);

    expect(find.text('Müşterinin kayıtlı telefonu yok'), findsOneWidget);
    expect(sahte.denenen, isEmpty);

    await ekraniKapat(tester);
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // HATA 5a — "Borçlu" sekmesi
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('Borçlu sekmesi', () {
    test('teslim EDİLMEMİŞ sipariş borç değildir — listeye girmez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final musteri = await CustomerRepository(db).create(name: 'Borçlu Bahri');
      final repo = OrderRepository(db);

      // 1) Teslim edilmiş veresiye → BORÇ (deftere debit yazar, bakiye artar).
      final veresiye = await repo.create(customerId: musteri, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 5000, qty: 1),
      ]);
      await repo.deliver(veresiye, paymentType: 'veresiye');

      // 2) Aynı müşterinin AÇIK siparişi → henüz borç değil (mal teslim edilmedi).
      final acik = await repo.create(customerId: musteri, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 5000, qty: 1),
      ]);

      // 3) Teslim edilmiş ve TAMAMI nakit tahsil edilmiş sipariş → borç bırakmaz.
      final nakit = await repo.create(customerId: musteri, lines: [
        LineInput(productName: 'Bardak su', unitPriceKurus: 1000, qty: 1),
      ]);
      await repo.deliver(nakit, paymentType: 'nakit');

      // 4) KISMİ ödeme ("50 ver kalanı yaz"): ödeme tipi nakit AMA geriye borç kaldı →
      //    sekme ödeme TİPİNE değil, defterdeki tahsilata bakmalı.
      final kismi = await repo.create(customerId: musteri, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 5000, qty: 1),
      ]);
      await repo.deliver(kismi, paymentType: 'nakit', tahsilKurus: 2000);

      final borclu = (await watchOrders(db, OrderFilter.borclu).first)
          .map((e) => e.order.id)
          .toSet();
      expect(borclu, {veresiye, kismi},
          reason: 'teslim edilmiş + tahsilatı eksik kalan siparişler borçtur');
      expect(borclu, isNot(contains(acik)), reason: 'teslim edilmemiş mal borç değildir');
      expect(borclu, isNot(contains(nakit)), reason: 'tamamı tahsil edilen borç bırakmaz');

      await db.close();
    });

    test('bakiyesi kapanan müşterinin siparişi listeden düşer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final musteri = await CustomerRepository(db).create(name: 'Ödeyen Ömer');
      final repo = OrderRepository(db);
      final veresiye = await repo.create(customerId: musteri, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 5000, qty: 1),
      ]);
      await repo.deliver(veresiye, paymentType: 'veresiye');
      expect((await watchOrders(db, OrderFilter.borclu).first).length, 1);

      // Bakiye önbelleği sıfırlanınca (tahsilat sonrası) sipariş borçlu değildir.
      await (db.update(db.customers)..where((t) => t.id.equals(musteri)))
          .write(const CustomersCompanion(balanceKurus: Value(0)));

      expect(await watchOrders(db, OrderFilter.borclu).first, isEmpty);
      await db.close();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // HATA 6 — kurye süzgeci
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('kurye süzgeci', () {
    test('yalnız patron görür', () {
      expect(kuryeSuzgeciGorunur('patron'), isTrue);
      expect(kuryeSuzgeciGorunur('kurye'), isFalse);
      expect(kuryeSuzgeciGorunur('operator'), isFalse);
      expect(kuryeSuzgeciGorunur(null), isFalse, reason: 'rol bilinmiyorsa kapı kapalı');
    });

    test('aday listesinde PATRON da bir kurye gibi durur', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.users).insert(
          UsersCompanion.insert(id: 'p1', name: 'Patron Pınar', role: 'patron', status: 'active'));
      await db.into(db.users).insert(
          UsersCompanion.insert(id: 'k1', name: 'Kurye Ali', role: 'kurye', status: 'active'));
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k2', name: 'Ayrılan Ayhan', role: 'kurye', status: 'disabled'));

      // SIRA ADA GÖRE, role göre DEĞİL ('Kurye Ali' < 'Patron Pınar'). Kullanıcının cümlesi
      // "patronun kendisi de aslında bir KURYE OLARAK görünmeli" — yani ayrıcalıklı bir satır
      // değil, diğerlerinin arasında sıradan bir satır. Rolü başa almak ayrıca iki patron/operator
      // olan bayide keyfî bir ikinci sıralama kuralı gerektirirdi ve `watchTeam` /
      // `watchAktifKuryeler` ile ayrışırdı — kullanıcı aynı ekibi her ekranda aynı sırada görmeli.
      final adaylar = await watchKuryeSuzgecAdaylari(db).first;
      expect(adaylar.map((u) => u.id).toList(), ['k1', 'p1'],
          reason: 'aktif patron+kurye ADA göre; pasif kullanıcı süzgeçte yer tutmaz');

      await db.close();
    });

    test('süzgeç siparişleri kuryeye ve "atanmamış"a göre ayırır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.users).insert(
          UsersCompanion.insert(id: 'p1', name: 'Patron Pınar', role: 'patron', status: 'active'));
      await db.into(db.users).insert(
          UsersCompanion.insert(id: 'k1', name: 'Kurye Ali', role: 'kurye', status: 'active'));

      final musteri = await CustomerRepository(db).create(name: 'Ayşe');
      final repo = OrderRepository(db);
      final aliSiparis = await repo.create(customerId: musteri, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      final patronSiparis = await repo.create(customerId: musteri, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      final bostaSiparis = await repo.create(customerId: musteri, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      await repo.assign(aliSiparis, 'k1');
      // Patronun kendisine atanan sipariş de süzülebilmeli (kullanıcı kararı).
      await repo.assign(patronSiparis, 'p1');

      Future<List<String>> suz(String? kim) async =>
          (await watchOrders(db, OrderFilter.tumu, assignedTo: kim).first)
              .map((e) => e.order.id)
              .toList();

      expect(await suz('k1'), [aliSiparis]);
      expect(await suz('p1'), [patronSiparis]);
      expect(await suz(kAtanmamisKurye), [bostaSiparis]);
      expect((await suz(null)).length, 3, reason: 'süzgeç yokken hepsi');

      await db.close();
    });
  });

  testWidgets('süzgeç düğmesi PATRONA çıkar, kuryede çıkmaz', (tester) async {
    genisYuzey(tester);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k1', name: 'Kurye Ali', role: 'kurye', status: 'active'));
      final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      await OrderRepository(db).create(customerId: m, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(userRole: Value('kurye')));
    });

    await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
    await akisiBekle(tester);
    expect(find.bySemanticsLabel('Kuryeye göre süz'), findsNothing);

    // Rol PATRONA döner (senkron yazar) — düğme belirir.
    await tester.runAsync(() async {
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(userRole: Value('patron')));
    });
    await akisiBekle(tester);
    expect(find.bySemanticsLabel('Kuryeye göre süz'), findsOneWidget);

    // Süzgeci seç: listede yalnız o kuryenin işi kalır (burada hiç → boş durum süzgeci söyler).
    await tester.tap(find.bySemanticsLabel('Kuryeye göre süz'));
    await akisiBekle(tester);
    await tester.tap(find.text('Kurye Ali'));
    await akisiBekle(tester);

    expect(find.text('Ayşe Yılmaz'), findsNothing);
    expect(find.text('Kurye Ali için bu filtrede sipariş yok.'), findsOneWidget);

    await ekraniKapat(tester);
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // HATA 4 — tutamaç tarafı
  // ═════════════════════════════════════════════════════════════════════════════════════════

  testWidgets('tutamaç VARSAYILAN SAĞDA, tercihle sola alınır', (tester) async {
    genisYuzey(tester);
    addTearDown(() => tutamacSagdaTercihi = true);

    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final m = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      final repo = OrderRepository(db);
      for (var i = 0; i < 2; i++) {
        await repo.create(customerId: m, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      }
    });

    await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
    await akisiBekle(tester);
    await tester.tap(find.text('Sırala'));
    await akisiBekle(tester);
    await tester.tap(find.text(siralamaEtiketi(OrderSort.elle)));
    await akisiBekle(tester);

    // Tutamaç, müşteri adının SAĞINDA (aynı satırda, daha büyük x).
    final adX = tester.getCenter(find.text('Ayşe Yılmaz').first).dx;
    final tutamacX =
        tester.getCenter(find.byType(ReorderableDragStartListener).first).dx;
    expect(tutamacX, greaterThan(adX), reason: 'varsayılan SAĞ (sağ el başparmağı)');

    // Sol elini kullanan bayi karşı tarafa alır.
    expect(find.text('Tutamaç sağda'), findsOneWidget);
    await tester.tap(find.text('Tutamaç sağda'));
    await akisiBekle(tester);

    expect(find.text('Tutamaç solda'), findsOneWidget);
    final yeniTutamacX =
        tester.getCenter(find.byType(ReorderableDragStartListener).first).dx;
    expect(yeniTutamacX, lessThan(adX), reason: 'tercih sola alındı');

    await ekraniKapat(tester);
  });
}

/// Testten sonra köprüyü kapalı bırakır: sızan bir sahte, sonraki testte sessizce yanlış
/// sonuç üretir. Gerçek açıcı yalnız uygulamada kullanılır.
Future<bool> _gercekAciciYerineHicbirSey(Uri _) async => false;
