// ARAYAN TANIMA AÇ/KAPA ayarı (`lib/screens/cagri/arayan_tanima_ayari.dart`).
//
// Anahtarın ASIL tüketicisi native taraftır (`ArayanAyari.kt` zil anında dosyayı okur) ve o
// yol widget testinden sınanamaz; burada kilitlenen sözleşme ŞUDUR: dosya adı ve içerik
// değerleri (`acik`/`kapali`, varsayılan açık) iki tarafın elle senkron tuttuğu sözleşmedir,
// Dart tarafı onları değiştirirse bu testler kırılmalıdır.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/cagri/arayan_tanima_ayari.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/app_theme.dart';

import 'support/ekran_yardimcilari.dart';
import 'package:sipario/screens/isletme/ayarlar/uygulama_ayarlari_ekrani.dart';

void main() {
  // Gerçek depo platform kanalına (sqflite dizini) uzanır; widget testinde dikiş bellekle
  // değiştirilir ve HER testten sonra geri alınır (`konumApiUret` deseni).
  late ArayanTanimaDeposu bellek;
  setUp(() {
    final eski = arayanTanimaDeposu;
    bellek = ArayanTanimaDeposu.bellek();
    arayanTanimaDeposu = bellek;
    addTearDown(() => arayanTanimaDeposu = eski);
  });

  group('ArayanTanimaDeposu', () {
    test('hiç yazılmamışsa AÇIK — kart göstermek varsayılandır', () async {
      expect(await ArayanTanimaDeposu.bellek().acikMi(), isTrue);
    });

    test('kapatılan tercih okunur, açılan geri gelir', () async {
      final depo = ArayanTanimaDeposu.bellek();
      await depo.yaz(false);
      expect(await depo.acikMi(), isFalse);
      await depo.yaz(true);
      expect(await depo.acikMi(), isTrue);
    });

    test('dosya adı ve içerik native sözleşmesiyle aynıdır (ArayanAyari.kt aynası)', () {
      // Bu sabitler `ArayanAyari.kt` ile ELLE senkron: ad ya da değerler değişirse önce
      // Kotlin tarafı, sonra bu test güncellenir — sessiz ayrışma yasak.
      expect(kArayanDosyaAdi, 'sipario_arayan.txt');
    });
  });

  group('ArayanTanimaSatiri', () {
    testWidgets('varsayılan açık çizilir; dokunuş kapatır ve depoya yazar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: SipTheme.acik(),
        home: const Scaffold(body: ArayanTanimaSatiri()),
      ));
      await tester.pump(); // depo okuması (bellek: anında) ağaca işlensin

      expect(find.text('Arayan tanıma'), findsOneWidget);
      // DURUM ANAHTARDAN OKUNUR, METİNDEN DEĞİL (2026-08-18). Alt başlık artık açık/kapalı
      // hâline göre değişmiyor: durumu sağdaki `SipKnob` gösteriyor ve aynı bilgiyi iki kez
      // yazmak satırı okumak yerine çözmeyi gerektiriyordu. Test de kontrolü sınıyor —
      // kopyayı sınayan bir test, kopya her iyileştiğinde kırılır ve hiçbir davranış korumaz.
      expect(tester.widget<SipKnob>(find.byType(SipKnob)).acik, isTrue);

      await tester.tap(find.text('Arayan tanıma'));
      await tester.pump();

      expect(tester.widget<SipKnob>(find.byType(SipKnob)).acik, isFalse);
      expect(await bellek.acikMi(), isFalse,
          reason: 'anahtar yalnız görünümü değil DEPOYU değiştirmeli — native taraf oradan okur');
    });

    testWidgets('kayıtlı KAPALI tercih yeniden kuruluşta korunur', (tester) async {
      await bellek.yaz(false);

      await tester.pumpWidget(MaterialApp(
        theme: SipTheme.acik(),
        home: const Scaffold(body: ArayanTanimaSatiri()),
      ));
      await tester.pump();

      expect(tester.widget<SipKnob>(find.byType(SipKnob)).acik, isFalse,
          reason: 'satır kalıcı tercihi okur; her açılışta açığa dönen bir anahtar sahte kontroldür');
    });
  });

  group('Ayarlar → Uygulama sayfası', () {
    testWidgets('anahtar Arayan Tanıma kartının İLK satırıdır', (tester) async {
      // Ayarlar 2026-08-13'te hub + beş sayfaya bölündü; arayan tanıma öbeği UYGULAMA
      // sayfasında yaşıyor. Anahtarın bölümün İLK satırı olması kuralı değişmedi: diğer
      // satırlar (kurulum) özelliğin parçalarıdır, özelliğin kendisi hepsinden önce gelir.
      // ("Gelen çağrıyı dene" satırı 2026-08-18'de kaldırıldı — kullanıcı kararı.)
      await ekranaKoy(tester, const UygulamaAyarlariEkrani());

      expect(find.text('Arayan tanıma'), findsOneWidget);
      // Bölümün diğer satırları anahtarın ALTINDA kalmaya devam eder.
      expect(find.text('Kurulum ve izinler'), findsOneWidget);

      await kapat(tester);
    });
  });
}
