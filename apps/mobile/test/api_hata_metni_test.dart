// API HATA METNİ + GİRİŞ YENİDEN DENEMESİ (kullanıcı isteği 2026-09-29).
//
// Kilitlenen iki şikâyet:
//   • "Uygulamalarda sunucu bilgisi hiçbir koşulda geçmemeli" — ekrana giden hiçbir hata
//     metni HTTP kodu, adres ya da çerçevenin İngilizce varsayılanını taşımaz.
//   • "Bazen tüm bilgiler doğru olmasına rağmen giriş yapamıyorum" — geçici arızada (dağıtım
//     anı, kopan bağlantı) giriş kendiliğinden yeniden denenir; kimlik reddi DENENMEZ.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sipario/auth/auth_api.dart';
import 'package:sipario/sync/api_hata_metni.dart';

/// Sırayla yanıt veren sahte sunucu; kaç istek geldiğini sayar.
class _SahteSunucu {
  _SahteSunucu(this._yanitlar);

  /// Her eleman bir istek: `http.Response` döner ya da `SocketException` fırlatır.
  final List<Object> _yanitlar;
  int istekSayisi = 0;

  static http.Response json(int durum, Map<String, dynamic> govde) =>
      http.Response(jsonEncode(govde), durum,
          headers: {'content-type': 'application/json; charset=utf-8'});

  static http.Response basarili() => json(200, {
        'token': 't',
        'user': {'id': 'u1', 'name': 'Ali', 'role': 'patron'},
        'tenant': {'name': 'Bayi', 'status': 'active'},
      });

  AuthApi api() => AuthApi(
        baseUrl: 'https://ornek.test/api/v1',
        client: MockClient((_) async {
          final y = _yanitlar[istekSayisi.clamp(0, _yanitlar.length - 1)];
          istekSayisi++;
          if (y is Exception) throw y;
          return y as http.Response;
        }),
        yenidenDeneme: const [Duration.zero, Duration.zero],
      );

  Future<Object> girisDene() async {
    try {
      return await api().login(
        tenantCode: 'merkezbayi',
        username: 'ali',
        password: 'parola1',
        deviceId: '0190a000-0000-7000-8000-000000000000',
      );
    } on AuthException catch (e) {
      return e;
    }
  }
}

void main() {
  group('ApiHataMetni — sunucu bilgisi sızmaz', () {
    const metin = ApiHataMetni('Adres araması yapılamadı');

    test('5xx: çerçevenin İngilizce cümlesi ve durum kodu yazılmaz', () {
      final m = metin.yanit(500, {'message': 'Server Error'});
      expect(m, isNot(contains('Server')));
      expect(m, isNot(contains('500')));
      expect(m, startsWith('Adres araması yapılamadı'));
    });

    test('502 HTML gövdesi (vekil sunucu sayfası) metne girmez', () {
      final m = metin.yanit(502, const {});
      expect(m, isNot(contains('502')));
      expect(m, contains('Geçici bir aksaklık'));
    });

    test('429 ve 401 kendi Türkçe cümlelerini alır', () {
      expect(metin.yanit(429, {'message': 'Too Many Attempts.'}), ApiHataMetni.cokFazlaDeneme);
      expect(metin.yanit(401, {'message': 'Unauthenticated.'}), ApiHataMetni.oturumBitti);
    });

    test('güvenilen kodda Türkçe sunucu cümlesi kullanılır, tek cümleyse noktası atılır', () {
      expect(metin.yanit(409, {'message': 'Oto sıralama hakkınız kalmadı.'}),
          'Oto sıralama hakkınız kalmadı');
      expect(metin.yanit(422, {'message': 'Hesabınız kapalı. Destek alın.'}),
          'Hesabınız kapalı. Destek alın.', reason: 'iki cümlede noktalama korunur');
    });

    test('güvenilen kodda bile İngilizce ya da adres taşıyan cümle kullanılmaz', () {
      expect(metin.yanit(422, {'message': 'The given data was invalid.'}),
          isNot(contains('given')));
      expect(metin.yanit(409, {'message': 'Çakışma: https://api.ornek.test/x'}),
          isNot(contains('https')));
    });

    test('doğrulama hatalarının ilki gösterilir', () {
      final m = const ApiHataMetni('Kaydedilemedi').yanit(422, {
        'message': 'The given data was invalid.',
        'errors': {
          'username': ['Bu kullanıcı adı bu bayide zaten kullanılıyor.'],
        },
      });
      expect(m, 'Bu kullanıcı adı bu bayide zaten kullanılıyor');
    });
  });

  group('Giriş — geçici arızada kendiliğinden yeniden dener', () {
    test('503 ardından 200: kullanıcı hata görmeden girer', () async {
      final s = _SahteSunucu([_SahteSunucu.json(503, const {}), _SahteSunucu.basarili()]);
      final sonuc = await s.girisDene();
      expect(sonuc, isA<LoginResult>());
      expect(s.istekSayisi, 2);
    });

    test('kopan bağlantı ardından 200: girer', () async {
      final s = _SahteSunucu([const SocketException('kopuk'), _SahteSunucu.basarili()]);
      expect(await s.girisDene(), isA<LoginResult>());
      expect(s.istekSayisi, 2);
    });

    test('⭐ kimlik reddi (401) YENİDEN DENENMEZ ve sunucunun nötr cümlesi gösterilir', () async {
      final s = _SahteSunucu([
        _SahteSunucu.json(401, {'message': 'Firma kodu, kullanıcı adı veya parola hatalı.'}),
      ]);
      final sonuc = await s.girisDene();
      expect(s.istekSayisi, 1, reason: 'yanlış parolayı tekrar sormak hız sınırını tüketir');
      expect((sonuc as AuthException).message, 'Firma kodu, kullanıcı adı veya parola hatalı');
    });

    test('arıza sürerse deneme sınırında durur ve kod göstermez', () async {
      final s = _SahteSunucu([_SahteSunucu.json(502, const {})]);
      final sonuc = await s.girisDene();
      expect(s.istekSayisi, 3, reason: 'bir ilk istek + iki yeniden deneme');
      final mesaj = (sonuc as AuthException).message;
      expect(mesaj, startsWith('Giriş yapılamadı'));
      expect(mesaj, isNot(contains('502')));
    });

    test('bağlantı hiç kurulamazsa internet cümlesi, sunucu sözcüğü yok', () async {
      final s = _SahteSunucu([const SocketException('yok')]);
      final mesaj = ((await s.girisDene()) as AuthException).message;
      expect(mesaj, ApiHataMetni.baglantiYok);
      expect(mesaj.toLowerCase(), isNot(contains('sunucu')));
    });
  });
}
