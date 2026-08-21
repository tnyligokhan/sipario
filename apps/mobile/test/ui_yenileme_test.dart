// AŞAĞI ÇEKEREK YENİLE · SAATE GÖRE SELAM · ORTALI BENTO (kullanıcı isteği 2026-07-29).
//
// Yenilemenin ASIL sınavı "gösterge döndü mü" değil, "gerçekten iş yapıldı mı"dır: bir
// `RefreshIndicator` göstergeyi hiçbir şey yapmadan da çevirebilir ve kullanıcıya yapıldı
// yalanını söyler. Bu yüzden testler jestin SONUCUNU sınar (senkron çağrıldı mı, güncelleme
// kontrolü koştu mu), görünümü değil.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/guncelleme/guncelleme_servisi.dart';
import 'package:sipario/screens/ana_ekran.dart';
import 'package:sipario/screens/shell/alt_nav.dart';
import 'package:sipario/theme/components/states.dart';

import 'support/kabuk_yardimcilari.dart';

void main() {
  group('selam — saate göre dört kuşak', () {
    String s(int saat) => AnaEkran.selam(DateTime(2026, 7, 29, saat));

    test('sabah Günaydın', () {
      expect(s(6), 'Günaydın');
      expect(s(9), 'Günaydın');
      expect(s(11), 'Günaydın');
    });

    test('öğle Kolay gelsin', () {
      // Esnaf sözlüğü: teslimatın en yoğun olduğu bantta "iyi günler" fazla resmî kalıyordu.
      expect(s(12), 'Kolay gelsin');
      expect(s(17), 'Kolay gelsin');
    });

    test('akşam İyi akşamlar', () {
      expect(s(18), 'İyi akşamlar');
      expect(s(21), 'İyi akşamlar');
    });

    test('gece İyi geceler — gün dönümünün İKİ yanında da', () {
      // 22:00 sonrası ve 06:00 öncesi AYNI kuşaktır; sınırın iki yakasını da sınamak şart,
      // yoksa "saat < 6" dalını unutan bir düzeltme gece yarısını sessizce günaydına çevirir.
      expect(s(22), 'İyi geceler');
      expect(s(23), 'İyi geceler');
      expect(s(0), 'İyi geceler');
      expect(s(5), 'İyi geceler');
    });
  });

  group('SipGovde — aşağı çekerek yenile', () {
    testWidgets('onYenile verilmezse gösterge HİÇ kurulmaz', (tester) async {
      // Yenilenecek bir şeyi olmayan ekranda dönen gösterge, iş yapıldığı yalanını söyler.
      await ekranaKoy(tester, const SipGovde(children: [Text('içerik')]));
      expect(find.byType(RefreshIndicator), findsNothing);
      await kapat(tester);
    });

    /// RefreshIndicator jesti: çek, sonra göstergenin kendi animasyonunu ilerlet.
    /// `pumpAndSettle` KULLANILMAZ — gösterge kapanırken sonsuz dönen bir animasyon bırakabilir
    /// ve test asılır (bu depoda iskelet parıltısıyla bir kez ödenen ders).
    /// ÇEKME MESAFESİ VİEWPORT'A ORANTILIDIR: `RefreshIndicator` tetiklenmek için görünür
    /// alanın ~%25'i kadar aşırı-kaydırma ister. Test yüzeyi 2400 piksel yüksek olduğu için
    /// 300 piksellik bir çekiş HİÇBİR ŞEY yapmıyordu (ilk denemede tam da bu oldu) — gerçek
    /// telefonda (~800 px) aynı jest yeterlidir.
    Future<void> asagiCek(WidgetTester tester) async {
      await tester.fling(find.byType(ListView), const Offset(0, 1200), 2000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('onYenile verilirse jest ÇAĞIRIR', (tester) async {
      var cagri = 0;
      await ekranaKoy(
        tester,
        SipGovde(
          onYenile: () async => cagri++,
          children: const [SizedBox(height: 400, child: Text('içerik'))],
        ),
      );

      await asagiCek(tester);

      expect(cagri, 1, reason: 'aşağı çekme gerçekten yenileme koşmalı');
      await kapat(tester);
    });

    testWidgets('kısa içerikte de çalışır — jest AlwaysScrollable ile açık', (tester) async {
      // Yenileme en çok BOŞ ekranda gerekiyor (yeni kurulum, senkron gelmemiş cihaz) ve
      // varsayılan fizik orada kaydırmayı tamamen kapatıyor.
      var cagri = 0;
      await ekranaKoy(
        tester,
        SipGovde(onYenile: () async => cagri++, children: const [Text('tek satır')]),
      );

      await asagiCek(tester);

      expect(cagri, 1);
      await kapat(tester);
    });
  });

  group('Ana ekran — Sürüm güncel çipi', () {
    Widget anaEkran(AppDatabase db) => AnaEkran(
          db: db,
          sahipAdi: 'Mehmet Usta',
          onMenu: () {},
          onSekme: (_) {},
          onYeniSiparis: () {},
          onArama: (_) {},
          onSiparisAc: (_) {},
          onBorclular: () {},
          onBildirimler: () {},
        );

    testWidgets('kontrol YAPILMAMIŞKEN çip çizilmez', (tester) async {
      // Hiç sorulmamış bir soruya "güncel" diye cevap vermek olurdu.
      guncellemeServisi.sonBasariliKontrol.value = null;
      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(tester, anaEkran(db));

      expect(find.text('Sürüm güncel'), findsNothing);
      await kapat(tester);
    });

    testWidgets('başarılı kontrolden sonra ve güncelleme YOKKEN çizilir', (tester) async {
      guncellemeServisi.sonBasariliKontrol.value = DateTime(2026, 7, 29, 10);
      guncellemeServisi.durum.value = GuncellemeDurumu.yok;
      addTearDown(() => guncellemeServisi.sonBasariliKontrol.value = null);

      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(tester, anaEkran(db));

      expect(find.text('Sürüm güncel'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('güncelleme BULUNDUYSA çip susar — bandı bırakır', (tester) async {
      // İki yüzey çelişemez: güncelleme varken "sürüm güncel" demek doğrudan yanlış bilgidir.
      guncellemeServisi.sonBasariliKontrol.value = DateTime(2026, 7, 29, 10);
      guncellemeServisi.durum.value = GuncellemeDurumu.bulundu;
      addTearDown(() {
        guncellemeServisi.sonBasariliKontrol.value = null;
        guncellemeServisi.durum.value = GuncellemeDurumu.yok;
      });

      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(tester, anaEkran(db));

      expect(find.text('Sürüm güncel'), findsNothing);
      await kapat(tester);
    });
  });

  group('Bento kutuları — ortalı düzen', () {
    testWidgets('etiket · değer · alt satır ORTALANIR', (tester) async {
      // Sola dayalı hâlde dört kutunun etiketi/rakamı farklı uzunlukta olduğu için ızgara
      // dört ayrı sol kenar üretiyordu ("yazılar ve rakamlar çok dağınık" — kullanıcı).
      final db = AppDatabase(NativeDatabase.memory());
      await ekranaKoy(
        tester,
        AnaEkran(
          db: db,
          sahipAdi: 'Bayi',
          onMenu: () {},
          onSekme: (_) {},
          onYeniSiparis: () {},
          onArama: (_) {},
          onSiparisAc: (_) {},
          onBorclular: () {},
          onBildirimler: () {},
        ),
      );

      final etiket = tester.widget<Text>(find.text('Açık Sipariş'));
      expect(etiket.textAlign, TextAlign.center);

      // Kutunun kendi sütunu da ortalı olmalı; yalnız metin hizası yetmez (kısa bir metin
      // ortalanmış görünse de sütunun içinde sola yapışık durur).
      final sutun = tester.widget<Column>(find.ancestor(
        of: find.text('Açık Sipariş'),
        matching: find.byType(Column),
      ).first);
      expect(sutun.crossAxisAlignment, CrossAxisAlignment.center);

      await kapat(tester);
    });
  });

  group('Sekme sözleşmesi', () {
    test('alt navigasyon dört sekme taşır (yenileme hiçbirini kaldırmadı)', () {
      expect(SipSekme.values, hasLength(4));
    });
  });
}
