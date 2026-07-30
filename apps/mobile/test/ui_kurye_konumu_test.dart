// CANLI KURYE KONUMU — kalp atışı (yaz) + harita katmanı (oku).
//
// İki söz sınanır:
//  A. Uygulama açıkken kullanıcı 30 sn'de bir konumunu SESSİZCE bildirir; izin/GPS/ağ arızasında
//     tur atlanır ve kullanıcıya hiçbir şey gösterilmez.
//  B. Kurye pinlerini YALNIZ PATRON görür. Rol kurye ise katman kurulmaz ve `/locations/live`
//     HİÇ çağrılmaz — "görünmüyor ama istek gidiyor" bir gizlilik sızıntısıdır, kapı gerçek olmalı.
//
// Bu dosyadaki testler AĞA ve PLATFORM KANALINA hiç uzanmaz: `konumApiUret`, `sessizKonumOku`,
// `cihazKonumuOku` ve `haritaKaroSaglayici` dikişleri sahtelenir ve hepsi tearDown'da GERİ ALINIR
// (sızan bir sahte, bir sonraki testte sessizce yanlış sonuç üretir).

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/konum/konum_bildirici.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/orders/harita_kurye_katmani.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/sync/konum_api.dart';
import 'package:sipario/theme/tokens.dart';

import 'support/siparis_yardimci.dart';

/// Testte kullanılan karo sağlayıcı: her karo için TEK saydam görsel döner, hiçbir istek atmaz.
class SahteKaro extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

/// Sahte sunucuya giden tek istek — yol, yöntem ve (varsa) gövde.
class Istek {
  Istek(this.yontem, this.yol, this.govde);
  final String yontem;
  final String yol;
  final Map<String, dynamic>? govde;
}

void main() {
  /// Konum istemcisini sahte sunucuya bağlar; giden istekleri toplar, canlı listede [liste] döner.
  List<Istek> konumApisiniSahtele({
    List<Map<String, dynamic>> liste = const [],
    int heartbeatKodu = 204,
  }) {
    final istekler = <Istek>[];
    final eski = konumApiUret;
    konumApiUret = (baseUrl, token) => KonumApi(
          baseUrl: baseUrl,
          token: token,
          client: MockClient((istek) async {
            istekler.add(Istek(
              istek.method,
              istek.url.path,
              istek.body.isEmpty
                  ? null
                  : jsonDecode(istek.body) as Map<String, dynamic>,
            ));
            if (istek.url.path.endsWith('/heartbeat')) {
              return http.Response('', heartbeatKodu);
            }
            return http.Response(
              jsonEncode({'locations': liste}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
    addTearDown(() => konumApiUret = eski);
    return istekler;
  }

  /// Sunucunun döneceği tek canlı konum kaydı (sözleşmedeki alan adlarıyla).
  Map<String, dynamic> canliKayit({
    String userId = 'u-kurye',
    String ad = 'Ahmet Kurye',
    String rol = 'kurye',
    double lat = 36.8860,
    double lng = 30.7070,
    // Nullable: sunucu `accuracy_m`i null döndürebilir (cihaz doğruluğu bilmiyor).
    double? dogruluk = 12.5,
    int dakikaOnce = 0,
    bool taze = true,
  }) =>
      {
        'user_id': userId,
        'name': ad,
        'role': rol,
        'lat': lat,
        'lng': lng,
        'accuracy_m': dogruluk,
        'reported_at':
            DateTime.now().subtract(Duration(minutes: dakikaOnce)).toIso8601String(),
        'is_fresh': taze,
      };

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // A. KonumApi — sözleşmenin okunması
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  group('KonumApi', () {
    KonumApi api(http.Response Function(http.Request) yanit) => KonumApi(
          baseUrl: 'https://ornek.test/api/v1',
          token: 'tk',
          client: MockClient((i) async => yanit(i)),
        );

    /// Sözleşmeye uygun ASGARİ öğe; her test yalnız ilgilendiği alanı ezer.
    const Map<String, dynamic> kayit = {
      'user_id': 'u1',
      'name': 'Ahmet',
      'role': 'kurye',
      'lat': 36.9,
      'lng': 30.7,
    };

    test('kalp atışı gövdesi sözleşmedeki üç alandır', () async {
      Map<String, dynamic>? govde;
      await api((i) {
        govde = jsonDecode(i.body) as Map<String, dynamic>;
        expect(i.url.path, endsWith('/locations/heartbeat'));
        return http.Response('', 204);
      }).kalpAtisiGonder(lat: 40.1, lng: 29.0, dogrulukM: 12.5);

      expect(govde, {'lat': 40.1, 'lng': 29.0, 'accuracy_m': 12.5});
    });

    test('BOZUK öğe listeyi düşürmez, yalnız kendisi düşer', () async {
      // Sunucunun tek satırlık bir hatası, patronun haritasındaki BÜTÜN kuryeleri
      // kaybettirmemeli — sınırda doğrulama öğe bazındadır.
      final liste = await api((_) => http.Response(
            jsonEncode({
              'locations': [
                {'user_id': 'u1', 'name': 'Taze', 'role': 'kurye', 'lat': 36.9, 'lng': 30.7},
                {'name': 'Kimliksiz', 'lat': 36.9, 'lng': 30.7}, // user_id yok
                {'user_id': 'u2', 'name': 'Uzay', 'lat': 999.0, 'lng': 30.7}, // aralık dışı
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )).canliKonumlar();

      expect([for (final k in liste) k.userId], ['u1']);
      // `is_fresh` gelmediyse TAZE sayılır: alanı göndermeyen bir sunucu yüzünden bütün
      // pinleri soluk çizmek, çalışan bir özelliği bozukmuş gibi gösterirdi.
      expect(liste.single.taze, isTrue);
    });

    /// Tek öğelik canlı liste yanıtı — öğenin alanları çağırana bırakılır.
    Future<List<CanliKonum>> tekOge(Map<String, dynamic> oge) => api((_) => http.Response(
          jsonEncode({
            'locations': [oge]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )).canliKonumlar();

    test('accuracy_m null ise doğruluk BİLİNMİYOR kalır (0 değil)', () async {
      // Sunucu bu alanı nullable döner (cihaz doğruluğu bilmiyor). Null'u 0'a çevirmek
      // "±0 m" yani KUSURSUZ ÖLÇÜM iddiası olurdu — yokluğun söyleyebileceği en yanlış şey.
      final liste = await tekOge({...kayit, 'accuracy_m': null});
      expect(liste.single.dogrulukM, isNull);
    });

    test('accuracy_m sayı değilse öğe düşmez, yalnız doğruluk bilinmez', () async {
      // Ham `as num?` dönüşümü burada TypeError fırlatır; hata öğe döngüsünün dışına taşarak
      // BÜTÜN listeyi (ve haritadaki her pini) düşürürdü — oysa kural, yalnız bozuğun elenmesi.
      final liste = await tekOge({...kayit, 'accuracy_m': 'çok'});
      expect(liste, hasLength(1));
      expect(liste.single.dogrulukM, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // B. KonumBildirici — sessiz kalp atışı turu
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  group('KonumBildirici', () {
    /// Oturumlu ([token] verilirse) boş bir veritabanı.
    Future<AppDatabase> dbKur({String? token = 'test-token'}) async {
      final db = AppDatabase(NativeDatabase.memory());
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
          .write(SyncMetaCompanion(authToken: Value(token)));
      return db;
    }

    void konumSahtele(Future<CihazKonumu> Function() oku) {
      final eski = sessizKonumOku;
      sessizKonumOku = oku;
      addTearDown(() => sessizKonumOku = eski);
    }

    test('tur konumu okur ve kalp atışını gönderir', () async {
      konumSahtele(
          () async => const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12.5));
      final istekler = konumApisiniSahtele();
      final db = await dbKur();

      await KonumBildirici(db).tur();

      expect(istekler, hasLength(1));
      expect(istekler.single.yontem, 'POST');
      expect(istekler.single.yol, endsWith('/locations/heartbeat'));
      expect(istekler.single.govde, {'lat': 36.8841, 'lng': 30.7056, 'accuracy_m': 12.5});

      await db.close();
    });

    test('konum okunamazsa tur SESSİZCE atlanır — istek gitmez', () async {
      // İzin yok / GPS kapalı / zaman aşımı. Kullanıcıya gösterilecek bir şey YOK: bu özelliğin
      // onun başlattığı bir eylemi yok, arızasını ekranına taşımak gürültüden ibaret olurdu.
      konumSahtele(() async => throw const KonumHatasi('Sessiz tur: konum izni yok'));
      final istekler = konumApisiniSahtele();
      final db = await dbKur();

      await KonumBildirici(db).tur(); // fırlatMAmalı

      expect(istekler, isEmpty);
      await db.close();
    });

    test('sunucu hata dönerse tur yine SESSİZ biter (kuyruklanmaz)', () async {
      konumSahtele(
          () async => const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12.5));
      final istekler = konumApisiniSahtele(heartbeatKodu: 500);
      final db = await dbKur();

      await KonumBildirici(db).tur();

      // Denendi ve düştü; yeniden denenmez — geç bildirilen konum haritaya yalan söyler.
      expect(istekler, hasLength(1));
      await db.close();
    });

    test('OTURUM YOKSA konum bile okunmaz', () async {
      var okundu = false;
      konumSahtele(() async {
        okundu = true;
        return const CihazKonumu(lat: 36.8841, lng: 30.7056, dogrulukM: 12.5);
      });
      final istekler = konumApisiniSahtele();
      final db = await dbKur(token: null);

      await KonumBildirici(db).tur();

      expect(okundu, isFalse, reason: 'kimliksiz ölçüm gidecek bir yer bulamaz');
      expect(istekler, isEmpty);
      await db.close();
    });

    test('durdur() sayacı kapatır', () async {
      konumSahtele(() async => throw const KonumHatasi('yok'));
      konumApisiniSahtele();
      final db = await dbKur();

      final bildirici = KonumBildirici(db, aralik: const Duration(seconds: 30));
      bildirici.baslat();
      expect(bildirici.calisiyor, isTrue);
      bildirici.durdur();
      expect(bildirici.calisiyor, isFalse);

      await db.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // C. Harita katmanı — rol kapısı ve pin
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  group('Kurye katmanı', () {
    setUp(() {
      final eskiKaro = haritaKaroSaglayici;
      haritaKaroSaglayici = SahteKaro.new;
      addTearDown(() => haritaKaroSaglayici = eskiKaro);

      // Cihaz konumu alınamaz (eklentisiz ortamın gerçeği) — kurye katmanı ondan bağımsızdır.
      final eskiKonum = cihazKonumuOku;
      cihazKonumuOku = () async => throw const KonumHatasi('Konum alınamadı');
      addTearDown(() => cihazKonumuOku = eskiKonum);
    });

    /// Bir koordinatlı açık sipariş (harita ancak durak varken kurulur) + verilen rol/oturum.
    Future<AppDatabase> haritaDbKur({
      required String? rol,
      String? token = 'test-token',
      String kendiId = 'u-patron',
    }) async {
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(
        name: 'Ayşe Yılmaz',
        addresses: [
          AddressInput(
              addressText: 'Bahçe Sk. No: 1', lat: 36.8841, lng: 30.7056, isPrimary: true),
        ],
      );
      await OrderRepository(db).create(customerId: cid, lines: [
        LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1),
      ]);
      await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(SyncMetaCompanion(
        authToken: Value(token),
        userRole: Value(rol),
        userId: Value(kendiId),
      ));
      return db;
    }

    /// Haritayı kurar ve katmanın ilk turunu bekler (veri akışı → kamera → API turu).
    Future<void> haritayiAc(WidgetTester tester, AppDatabase db) async {
      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
      await akisiBekle(tester);
      // İKİNCİ TUR: pinler ancak harita ölçüsünü aldıktan sonra çizilir ve canlı liste isteği
      // ilk turun sonunda yola çıkar.
      await akisiBekle(tester, ms: 300);
    }

    testWidgets('PATRON rolünde kurye pini adıyla çizilir', (tester) async {
      genisYuzey(tester);
      final istekler = konumApisiniSahtele(liste: [canliKayit()]);
      late AppDatabase db;
      await tester.runAsync(() async => db = await haritaDbKur(rol: 'patron'));

      await haritayiAc(tester, db);

      expect(find.byType(KuryePini), findsOneWidget);
      expect(find.text('Ahmet Kurye'), findsOneWidget);
      expect(istekler.map((i) => i.yol), everyElement(endsWith('/locations/live')));

      await ekraniKapat(tester);
    });

    testWidgets('KURYE rolünde katman kurulmaz ve canlı liste HİÇ çağrılmaz', (tester) async {
      // Kapı gerçek olmalı: pini gizleyip isteği yine atmak, sunucudan başkalarının konumunu
      // çekip ekranda saklamak demektir.
      genisYuzey(tester);
      final istekler = konumApisiniSahtele(liste: [canliKayit()]);
      late AppDatabase db;
      await tester.runAsync(() async => db = await haritaDbKur(rol: 'kurye'));

      await haritayiAc(tester, db);

      expect(find.byType(KuryePini), findsNothing);
      expect(istekler, isEmpty);
      // Harita YİNE çalışır — kapı yalnız kurye katmanını kapatır.
      expect(find.byType(DurakPini), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('OTURUM YOKSA (rol patron olsa da) istek atılmaz', (tester) async {
      genisYuzey(tester);
      final istekler = konumApisiniSahtele(liste: [canliKayit()]);
      late AppDatabase db;
      await tester.runAsync(
          () async => db = await haritaDbKur(rol: 'patron', token: null));

      await haritayiAc(tester, db);

      expect(find.byType(KuryePini), findsNothing);
      expect(istekler, isEmpty);

      await ekraniKapat(tester);
    });

    testWidgets('KENDİ konumun kurye katmanında çizilmez', (tester) async {
      // "Konumum" düğmesi zaten cihazın kendi noktasını taze okuyor; aynı kişiyi iki işaretle
      // göstermek patrona kendini kurye sandırırdı.
      genisYuzey(tester);
      konumApisiniSahtele(liste: [
        canliKayit(userId: 'u-patron', ad: 'Kendim', rol: 'patron'),
        canliKayit(userId: 'u-kurye', ad: 'Ahmet Kurye'),
      ]);
      late AppDatabase db;
      await tester.runAsync(() async => db = await haritaDbKur(rol: 'patron'));

      await haritayiAc(tester, db);

      expect(find.byType(KuryePini), findsOneWidget);
      expect(find.text('Kendim'), findsNothing);
      expect(find.text('Ahmet Kurye'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('BAYAT konum soluk gri çizilir ve "X dk önce" yazar', (tester) async {
      // Taze pinle aynı görünseydi patron 7 dakika önceki bir noktaya bakıp kuryenin orada
      // olduğunu sanırdı; pini gizlemek ise kuryenin hiç çalışmadığını söylerdi.
      genisYuzey(tester);
      konumApisiniSahtele(liste: [canliKayit(dakikaOnce: 7, taze: false)]);
      late AppDatabase db;
      await tester.runAsync(() async => db = await haritaDbKur(rol: 'patron'));

      await haritayiAc(tester, db);

      expect(find.text('Ahmet Kurye'), findsOneWidget);
      expect(find.text('7 dk önce'), findsOneWidget);

      final daire = tester.widget<Container>(
        find.descendant(of: find.byType(KuryePini), matching: find.byType(Container)),
      );
      expect((daire.decoration! as BoxDecoration).color, SipTokens.acik.muted,
          reason: 'bayat pin vurgu moruyla çizilmez');

      await ekraniKapat(tester);
    });

    testWidgets('TAZE pin vurgu rengiyle çizilir ve süre etiketi taşımaz', (tester) async {
      genisYuzey(tester);
      konumApisiniSahtele(liste: [canliKayit(dakikaOnce: 2)]);
      late AppDatabase db;
      await tester.runAsync(() async => db = await haritaDbKur(rol: 'patron'));

      await haritayiAc(tester, db);

      final daire = tester.widget<Container>(
        find.descendant(of: find.byType(KuryePini), matching: find.byType(Container)),
      );
      expect((daire.decoration! as BoxDecoration).color, SipTokens.acik.accent);
      // Süre yalnız BAYAT pinde yazar: taze bir pinde her pinin altına saat asmak haritayı
      // okunmaz hâle getirirdi.
      expect(find.text('2 dk önce'), findsNothing);

      await ekraniKapat(tester);
    });

    testWidgets('pine dokununca ÖZET açılır (rol · son görülme · doğruluk)', (tester) async {
      genisYuzey(tester);
      konumApisiniSahtele(liste: [canliKayit(dakikaOnce: 2, dogruluk: 12.5)]);
      late AppDatabase db;
      await tester.runAsync(() async => db = await haritaDbKur(rol: 'patron'));

      await haritayiAc(tester, db);
      expect(find.byType(KuryeOzetGovde), findsNothing);

      await tester.tap(find.byType(KuryePini));
      await akisiBekle(tester, ms: 400);

      expect(find.byType(KuryeOzetGovde), findsOneWidget);
      expect(find.text('Kurye'), findsOneWidget);
      expect(find.text('2 dk önce'), findsOneWidget);
      // "±800 m" bir konum değil bir bölgedir; gizlenirse pine olduğundan fazla güvenilir.
      expect(find.text('±13 m'), findsOneWidget);

      await ekraniKapat(tester);
    });

    testWidgets('doğruluk bildirilmemişse özet "±0 m" DEMEZ', (tester) async {
      genisYuzey(tester);
      konumApisiniSahtele(liste: [canliKayit(dakikaOnce: 2, dogruluk: null)]);
      late AppDatabase db;
      await tester.runAsync(() async => db = await haritaDbKur(rol: 'patron'));

      await haritayiAc(tester, db);
      await tester.tap(find.byType(KuryePini));
      await akisiBekle(tester, ms: 400);

      expect(find.byType(KuryeOzetGovde), findsOneWidget);
      expect(find.text('±0 m'), findsNothing,
          reason: 'sıfır hata payı EN KESİN ölçüm demektir; bilinmeyen için yazılamaz');
      expect(find.text('bilinmiyor'), findsOneWidget);

      await ekraniKapat(tester);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // D. Süre metni — saf fonksiyon
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  group('kuryeSonGorulme', () {
    final simdi = DateTime(2026, 7, 30, 12, 0);
    String metin(Duration once) =>
        kuryeSonGorulme(simdi.subtract(once).toIso8601String(), simdi: simdi);

    test('dakika altı "az önce", sonrası dakika · saat · gün', () {
      expect(metin(const Duration(seconds: 20)), 'az önce');
      expect(metin(const Duration(minutes: 7)), '7 dk önce');
      expect(metin(const Duration(minutes: 59)), '59 dk önce');
      expect(metin(const Duration(hours: 3, minutes: 12)), '3 sa önce');
      expect(metin(const Duration(days: 2)), '2 gün önce');
    });

    test('İLERİ tarihli damga "az önce" sayılır', () {
      // Cihaz saati sunucudan ileri olabilir; "−4 dk önce" yazmak veriye güveni sarsar.
      expect(metin(const Duration(minutes: -4)), 'az önce');
    });

    test('çözülemeyen damga boş metin döner (etiket hiç çizilmez)', () {
      expect(kuryeSonGorulme(''), '');
    });

    test('sunucunun ISO8601 UTC OFSETLİ damgası doğru okunur', () {
      // Sözleşmenin gerçek biçimi budur: sunucu her zaman `...+00:00` yollar (CanliKonum::toArray
      // → `->utc()->toIso8601String()`), oysa bu dosyanın geri kalanı ofsetsiz YEREL damga
      // üretiyor. Ofsetin yok sayıldığı bir ayrıştırma hatası, testlerin görmediği yerde
      // makinenin saat diliminden kaynaklanan sabit bir kayma üretirdi.
      expect(
        kuryeSonGorulme('2026-07-30T11:53:00+00:00', simdi: DateTime.utc(2026, 7, 30, 12)),
        '7 dk önce',
      );
    });
  });
}
