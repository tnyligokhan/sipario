// İKİ SAHA İSTEĞİ, tek dosya — ikisi de "sipariş ekranında ne görünüyor, ne oluyor" sorusu.
//
//  A. YENİ SİPARİŞTE KURYE SEÇİMİ. Siparişi girerken kimin götüreceği çoğu zaman bellidir;
//     onu atamak için kaydedip listeye dönüp detayı açmak üç fazladan dokunuştu. Atama MEVCUT
//     yoldan (`assign` → `assigned` olayı → outbox) yazılır — formun kendine ait bir yazma yolu
//     YOKTUR.
//     ⚠️ SEÇİM 2026-08-13'TEN İTİBAREN ZORUNLU (kullanıcı kararı; önce opsiyoneldi). Zorunluluk
//     KOŞULSUZ DEĞİL: yalnız atama YAPILABİLDİĞİNDE geçer (`yetkiler().atama` =
//     `yönetici && aktif kurye var`). Tek kişilik bayide ve kurye rolünde kapı hiç kurulmaz —
//     kurulsaydı o iki kullanıcı hiç sipariş giremezdi. Üç test bu üç durumu birlikte kilitler.
//
//  B. ARAÇ ŞERİDİ (2026-08-01): harita ve kurye süzgeci başlıktaki çıplak ikon düğmelerinden
//     sekmelerin altındaki ETİKETLİ çiplere indi.
//
//  C. "OTO SIRALA" ARTIK HARİTADA. Düğme sıralama sheet'inin içindeydi; kullanıcı kontörlü bir
//     isteği sonucunu göremeyeceği bir yerden tetikliyordu. Kapılar (salt-okunur · hak yok ·
//     hak bilinmiyor · iki duraktan az) korundu, yeri değişti — ve gerekçe hâlâ DOKUNMADAN
//     ÖNCE, düğmenin hemen üstünde yazar.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/orders/order_form_parts.dart'
    show AltKuryeCipi, kuryeZorunluUyarisi;
import 'package:sipario/screens/orders/order_form_screen.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/siparis_yardimci.dart';

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // A. Yeni sipariş formunda KURYE SEÇİMİ
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('OrderFormScreen — kurye seçimi (ZORUNLU, atama yapılabildiğinde)', () {
    /// Katalogda tek ürün, tek müşteri, [kuryeVar] ise tek AKTİF kurye. [rol]
    /// `sync_meta.user_role`e yazılır: çipin görünürlüğü K2 matrisinden (`yetkiler().atama`
    /// = `yönetici && kuryeVar`) türer, ekranın kendi kararı değil.
    Future<AppDatabase> kur({required String rol, bool kuryeVar = true}) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ProductRepository(db)
          .create(name: 'Damacana 19 L', unitPriceKurus: 4500, unit: 'adet');
      await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      if (kuryeVar) {
        await db.into(db.users).insert(UsersCompanion.insert(
              id: 'k1',
              name: 'Kurye Ali',
              role: 'kurye',
              status: 'active',
            ));
      }
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

      // Çip BOŞ başlar ve doldurulması gerekir (bir sonraki test kapıyı kanıtlıyor).
      expect(find.text(AltKuryeCipi.bosEtiket), findsOneWidget);

      await tester.tap(find.text(AltKuryeCipi.bosEtiket));
      await akisiBekle(tester);
      await tester.tap(find.text('Kurye Ali'));
      await akisiBekle(tester);

      // Seçim çipe yansır — kullanıcı kaydetmeden önce kime gittiğini görür.
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

    testWidgets('kurye seçilmeden SİPARİŞ OLUŞMAZ — sebebi yazılır (kullanıcı kararı)',
        (tester) async {
      // KURAL 2026-08-13'te DEĞİŞTİ: seçim opsiyoneldi, artık zorunlu. Gerekçe kullanıcının:
      // atanmamış sipariş sahipsiz kalıyor. Engel SESSİZ OLAMAZ — dokunan kişi neden
      // kaydedilmediğini ekranda okumalı, yoksa "uygulama bozuk" der.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(rol: 'patron'));

      await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await ozeteKadar(tester);

      // Çipe HİÇ dokunulmadan kaydet.
      await tester.tap(find.text('Siparişi Kaydet'));
      await akisiBekle(tester, ms: 300);

      late List<Order> siparisler;
      await tester.runAsync(() async => siparisler = await db.select(db.orders).get());
      expect(siparisler, isEmpty, reason: 'atamasız sipariş YAZILMAZ');
      expect(find.text(kuryeZorunluUyarisi), findsOneWidget,
          reason: 'engel sebebini söylemeli');

      // Kurye seçilince aynı düğme çalışır — kapı kilit değil, eksik alan.
      await tester.tap(find.text(AltKuryeCipi.bosEtiket));
      await akisiBekle(tester);
      await tester.tap(find.text('Kurye Ali'));
      await akisiBekle(tester);
      await tester.tap(find.text('Siparişi Kaydet'));
      await akisiBekle(tester, ms: 300);

      late List<OrderEvent> olaylar;
      await tester.runAsync(() async {
        siparisler = await db.select(db.orders).get();
        olaylar = await db.select(db.orderEvents).get();
      });
      expect(siparisler, hasLength(1));
      expect(siparisler.single.assignedUserId, 'k1');
      expect(olaylar.where((e) => e.eventType == 'assigned'), hasLength(1));

      await ekraniKapat(tester);
    });

    testWidgets('TEK KİŞİLİK BAYİDE kural GEÇMEZ — aktif kurye yokken sipariş kaydedilir',
        (tester) async {
      // ZORUNLULUĞUN SINIRI. `yetkiler().atama` = `yönetici && kuryeVar`; kurye yoksa çip hiç
      // çizilmez. Zorunluluk koşulsuz olsaydı BRIEF'in "tek kişilik bayi çoktur" dediği
      // işletme HİÇ sipariş giremezdi — seçemeyeceği bir alan yüzünden kaydı kapanırdı.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(rol: 'patron', kuryeVar: false));

      await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await ozeteKadar(tester);

      expect(find.text(AltKuryeCipi.bosEtiket), findsNothing, reason: 'atanacak kimse yok');

      await tester.tap(find.text('Siparişi Kaydet'));
      await akisiBekle(tester, ms: 300);

      late List<Order> siparisler;
      late List<OrderEvent> olaylar;
      await tester.runAsync(() async {
        siparisler = await db.select(db.orders).get();
        olaylar = await db.select(db.orderEvents).get();
      });
      expect(siparisler, hasLength(1), reason: 'malı patron kendi götürür, sipariş yazılmalı');
      expect(siparisler.single.assignedUserId, isNull);
      expect(olaylar.where((e) => e.eventType == 'assigned'), isEmpty);
      expect(find.text(kuryeZorunluUyarisi), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('KURYE rolünde kurye çipi hiç çizilmez (K2: atama yöneticinin işi)',
        (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(rol: 'kurye'));

      await tester.pumpWidget(sipKabuk(OrderFormScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await ozeteKadar(tester);

      // Özet adımının kendisi çizildi (bölüm başlıkları yerinde) ve alt çubuk da çizildi
      // (kaydet düğmesi duruyor) — yalnız kurye çipi yok.
      expect(find.text('Sipariş Notu'), findsOneWidget);
      expect(find.text('Siparişi Kaydet'), findsOneWidget);
      expect(find.text(AltKuryeCipi.bosEtiket), findsNothing);

      // ZORUNLULUK KURYEYE İŞLEMEZ: kurye kendine iş atayamaz (K2), o yüzden kapı da açılmaz.
      // İşlemiş olsaydı kurye rolündeki kullanıcı hiç sipariş giremezdi.
      await tester.tap(find.text('Siparişi Kaydet'));
      await akisiBekle(tester, ms: 300);
      late List<Order> siparisler;
      await tester.runAsync(() async => siparisler = await db.select(db.orders).get());
      expect(siparisler, hasLength(1));
      expect(find.text(kuryeZorunluUyarisi), findsNothing);

      await ekraniKapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // B. ARAÇ ŞERİDİ — "Harita" ve kurye süzgeci çipleri (2026-08-01 yeniden yerleşimi)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('Sipariş listesi araç şeridi', () {
    /// [acik] adet açık sipariş + bir aktif kurye. [rol] süzgeç çipinin görünürlüğünü belirler.
    Future<AppDatabase> kur({int acik = 2, String rol = 'patron'}) async {
      final db = AppDatabase(NativeDatabase.memory());
      final musteri = CustomerRepository(db);
      final repo = OrderRepository(db);
      await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k1',
            name: 'Kurye Ali',
            role: 'kurye',
            status: 'active',
          ));
      for (var i = 0; i < acik; i++) {
        final m = await musteri.create(name: 'Açık Müşteri $i');
        await repo.create(customerId: m, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      }
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(SyncMetaCompanion(userRole: Value(rol)));
      return db;
    }

    testWidgets('patronda İKİ çip; süzgeç seçilince etiket kuryenin ADINI yazar',
        (tester) async {
      // Eski hâlde ikisi de başlıkta ÇIPLAK İKON düğmesiydi: ne yaptıklarını ancak dokunarak
      // öğrenebiliyordunuz ve süzgecin açık olduğunu yalnız düğmenin rengi söylüyordu.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur());

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('Harita'), findsOneWidget);
      expect(find.text('Kurye: Tümü'), findsOneWidget);
      // Başlıkta TEK eylem kaldı — eski ikon düğmeleri şeride indi.
      expect(find.bySemanticsLabel('Haritada göster'), findsNothing);
      expect(find.bySemanticsLabel('Kuryeye göre süz'), findsNothing);

      await tester.tap(find.text('Kurye: Tümü'));
      await akisiBekle(tester);
      await tester.tap(find.text('Kurye Ali'));
      await akisiBekle(tester);

      // Süzgecin DEĞERİ etiketin içinde yazar; renk tek başına "hangi kurye" demiyordu.
      expect(find.text('Kurye: Kurye Ali'), findsOneWidget);
      expect(find.text('Kurye: Tümü'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('KURYE rolünde süzgeç çipi çizilmez, "Harita" yine durur', (tester) async {
      // Süzgeç yalnız patrona çıkar (kurye zaten kendi işini görür); harita HERKESİN işi.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(rol: 'kurye'));

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.textContaining('Kurye:'), findsNothing);
      expect(find.text('Harita'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('elle sıralama kipinde şeridin TAMAMI gizlenir', (tester) async {
      // Sıra yazılırken listenin altından küme değişmemeli — süzgecin eski gizlenme kuralı
      // artık şeridin tamamına uygulanır.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur());

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);
      await tester.tap(find.text(siralamaEtiketi(OrderSort.elle)));
      await akisiBekle(tester);

      expect(find.text('Harita'), findsNothing);
      expect(find.text('Kurye: Tümü'), findsNothing);
      expect(find.text('Bitti'), findsOneWidget, reason: 'elle kipi gerçekten açık');

      await ekraniKapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // C. HARİTADAKİ "Oto Sırala" — kullanılamıyorsa PASİF ve gerekçe DOKUNMADAN ÖNCE yazar
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('Harita — Oto Sırala kapıları', () {
    setUp(haritaDikisleriniSahtele);

    /// [durak] adet KOORDİNATLI açık sipariş. [hak] null → kontör hiç yazılmaz; [oturum] false
    /// → token yok, yani kalan hak BİLİNEMEZ.
    Future<AppDatabase> kur({int durak = 2, int? hak = 34, bool oturum = true}) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = OrderRepository(db);
      for (var i = 0; i < durak; i++) {
        final cid = await CustomerRepository(db).create(
          name: 'Durak $i',
          addresses: [
            AddressInput(
              addressText: '$i. Sokak',
              lat: 36.88 + i * 0.01,
              lng: 30.70 + i * 0.01,
              isPrimary: true,
            ),
          ],
        );
        await repo.create(customerId: cid, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
      }
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        SyncMetaCompanion(
          authToken: Value(oturum ? 'test-token' : null),
          routeCredits: Value(hak ?? 0),
        ),
      );
      return db;
    }

    testWidgets('hak ve iki durak varken düğme ETKİN — gerekçe yazmaz', (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur());

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('Oto Sırala · 34 hak'), findsOneWidget);
      expect(find.textContaining('en az iki açık sipariş'), findsNothing);
      expect(find.textContaining('Salt-okunur'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('SALT-OKUNUR kipte pasif ve gerekçesi yazar', (tester) async {
      // Görünürlük ≠ kullanılabilirlik: düğme HEP çizilir, kontör yine yazar. Yeteneği gizlemek
      // kullanıcıya onun yokluğunu öğretirdi.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur());

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: false)));
      await akisiBekle(tester);

      expect(find.text('Oto Sırala · 34 hak'), findsOneWidget);
      expect(find.text('Salt-okunur kip: sıra kaydedilemez.'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('HAK BİTTİYSE pasif ve gerekçesi yazar', (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(hak: 0));

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('Oto Sırala · 0 hak'), findsOneWidget);
      expect(find.text('Oto sıralama hakkı kalmadı.'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('hak BİLİNMİYORKEN pasif ve etikette SAHTE KONTÖR yazmaz', (tester) async {
      // Kontör sunucu sahiplidir; token yokken kalan hak bilinemez. Uydurma bir sayı yazmak,
      // tıklayınca 409 yiyen bir düğme demekti.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(oturum: false));

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      // TAM eşleşme: etikette " · N hak" eki YOK.
      expect(find.text('Oto Sırala'), findsOneWidget);
      expect(find.text('Hak bilgisi bekleniyor — ilk senkrondan sonra kullanılabilir.'),
          findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('TEK durak varken pasif — rota iki noktadan başlar', (tester) async {
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(durak: 1));

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('Rota için en az iki açık sipariş gerekir.'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('kontör ekran AÇILDIKTAN SONRA senkronla gelince düğme güncellenir',
        (tester) async {
      // CİHAZDA YAKALANAN GERİLEME (liste ekranında): kalan hak `initState`te TEK ATIŞ
      // okunuyordu. Kontör giriş yanıtında GELMEZ, ilk senkron yazar — ekran girişten hemen
      // sonra 0 görüp sonsuza dek "0 hak" gösteriyordu. Düğme haritaya taşındı, kural taşındı.
      genisYuzey(tester);
      late AppDatabase db;
      await tester.runAsync(() async => db = await kur(hak: 0));

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      expect(find.text('Oto Sırala · 0 hak'), findsOneWidget);

      await tester.runAsync(() async {
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
            .write(const SyncMetaCompanion(routeCredits: Value(34)));
      });
      await akisiBekle(tester);

      expect(find.text('Oto Sırala · 34 hak'), findsOneWidget,
          reason: 'kontör senkronla gelince düğme tazelenmeli — "0 hak"ta donmamalı');
      expect(find.text('Oto sıralama hakkı kalmadı.'), findsNothing);

      await ekraniKapat(tester);
    });
  });
}
