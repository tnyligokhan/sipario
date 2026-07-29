// ROTA KONUMU + SİPARİŞ HARİTASI (kullanıcı isteği 2026-07-29).
//
// İki iş, tek dert: "Oto Sırala" nereden başlıyor ve o sıra yeryüzünde neye benziyor?
//
//  A. Oto sıralama kuryenin BULUNDUĞU noktadan başlar (`start`). Konum alınamazsa istek yine
//     gider ama kullanıcıya HANGİ KİPTE sıralandığı söylenir — sessiz bozulma yasak.
//  B. Harita ekranı açık siparişleri rota sırasında numaralı pinlerle çizer.
//
// Bu dosyadaki widget testleri AĞA ve PLATFORM KANALINA hiç uzanmaz: `cihazKonumuOku`,
// `rotaApiUret` ve `haritaKaroSaglayici` dikişleri sahtelenir. Sızan bir sahte bir sonraki testte
// sessizce yanlış sonuç üretir — üçü de tearDown'da geri alınır.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/order_queries.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/sync/route_api.dart';

import 'support/siparis_yardimci.dart';

/// Testte kullanılan karo sağlayıcı: her karo için TEK saydam görsel döner, hiçbir istek atmaz.
/// `flutter_map` bu baytları kendi "yüklenemedi" yolu için de kullanıyor — geçerli bir PNG'dir.
class SahteKaroSaglayici extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // A1. RouteApi — `start` gövdeye ne zaman girer?
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('RouteApi.autoRoute başlangıç noktası', () {
    /// İstek gövdesini yakalayan sahte sunucu; her zaman geçerli bir sıra döner.
    (RouteApi, List<Map<String, dynamic>>) apiKur() {
      final govdeler = <Map<String, dynamic>>[];
      final api = RouteApi(
        baseUrl: 'https://ornek.test/api/v1',
        token: 'tk',
        client: MockClient((istek) async {
          govdeler.add(jsonDecode(istek.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'order': ['o1', 'o2'],
              'without_location': 0,
              'route_credits': 33,
              // Sunucu motorunu bildirebilir; istemci OKUMAZ — sözleşmeye girmez.
              'engine': 'osrm',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      return (api, govdeler);
    }

    test('başlangıç verilirse gövdede start durur', () async {
      final (api, govdeler) = apiKur();

      final sonuc = await api.autoRoute(
        ['o1', 'o2'],
        baslangic: (lat: 36.8841, lng: 30.7056),
      );

      expect(govdeler.single['order_ids'], ['o1', 'o2']);
      expect(govdeler.single['start'], {'lat': 36.8841, 'lng': 30.7056});
      expect(sonuc.sira, ['o1', 'o2']);
      expect(sonuc.kalanHak, 33);
    });

    test('başlangıç verilmezse gövdede start HİÇ yoktur', () async {
      // Boş/sıfır bir `start` göndermek sunucuya Gine Körfezi'ni başlangıç noktası olarak
      // bildirmek olurdu; alan ya doğrudur ya da hiç yoktur.
      final (api, govdeler) = apiKur();

      await api.autoRoute(['o1', 'o2']);

      expect(govdeler.single.containsKey('start'), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // A2. "Oto Sırala" ekran akışı — konum dikişi ile istek gövdesi arasındaki halka
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('Oto sıralama cihaz konumundan başlar', () {
    /// İki açık sipariş + oturum + kontör. Sunucunun tanıyacağı kimlikler dönebilsin diye
    /// sipariş id'leri de döner.
    Future<(AppDatabase, List<String>)> kur() async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = OrderRepository(db);
      final m1 = await CustomerRepository(db).create(name: 'Ayşe Yılmaz');
      final m2 = await CustomerRepository(db).create(name: 'Mehmet Kaya');
      final o1 = await repo.create(customerId: m1, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      final o2 = await repo.create(customerId: m2, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 2),
      ]);
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
        const SyncMetaCompanion(
          authToken: Value('test-token'),
          routeCredits: Value(34),
          routeCreditsMonthly: Value(50),
        ),
      );
      return (db, [o1, o2]);
    }

    /// Rota istemcisini sahte sunucuya bağlar ve giden gövdeleri toplar.
    List<Map<String, dynamic>> rotayiSahtele(List<String> siparisIdleri) {
      final govdeler = <Map<String, dynamic>>[];
      final eski = rotaApiUret;
      rotaApiUret = (baseUrl, token) => RouteApi(
            baseUrl: baseUrl,
            token: token,
            client: MockClient((istek) async {
              govdeler.add(jsonDecode(istek.body) as Map<String, dynamic>);
              return http.Response(
                jsonEncode({
                  'order': siparisIdleri,
                  'without_location': 0,
                  'route_credits': 33,
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          );
      addTearDown(() => rotaApiUret = eski);
      return govdeler;
    }

    void konumSahtele(Future<CihazKonumu> Function() oku) {
      final eski = cihazKonumuOku;
      cihazKonumuOku = oku;
      addTearDown(() => cihazKonumuOku = eski);
    }

    /// Sıralama sheet'ini açıp "Oto Sırala" düğmesine basar.
    Future<void> otoSirala(WidgetTester tester) async {
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);
      await tester.tap(find.text('Oto Sırala (rota) · 34 hak'));
      await akisiBekle(tester, ms: 400);
    }

    testWidgets('GÜVENİLİR konum alınırsa istek start ile gider', (tester) async {
      konumSahtele(
          () async => const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12));
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async => (db, idler) = await kur());
      final govdeler = rotayiSahtele(idler);

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await otoSirala(tester);

      expect(govdeler, hasLength(1));
      expect(govdeler.single['start'], {'lat': 36.8841, 'lng': 30.7056});
      // Konum gitti → toast'ta kip eki YOK (tam eşleşme: ek olsaydı bu bulunamazdı).
      expect(find.text('Rota otomatik sıralandı · 33 hak kaldı'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('konum OKUNAMAZSA istek startsız gider ve toast bunu söyler', (tester) async {
      konumSahtele(() async => throw const KonumHatasi('Konum izni verilmedi'));
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async => (db, idler) = await kur());
      final govdeler = rotayiSahtele(idler);

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await otoSirala(tester);

      // Sıralama YAPILIR — konum bir ön koşul değil, bir kolaylıktır.
      expect(govdeler, hasLength(1));
      expect(govdeler.single.containsKey('start'), isFalse);
      expect(
        find.text('Rota otomatik sıralandı · 33 hak kaldı · konum alınamadı, ilk duraktan'),
        findsOneWidget,
      );

      await ekraniKapat(tester);
    });

    testWidgets('"Tümü" sekmesinde KAPALI sipariş rotaya girmez ve bu SÖYLENİR', (tester) async {
      // İnceleme bulgusu (2026-07-29): görünen kümenin tamamı gönderiliyordu; sunucu kapalıları
      // cevaptan düşürüyor ve onlar SESSİZCE listenin sonuna iniyordu. Artık kapalılar hiç
      // gönderilmez ve toast sayısını söyler — "sıraladım" derken kümenin bir kısmının yeniden
      // konumlandığı kullanıcıdan gizlenmez.
      konumSahtele(
          () async => const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12));
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async {
        (db, idler) = await kur();
        // Üçüncü sipariş: oluştur ve TESLİM ET — "Tümü" sekmesinde görünür ama rotaya girmemeli.
        final repo = OrderRepository(db);
        final m3 = await CustomerRepository(db).create(name: 'Fatma Demir');
        final kapaliId = await repo.create(customerId: m3, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
        await repo.deliver(kapaliId, paymentType: 'nakit');
      });
      final govdeler = rotayiSahtele(idler);

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Tümü'));
      await akisiBekle(tester);
      await otoSirala(tester);

      // Gövdeye yalnız İKİ AÇIK sipariş girdi; kapalı olan hiç gönderilmedi.
      expect(govdeler, hasLength(1));
      expect(govdeler.single['order_ids'], unorderedEquals(idler));
      expect(
        find.text(
            'Rota otomatik sıralandı · 33 hak kaldı · 1 kapalı sipariş rotaya girmedi'),
        findsOneWidget,
      );

      await ekraniKapat(tester);
    });

    testWidgets('GÜVENİLMEZ ölçüm başlangıç sayılmaz (±100 m üstü)', (tester) async {
      // ±800 m'lik bir "başlangıç", rotayı kuryenin bulunmadığı bir mahalleden kurabilir.
      // Kötü bir başlangıç, başlangıçsızdan daha zararlıdır — çünkü kimse şüphelenmez.
      konumSahtele(
          () async => const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 800));
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async => (db, idler) = await kur());
      final govdeler = rotayiSahtele(idler);

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await otoSirala(tester);

      expect(govdeler.single.containsKey('start'), isFalse);
      expect(
        find.text('Rota otomatik sıralandı · 33 hak kaldı · konum alınamadı, ilk duraktan'),
        findsOneWidget,
      );

      await ekraniKapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // B. Harita ekranı
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('Sipariş haritası', () {
    setUp(() {
      final eskiKaro = haritaKaroSaglayici;
      haritaKaroSaglayici = SahteKaroSaglayici.new;
      addTearDown(() => haritaKaroSaglayici = eskiKaro);

      // Cihaz konumu VARSAYILAN OLARAK alınamaz: eklentisiz ortamın gerçeği bu ve haritanın
      // onsuz da çalıştığı her testte kanıtlanmış olur.
      final eskiKonum = cihazKonumuOku;
      cihazKonumuOku = () async => throw const KonumHatasi('Konum alınamadı');
      addTearDown(() => cihazKonumuOku = eskiKonum);
    });

    /// Bir müşteri + siparişi. [lat]/[lng] null ise adres konumsuzdur.
    Future<String> siparisEkle(
      AppDatabase db, {
      required String ad,
      double? lat,
      double? lng,
      bool teslim = false,
      int? sira,
    }) async {
      final cid = await CustomerRepository(db).create(
        name: ad,
        addresses: [
          AddressInput(
            addressText: '$ad sokağı No: 1',
            lat: lat,
            lng: lng,
            isPrimary: true,
          ),
        ],
      );
      final repo = OrderRepository(db);
      final oid = await repo.create(customerId: cid, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      // Pin numaraları `sort_index`ten gelir — testin beklediği sıra açıkça yazılır, aksi hâlde
      // aynı milisaniyede üretilen kimliklerin sırası yazı-tura olurdu.
      if (sira != null) await repo.setSortIndex(oid, sira);
      if (teslim) await repo.deliver(oid, paymentType: 'nakit');
      return oid;
    }

    testWidgets('koordinatlı AÇIK siparişler numaralı pin olur; teslim edilen olmaz',
        (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 10);
        await siparisEkle(db,
            ad: 'Teslim Edilmiş', lat: 36.8700, lng: 30.7200, sira: 20, teslim: true);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.byType(DurakPini), findsNWidgets(2));
      expect(find.widgetWithText(DurakPini, '1'), findsOneWidget);
      expect(find.widgetWithText(DurakPini, '2'), findsOneWidget);
      expect(find.widgetWithText(DurakPini, '3'), findsNothing,
          reason: 'teslim edilmiş sipariş rotada bir durak değildir');
      // Üst başlıkta durak sayısı — kullanıcı haritayı saymak zorunda kalmasın.
      expect(find.text('2 durak · rota sırası'), findsOneWidget);
      // Konumsuz sipariş yok → bant hiç çizilmez.
      expect(find.byType(KonumsuzBant), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('konumsuz açık siparişin SAYISI bantta yazar', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db, ad: 'Konumsuz Müşteri', sira: 10);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.byType(DurakPini), findsOneWidget);
      // Metin SÖZLEŞMEDİR: sessizce yutulan sipariş, eksik koşulan rota demektir.
      expect(find.text('1 sipariş konumsuz — haritada yok'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('pine dokununca o siparişin detayı açılır', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 10);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      // Harita müşteri ADI yazmaz — bu metnin ekranda belirmesi sheet'in açıldığının kanıtıdır.
      expect(find.text('Mehmet Kaya'), findsNothing);
      await tester.tap(find.widgetWithText(DurakPini, '2'));
      await akisiBekle(tester, ms: 400);

      expect(find.text('Mehmet Kaya'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('hiç durak yoksa boş durum çizilir, harita kurulmaz', (tester) async {
      // Veri yokken haritayı bir şehre sabitlemek kullanıcıya "pinlerim nerede" dedirtir.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Konumsuz Müşteri');
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Haritada gösterilecek sipariş yok'), findsOneWidget);
      expect(find.text('1 sipariş konumsuz — haritada yok'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('cihaz konumu alınabiliyorsa AYRI bir işaret çizilir', (tester) async {
      cihazKonumuOku =
          () async => const CihazKonumu(lat: 36.8850, lng: 30.7060, dogrulukM: 15);

      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(find.byType(CihazPini), findsOneWidget);
      // Cihaz bir DURAK değildir: numara almaz, durak sayısını da değiştirmez.
      expect(find.text('1 durak · rota sırası'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('sipariş listesinden harita düğmesiyle açılır', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.bySemanticsLabel('Haritada göster'));
      await akisiBekle(tester, ms: 400);

      expect(find.byType(SiparisHaritaEkrani), findsOneWidget);
      // İKİNCİ TUR ŞART: sayfa geçişi biterken harita henüz ölçüsünü almamış oluyor, kamera
      // (`initialCameraFit`) bir kare sonra oturuyor ve işaretçiler ancak o zaman çiziliyor.
      await akisiBekle(tester, ms: 400);
      expect(find.byType(DurakPini), findsOneWidget);

      await ekraniKapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // B2. Harita sorgusu — ekran kurmadan (saf async, drift gerçek zamanında)
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('watchHaritaDuraklari', () {
    test('birincil adres koordinatsızsa sipariş KONUMSUZ sayılır', () async {
      // İkincil adrese düşmek, kullanıcının listede gördüğü adresin dışında bir kapıya pin
      // koymak olurdu — harita ile liste ayrışır.
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        addresses: [
          AddressInput(addressText: 'Birincil — konumsuz', isPrimary: true),
          AddressInput(addressText: 'İkincil — konumlu', lat: 36.9, lng: 30.7),
        ],
      );
      await OrderRepository(db).create(customerId: cid, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);

      final veri = await watchHaritaDuraklari(db).first;

      expect(veri.duraklar, isEmpty);
      expect(veri.konumsuz, 1);
      await db.close();
    });

    test('duraklar sort_index sırasında döner (oto sıralamanın rota sırası)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = OrderRepository(db);
      final idler = <String>[];
      for (final ad in ['Bir', 'İki', 'Üç']) {
        final cid = await CustomerRepository(db).create(
          name: ad,
          addresses: [
            AddressInput(addressText: '$ad sokağı', lat: 36.9, lng: 30.7, isPrimary: true),
          ],
        );
        idler.add(await repo.create(customerId: cid, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]));
      }
      // Rota sırası listenin yazılma sırasının TERSİ olsun ki sıra gerçekten okunuyor mu görelim.
      await repo.setSortIndex(idler[0], 20);
      await repo.setSortIndex(idler[1], 10);
      await repo.setSortIndex(idler[2], 0);

      final veri = await watchHaritaDuraklari(db).first;

      expect([for (final d in veri.duraklar) d.baslik], ['Üç', 'İki', 'Bir']);
      expect(veri.konumsuz, 0);
      await db.close();
    });
  });
}
