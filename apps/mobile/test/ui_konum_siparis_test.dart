// SİPARİŞ DETAYINDA "KONUM GÜNCELLE" (kullanıcı isteği 2026-07-29).
//
// İstek: "aktif bir siparişe tıkladığımızda çıkan menüde teslimat adresinin yakınında konum
// güncelle diye bir buton olmalı, anlık işlem yapan cihazın konumunu oraya kaydetmeli."
//
// Sahadaki değeri: kurye kapıyı İLK KEZ bulduğunda oradadır; o an tek dokunuşla kaydedilen pin,
// bir daha hiçbir kuryenin aynı kapıyı aramamasını sağlar. Bu yüzden testler düğmenin ÇİZİLDİĞİNİ
// değil, dokununca VERİTABANINA YAZDIĞINI sınar — çizilen ama yazmayan bir düğme bu depoda
// dört kez görüldü (kopmuş son halka: hata yok, sonuç da yok).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/customers/customer_form_ops.dart' show konumKaydet;
import 'package:sipario/screens/customers/customer_location_picker.dart';
import 'package:sipario/screens/orders/order_detail_screen.dart';

import 'support/siparis_yardimci.dart';

void main() {
  /// Konum okuyucusunu sahteleyip eski hâline döndürür — `cihaz_konumu.dart` dikişi tam da
  /// bunun için var (widget testleri platform kanalına HİÇ uzanmaz).
  void konumSahtele(CihazKonumu Function() uret) {
    final eski = cihazKonumuOku;
    cihazKonumuOku = () async => uret();
    addTearDown(() => cihazKonumuOku = eski);
  }

  Future<(AppDatabase, String, String)> kur({bool adresli = true}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final cid = await CustomerRepository(db).create(
      name: 'Ayşe Yılmaz',
      phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)],
      addresses: adresli
          ? [AddressInput(addressText: 'Şirinyalı Mah. 1497. Sk. No: 9', isPrimary: true)]
          : const [],
    );
    final oid = await OrderRepository(db).create(
      customerId: cid,
      lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1)],
    );
    return (db, cid, oid);
  }

  testWidgets('konumsuz adreste "Bulunduğum Yeri Kaydet" cihaz konumunu KAYDEDER', (tester) async {
    // Metin duruma göre değişir: olmayan bir şeyi "güncellemek" yanlış okunurdu.
    konumSahtele(() => const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12));
    late AppDatabase db;
    late String cid, oid;
    await tester.runAsync(() async => (db, cid, oid) = await kur());

    genisYuzey(tester);
    await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
    await akisiBekle(tester);

    expect(find.text('Bulunduğum Yeri Kaydet'), findsOneWidget);
    expect(find.text('Konum alınmamış'), findsOneWidget);

    await tester.tap(find.text('Bulunduğum Yeri Kaydet'));
    await akisiBekle(tester, ms: 300);

    await tester.runAsync(() async {
      final adres = await (db.select(db.customerAddresses)
            ..where((t) => t.customerId.equals(cid)))
          .getSingle();
      expect(adres.lat, closeTo(36.8841, 0.0001));
      expect(adres.lng, closeTo(30.7056, 0.0001));
      // ADRES METNİ DEĞİŞMEZ: bu akış yalnız koordinat ekler.
      expect(adres.addressText, 'Şirinyalı Mah. 1497. Sk. No: 9');
    });

    await ekraniKapat(tester);
  });

  testWidgets('konumu OLAN adreste "Konum Güncelle" yazar — pin düzeltilebilir', (tester) async {
    // Kodlamadan gelen "sokak" kesinliğindeki bir pin yanlış kapıya işaret edebilir; kurye
    // kapının önündeyken onu düzeltebilmeli.
    konumSahtele(() => const CihazKonumu(lat: 36.9, lng: 30.7, dogrulukM: 8));
    late AppDatabase db;
    late String cid, oid;
    await tester.runAsync(() async {
      (db, cid, oid) = await kur();
      final adres = await (db.select(db.customerAddresses)
            ..where((t) => t.customerId.equals(cid)))
          .getSingle();
      await konumKaydet(db, adres, 36.0, 30.0);
    });

    genisYuzey(tester);
    await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
    await akisiBekle(tester);

    expect(find.text('Konum Güncelle'), findsOneWidget);
    expect(find.textContaining('Konum kayıtlı'), findsOneWidget);

    await tester.tap(find.text('Konum Güncelle'));
    await akisiBekle(tester, ms: 300);

    await tester.runAsync(() async {
      final adres = await (db.select(db.customerAddresses)
            ..where((t) => t.customerId.equals(cid)))
          .getSingle();
      expect(adres.lat, closeTo(36.9, 0.0001), reason: 'eski pin ÜZERİNE yazılmalı');
    });

    await ekraniKapat(tester);
  });

  testWidgets('SALT-OKUNUR kipte yazmaz ve sebebini söyler', (tester) async {
    konumSahtele(() => const CihazKonumu(lat: 36.9, lng: 30.7, dogrulukM: 8));
    late AppDatabase db;
    late String cid, oid;
    await tester.runAsync(() async => (db, cid, oid) = await kur());

    genisYuzey(tester);
    await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: false)));
    await akisiBekle(tester);

    // Düğme GİZLENMEZ (Dilim 3 kararı: ana eylemler görünür kalır, kilit sebebini söyler).
    expect(find.text('Bulunduğum Yeri Kaydet'), findsOneWidget);
    await tester.tap(find.text('Bulunduğum Yeri Kaydet'));
    await akisiBekle(tester, ms: 300);

    expect(find.text('Aboneliğiniz sona erdiği için konum kaydedilemiyor'), findsOneWidget);
    await tester.runAsync(() async {
      final adres = await (db.select(db.customerAddresses)
            ..where((t) => t.customerId.equals(cid)))
          .getSingle();
      expect(adres.lat, isNull, reason: 'kilitli kipte tek koordinat bile yazılmamalı');
    });

    await ekraniKapat(tester);
  });

  testWidgets('konum okunamazsa hata SÖYLENİR, sessizce yutulmaz', (tester) async {
    cihazKonumuOku = () async => throw const KonumHatasi('Konum izni verilmedi');
    addTearDown(() => cihazKonumuOku = gercekCihazKonumu);

    late AppDatabase db;
    late String oid;
    await tester.runAsync(() async {
      final (d, _, o) = await kur();
      db = d;
      oid = o;
    });

    genisYuzey(tester);
    await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
    await akisiBekle(tester);

    await tester.tap(find.text('Bulunduğum Yeri Kaydet'));
    await akisiBekle(tester, ms: 300);

    expect(find.text('Konum izni verilmedi'), findsOneWidget);
    // Düğme yeniden denemeye AÇIK kalmalı: izin verildikten sonra ikinci dokunuş çalışmalı.
    expect(find.text('Bulunduğum Yeri Kaydet'), findsOneWidget);

    await ekraniKapat(tester);
  });

  // ── ADRESTEN KONUM BUL (kullanıcı şikâyeti 2026-09-26) ─────────────────────────────────
  // "Aktif siparişte adres konumunu bulmuyor, güncel konumu kaydediyor": konumsuz adreste tek
  // düğme GPS yazıyordu ve dükkânda basan patron kapıya dükkânın konumunu kaydediyordu.

  group('adresten konum bul', () {
    late List<String> aramalar;

    setUp(() => aramalar = []);
    tearDown(() {
      // Sızan sahte, sonraki testte sessizce yanlış sonuç üretir.
      adresAdaylariGetir = sunucudanAdresAdaylari;
      cihazKonumuOku = gercekCihazKonumu;
    });

    void bulucuKur(List<AdresAdayi> sonuc) {
      adresAdaylariGetir = (db, metin) async {
        aramalar.add(metin);
        return sonuc;
      };
    }

    Future<CustomerAddressesData> adresOku(WidgetTester tester, AppDatabase db, String cid) async =>
        (await tester.runAsync(() => (db.select(db.customerAddresses)
              ..where((t) => t.customerId.equals(cid)))
            .getSingle()))!;

    testWidgets('adres aranır, SEÇİLEN aday kaydedilir, cihaz konumu OKUNMAZ', (tester) async {
      var gpsOkundu = false;
      konumSahtele(() {
        gpsOkundu = true;
        return const CihazKonumu(lat: 1, lng: 1, dogrulukM: 5);
      });
      bulucuKur(const [
        AdresAdayi(metin: 'Antalya, Konyaaltı, 1497. Sk.', lat: 36.88, lng: 30.65, kesinlik: 'sokak'),
        AdresAdayi(metin: 'Antalya, Konyaaltı, 1497. Sk., 9', lat: 36.8812, lng: 30.6523, kesinlik: 'bina'),
      ]);
      late AppDatabase db;
      late String cid, oid;
      await tester.runAsync(() async => (db, cid, oid) = await kur());

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.text('Adresten Konum Bul'));
      await akisiBekle(tester, ms: 300);
      await tester.pump(const Duration(milliseconds: 600));

      expect(aramalar.single, 'Şirinyalı Mah. 1497. Sk. No: 9');
      // Otomatik atama YOK: seçilene dek hiçbir koordinat yazılmaz.
      expect((await adresOku(tester, db, cid)).lat, isNull);

      await tester.tap(find.text('Antalya, Konyaaltı, 1497. Sk., 9'));
      await akisiBekle(tester, ms: 300);

      final adres = await adresOku(tester, db, cid);
      expect(adres.lat, closeTo(36.8812, 0.0001));
      expect(adres.lng, closeTo(30.6523, 0.0001));
      expect(adres.addressText, 'Şirinyalı Mah. 1497. Sk. No: 9');
      expect(gpsOkundu, isFalse, reason: 'adresten bulmak cihaz konumuna HİÇ uzanmamalı');

      await ekraniKapat(tester);
    });

    testWidgets('sonuç yoksa ne yapılacağı söylenir, hiçbir şey yazılmaz', (tester) async {
      bulucuKur(const []);
      late AppDatabase db;
      late String cid, oid;
      await tester.runAsync(() async => (db, cid, oid) = await kur());

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
      await akisiBekle(tester);

      await tester.tap(find.text('Adresten Konum Bul'));
      await akisiBekle(tester, ms: 300);

      expect(find.text(konumBulunamadiMesaji), findsOneWidget);
      expect((await adresOku(tester, db, cid)).lat, isNull);

      await ekraniKapat(tester);
    });

    testWidgets('konumu OLAN adreste adresten bulma sunulmaz — kayıtlı pin ezilmez', (tester) async {
      late AppDatabase db;
      late String oid;
      await tester.runAsync(() async {
        final (d, cid, o) = await kur();
        db = d;
        oid = o;
        final adres = await (db.select(db.customerAddresses)
              ..where((t) => t.customerId.equals(cid)))
            .getSingle();
        await konumKaydet(db, adres, 36.0, 30.0);
      });

      genisYuzey(tester);
      await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
      await akisiBekle(tester);

      expect(find.text('Adresten Konum Bul'), findsNothing);
      expect(find.text('Konum Güncelle'), findsOneWidget);

      await ekraniKapat(tester);
    });
  });
}
