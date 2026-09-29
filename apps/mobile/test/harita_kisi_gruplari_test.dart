// HARİTADA KİŞİ GRUPLARI + KİŞİ KİŞİ OTO SIRALAMA (kullanıcı kararı 2026-09-29).
//
//   "Kuryeler sadece kendi siparişlerini haritada görebilir! Patron hem kendi siparişlerini hem
//    de kuryelerin siparişlerini görebilir fakat ayrıştırılmış şekilde!"
//   "Patron oto sıralama yaptığında hem kendi siparişlerini hem de kuryelerin konumlarına göre
//    onların siparişlerini sıralayabilmeli."
//
// Kilitlenenler: grup üyeliği (kurye yalnız kendisi; "Siz" = kendi + atanmamış), renk kişiye
// bağlı, numara grup içinde, kurye rotası kuryenin TAZE konumundan, her rota ayrı istek ve ayrı
// sıra bandı, şeritten seçilen grup hem haritayı hem sıralamayı daraltır.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/konum/cihaz_konumu.dart';
import 'package:sipario/screens/orders/harita_gruplari.dart';
import 'package:sipario/screens/orders/harita_icerigi.dart';
import 'package:sipario/screens/orders/harita_sorgulari.dart';
import 'package:sipario/screens/orders/order_queries.dart' show AdresBilgi;
import 'package:sipario/screens/orders/oto_siralama.dart';
import 'package:sipario/screens/orders/siparis_gruplari.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/sync/konum_api.dart';
import 'package:sipario/sync/route_api.dart';

import 'support/harita_ortami.dart';
import 'support/siparis_yardimci.dart';

/// Bir bayi: patron (oturum), iki kurye, atanmış/atanmamış siparişler; sahte rota ve konum
/// sunucusu. Durum ve davranış tek nesnede.
class _BayiOrtami {
  late final AppDatabase db = AppDatabase(NativeDatabase.memory());

  /// Rota sunucusuna giden gövdeler, sırasıyla.
  final rotaIstekleri = <Map<String, dynamic>>[];

  /// Sunucunun her istekte döneceği kalan hak (sırayla azalır).
  int hak = 10;

  Future<void> kur({String rol = 'patron', String kendiId = 'u-patron'}) async {
    for (final (id, ad, r) in [
      ('u-patron', 'Patron', 'patron'),
      ('u-ali', 'Ali', 'kurye'),
      ('u-veli', 'Veli', 'kurye'),
    ]) {
      await db.into(db.users).insert(UsersCompanion.insert(id: id, name: ad, role: r, status: 'active'));
    }
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(SyncMetaCompanion(
      authToken: const Value('t'),
      userId: Value(kendiId),
      userRole: Value(rol),
      routeCredits: const Value(10),
      routeCreditsMonthly: const Value(10),
    ));
  }

  /// Koordinatlı açık sipariş; [atanan] null = atanmamış.
  Future<String> siparis(String ad, {String? atanan, double lat = 36.88, double lng = 30.70}) async {
    final id = await siparisEkle(db, ad: ad, lat: lat, lng: lng);
    if (atanan != null) {
      await (db.update(db.orders)..where((t) => t.id.equals(id)))
          .write(OrdersCompanion(assignedUserId: Value(atanan)));
    }
    return id;
  }

  /// Rota ve canlı konum dikişlerini sahteler. Rota sunucusu gelen sırayı TERS çevirir (sıranın
  /// gerçekten yazıldığı görülsün diye).
  void sunucuyuSahtele({List<Map<String, dynamic>> konumlar = const []}) {
    final eskiRota = rotaApiUret;
    rotaApiUret = (baseUrl, token) => RouteApi(
          baseUrl: baseUrl,
          token: token,
          client: MockClient((istek) async {
            final govde = jsonDecode(istek.body) as Map<String, dynamic>;
            rotaIstekleri.add(govde);
            hak--;
            return http.Response(
              jsonEncode({
                'order': (govde['order_ids'] as List).reversed.toList(),
                'without_location': 0,
                'route_credits': hak,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
    final eskiKonum = konumApiUret;
    konumApiUret = (baseUrl, token) => KonumApi(
          baseUrl: baseUrl,
          token: token,
          client: MockClient((_) async => http.Response(
                jsonEncode({'locations': konumlar}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              )),
        );
    final eskiCihaz = cihazKonumuOku;
    cihazKonumuOku = () async => const CihazKonumu(lat: 36.9, lng: 30.6, dogrulukM: 10);
    addTearDown(() {
      rotaApiUret = eskiRota;
      konumApiUret = eskiKonum;
      cihazKonumuOku = eskiCihaz;
    });
  }

  static Map<String, dynamic> canli(String id, String ad,
          {double lat = 36.95, double lng = 30.55, bool taze = true}) =>
      {
        'user_id': id,
        'name': ad,
        'role': 'kurye',
        'lat': lat,
        'lng': lng,
        'reported_at': DateTime.now().toIso8601String(),
        'is_fresh': taze,
      };

  Future<int?> sira(String id) async =>
      (await (db.select(db.orders)..where((t) => t.id.equals(id))).getSingle()).sortIndex;

  Future<HaritaVerisi> harita() => watchHaritaDuraklari(db).first;
}

HaritaDuragi _durak(String id, {String? atanan, double lat = 36.88}) => HaritaDuragi(
      orderId: id,
      baslik: 'Müşteri $id',
      adres: AdresBilgi(metin: 'Sokak', lat: lat, lng: 30.7),
      tutarKurus: 100,
      occurredAt: '2026-09-29T10:00:00Z',
      atananId: atanan,
    );

void main() {
  group('siparisleriGrupla — saf', () {
    List<SiparisGrubu<HaritaDuragi>> grupla(List<HaritaDuragi> d, {bool kurye = false}) =>
        siparisleriGrupla(
          d,
          atanan: (x) => x.atananId,
          kendiId: 'u-ben',
          adlar: const {'u-ali': 'Ali', 'u-veli': 'Veli', 'u-ben': 'Ben'},
          kuryeKipi: kurye,
        );

    test('kurye yalnız KENDİSİNE ATANMIŞ siparişleri görür; atanmamış da gelmez', () {
      final g = grupla([
        _durak('a', atanan: 'u-ben'),
        _durak('b'),
        _durak('c', atanan: 'u-ali'),
      ], kurye: true);
      expect(g, hasLength(1));
      expect(g.single.ogeler.map((d) => d.orderId), ['a']);
    });

    test('patronda "Siz" = kendi + atanmamış, önce gelir; kuryeler adına göre', () {
      final g = grupla([
        _durak('v', atanan: 'u-veli'),
        _durak('b'),
        _durak('a', atanan: 'u-ali'),
        _durak('k', atanan: 'u-ben'),
      ]);
      expect(g.map((x) => x.ad), ['Siz', 'Ali', 'Veli']);
      expect(g.first.kendi, isTrue);
      expect(g.first.ogeler.map((d) => d.orderId), ['b', 'k'], reason: 'verilen sıra korunur');
    });

    test('kişinin rengi grup sayısından bağımsız, kişiye bağlıdır', () {
      const sira = ['u-ali', 'u-veli'];
      expect(kisiRengi('u-veli', kisiSirasi: sira), kGrupRenkleri[1]);
      expect(kisiRengi('u-veli', kisiSirasi: sira), kisiRengi('u-veli', kisiSirasi: sira));
      expect(kisiRengi('u-ali', kisiSirasi: sira), isNot(kisiRengi('u-veli', kisiSirasi: sira)));
    });
  });

  group('grupluIcerik — saf', () {
    const renkler = {'kendi': Color(0xFF111111), 'u-ali': Color(0xFF222222)};
    final gruplar = [
      SiparisGrubu(kullaniciId: 'u-ben', ad: 'Siz', kendi: true,
          ogeler: [_durak('k1'), _durak('k2', lat: 36.89)]),
      SiparisGrubu(kullaniciId: 'u-ali', ad: 'Ali', kendi: false,
          ogeler: [_durak('a1', atanan: 'u-ali'), _durak('a2', atanan: 'u-ali', lat: 36.87)]),
    ];
    const ali = KuryeIsareti(
        id: 'u-ali', nokta: HaritaNoktasi(36.86, 30.69), ad: 'Ali', taze: true);

    test('her kişinin rotası 1\'den başlar ve kendi renginde', () {
      final i = grupluIcerik(gruplar: gruplar, renkler: renkler, kuryeler: const [ali]);
      expect(i.duraklar.map((d) => '${d.grup}:${d.no}'),
          ['kendi:1', 'kendi:2', 'u-ali:1', 'u-ali:2']);
      expect(i.duraklar.last.renk, renkler['u-ali']);
      expect(i.cokluRota, isTrue);
      expect(i.rotaNoktalari, isEmpty, reason: 'Ali ile Siz tek çizgiyle birleştirilmez');
    });

    test('kurye rotası kuryenin TAZE konumundan başlar, bayat konum kullanılmaz', () {
      final taze = grupluIcerik(gruplar: gruplar, renkler: renkler, kuryeler: const [ali]);
      expect(taze.rotalar[1].noktalar.first, const HaritaNoktasi(36.86, 30.69));

      const bayat = KuryeIsareti(
          id: 'u-ali', nokta: HaritaNoktasi(36.86, 30.69), ad: 'Ali', taze: false);
      final eski = grupluIcerik(gruplar: gruplar, renkler: renkler, kuryeler: const [bayat]);
      expect(eski.rotalar[1].noktalar, hasLength(2), reason: 'yalnız duraklar');
    });

    test('tek kuryeye odaklanınca rota onun renginde ve onun konumundan', () {
      final i = grupluIcerik(gruplar: [gruplar[1]], renkler: renkler, kuryeler: const [ali]);
      expect(i.cokluRota, isFalse);
      expect(i.rotaRengi, renkler['u-ali']);
      expect(i.rotaBaslangici, const HaritaNoktasi(36.86, 30.69));
    });
  });

  group('otoSonucMetni — saf', () {
    test('tek rota eski cümleyi korur', () {
      expect(otoSonucMetni(rotaSayisi: 1, kalanHak: 33), 'Rota sıralandı, 33 hakkınız kaldı.');
    });

    test('çok rota, konumsuz başlayan kurye ve yarım kalan söylenir', () {
      final m = otoSonucMetni(
        rotaSayisi: 2,
        kalanHak: 0,
        konumsuzBaslayan: ['Ali'],
        yarimKalan: ['Veli'],
      );
      expect(m, contains('2 rota sıralandı, 0 hakkınız kaldı.'));
      expect(m, contains('ilk duraktan başlanan rota: Ali'));
      expect(m, contains('Sıralanamayan rota: Veli'));
    });
  });

  group('Harita verisi — kapsam', () {
    late _BayiOrtami o;
    setUp(() => o = _BayiOrtami());

    test('kurye haritası yalnız kendi siparişlerini ve kendi konumsuzlarını sayar', () async {
      await o.kur(rol: 'kurye', kendiId: 'u-ali');
      await o.siparis('Ali 1', atanan: 'u-ali');
      await o.siparis('Veli 1', atanan: 'u-veli');
      await o.siparis('Atanmamış');
      final h = await o.harita();
      expect(h.duraklar.map((d) => d.baslik), ['Ali 1']);
      expect(h.gruplu, isFalse);
    });

    test('patron haritası kişi kişi gruplu', () async {
      await o.kur();
      await o.siparis('Benim', atanan: 'u-patron');
      await o.siparis('Atanmamış');
      await o.siparis('Ali 1', atanan: 'u-ali');
      await o.siparis('Veli 1', atanan: 'u-veli');
      final h = await o.harita();
      expect(h.gruplar.map((g) => '${g.ad}:${g.ogeler.length}'), ['Siz:2', 'Ali:1', 'Veli:1']);
      expect(h.gruplu, isTrue);
    });
  });

  group('Oto sıralama — kişi kişi rota', () {
    late _BayiOrtami o;
    setUp(() => o = _BayiOrtami());

    test('patron: her grup AYRI istek; kurye rotası kuryenin konumundan; sıra bantları ayrı',
        () async {
      await o.kur();
      final s1 = await o.siparis('Benim 1');
      final s2 = await o.siparis('Benim 2', atanan: 'u-patron');
      final a1 = await o.siparis('Ali 1', atanan: 'u-ali');
      final a2 = await o.siparis('Ali 2', atanan: 'u-ali');
      await o.siparis('Veli tek', atanan: 'u-veli');
      o.sunucuyuSahtele(konumlar: [_BayiOrtami.canli('u-ali', 'Ali', lat: 36.95, lng: 30.55)]);

      final sonuc = await otoSiralaKos(o.db);

      expect(sonuc.basarili, isTrue);
      expect(o.rotaIstekleri, hasLength(2), reason: 'Veli\'nin tek siparişi hak harcamaz');
      expect((o.rotaIstekleri[0]['order_ids'] as List).toSet(), {s1, s2});
      expect(o.rotaIstekleri[0]['start'], {'lat': 36.9, 'lng': 30.6},
          reason: 'Siz grubu telefonun konumundan');
      expect((o.rotaIstekleri[1]['order_ids'] as List).toSet(), {a1, a2});
      expect(o.rotaIstekleri[1]['start'], {'lat': 36.95, 'lng': 30.55},
          reason: 'kurye rotası kuryenin canlı konumundan');
      // Ali bandı Siz bandından sonra gelir; Ali'nin kendi sırası sunucunun sırasıdır (ters).
      final gonderilen = (o.rotaIstekleri[1]['order_ids'] as List).cast<String>();
      final ilk = await o.sira(gonderilen.first), son = await o.sira(gonderilen.last);
      expect(ilk! >= kGrupSiraBandi && son! >= kGrupSiraBandi, isTrue,
          reason: 'Ali\'nin sırası kendi bandında');
      expect(son! < ilk, isTrue, reason: 'sunucunun döndüğü (ters) sıra yazılır');
      expect((await o.sira(s1))! < kGrupSiraBandi, isTrue);
      expect(sonuc.mesaj, startsWith('2 rota sıralandı'));
    });

    test('kuryenin konumu bayatsa rotası ilk duraktan başlar ve söylenir', () async {
      await o.kur();
      await o.siparis('Ali 1', atanan: 'u-ali');
      await o.siparis('Ali 2', atanan: 'u-ali');
      o.sunucuyuSahtele(konumlar: [_BayiOrtami.canli('u-ali', 'Ali', taze: false)]);

      final sonuc = await otoSiralaKos(o.db);

      expect(o.rotaIstekleri.single.containsKey('start'), isFalse);
      expect(sonuc.mesaj, contains('ilk duraktan başlanan rota: Ali'));
    });

    test('şeritte seçili grup varsa YALNIZ o grup sıralanır', () async {
      await o.kur();
      await o.siparis('Benim 1');
      await o.siparis('Benim 2');
      final a1 = await o.siparis('Ali 1', atanan: 'u-ali');
      final a2 = await o.siparis('Ali 2', atanan: 'u-ali');
      o.sunucuyuSahtele();

      await otoSiralaKos(o.db, grup: 'u-ali');

      expect(o.rotaIstekleri, hasLength(1));
      expect((o.rotaIstekleri.single['order_ids'] as List).toSet(), {a1, a2});
    });

    test('kurye yalnız KENDİ siparişlerini sıralar', () async {
      await o.kur(rol: 'kurye', kendiId: 'u-ali');
      final a1 = await o.siparis('Ali 1', atanan: 'u-ali');
      final a2 = await o.siparis('Ali 2', atanan: 'u-ali');
      await o.siparis('Veli 1', atanan: 'u-veli');
      await o.siparis('Veli 2', atanan: 'u-veli');
      o.sunucuyuSahtele();

      await otoSiralaKos(o.db);

      expect(o.rotaIstekleri, hasLength(1));
      expect((o.rotaIstekleri.single['order_ids'] as List).toSet(), {a1, a2});
    });

    test('hak ortada biterse kalan rotalar sıralanmaz ve adları söylenir', () async {
      await o.kur();
      await o.siparis('Benim 1');
      await o.siparis('Benim 2');
      await o.siparis('Ali 1', atanan: 'u-ali');
      await o.siparis('Ali 2', atanan: 'u-ali');
      o
        ..hak = 1
        ..sunucuyuSahtele();

      final sonuc = await otoSiralaKos(o.db);

      expect(o.rotaIstekleri, hasLength(1));
      expect(sonuc.mesaj, contains('Sıralanamayan rota: Ali'));
    });
  });

  group('Harita ekranı — kişi şeridi', () {
    late SahteHaritaTuvali harita;
    setUp(() => harita = haritaDikisleriniSahtele());

    testWidgets('patron kişi çiplerini görür; çipe dokununca yalnız o kişi kalır',
        (tester) async {
      genisYuzey(tester);
      final o = _BayiOrtami();
      await tester.runAsync(() async {
        await o.kur();
        await o.siparis('Benim 1');
        await o.siparis('Ali 1', atanan: 'u-ali');
        await o.siparis('Ali 2', atanan: 'u-ali');
      });

      await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: o.db, writable: true)));
      await akisiBekle(tester);

      expect(find.text('3 durak, 2 kişi'), findsOneWidget);
      expect(find.byKey(const ValueKey('harita-grup-kendi')), findsOneWidget);
      expect(harita.grupDuragi('kendi', 1), findsOneWidget);
      expect(harita.grupDuragi('u-ali', 2), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('harita-grup-u-ali')));
      await akisiBekle(tester);

      expect(harita.duraklar, findsNWidgets(2), reason: 'yalnız Ali\'nin durakları');
      expect(harita.icerik.rotaRengi, isNotNull, reason: 'Ali\'nin rengiyle tek rota');

      await ekraniKapat(tester);
    });
  });
}
