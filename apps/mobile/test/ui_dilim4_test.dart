import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/cash_handover_screen.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/screens/money.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/team.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';
import 'package:sipario/sync/sync_service.dart';

import 'support/fake_sync_api.dart';

/// Dilim 4 UI testleri: kurye + kasa devri. Sorgu/yetki mantığı ekrandan bağımsız fonksiyonlarda
/// tutulur ve saf async sınanır; widget ilk-çizim testleri gizleme kapılarını doğrular. Widget-test
/// sahte zamanında HER gerçek drift async çağrısı tester.runAsync içinde await edilir (Dilim 1-3 dersi:
/// düz Future sorgular da asılır); db widget-testte close edilmez; test sonunda ağaç boşaltılır.
void main() {
  Future<void> addUser(AppDatabase db, String id, String name, String role,
          {String status = 'active'}) =>
      db.into(db.users).insert(
          UsersCompanion.insert(id: id, name: name, role: role, status: status));

  Future<void> setUser(AppDatabase db, {String? id, String? role}) async {
    await db.syncState(); // meta satırı (id=1) hazır olsun
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(userId: Value(id), userRole: Value(role)));
  }

  // ---------------------------------------------------------------------------
  // K2 rol matrisi — tek kişilik gizleme regresyonu (pazarlıksız, BRIEF)
  // ---------------------------------------------------------------------------
  group('yetkiler() — K2 rol matrisi', () {
    test('patron/operator: ürün+gün-sonu+kupon+düzeltme AÇIK', () {
      for (final rol in ['patron', 'operator']) {
        final y = yetkiler(rol: rol, kuryeVar: true);
        expect(y.urunYonetimi, isTrue, reason: '$rol ürün yönetir');
        expect(y.gunSonu, isTrue);
        expect(y.kuponSatisi, isTrue);
        expect(y.defterDuzeltme, isTrue);
        expect(y.tahsilat, isTrue);
      }
    });

    test('KURYE: yönetici işleri KAPALI; tahsilat + kasa devri AÇIK (kuryeVar önemsiz)', () {
      final y = yetkiler(rol: 'kurye', kuryeVar: false);
      expect(y.urunYonetimi, isFalse);
      expect(y.gunSonu, isFalse);
      expect(y.kuponSatisi, isFalse);
      expect(y.defterDuzeltme, isFalse);
      expect(y.atama, isFalse, reason: 'kurye atama yapmaz');
      expect(y.tahsilat, isTrue, reason: 'kurye sahada tahsilat alır (collected_by ondan)');
      expect(y.kasaDevri, isTrue, reason: 'kurye kendisi kanıttır — her zaman kendi devrini görür');
    });

    test('TEK KİŞİLİK BAYİ (patron, aktif kurye YOK): atama VE kasa devri GİZLİ', () {
      final y = yetkiler(rol: 'patron', kuryeVar: false);
      expect(y.atama, isFalse, reason: 'tek kişilikte atama görünmez (BRIEF)');
      expect(y.kasaDevri, isFalse, reason: 'tek kişilikte kasa devri görünmez (BRIEF)');
      // İş yönetimi yine açık.
      expect(y.urunYonetimi, isTrue);
      expect(y.gunSonu, isTrue);
    });

    test('patron + aktif kurye VAR: atama ve kasa devri AÇILIR', () {
      final y = yetkiler(rol: 'patron', kuryeVar: true);
      expect(y.atama, isTrue);
      expect(y.kasaDevri, isTrue);
    });

    test('rol null (giriş öncesi): yönetici/atama/kasa kapalı, tahsilat açık', () {
      final y = yetkiler(rol: null, kuryeVar: true);
      expect(y.urunYonetimi, isFalse);
      expect(y.atama, isFalse);
      expect(y.kasaDevri, isFalse);
      expect(y.tahsilat, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // SyncEngine team önbelleği (_applyTeam) — toptan tazeleme + null koruması
  // ---------------------------------------------------------------------------
  group('SyncEngine team önbelleği (_applyTeam)', () {
    late AppDatabase db;
    late FakeSyncApi api;
    late SyncEngine engine;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      api = FakeSyncApi();
      engine = SyncEngine(db, api);
    });
    tearDown(() => db.close());

    PullResponse withTeam(List<Map<String, dynamic>>? team) => PullResponse(
        mode: 'delta', cursor: 0, hasMore: false, currentSeq: 0, team: team);

    test('team bloğu users aynasını TOPTAN yazar', () async {
      api.pullQueue.add(withTeam([
        {'id': 'u1', 'name': 'Ali', 'role': 'patron', 'status': 'active'},
        {'id': 'u2', 'name': 'Veli', 'role': 'kurye', 'status': 'active'},
      ]));
      await engine.pull();
      final ids = (await db.select(db.users).get()).map((u) => u.id).toSet();
      expect(ids, {'u1', 'u2'});
    });

    test('team=null (anahtar yok) yerel users\'a DOKUNMAZ (KRİTİK — eski sunucu)', () async {
      await addUser(db, 'u1', 'Ali', 'patron');
      // pullQueue boş → varsayılan yanıt team taşımaz (null).
      await engine.pull();
      expect(await db.select(db.users).get(), hasLength(1),
          reason: 'team null → önbellek korunur; silinirse kurye adımları yanlış gizlenir');
    });

    test('listeden düşen kullanıcı yerelden silinir (toptan değişim)', () async {
      await addUser(db, 'eski', 'Eski Kurye', 'kurye');
      api.pullQueue.add(withTeam([
        {'id': 'u1', 'name': 'Ali', 'role': 'patron', 'status': 'active'},
      ]));
      await engine.pull();
      final ids = (await db.select(db.users).get()).map((u) => u.id).toSet();
      expect(ids, {'u1'});
    });

    test('team boş liste [] önbelleği temizler', () async {
      await addUser(db, 'u1', 'Ali', 'patron');
      api.pullQueue.add(withTeam(const []));
      await engine.pull();
      expect(await db.select(db.users).get(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Ekip sorguları (team.dart)
  // ---------------------------------------------------------------------------
  group('ekip sorguları (team.dart)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await addUser(db, 'p', 'Patron', 'patron');
      await addUser(db, 'o', 'Operator', 'operator');
      await addUser(db, 'k1', 'Kurye Bir', 'kurye');
      await addUser(db, 'k2', 'Kurye İki', 'kurye', status: 'disabled');
    });
    tearDown(() => db.close());

    test('watchAktifKuryeler yalnız AKTİF kuryeleri döner', () async {
      final list = await watchAktifKuryeler(db).first;
      expect(list.map((u) => u.id).toList(), ['k1'],
          reason: 'pasif kurye k2 atama hedefi olamaz');
    });

    test('watchYoneticiler aktif patron+operator döner (kurye hariç)', () async {
      final list = await watchYoneticiler(db).first;
      expect(list.map((u) => u.id).toSet(), {'p', 'o'});
    });

    test('kullaniciAdi çözer; pasif de çözülür; bulunamazsa/null → null', () async {
      final team = await watchTeam(db).first;
      expect(kullaniciAdi(team, 'k1'), 'Kurye Bir');
      expect(kullaniciAdi(team, 'k2'), 'Kurye İki',
          reason: 'pasif kullanıcı adı eski atamalarda gösterilmeli');
      expect(kullaniciAdi(team, 'yok'), isNull);
      expect(kullaniciAdi(team, null), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Kasa devri — onizle == devret tutarlılığı (ekran gösterimi = kayıt)
  // ---------------------------------------------------------------------------
  group('kasa devri: onizle == devret', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('onizle beklenen = kayıttaki expectedCashKurus; fark = sayılan − beklenen', () async {
      await setUser(db, id: 'k1', role: 'kurye');
      final custId = await CustomerRepository(db).create(name: 'Nakitçi');
      await LedgerRepository(db).tahsilat(custId, 5000, 'nakit'); // collected_by=k1
      await LedgerRepository(db).tahsilat(custId, 3000, 'kart'); // fiziksel kasa değil

      final repo = CashHandoverRepository(db);
      final on = await repo.onizle('k1');
      expect(on.expectedKurus, 5000, reason: 'yalnız nakit; kart hariç');

      final id = await repo.devret(fromUserId: 'k1', countedCashKurus: 4500);
      final row = await (db.select(db.cashHandovers)..where((t) => t.id.equals(id))).getSingle();
      expect(row.expectedCashKurus, on.expectedKurus,
          reason: 'ekran önizlemesi ile kayıt AYNI koddan çıkar');
      expect(row.diffKurus, 4500 - 5000, reason: 'fark kanıt olarak yazılır (−500)');
    });

    test('ikinci onizle penceresi son devrin occurredAt\'inden başlar', () async {
      await setUser(db, id: 'k1', role: 'kurye');
      final repo = CashHandoverRepository(db);
      final firstId = await repo.devret(fromUserId: 'k1', countedCashKurus: 0);
      final first =
          await (db.select(db.cashHandovers)..where((t) => t.id.equals(firstId))).getSingle();

      final on = await repo.onizle('k1');
      expect(on.periodStartIso, first.occurredAt,
          reason: 'sonraki mutabakat penceresi son devirden başlar (period_start)');
    });

    test(
        'ikinci devir ÖNCEKİNİ DEĞİŞTİRMEZ (append-only); eksik para (negatif fark) kanıt olarak durur',
        () async {
      await setUser(db, id: 'k1', role: 'kurye');
      final custId = await CustomerRepository(db).create(name: 'Eksik Kasa');
      await LedgerRepository(db).tahsilat(custId, 5000, 'nakit'); // beklenen 5000

      final repo = CashHandoverRepository(db);
      // Sayılan 4500 < beklenen 5000 → fark −500: eksik para, BRIEF'e göre devir yine de yazılır.
      final firstId = await repo.devret(fromUserId: 'k1', countedCashKurus: 4500);
      final oncekiSatirlar = await db.select(db.cashHandovers).get();
      expect(oncekiSatirlar, hasLength(1));
      final ilkOnce = oncekiSatirlar.single;
      expect(ilkOnce.diffKurus, -500, reason: 'eksik para negatif fark olarak yazılır (kanıt)');

      // uuid7 aynı ms'de monoton değil → sıralamanın dayanağı occurred_at ayrışsın diye bekle.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // İkinci devir (yeni dönem, sıfır sayım) — birinci satırı ASLA EZMEZ (silme/UPDATE yok).
      await repo.devret(fromUserId: 'k1', countedCashKurus: 0);

      final sonrakiSatirlar = await db.select(db.cashHandovers).get();
      expect(sonrakiSatirlar, hasLength(2),
          reason: 'ikinci devir YENİ satırdır, öncekinin yerine geçmez');

      final ilkSonra = sonrakiSatirlar.firstWhere((h) => h.id == firstId);
      expect(ilkSonra, equals(ilkOnce),
          reason: 'append-only: ilk devir satırının TEK bir alanı bile değişmemiş olmalı');
      expect(ilkSonra.diffKurus, -500,
          reason: 'eksik para kanıtı ikinci devirden sonra da GÖRÜNÜR kalır (BRIEF)');
    });
  });

  // ---------------------------------------------------------------------------
  // CashHandoverScreen — ekran-repo tutarlılığı (paralel hesap yok)
  // ---------------------------------------------------------------------------
  group('CashHandoverScreen: ekran-repo tutarlılığı (beklenen nakit = onizle())', () {
    testWidgets('ekranda gösterilen "Beklenen nakit" repo.onizle() ile birebir aynı metinle çıkar',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late int gercekBeklenen;
      await tester.runAsync(() async {
        await setUser(db, id: 'k1', role: 'kurye');
        final custId = await CustomerRepository(db).create(name: 'Ekran Kasa');
        await LedgerRepository(db).tahsilat(custId, 12345, 'nakit');
        await LedgerRepository(db).tahsilat(custId, 3000, 'kart'); // fiziksel kasa değil (kontrast)
        gercekBeklenen = (await CashHandoverRepository(db).onizle('k1')).expectedKurus;
      });

      await tester.pumpWidget(MaterialApp(
          home: CashHandoverScreen(db: db, userId: 'k1', writable: true, userRole: 'kurye')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      // Ekranın sabit bir metnini tahmin etmiyoruz — repo'nun ürettiği gerçek değeri formatKurus'a
      // sokup ekranda arıyoruz (Dilim 3 ekran-repo tutarlılığı deseniyle simetri).
      expect(find.text(formatKurus(gercekBeklenen)), findsOneWidget,
          reason: 'ekranın önizlemesi ile repo.onizle() paralel hesap değil, AYNI kod');
      expect(gercekBeklenen, 12345, reason: 'yalnız nakit toplanır; kart hariç (sağlamlık)');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  // ---------------------------------------------------------------------------
  // watchCashHandovers (geçmiş sorgusu)
  // ---------------------------------------------------------------------------
  group('watchCashHandovers (geçmiş)', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('fromUserId → yalnız o kurye; null → tümü; en yeni önce', () async {
      final repo = CashHandoverRepository(db);
      await repo.devret(fromUserId: 'k1', countedCashKurus: 100);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.devret(fromUserId: 'k2', countedCashKurus: 200);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.devret(fromUserId: 'k1', countedCashKurus: 300);

      final k1 = await watchCashHandovers(db, fromUserId: 'k1').first;
      expect(k1.map((h) => h.countedCashKurus).toList(), [300, 100],
          reason: 'yalnız k1, en yeni önce');

      final all = await watchCashHandovers(db).first;
      expect(all, hasLength(3));
      expect(all.first.countedCashKurus, 300, reason: 'yönetici görünümü: tümü, en yeni önce');
    });
  });

  // ---------------------------------------------------------------------------
  // watchOrders — "Benim" filtresi (kuryenin iş listesi)
  // ---------------------------------------------------------------------------
  group('watchOrders — Benim filtresi', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<String> mkOrder(OrderRepository r) =>
        r.create(lines: [LineInput(productName: 'D', unitPriceKurus: 100, qty: 1)]);

    test('yalnız bana atanmış AÇIK siparişler', () async {
      final orders = OrderRepository(db);
      final o1 = await mkOrder(orders);
      await Future<void>.delayed(const Duration(milliseconds: 3));
      final o2 = await mkOrder(orders);
      await Future<void>.delayed(const Duration(milliseconds: 3));
      await mkOrder(orders); // o3 atanmamış
      await orders.assign(o1, 'k1');
      await orders.assign(o2, 'k2');

      final benim = await watchOrders(db, OrderFilter.benim, assignedTo: 'k1').first;
      expect(benim.map((i) => i.order.id).toList(), [o1], reason: 'yalnız k1\'e atanmış açık sipariş');
    });

    test('teslim edilen sipariş Benim listesinden düşer (yalnız açık)', () async {
      final orders = OrderRepository(db);
      final custId = await CustomerRepository(db).create(name: 'X');
      final o = await orders.create(
          customerId: custId, lines: [LineInput(productName: 'D', unitPriceKurus: 100, qty: 1)]);
      await orders.assign(o, 'k1');
      await orders.deliver(o, paymentType: 'nakit');

      final benim = await watchOrders(db, OrderFilter.benim, assignedTo: 'k1').first;
      expect(benim, isEmpty, reason: 'teslim edilmiş sipariş kuryenin açık iş listesinde olmamalı');
    });

    test('assignedTo null → boş (kimseye atanmamış gösterilmez)', () async {
      final orders = OrderRepository(db);
      await mkOrder(orders);
      final benim = await watchOrders(db, OrderFilter.benim, assignedTo: null).first;
      expect(benim, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget ilk-çizim: gizleme kapıları (runAsync ŞART).
  // db BİLEREK kapatılmaz (Dilim 1 dersi: akış-abonelikli drift db'yi widget-test
  // zonunda kapatmak ASILI KALIR); bellek-içi db süreç sonunda gider. Test sonunda
  // ağaç boşaltılıp sahte saat ilerletilir (bekleyen zamanlayıcılar sönsün — !timersPending).
  // ---------------------------------------------------------------------------
  group('ekran görünürlüğü (widget ilk-çizim)', () {
    testWidgets('sipariş detayı: canAssign=false → "Kuryeye ata" YOK (tek kişilik)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String orderId;
      await tester.runAsync(() async {
        orderId = await OrderRepository(db)
            .create(lines: [LineInput(productName: 'D', unitPriceKurus: 100, qty: 1)]);
      });

      await tester.pumpWidget(MaterialApp(
          home: OrderDetailScreen(db: db, orderId: orderId, writable: true, canAssign: false)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Kuryeye ata'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sipariş detayı: canAssign=true + açık → "Kuryeye ata" VAR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String orderId;
      await tester.runAsync(() async {
        orderId = await OrderRepository(db)
            .create(lines: [LineInput(productName: 'D', unitPriceKurus: 100, qty: 1)]);
      });

      await tester.pumpWidget(MaterialApp(
          home: OrderDetailScreen(db: db, orderId: orderId, writable: true, canAssign: true)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      expect(find.text('Kuryeye ata'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sipariş listesi: kurye → "Benim" sekmesi VAR; patron → YOK', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(MaterialApp(
          home: OrderListScreen(db: db, writable: true, userRole: 'kurye', userId: 'k1')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      expect(find.text('Benim'), findsOneWidget, reason: 'kuryede günlük iş sekmesi');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));

      await tester.pumpWidget(MaterialApp(
          home: OrderListScreen(db: db, writable: true, userRole: 'patron', userId: 'p')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      expect(find.text('Benim'), findsNothing, reason: 'yöneticide Benim sekmesi yok');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('kasa devri: salt-okunur kipte devir SnackBar ile engellenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => setUser(db, id: 'k1', role: 'kurye'));

      await tester.pumpWidget(MaterialApp(
          home: CashHandoverScreen(db: db, userId: 'k1', writable: false, userRole: 'kurye')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      await tester.tap(find.text('Kasayı devret'));
      await tester.pump();
      expect(find.textContaining('Salt-okunur'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('kasa devri: mağaza-kuralı ihlali yok (satın alma/abonelik metni)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => setUser(db, id: 'k1', role: 'kurye'));

      await tester.pumpWidget(MaterialApp(
          home: CashHandoverScreen(db: db, userId: 'k1', writable: true, userRole: 'kurye')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      for (final yasak in ['Abone', 'Satın al', 'Üye ol', 'Kaydol', 'Ödeme yap']) {
        expect(find.textContaining(yasak), findsNothing, reason: '"$yasak" mobilde gösterilemez');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  // ---------------------------------------------------------------------------
  // HomeShell menü gizleme (entegrasyon: doğru bayraklar menüye geçiyor mu)
  // ---------------------------------------------------------------------------
  group('HomeShell menü gizleme (tek kişilik regresyonu)', () {
    Future<void> pumpShell(WidgetTester tester, AppDatabase db) async {
      final session = Session(db);
      final sync = SyncService(db); // kuruluşta ağ/timer YOK; start() çağrılmaz
      await tester.pumpWidget(MaterialApp(
          home: HomeShell(db: db, session: session, sync: sync, onLoggedOut: () {})));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.tap(find.text('Menü'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }

    testWidgets('kurye kabuğu: Ürünler/Gün sonu YOK, Kasa devri VAR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await setUser(db, id: 'k1', role: 'kurye');
        await addUser(db, 'k1', 'Kurye', 'kurye');
      });

      await pumpShell(tester, db);

      expect(find.text('Ürünler'), findsNothing);
      expect(find.text('Gün sonu'), findsNothing);
      expect(find.text('Kasa devri'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    testWidgets('patron + aktif kurye YOK: Ürünler/Gün sonu VAR, Kasa devri YOK (tek kişilik)',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await setUser(db, id: 'p', role: 'patron');
        await addUser(db, 'p', 'Patron', 'patron'); // kurye YOK
      });

      await pumpShell(tester, db);

      expect(find.text('Ürünler'), findsOneWidget);
      expect(find.text('Gün sonu'), findsOneWidget);
      expect(find.text('Kasa devri'), findsNothing,
          reason: 'tek kişilik bayide kasa devri girişi HİÇ render edilmez (BRIEF)');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    testWidgets(
        'patron kabuğu + aktif kurye VAR: Ürünler/Gün sonu/Kasa devri HEPSİ VAR (kontrast çifti)',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await setUser(db, id: 'p', role: 'patron');
        await addUser(db, 'p', 'Patron', 'patron');
        await addUser(db, 'k1', 'Kurye', 'kurye'); // aktif kurye VAR → çok kişilik
      });

      await pumpShell(tester, db);

      expect(find.text('Ürünler'), findsOneWidget);
      expect(find.text('Gün sonu'), findsOneWidget);
      expect(find.text('Kasa devri'), findsOneWidget,
          reason: 'aktif kurye varken yönetici kasa devrini de görür (tek-kişilik gizlemenin tersi)');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });
  });
}
