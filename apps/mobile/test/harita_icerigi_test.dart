// HARİTA İÇERİĞİ — motora giden GeoJSON'un ve kadrajın saf birim testleri (2026-09-28).
//
// Yerel harita widget testinde çizilemez; pinlerin numarası, çizim önceliği, rota çizgisinin
// sırası ve seçili durak ancak motora giden veriden sınanabilir. Bir hata burada sessizdir:
// ters koordinat pini okyanusa atar, yanlış öncelik sıradaki durağı başka pinin altına gömer.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/orders/harita_icerigi.dart';
import 'package:sipario/screens/orders/harita_kurye_katmani.dart';
import 'package:sipario/sync/konum_api.dart';

/// Üç duraklı örnek rota + isteğe bağlı cihaz/seçim. Fikstür sınıfı: testler aynı rotayı
/// farklı açılardan okur.
class _Rota {
  _Rota({this.cihaz, this.secili});

  final HaritaNoktasi? cihaz;
  final String? secili;

  static const a = HaritaNoktasi(40.1950, 29.0600);
  static const b = HaritaNoktasi(40.2100, 29.0200);
  static const c = HaritaNoktasi(40.1800, 29.1000);

  late final HaritaIcerigi icerik = HaritaIcerigi(
    duraklar: const [
      DurakIsareti(id: 's1', no: 1, nokta: a, ad: 'Ayşe'),
      DurakIsareti(id: 's2', no: 2, nokta: b, ad: 'Mehmet'),
      DurakIsareti(id: 's3', no: 3, nokta: c, ad: 'Şükrü'),
    ],
    cihaz: cihaz,
    seciliDurakId: secili,
  );

  List<Map<String, dynamic>> get ozellikler =>
      (icerik.duraklarGeoJson['features'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> ozellik(String id) =>
      ozellikler.singleWhere((f) => f['id'] == 'd:$id');
}

void main() {
  group('durak GeoJSON', () {
    test('koordinat sırası [boylam, enlem] — ters yazılsa pin başka yere düşer', () {
      final f = _Rota().ozellik('s1');
      expect(f['geometry'], {
        'type': 'Point',
        'coordinates': [29.0600, 40.1950],
      });
    });

    test('kimlik ÜST DÜZEYDE ve önekli — dokunuş yalnız buradan geri gelir', () {
      final ids = [for (final f in _Rota().ozellikler) f['id']];
      expect(ids, ['d:s1', 'd:s2', 'd:s3']);
    });

    test('numara ve ad özellik olarak taşınır', () {
      final p = _Rota().ozellik('s3')['properties'] as Map;
      expect(p['no'], 3);
      expect(p['ad'], 'Şükrü');
      expect(p['secili'], isFalse);
    });

    test('çizim önceliği: 1 numara EN ÜSTTE (üst üste binen pinlerde sıradaki durak görünür)',
        () {
      final r = _Rota();
      int sira(String id) => (r.ozellik(id)['properties'] as Map)['sira'] as int;
      expect(sira('s1'), greaterThan(sira('s2')));
      expect(sira('s2'), greaterThan(sira('s3')));
    });

    test('seçili durak HER ŞEYİN üstüne çıkar ve işaretlenir', () {
      final r = _Rota(secili: 's3');
      final p3 = r.ozellik('s3')['properties'] as Map;
      final p1 = r.ozellik('s1')['properties'] as Map;
      expect(p3['secili'], isTrue);
      expect(p1['secili'], isFalse);
      expect(p3['sira'] as int, greaterThan(p1['sira'] as int));
    });

    test('kopyala seçimi değiştirir, null ile TEMİZLER, verilmezse korur', () {
      final r = _Rota(secili: 's2').icerik;
      expect(r.kopyala(seciliDurakId: () => null).seciliDurakId, isNull);
      expect(r.kopyala(seciliDurakId: () => 's1').seciliDurakId, 's1');
      expect(r.kopyala().seciliDurakId, 's2');
    });
  });

  group('rota çizgisi', () {
    List<dynamic> koordinatlar(HaritaIcerigi i) {
      final ozellikler = i.rotaGeoJson['features'] as List;
      return (ozellikler.single as Map)['geometry']['coordinates'] as List;
    }

    test('durakları SIRAYLA bağlar', () {
      expect(koordinatlar(_Rota().icerik), [
        _Rota.a.geoJson,
        _Rota.b.geoJson,
        _Rota.c.geoJson,
      ]);
    });

    test('cihaz biliniyorsa çizgi ORADAN başlar (oto sıralama da oradan başlıyor)', () {
      const cihaz = HaritaNoktasi(40.2000, 29.0000);
      expect(koordinatlar(_Rota(cihaz: cihaz).icerik).first, cihaz.geoJson);
      expect(koordinatlar(_Rota(cihaz: cihaz).icerik), hasLength(4));
    });

    test('UZAKTAKİ cihaz rotanın başı DEĞİLDİR — çizgiye de kadraja da girmez', () {
      // Emülatörde görüldü: Kaliforniya'daki cihaz Bursa rotasına çizgi çekiyordu. Evdeki patron
      // ya da başka şehirdeki telefon için de aynısı: harita ülke ölçeğine uzaklaşırdı.
      const uzak = HaritaNoktasi(37.42, -122.08);
      final i = _Rota(cihaz: uzak).icerik;
      expect(i.rotaBaslangici, isNull);
      expect(koordinatlar(i), hasLength(3), reason: 'çizgi yalnız durakları bağlar');
      expect(i.kadraj!.kuzeyDogu!.lng, lessThan(30), reason: 'kadraj Bursa\'da kalır');
      // Nokta yine ÇİZİLİR — cihazın nerede olduğu gizlenmez.
      expect(i.cihazGeoJson['features'], hasLength(1));
    });

    test('30 km sınırı: sınırın içindeki cihaz rotanın başıdır', () {
      // _Rota.a'dan yaklaşık 20 km güney (0,18° enlem).
      const yakin = HaritaNoktasi(40.0150, 29.0600);
      expect(HaritaIcerigi.mesafeKm(yakin, _Rota.a), closeTo(20.0, 0.3));
      expect(_Rota(cihaz: yakin).icerik.rotaBaslangici, yakin);
      // ~44 km güney: dışarıda.
      const uzak = HaritaNoktasi(39.7950, 29.0600);
      expect(_Rota(cihaz: uzak).icerik.rotaBaslangici, isNull);
    });

    test('durak yokken cihaz tek başına kadrajdır', () {
      const i = HaritaIcerigi(cihaz: HaritaNoktasi(37.42, -122.08));
      expect(i.kadraj!.merkez, const HaritaNoktasi(37.42, -122.08));
    });

    test('tek nokta çizgi DEĞİLDİR — boş koleksiyon', () {
      const tek = HaritaIcerigi(duraklar: [
        DurakIsareti(id: 'x', no: 1, nokta: _Rota.a, ad: 'Tek'),
      ]);
      expect(tek.rotaGeoJson['features'], isEmpty);
    });

    test('tek durak + cihaz = iki nokta, çizgi VAR', () {
      const i = HaritaIcerigi(
        duraklar: [DurakIsareti(id: 'x', no: 1, nokta: _Rota.a, ad: 'Tek')],
        cihaz: _Rota.b,
      );
      expect(i.rotaGeoJson['features'], hasLength(1));
    });
  });

  group('kadraj', () {
    test('duraklar + cihaz kutuyu belirler', () {
      const cihaz = HaritaNoktasi(40.3000, 28.9000);
      final k = _Rota(cihaz: cihaz).icerik.kadraj!;
      expect(k.kutuMu, isTrue);
      expect(k.guneyBati, const HaritaNoktasi(40.1800, 28.9000));
      expect(k.kuzeyDogu, const HaritaNoktasi(40.3000, 29.1000));
    });

    test('kuryeler kadraja GİRMEZ — şehrin öbür ucundaki kurye rotayı okunmaz kılardı', () {
      final i = HaritaIcerigi(
        duraklar: const [DurakIsareti(id: 'x', no: 1, nokta: _Rota.a, ad: 'A')],
        kuryeler: const [
          KuryeIsareti(id: 'k', nokta: HaritaNoktasi(41.0, 30.0), ad: 'Uzak', taze: true),
        ],
      );
      final k = i.kadraj!;
      expect(k.kutuMu, isFalse);
      expect(k.merkez, _Rota.a);
    });

    test('tek nokta sıfır alanlı kutu değil, merkez + sokak ölçeği', () {
      final k = HaritaKadraji.noktalardan([_Rota.a]);
      expect(k.kutuMu, isFalse);
      expect(k.merkez, _Rota.a);
      expect(k.zoom, 16);
    });

    test('çok dar küme (aynı apartman) de merkez + zoom olur', () {
      final k = HaritaKadraji.noktalardan([
        const HaritaNoktasi(40.19500, 29.06000),
        const HaritaNoktasi(40.19550, 29.06040),
      ]);
      expect(k.kutuMu, isFalse);
      expect(k.orta.lat, closeTo(40.19525, 1e-9));
    });

    test('durak ve cihaz yoksa kadraj yok', () {
      expect(const HaritaIcerigi().kadraj, isNull);
      expect(() => HaritaKadraji.noktalardan(const []), throwsArgumentError);
    });
  });

  group('dokunuş çözümü', () {
    test('durak ve kurye önekleri çözülür', () {
      expect(HaritaDokunusu.coz('d:abc'), isA<DurakDokunusu>().having((d) => d.id, 'id', 'abc'));
      expect(HaritaDokunusu.coz('k:u1'), isA<KuryeDokunusu>().having((d) => d.id, 'id', 'u1'));
    });

    test('cihaz ve taban haritanın öğeleri dokunuş SAYILMAZ', () {
      // Cihaz bir durak değildir, özet açmaz; sokak adına dokunmak hiçbir şey yapmamalı.
      expect(HaritaDokunusu.coz('cihaz'), isNull);
      expect(HaritaDokunusu.coz('123456'), isNull);
      expect(HaritaDokunusu.coz(''), isNull);
    });
  });

  group('kurye işareti', () {
    CanliKonum konum({required bool taze, required DateTime zaman}) => CanliKonum(
          userId: 'u1',
          ad: 'Ahmet Kurye',
          rol: 'kurye',
          lat: 40.2,
          lng: 29.0,
          dogrulukM: 10,
          bildirilenIso: zaman.toUtc().toIso8601String(),
          taze: taze,
        );

    test('bayat konumun etiketi ad + ne kadar eski olduğu', () {
      final simdi = DateTime(2026, 9, 28, 12);
      final i = kuryeIsareti(
        konum(taze: false, zaman: simdi.subtract(const Duration(minutes: 7))),
        simdi: simdi,
      );
      expect(i.taze, isFalse);
      expect(i.etiket, 'Ahmet Kurye\n7 dk önce');
    });

    test('taze konumun etiketi yalnız ad — her pine saat asmak haritayı okunmaz kılar', () {
      final simdi = DateTime(2026, 9, 28, 12);
      final i = kuryeIsareti(
        konum(taze: true, zaman: simdi.subtract(const Duration(minutes: 2))),
        simdi: simdi,
      );
      expect(i.etiket, 'Ahmet Kurye');
    });

    test('GeoJSON kimliği önekli, taze bayrağı katmanın rengini seçer', () {
      const i = HaritaIcerigi(kuryeler: [
        KuryeIsareti(id: 'u9', nokta: _Rota.a, ad: 'Ali', taze: false, bayatlik: '3 sa önce'),
      ]);
      final f = (i.kuryelerGeoJson['features'] as List).single as Map;
      expect(f['id'], 'k:u9');
      expect(f['properties'], {'taze': false, 'etiket': 'Ali\n3 sa önce'});
    });
  });
}
