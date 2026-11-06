// HARİTA YOL ÇİZGİSİ — ekran ↔ sunucu (kullanıcı isteği 2026-09-29: "konumlar arası yolu
// kuşbakışı çiziyor, yollardan çizmeli").
//
// Sınananlar: çizgi durakların GÖRÜNEN sırasıyla istenir ve haritaya gider; sunucunun durakları
// pinlerle örtüşmezse (senkronlanmamış konum) çizgi KULLANILMAZ; servis kapalıyken ve oturum
// yokken harita kuş uçuşu çizgiyle çalışmaya devam eder; aynı dizi ikinci kez İSTENMEZ.
//
// Testler ağa ve platform görünümüne uzanmaz: `rotaCizgisiApiUret` ve `haritaTuvaliUret`
// dikişleri sahtelenir ve tearDown'da geri alınır.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/orders/harita_icerigi.dart';
import 'package:sipario/screens/orders/harita_sorgulari.dart';
import 'package:sipario/screens/orders/harita_yol_cizgisi.dart';
import 'package:sipario/screens/orders/order_musteri_sorgulari.dart';
import 'package:sipario/screens/orders/siparis_harita.dart';
import 'package:sipario/sync/rota_cizgisi_api.dart';

import 'support/harita_ortami.dart';
import 'support/siparis_yardimci.dart';

/// Sahte yol çizgisi sunucusu — dikişi takar, gelen istekleri kaydeder.
class _YolSunucusu {
  _YolSunucusu(this.yanit) {
    final eski = rotaCizgisiApiUret;
    rotaCizgisiApiUret = (baseUrl, token) => RotaCizgisiApi(
          baseUrl: baseUrl,
          token: token,
          client: MockClient((istek) async {
            istekler.add(jsonDecode(istek.body) as Map<String, dynamic>);
            return yanit();
          }),
        );
    addTearDown(() => rotaCizgisiApiUret = eski);
  }

  http.Response Function() yanit;
  final List<Map<String, dynamic>> istekler = [];

  static http.Response cizgi(List<List<double>> noktalar, List<List<double>> duraklar) =>
      http.Response(jsonEncode({'noktalar': noktalar, 'duraklar': duraklar}), 200);
}

void main() {
  late SahteHaritaTuvali harita;
  setUp(() {
    harita = haritaDikisleriniSahtele();
    YolCizgisiKatmani.bellegiTemizle();
  });

  const ayse = [36.8841, 30.7056];
  const mehmet = [36.9200, 30.7600];
  const yol = [
    [36.8841, 30.7056],
    [36.9000, 30.7300],
    [36.9200, 30.7600],
  ];

  /// İki koordinatlı açık sipariş (sıra: Ayşe, Mehmet) + [oturum] varsa token.
  Future<(AppDatabase, List<String>)> kur(WidgetTester tester, {bool oturum = true}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final idler = <String>[];
    await tester.runAsync(() async {
      idler.add(await siparisEkle(db, ad: 'Ayşe Yılmaz', lat: ayse[0], lng: ayse[1], sira: 0));
      idler.add(await siparisEkle(db, ad: 'Mehmet Kaya', lat: mehmet[0], lng: mehmet[1], sira: 10));
      if (oturum) {
        await (db.update(db.syncMeta)..where((t) => t.id.equals(1)))
            .write(const SyncMetaCompanion(authToken: Value('test-token')));
      }
    });
    return (db, idler);
  }

  Future<void> ac(WidgetTester tester, AppDatabase db) async {
    genisYuzey(tester);
    await tester.pumpWidget(sipKabuk(SiparisHaritaEkrani(db: db, writable: true)));
    await akisiBekle(tester);
    // Çizgi isteği gerçek zamanlı (MockClient) — bir tur daha beklenir.
    await akisiBekle(tester, ms: 200);
  }

  testWidgets('çizgi GÖRÜNEN sırayla istenir ve haritaya gider', (tester) async {
    final sunucu = _YolSunucusu(() => _YolSunucusu.cizgi(yol, [ayse, mehmet]));
    final (db, idler) = await kur(tester);

    await ac(tester, db);

    expect(sunucu.istekler.single, {'order_ids': idler});
    expect(harita.icerik.yolVar, isTrue);
    expect(harita.icerik.yolNoktalari, hasLength(3));
    expect(harita.icerik.yolNoktalari[1], const HaritaNoktasi(36.9, 30.73));
    // Cihaz konumu yok → kesikli çizgiye gerek kalmaz.
    expect(harita.icerik.rotaNoktalari, isEmpty);

    await ekraniKapat(tester);
  });

  testWidgets('sunucunun durağı pinden SAPIYORSA çizgi kullanılmaz (senkronlanmamış konum)',
      (tester) async {
    // Sunucu Mehmet'i 2 km öteden biliyor: çizgi yanlış kapıya giderdi.
    _YolSunucusu(() => _YolSunucusu.cizgi(yol, [
          ayse,
          [36.9380, 30.7600],
        ]));
    final (db, _) = await kur(tester);

    await ac(tester, db);

    expect(harita.icerik.yolVar, isFalse);
    // Harita kuş uçuşu kesikli çizgiyle çalışmaya devam eder.
    expect(harita.icerik.rotaNoktalari, hasLength(2));

    await ekraniKapat(tester);
  });

  testWidgets('sunucu durak SAYISI tutmazsa çizgi kullanılmaz', (tester) async {
    // Bir durağın konumu sunucuya henüz ulaşmamış: sunucu tek durak biliyor.
    _YolSunucusu(() => _YolSunucusu.cizgi(yol, [ayse]));
    final (db, _) = await kur(tester);

    await ac(tester, db);

    expect(harita.icerik.yolVar, isFalse);

    await ekraniKapat(tester);
  });

  testWidgets('servis kapalıysa (503) harita kuş uçuşu çizgiyle çalışır', (tester) async {
    _YolSunucusu(() => http.Response('{"message":"Yol çizgisi bu kurulumda tanımlı değil."}', 503));
    final (db, _) = await kur(tester);

    await ac(tester, db);

    expect(harita.icerik.yolVar, isFalse);
    expect(harita.icerik.rotaNoktalari, hasLength(2));
    expect(harita.duraklar, findsNWidgets(2));

    await ekraniKapat(tester);
  });

  testWidgets('oturum YOKSA istek hiç atılmaz', (tester) async {
    final sunucu = _YolSunucusu(() => _YolSunucusu.cizgi(yol, [ayse, mehmet]));
    final (db, _) = await kur(tester, oturum: false);

    await ac(tester, db);

    expect(sunucu.istekler, isEmpty);
    expect(harita.icerik.yolVar, isFalse);

    await ekraniKapat(tester);
  });

  testWidgets('harita yeniden açılınca çizgi bellekten gelir — ikinci istek YOK', (tester) async {
    final sunucu = _YolSunucusu(() => _YolSunucusu.cizgi(yol, [ayse, mehmet]));
    final (db, _) = await kur(tester);

    await ac(tester, db);
    await ekraniKapat(tester);
    await ac(tester, db);

    expect(sunucu.istekler, hasLength(1));
    expect(harita.icerik.yolVar, isTrue);

    await ekraniKapat(tester);
  });

  test('örtüşme kuralı: 100 m içi kabul, fazlası ret, sayı farkı ret', () {
    HaritaDuragi durak(String id, double lat, double lng) => HaritaDuragi(
          orderId: id,
          baslik: id,
          adres: AdresBilgi(metin: '$id sokağı', lat: lat, lng: lng),
          tutarKurus: 0,
          occurredAt: '2026-09-29T10:00:00Z',
        );
    final pinler = [durak('a', 36.8841, 30.7056), durak('b', 36.92, 30.76)];
    expect(
      YolCizgisiKatmani.ortusur(pinler, const [
        HaritaNoktasi(36.8845, 30.7056), // ~45 m
        HaritaNoktasi(36.92, 30.76),
      ]),
      isTrue,
    );
    expect(
      YolCizgisiKatmani.ortusur(pinler, const [
        HaritaNoktasi(36.8861, 30.7056), // ~220 m
        HaritaNoktasi(36.92, 30.76),
      ]),
      isFalse,
    );
    expect(YolCizgisiKatmani.ortusur(pinler, const [HaritaNoktasi(36.8841, 30.7056)]), isFalse);
  });
}
