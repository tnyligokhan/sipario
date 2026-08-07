// ÇAĞRI KARTI EYLEMLERİ — kartın düğmeleri gerçekten bir yere gidiyor mu.
//
// NEDEN AYRI DOSYA: `ui_cagri_test.dart` kartın ÇİZİMİNİ doğrular (hangi varyantta hangi
// satır, hangi rozet) ve 500 satır sınırına dayandı. Burası kartın ÇIKTISINI doğrular:
// dönen eylem kabukta ne yapıyor.
//
// CİHAZDA YAKALANAN GERİLEME (2026-07-26): kabuk kartı `await cagriKartiGoster(...)` ile
// açıp DÖNEN EYLEMİ ATIYORDU. Üç düğme de (Sipariş Oluştur · Defteri Aç · Müşteri Olarak
// Kaydet) yalnız kartı kapatıyor, hiçbiri bir ekran açmıyordu. Kartın kendi sözleşmesi
// (düğme → doğru enum ile pop) `ui_cagri_test.dart`ta zaten kilitliydi ve YEŞİLDİ —
// kırık olan çağıran taraftı. Bu dosya o boşluğu kapatır.
//
// Native kart (telefon çalarken çizilen Kotlin kartı) uygulamayı ekstralarla açar; ekstralar
// `sipario/cagri` kanalında BEKLETİLİR. Kanal burada sahtelenir — testler platformsuz koşar
// ama köprünün Dart ucu (çözme, tüketme, gezinme) gerçek koddur.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/auth/session.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/cagri/cagri_eylem_kanali.dart';
import 'package:sipario/screens/cagri/cagri_karti.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/home_shell.dart';
import 'package:sipario/screens/orders/order_form_screen.dart';
import 'package:sipario/sync/sync_service.dart';

void main() {
  group('cagriEylemiCoz — native adı enum\'a çevirir', () {
    test('üç eylem adı tanınır', () {
      expect(cagriEylemiCoz('siparis'), CagriEylemi.siparis);
      expect(cagriEylemiCoz('defter'), CagriEylemi.defter);
      expect(cagriEylemiCoz('kaydet'), CagriEylemi.kaydet);
    });

    // Köprünün iki ucu ayrışırsa (native yeni bir eylem gönderirse) YANLIŞ ekrana gitmek
    // sessizce durmaktan kötüdür — bilinmeyen ad null döner ve istek düşer.
    test('bilinmeyen ad ve null düşer', () {
      expect(cagriEylemiCoz('kapat'), isNull);
      expect(cagriEylemiCoz(''), isNull);
      expect(cagriEylemiCoz(null), isNull);
    });
  });

  group('bekleyenCagriEylemi — native köprüsünün Dart ucu', () {
    /// Kanalı sahteler; [cevap] `bekleyen` çağrısına dönecek harita (null = bekleyen yok).
    /// Köprü de açılır: masaüstü koşumunda varsayılan KAPALI'dır.
    void kanaliKur(WidgetTester tester, Object? cevap) {
      cagriKopruAcik = true;
      addTearDown(() => cagriKopruAcik = false);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        kCagriEylemKanali,
        (call) async => call.method == 'bekleyen' ? cevap : null,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(kCagriEylemKanali, null));
    }

    testWidgets('bekleyen eylem çözülür', (tester) async {
      kanaliKur(tester, {'eylem': 'defter', 'numara': '+905321112233'});

      final istek = await bekleyenCagriEylemi();

      expect(istek, isNotNull);
      expect(istek!.eylem, CagriEylemi.defter);
      expect(istek.numara, '+905321112233');
    });

    testWidgets('bekleyen yoksa null', (tester) async {
      kanaliKur(tester, null);
      expect(await bekleyenCagriEylemi(), isNull);
    });

    testWidgets('numarasız ya da tanınmayan eylem düşer', (tester) async {
      kanaliKur(tester, {'eylem': 'defter', 'numara': ''});
      expect(await bekleyenCagriEylemi(), isNull, reason: 'numarasız istek işe yaramaz');

      kanaliKur(tester, {'eylem': 'ucus', 'numara': '+905321112233'});
      expect(await bekleyenCagriEylemi(), isNull);
    });

    // Köprü Android dışında KAPALI ve kanala hiç dokunulmamalı. Sahtelenmemiş bir kanala
    // yapılan çağrı `flutter_test`te ne yanıt ne hata döndürür — gelecek askıda kalır ve
    // kabuğu kuran HER widget testi arkasında ölü bir bekleyiş bırakırdı (ölçüldü: bu test
    // 10 dk zaman aşımına düştü). Kapı bu yüzden var; kalkarsa süite geri sızar.
    testWidgets('köprü kapalıyken kanala hiç dokunulmaz', (tester) async {
      var dokunuldu = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        kCagriEylemKanali,
        (call) async {
          dokunuldu = true;
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(kCagriEylemKanali, null));

      cagriKopruAcik = false;
      expect(await bekleyenCagriEylemi(), isNull);
      expect(dokunuldu, isFalse, reason: 'kapalı köprü kanalı hiç çağırmamalı');
    });
  });

  group('Kabuk — kart eylemi hedef ekrana gider', () {
    /// Native'in bekleteceği eylemi sahteler ve kabuğu kurar. Kabuk açılışta köprüyü
    /// yokladığı için eylem KENDİLİĞİNDEN uygulanır — native karttan dokunmuş gibi.
    Future<AppDatabase> kabugaKoy(
      WidgetTester tester, {
      required Map<String, String>? eylem,
      required Future<void> Function(AppDatabase db) hazirla,
    }) async {
      // Kabuk uzun: hap navigasyon + hero blokları dar viewport'ta taşar ve `SipGovde`
      // bir ListView olduğu için katlamanın altındaki içerik hiç build edilmez.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      cagriKopruAcik = true; // masaüstü koşumunda köprü varsayılan KAPALI
      addTearDown(() => cagriKopruAcik = false);

      var verildi = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        kCagriEylemKanali,
        (call) async {
          if (call.method != 'bekleyen' || verildi) return null;
          verildi = true; // native de tüketilen eylemi siler: iki kez uygulanamaz
          return eylem;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(kCagriEylemKanali, null));

      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await db.syncState();
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
          const SyncMetaCompanion(
            userId: Value('p'),
            userRole: Value('patron'),
          ),
        );
        await hazirla(db);
      });

      await tester.pumpWidget(MaterialApp(
        home: HomeShell(
          db: db,
          session: Session(db),
          sync: SyncService(db), // start() çağrılmaz: ağ/timer yok
          onLoggedOut: () {},
        ),
      ));
      // Gerçek drift çağrıları sahte zamanda asılır; köprü + çözücü burada ilerler.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // rota geçişi
      return db;
    }

    Future<void> kapat(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }

    Future<String> musteriKur(AppDatabase db, String ad, String telefon) =>
        CustomerRepository(db).create(
          name: ad,
          phones: [PhoneInput(phoneE164: telefon, isPrimary: true)],
        );

    testWidgets('"Defteri Aç" müşteri defterini açar', (tester) async {
      await kabugaKoy(
        tester,
        eylem: {'eylem': 'defter', 'numara': '+905321112233'},
        hazirla: (db) => musteriKur(db, 'Ayşe Yılmaz', '+905321112233'),
      );

      expect(find.byType(CustomerDetailScreen), findsOneWidget,
          reason: 'defter eylemi müşteri detayına gitmeli');

      await kapat(tester);
    });

    testWidgets('"Sipariş Oluştur" formu müşteri KİLİTLİ açar', (tester) async {
      await kabugaKoy(
        tester,
        eylem: {'eylem': 'siparis', 'numara': '05321112233'},
        hazirla: (db) => musteriKur(db, 'Ayşe Yılmaz', '+905321112233'),
      );

      final form = find.byType(OrderFormScreen);
      expect(form, findsOneWidget, reason: 'sipariş eylemi formu açmalı');
      // Müşteri karttan geliyor: form müşteri SEÇİMİ adımını hiç göstermemeli.
      expect(tester.widget<OrderFormScreen>(form).initialCustomerId, isNotNull,
          reason: 'arayan müşteri forma önceden geçmeli — seçim adımı tekrar sorulmaz');

      await kapat(tester);
    });

    testWidgets('"Müşteri Olarak Kaydet" formu numara DOLU açar', (tester) async {
      await kabugaKoy(
        tester,
        eylem: {'eylem': 'kaydet', 'numara': '+905329998877'},
        hazirla: (db) async {}, // numara defterde YOK
      );

      expect(find.text('Yeni Müşteri'), findsOneWidget,
          reason: 'kaydet eylemi yeni müşteri sheet\'ini açmalı');
      expect(find.text('0532 999 88 77'), findsOneWidget,
          reason: 'arayan numara forma önceden yazılmalı');

      await kapat(tester);
    });

    // Kart çizildikten sonra müşteri silinmiş olabilir. Sessizce hiçbir şey yapmak, bayinin
    // dokunuşunu yutmak demektir — kartı gösterip "Müşteri Olarak Kaydet" yolunu açıyoruz.
    testWidgets('defter isteği kayıtsız numaraya düşerse kart gösterilir', (tester) async {
      await kabugaKoy(
        tester,
        eylem: {'eylem': 'defter', 'numara': '+905550001122'},
        hazirla: (db) async {},
      );

      expect(find.byType(CustomerDetailScreen), findsNothing);
      expect(find.byType(CagriKarti), findsOneWidget,
          reason: 'ölü uç yerine kart: bayi oradan kaydetmeye geçebilir');
      expect(find.text('Müşteri Olarak Kaydet'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('bekleyen eylem yoksa kabuk normal açılır', (tester) async {
      await kabugaKoy(tester, eylem: null, hazirla: (db) async {});

      expect(find.byType(CagriKarti), findsNothing);
      expect(find.byType(CustomerDetailScreen), findsNothing);
      expect(find.byType(OrderFormScreen), findsNothing);

      await kapat(tester);
    });
  });
}
