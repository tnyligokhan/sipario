// İKİ SAHA İSTEĞİ, tek dosya — ikisi de "sipariş ekranında ne görünüyor, ne oluyor" sorusu.
//
//  A. YENİ SİPARİŞTE KURYE SEÇİMİ. Siparişi girerken kimin götüreceği çoğu zaman bellidir;
//     onu atamak için kaydedip listeye dönüp detayı açmak üç fazladan dokunuştu. Seçim
//     OPSİYONELDİR ve atama MEVCUT yoldan (`assign` → `assigned` olayı → outbox) yazılır —
//     formun kendine ait bir yazma yolu YOKTUR.
//
//  B. "OTO SIRALA" SAHA HATASI: düğme, rotaya girecek açık sipariş kalmayan sekmelerde de ETKİN
//     çiziliyor ve dokunulunca hata veriyordu. "Teslim"/"Borçlu" sekmeleri tanımı gereği KAPALI
//     sipariş listeler, yani orada küme HER ZAMAN boştur — kullanıcı "sıralanacak sipariş yok"
//     okuyup bir sekme ötede duran açık siparişlerini düşünüyordu. Gerekçe artık dokunmadan
//     ÖNCE, düğmenin altında yazar.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/orders/order_form_screen.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/siparis_yardimci.dart';

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // A. Yeni sipariş formunda KURYE SEÇİMİ
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('OrderFormScreen — kurye seçimi (opsiyonel)', () {
    /// Katalogda tek ürün, tek müşteri, tek AKTİF kurye. [rol] `sync_meta.user_role`e yazılır:
    /// satırın görünürlüğü K2 matrisinden (`yetkiler().atama`) türer, ekranın kendi kararı değil.
    Future<AppDatabase> kur({required String rol}) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500, unit: 'adet');
      await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k1',
            name: 'Kurye Ali',
            role: 'kurye',
            status: 'active',
          ));
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(SyncMetaCompanion(userRole: Value(rol)));
      return db;
    }

    /// Müşteri seç → katalogdan bir kalem → "Devam" (özet adımına geç).
    Future<void> ozeteKadar(WidgetTester tester) async {
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
      await tester.tap(find.text('Devam'));
      await akisiBekle(tester);
    }

    testWidgets('patron kurye seçer → kayıt ATAMA OLAYI üretir (yeni yazma yolu YOK)',
        (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(rol: 'patron'));

      await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await ozeteKadar(tester);

      // Satır BOŞ başlar: seçim zorunlu değil, metin de bunu söyler.
      expect(find.text('Atama yok — sonra da atanabilir'), findsOneWidget);

      await tester.tap(find.text('Atama yok — sonra da atanabilir'));
      await akisiBekle(tester);
      await tester.tap(find.text('Kurye Ali'));
      await akisiBekle(tester);

      // Seçim satıra yansır — kullanıcı kaydetmeden önce kime gittiğini görür.
      expect(find.text('Kurye Ali'), findsOneWidget);

      await tester.tap(find.text('Siparişi Kaydet'));
      await akisiBekle(tester, ms: 300);

      late List<OrderEvent> olaylar;
      late List<Order> siparisler;
      await tester.runAsync(() async {
        olaylar = await db.select(db.orderEvents).get();
        siparisler = await db.select(db.orders).get();
      });

      final atama = olaylar.where((e) => e.eventType == 'assigned').toList();
      expect(atama, hasLength(1),
          reason: 'atama TEK yazma yüzeyinden geçer: `assign` → `assigned` olayı → outbox');
      expect(atama.single.orderId, siparisler.single.id);
      expect(siparisler.single.assignedUserId, 'k1',
          reason: 'assigned_user_id bir ÖNBELLEKTİR — kaynağı yukarıdaki olaydır');

      await ekraniKapat(tester);
    });

    testWidgets('kurye seçilmezse atama olayı YAZILMAZ (seçim gerçekten opsiyonel)',
        (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(rol: 'patron'));

      await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await ozeteKadar(tester);

      // Satıra HİÇ dokunulmaz — sipariş atamasız kaydedilmeli.
      await tester.tap(find.text('Siparişi Kaydet'));
      await akisiBekle(tester, ms: 300);

      late List<OrderEvent> olaylar;
      late List<Order> siparisler;
      await tester.runAsync(() async {
        olaylar = await db.select(db.orderEvents).get();
        siparisler = await db.select(db.orders).get();
      });

      expect(olaylar.where((e) => e.eventType == 'assigned'), isEmpty);
      expect(siparisler.single.assignedUserId, isNull);

      await ekraniKapat(tester);
    });

    testWidgets('KURYE rolünde kurye satırı hiç çizilmez (K2: atama yöneticinin işi)',
        (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(rol: 'kurye'));

      await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await ozeteKadar(tester);

      // Özet adımının kendisi çizildi (bölüm başlıkları yerinde) — yalnız Kurye bölümü yok.
      expect(find.text('Sipariş Notu'), findsOneWidget);
      expect(find.text('Kurye'), findsNothing);
      expect(find.text('Atama yok — sonra da atanabilir'), findsNothing);

      await ekraniKapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // B. "Oto Sırala" — küme yetersizken düğme PASİF ve gerekçe DOKUNMADAN ÖNCE yazar
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('OrderListScreen — Oto Sırala küme kapısı', () {
    /// [teslim] adet kapalı + 2 açık sipariş. Oturum ve kontör senkronla gelmiş sayılır
    /// (yoksa düğmenin kilit gerekçesi kontör olurdu, sınamak istediğimiz o değil).
    Future<AppDatabase> kur({int teslim = 0, String rol = 'patron'}) async {
      final db = AppDatabase(NativeDatabase.memory());
      final musteri = CustomerRepository(db);
      final repo = OrderRepository(db);
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k1',
            name: 'Kurye Ali',
            role: 'kurye',
            status: 'active',
          ));
      for (var i = 0; i < 2; i++) {
        final m = await musteri.create(name: 'Açık Müşteri $i');
        await repo.create(customerId: m, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      }
      for (var i = 0; i < teslim; i++) {
        final m = await musteri.create(name: 'Teslim Müşteri $i');
        final id = await repo.create(customerId: m, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
        await repo.deliver(id, paymentType: 'nakit');
      }
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        SyncMetaCompanion(
          authToken: const Value('test-token'),
          routeCredits: const Value(34),
          userRole: Value(rol),
        ),
      );
      return db;
    }

    testWidgets('"Açık" sekmesinde düğme ETKİN — kilit gerekçesi yazmaz', (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(teslim: 1));

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);

      expect(find.text('Oto Sırala (rota) · 34 hak'), findsOneWidget);
      expect(find.textContaining('en az iki açık sipariş'), findsNothing);
      expect(find.textContaining('"Açık" sekmesine geçin'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('"Teslim" sekmesinde düğme PASİF ve nedeni AÇIK sekmesini gösterir',
        (tester) async {
      // SAHA HATASI: burada düğme etkin çiziliyordu; dokunan kullanıcı "sıralanacak sipariş yok"
      // duyuyor, oysa bir sekme ötede iki açık siparişi duruyordu. Sekme tanımı gereği KAPALI
      // sipariş listeler — bu sekmede rota kümesi hiçbir zaman dolmaz.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(teslim: 2));

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Teslim'));
      await akisiBekle(tester);
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);

      // Görünürlük ≠ kullanılabilirlik: düğme HEP çizilir, kontör yine yazar.
      expect(find.text('Oto Sırala (rota) · 34 hak'), findsOneWidget);
      expect(find.text('Rota yalnız açık siparişleri sıralar — "Açık" sekmesine geçin.'),
          findsOneWidget);

      // Pasif düğmeye dokunmak sheet'i KAPATMAZ (eylem hiç tetiklenmez).
      await tester.tap(find.text('Oto Sırala (rota) · 34 hak'));
      await akisiBekle(tester);
      expect(find.text('Sıralama'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('BOŞ sekmeye geçince önceki sekmenin kümesi taşınmaz', (tester) async {
      // Görünen küme yalnız DOLU listede tazeleniyordu; boş bir sekmede eski liste elde kalıyor
      // ve "Oto Sırala" kullanıcının BAKMADIĞI siparişleri sıralayabiliyordu (sessiz bozulma).
      // Hiç teslim sipariş yok → "Teslim" sekmesi tamamen boş.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur());

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Teslim'));
      await akisiBekle(tester);

      expect(find.text('Sipariş yok'), findsOneWidget, reason: 'sekme gerçekten boş');

      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);
      expect(find.text('Rota yalnız açık siparişleri sıralar — "Açık" sekmesine geçin.'),
          findsOneWidget,
          reason: 'boş sekmede küme BOŞTUR — "Açık" sekmesinin iki siparişi burada sayılmaz');

      await ekraniKapat(tester);
    });

    testWidgets('kurye süzgeci açıkken gerekçe SÜZGECİ söyler', (tester) async {
      // Ölçülen saha durumu: demo bayideki açık siparişlerin HİÇBİRİ atanmamış. Patron kuryeye
      // göre süzünce küme boşalıyor ve "sıralanacak sipariş yok" haksız bir cümle oluyor —
      // sipariş var, seçili kuryede yok. Gerekçe süzgeci ve çıkış yolunu söylemeli.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur());

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.bySemanticsLabel('Kuryeye göre süz'));
      await akisiBekle(tester);
      await tester.tap(find.text('Kurye Ali'));
      await akisiBekle(tester);

      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);
      expect(
        find.text('Kurye Ali için en az iki açık sipariş yok — süzgeci kaldırın.'),
        findsOneWidget,
      );

      await ekraniKapat(tester);
    });
  });
}
