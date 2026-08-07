// SİHİRBAZ — "ARKA PLANDA ÇALIŞMA" ADIMI (saha hatası 2026-07-29).
//
// Bayi: "kurulumdaki pil optimizasyonu izni arka planda otomatik çalıştırma iznini açıyor."
// Haklıydı: adım "Pil optimizasyonu muafiyeti" diyordu ama `openBestSettingsScreen`
// Xiaomi/Oppo/Vivo/Huawei'de OTOMATİK BAŞLATMA bileşenini açıyordu. İki zarar birden:
//  1. Kullanıcı adı verilen ayarı açılan ekranda bulamıyor ("uygulama bozuk").
//  2. Pil kısıtlaması HİÇ kaldırılmıyor — oysa MIUI'de arayan tanımayı iki ayrı mekanizma
//     öldürebiliyor ve ikisi de gerekli (otomatik başlatma kapalıysa servis hiç uyanmaz,
//     pil kısıtlaması ise uyanmış süreci keser).
//
// Testler KANALA GİDEN METODU sınar — düğmenin çizilmesi değil, DOĞRU AYARIN açılması.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/sihirbaz/izin_adimlari.dart';
import 'package:sipario/screens/sihirbaz/izin_sihirbazi.dart';

import 'support/kabuk_yardimcilari.dart';

void main() {
  const kanal = MethodChannel('sipario/izinler');
  late List<String> cagrilar;
  late bool otomatikBaslatmaVar;

  setUp(() {
    cagrilar = [];
    otomatikBaslatmaVar = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kanal, (call) async {
      cagrilar.add(call.method);
      return switch (call.method) {
        // Tüm izinler verilmiş görünsün ki adımlar "Devam" ile hızlı geçilsin; pil adımının
        // durumu zaten okunamaz (durumAnahtari null) ve kendi düğmelerini gösterir.
        'status' => <String, dynamic>{
            'hasScreeningRole': true,
            'hasContactsPermission': true,
            'canDrawOverlays': true,
            'hasNotificationPermission': true,
            'canUseFullScreenIntent': true,
          },
        'hasAutostartSettings' => otomatikBaslatmaVar,
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kanal, null);
  });

  /// Karşılamadan son adıma (pil) kadar ilerler.
  Future<void> pilAdimina(WidgetTester tester) async {
    await ekranaKoy(tester, const IzinSihirbazi(channel: kanal));
    await tester.tap(find.text('Kuruluma Başla'));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Devam'));
      await tester.pump();
    }
    expect(find.text('Adım 6/6'), findsOneWidget);
  }

  group('Adım tanımı', () {
    test('adım artık İKİ ayarı kapsıyor ve adı buna göre', () {
      final pil = izinAdimlari.firstWhere((i) => i.anahtar == 'pil');
      expect(pil.ad, 'Arka planda çalışma');
      expect(pil.eylem, 'openBatterySettings');
      expect(pil.ikincilEylem, 'openAutostartSettings',
          reason: 'otomatik başlatma AYRI bir eylemdir, pil düğmesinin arkasına saklanmaz');
      expect(pil.ikincilVarlikAnahtari, 'hasAutostartSettings');
    });

    test('adım sayısı DEĞİŞMEDİ — sabit altı adım kararı korunuyor', () {
      // Sabit liste kararı ADIM SAYISIYLA ilgilidir; bir adımın içindeki düğme sayısıyla değil.
      expect(izinAdimlari.map((i) => i.anahtar).toList(),
          ['tarama', 'rehber', 'overlay', 'bildirim', 'kilit', 'pil']);
    });
  });

  group('Pil adımı — hangi ayar açılıyor', () {
    testWidgets('birincil düğme PİL ayarını açar (otomatik başlatmayı DEĞİL)', (tester) async {
      await pilAdimina(tester);

      expect(find.text('Pil Ayarını Aç'), findsOneWidget);
      cagrilar.clear();
      await tester.tap(find.text('Pil Ayarını Aç'));
      await tester.pump();

      expect(cagrilar, contains('openBatterySettings'));
      expect(cagrilar, isNot(contains('openAutostartSettings')),
          reason: 'ASIL HATA BUYDU: pil düğmesi otomatik başlatmayı açıyordu');

      await kapat(tester);
    });

    testWidgets('ikincil düğme otomatik başlatmayı açar', (tester) async {
      await pilAdimina(tester);

      expect(find.text('Otomatik Başlatmayı Aç'), findsOneWidget);
      cagrilar.clear();
      await tester.tap(find.text('Otomatik Başlatmayı Aç'));
      await tester.pump();

      expect(cagrilar, contains('openAutostartSettings'));
      expect(cagrilar, isNot(contains('openBatterySettings')));

      await kapat(tester);
    });

    testWidgets('otomatik başlatma ekranı OLMAYAN cihazda ikinci düğme ÇİZİLMEZ',
        (tester) async {
      // Pixel'de böyle bir kavram yok; hiçbir yere gitmeyen bir düğme kullanıcıya
      // "bir şeyi eksik yaptım" hissi bırakır.
      otomatikBaslatmaVar = false;
      await pilAdimina(tester);

      expect(find.text('Pil Ayarını Aç'), findsOneWidget);
      expect(find.text('Otomatik Başlatmayı Aç'), findsNothing);

      await kapat(tester);
    });

    testWidgets('ikincil düğme adımı "verildi" SAYMAZ', (tester) async {
      // İki düğmeden birine dokunmayı "tamam" saymak, kullanıcının yalnız birini yaptığı
      // durumu gizlerdi. Adımı tamamlayan birincil eylemdir.
      await pilAdimina(tester);

      await tester.tap(find.text('Otomatik Başlatmayı Aç'));
      await tester.pump();

      expect(find.text('İzin verildi'), findsNothing);
      expect(find.text('Pil Ayarını Aç'), findsOneWidget, reason: 'adım hâlâ açık');

      await kapat(tester);
    });
  });
}
