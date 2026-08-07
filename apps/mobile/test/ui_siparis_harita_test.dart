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
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/tenant_settings_repository.dart';
import 'package:sipario/screens/orders/harita_sorgulari.dart';
import 'package:sipario/screens/orders/musteri_eylemleri.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/order_sheets.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/screens/orders/siparis_harita_ozet.dart';
import 'package:sipario/sync/route_api.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/siparis_yardimci.dart';

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
      await tester.tap(find.text('Oto Sırala · 34 hak'));
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
      expect(find.text('Rota otomatik sıralandı · 33 hak kaldı'), findsOneWidget);

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
        find.text('Rota otomatik sıralandı · 33 hak kaldı · konum alınamadı, ilk duraktan'),
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
      expect(find.text('Rota otomatik sıralandı · 33 hak kaldı'), findsOneWidget);

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
        find.text('Rota otomatik sıralandı · 33 hak kaldı · konum alınamadı, ilk duraktan'),
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
      expect(find.text('Rota otomatik sıralandı · 33 hak kaldı'), findsOneWidget);

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

  group('Sipariş haritası', () {
    // Cihaz konumu VARSAYILAN OLARAK alınamaz: eklentisiz ortamın gerçeği bu ve haritanın
    // onsuz da çalıştığı her testte kanıtlanmış olur.
    setUp(haritaDikisleriniSahtele);

    /// Bir müşteri + siparişi. [lat]/[lng] null ise adres konumsuzdur.
    Future<String> siparisEkle(
      AppDatabase db, {
      required String ad,
      double? lat,
      double? lng,
      bool teslim = false,
      int? sira,
      String? telefon,
      String? not,
      int tutarKurus = 4500,
    }) async {
      final cid = await CustomerRepository(db).create(
        name: ad,
        phones: [
          if (telefon != null) PhoneInput(phoneE164: telefon, isPrimary: true),
        ],
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
      final oid = await repo.create(customerId: cid, note: not, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: tutarKurus, qty: 1),
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

    testWidgets('pine dokununca ÖZET açılır — detay ekranı AÇILMAZ', (tester) async {
      // Kullanıcı isteği 2026-07-29: pin doğrudan detaya gidiyordu. Kurye haritada önce "burada
      // ne var" sorusunu sorar; tam detay bir dokunuş uzakta durmalı, haritayı kaybettirmemeli.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db,
            ad: 'Mehmet Kaya',
            lat: 36.8900,
            lng: 30.7100,
            sira: 10,
            tutarKurus: 12500,
            not: 'Zili çalma, kapıyı tıklat');
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      // Harita müşteri ADI yazmaz — başlığın belirmesi sayfanın açıldığının kanıtıdır.
      expect(find.byType(DurakOzetGovde), findsNothing);
      await tester.tap(find.widgetWithText(DurakPini, '2'));
      await akisiBekle(tester, ms: 400);

      // Başlık dokunulan PİNİN numarasını taşır: yanlış pine dokunmak sık ve sessiz bir hatadır.
      expect(find.text('2. Durak · Mehmet Kaya'), findsOneWidget);
      expect(find.text(sipTutar(12500)), findsOneWidget);
      expect(find.text('Mehmet Kaya sokağı No: 1'), findsOneWidget);
      expect(find.textContaining('Zili çalma'), findsOneWidget);
      // Asıl sözleşme: DETAY açılmadı.
      expect(find.byType(SiparisDetayGovde), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('özetteki "Sipariş Detayı" detay sayfasını açar', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.widgetWithText(DurakPini, '1'));
      await akisiBekle(tester, ms: 400);

      await tester.tap(find.text('Sipariş Detayı'));
      await akisiBekle(tester, ms: 600);

      expect(find.byType(SiparisDetayGovde), findsOneWidget);
      // Detay özetin YERİNE geçer — iki sayfa üst üste kalsaydı geri dönmek iki dokunuş olurdu.
      expect(find.byType(DurakOzetGovde), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('"Yol Tarifi" geo: URI ile harici haritayı açar', (tester) async {
      // Koordinatlar `toStringAsFixed` ile yazılır: cihaz yereli virgüle geçse bile URI bozulmaz.
      final acilanlar = <Uri>[];
      final eskiAcici = uriAcici;
      uriAcici = (u) async {
        acilanlar.add(u);
        return true; // ilk aday açıldı → yedek (Google Maps web) hiç denenmez
      };
      addTearDown(() => uriAcici = eskiAcici);

      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.widgetWithText(DurakPini, '1'));
      await akisiBekle(tester, ms: 400);

      await tester.tap(find.text('Yol Tarifi'));
      await akisiBekle(tester, ms: 300);

      expect(acilanlar, hasLength(1));
      expect(acilanlar.single.scheme, 'geo');
      // Sıra ENLEM,BOYLAM — ters yazılmış bir çift kuryeyi başka bir ile gönderir.
      expect(acilanlar.single.toString(), startsWith('geo:36.890000,30.710000'));
      // Özet AÇIK kalır: kurye harici haritadan dönünce durağı yerinde bulmalı.
      expect(find.byType(DurakOzetGovde), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('telefonu OLAN müşteride "Ara" düğmesi tel: URI açar', (tester) async {
      final acilanlar = <Uri>[];
      final eskiAcici = uriAcici;
      uriAcici = (u) async {
        acilanlar.add(u);
        return true;
      };
      addTearDown(() => uriAcici = eskiAcici);

      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db,
            ad: 'Mehmet Kaya',
            lat: 36.8900,
            lng: 30.7100,
            sira: 0,
            telefon: '+905321112233');
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.widgetWithText(DurakPini, '1'));
      await akisiBekle(tester, ms: 400);

      await tester.tap(find.text('Ara'));
      await akisiBekle(tester, ms: 300);

      expect(acilanlar.single.toString(), 'tel:+905321112233');

      await ekraniKapat(tester);
    });

    testWidgets('telefonu OLMAYAN müşteride "Ara" düğmesi HİÇ çizilmez', (tester) async {
      // Hiçbir yere gitmeyen düğme çizilmez: tek başına duran pasif bir "Ara", kullanıcıya
      // uygulamanın bozuk olduğunu düşündürür (liste satırındaki ŞERİT farklı — orada düğmenin
      // kaybolması hizalamayı bozardı, bu yüzden orada pasif çizilir).
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.8900, lng: 30.7100, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      await tester.tap(find.widgetWithText(DurakPini, '1'));
      await akisiBekle(tester, ms: 400);

      expect(find.text('Ara'), findsNothing);
      // Yol tarifi HER durakta vardır — koordinatsız sipariş zaten haritaya girmiyor.
      expect(find.text('Yol Tarifi'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('cihaz konumu pini özet AÇMAZ (o bir durak değil)', (tester) async {
      cihazKonumuOku =
          () async => const CihazKonumu(lat: 36.8850, lng: 30.7060, dogrulukM: 15);

      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.byType(CihazPini));
      await akisiBekle(tester, ms: 400);

      expect(find.byType(DurakOzetGovde), findsNothing);

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

    // ───────────────────────────────────────────────────────────────────────────────────────
    // Stil ve kontroller (kullanıcı isteği 2026-07-29: "harita stili uygulamaya yakın olmalı,
    // gereksiz şeyler kaldırılmalı, harita butonları eklenmeli")
    // ───────────────────────────────────────────────────────────────────────────────────────

    /// Haritanın kamerası — kontrolcü `FlutterMap`e verildiği için testten okunabilir.
    MapController kamera(WidgetTester tester) =>
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;

    Future<AppDatabase> ikiDurak(WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.9200, lng: 30.7600, sira: 10);
      });
      return db;
    }

    testWidgets('karo katmanı CARTO Positron şablonunu kullanır', (tester) async {
      // STİL SÖZLEŞMESİ: ham OSM karosu (kırmızı otoyollar, yol kodu etiketleri, POI seli)
      // uygulamanın sade dilinin yanında gürültü gibi duruyordu ve mor pinler kayboluyordu.
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      final katman = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(katman.urlTemplate,
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png');
      expect(katman.subdomains, ['a', 'b', 'c', 'd']);
      // Atıf HUKUKİ ZORUNLULUK — kaldırılamaz, metni sözleşmedir.
      expect(find.text('© OpenStreetMap katkıcıları · © CARTO'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('KOYU temada karo Dark Matter şablonuna geçer', (tester) async {
      // Saha bulgusu (2026-07-29): uygulama koyu temadayken harita bembeyaz açılıyordu —
      // hem göz alıyor hem "bozuk" izlenimi veriyordu. Karo stili temayı İZLER; seçim
      // `haritaKaroUrl(koyu:)` tek yerinde durur, bu test o sözleşmeyi kilitler.
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabukKoyu(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      final katman = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(katman.urlTemplate,
          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png');
      // Atıf koyuda da durur — hukuki zorunluluk temayla pazarlık etmez.
      expect(find.text('© OpenStreetMap katkıcıları · © CARTO'), findsOneWidget);

      await ekraniKapat(tester);
    });

    test('üretim karo sağlayıcısının varsayılanı İPTAL EDİLEBİLİR indirmedir', () {
      // Saha bulgusu (2026-07-29): "harita çok kasıyor". Kaydırmada görünürlükten çıkan
      // karoların istekleri iptal edilmezse kuyruk ana iş parçacığını boğar. Dikişin
      // varsayılanı ayrı fonksiyonda durur ki bu söz, testlerin dikişi sahteyle değiştirdiği
      // durumdan bağımsız sınanabilsin.
      expect(varsayilanKaroSaglayici(), isA<CancellableNetworkTileProvider>());
    });

    testWidgets('+ / − düğmeleri kamerayı yakınlaştırır ve uzaklaştırır', (tester) async {
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      final onceki = kamera(tester).camera.zoom;
      await tester.tap(find.bySemanticsLabel('Yakınlaş'));
      await akisiBekle(tester);
      expect(kamera(tester).camera.zoom, closeTo(onceki + 1, 0.001));

      await tester.tap(find.bySemanticsLabel('Uzaklaş'));
      await akisiBekle(tester);
      expect(kamera(tester).camera.zoom, closeTo(onceki, 0.001));

      await ekraniKapat(tester);
    });

    testWidgets('"Duraklara sığdır" açılış kadrajına döndürür', (tester) async {
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      final acilis = kamera(tester).camera;
      final acilisZoom = acilis.zoom;
      final acilisMerkez = acilis.center;

      // Kullanıcı elle yakınlaşıp kayboldu…
      await tester.tap(find.bySemanticsLabel('Yakınlaş'));
      await akisiBekle(tester);
      await tester.tap(find.bySemanticsLabel('Yakınlaş'));
      await akisiBekle(tester);
      expect(kamera(tester).camera.zoom, greaterThan(acilisZoom));

      // …tek dokunuşla bütün duraklar yine kadrajda.
      await tester.tap(find.bySemanticsLabel('Duraklara sığdır'));
      await akisiBekle(tester);
      expect(kamera(tester).camera.zoom, closeTo(acilisZoom, 0.001));
      expect(kamera(tester).camera.center.latitude,
          closeTo(acilisMerkez.latitude, 0.0001));
      expect(kamera(tester).camera.center.longitude,
          closeTo(acilisMerkez.longitude, 0.0001));

      await ekraniKapat(tester);
    });

    testWidgets('"Konumum" kamerayı cihaz konumuna taşır', (tester) async {
      // Açılışta konum YOK (setUp hata fırlatıyor), düğmeye basınca gelir: düğmenin TAZE
      // okuduğunun kanıtı bu — açılıştaki tek denemeyi tekrar kullansaydı hiçbir şey olmazdı.
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      expect(find.byType(CihazPini), findsNothing);

      cihazKonumuOku =
          () async => const CihazKonumu(lat: 36.7000, lng: 30.5000, dogrulukM: 20);
      await tester.tap(find.bySemanticsLabel('Konumum'));
      await akisiBekle(tester, ms: 300);

      expect(kamera(tester).camera.center.latitude, closeTo(36.7000, 0.0001));
      expect(kamera(tester).camera.center.longitude, closeTo(30.5000, 0.0001));
      expect(kamera(tester).camera.zoom, closeTo(15, 0.001));
      // Pin de güncellenir: kamera oraya gitti ama kuryenin kendisi görünmeseydi eksik olurdu.
      expect(find.byType(CihazPini), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('konum alınamazsa "Konumum" sebebini söyler ve kamera OYNAMAZ', (tester) async {
      // Sessiz kalan bir düğme "uygulama bozuk" dedirtir; sebep AYRI AYRI söylenir
      // (`cihaz_konumu.dart` kuralı: "izin verilmedi" ile "GPS kapalı" farklı işler).
      cihazKonumuOku = () async =>
          throw const KonumHatasi('Konum servisi kapalı — telefonun konum ayarını açın.');

      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      final onceki = kamera(tester).camera;

      await tester.tap(find.bySemanticsLabel('Konumum'));
      await akisiBekle(tester, ms: 300);

      expect(find.text('Konum servisi kapalı — telefonun konum ayarını açın.'), findsOneWidget);
      expect(kamera(tester).camera.zoom, closeTo(onceki.zoom, 0.001));
      expect(kamera(tester).camera.center.latitude, closeTo(onceki.center.latitude, 0.0001));
      expect(find.byType(CihazPini), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('sipariş listesinden "Harita" çipiyle açılır', (tester) async {
      // Çip 2026-08-01'de başlıktaki çıplak pin ikonunun yerini aldı: etiketi olmayan bir düğme
      // ancak dokunarak öğrenilirdi.
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
      });

      await tester.pumpWidget(sipKabuk(OrderListScreen(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.text('Harita'));
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

    test('kod rozeti bayi TERCİHİNİ izler (liste satırıyla tek kural)', () async {
      // Harita başka bir numara gösterseydi bayi aynı siparişi iki farklı kodla anardı.
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        addresses: [
          AddressInput(addressText: 'Bahçe Sk.', lat: 36.9, lng: 30.7, isPrimary: true),
        ],
      );
      final oid = await OrderRepository(db).create(customerId: cid, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      // Kodlar SUNUCUDAN gelir (yerelde üretilmez) — senkron sonrası hâli elle kurulur.
      await (db.update(db.customers)..where((t) => t.id.equals(cid)))
          .write(const CustomersCompanion(code: Value(102)));
      await (db.update(db.orders)..where((t) => t.id.equals(oid)))
          .write(const OrdersCompanion(code: Value(248)));

      expect((await watchHaritaDuraklari(db).first).duraklar.single.kod, '102');

      await TenantSettingsRepository(db).siparisKoduTercihiKaydet('siparis');
      expect((await watchHaritaDuraklari(db).first).duraklar.single.kod, '#248');

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
