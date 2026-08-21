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
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/order_sheets.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/sync/route_api.dart';

import 'support/siparis_yardimci.dart';


/// HARİTA — OTO SIRALAMA (RouteApi `start` sözleşmesi + cihaz konumundan başlama).
///
/// DOSYA ÜÇE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 925 satırdı): harita EKRANI
/// `ui_siparis_harita_ekran_test.dart`ta, veri sorguları `ui_siparis_harita_veri_test.dart`ta.
void main() {
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
  //
  // Düğme 2026-08-01'de sıralama sheet'inden HARİTAYA taşındı: eylem bir ROTA üretir ve
  // rotanın saçma olup olmadığı ancak yeryüzünde anlaşılır. Akış aynı, tetiklendiği ekran
  // farklı — testler de artık haritadan basıyor.
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('Oto sıralama cihaz konumundan başlar', () {
    /// İki KOORDİNATLI açık sipariş + oturum + kontör. Sunucunun tanıyacağı kimlikler
    /// dönebilsin diye sipariş id'leri de döner.
    Future<(AppDatabase, List<String>)> kur() async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = OrderRepository(db);
      final m1 = await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        addresses: [
          AddressInput(
              addressText: 'Bahçe Sk.', lat: 36.8841, lng: 30.7056, isPrimary: true),
        ],
      );
      final m2 = await CustomerRepository(db).create(
        name: 'Mehmet Kaya',
        addresses: [
          AddressInput(
              addressText: 'Deniz Sk.', lat: 36.8900, lng: 30.7100, isPrimary: true),
        ],
      );
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

    /// Karo dikişi + istenen konum. Konum verilmezse ALINAMAZ sayılır.
    void haritayiKur({CihazKonumu? konum}) => haritaDikisleriniSahtele(konum: konum);

    /// Haritadaki birincil eyleme basar.
    Future<void> otoSirala(WidgetTester tester) async {
      await tester.tap(find.text('Oto Sırala (34 hak)'));
      await akisiBekle(tester, ms: 400);
    }

    testWidgets('GÜVENİLİR konum alınırsa istek start ile gider', (tester) async {
      haritayiKur(konum: const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12));
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async => (db, idler) = await kur());
      final govdeler = rotayiSahtele(idler);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await otoSirala(tester);

      expect(govdeler, hasLength(1));
      expect(govdeler.single['start'], {'lat': 36.8841, 'lng': 30.7056});
      // Konum gitti → toast'ta kip eki YOK (tam eşleşme: ek olsaydı bu bulunamazdı).
      expect(find.text('Rota sıralandı, 33 hakkınız kaldı.'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('konum OKUNAMAZSA istek startsız gider ve toast bunu söyler', (tester) async {
      haritayiKur();
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async => (db, idler) = await kur());
      final govdeler = rotayiSahtele(idler);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await otoSirala(tester);

      // Sıralama YAPILIR — konum bir ön koşul değil, bir kolaylıktır.
      expect(govdeler, hasLength(1));
      expect(govdeler.single.containsKey('start'), isFalse);
      expect(
        find.text('Rota sıralandı, 33 hakkınız kaldı. Konumunuz alınamadığı için ilk duraktan başlandı.'),
        findsOneWidget,
      );

      await ekraniKapat(tester);
    });

    testWidgets('KAPALI sipariş rotaya HİÇ girmez — küme açık siparişlerin tamamıdır',
        (tester) async {
      // İnceleme bulgusu (2026-07-29): görünen kümenin tamamı gönderiliyordu; sunucu kapalıları
      // cevaptan düşürüyor ve onlar SESSİZCE listenin sonuna iniyordu. Küme artık EKRANIN
      // gördüğü liste değil, doğrudan açık siparişlerdir (`otoSiralaKos` kendisi okur) —
      // dolayısıyla ne sekme seçimi ne kurye süzgeci rotayı daraltabilir ve "N kapalı sipariş
      // rotaya girmedi" cümlesine gerek kalmaz: kapalı sipariş kümeye zaten hiç girmez.
      haritayiKur(konum: const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12));
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async {
        (db, idler) = await kur();
        final repo = OrderRepository(db);
        final m3 = await CustomerRepository(db).create(
          name: 'Fatma Demir',
          addresses: [
            AddressInput(
                addressText: 'Çınar Sk.', lat: 36.8700, lng: 30.7200, isPrimary: true),
          ],
        );
        final kapaliId = await repo.create(customerId: m3, lines: [
          LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
        ]);
        await repo.deliver(kapaliId, paymentType: 'nakit');
      });
      final govdeler = rotayiSahtele(idler);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await otoSirala(tester);

      expect(govdeler, hasLength(1));
      expect(govdeler.single['order_ids'], unorderedEquals(idler));
      // Toast'ta kapalı eki YOK (tam eşleşme).
      expect(find.text('Rota sıralandı, 33 hakkınız kaldı.'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('GÜVENİLMEZ ölçüm başlangıç sayılmaz (±100 m üstü)', (tester) async {
      // ±800 m'lik bir "başlangıç", rotayı kuryenin bulunmadığı bir mahalleden kurabilir.
      // Kötü bir başlangıç, başlangıçsızdan daha zararlıdır — çünkü kimse şüphelenmez.
      haritayiKur(konum: const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 800));
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async => (db, idler) = await kur());
      final govdeler = rotayiSahtele(idler);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await otoSirala(tester);

      expect(govdeler.single.containsKey('start'), isFalse);
      expect(
        find.text('Rota sıralandı, 33 hakkınız kaldı. Konumunuz alınamadığı için ilk duraktan başlandı.'),
        findsOneWidget,
      );

      await ekraniKapat(tester);
    });

    testWidgets('oto sıralamadan sonra LİSTE rota görünümüne geçer, elle kipi AÇILMAZ',
        (tester) async {
      // KULLANICI ŞİKÂYETİ (2026-08-01): "oto sıralamadan sonra tekrar elle sıralama alanı
      // geliyor, mantıksız". Sonucu görmek isteyen kullanıcı kendini tutamaçlı bir düzenleme
      // kipinde buluyordu. Haritadan dönüşteki sinyal (Navigator sonucu) listeyi yalnız
      // GÖRÜNÜME alır; düzenlemek isteyen Sırala → "Elle sırala"yı kendisi seçer.
      haritayiKur(konum: const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12));
      genisYuzey(tester);
      late AppDatabase db;
      late List<String> idler;
      await tester.runAsync(() async => (db, idler) = await kur());
      // Sunucu sırayı TERS döndürsün ki listedeki değişiklik gözle görülsün.
      rotayiSahtele(idler.reversed.toList());

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.text('Harita'));
      await akisiBekle(tester, ms: 400);

      await otoSirala(tester);
      expect(find.text('Rota sıralandı, 33 hakkınız kaldı.'), findsOneWidget);

      // İKİ TUR ŞART: geri dönüş `PopScope` üzerinden gidiyor (donanım geri tuşu da sonucu
      // taşısın diye). İlk tur bekleyen mikro görevleri boşaltıp `pop`u başlatır, ikinci tur
      // geçiş animasyonunu bitirip rotayı ağaçtan söker. Tek turda ekran hâlâ ağaçtadır.
      await tester.tap(find.bySemanticsLabel('Geri'));
      await akisiBekle(tester, ms: 500);
      await akisiBekle(tester, ms: 500);

      expect(find.byType(SiparisHaritaEkrani), findsNothing, reason: 'listeye dönüldü');
      // Sıralama sheet'i seçili kipi işaretler — liste "Rota sırası"nda.
      await tester.tap(find.text('Sırala'));
      await akisiBekle(tester);
      expect(
        tester
            .widget<SecimSatiri>(find.widgetWithText(SecimSatiri, 'Rota sırası'))
            .secili,
        isTrue,
      );
      await tester.tapAt(const Offset(10, 10)); // sheet'i kapat
      await akisiBekle(tester, ms: 400);

      // ASIL SÖZLEŞME: tutamaç ve elle bandı YOK.
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      expect(find.text('Bitti'), findsNothing);
      expect(find.text('Tutamaçtan sürükleyip bırak, bitince “Bitti”ye bas.'), findsNothing);

      await ekraniKapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // B. Harita ekranı
  // ═════════════════════════════════════════════════════════════════════════════════════════

}
