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

  testWidgets('konumsuz adreste "Konumu Kaydet" yazar ve dokununca KAYDEDER', (tester) async {
    // Metin duruma göre değişir: olmayan bir şeyi "güncellemek" yanlış okunurdu.
    konumSahtele(() => const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12));
    late AppDatabase db;
    late String cid, oid;
    await tester.runAsync(() async => (db, cid, oid) = await kur());

    genisYuzey(tester);
    await tester.pumpWidget(sipKabuk(OrderDetailScreen(db: db, orderId: oid, writable: true)));
    await akisiBekle(tester);

    expect(find.text('Konumu Kaydet'), findsOneWidget);
    expect(find.text('Konum alınmamış'), findsOneWidget);

    await tester.tap(find.text('Konumu Kaydet'));
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
    expect(find.text('Konumu Kaydet'), findsOneWidget);
    await tester.tap(find.text('Konumu Kaydet'));
    await akisiBekle(tester, ms: 300);

    expect(find.text('Aboneliğiniz sona erdi — konum kaydedilemiyor.'), findsOneWidget);
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

    await tester.tap(find.text('Konumu Kaydet'));
    await akisiBekle(tester, ms: 300);

    expect(find.text('Konum izni verilmedi'), findsOneWidget);
    // Düğme yeniden denemeye AÇIK kalmalı: izin verildikten sonra ikinci dokunuş çalışmalı.
    expect(find.text('Konumu Kaydet'), findsOneWidget);

    await ekraniKapat(tester);
  });
}
