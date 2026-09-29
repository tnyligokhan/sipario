// YOL ÇİZGİSİ İSTEMCİSİ — `POST /rota/cizgi` (2026-09-29).
//
// Sözleşme: ASLA fırlatmaz; her arıza `null` döner ve harita kuş uçuşu çizgiye düşer. Gövde
// yalnız sipariş kimliklerini taşır (koordinat telefondan çıkmaz), sıra korunur.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/screens/orders/harita_icerigi.dart';
import 'package:sipario/sync/rota_cizgisi_api.dart';

/// Sahte sunucu + son istek. Fikstür sınıfı: her test kendi yanıtını kurar.
class _Sunucu {
  _Sunucu(this._yanit);

  final http.Response Function() _yanit;
  http.Request? sonIstek;

  RotaCizgisiApi get api => RotaCizgisiApi(
        baseUrl: 'https://x.test/api/v1',
        token: 'jeton',
        client: MockClient((istek) async {
          sonIstek = istek;
          return _yanit();
        }),
      );
}

void main() {
  const gecerli = {
    'noktalar': [
      [40.19, 29.06],
      [40.20, 29.04],
      [40.21, 29.02],
    ],
    'duraklar': [
      [40.19, 29.06],
      [40.21, 29.02],
    ],
  };

  test('çizgi ve durakları çözer; gövde yalnız sıralı sipariş kimlikleridir', () async {
    final s = _Sunucu(() => http.Response(jsonEncode(gecerli), 200));
    final sonuc = await s.api.cizgi(['s2', 's1']);

    expect(sonuc!.noktalar, hasLength(3));
    expect(sonuc.noktalar.first, const HaritaNoktasi(40.19, 29.06));
    expect(sonuc.duraklar, const [HaritaNoktasi(40.19, 29.06), HaritaNoktasi(40.21, 29.02)]);
    expect(s.sonIstek!.url.toString(), 'https://x.test/api/v1/rota/cizgi');
    expect(s.sonIstek!.headers['Authorization'], 'Bearer jeton');
    expect(jsonDecode(s.sonIstek!.body), {
      'order_ids': ['s2', 's1'],
    });
  });

  test('503 (servis kapalı) → null', () async {
    final s = _Sunucu(() => http.Response('{"message":"x"}', 503));
    expect(await s.api.cizgi(['a', 'b']), isNull);
  });

  test('ağ hatası → null, fırlatmaz', () async {
    final api = RotaCizgisiApi(
      baseUrl: 'https://x.test',
      token: 't',
      client: MockClient((_) async => throw const SocketException('ağ yok')),
    );
    expect(await api.cizgi(['a', 'b']), isNull);
  });

  test('bozuk gövde, eksik alan ya da aralık dışı nokta → null', () async {
    for (final govde in [
      'html değil json',
      jsonEncode({'noktalar': gecerli['noktalar']}),
      jsonEncode({
        'noktalar': [
          [99.0, 29.0],
          [40.0, 29.0],
        ],
        'duraklar': <Object>[],
      }),
      jsonEncode({
        'noktalar': [
          [40.0],
        ],
        'duraklar': <Object>[],
      }),
    ]) {
      final s = _Sunucu(() => http.Response(govde, 200));
      expect(await s.api.cizgi(['a', 'b']), isNull, reason: govde);
    }
  });

  test('ikiden az durak için istek HİÇ gitmez', () async {
    final s = _Sunucu(() => http.Response(jsonEncode(gecerli), 200));
    expect(await s.api.cizgi(['tek']), isNull);
    expect(s.sonIstek, isNull);
  });
}
