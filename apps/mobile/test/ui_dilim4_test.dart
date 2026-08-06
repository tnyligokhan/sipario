import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/ledger_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/team.dart';
import 'package:sipario/sync/sync_api.dart';
import 'package:sipario/sync/sync_engine.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/ekran_yardimcilari.dart' show akislariBekle, sheetAnimasyonu;
import 'support/fake_sync_api.dart';

/// Dilim 4 UI testleri: kurye + kasa devri. Sorgu/yetki mantığı ekrandan bağımsız fonksiyonlarda
/// tutulur ve saf async sınanır; widget ilk-çizim testleri gizleme kapılarını doğrular. Widget-test
/// sahte zamanında HER gerçek drift async çağrısı tester.runAsync içinde await edilir (Dilim 1-3 dersi:
/// düz Future sorgular da asılır); db widget-testte close edilmez; test sonunda ağaç boşaltılır.
///
/// NOT (2026-07-26): AYRI `CashHandoverScreen` KALDIRILDI — tasarımda `kasaDevri` rotası yok, devir
/// Gün Sonu'nun "Hesabı Kapat · Kasa Devri" sheet'inin içindedir. `CashHandoverRepository` ve
/// `cash_handovers` tablosu YERİNDE: kurye kapanışı devri yazmaya devam ediyor
/// (`DayClosingRepository.kapat(alsoHandover: true)`), o yüzden repo testleri burada KALDI —
/// yalnız ekranın kendi görünüm testleri gitti.
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
    test('patron/operator: ürün+gün-sonu+düzeltme AÇIK', () {
      for (final rol in ['patron', 'operator']) {
        final y = yetkiler(rol: rol, kuryeVar: true);
        expect(y.urunYonetimi, isTrue, reason: '$rol ürün yönetir');
        expect(y.gunSonu, isTrue);
        expect(y.defterDuzeltme, isTrue);
        expect(y.tahsilat, isTrue);
      }
    });

    test('KURYE: yönetici işleri KAPALI; tahsilat AÇIK (kuryeVar önemsiz)', () {
      final y = yetkiler(rol: 'kurye', kuryeVar: false);
      expect(y.urunYonetimi, isFalse);
      expect(y.gunSonu, isFalse);
      expect(y.defterDuzeltme, isFalse);
      expect(y.atama, isFalse, reason: 'kurye atama yapmaz');
      expect(y.tahsilat, isTrue, reason: 'kurye sahada tahsilat alır (collected_by ondan)');
    });

    test('TEK KİŞİLİK BAYİ (patron, aktif kurye YOK): atama GİZLİ', () {
      final y = yetkiler(rol: 'patron', kuryeVar: false);
      expect(y.atama, isFalse, reason: 'tek kişilikte atama görünmez (BRIEF)');
      // İş yönetimi yine açık.
      expect(y.urunYonetimi, isTrue);
      expect(y.gunSonu, isTrue);
    });

    test('patron + aktif kurye VAR: atama AÇILIR', () {
      final y = yetkiler(rol: 'patron', kuryeVar: true);
      expect(y.atama, isTrue);
    });

    test('rol null (giriş öncesi): yönetici/atama kapalı, tahsilat açık', () {
      final y = yetkiler(rol: null, kuryeVar: true);
      expect(y.urunYonetimi, isFalse);
      expect(y.atama, isFalse);
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

  // KALDIRILAN İKİ TEST GRUBU (2026-07-26), ikisi de ÖLÜ YÜZEY savunuyordu:
  //  • `watchCashHandovers` — sorgu silinen `cash_handover_screen.dart` içindeydi, tek tüketicisi
  //    o ekrandı. Devrin append-only olduğunu yukarıdaki grup + `courier_test.dart` kanıtlıyor;
  //    geçmiş yeniden gösterilecekse sorgu `CashHandoverRepository`ye taşınmalı, test geri gelir.
  //  • `OrderFilter.benim` — "Benim" sekmesi kullanıcı kararıyla kalktı (tasarımda yoktu, atama
  //    kullanmayan bayide boş sekme karşılıyordu). Enum değeri ve `order_queries.dart` dalı da
  //    temizlenecek. Şeridin yeni sözleşmesi: test/ui_siparis_test.dart (dört sekme, "Benim" YOK).

  // ---------------------------------------------------------------------------
  // Widget ilk-çizim: gizleme kapıları (runAsync ŞART).
  // db BİLEREK kapatılmaz (Dilim 1 dersi: akış-abonelikli drift db'yi widget-test
  // zonunda kapatmak ASILI KALIR); bellek-içi db süreç sonunda gider. Test sonunda
  // ağaç boşaltılıp sahte saat ilerletilir (bekleyen zamanlayıcılar sönsün — !timersPending).
  // ---------------------------------------------------------------------------
  group('ekran görünürlüğü (widget ilk-çizim)', () {
    // ATAMA YÜZEYİ YİNE DEĞİŞTİ (2026-08-01, saha: "açık siparişe kurye ataması yapamıyorum"):
    // 2026-07-26'da "Kuryeye ata" bağlantısı kaldırılmış, çip yalnız DOLUYKEN çizilir olmuştu.
    // Ama sipariş formu "sonra da atanabilir" der oldu ve atanmamış açık siparişin HİÇBİR
    // yüzeyinde atama yolu kalmamıştı. Yeni sözleşme:
    //  • atanmamış + AÇIK + canAssign → SOLUK "Kurye ata" çipi; dokununca seçim sheet'i açılır
    //    ve seçim atamayı yazar (tek kişilik ilkesi canAssign'da korunur: yetkiler().atama =
    //    yönetici VE aktif kurye var — kuryesiz bayide çip hiç çizilmez)
    //  • atanmamış + !canAssign → hiç çip yok (eski davranış)
    //  • atanmış + canAssign → çip kuryenin adıyla ve DOKUNULABİLİR (atama değişebilir)
    //  • atanmış + !canAssign → çip var, dokunma KAPALI (K2: kurye atama yapmaz)
    // BEKLEME: çip `assignedUserId`yi EKİP AKIŞINDAN çözüyor ve ekran İÇ İÇE dört akış dinliyor
    // (sipariş · satırlar · ekip · adresler). Tek 150 ms turu ekip akışına yetmiyordu: çip
    // `kuryeAd == null` sanıp hiç çizilmiyordu. Paylaşılan `akislariBekle` (4×80 ms) kullanılıyor.
    testWidgets('sipariş detayı: atanmamış + canAssign → "Kurye ata" çipi, seçim atamayı YAZAR',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String orderId;
      await tester.runAsync(() async {
        await addUser(db, 'k1', 'Emre', 'kurye');
        orderId = await OrderRepository(db)
            .create(lines: [LineInput(productName: 'D', unitPriceKurus: 100, qty: 1)]);
      });

      // UZUN yüzey ŞART: varsayılan 600 piksellik yüzeyde sheet'in satırı ekranın ALTINDA
      // kalıyor ve dokunuş sessizce ıskalıyor (ölçüldü: hedef y=690) — siparis_yardimci dersi.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
          home: OrderDetailScreen(db: db, orderId: orderId, writable: true, canAssign: true)));
      await akislariBekle(tester);

      expect(find.text('Kurye ata'), findsOneWidget,
          reason: 'atanmamış açık siparişte atama girişi olmalı — form "sonra da atanabilir" diyor');

      await tester.tap(find.text('Kurye ata'));
      // İKİ aşama: dokunuş önce GERÇEK drift sorgusunu bekler (watchAktifKuryeler.first) — sheet
      // ancak sheetAnimasyonu'nun runAsync turunda AÇILIR; kayma animasyonunu bitirmek için
      // AÇILIŞTAN SONRA ayrıca süreli pump gerekir, yoksa satır ağaçta var ama ekran dışında
      // kalır ve dokunuş sessizce ıskalar (ölçüldü: hedef y=2490 > 2400).
      await sheetAnimasyonu(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Emre'), findsOneWidget, reason: 'seçim sheet\'i aktif kuryeleri listeler');

      await tester.tap(find.text('Emre'));
      await sheetAnimasyonu(tester);

      final atanmis = await tester.runAsync(
          () => (db.select(db.orders)..where((o) => o.id.equals(orderId))).getSingle());
      expect(atanmis!.assignedUserId, 'k1',
          reason: 'çipten yapılan seçim mevcut atama yolundan (assign → olay) yazılmalı');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sipariş detayı: atanmamış + canAssign=false → "Kurye ata" çipi YOK',
        (tester) async {
      // Tek kişilik bayi / kurye rolü: atama yetkisi olmayana kurye kavramı hatırlatılmaz.
      final db = AppDatabase(NativeDatabase.memory());
      late String orderId;
      await tester.runAsync(() async {
        await addUser(db, 'k1', 'Emre', 'kurye');
        orderId = await OrderRepository(db)
            .create(lines: [LineInput(productName: 'D', unitPriceKurus: 100, qty: 1)]);
      });

      await tester.pumpWidget(MaterialApp(
          home: OrderDetailScreen(db: db, orderId: orderId, writable: true, canAssign: false)));
      await akislariBekle(tester);

      expect(find.text('Kurye ata'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sipariş detayı: atanmış + canAssign=true → çip DOKUNULABİLİR', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String orderId;
      await tester.runAsync(() async {
        await addUser(db, 'k1', 'Emre', 'kurye');
        final orders = OrderRepository(db);
        orderId = await orders
            .create(lines: [LineInput(productName: 'D', unitPriceKurus: 100, qty: 1)]);
        await orders.assign(orderId, 'k1');
      });

      await tester.pumpWidget(MaterialApp(
          home: OrderDetailScreen(db: db, orderId: orderId, writable: true, canAssign: true)));
      await akislariBekle(tester);

      expect(find.text('Emre'), findsOneWidget, reason: 'çip atanan kuryenin adını taşır');
      final cip = tester.widget<SipDokun>(
        find.ancestor(of: find.text('Emre'), matching: find.byType(SipDokun)).first,
      );
      expect(cip.onTap, isNotNull, reason: 'yönetici çipten atamayı değiştirebilir');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sipariş detayı: atanmış + canAssign=false → çip var, dokunma KAPALI (K2)',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String orderId;
      await tester.runAsync(() async {
        await addUser(db, 'k1', 'Emre', 'kurye');
        final orders = OrderRepository(db);
        orderId = await orders
            .create(lines: [LineInput(productName: 'D', unitPriceKurus: 100, qty: 1)]);
        await orders.assign(orderId, 'k1');
      });

      await tester.pumpWidget(MaterialApp(
          home: OrderDetailScreen(db: db, orderId: orderId, writable: true, canAssign: false)));
      await akislariBekle(tester);

      // Bilgi KAYBOLMAZ (kurye kime atandığını görür), yalnız EYLEM kapanır.
      expect(find.text('Emre'), findsOneWidget);
      final cip = tester.widget<SipDokun>(
        find.ancestor(of: find.text('Emre'), matching: find.byType(SipDokun)).first,
      );
      expect(cip.onTap, isNull, reason: 'kurye atama yapmaz (K2)');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    // NOT — 'kurye → "Benim" sekmesi VAR' testi de KALDIRILDI: sekme hiçbir rolde çizilmiyor.
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
      // SİPARİO 3.0: menüyü açan şey artık bir metin değil, ana ekran hero'sundaki ikon
      // düğmesi (`SipIkonButon(ikon: menu, etiket: 'Menü')`). Tasarımda o düğmenin yanında
      // yazı YOK — bilinçli bir görsel karar — bu yüzden etiketi semantikten okuyoruz.
      await tester.tap(find.bySemanticsLabel('Menü'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }

    // CİHAZDA YAKALANAN GERİLEME (2026-07-26): kabuk `onMenu`yu YALNIZ ana ekrana geçiyordu.
    // Diğer üç sekmede hamburger hiç çizilmiyordu (Gün Sonu'nda yerine işlevsiz bir geri oku
    // vardı) — yani çekmece, dolayısıyla Ürünler/Kuryeler/Muaf/Ayarlar/çıkış, o sekmelerdeyken
    // ERİŞİLEMEZDİ. Tasarımda (s-uygulama.jsx) dört ana ekranın dördü de `onMenu` alır.
    testWidgets('çekmece DÖRT sekmenin hepsinden açılabilir', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await setUser(db, id: 'p', role: 'patron');
        await addUser(db, 'p', 'Patron', 'patron');
      });

      final session = Session(db);
      final sync = SyncService(db);
      await tester.pumpWidget(MaterialApp(
          home: HomeShell(db: db, session: session, sync: sync, onLoggedOut: () {})));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      // Sekmelere METİNLE dokunulamaz: tasarımda yalnız SEÇİLİ sekmenin etiketi görünür
      // (CSS `.altnav-b span { display: none }`), diğerleri sadece ikon. Erişilebilirlik
      // etiketi ise her zaman var — dokunuş oradan.
      for (final sekme in ['Ana', 'Müşteri', 'Sipariş', 'Gün Özeti']) {
        if (sekme != 'Ana') {
          await tester.tap(find.bySemanticsLabel(sekme).last);
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await tester.pump();
        }
        expect(find.bySemanticsLabel('Menü'), findsWidgets,
            reason: '$sekme sekmesinde çekmeceyi açacak düğme yok — '
                'Ürünler/Kuryeler/Muaf/Ayarlar/çıkış oradan erişiliyor');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    // Aynı turda bulunan ikinci kopukluk: Ayarlar ekranı yazılmıştı ama çekmecede girişi yoktu,
    // ve Kuryeler/Muaf/İşletme Profili yalnız Ayarlar'dan açıldığı için o dalın TAMAMI ölüydü.
    testWidgets('çekmecede Kuryeler · Muaf Telefonlar · Ayarlar girişleri VAR', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await setUser(db, id: 'p', role: 'patron');
        await addUser(db, 'p', 'Patron', 'patron');
      });

      await pumpShell(tester, db);

      for (final giris in ['Ürünler', 'Kuryeler', 'Muaf Telefonlar', 'Ayarlar']) {
        expect(find.text(giris), findsOneWidget, reason: '$giris çekmecede yok');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    // AYRI KASA DEVRİ EKRANI KALDIRILDI (2026-07-26): çekmecedeki satır artık Gün Sonu sekmesine
    // gider ve rolüne göre ETİKETLENİR — kuryede "Kasa Devri" (kendi işinin adı), yöneticide
    // tasarımın birleşik etiketi "Gün Sonu & Kasa Devri". Bu testler kabuğun tamamı üzerinden
    // (HomeShell) bakar; çekmecenin kendi sözleşmesi test/ui_kabuk_test.dart'ta.
    testWidgets('kurye kabuğu: Ürünler/Gün sonu YOK, satır "Kasa Devri" adıyla VAR',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await setUser(db, id: 'k1', role: 'kurye');
        await addUser(db, 'k1', 'Kurye', 'kurye');
      });

      await pumpShell(tester, db);

      expect(find.text('Ürünler'), findsNothing);
      expect(find.text('Gün Özeti & Kasa Devri'), findsNothing,
          reason: 'kuryede birleşik yönetici etiketi kullanılmaz');
      expect(find.text('Kasa Devri'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    testWidgets('patron + aktif kurye YOK: Ürünler/Gün sonu VAR (tek kişilik)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await setUser(db, id: 'p', role: 'patron');
        await addUser(db, 'p', 'Patron', 'patron'); // kurye YOK
      });

      await pumpShell(tester, db);

      expect(find.text('Ürünler'), findsOneWidget);
      expect(find.text('Gün Özeti & Kasa Devri'), findsOneWidget);
      expect(find.text('Kasa Devri'), findsNothing,
          reason: 'kuryeye özgü etiket yöneticide çizilmez — tek satır, tek hedef');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    testWidgets('patron kabuğu + aktif kurye VAR: etiket kuryeVar\'a göre DEĞİŞMEZ',
        (tester) async {
      // Eski davranış: kasa devri girişi yöneticide yalnız aktif kurye varken açılıyordu. Artık
      // ayrı ekran yok — satır Gün Sonu'na gidiyor ve yönetici onu her hâlde görüyor.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await setUser(db, id: 'p', role: 'patron');
        await addUser(db, 'p', 'Patron', 'patron');
        await addUser(db, 'k1', 'Kurye', 'kurye'); // aktif kurye VAR → çok kişilik
      });

      await pumpShell(tester, db);

      expect(find.text('Ürünler'), findsOneWidget);
      expect(find.text('Gün Özeti & Kasa Devri'), findsOneWidget);
      expect(find.text('Kasa Devri'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    // NOT — "Ekran 4 / Menü sekmesi" testleri KALDIRILDI (2026-07-26): o ekran tasarımda YOK,
    // yerini Çekmece aldı; çekmecenin görünüm sözleşmesi test/ui_kabuk_test.dart'ta.
  });
}
