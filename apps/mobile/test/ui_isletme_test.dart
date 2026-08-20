import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/repo/product_repository.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/isletme/gun_kapatma_sheet.dart';
import 'package:sipario/screens/isletme/gun_kapsami.dart';
import 'package:sipario/screens/products/product_form_sheet.dart';
import 'package:sipario/screens/products/product_list_screen.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/ekran_yardimcilari.dart';

/// SİPARİO 3.0 ÜRÜNLER + GÜN SONU ekranları. Ayar/yönetim ekranları (muaf telefonlar, işletme
/// profili, kuryeler, ayarlar, abonelik kilidi) `ui_isletme_ayarlar_test.dart` içinde — dosya
/// 500 satır sınırını aşınca bölündü. Paylaşılan yardımcılar `support/ekran_yardimcilari.dart`.
/// Ekrandan bağımsız kurallar `isletme_kurallari_test.dart` içinde.
void main() {
  // ═════════════════════════════════════════════════════════════════════════════════════════
  group('Ürünler', () {
    testWidgets('pasif ürün PASİF rozetiyle sönük çizilir ama fiyatı okunur kalır',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final repo = ProductRepository(db);
        await repo.create(name: 'Damacana 19 L', unitPriceKurus: 4500);
        final eski = await repo.create(name: 'Bardak su', unitPriceKurus: 500);
        await repo.deactivate(eski);
      });

      await ekranaKoy(tester, ProductListScreen(db: db, writable: true, rol: 'patron'));

      expect(find.text('PASİF'), findsOneWidget, reason: 'pasif ürün rozet taşır');
      expect(find.text(sipTutar(500)), findsOneWidget,
          reason: 'pasif ürünün fiyatı KAYBOLMAZ — bilgi geri plana düşer, silinmez');
      expect(find.text(sipTutar(4500)), findsOneWidget);

      // CSS `.urow.pasif { opacity: .55 }` — satır sönükleşir.
      final opaklik = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);
      expect(opaklik, contains(0.55), reason: 'pasif satır 0.55 opaklıkla çizilir');

      await kapat(tester);
    });

    testWidgets('formda girilen barkod ürünle birlikte kaydedilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await sheetAc(tester, (ctx) => urunFormuAc(ctx, db: db));

      // Alan sırası: ad · birim fiyat · barkod.
      //
      // BİRİM ARTIK BİR TextField DEĞİL (2026-08-11): serbest metin alanı açılır menüye
      // dönüştü, yani metin kutusu sayısı 4'ten 3'e düştü ve barkod bir indeks öne kaydı.
      // Testin eski hâli `at(3)` diyordu ve "index should be less than 3: 3" ile kırılıyordu —
      // indekse dayalı finder'ın bedeli budur: alan eklenip çıktıkça sessizce kayar.
      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'Damacana 19 L');
      await tester.enterText(alanlar.at(1), '45');
      await tester.enterText(alanlar.at(2), '8690123456789');
      await tester.pump();

      await dokun(tester, find.text('Kaydet'));

      final kayit = await tester.runAsync(
        () => (db.select(db.products)..where((t) => t.name.equals('Damacana 19 L')))
            .getSingleOrNull(),
      );
      expect(kayit, isNotNull);
      expect(kayit!.barcode, '8690123456789',
          reason: 'barkod artık gerçek kolona (Products.barcode) yazılır');
      expect(kayit.unitPriceKurus, 4500);

      await kapat(tester);
    });

    // Görsel seçici bir EKLENTİ ister (`image_picker`) ve o bağımlılık henüz pubspec'te yok;
    // form kodu bu yüzden `urunGorselSecici` kancasına yazıldı. Test kancayı doldurup ekranın
    // seçilen yolu cihaz-yerel kolona GERÇEKTEN yazdığını kanıtlar — eklenti gelince yalnız
    // kancanın bağlanması kalır.
    testWidgets('seçilen görsel imageLocalPath kolonuna yazılır (seçici kancası)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      urunGorselSecici = () async => '/veri/urun/damacana.jpg';
      addTearDown(() => urunGorselSecici = null);

      await sheetAc(tester, (ctx) => urunFormuAc(ctx, db: db));

      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'Damacana 19 L');
      await tester.enterText(alanlar.at(1), '45');
      await tester.pump();

      expect(find.text('Görsel Ekle'), findsOneWidget);
      await dokun(tester, find.text('Görsel Ekle'));
      expect(find.text('Görsel yüklendi'), findsOneWidget,
          reason: 'seçim sonrası önizleme metni değişir (tasarım .uf-gorsel-not)');
      expect(find.text('Kaldır'), findsOneWidget,
          reason: '"Kaldır" ancak görsel varken anlamlıdır — eskiden hiç erişilemiyordu');

      await dokun(tester, find.text('Kaydet'));

      final kayit = await tester.runAsync(
        () => (db.select(db.products)..where((t) => t.name.equals('Damacana 19 L')))
            .getSingleOrNull(),
      );
      expect(kayit?.imageLocalPath, '/veri/urun/damacana.jpg',
          reason: 'yol cihaz-yerel kolona yazılır (senkronlanmaz)');

      await kapat(tester);
    });

    testWidgets('seçici bağlı değilken bilgilendirme çıkar, form bozulmaz', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      urunGorselSecici = null;

      await sheetAc(tester, (ctx) => urunFormuAc(ctx, db: db));
      await dokun(tester, find.text('Görsel Ekle'));

      expect(find.textContaining('cihaz galerisi eklentisiyle gelecek'), findsOneWidget);
      expect(find.text('Görsel yüklendi'), findsNothing,
          reason: 'seçim olmadan "yüklendi" yazmak yalan olurdu');

      await kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // Ekran artık `rol`/`kullaniciId` alıyor ve kapatma kapısını KENDİ tutuyor (ayrı kasa devri
  // ekranı kaldırılınca kurye trafiği de buraya geliyor, kabuk önünde kapı tutmuyor). Yönetici
  // davranışını sınayan testler bu yüzden rolü AÇIKÇA veriyor: `rol` verilmediğinde ekran
  // "yetki bilinmiyor" sayar ve hiçbir kapatma sunmaz (permissive değil — K2).
  group('Gün sonu', () {
    testWidgets('açık sipariş varken kapatma engellenir ve uyarı çıkar', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Ayşe');
        await OrderRepository(db).create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 1)],
        );
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      // CSS `.gs-engel`
      expect(find.text('Önce açık siparişleri kapatın: 1 açık sipariş var.'), findsOneWidget);

      final kapatDugmesi = tester.widget<SipButon>(
        find.widgetWithText(SipButon, 'Günü Kapat'),
      );
      expect(kapatDugmesi.onTap, isNull,
          reason: 'açık sipariş varken kapat düğmesi devre dışıdır');

      await kapat(tester);
    });

    testWidgets('kurye hesaplarının BİR KISMI kapalıyken gün kapatılamaz', (tester) async {
      // Tasarım `gunEngel` (s-gunsonu.jsx): yarım kalmış devir. İki aktif kurye var, biri
      // hesabını kapattı; gün şimdi kapatılırsa Ali'nin kasası mutabakatsız kalırdı.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await kuryeEkle(db, id: 'k2', ad: 'Ali');
        await DayClosingRepository(db).kapat(
          scope: ClosingScope.courier,
          userId: 'k1',
          countedCashKurus: 0,
        );
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.text('Önce açık kurye hesaplarını kapatın: Ali'), findsOneWidget);
      final dugme = tester.widget<SipButon>(find.widgetWithText(SipButon, 'Günü Kapat'));
      expect(dugme.onTap, isNull, reason: 'yarım kalmış devirde gün kapatılamaz');

      await kapat(tester);
    });

    testWidgets('hiçbir kurye hesabı kapanmamışsa gün DOĞRUDAN kapatılabilir', (tester) async {
      // Karşı-kanıt: engel "kurye var" diye değil, "bir kısmı kapandı" diye çıkar. Kurye
      // hesaplarını hiç kullanmayan bayi gün sonunu tek dokunuşta kapatabilmeli.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await kuryeEkle(db, id: 'k2', ad: 'Ali');
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.textContaining('Önce açık kurye hesaplarını'), findsNothing);
      final dugme = tester.widget<SipButon>(find.widgetWithText(SipButon, 'Günü Kapat'));
      expect(dugme.onTap, isNotNull);

      await kapat(tester);
    });

    // Segment tasarımda (`s-gunsonu.jsx:37-41`) KOŞULSUZ çizilir. Eskiden "en az iki seçenek"
    // kapısı vardı: tek kuryeli (ya da kuryesiz) bayide şerit hiç görünmüyor, kapsam kavramının
    // varlığı keşfedilemiyordu.
    testWidgets('kapsam segmenti kurye yokken de çizilir; alt bilgi satırı YOK', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.text('Tümü'), findsOneWidget,
          reason: 'kurye olmasa da kapsam şeridi görünür');
      expect(find.text('Rakamlar defterden türetilir.'), findsNothing,
          reason: 'tasarımda böyle bir alt bilgi yok — ekran kendini açıklamaz');

      await kapat(tester);
    });

    testWidgets('arşiv satırı GÜN + saat yazar (çok günlük arşivde satırlar ayrışsın)',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await DayClosingRepository(db).kapat(
          scope: ClosingScope.courier,
          userId: 'k1',
          countedCashKurus: 0,
        );
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(
        find.textContaining(RegExp(r'^Bugün \d{2}:\d{2} · \d+ teslimat')),
        findsOneWidget,
        reason: 'yalnız saat basılınca iki günün kapanışı aynı görünüyordu (tasarım {a.tarih})',
      );

      await kapat(tester);
    });

    // Ayrı kasa devri ekranı kaldırılınca çekmecenin "Kasa Devri" satırı bu ekrana bağlandı:
    // ekran artık KURYE trafiği alıyor, dolayısıyla rol kapısı ve kapsam ön seçimi BURADA.
    testWidgets('kurye kendi kapsamında açılır ve hesabını KAPATAMAZ', (tester) async {
      // DAVRANIŞ 2026-08-11'DE TERSİNE ÇEVRİLDİ (kullanıcı kararı): kurye eskiden kendi
      // kapsamını kapatabiliyordu ("kendi kasasının kanıtı odur"). Kapanış geri alınamaz bir
      // mutabakattır ve arşive donar; yanlış sayımla kapatan kuryenin bıraktığı farkı ertesi
      // gün patron çözemez. Kapatan taraf artık yalnız yöneticidir.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await kuryeEkle(db, id: 'k2', ad: 'Ali');
      });

      await ekranaKoy(
        tester,
        DayEndScreen(db: db, rol: 'kurye', kullaniciId: 'k1'),
      );

      expect(find.text('Kasa Özeti · Emre'), findsOneWidget,
          reason: 'kurye "Tümü"de değil KENDİ kapsamında açılır (çekmeceden Kasa Devri geldi)');
      expect(find.text('Ali'), findsNothing,
          reason: 'kurye başka kuryenin kapsamını segmentte GÖRMEZ (K2)');
      expect(find.text('Açık Veresiye'), findsNothing,
          reason: 'açık veresiye dökümü yalnız gün kapsamında çizilir');

      final dugme = tester.widget<SipButon>(find.widgetWithText(SipButon, 'Hesabı Kapat'));
      expect(dugme.onTap, isNull, reason: 'kapatma yalnız yöneticidedir (2026-08-11)');
      expect(
        find.text('Hesabı yönetici kapatır. Siz günlük tahsilat ve teslimat dökümünüzü '
            'görebilirsiniz.'),
        findsOneWidget,
        reason: 'sessizce devre dışı bir düğme sebebini söylemeli',
      );

      await kapat(tester);
    });

    testWidgets('kurye segmentte "Tümü"yü HİÇ göremez — gün hesabı ona kapalıdır',
        (tester) async {
      // Şikâyetin kendisi buydu (kullanıcı 2026-08-11): "kurye genel raporu görüyor".
      // "Tümü" seçeneği kuryede artık ÜRETİLMİYOR; tek kapsamı kaldığı için segment de
      // çizilmiyor (dokunulunca hiçbir şey değiştirmeyen ölü kontrol sunulmaz).
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await kuryeEkle(db, id: 'k2', ad: 'Ali');
      });

      await ekranaKoy(
        tester,
        DayEndScreen(db: db, rol: 'kurye', kullaniciId: 'k1'),
      );

      expect(find.text('Tümü'), findsNothing, reason: 'gün hesabı kuryeye kapalı');
      expect(find.byType(SipSegment), findsNothing, reason: 'tek kapsamda segment çizilmez');
      expect(find.text('Kasa Özeti · Emre'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('yönetici "Tümü"de açılır ve tüm kuryeleri seçebilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await kuryeEkle(db, id: 'k2', ad: 'Ali');
      });

      await ekranaKoy(
        tester,
        DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'),
      );

      expect(find.text('Kasa Özeti'), findsOneWidget, reason: 'gün kapsamı');
      final dugme = tester.widget<SipButon>(find.widgetWithText(SipButon, 'Günü Kapat'));
      expect(dugme.onTap, isNotNull);

      // KAPSAM ARTIK AÇILIR LİSTE (2026-08-20): ekipte kim olduğu şeritte değil, seçici
      // açıldığında görünür. Seçici kapalıyken YALNIZ seçili kapsamın adı yazar.
      expect(find.text('Tümü'), findsOneWidget, reason: 'yönetici gün hesabıyla açılır');
      expect(find.text('Emre · Kurye'), findsNothing, reason: 'liste kapalıyken ad yazmaz');

      await tester.tap(find.byType(GunKapsamSecici));
      await sheetAnimasyonu(tester);

      // ÜÇ KATMAN: gün geneli · kendi işlerim · elemanlar, sonra kişi kişi herkes.
      expect(find.text('Kendi işlemlerim'), findsOneWidget);
      expect(find.text('Elemanlar'), findsOneWidget);
      expect(find.text('Emre · Kurye'), findsOneWidget);
      expect(find.text('Ali · Kurye'), findsOneWidget);
      // Patron kendi satırını "Kendi işlemlerim" olarak görür — ikinci kez adıyla listelenmez.
      expect(find.text('Patron · Patron'), findsNothing);

      await kapat(tester);
    });

    testWidgets('kapatma sheet: fark eksi iken bile "Kapat ve Arşivle" ETKİN kalır',
        (tester) async {
      // BRIEF kırmızı çizgisi: eksik para GÖRÜNÜR kalmalı — engelleme YOK.
      await sheetAc(
        tester,
        (ctx) => gunKapatmaSheet(
          ctx,
          kapsamAdi: 'Gün hesabı',
          gunHesabi: true,
          beklenen: 24000,
          teslimat: 3,
        ),
      );

      await tester.enterText(find.byType(TextField).first, '200');
      await akislariBekle(tester, tur: 2);

      expect(find.text('EKSİK'), findsOneWidget, reason: 'CSS .kd-fark eksik şeridi');
      expect(find.text('Eksik tutar kanıt olarak arşive geçer; kapatma engellenmez.'),
          findsOneWidget);

      final dugme = tester.widget<SipButon>(
        find.widgetWithText(SipButon, 'Kapat ve Arşivle'),
      );
      expect(dugme.onTap, isNotNull, reason: 'fark ≠ 0 kapatmayı ENGELLEMEZ');

      await kapat(tester);
    });
  });

}
