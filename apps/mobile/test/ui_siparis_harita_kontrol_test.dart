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


import 'package:drift/native.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';

import 'support/harita_ortami.dart';
import 'support/siparis_yardimci.dart';


/// HARİTA EKRANI — pinler · kurye katmanı · karo sağlayıcı · boş durum.
///
/// Bölme gerekçesi: `ui_siparis_harita_test.dart` başlığı.

/// HARİTA EKRANI — KARO KATMANI ve KAMERA KONTROLLERİ.
///
/// Bölme gerekçesi: `ui_siparis_harita_test.dart` başlığı.
void main() {
  group('Sipariş haritası — karo ve kamera', () {
    setUp(haritaDikisleriniSahtele);

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
}
