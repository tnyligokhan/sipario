// HARİTA STİLİ — indir, diskte sakla, Türkçeleştir, yedekle (2026-09-28).
//
// Stil yüklenemezse MapLibre HİÇBİR ŞEY çizmez, pinler dahil. Bu yüzden deponun asıl sözü
// "asla boş dönmez"dir: ağ yoksa disk, disk yoksa yedek stil. Testler ağa çıkmaz (`MockClient`)
// ve cihaz dizinine dokunmaz (geçici klasör).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/screens/orders/harita_stili.dart';

/// Uzak stilin küçük ama gerçekçi bir kopyası: ülke adı `name:latin`'den, yol kalkanı `ref`'ten.
String _uzakStil({String zemin = 'rgb(242,243,240)'}) => jsonEncode({
      'version': 8,
      'sources': {
        'openmaptiles': {'type': 'vector', 'url': 'https://tiles.openfreemap.org/planet'},
      },
      'glyphs': 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
      'layers': [
        {
          'id': 'background',
          'type': 'background',
          'paint': {'background-color': zemin},
        },
        {
          'id': 'label_country',
          'type': 'symbol',
          'layout': {
            'text-field': [
              'case',
              ['has', 'name:nonlatin'],
              ['concat', ['get', 'name:latin'], ' ', ['get', 'name:nonlatin']],
              ['coalesce', ['get', 'name_en'], ['get', 'name']],
            ],
          },
        },
        {
          'id': 'place_village',
          'type': 'symbol',
          'layout': {
            'text-field': ['get', 'name:latin'],
            'text-transform': 'uppercase',
          },
        },
        {
          'id': 'highway-shield',
          'type': 'symbol',
          'layout': {
            'text-field': ['to-string', ['get', 'ref']],
          },
        },
      ],
    });

/// Depo + sahte ağ + geçici dizin. Fikstür sınıfı: her test kendi ortamını kurar, sonunda siler.
class _StilOrtami {
  _StilOrtami({this.yanit}) {
    addTearDown(() {
      if (dizin.existsSync()) dizin.deleteSync(recursive: true);
    });
  }

  /// Ağın vereceği cevap; null = bağlantı hatası.
  http.Response Function(http.Request istek)? yanit;
  final List<Uri> istekler = [];
  final Directory dizin = Directory.systemTemp.createTempSync('harita_stili_');

  HaritaStilDeposu depo({Duration tazelik = const Duration(days: 1)}) => HaritaStilDeposu(
        istemci: MockClient((istek) async {
          istekler.add(istek.url);
          final y = yanit;
          if (y == null) throw const SocketException('ağ yok');
          return y(istek);
        }),
        dizin: () async => dizin.path,
        tazelikSuresi: tazelik,
      );

  File dosya(String ad) => File('${dizin.path}/harita_stili_$ad.json');
}

void main() {
  group('HaritaStili (saf)', () {
    test('ad yazan etiketler TÜRKÇE önceliğe geçer, yol numarası kalkanı dokunulmaz', () {
      final stil = jsonDecode(HaritaStili.uyarla(_uzakStil())) as Map;
      final katmanlar = {for (final k in stil['layers'] as List) k['id']: k};
      expect(katmanlar['label_country']['layout']['text-field'], [
        'coalesce',
        ['get', 'name:tr'],
        ['get', 'name:latin'],
        ['get', 'name'],
      ]);
      expect(katmanlar['highway-shield']['layout']['text-field'], [
        'to-string',
        ['get', 'ref'],
      ]);
    });

    test('büyük harf dönüşümü kalkar — motor Türkçe İ/ı bilmez ("ÇELTIKKÖY" yazıyordu)', () {
      final stil = jsonDecode(HaritaStili.uyarla(_uzakStil())) as Map;
      final koy = (stil['layers'] as List).singleWhere((k) => k['id'] == 'place_village') as Map;
      expect((koy['layout'] as Map).containsKey('text-transform'), isFalse);
      expect(koy['layout']['text-field'], [
        'coalesce',
        ['get', 'name:tr'],
        ['get', 'name:latin'],
        ['get', 'name'],
      ]);
    });

    test('geçerli stil tanınır; Wi-Fi giriş sayfası (HTML) ve bozuk JSON reddedilir', () {
      expect(HaritaStili.gecerliMi(_uzakStil()), isTrue);
      expect(HaritaStili.gecerliMi('<html><body>Otel Wi-Fi giriş</body></html>'), isFalse);
      expect(HaritaStili.gecerliMi('{"version": 7, "layers": []}'), isFalse);
      expect(HaritaStili.gecerliMi('{"hata": "yok"}'), isFalse);
      expect(HaritaStili.gecerliMi(''), isFalse);
    });

    test('yedek stil geçerlidir, zemin temayı izler ve glif adresini taşır', () {
      final acik = HaritaStili.yedek(koyu: false);
      final koyu = HaritaStili.yedek(koyu: true);
      expect(HaritaStili.gecerliMi(acik), isTrue);
      expect(HaritaStili.gecerliMi(koyu), isTrue);
      expect(acik, isNot(koyu));
      // Glif adresi durur: yazı tipi önbellekteyse pin numaraları çevrimdışında da yazılır.
      expect((jsonDecode(koyu) as Map)['glyphs'], contains('openfreemap.org/fonts'));
    });
  });

  group('HaritaStilDeposu', () {
    test('ağdan indirir, Türkçeleştirir ve diske yazar', () async {
      final o = _StilOrtami(yanit: (_) => http.Response(_uzakStil(), 200));
      final stil = await o.depo().getir(koyu: false);

      expect(o.istekler.single.toString(), 'https://tiles.openfreemap.org/styles/positron');
      expect(stil, contains('name:tr'));
      expect(o.dosya('positron').existsSync(), isTrue);
    });

    test('koyu tema koyu stili ister', () async {
      final o = _StilOrtami(yanit: (_) => http.Response(_uzakStil(), 200));
      await o.depo().getir(koyu: true);
      expect(o.istekler.single.path, '/styles/dark');
      expect(o.dosya('dark').existsSync(), isTrue);
    });

    test('diskteki TAZE stil ağ beklemeden kullanılır — çevrimdışı açılış', () async {
      final o = _StilOrtami(yanit: (_) => http.Response(_uzakStil(zemin: 'rgb(1,2,3)'), 200));
      await o.depo().getir(koyu: false);
      o.istekler.clear();
      o.yanit = null; // ağ gitti

      final stil = await o.depo().getir(koyu: false);
      expect(stil, contains('rgb(1,2,3)'), reason: 'yedek değil, diskteki gerçek stil');
      expect(o.istekler, isEmpty);
    });

    test('diskteki BAYAT stil hemen döner, arkada tazelenir', () async {
      final o = _StilOrtami(yanit: (_) => http.Response(_uzakStil(zemin: 'rgb(1,1,1)'), 200));
      await o.depo().getir(koyu: false);
      o.dosya('positron').setLastModifiedSync(DateTime.now().subtract(const Duration(days: 3)));
      o.istekler.clear();
      o.yanit = (_) => http.Response(_uzakStil(zemin: 'rgb(9,9,9)'), 200);

      final stil = await o.depo().getir(koyu: false);
      expect(stil, contains('rgb(1,1,1)'), reason: 'açılış ağı beklemez');
      // Tazeleme arkada GERÇEK disk yazımı yapar — olay kuyruğunu boşaltmak ona yetmez.
      for (var i = 0; i < 100; i++) {
        if (o.dosya('positron').readAsStringSync().contains('rgb(9,9,9)')) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(o.istekler, hasLength(1));
      expect(o.dosya('positron').readAsStringSync(), contains('rgb(9,9,9)'));
    });

    test('ağ yok, disk yok → YEDEK stil (asla boş dönmez, pinler çizilir)', () async {
      final o = _StilOrtami();
      final stil = await o.depo().getir(koyu: true);
      expect(stil, HaritaStili.yedek(koyu: true));
    });

    test('sunucu hatası → yedek; diske hiçbir şey yazılmaz', () async {
      final o = _StilOrtami(yanit: (_) => http.Response('bakımda', 503));
      final stil = await o.depo().getir(koyu: false);
      expect(stil, HaritaStili.yedek(koyu: false));
      expect(o.dosya('positron').existsSync(), isFalse);
    });

    test('200 ile gelen HTML (Wi-Fi giriş sayfası) stil diye KAYDEDİLMEZ', () async {
      // Kaydedilseydi ağ düzeldikten sonra bile harita diskteki HTML yüzünden boş kalırdı.
      final o = _StilOrtami(yanit: (_) => http.Response('<html>Giriş yapın</html>', 200));
      final stil = await o.depo().getir(koyu: false);
      expect(stil, HaritaStili.yedek(koyu: false));
      expect(o.dosya('positron').existsSync(), isFalse);
    });

    test('diskteki BOZUK dosya yok sayılır ve ağdan yenisi alınır', () async {
      final o = _StilOrtami(yanit: (_) => http.Response(_uzakStil(zemin: 'rgb(5,5,5)'), 200));
      o.dosya('positron').writeAsStringSync('{yarım');
      final stil = await o.depo().getir(koyu: false);
      expect(stil, contains('rgb(5,5,5)'));
    });

    test('eşzamanlı iki istek TEK indirmeye düşer', () async {
      final o = _StilOrtami(yanit: (_) => http.Response(_uzakStil(), 200));
      final depo = o.depo();
      await Future.wait([depo.getir(koyu: false), depo.getir(koyu: false)]);
      expect(o.istekler, hasLength(1));
    });

    test('aynı depo ikinci kez bellekten verir', () async {
      final o = _StilOrtami(yanit: (_) => http.Response(_uzakStil(), 200));
      final depo = o.depo();
      await depo.getir(koyu: false);
      o.dosya('positron').deleteSync();
      await depo.getir(koyu: false);
      expect(o.istekler, hasLength(1));
    });
  });
}
