// Uygulama içi güncelleme — SAF kuralların regresyon kilidi.
//
// Kapsam: sürüm karşılaştırması, JSON çözümlemesi, ABI seçimi ve indirme bütünlüğü. Ağ, dosya
// ve native köprü buradan test EDİLEMEZ (platform kanalı yok) — ama kararların TAMAMI saf
// fonksiyonlara çekildiği için kurallar burada çivileniyor.

import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/guncelleme/guncelleme_sozlesmesi.dart';

const _tamJson = '''
{
  "yapim": 128,
  "surum": "0.9.0",
  "apk_arm64": "https://ornek/saha-arm64.apk",
  "apk_evrensel": "https://ornek/saha-evrensel.apk",
  "boyut_arm64": 30204268,
  "boyut_evrensel": 79600000
}
''';

void main() {
  group('guncellemeVarMi — tek karar noktası', () {
    test('uzak yapı BÜYÜKSE güncelleme vardır', () {
      expect(guncellemeVarMi(yerelYapim: 128, uzakYapim: 129), isTrue);
    });

    test('eşitse YOKTUR', () {
      expect(guncellemeVarMi(yerelYapim: 128, uzakYapim: 128), isFalse);
    });

    test('uzak yapı KÜÇÜKSE yoktur — sürüm DÜŞÜRÜLMEZ', () {
      // Cihazda sunucudan yeni bir derleme olabilir (geliştirici telefonu, elle kurulmuş APK).
      // Onu "güncelle" diye geri sürüme düşürmek veri kaybı riskidir.
      expect(guncellemeVarMi(yerelYapim: 200, uzakYapim: 128), isFalse);
    });

    test('yerel yapı BİLİNMİYORSA (0) asla güncelleme yok', () {
      // `--dart-define=SIPARIO_YAPIM` verilmemiş yerel/geliştirme derlemesi: bayi dürtülmez.
      expect(guncellemeVarMi(yerelYapim: 0, uzakYapim: 999), isFalse);
    });
  });

  group('SurumBilgisi.cozumle', () {
    test('tam JSON çözülür', () {
      final b = SurumBilgisi.cozumle(_tamJson)!;
      expect(b.yapim, 128);
      expect(b.surum, '0.9.0');
      expect(b.apkArm64, 'https://ornek/saha-arm64.apk');
      expect(b.apkEvrensel, 'https://ornek/saha-evrensel.apk');
      expect(b.boyutArm64, 30204268);
      expect(b.boyutEvrensel, 79600000);
    });

    test('boyut alanları YOKSA 0 kalır, çözümleme yine başarılı', () {
      // Eski bir `surum.json` yüzünden güncellemenin tamamen durması istenmez; yalnız
      // bütünlük kontrolü atlanır.
      const eksik = '{"yapim":5,"surum":"0.9.0","apk_arm64":"a","apk_evrensel":"b"}';
      final b = SurumBilgisi.cozumle(eksik)!;
      expect(b.boyutArm64, 0);
      expect(b.boyutEvrensel, 0);
    });

    test('bozuk/eksik girdiler null döner — çökme YOK', () {
      expect(SurumBilgisi.cozumle('bu json değil'), isNull);
      expect(SurumBilgisi.cozumle('[]'), isNull, reason: 'nesne değil');
      expect(SurumBilgisi.cozumle('{}'), isNull);
      expect(SurumBilgisi.cozumle('{"yapim":0,"surum":"a","apk_arm64":"x","apk_evrensel":"y"}'),
          isNull, reason: 'yapim 0 anlamsız');
      expect(SurumBilgisi.cozumle('{"yapim":5,"surum":"a","apk_arm64":"","apk_evrensel":"y"}'),
          isNull, reason: 'boş url');
      expect(SurumBilgisi.cozumle('{"yapim":5,"apk_arm64":"x","apk_evrensel":"y"}'),
          isNull, reason: 'surum yok');
    });

    test('yapim metin olarak gelse de çözülür', () {
      const metin = '{"yapim":"128","surum":"0.9.0","apk_arm64":"a","apk_evrensel":"b"}';
      expect(SurumBilgisi.cozumle(metin)!.yapim, 128);
    });
  });

  group('indirilecek — ABI seçimi', () {
    final bilgi = SurumBilgisi.cozumle(_tamJson)!;

    test('arm64 cihaz KÜÇÜK APKyı alır', () {
      final h = bilgi.indirilecek(['arm64-v8a', 'armeabi-v7a']);
      expect(h.url, bilgi.apkArm64);
      expect(h.boyut, 30204268);
    });

    test('arm64 OLMAYAN cihaz evrensel APKyı alır', () {
      final h = bilgi.indirilecek(['armeabi-v7a']);
      expect(h.url, bilgi.apkEvrensel);
      expect(h.boyut, 79600000);
    });

    test('ABI listesi BOŞSA evrensel seçilir', () {
      // Köprü cevap vermedi: büyük ama her cihazda çalışan paket. Yanlış ABI kurmaktansa
      // fazladan indirmek tercih edilir.
      expect(bilgi.indirilecek(const []).url, bilgi.apkEvrensel);
    });
  });

  group('indirmeSaglamMi — yarım indirme koruması', () {
    test('boyut birebir tutmalı', () {
      expect(indirmeSaglamMi(inenBayt: 100, beklenenBayt: 100), isTrue);
      expect(indirmeSaglamMi(inenBayt: 99, beklenenBayt: 100), isFalse);
      expect(indirmeSaglamMi(inenBayt: 101, beklenenBayt: 100), isFalse);
    });

    test('beklenen boyut bilinmiyorsa yalnız BOŞ dosya reddedilir', () {
      expect(indirmeSaglamMi(inenBayt: 1, beklenenBayt: 0), isTrue);
      expect(indirmeSaglamMi(inenBayt: 0, beklenenBayt: 0), isFalse);
    });
  });

  group('onbelleksizAdres — CDN bayat cevap veriyordu (2026-07-29 saha hatası)', () {
    // Ölçülen arıza: CI yeni sürümü yayınladıktan SONRA düz adresten yapılan üç ardışık istek
    // de eski içeriği döndürdü (`X-Cache: HIT`, `Age: 930`); aynı adres benzersiz bir sorgu
    // parametresiyle istendiğinde yenisi geldi. Bant düşmemesinin gerçek sebebi buydu ve
    // hiçbir hata/kayıt üretmiyordu — bu yüzden kural burada çivileniyor.
    final damga = DateTime.fromMillisecondsSinceEpoch(1790000000000); // sabit an

    test('sorgu parametresi EKLENİR — önbellek anahtarı değişsin', () {
      final u = onbelleksizAdres('https://ornek/saha/surum.json', damga);
      expect(u.queryParameters['t'], isNotNull);
      expect(u.path, '/saha/surum.json', reason: 'yol bozulmamalı');
      expect(u.host, 'ornek');
    });

    test('farklı anlarda farklı adres üretir', () {
      final a = onbelleksizAdres('https://ornek/x.json', damga);
      final b = onbelleksizAdres(
          'https://ornek/x.json', damga.add(const Duration(seconds: 30)));
      expect(a, isNot(equals(b)));
    });

    test('adreste ZATEN sorgu varsa korunur', () {
      // GitHub varlık adresleri bugün sorgusuz; ama imzalı/parametreli bir adrese geçilirse
      // parametreyi düşürmek indirmeyi sessizce bozardı.
      final u = onbelleksizAdres('https://ornek/x.apk?imza=abc', damga);
      expect(u.queryParameters['imza'], 'abc');
      expect(u.queryParameters['t'], isNotNull);
    });

    test('başlıklar da önbelleklemeyi reddeder', () {
      expect(kOnbelleksizBasliklar['Cache-Control'], contains('no-cache'));
      expect(kOnbelleksizBasliklar['Pragma'], 'no-cache');
    });
  });

  group('Kanal kapısı', () {
    test('define verilmeyen testte güncelleme KAPALI', () {
      // Test koşumunda `SIPARIO_KANAL`/`SIPARIO_YAPIM` tanımsızdır → magaza + 0.
      // Bu, mağaza derlemesinin davranışının aynısı: ağa hiç çıkılmaz.
      expect(kKanal, 'magaza');
      expect(kYapim, 0);
      expect(guncellemeKapaliMi, isTrue);
    });
  });

  // KANAL AYRIMI — 2026-08-09 arızasının regresyon kilidi.
  //
  // O tarihe kadar güncelleme adresi SABİT 'saha' idi ve CI 'dev' dalına her push'ta saha
  // release'ini güncelliyordu: GERÇEK BAYİLERİN telefonları denenmemiş kodla kendi kendine
  // güncelleniyordu. Aşağıdaki iddialar o yolun bir daha açılmasını engelliyor.
  group('Kanal → release etiketi', () {
    test('saha ve test AYRI adreslere bakar (arızanın ta kendisi)', () {
      expect(surumJsonAdresi('saha'), isNot(surumJsonAdresi('test')),
          reason: 'iki kanal aynı adrese bakarsa geliştirme derlemesi sahadaki bayiye iner');
      expect(surumJsonAdresi('saha'), contains('/saha/surum.json'));
      expect(surumJsonAdresi('test'), contains('/test/surum.json'));
    });

    test('tanınmayan kanal SAHA etiketine düşer (güvenli taraf)', () {
      expect(surumJsonAdresi('magaza'), contains('/saha/surum.json'));
      expect(surumJsonAdresi('uydurma'), contains('/saha/surum.json'),
          reason: 'tanımsız bir etikete istek atmaktansa var olan kanala düşmek yeğdir; '
              'mağaza kanalında bu adres zaten hiç kullanılmaz');
    });

    test('derleme sabiti kuralla AYNI şeyi söyler', () {
      // kKanal derleme sabiti olduğu için testte değiştirilemez; sabitin KURALA UYDUĞU burada
      // kilitlenir. İkisi ayrışırsa kural değişmiş ama sabit güncellenmemiş demektir.
      expect(kSurumJsonAdresi, surumJsonAdresi(kKanal));
    });
  });
}
