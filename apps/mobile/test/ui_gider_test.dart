// GİDER EKLEME — EKRAN (kullanıcı isteği 2026-08-25).
//
// *"Ek olarak bu sayfada Gider Ekleme özelliği de olmalı."* Yetki matrisinde "Saha Gideri Girme
// (Benzin vb. — Benzin, tamir gibi masrafları kasadan düşer)" satırı aylardır vardı ama ÜRÜNDE
// KARŞILIĞI YOKTU: yetkiyi açan bayi hiçbir şey açmıyordu.
//
// Burada çivilenen kararlar:
//  1. GİDER YETKİSİ AYRI BİR ANAHTARDIR (`sahaGideri`), kapatma/ara tahsilatın `gunuKapatma`
//     anahtarı DEĞİL. Gerekçe matrisin kendisidir: benzini yolda alan kişi kuryedir ve kaydı
//     ondan istemek, akşamki farkın tek açıklamasıdır. Varsayılan yine de KAPALI.
//  2. GİDER YALNIZ BUGÜNE YAZILIR: geçmiş bir güne bugünün parasını yazmak, kapanmış ya da
//     kapanmaya hazır bir günün kasasını geriye dönük değiştirmek olurdu.
//  3. KAPANMIŞ KAPSAMDA yol kapalıdır — kapanış o anın gerçeğini dondurur.
//  4. "Elemanlar" kapsamında düğme ÇİZİLMEZ: gider tek bir kişiye yazılır ve o kapsam birden
//     çok kişiyi kapsıyor; parayı hangi cepten düşeceğimizi bilmeden yazamayız.
//  5. Kayıt SEÇİLİ KAPSAMA yazılır (kişi kapsamında o kişiye, gün hesabında oturumdaki
//     kullanıcıya) — ayrı bir "kim harcadı" seçicisi YOK.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/gider_repository.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/isletme/gun_kapsami.dart';
import 'package:sipario/screens/team.dart' show KuryeIzinleri;
import 'package:sipario/theme/app_theme.dart';

import 'support/ara_tahsilat_yardimcilari.dart';
import 'support/ekran_yardimcilari.dart';
import 'support/kabuk_yardimcilari.dart' show semantikDugme;

void main() {
  /// Ekranı patron olarak açar; kasada 90,00 ₺ nakit vardır.
  Future<AppDatabase> nakitliEkran(WidgetTester tester, {String? rol = 'patron'}) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
      await kuryeEkle(db, id: 'k1', ad: 'Emre');
      await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
    });
    await ekranaKoy(
      tester,
      DayEndScreen(db: db, rol: rol, kullaniciId: rol == 'kurye' ? 'k1' : 'p1'),
    );
    await akislariBekle(tester, tur: 6);
    return db;
  }

  /// Gider sheet'ini açar, tutarı ve açıklamayı yazıp kaydeder.
  Future<void> giderYaz(WidgetTester tester, String tutar, {String? aciklama}) async {
    await tester.tap(find.text('Gider Ekle'));
    await sheetAnimasyonu(tester);
    await tester.enterText(find.byType(TextField).first, tutar);
    await akislariBekle(tester);
    if (aciklama != null) {
      await tester.enterText(find.byType(TextField).at(1), aciklama);
      await akislariBekle(tester);
    }
    await dokun(tester, find.text('Gideri Kaydet'));
    await sheetAnimasyonu(tester);
    await akislariBekle(tester, tur: 6);
  }

  group('Yetki kapısı — `sahaGideri`', () {
    testWidgets('PATRON düğmeyi görür', (tester) async {
      await nakitliEkran(tester);
      expect(find.text('Gider Ekle'), findsOneWidget);
      await kapat(tester);
    });

    testWidgets('KURYE varsayılan ayarda düğmeyi GÖREMEZ', (tester) async {
      // `KuryeIzinleri.sahaGideri` varsayılanı PASİFTİR: kurye kendi yazdığı bir giderle kasadaki
      // eksiği açıklayabilir, yani yetki güvene bağlıdır ve kapalı başlar.
      await nakitliEkran(tester, rol: 'kurye');
      expect(find.text('Gider Ekle'), findsNothing);
      await kapat(tester);
    });

    testWidgets('KURYE yetki açıkken düğmeyi görür', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      });
      await ekranaKoy(
        tester,
        DayEndScreen(
          db: db,
          rol: 'kurye',
          kullaniciId: 'k1',
          kuryeIzin: const KuryeIzinleri(sahaGideri: true),
        ),
      );
      await akislariBekle(tester, tur: 6);

      expect(find.text('Gider Ekle'), findsOneWidget);
      await kapat(tester);
    });
  });

  group('Akış', () {
    testWidgets('gider kaydedilir; kasa kartına satır düşer, net nakit azalır',
        (tester) async {
      final db = await nakitliEkran(tester);

      expect(find.text('Gider yazılmadı'), findsOneWidget, reason: 'sıfır hâli de yazılır');

      await giderYaz(tester, '20', aciklama: 'Yakıt');

      // KASA KARTI: tahsilat DEĞİŞMEZ, gider ayrı satırda ve NEGATİF işaretle yazılır.
      expect(find.text('Toplam tahsilat (1 teslimat)'), findsOneWidget);
      expect(find.text('Gider (kasadan çıktı)'), findsOneWidget);
      expect(find.text('Kasadan çıkan'), findsOneWidget, reason: 'bölüm başlığı da değişir');

      // DEFTERE GERÇEKTEN YAZILDI ve atıf oturumdaki kullanıcıya düştü (gün hesabı kapsamı).
      final satirlar = await tester.runAsync(() => (db.select(db.ledgerEntries)
            ..where((t) => t.entryType.equals('expense')))
          .get());
      expect(satirlar, hasLength(1));
      expect(satirlar!.single.amountKurus, 2000, reason: 'POZİTİF = kasadan çıkan');
      expect(satirlar.single.note, 'Yakıt');
      expect(satirlar.single.collectedByUserId, 'p1');
      expect(satirlar.single.paymentType, 'nakit');

      await kapat(tester);
    });

    testWidgets('KİŞİ kapsamında gider O KİŞİYE yazılır', (tester) async {
      // Ayrı bir "kim harcadı" seçicisi YOK: patron Emre'nin benzinini yazmak istiyorsa kapsamı
      // Emre'ye çevirir — ondan ara tahsilat alırken yaptığı hareketin aynısı.
      final db = await nakitliEkran(tester);

      await tester.tap(find.byType(GunKapsamSecici));
      await sheetAnimasyonu(tester);
      await tester.tap(find.text('Emre (Kurye)'));
      await akislariBekle(tester, tur: 6);

      await giderYaz(tester, '15', aciklama: 'Yakıt');

      final satirlar = await tester.runAsync(() => (db.select(db.ledgerEntries)
            ..where((t) => t.entryType.equals('expense')))
          .get());
      expect(satirlar!.single.collectedByUserId, 'k1',
          reason: 'para Emre\'nin cebinden çıktı; akşam onun kasası eksik olacak');

      await kapat(tester);
    });

    testWidgets('İPTAL onay ister ve satırı ÜSTÜ ÇİZİLİ bırakır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
        await nakitTeslim(db, kuryeId: 'p1', tutarKurus: 9000);
        await GiderRepository(db).ekle(kurus: 2000, aciklama: 'Yakıt', harcayanId: 'p1');
      });
      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await akislariBekle(tester, tur: 6);

      // Döküm KAPALI başlar (özet bir özettir); satıra ulaşmak için açılır.
      await tester.tap(find.text('Kasadan çıkan'));
      await akislariBekle(tester, tur: 6);
      expect(find.text('Yakıt'), findsOneWidget);

      await tester.tap(find.text('Yakıt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await akislariBekle(tester);

      expect(find.text('Gider iptal edilsin mi?'), findsOneWidget,
          reason: 'kazara dokunuş kalıcı bir düzeltme kaydı yazardı');

      await tester.tap(find.text('İptal Et'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await akislariBekle(tester, tur: 8);

      // KAYIT SİLİNMEDİ: ters işaretli ikinci bir satır yazıldı (kırmızı çizgi #2).
      final satirlar = await tester.runAsync(() => (db.select(db.ledgerEntries)
            ..where((t) => t.entryType.equals('expense')))
          .get());
      expect(satirlar, hasLength(2));
      expect(satirlar!.where((e) => e.amountKurus == -2000), hasLength(1));

      // Kasa kartındaki gider satırı KAYBOLUR: fiilen çıkan para sıfırlandı.
      expect(find.text('Gider (kasadan çıktı)'), findsNothing);
      expect(find.text('Gider yazılmadı'), findsOneWidget);

      await kapat(tester);
    });
  });

  group('Kapılar — düğme HİÇ çizilmez', () {
    testWidgets('GEÇMİŞ günde yol kapalıdır', (tester) async {
      await nakitliEkran(tester);
      expect(find.text('Gider Ekle'), findsOneWidget);

      await tester.tap(semantikDugme('Önceki gün'));
      await akislariBekle(tester, tur: 6);

      expect(find.text('Gider Ekle'), findsNothing,
          reason: 'geçmiş bir güne bugünün parası yazılamaz');
      await kapat(tester);
    });

    testWidgets('GÜN KAPANDIYSA yol kapalıdır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
        await nakitTeslim(db, kuryeId: 'p1', tutarKurus: 9000);
        await DayClosingRepository(db)
            .kapat(scope: ClosingScope.day, countedCashKurus: 9000);
      });
      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await akislariBekle(tester, tur: 6);

      expect(find.text('Gider Ekle'), findsNothing,
          reason: 'kapanış o anın gerçeğini dondurur');
      await kapat(tester);
    });

    testWidgets('"ELEMANLAR" kapsamında yol kapalıdır', (tester) async {
      // Kapsam birden çok kişiyi kapsıyor; gider tek bir cepten düşer ve hangisinden düşeceğini
      // bilmeden yazmak, rastgele birinin kasasını eksiltmek olurdu.
      await nakitliEkran(tester);

      await tester.tap(find.byType(GunKapsamSecici));
      await sheetAnimasyonu(tester);
      await tester.tap(find.text('Elemanlar'));
      await akislariBekle(tester, tur: 6);

      expect(find.text('Gider Ekle'), findsNothing);
      await kapat(tester);
    });
  });

  group('Yerleşim', () {
    testWidgets('DAR EKRANDA taşma yok — tepe bloğu ve üç kutu sığar', (tester) async {
      // ⚠️ BU BİR CİHAZ KANITI DEĞİL, PROVADIR: widget testinin varsayılan yazı tipi gerçek
      // cihazdakinden ~1.8 kat geniştir (bu depoda yazılı ders). Yani buradaki yeşil "ucu ucuna
      // sığar" değil "rahat sığar" demektir; kırmızı ise gerçek bir darlıktır.
      //
      // NEDEN GEREKLİ: bu turda ekrana iri puntolu bir tepe bloğu ve YAN YANA üç istatistik
      // kutusu eklendi. Paylaşılan `ekranaKoy` 800 punto genişlikte çiziyor ve orada hiçbir
      // darlık görünmez — sahadaki telefon 360'tır.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        // Altı haneli tutar: rakam ne kadar uzarsa kutular o kadar zorlanır.
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 12345678);
        await GiderRepository(db).ekle(kurus: 987654, aciklama: 'Yakıt', harcayanId: 'p1');
      });

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: SipTheme.acik(),
        home: DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'),
      ));
      await akislariBekle(tester, tur: 8);

      expect(tester.takeException(), isNull, reason: 'RenderFlex taşması ya da başka çizim hatası');
      // Tepe bloğu gerçekten çizildi (boş bir ekranda "taşma yok" demek anlamsız olurdu).
      // Etiket `trBuyuk` ile büyütülür: Dart'ın `toUpperCase()`i 'i' harfini 'I' yapar ve
      // ekranda "KASADA OLMASI GEREKEN" yerine yanlış bir yazım çıkardı.
      expect(find.text('KASADA OLMASI GEREKEN'), findsOneWidget);
      expect(find.text('Gider'), findsOneWidget, reason: 'gider varken alt satırda yazar');

      await kapat(tester);
    });
  });
}
