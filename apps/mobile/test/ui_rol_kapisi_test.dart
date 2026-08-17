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
    test('yalnız "kurye" kapatır', () {
      expect(const YoneticiKapisi(rol: 'kurye', child: SizedBox()).acik, isFalse);
      expect(const YoneticiKapisi(rol: 'patron', child: SizedBox()).acik, isTrue);
      expect(const YoneticiKapisi(rol: 'operator', child: SizedBox()).acik, isTrue);
    });

    test('ROL BİLİNMİYORSA kapı AÇIKTIR — ölçülmüş davranış, matristen AYRIŞIR', () {
      // ⚠️ Kayda geçiyoruz: `yetkiler(rol: null)` KURYE kümesini verir (en dar taraf), kapı ise
      // `rol != 'kurye'` dediği için null'da AÇILIR. İki kural aynı soruya farklı cevap verir.
      //
      // Bugün bir açık üretmiyor çünkü bu dört ekrana giden tek yol çekmecedir ve çekmece de
      // aynı `rol == 'kurye'` ölçütünü kullanır — yani rol inmemişken çekmece girişleri de
      // gizlidir. Ama kapının VARLIK SEBEBİ "çekmece atlandığında" korumaktı; o senaryoda
      // (derin bağlantı) rol henüz inmemişse koruma yoktur.
      //
      // Bu test MEVCUT davranışı kilitler, doğrulamaz. Kural değiştirilirse burası kırmızı
      // yanar ve kararın bilinçli olduğu görülür.
      expect(const YoneticiKapisi(rol: null, child: SizedBox()).acik, isTrue);
      expect(const YoneticiKapisi(rol: '', child: SizedBox()).acik, isTrue);
      expect(const YoneticiKapisi(rol: 'KURYE', child: SizedBox()).acik, isTrue,
          reason: 'eşleşme birebir küçük harf — sunucu sözleşmesi budur');
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
