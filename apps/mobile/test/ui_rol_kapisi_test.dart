import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/isletme/atomlar/rol_kapisi.dart';
import 'package:sipario/screens/products/product_list_screen.dart';

import 'support/siparis_yardimci.dart';

/// ROL KAPISI (`YoneticiKapisi`) — K2 kuralının EKRAN İÇİ ikinci savunması.
///
/// NEDEN VAR (kod borcu #9, 2026-08-17): kapı dört ekranı koruyor (`Ürünler`, `Kuryeler`,
/// `Muaf Telefonlar`, `Kurye Yetkileri`) ve TEK BİR testi yoktu. Çekmece bu girişleri zaten
/// gizliyor; kapının varlık sebebi çekmecenin GEÇİLDİĞİ hâllerdir (derin bağlantı, geri
/// yığınında kalmış rota, rol oturum ortasında değişmesi). Yani kapı, testi olmadığı sürece
/// tam da "kimsenin bakmadığı yolda" sessizce açık kalabilecek türden bir savunmaydı.
///
/// `yetki_matrisi_test.dart` matrisin HESABINI kilitler; bu dosya kapının çizimini kilitler.
void main() {
  group('YoneticiKapisi — kimin geçtiği', () {
    /// Kapının ardındaki içerik: geçtiyse bu metin ekranda olur.
    const icerik = Text('KORUNAN ICERIK', textDirection: TextDirection.ltr);

    testWidgets('KURYE geçemez — içerik hiç çizilmez', (tester) async {
      await tester.pumpWidget(
          sipKabuk(const YoneticiKapisi(rol: 'kurye', baslik: 'Ürünler', child: icerik)));
      await tester.pump();

      expect(find.text('KORUNAN ICERIK'), findsNothing,
          reason: 'kapı kapalıyken çocuk ağaca HİÇ girmemeli — gizlemek yetmez');
      expect(find.text('Bu ekran yöneticilere açık'), findsOneWidget);
    });

    testWidgets('patron ve operatör geçer', (tester) async {
      for (final rol in ['patron', 'operator']) {
        await tester.pumpWidget(
            sipKabuk(YoneticiKapisi(rol: rol, baslik: 'Ürünler', child: icerik)));
        await tester.pump();
        expect(find.text('KORUNAN ICERIK'), findsOneWidget, reason: '$rol geçebilmeli');
      }
    });

    testWidgets('kapı KAPALIYKEN ekranın kendi başlığı korunur (geri düğmesi kaybolmaz)',
        (tester) async {
      // Kapalı kapı, ekranın `SipUst`unu da yutar; yerine `SipUstYerine` çizilir. Başlık ve
      // geri düğmesi olmasaydı kurye o rotada KİLİTLİ kalırdı — çıkmak için uygulamayı
      // öldürmesi gerekirdi.
      await tester.pumpWidget(
          sipKabuk(const YoneticiKapisi(rol: 'kurye', baslik: 'Muaf Telefonlar', child: icerik)));
      await tester.pump();

      expect(find.text('Muaf Telefonlar'), findsOneWidget);
      expect(find.bySemanticsLabel('Geri'), findsOneWidget);
    });

    testWidgets('başlık verilmezse "Yetki yok" yazar', (tester) async {
      await tester.pumpWidget(sipKabuk(const YoneticiKapisi(rol: 'kurye', child: icerik)));
      await tester.pump();
      expect(find.text('Yetki yok'), findsOneWidget);
    });

    testWidgets('gerekçe METNİ gösterilir — sessiz boş ekran değil', (tester) async {
      // Sessiz bir boş ekran, sahada "uygulama bozuk" olarak rapor edilir. Metin sözleşmedir.
      await tester.pumpWidget(sipKabuk(const YoneticiKapisi(rol: 'kurye', child: icerik)));
      await tester.pump();
      expect(
        find.text('Kurye hesabıyla ürün, kurye ve muaf numara yönetimi görülemez.'),
        findsOneWidget,
      );
    });
  });

  group('YoneticiKapisi.acik — kapının saf kuralı', () {
    test('yalnız TANINAN yönetici rolleri açar', () {
      expect(const YoneticiKapisi(rol: 'patron', child: SizedBox()).acik, isTrue);
      expect(const YoneticiKapisi(rol: 'operator', child: SizedBox()).acik, isTrue);
      expect(const YoneticiKapisi(rol: 'kurye', child: SizedBox()).acik, isFalse);
    });

    test('ROL BİLİNMİYORSA kapı KAPALIDIR — matrisle aynı yöne bakar (2026-08-17)', () {
      // ⚠️ DAVRANIŞ DEĞİŞTİ. Eskiden kural `rol != 'kurye'` idi ve null'da AÇILIYORDU; oysa aynı
      // soruya cevap veren `yetkiler(rol: null)` EN DAR kümeyi (kurye) veriyor. İki kural aynı
      // soruya ters cevap veriyordu.
      //
      // Açık üretmesini çekmecenin aynı ölçütü kullanması engelliyordu — ama kapı tam olarak
      // "ÇEKMECE ATLANDIĞINDA" (derin bağlantı, geri yığını) korumak için var; yani korumasının
      // gerektiği tek senaryoda korumuyordu. Uygulanan ilke deponun kendi yazılı kuralı:
      // belirsizlikte AÇILAN değil KAPANAN taraf seçilir.
      //
      // PRATİK SONUÇ: oturum açılmış ama ilk senkron inmemişken bu dört ekran kapalı görünür;
      // rol indiği anda ekran yeniden çizilir ve açılır. Kapalı bir ekranı bir saniye sonra
      // açmak, açık bir ekranı yetkisiz birine göstermekten iyidir.
      expect(const YoneticiKapisi(rol: null, child: SizedBox()).acik, isFalse);
      expect(const YoneticiKapisi(rol: '', child: SizedBox()).acik, isFalse);
      expect(const YoneticiKapisi(rol: 'KURYE', child: SizedBox()).acik, isFalse,
          reason: 'eşleşme birebir küçük harf — sunucu sözleşmesi budur');
      expect(const YoneticiKapisi(rol: 'yeni_rol', child: SizedBox()).acik, isFalse,
          reason: 'sunucu ileride yeni bir rol gönderirse kapı KAPALI kalır (izin listesi)');
    });
  });

  group('kapı GERÇEK ekrana bağlı mı — ProductListScreen', () {
    // Kapının kendi testi geçse bile ekranların onu SARMASI ayrı bir gerçektir; `rol` alanı
    // eklenip kapı unutulsaydı yukarıdaki testlerin hepsi yeşil kalırdı.
    testWidgets('kurye Ürünler ekranını açamaz', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
          sipKabuk(ProductListScreen(db: db, writable: true, rol: 'kurye')));
      await akisiBekle(tester);

      expect(find.text('Bu ekran yöneticilere açık'), findsOneWidget);
      expect(find.text('Ürünler'), findsOneWidget, reason: 'kapalı kapı başlığı');

      await ekraniKapat(tester);
    });

    testWidgets('patron Ürünler ekranını açar', (tester) async {
      genisYuzey(tester);
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
          sipKabuk(ProductListScreen(db: db, writable: true, rol: 'patron')));
      await akisiBekle(tester);

      expect(find.text('Bu ekran yöneticilere açık'), findsNothing);

      await ekraniKapat(tester);
    });
  });
}
