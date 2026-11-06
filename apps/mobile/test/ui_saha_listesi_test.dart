// 2026-11-05 SAHA LİSTESİ — dokunuşla sınanan yüzeyler: kabuk (geri tuşu, + menüsü, Tanımlamalar),
// numara seçimi, sepet iskontosu, müşteriye özel fiyat.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/gider_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/screens/orders/musteri_eylemleri.dart';
import 'package:sipario/screens/orders/musteri_numara_secici.dart';
import 'package:sipario/screens/orders/order_form_screen.dart';
import 'package:sipario/sync/sync_service.dart';
import 'package:sipario/screens/isletme/ayarlar/isletme_ayarlari_ekrani.dart';
import 'package:sipario/theme/app_theme.dart';

import 'support/yetki_yardimcilari.dart';

/// Kabuğu gerçek veritabanıyla kurar ve sistem geri tuşunu yakalar.
class _KabukOrtami {
  _KabukOrtami(this.tester) : db = AppDatabase(NativeDatabase.memory());

  final WidgetTester tester;
  final AppDatabase db;
  int cikisSayisi = 0;

  Future<void> kur({String rol = 'patron'}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'SystemNavigator.pop') cikisSayisi++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.runAsync(() async {
      await db.syncState();
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        SyncMetaCompanion(userId: const Value('p'), userRole: Value(rol)),
      );
    });
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(db: db, session: Session(db), sync: SyncService(db), onLoggedOut: () {}),
    ));
    await bekle();
  }

  Future<void> bekle() async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> geriBas() async {
    await tester.binding.handlePopRoute();
    await bekle();
  }

  Future<void> kapat() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.close();
    });
  }
}

/// URI açıcıyı sahteler; denenen adresleri tutar.
class _SahteAcici {
  final denenen = <Uri>[];

  Future<bool> ac(Uri uri) async {
    denenen.add(uri);
    return true;
  }
}

Widget _sar(Widget icerik) => MaterialApp(theme: SipTheme.acik(), home: Scaffold(body: icerik));

void main() {
  group('Madde 9 — geri tuşu', () {
    testWidgets('ana sekmede geri, çıkış sorar; Vazgeç uygulamada kalır, Çık çıkar', (tester) async {
      final o = _KabukOrtami(tester);
      await o.kur();

      await o.geriBas();
      expect(find.text('Uygulamadan çıkılsın mı?'), findsOneWidget);
      expect(o.cikisSayisi, 0, reason: 'soru cevaplanmadan çıkılmaz');

      await tester.tap(find.text('Vazgeç'));
      await o.bekle();
      expect(find.text('Uygulamadan çıkılsın mı?'), findsNothing);
      expect(o.cikisSayisi, 0);

      await o.geriBas();
      await tester.tap(find.text('Çık'));
      await o.bekle();
      expect(o.cikisSayisi, 1);

      await o.kapat();
    });

    testWidgets('başka sekmede geri önce ana sekmeye döner, çekmece açıksa önce o kapanır',
        (tester) async {
      final o = _KabukOrtami(tester);
      await o.kur();

      await tester.tap(find.bySemanticsLabel('Müşteri'));
      await o.bekle();
      await o.geriBas();
      expect(find.text('Uygulamadan çıkılsın mı?'), findsNothing);
      expect(find.text('Ana'), findsOneWidget, reason: 'seçili sekme etiketini yazar');

      await tester.tap(find.bySemanticsLabel('Menü'));
      await o.bekle();
      expect(find.text('Tanımlamalar'), findsOneWidget);
      await o.geriBas();
      expect(find.text('Uygulamadan çıkılsın mı?'), findsNothing, reason: 'çekmece kapandı');

      await o.kapat();
    });
  });

  group('Madde 6 — + menüsü', () {
    testWidgets('Gider Ekle gider yazar', (tester) async {
      final o = _KabukOrtami(tester);
      await o.kur();

      await tester.tap(find.bySemanticsLabel('Yeni kayıt ekle'));
      await o.bekle();
      await tester.tap(find.text('Gider Ekle'));
      await o.bekle();

      await tester.enterText(find.byType(TextField).first, '150');
      await tester.pump();
      await tester.tap(find.text('Yakıt'));
      await tester.pump();
      await tester.tap(find.text('Gideri Kaydet'));
      await o.bekle();

      final giderler = await tester.runAsync(
          () => GiderRepository(o.db).gunGiderleri(DateTime.now()));
      expect(giderler!.single.kurus, 15000);
      expect(giderler.single.aciklama, 'Yakıt');

      await o.kapat();
    });

    testWidgets('gider yetkisi kapalı kuryede satır çizilmez', (tester) async {
      final o = _KabukOrtami(tester);
      await o.kur(rol: 'kurye');

      await tester.tap(find.bySemanticsLabel('Yeni kayıt ekle'));
      await o.bekle();
      expect(find.text('Gider Ekle'), findsNothing);

      await o.kapat();
    });
  });

  group('Yönetim — İşletme ve Mesajlar (2026-11-06)', () {
    testWidgets('patron menüden İşletme ve Mesajlar sayfalarını açar', (tester) async {
      final o = _KabukOrtami(tester);
      await o.kur();

      await tester.tap(find.bySemanticsLabel('Menü'));
      await o.bekle();
      await tester.tap(find.text('Mesajlar'));
      await o.bekle();
      expect(find.text('Yeni Mesaj Ekle'), findsOneWidget);
      await o.geriBas();
      await o.bekle();

      await tester.tap(find.bySemanticsLabel('Menü'));
      await o.bekle();
      await tester.tap(find.text('İşletme'));
      await o.bekle();
      expect(find.text('Tahsilat'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(IsletmeAyarlariEkrani), matching: find.text('Mesajlar')),
        findsNothing,
        reason: 'İşletme sayfasından çıktı',
      );

      await o.kapat();
    });

    testWidgets('operatör menüde ikisini de görmez', (tester) async {
      final o = _KabukOrtami(tester);
      await o.kur(rol: 'operator');

      await tester.tap(find.bySemanticsLabel('Menü'));
      await o.bekle();
      expect(find.text('Tanımlamalar'), findsOneWidget, reason: 'Yönetim bölümü durur');
      expect(find.text('İşletme'), findsNothing);
      expect(find.text('Mesajlar'), findsNothing);

      await o.kapat();
    });
  });

  group('Madde 7 — Tanımlamalar', () {
    testWidgets('kapalı başlar, dokununca dört satır açılır, tekrar dokununca kapanır',
        (tester) async {
      final o = _KabukOrtami(tester);
      await o.kur();
      await tester.tap(find.bySemanticsLabel('Menü'));
      await o.bekle();

      const satirlar = ['Ürünler', 'Kuryeler', 'Muaf Numaralar', 'Gider Kategorileri'];
      for (final s in satirlar) {
        expect(find.text(s), findsNothing, reason: '$s kapalıyken görünmemeli');
      }

      await tester.tap(find.text('Tanımlamalar'));
      await o.bekle();
      for (final s in satirlar) {
        expect(find.text(s), findsOneWidget, reason: '$s açıkken görünmeli');
      }

      await tester.tap(find.text('Tanımlamalar'));
      await o.bekle();
      expect(find.text('Ürünler'), findsNothing);

      await o.kapat();
    });

    testWidgets('Gider Kategorileri ekranından kategori eklenir', (tester) async {
      final o = _KabukOrtami(tester);
      await o.kur();
      await tester.tap(find.bySemanticsLabel('Menü'));
      await o.bekle();
      await tester.tap(find.text('Tanımlamalar'));
      await o.bekle();
      await tester.tap(find.text('Gider Kategorileri'));
      await o.bekle();

      await tester.tap(find.text('Kategori ekle'));
      await o.bekle();
      await tester.enterText(find.byType(TextField).last, 'Kömür');
      await tester.pump();
      await tester.tap(find.text('Kategoriyi Ekle'));
      await o.bekle();

      expect(find.text('Kömür'), findsOneWidget);

      await o.kapat();
    });
  });

  group('Madde 2 — hangi numara', () {
    late AppDatabase db;
    late _SahteAcici acici;
    late String musteriId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      acici = _SahteAcici();
      uriAcici = acici.ac;
      await db.syncState();
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(userId: Value('p'), userRole: Value('patron')));
      musteriId = await CustomerRepository(db).create(name: 'Ayşe', phones: [
        PhoneInput(phoneE164: '+905321112233', isPrimary: true),
        PhoneInput(phoneE164: '+905339998877'),
      ]);
    });
    tearDown(() async {
      uriAcici = (_) async => false;
      await db.close();
    });

    Future<void> dugmeKur(WidgetTester tester, MusteriNumaraSecici secici) async {
      await tester.pumpWidget(_sar(Builder(
        builder: (c) => TextButton(onPressed: () => secici.whatsapp(c), child: const Text('yaz')),
      )));
      await tester.tap(find.text('yaz'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('çağrıdan açıldıysa soru sormadan arayan numaraya gider', (tester) async {
      await dugmeKur(
        tester,
        MusteriNumaraSecici(db: db, customerId: musteriId, arayanNumara: '05339998877'),
      );
      expect(acici.denenen.first.toString(), contains('905339998877'));
    });

    testWidgets('çağrı bağlamı yoksa numara sorulur, seçilene gider', (tester) async {
      await dugmeKur(tester, MusteriNumaraSecici(db: db, customerId: musteriId));
      expect(acici.denenen, isEmpty, reason: 'seçim yapılmadan WhatsApp açılmaz');

      await tester.tap(find.text('0533 999 88 77'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(acici.denenen.first.toString(), contains('905339998877'));
    });

    testWidgets('çağrıdan açılan müşteri kartı başlıkta arayan numarayı yazar', (tester) async {
      Future<void> kartAc(String? arayan) async {
        await tester.pumpWidget(MaterialApp(
          theme: SipTheme.acik(),
          home: CustomerDetailScreen(
            db: db,
            customerId: musteriId,
            writable: true,
            yetki: tamYetki,
            arayanNumara: arayan,
          ),
        ));
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        await tester.pump();
      }

      await kartAc('+905339998877');
      expect(find.text('0533 999 88 77'), findsWidgets);
      expect(find.text('0532 111 22 33'), findsNothing);

      await kartAc(null);
      expect(find.text('0532 111 22 33'), findsWidgets, reason: 'çağrı yoksa birincil numara');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('tek numaralı müşteride soru sorulmaz', (tester) async {
      final tek = await tester.runAsync(() => CustomerRepository(db).create(
            name: 'Ali',
            phones: [PhoneInput(phoneE164: '+905321110000', isPrimary: true)],
          ));
      await dugmeKur(tester, MusteriNumaraSecici(db: db, customerId: tek!));
      expect(acici.denenen.first.toString(), contains('905321110000'));
    });
  });

  group('Madde 3-4 — sepet', () {
    late AppDatabase db;
    late String musteriId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.syncState();
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        const SyncMetaCompanion(userId: Value('p'), userRole: Value('patron')),
      );
      final urun = await ProductRepository(db).create(name: 'Damacana', unitPriceKurus: 10000);
      musteriId = await CustomerRepository(db).create(name: 'Ayşe');
      await CustomerRepository(db).musteriFiyatiKaydet(musteriId, urun, 8500);
      await CustomerRepository(db).favorileriKaydet(musteriId, [urun]);
    });
    tearDown(() => db.close());

    Future<void> bekle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('özel fiyat sepete düşer, iskonto toplamdan iner ve kaydedilir', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: SipTheme.acik(),
        home: OrderFormScreen(db: db, writable: true, initialCustomerId: musteriId),
      ));
      await bekle(tester);

      await tester.tap(find.text('Damacana'));
      await bekle(tester);
      expect(find.text('85,00 ₺'), findsWidgets, reason: 'katalog değil özel fiyat');

      await tester.tap(find.text('İskonto'));
      await bekle(tester);
      await tester.enterText(find.byType(TextField).last, '10,00');
      await tester.pump();
      expect(find.text('Yeni satır tutarı 75,00 ₺'), findsOneWidget);
      await tester.tap(find.text('İskontoyu Uygula'));
      await bekle(tester);

      await tester.tap(find.text('Devam'));
      await bekle(tester);
      await tester.tap(find.text('Siparişi Kaydet'));
      await bekle(tester);

      final satir = await tester.runAsync(() => db.select(db.orderLines).getSingle());
      expect(satir!.unitPriceKurus, 8500);
      expect(satir.discountKurus, 1000);
      expect(satir.lineTotalKurus, 7500);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('iskonto yetkisi olmayan kuryede dokunuş çizilmez', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(userRole: Value('kurye'))));

      await tester.pumpWidget(MaterialApp(
        theme: SipTheme.acik(),
        home: OrderFormScreen(db: db, writable: true, initialCustomerId: musteriId),
      ));
      await bekle(tester);
      await tester.tap(find.text('Damacana'));
      await bekle(tester);

      expect(find.text('İskonto'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
