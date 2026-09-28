// HARİTA İÇERİĞİ — motora giden verinin ve kadrajın saf birim testleri (2026-09-28).
//
// Yerel harita widget testinde çizilemez; pinlerin çizim önceliği, rota çizgisinin sırası,
// seçili durak ve uzak cihaz kuralı ancak motora giden veriden sınanabilir. Bir hata burada
// sessizdir: yanlış öncelik sıradaki durağı başka pinin altına gömer, uzak cihaz haritayı ülke
// ölçeğine uzaklaştırır.

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

  static const s1 = DurakIsareti(id: 's1', no: 1, nokta: a, ad: 'Ayşe');
  static const s2 = DurakIsareti(id: 's2', no: 2, nokta: b, ad: 'Mehmet');
  static const s3 = DurakIsareti(id: 's3', no: 3, nokta: c, ad: 'Şükrü');

  late final HaritaIcerigi icerik = HaritaIcerigi(
    duraklar: const [s1, s2, s3],
    cihaz: cihaz,
    seciliDurakId: secili,
  );
}

void main() {
  group('durak çizimi', () {
    test('çizim önceliği: 1 numara EN ÜSTTE (üst üste binen pinlerde sıradaki durak görünür)',
        () {
      final i = _Rota().icerik;
      expect(i.oncelik(_Rota.s1), greaterThan(i.oncelik(_Rota.s2)));
      expect(i.oncelik(_Rota.s2), greaterThan(i.oncelik(_Rota.s3)));
    });

    test('seçili durak HER ŞEYİN üstüne çıkar ve yalnız o seçilidir', () {
      final i = _Rota(secili: 's3').icerik;
      expect(i.seciliMi(_Rota.s3), isTrue);
      expect(i.seciliMi(_Rota.s1), isFalse);
      expect(i.oncelik(_Rota.s3), greaterThan(i.oncelik(_Rota.s1)));
    });

    test('kopyala seçimi değiştirir, null ile TEMİZLER, verilmezse korur', () {
      final r = _Rota(secili: 's2').icerik;
      expect(r.kopyala(seciliDurakId: () => null).seciliDurakId, isNull);
      expect(r.kopyala(seciliDurakId: () => 's1').seciliDurakId, 's1');
      expect(r.kopyala().seciliDurakId, 's2');
    });
  });

  group('rota çizgisi', () {
    test('durakları SIRAYLA bağlar', () {
      expect(_Rota().icerik.rotaNoktalari, [_Rota.a, _Rota.b, _Rota.c]);
    });

    test('cihaz biliniyorsa çizgi ORADAN başlar (oto sıralama da oradan başlıyor)', () {
      const cihaz = HaritaNoktasi(40.2000, 29.0000);
      final noktalar = _Rota(cihaz: cihaz).icerik.rotaNoktalari;
      expect(noktalar.first, cihaz);
      expect(noktalar, hasLength(4));
    });

    test('UZAKTAKİ cihaz rotanın başı DEĞİLDİR — çizgiye de kadraja da girmez', () {
      // Emülatörde görüldü: Kaliforniya'daki cihaz Bursa rotasına çizgi çekiyordu. Evdeki patron
      // ya da başka şehirdeki telefon için de aynısı: harita ülke ölçeğine uzaklaşırdı.
      const uzak = HaritaNoktasi(37.42, -122.08);
      final i = _Rota(cihaz: uzak).icerik;
      expect(i.rotaBaslangici, isNull);
      expect(i.rotaNoktalari, hasLength(3), reason: 'çizgi yalnız durakları bağlar');
      expect(i.kadraj!.kuzeyDogu!.lng, lessThan(30), reason: 'kadraj Bursa\'da kalır');
      // Nokta yine ÇİZİLİR — cihazın nerede olduğu gizlenmez.
      expect(i.cihaz, uzak);
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

    test('tek nokta çizgi DEĞİLDİR — boş liste', () {
      const tek = HaritaIcerigi(duraklar: [_Rota.s1]);
      expect(tek.rotaNoktalari, isEmpty);
    });

    test('tek durak + yakın cihaz = iki nokta, çizgi VAR', () {
      const i = HaritaIcerigi(duraklar: [_Rota.s1], cihaz: _Rota.b);
      expect(i.rotaNoktalari, [_Rota.b, _Rota.a]);
    });
  });

  group('kadraj', () {
    test('duraklar + yakın cihaz kutuyu belirler', () {
      const cihaz = HaritaNoktasi(40.3000, 28.9000);
      final k = _Rota(cihaz: cihaz).icerik.kadraj!;
      expect(k.kutuMu, isTrue);
      expect(k.guneyBati, const HaritaNoktasi(40.1800, 28.9000));
      expect(k.kuzeyDogu, const HaritaNoktasi(40.3000, 29.1000));
    });

    test('kuryeler kadraja GİRMEZ — şehrin öbür ucundaki kurye rotayı okunmaz kılardı', () {
      const i = HaritaIcerigi(
        duraklar: [_Rota.s1],
        kuryeler: [
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

    test('durak yokken cihaz tek başına kadrajdır; ikisi de yoksa kadraj yok', () {
      const i = HaritaIcerigi(cihaz: HaritaNoktasi(37.42, -122.08));
      expect(i.kadraj!.merkez, const HaritaNoktasi(37.42, -122.08));
      expect(const HaritaIcerigi().kadraj, isNull);
      expect(() => HaritaKadraji.noktalardan(const []), throwsArgumentError);
    });
  });

  group('dokunuş çözümü', () {
    test('durak ve kurye önekleri çözülür', () {
      expect(HaritaDokunusu.coz('d:abc'), isA<DurakDokunusu>().having((d) => d.id, 'id', 'abc'));
      expect(HaritaDokunusu.coz('k:u1'), isA<KuryeDokunusu>().having((d) => d.id, 'id', 'u1'));
    });

    test('cihaz ve tanınmayan kimlik dokunuş SAYILMAZ', () {
      // Cihaz bir durak değildir, özet açmaz; tanınmayan kimliğe dokunmak hiçbir şey yapmamalı.
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
      expect(i.id, 'u1');
      expect(i.nokta, const HaritaNoktasi(40.2, 29.0));
    });

    test('taze konumun etiketi yalnız ad — her pine saat asmak haritayı okunmaz kılar', () {
      final simdi = DateTime(2026, 9, 28, 12);
      final i = kuryeIsareti(
        konum(taze: true, zaman: simdi.subtract(const Duration(minutes: 2))),
        simdi: simdi,
      );
      expect(i.etiket, 'Ahmet Kurye');
    });
  });
}
