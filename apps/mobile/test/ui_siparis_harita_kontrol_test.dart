// ROTA KONUMU + SİPARİŞ HARİTASI (kullanıcı isteği 2026-07-29).
//
// İki iş, tek dert: "Oto Sırala" nereden başlıyor ve o sıra yeryüzünde neye benziyor?
//
//  A. Oto sıralama kuryenin BULUNDUĞU noktadan başlar (`start`). Konum alınamazsa istek yine
//     gider ama kullanıcıya HANGİ KİPTE sıralandığı söylenir — sessiz bozulma yasak.
//  B. Harita ekranı açık siparişleri rota sırasında numaralı pinlerle çizer.
//
// Bu dosyadaki widget testleri AĞA ve PLATFORM KANALINA hiç uzanmaz: `cihazKonumuOku`,
// `rotaApiUret` ve `haritaTuvaliUret` dikişleri sahtelenir. Sızan bir sahte bir sonraki testte
// sessizce yanlış sonuç üretir — üçü de tearDown'da geri alınır.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/screens/orders/harita_icerigi.dart';
import 'package:sipario/screens/orders/harita_kontrolleri.dart';
import 'package:sipario/screens/orders/harita_stili.dart';
import 'package:sipario/screens/orders/order_list_screen.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';

import 'support/harita_ortami.dart';
import 'support/siparis_yardimci.dart';

/// HARİTA EKRANI — STİL ve KAMERA KONTROLLERİ.
///
/// Bölme gerekçesi: `ui_siparis_harita_test.dart` başlığı. Kamera yerel motordadır ve widget
/// testinde çizilemez; testler kameraya verilen KOMUTLARI sahte tuvalden okur.
void main() {
  group('Sipariş haritası — stil ve kamera', () {
    late SahteHaritaTuvali harita;
    setUp(() => harita = haritaDikisleriniSahtele());

    Future<AppDatabase> ikiDurak(WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: 36.8841, lng: 30.7056, sira: 0);
        await siparisEkle(db, ad: 'Mehmet Kaya', lat: 36.9200, lng: 30.7600, sira: 10);
      });
      return db;
    }

    testWidgets('AÇIK temada harita açık stille, atfıyla çizilir', (tester) async {
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(harita.sonAyar!.koyu, isFalse);
      // Atıf HUKUKİ ZORUNLULUK — kaldırılamaz, metni sözleşmedir.
      expect(find.text('© OpenFreeMap © OpenMapTiles © OpenStreetMap'), findsOneWidget);
      expect(HaritaAtfi.metin, HaritaStili.atif);

      await ekraniKapat(tester);
    });

    testWidgets('KOYU temada harita koyu stile geçer', (tester) async {
      // Saha bulgusu (2026-07-29): uygulama koyu temadayken harita bembeyaz açılıyordu —
      // hem göz alıyor hem "bozuk" izlenimi veriyordu. Stil temayı İZLER.
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabukKoyu(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      expect(harita.sonAyar!.koyu, isTrue);
      expect(HaritaStili.adres(koyu: true), endsWith('/styles/dark'));
      expect(HaritaStili.adres(koyu: false), endsWith('/styles/positron'));
      // Atıf koyuda da durur — hukuki zorunluluk temayla pazarlık etmez.
      expect(find.text(HaritaStili.atif), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('kadraj üstteki düğmelerin payını bırakır', (tester) async {
      // Sağda kontrol sütunu, altta "Oto Sırala" var: sığdırılan bir pin onların altında
      // kalırsa dokunulamaz.
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      final pay = harita.sonAyar!.kenarBoslugu;
      expect(pay.right, greaterThan(12 + 40));
      expect(pay.bottom, greaterThan(pay.top));

      await ekraniKapat(tester);
    });

    testWidgets('+ / − düğmeleri kamerayı birer kademe yakınlaştırır ve uzaklaştırır',
        (tester) async {
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.bySemanticsLabel('Yakınlaş'));
      await akisiBekle(tester);
      await tester.tap(find.bySemanticsLabel('Uzaklaş'));
      await akisiBekle(tester);

      expect(
        [for (final k in harita.komutlar.whereType<YakinlastirKomutu>()) k.fark],
        [1, -1],
      );

      await ekraniKapat(tester);
    });

    testWidgets('"Duraklara sığdır" bütün durakları kadraja alır', (tester) async {
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.bySemanticsLabel('Duraklara sığdır'));
      await akisiBekle(tester);

      final kadraj = harita.komutlar.whereType<KadrajlaKomutu>().single.kadraj;
      expect(kadraj.kutuMu, isTrue);
      expect(kadraj.guneyBati, const HaritaNoktasi(36.8841, 30.7056));
      expect(kadraj.kuzeyDogu, const HaritaNoktasi(36.9200, 30.7600));

      await ekraniKapat(tester);
    });

    testWidgets('"Konumum" kamerayı cihaz konumuna sokak ölçeğinde taşır', (tester) async {
      // Açılışta konum YOK (setUp hata fırlatıyor), düğmeye basınca gelir: düğmenin TAZE
      // okuduğunun kanıtı bu — açılıştaki tek denemeyi tekrar kullansaydı hiçbir şey olmazdı.
      genisYuzey(tester);
      final db = await ikiDurak(tester);

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      expect(harita.cihaz, findsNothing);

      cihazKonumuOku =
          () async => const CihazKonumu(lat: 36.7000, lng: 30.5000, dogrulukM: 20);
      await tester.tap(find.bySemanticsLabel('Konumum'));
      await akisiBekle(tester, ms: 300);

      final odak = harita.komutlar.whereType<OdaklaKomutu>().single;
      expect(odak.nokta, const HaritaNoktasi(36.7000, 30.5000));
      expect(odak.zoom, 15);
      // Pin de güncellenir: kamera oraya gitti ama kuryenin kendisi görünmeseydi eksik olurdu.
      expect(harita.cihaz, findsOneWidget);

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

      await tester.tap(find.bySemanticsLabel('Konumum'));
      await akisiBekle(tester, ms: 300);

      expect(find.text('Konum servisi kapalı — telefonun konum ayarını açın.'), findsOneWidget);
      expect(harita.komutlar, isEmpty);
      expect(harita.cihaz, findsNothing);

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
      await akisiBekle(tester, ms: 400);

      expect(find.byType(SiparisHaritaEkrani), findsOneWidget);
      expect(harita.duraklar, findsOneWidget);

      await ekraniKapat(tester);
    });
  });
}
