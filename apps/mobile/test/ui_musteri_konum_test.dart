// KONUM — iki ayrı yol, iki ayrı dikiş.
//
//  1. "Adresten Konum Al": kendi sunucumuza sorar (`POST /geocode`), ADAY döner, doğrusunu
//     KULLANICI seçer. Sağlayıcı (Yandex/Google) anahtarı APK'da DEĞİL sunucudadır.
//  2. "Konum Güncelle": cihazın BULUNDUĞU noktayı yazar — adresten kodlama sokağı bulur, kapıyı
//     bulmaz; doğru pin ancak orada durup alınır.
//
// İkisi de widget testinde platform kanalına/ağa UZANMAZ: `adresAdaylariGetir` ve
// `cihazKonumuOku` dikişlerinden sahte verilir (`sesliGirisUret` deseninin aynısı). Sızan sahte
// bir sonraki testte sessizce yanlış sonuç üretir — tearDown'da ikisi de geri alınır.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/customers/customer_form_screen.dart';
import 'package:sipario/screens/customers/customer_location_picker.dart';
import 'package:sipario/sync/geocode_api.dart';
import 'package:sipario/theme/app_theme.dart';

void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  // GeocodeApi — sunucu yanıtının çözümü
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('GeocodeApi', () {
    GeocodeApi apiKur(MockClient client) =>
        GeocodeApi(baseUrl: 'https://ornek.test/api/v1', token: 'tk', client: client);

    test('adayları çözer; BOZUK kayıt atlanır, sağlamlar kalır', () async {
      // Tek bozuk kayıt yüzünden bütün listeyi düşürmek kullanıcıyı boş yere adressiz bırakırdı.
      final api = apiKur(MockClient((_) async => http.Response(
            jsonEncode({
              'results': [
                {'text': 'Antalya, Kepez, Bahçe Sk., 5', 'lat': 36.8969, 'lng': 30.7133, 'precision': 'bina'},
                {'text': 'Metinsiz değil ama koordinatsız', 'lat': null, 'lng': 30.7},
                {'text': '', 'lat': 36.9, 'lng': 30.7},
                {'text': 'Antalya, Kepez, Bahçe Sk.', 'lat': 36.9014, 'lng': 30.7221},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )));

      final adaylar = await api.ara('Bahçe Sk. no:5', bolge: 'Kepez');

      expect(adaylar, hasLength(2));
      expect(adaylar.first.metin, 'Antalya, Kepez, Bahçe Sk., 5');
      expect(adaylar.first.lat, 36.8969);
      expect(adaylar.first.lng, 30.7133);
      expect(adaylar.first.kesinlik, 'bina');
      // Sunucu kesinlik bildirmediyse en TEMKİNLİ kademe varsayılır.
      expect(adaylar.last.kesinlik, 'semt');
    });

    test('kaynak alanı çözülür; alan YOKSA boş kalır (eski sunucu)', () async {
      final api = apiKur(MockClient((_) async => http.Response(
            jsonEncode({
              'results': [
                {'text': 'Bahçe Sk. 5', 'lat': 36.8969, 'lng': 30.7133, 'source': 'google+yandex'},
                {'text': 'Bahçe Sk.', 'lat': 36.9014, 'lng': 30.7221},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )));

      final adaylar = await api.ara('Bahçe Sk. no:5');

      expect(adaylar.first.kaynak, 'google+yandex');
      // Alanı hiç göndermeyen sunucu bir ARIZA değildir: aday yine gösterilir, etiketi çizilmez.
      expect(adaylar.last.kaynak, '');
    });

    test('bölge yalnız DOLUYSA gövdeye konur', () async {
      late Map<String, dynamic> govde;
      final api = apiKur(MockClient((istek) async {
        govde = jsonDecode(istek.body) as Map<String, dynamic>;
        return http.Response('{"results":[]}', 200);
      }));

      await api.ara('Bahçe Sk. no:5', bolge: '   ');
      expect(govde.containsKey('region'), isFalse, reason: 'boş bölge sorguyu bozar');

      await api.ara('Bahçe Sk. no:5', bolge: 'Kepez');
      expect(govde['region'], 'Kepez');
    });

    test('sunucunun nötr mesajı aynen taşınır (503)', () async {
      final api = apiKur(MockClient((_) async => http.Response(
            jsonEncode({'message': 'Adres servisine ulaşılamadı — birazdan tekrar deneyin.'}),
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )));

      expect(
        () => api.ara('Bahçe Sk. no:5'),
        throwsA(isA<GeocodeException>().having(
          (e) => e.message, 'mesaj', contains('birazdan tekrar deneyin'))),
      );
    });

    test('ağ düşerse kullanıcıya çevrimdışı gerçeği söylenir', () async {
      final api = apiKur(MockClient((_) async => throw http.ClientException('kopuk')));

      expect(
        () => api.ara('Bahçe Sk. no:5'),
        throwsA(isA<GeocodeException>()
            .having((e) => e.message, 'mesaj', contains('İnternete ulaşılamadı'))),
      );
    });
  });

  group('AdresAdayi.kaynakNotu', () {
    test('mutabakat sağlayıcı ADI vermez, "iki servis de doğruladı" der', () {
      // Sunucu iki sağlayıcıyı birden sorduğunda (`coklu`) artı işareti MUTABAKAT demektir:
      // iki bağımsız servis aynı noktayı gösterdi. Bayi için "Yandex" ile "Google" arasındaki
      // fark bir şey ifade etmez; "ikisi de burayı gösterdi" doğrudan seçim kararını kolaylaştırır.
      const mutabakat =
          AdresAdayi(metin: 'x', lat: 36.9, lng: 30.7, kaynak: 'google+yandex');
      expect(mutabakat.kaynakNotu, 'iki servis de doğruladı');
      expect(mutabakat.mutabakatVar, isTrue);
    });

    test('tek sağlayıcı kendi adıyla görünür', () {
      const y = AdresAdayi(metin: 'x', lat: 36.9, lng: 30.7, kaynak: 'yandex');
      const g = AdresAdayi(metin: 'x', lat: 36.9, lng: 30.7, kaynak: 'google');
      expect(y.kaynakNotu, 'Yandex');
      expect(g.kaynakNotu, 'Google');
      expect(y.mutabakatVar, isFalse);
    });

    test('kaynak BİLİNMİYORSA satır sessizce eski gibi çizilir', () {
      // Eski sunucu `source` alanını hiç göndermez; bu, boş bir etiket çizmek için sebep değil.
      const bilinmeyen = AdresAdayi(metin: 'x', lat: 36.9, lng: 30.7);
      expect(bilinmeyen.kaynakNotu, isNull);
      expect(bilinmeyen.mutabakatVar, isFalse);
    });
  });

  group('AdresAdayi.kesinlikNotu', () {
    test('yalnız BİNA kesinliğinde uyarı YOKTUR', () {
      const bina = AdresAdayi(metin: 'x', lat: 36.9, lng: 30.7, kesinlik: 'bina');
      const sokak = AdresAdayi(metin: 'x', lat: 36.9, lng: 30.7, kesinlik: 'sokak');
      const semt = AdresAdayi(metin: 'x', lat: 36.9, lng: 30.7, kesinlik: 'semt');

      // "Sokak" kesinliğindeki pin kuryeyi doğru sokağa götürür, doğru kapıya götürmez —
      // bunu sessizce "konum kayıtlı" saymak, güvenilen bir yanlış üretir.
      expect(bina.kesinlikNotu, isNull);
      expect(sokak.kesinlikNotu, 'sokak yaklaşık');
      expect(semt.kesinlikNotu, 'semt yaklaşık');
    });
  });

  group('CihazKonumu.guvenilir', () {
    test('100 m üstü ölçüm kapı adresi sayılmaz', () {
      expect(const CihazKonumu(lat: 36.9, lng: 30.7, dogrulukM: 12).guvenilir, isTrue);
      expect(const CihazKonumu(lat: 36.9, lng: 30.7, dogrulukM: 100).guvenilir, isTrue);
      expect(const CihazKonumu(lat: 36.9, lng: 30.7, dogrulukM: 480).guvenilir, isFalse);
      // Doğruluk bilinmiyorsa (0) güvenilir SAYILMAZ — bilinmeyeni iyi varsaymak yanlış yön.
      expect(const CihazKonumu(lat: 36.9, lng: 30.7, dogrulukM: 0).guvenilir, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Ekran akışları
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('Ekranlar', () {
    /// Sahte bulucuya giden adres metinleri — servise NE gönderildiğini kanıtlar.
    late List<String> aramalar;

    setUp(() {
      aramalar = [];
    });

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

    void bulucuPatlat(String mesaj) {
      adresAdaylariGetir = (db, metin) async => throw GeocodeException(mesaj);
    }

    Future<void> ekranaKoy(WidgetTester tester, Widget ekran) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: SipTheme.acik(), home: ekran));
      await tester.pumpAndSettle();
    }

    Future<void> formuAc(WidgetTester tester, AppDatabase db) async {
      await ekranaKoy(
        tester,
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => musteriEkleSheet(ctx, db: db),
                child: const Text('AÇ'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('AÇ'));
      await tester.pumpAndSettle();
    }

    Future<void> kapat(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }

    testWidgets('adresten konum: adaylar çizilir, SEÇİLEN koordinat kaydedilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      bulucuKur(const [
        AdresAdayi(metin: 'Antalya, Kepez, Bahçe Sk.', lat: 36.9014, lng: 30.7221, kesinlik: 'sokak'),
        AdresAdayi(metin: 'Antalya, Kepez, Bahçe Sk., 5', lat: 36.8969, lng: 30.7133, kesinlik: 'bina'),
      ]);
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(0), 'Konumlu Kişi');
      await tester.enterText(find.byType(TextField).at(1), '0532 111 22 33');
      await tester.enterText(find.byType(TextField).at(2), 'Bahçe Sk. no:5');
      await tester.pump();

      await tester.tap(find.text('Konum Al'));
      await tester.pumpAndSettle();

      // Servise giden TEK şey adres metnidir (bölge alanı 2026-07-28'de kaldırıldı; semt/ilçe
      // artık adresin içine yazılır).
      expect(aramalar.single, 'Bahçe Sk. no:5');

      // Konum OTOMATİK atanmaz: iki aday da listede, hiçbiri seçili değil.
      expect(find.text('Antalya, Kepez, Bahçe Sk.'), findsOneWidget);
      expect(find.text('Antalya, Kepez, Bahçe Sk., 5'), findsOneWidget);
      expect(find.textContaining('Konum alındı'), findsNothing);
      // Kapı kesinliği olmayan aday uyarısıyla gösterilir.
      expect(find.text('· sokak yaklaşık'), findsOneWidget);

      await tester.tap(find.text('Antalya, Kepez, Bahçe Sk., 5'));
      await tester.pumpAndSettle();

      expect(find.text('Konum alındı · 36.8969, 30.7133'), findsOneWidget);
      expect(find.text('Antalya, Kepez, Bahçe Sk.'), findsNothing, reason: 'aday listesi kapanır');

      await tester.tap(find.text('Müşteriyi Kaydet'));
      await tester.pumpAndSettle();

      late CustomerAddressesData adres;
      await tester.runAsync(() async {
        adres = await db.select(db.customerAddresses).getSingle();
      });
      expect(adres.lat, 36.8969);
      expect(adres.lng, 30.7133);
      expect(adres.addressText, 'Bahçe Sk. no:5', reason: 'adres metni adayla EZİLMEZ');
      // Bölge alanı kalktı: yeni kayıtlarda region HİÇ doldurulmaz.
      expect(adres.region, isNull);

      await kapat(tester);
    });

    testWidgets('adres metni değişince alınmış konum DÜŞER', (tester) async {
      // Koordinat artık o adrese ait değildir; sessizce tutmak yanlış kapı üretir.
      final db = AppDatabase(NativeDatabase.memory());
      bulucuKur(const [AdresAdayi(metin: 'Aday', lat: 36.8969, lng: 30.7133, kesinlik: 'bina')]);
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(2), 'Bahçe Sk. no:5');
      await tester.pump();
      await tester.tap(find.text('Konum Al'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aday'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Konum alındı'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(2), 'Bahçe Sk. no:7');
      await tester.pumpAndSettle();

      expect(find.textContaining('Konum alındı'), findsNothing);
      expect(find.text('Konum Al'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('sonuç yoksa ARIZA denmez — adresi açık yazması istenir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      bulucuKur(const []);
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(2), 'zzz qqq');
      await tester.pump();
      await tester.tap(find.text('Konum Al'));
      await tester.pumpAndSettle();

      expect(find.text(konumBulunamadiMesaji), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('servis arızası ile "bulunamadı" AYRI cümlelerdir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      bulucuPatlat('Adres servisine ulaşılamadı — birazdan tekrar deneyin.');
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(2), 'Bahçe Sk. no:5');
      await tester.pump();
      await tester.tap(find.text('Konum Al'));
      await tester.pumpAndSettle();

      // Kullanıcı beklemeli; adresi tekrar tekrar düzeltmemeli.
      expect(find.text('Adres servisine ulaşılamadı — birazdan tekrar deneyin.'), findsOneWidget);
      expect(find.text(konumBulunamadiMesaji), findsNothing);

      await kapat(tester);
    });

    testWidgets('adres boşken servise HİÇ gidilmez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      bulucuKur(const [AdresAdayi(metin: 'Aday', lat: 36.9, lng: 30.7)]);
      await formuAc(tester, db);

      await tester.tap(find.text('Konum Al'));
      await tester.pumpAndSettle();

      expect(aramalar, isEmpty, reason: 'boş sorgu kota yakar, sunucu da reddederdi');
      expect(find.text('Önce adresi yazın'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('konum alındıktan sonra çipe dokunmak CİHAZ konumuyla günceller', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      bulucuKur(const [AdresAdayi(metin: 'Aday', lat: 36.9014, lng: 30.7221, kesinlik: 'sokak')]);
      cihazKonumuOku = () async =>
          const CihazKonumu(lat: 36.8969, lng: 30.7133, dogrulukM: 8);
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(2), 'Bahçe Sk. no:5');
      await tester.pump();
      await tester.tap(find.text('Konum Al'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aday'));
      await tester.pumpAndSettle();
      expect(find.text('Konum alındı · 36.9014, 30.7221'), findsOneWidget);

      // Adresten türetilen "sokak" pini, kapının önünde alınan ölçümle değişir.
      await tester.tap(find.text('Konum alındı · 36.9014, 30.7221'));
      await tester.pumpAndSettle();

      expect(find.text('Konum alındı · 36.8969, 30.7133'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('konum izni yoksa sebep SÖYLENİR, form çalışmaya devam eder', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      bulucuKur(const [AdresAdayi(metin: 'Aday', lat: 36.9014, lng: 30.7221)]);
      cihazKonumuOku = () async => throw const KonumHatasi(
            'Konum izni kapalı — telefon ayarlarından Sipario için konum iznini açın.',
            ayarlaraYonlendir: true,
          );
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(2), 'Bahçe Sk. no:5');
      await tester.pump();
      await tester.tap(find.text('Konum Al'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aday'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konum alındı · 36.9014, 30.7221'));
      await tester.pumpAndSettle();

      expect(find.textContaining('telefon ayarlarından'), findsOneWidget);
      // Eski konum KORUNUR — hata yüzünden kayıtlı veri silinmez.
      expect(find.text('Konum alındı · 36.9014, 30.7221'), findsOneWidget);
      expect(find.text('Müşteriyi Kaydet'), findsOneWidget, reason: 'form kullanılabilir kalır');

      await kapat(tester);
    });

    testWidgets('detayda kayıtlı konum CİHAZ konumuyla güncellenir, adres metni bozulmaz',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      late String customerId;
      await tester.runAsync(() async {
        customerId = await CustomerRepository(db).create(
          name: 'Konumlu',
          phones: [PhoneInput(phoneE164: '+905321112233', isPrimary: true)],
          addresses: [
            AddressInput(
              addressText: 'Bahçe Sk. no:5',
              region: 'Kepez',
              label: 'Ev',
              lat: 36.9014,
              lng: 30.7221,
              isPrimary: true,
            ),
          ],
        );
      });
      cihazKonumuOku = () async => const CihazKonumu(lat: 36.8969, lng: 30.7133, dogrulukM: 9);

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: customerId, writable: true));

      expect(find.text('36.9014, 30.7221'), findsOneWidget);
      await tester.tap(find.text('36.9014, 30.7221'));
      await tester.pumpAndSettle();

      late CustomerAddressesData adres;
      await tester.runAsync(() async {
        adres = await db.select(db.customerAddresses).getSingle();
      });
      expect(adres.lat, 36.8969);
      expect(adres.lng, 30.7133);
      // Bu akış YALNIZ koordinat yazar: metin, bölge ve etiket olduğu gibi kalır.
      expect(adres.addressText, 'Bahçe Sk. no:5');
      expect(adres.region, 'Kepez');
      expect(adres.label, 'Ev');

      await kapat(tester);
    });

    testWidgets('salt-okunur kipte konum güncellenmez', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      var okundu = false;
      late String customerId;
      await tester.runAsync(() async {
        customerId = await CustomerRepository(db).create(
          name: 'Konumlu',
          addresses: [
            AddressInput(
                addressText: 'Bahçe Sk. no:5', lat: 36.9014, lng: 30.7221, isPrimary: true),
          ],
        );
      });
      cihazKonumuOku = () async {
        okundu = true;
        return const CihazKonumu(lat: 36.8969, lng: 30.7133, dogrulukM: 9);
      };

      await ekranaKoy(tester, CustomerDetailScreen(db: db, customerId: customerId, writable: false));
      await tester.tap(find.text('36.9014, 30.7221'));
      await tester.pumpAndSettle();

      // Yazma kapısı ÖNCE çalışır: izin yokken cihazın konumu hiç okunmaz (izin diyaloğu bile
      // açılmaz — kullanıcıya yapamayacağı bir işi teklif etmeyiz).
      expect(okundu, isFalse);
      late CustomerAddressesData adres;
      await tester.runAsync(() async {
        adres = await db.select(db.customerAddresses).getSingle();
      });
      expect(adres.lat, 36.9014);

      await kapat(tester);
    });

    testWidgets('oturum yoksa adres araması dürüstçe reddedilir', (tester) async {
      // Dikiş SAHTELENMEZ: gerçek `sunucudanAdresAdaylari` koşar ve token olmadığı için ağa
      // hiç çıkmaz. Testin ağa uzanmadığının kanıtı da budur.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
            .write(const SyncMetaCompanion(authToken: Value(null)));
      });

      await expectLater(
        () => sunucudanAdresAdaylari(db, 'Bahçe Sk. no:5'),
        throwsA(isA<GeocodeException>()
            .having((e) => e.message, 'mesaj', contains('oturum gerekir'))),
      );

      await tester.runAsync(db.close);
    });

    test('3 karakterden kısa sorgu sunucuya HİÇ gitmez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Sunucu da reddederdi; buradan çıkmaması bir tur ağ ve bir tur kota tasarrufudur.
      await expectLater(
        () => sunucudanAdresAdaylari(db, 'ab'),
        throwsA(isA<GeocodeException>()
            .having((e) => e.message, 'mesaj', contains('en az 3 karakter'))),
      );
    });
  });
}
