// ARA TAHSİLAT + KALAN NAKİT (kullanıcı kararı 2026-08-06).
//
// "Ara tahsilat: sayımlı serbest tutar, gün açık kalır · kapanışta beklenen = KALAN nakit ·
// patron her kuryeden alır, kurye yalnız kendi kasasını · tek kişilik bayide hiç görünmez."
//
// Burada çivilenen kararlar:
//  1. Ekranın adı "Gün Özeti"dir (iç tanımlayıcılar `gunSonu` / `day_end_*` DEĞİŞMEZ).
//  2. Ara tahsilat düğmesi YETKİ + KAPSAM + KİLİT üçlü kapısından geçer; kapı kapalıysa düğme
//     PASİF değil HİÇ ÇİZİLMEZ.
//  3. Tahsilat sonrası gün AÇIK kalır (kapanış kaydı yazılmaz) ve özet satırı belirir.
//  4. Kapanış sheet'i ÜÇ SAYIYI birlikte gösterir: günün nakdi · gün içinde alınan · beklenen.
//     Yoksa bayi her gün açıklanamayan bir eksik görürdü (BRIEF: rakamlar elle tutulan defterle
//     tutmazsa ürüne güven ölür). "Gün içinde alınan" ARA ve KAPANIŞ devirlerini BİRLİKTE kapsar
//     ve etiketi bunu iddia etmez — ara tahsilat hiç alınmamış bir günde de çizilir.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/isletme/gun_sonu_ozet.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/ekran_yardimcilari.dart';

/// Kuryenin NAKİT tahsil ettiği bir teslimat — ara tahsilatın beklediği para budur.
Future<void> nakitTeslim(
  AppDatabase db, {
  required String kuryeId,
  required int tutarKurus,
  String musteri = 'Ayşe',
}) async {
  final cid = await CustomerRepository(db).create(name: musteri);
  final oid = await OrderRepository(db).create(
    customerId: cid,
    lines: [LineInput(productName: 'Damacana', unitPriceKurus: tutarKurus, qty: 1)],
  );
  await OrderRepository(db).assign(oid, kuryeId);
  await OrderRepository(db)
      .deliver(oid, paymentType: 'nakit', collectedByUserId: kuryeId);
}

/// Kurye kapsamına geçer (segmentteki kurye adına dokunur).
Future<void> kapsamaGec(WidgetTester tester, String kuryeAdi) async {
  await tester.tap(find.text(kuryeAdi));
  await akislariBekle(tester, tur: 6);
}

void main() {
  group('Adlandırma — "Gün Sonu" → "Gün Özeti"', () {
    testWidgets('ekran başlığı "Gün Özeti" yazar', (tester) async {
      // Metin SÖZLEŞMEDİR: kullanıcıya görünen her yerde ad değişti, iç tanımlayıcılar
      // (`gunSonu` yetki anahtarı, `day_end_*` tabloları, dosya/sınıf adları) DEĞİŞMEDİ.
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.text('Gün Özeti'), findsWidgets);
      expect(find.text('Gün Sonu'), findsNothing);

      await kapat(tester);
    });

    testWidgets('başlıkta "Geçmiş" düğmesi durur — gövdede geçmiş listesi YOK', (tester) async {
      // Geçmiş ayrı ekrana taşındı: bu ekranın işi BUGÜNDÜR ve geçmiş listesi onu her açılışta
      // aşağı itiyordu.
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.text('Geçmiş'), findsOneWidget, reason: 'başlıktaki düğme');
      expect(find.textContaining('Henüz geçmiş gün yok'), findsNothing,
          reason: 'gövdedeki geçmiş listesi kaldırıldı');

      await kapat(tester);
    });
  });

  group('Ara tahsilat — yetki kapıları (K2)', () {
    test('TEK KİŞİLİK bayide `araTahsilatMumkun` FALSE — bayrağın kendisi', () async {
      // Ekranın kapısı bu bayrağa DOĞRUDAN bağlı. "Segmentte kurye yok → _kuryeId hep null"
      // zinciri dolaylıdır ve segment bir gün değişince sessizce kırılırdı; o yüzden hem bayrağı
      // hem sonucunu ayrı ayrı kilitliyoruz.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final g = await gunSonuGorunumu(db, bugunTr());
      expect(g.araTahsilatMumkun, isFalse, reason: 'aktif kurye yok');
    });

    test('AKTİF KURYE varken `araTahsilatMumkun` TRUE olur', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await kuryeEkle(db, id: 'k1', ad: 'Emre');

      final g = await gunSonuGorunumu(db, bugunTr());
      expect(g.araTahsilatMumkun, isTrue);
    });

    test('GÜN kapandıysa `araTahsilatMumkun` FALSE olur', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await kuryeEkle(db, id: 'k1', ad: 'Emre');
      await DayClosingRepository(db)
          .kapat(scope: ClosingScope.day, countedCashKurus: 0);

      final g = await gunSonuGorunumu(db, bugunTr());
      expect(g.araTahsilatMumkun, isFalse);
    });

    testWidgets('TEK KİŞİLİK bayide düğme HİÇ çizilmez', (tester) async {
      // Aktif kurye yoksa "kuryeden ara tahsilat" diye bir kavram yoktur — patron parayı zaten
      // cebinde taşır. Pasif bir düğme, olmayan bir iş akışını varmış gibi gösterirdi.
      final db = AppDatabase(NativeDatabase.memory());

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(find.text('Ara Tahsilat'), findsNothing);
      expect(find.text('Günü Kapat'), findsOneWidget, reason: 'kapatma yine durur');

      await kapat(tester);
    });

    testWidgets('GÜN kapsamında düğme çizilmez — para kuryeden alınır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      // Açılış kapsamı "Tümü" (gün hesabı).
      expect(find.text('Ara Tahsilat'), findsNothing,
          reason: 'gün hesabından ara tahsilat alınmaz');

      await kapat(tester);
    });

    testWidgets('PATRON kurye kapsamında düğmeyi görür', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await kapsamaGec(tester, 'Emre');

      expect(find.text('Ara Tahsilat'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('KURYE kendi kapsamında düğmeyi görür', (tester) async {
      // Kurye kendi kasasını patrona devrediyor — kendi kasasının kanıtı odur.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'kurye', kullaniciId: 'k1'));

      expect(find.text('Ara Tahsilat'), findsOneWidget,
          reason: 'kurye kendi kapsamında açılır');

      await kapat(tester);
    });

    testWidgets('KURYE başkasının kapsamını göremez — düğme de yok', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await kuryeEkle(db, id: 'k2', ad: 'Hakan');
        await nakitTeslim(db, kuryeId: 'k2', tutarKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'kurye', kullaniciId: 'k1'));

      expect(find.text('Hakan'), findsNothing,
          reason: 'segmentte başka kurye listelenmez (K2)');

      await kapat(tester);
    });

    testWidgets('KAPATILMIŞ kapsamda ara tahsilat alınamaz', (tester) async {
      // Kapanmış bir hesaba sonradan para eklemek mutabakatı bozar.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
        await DayClosingRepository(db).kapat(
          scope: ClosingScope.courier,
          userId: 'k1',
          countedCashKurus: 9000,
        );
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'kurye', kullaniciId: 'k1'));

      expect(find.text('Ara Tahsilat'), findsNothing);
      expect(find.textContaining('kapatıldı'), findsWidgets);

      await kapat(tester);
    });
  });

  group('Ara tahsilat — akış', () {
    testWidgets('tahsilat alınır, gün AÇIK kalır, özet satırı belirir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await kapsamaGec(tester, 'Emre');

      await dokun(tester, find.text('Ara Tahsilat'));
      await sheetAnimasyonu(tester);

      // ETİKET FORMÜL İDDİA ETMEZ: beklenen nakdin tanımı repo'nundur ve değişebilir
      // (2026-08-06'da kümülatife döndü). Ekran metni "nasıl hesaplandığını" söylerse, tanım
      // değiştiği gün sessizce yalan söyler.
      expect(find.text('Kuryede beklenen nakit'), findsOneWidget);
      expect(find.textContaining('Son devirden beri'), findsNothing);
      // İlk tahsilatta beklenen, günün toplanan nakdine eşittir — her iki tanımda da 90 ₺.
      expect(find.text(sipTutar(9000)), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '60');
      await akislariBekle(tester);

      // Kuryede kalan = 90 − 60 = 30 ₺. Bu bir "EKSİK" damgası DEĞİLDİR: ara tahsilatta sayılan
      // tutar serbesttir (patron para üstü için kuryede para bırakabilir).
      expect(find.text('KURYEDE KALAN'), findsOneWidget);
      expect(find.text('EKSİK'), findsNothing, reason: 'ara tahsilat bir mutabakat değildir');

      await dokun(tester, find.text('Tahsilatı Al'));
      await akislariBekle(tester, tur: 8);

      // Gün AÇIK kaldı: kapanış kaydı yazılmadı, kapatma düğmesi hâlâ orada.
      final kapanmaSayisi = await tester
          .runAsync(() => DayClosingRepository(db).watchArchive().first);
      expect(kapanmaSayisi, isEmpty, reason: 'ara tahsilat KAPANIŞ yazmaz');
      expect(find.text('Hesabı Kapat'), findsOneWidget);

      // Özet kartı ara tahsilatı gösterir.
      expect(find.text('Ara Tahsilatlar'), findsOneWidget);
      expect(find.textContaining('Alınan toplam · 1 tahsilat'), findsOneWidget);

      await kapat(tester);
    });

    test('KAPANMIŞ kapsamda repo StateError atar — ekranın arkasındaki kapı', () async {
      // Ekran düğmeyi zaten çizmiyor, ama sheet açıkken senkron başka bir cihazdan kapanış
      // indirebilir. O an ekranın bildiği durum bayattır; son sözü repo söyler.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await kuryeEkle(db, id: 'k1', ad: 'Emre');
      await kuryeEkle(db, id: 'k2', ad: 'Hakan');
      await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      await DayClosingRepository(db).kapat(
        scope: ClosingScope.courier,
        userId: 'k1',
        countedCashKurus: 9000,
      );

      await expectLater(
        CashHandoverRepository(db).araTahsilat(fromUserId: 'k1', countedCashKurus: 1000),
        throwsA(isA<StateError>()),
      );

      // DİĞER kurye serbest kalır: bir kuryenin hesabının kapanması ötekini kilitlemez.
      await expectLater(
        CashHandoverRepository(db).araTahsilat(fromUserId: 'k2', countedCashKurus: 1000),
        completes,
      );
    });

    testWidgets('sayım GİRİLMEDEN kaydedilemez', (tester) async {
      // Sayılmamış bir para transferi kaydı, kimsenin doğrulayamayacağı bir rakam olurdu.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await kapsamaGec(tester, 'Emre');
      await dokun(tester, find.text('Ara Tahsilat'));
      await sheetAnimasyonu(tester);

      final dugme =
          tester.widget<SipButon>(find.widgetWithText(SipButon, 'Tahsilatı Al'));
      expect(dugme.onTap, isNull, reason: 'boş sayımla tahsilat kaydedilmez');

      await kapat(tester);
    });
  });

  group('Kapanış sheet\'i — beklenen nakit KALAN nakittir', () {
    testWidgets('günün nakdi · gün içinde alınan · beklenen — üçü de yazılır', (tester) async {
      // Bu üç satır olmasaydı bayi "ciro 90 ₺ ama uygulama 30 ₺ bekliyor" der ve mutabakata
      // güvenmeyi bırakırdı (BRIEF: rakamlar elle tutulan defterle tutmazsa ürüne güven ölür).
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
        await CashHandoverRepository(db)
            .araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await kapsamaGec(tester, 'Emre');

      await dokun(tester, find.text('Hesabı Kapat'));
      await sheetAnimasyonu(tester);

      expect(find.text('Günün nakdi'), findsOneWidget);
      expect(find.text('Gün içinde alınan'), findsOneWidget);
      // Bu iki rakam elle doğrulanabilir: gün boyu 90 ₺ nakit girdi, 60 ₺'si alındı.
      expect(find.text(sipTutar(9000)), findsWidgets);
      expect(find.text('− ${sipTutar(6000)}'), findsOneWidget);

      // BEKLENEN NAKİT ELLE TÜRETİLMEZ — bilerek "90 − 60 = 30" yazmıyoruz. Beklenen nakdin
      // tanımı repo'nundur ve bu turda İKİ KEZ değişti (period_start penceresi → kümülatif kalan
      // → tüm devirleri kapsayan kümülatif). Buradaki iddia rakamın DEĞERİ değil, EKRANIN
      // REPO'YU BASTIĞIDIR: ekran kendi çıkarmasını yapsaydı sheet'te yazan tutar arşive donan
      // tutardan ayrışır ve kayıt append-only olduğu için o fark kalıcı olurdu.
      final onizleme = await tester.runAsync(
        () => DayClosingRepository(db).onizle(ClosingScope.courier, userId: 'k1'),
      );
      expect(find.text(sipTutar(onizleme!.expectedCashKurus)), findsWidgets);
      expect(onizleme.gunNakitKurus, 9000);
      expect(onizleme.teslimEdilenKurus, 6000);

      await kapat(tester);
    });

    testWidgets('KURYE HESABI KAPANDIKTAN SONRA gün kapanışı da düşer', (tester) async {
      // ASİMETRİ DÜZELTMESİ (kullanıcı kararı 2026-08-06): kurye kapsamı ARA + KAPANIŞ
      // devirlerinin ikisini de düşerken gün kapsamı yalnız ARA tahsilatı düşüyordu. Kurye
      // hesabını kapatıp 90 ₺ teslim ettikten sonra gün kapanışı hâlâ 90 ₺ bekliyordu — patron
      // eline geçmiş bir parayı ikinci kez sayması gerektiğini sanırdı.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
        // Kurye kendi hesabını kapatır ve kasayı TAM teslim eder (ara tahsilat YOK).
        await DayClosingRepository(db).kapat(
          scope: ClosingScope.courier,
          userId: 'k1',
          countedCashKurus: 9000,
          alsoHandover: true,
        );
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text('Günü Kapat'));
      await sheetAnimasyonu(tester);

      // ÜÇ SATIR DA GÖRÜNÜR — ara tahsilat hiç alınmamış olsa bile. Eski koşul "ara tahsilat > 0"
      // olsaydı bu sheet açıklamasız açılır ve patron 90 ₺ nakit girmiş bir günde 0 ₺ beklentiyi
      // hiçbir yerde okuyamazdı.
      expect(find.text('Günün nakdi'), findsOneWidget);
      expect(find.text('Gün içinde alınan'), findsOneWidget);
      expect(find.text('Beklenen nakit'), findsOneWidget);

      // Bağıntı repo'nun sözleşmesi: gün nakdi − teslim edilen == beklenen. Testte de ekranda da
      // ELLE ÇIKARILMAZ; üçü birlikte okunup tutarlılıkları doğrulanır.
      final onizleme = await tester.runAsync(
        () => DayClosingRepository(db).onizle(ClosingScope.day),
      );
      expect(onizleme!.gunNakitKurus, 9000);
      expect(onizleme.teslimEdilenKurus, 9000,
          reason: 'KAPANIŞ devri de teslim edilen paradır');
      expect(onizleme.expectedCashKurus, 0,
          reason: 'kurye kasayı zaten verdi; patron aynı parayı ikinci kez saymaz');
      expect(find.text('− ${sipTutar(onizleme.teslimEdilenKurus)}'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('gün içinde HİÇ para alınmadıysa açıklama satırları çizilmez', (tester) async {
      // Çoğunluk gün böyle geçer; "− 0,00 ₺" her akşam cevapsız bir soru olurdu.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await kapsamaGec(tester, 'Emre');
      await dokun(tester, find.text('Hesabı Kapat'));
      await sheetAnimasyonu(tester);

      expect(find.text('Günün nakdi'), findsNothing);
      expect(find.text('Gün içinde alınan'), findsNothing);
      expect(find.text('Beklenen nakit (Emre)'), findsOneWidget);

      await kapat(tester);
    });
  });
}
