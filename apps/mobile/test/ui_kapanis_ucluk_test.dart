// KAPANIŞ SHEET'İNİN ÜÇLÜSÜ — günün nakdi · düşülen · beklenen (kullanıcı kararı 2026-08-06).
//
// NEDEN AYRI DOSYA: `ui_ara_tahsilat_test.dart` bu grupla 499 satıra çıkmıştı (depo sınırı 500).
// Ara tahsilat AKIŞI ile kapanış sheet'inin ARİTMETİĞİ ayrı sorular; ikisini ayrı dosyada tutmak
// bir grubun büyümesini diğerinin bütçesine yazmıyor.
//
// SHEET'İN TEK KURALI: **üst − orta == alt**, her kapsamda. Sayıların hepsi repo'dan gelir; sheet
// ne toplar ne çıkarır. Kimlik tutmuyorsa çizim değil VERİ hatalıdır.
//
// ETİKETLER VERİDEN TÜRER (`DusulenKalem` enum'u), ekranın kapsam çıkarımından değil:
//  • üst  → kurye: "Topladığı" (PENCERE nakdi) · gün: "Günün nakdi" (takvim günü)
//  • orta → kurye: "Teslim edilen" (verdiği)   · gün: "Kuryelerde kalan" (vermediği)
//
// HER TESTTE İKİ YÖNLÜ KİLİT: doğru kelimenin VARLIĞI **ve** öbür kapsamın kelimesinin YOKLUĞU.
// Yalnız varlığı sınamak yetmiyordu — üst satır bir tur boyunca yanlış etiketle durdu ve suite
// yeşil geçti, çünkü o etiketi hiçbir iddia tutmuyordu.

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/day_closing_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/components/overlays.dart' show SipToast;

import 'support/ara_tahsilat_yardimcilari.dart';
import 'support/ekran_yardimcilari.dart';

void main() {
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

      // ÜST SATIR KURYE KAPSAMINDA "GÜNÜN NAKDİ" DEMEZ: orada gösterilen, o kuryenin PENCERE
      // nakdidir (son kapanışından beri topladığı). Kurye gün içinde bir kez kapatıp yeniden
      // çalışmışsa günün tamamıyla aynı DEĞİLDİR ve "Günün nakdi" yazmak yanlış olur. Bu satır
      // bir tur boyunca yanlış etiketle durdu ve hiçbir test yakalamadı — artık yakalıyor.
      expect(find.text('Topladığı'), findsOneWidget);
      expect(find.text('Günün nakdi'), findsNothing,
          reason: 'kurye kapsamında üst satır günün tamamı değil, pencere nakdidir');

      // ORTA SATIR: doğru kelimenin VARLIĞI ve diğer kapsamın kelimesinin YOKLUĞU birlikte
      // kilitlenir. Yalnız varlığı sınamak yetmez — iki etiket de aynı anda çizilseydi (ya da
      // yanlış olan seçilseydi) tek taraflı bir iddia bunu görmezdi.
      expect(find.text('Teslim edilen'), findsOneWidget);
      expect(find.text('Kuryelerde kalan'), findsNothing,
          reason: 'kurye kapsamında düşülen, teslim EDİLEN paradır');
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
      expect(onizleme.dusulenKurus, 6000);

      await kapat(tester);
    });

    testWidgets('KURYE HESABINI KAPATMIŞSA gün kapanışı DÜŞMEZ — devir iç transfer',
        (tester) async {
      // REGRESYON KİLİDİ (kullanıcı kararı 2026-08-06). Bir ara kararla gün kapsamı da tüm
      // devirleri düşüyordu ve bu YANLIŞTI: gün kapsamında devir bir İÇ TRANSFERDİR — para
      // kuryeden patrona geçer, işletmeden ÇIKMAZ. O hâliyle kurye 90 ₺ toplayıp hepsini teslim
      // ettiğinde ekran "beklenen 0" diyordu, oysa patronun kasasında 90 ₺ duruyordu ve sayınca
      // "FAZLA 90 ₺" yazacaktı.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
        // Kurye kendi hesabını kapatır ve kasayı TAM teslim eder.
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

      final onizleme = await tester.runAsync(
        () => DayClosingRepository(db).onizle(ClosingScope.day),
      );
      expect(onizleme!.gunNakitKurus, 9000);
      expect(onizleme.expectedCashKurus, 9000,
          reason: 'para işletmeden çıkmadı; patron kendi kasasını sayacak, fark 0 olmalı');

      // KURYELERDE KALAN SIFIR → orta satır HİÇ çizilmez, sheet sade kalır.
      expect(find.text('Kuryelerde kalan'), findsNothing);
      expect(find.text('Günün nakdi'), findsNothing,
          reason: 'düşülecek bir şey yokken üçlü açıklamaya gerek yok');
      expect(find.text('Beklenen nakit'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('ÇOK KURYELİ bayide gün kapanışı üç satırı da yazar', (tester) async {
      // Emre 90 ₺ toplar, patron 60 ₺ ara tahsilat alır → Emre'de 30 ₺ kalır.
      // Hakan 50 ₺ toplar, hiç teslim etmez → Hakan'da 50 ₺ kalır.
      // Gün kapanışı: nakit 140 ₺ · kuryelerde kalan 80 ₺ · patron kasasında 60 ₺ sayacak.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await kuryeEkle(db, id: 'k2', ad: 'Hakan');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000, musteri: 'Ayşe');
        await nakitTeslim(db, kuryeId: 'k2', tutarKurus: 5000, musteri: 'Veli');
        await CashHandoverRepository(db)
            .araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text('Günü Kapat'));
      await sheetAnimasyonu(tester);

      // ETİKET GÜN KAPSAMINDA "TESLİM EDİLEN" DEMEZ: düşülen tutar burada kuryelerde KALAN
      // paradır, teslim edilen değil. Teslim edilen 60 ₺ zaten patronun kasasında ve sayılacak.
      // Gün kapsamının SİMETRİĞİ: her iki satırda da doğru kelime var, diğer kapsamın kelimesi yok.
      expect(find.text('Günün nakdi'), findsOneWidget);
      expect(find.text('Topladığı'), findsNothing,
          reason: 'gün kapsamında üst satır bir kuryenin penceresi değil, günün tamamıdır');
      expect(find.text('Kuryelerde kalan'), findsOneWidget);
      expect(find.text('Teslim edilen'), findsNothing,
          reason: 'gün kapsamında bu sayı teslim edilen DEĞİL, kalan paradır');
      // İŞARETE GÖRE DALLANAN ETİKETİN POZİTİF UCU: düşülen artı olduğunda para kuryede
      // KALMIŞTIR; "devir" kelimesi yalnız negatif hâle (dünden gelen paraya) aittir.
      expect(find.text('Kuryelerden devir'), findsNothing);
      expect(find.text('Beklenen nakit'), findsOneWidget);

      // ÜÇLÜ ARİTMETİK OLARAK KAPANIR — repo'nun sözleşmesi. Test bunu ELLE çıkarmaz, üçünü
      // birlikte okuyup kimliği doğrular; kimlik tutmuyorsa çizim değil VERİ hatalıdır.
      final on = await tester.runAsync(
        () => DayClosingRepository(db).onizle(ClosingScope.day),
      );
      expect(on!.gunNakitKurus, 14000);
      expect(on.dusulenKurus, 8000, reason: 'Emre 30 + Hakan 50 = 80 ₺ kuryelerde');
      expect(on.expectedCashKurus, 6000, reason: 'patronun kasasındaki ara tahsilat');
      expect(on.gunNakitKurus - on.dusulenKurus, on.expectedCashKurus);

      expect(find.text(sipTutar(on.gunNakitKurus)), findsWidgets);
      expect(find.text('− ${sipTutar(on.dusulenKurus)}'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('TEK KİŞİLİK bayide orta satır hiç çizilmez', (tester) async {
      // Kurye yok → kuryelerde kalan yok → beklenen, günün tüm nakdidir.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        final cid = await CustomerRepository(db).create(name: 'Ayşe');
        final oid = await OrderRepository(db).create(
          customerId: cid,
          lines: [LineInput(productName: 'Damacana', unitPriceKurus: 9000, qty: 1)],
        );
        await OrderRepository(db).deliver(oid, paymentType: 'nakit');
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text('Günü Kapat'));
      await sheetAnimasyonu(tester);

      expect(find.text('Kuryelerde kalan'), findsNothing);
      expect(find.text('Günün nakdi'), findsNothing);
      expect(find.text('Beklenen nakit'), findsOneWidget);
      expect(find.text(sipTutar(9000)), findsWidgets, reason: 'beklenen = günün tüm nakdi');

      await kapat(tester);
    });

    testWidgets('KURYE kapsamında hiç para teslim edilmediyse orta satır çizilmez',
        (tester) async {
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

      expect(find.text('Topladığı'), findsNothing);
      expect(find.text('Teslim edilen'), findsNothing);
      expect(find.text('Beklenen nakit (Emre)'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('KURYE DÜNÜN PARASINI BUGÜN TESLİM ETTİYSE orta satır ARTI yazar',
        (tester) async {
      // BU SENARYO BUGÜNE KADAR HİÇ OLUŞMADI ve tam olarak bu yüzden riskliydi: `dusulenKurus`
      // gün kapsamında kuryelerin O GÜNKÜ NET DEĞİŞİMİDİR ve NEGATİF olabilir. Emre dün 50 ₺
      // topladı (kapanış YOK, para cebinde kaldı), bugün hiç toplamadı ve dünün parasını bugün
      // teslim etti. Kasaya günün KENDİ nakdinden (0 ₺) fazlası girdi.
      //
      // Ekran eskiden sabit "−" basıyordu ve "− −50,00 ₺" yazıyordu: hem bozuk hem ters yönlü.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 5000);
        await duneKaydir(db, kuryeId: 'k1');
        // Dünün kasası BUGÜN patrona geçer. Kuryenin mutabakat penceresi alttan açık olduğu için
        // (hiç kapanışı yok) tahsilat beklenenle birebir tutar — fark üretmiyoruz, işaret sınanıyor.
        await CashHandoverRepository(db)
            .araTahsilat(fromUserId: 'k1', countedCashKurus: 5000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text('Günü Kapat'));
      await sheetAnimasyonu(tester);

      // ÜÇLÜ KİMLİĞİ NEGATİFTE DE KAPANIR: üst − orta == alt, yani 0 − (−50) = 50.
      final on = await tester.runAsync(
        () => DayClosingRepository(db).onizle(ClosingScope.day),
      );
      expect(on!.gunNakitKurus, 0, reason: 'bugün hiç nakit toplanmadı');
      expect(on.dusulenKurus, -5000,
          reason: 'bugün toplanan 0 − bugün teslim edilen 50 ₺ = −50 ₺');
      expect(on.expectedCashKurus, 5000,
          reason: 'dünün parası BUGÜN patronun kasasına girdi; akşam onu sayacak');
      expect(on.gunNakitKurus - on.dusulenKurus, on.expectedCashKurus);

      // İŞARET DEĞERDEN TÜRER: negatif düşülen ekranda ARTI ile çizilir.
      expect(find.text('+ ${sipTutar(on.dusulenKurus.abs())}'), findsOneWidget);
      // ESKİ KUSURUN TAM METNİ — sabit "−" + kendi işaretini basan `sipTutar`.
      expect(find.text('− ${sipTutar(on.dusulenKurus)}'), findsNothing,
          reason: 'çift işaret ("− −50,00 ₺") hem bozuk hem ters yönlüdür');
      expect(find.textContaining('− −'), findsNothing);

      // ETİKET DE DEĞİŞİR — asıl iş bu. "Kuryelerde kalan: + 50 ₺" cümlesi yalandır: o para
      // kuryede KALMADI, tam tersine kuryeden GELDİ. İşareti düzeltip kelimeyi bırakmak, anlamı
      // değişen sayıyı eski kelimesiyle taşımak olurdu.
      expect(find.text('Kuryelerden devir'), findsOneWidget);
      expect(find.text('Kuryelerde kalan'), findsNothing,
          reason: 'negatifte o para kuryede kalmadı, kuryeden geldi');
      expect(find.text('Teslim edilen'), findsNothing,
          reason: 'gün kapsamının kelimesi kurye kapsamınınkine kaymamalı');

      // Üst ve alt satır yerinde: gün kapsamının çerçevesi değişmedi.
      expect(find.text('Günün nakdi'), findsOneWidget);
      expect(find.text('Topladığı'), findsNothing);
      expect(find.text('Beklenen nakit'), findsOneWidget);
      expect(find.text(sipTutar(on.expectedCashKurus)), findsWidgets);

      await kapat(tester);
    });
  });

  group('Kapatma submit\'i — repo kapıyı kapatırsa ekran SÖYLER', () {
    testWidgets('sheet AÇIKKEN kapsam kapanırsa hata basılır, ekran çökmez', (tester) async {
      // Ekran kapanmış kapsamda "Kapat" düğmesini zaten çizmiyor. Ama sheet AÇIKKEN senkron
      // başka bir cihazdan gelen kapanışı indirebilir; o an ekranın bildiği durum bayattır ve
      // son sözü repo söyler (`kapat()` → StateError). Yakalanmasaydı bayi, sayımını girip
      // düğmeye bastıktan sonra hiçbir açıklama görmeden çöken bir ekranla kalırdı.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text('Günü Kapat'));
      await sheetAnimasyonu(tester);

      // Sheet açıkken gün BAŞKA BİR YERDEN kapanır (senkronun indirdiği kapanışın karşılığı).
      await tester.runAsync(() async {
        await DayClosingRepository(db)
            .kapat(scope: ClosingScope.day, countedCashKurus: 9000);
      });

      await tester.enterText(find.byType(TextField).first, '90');
      await akislariBekle(tester);
      await dokun(tester, find.text('Kapat ve Arşivle'));
      await akislariBekle(tester, tur: 8);

      // Mesaj repo'dan geldiği gibi basılır — "bir şeyler ters gitti" demek, NE olduğunu
      // bilirken bilgi saklamaktır.
      expect(find.text('Gün hesabı kapandı; yeniden kapatılamaz'), findsOneWidget);

      // İKİNCİ KAYIT YAZILMADI: arşiv append-only, uydurma bir kapanış kalıcı olurdu.
      final arsiv =
          await tester.runAsync(() => DayClosingRepository(db).watchArchive().first);
      expect(arsiv!.length, 1, reason: 'yalnız arkadan gelen kapanış duruyor');

      // Ekran gerçeğe döndü: kapsam artık kilitli görünüyor.
      expect(find.textContaining('kapatıldı'), findsWidgets);

      SipToast.temizle();
      await kapat(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // ÇERÇEVE NOTU — sheet PENCERE konuşur, ekran GÜN
  // ═════════════════════════════════════════════════════════════════════════════════════════
  //
  // Kurye kapsamında iki farklı çerçeve yan yana duruyor ve arayı açıklayan HİÇBİR satır yoktu:
  //  • EKRAN (kasa kartı, ara tahsilat kartı) → TAKVİM GÜNÜ
  //  • SHEET (topladığı · teslim edilen · beklenen) → PENCERE (son hesap kapanışından beri)
  // Bayi "3.000 mü 8.000 mi doğru" diye soruyor ve uygulama cevap vermiyordu.
  //
  // Satır YALNIZ ayrıştıklarında çizilir; çakışan günlerde (çoğunluk) gürültü yapmaz.
  group('Çerçeve notu — iki çerçeve ayrışınca ekran bunu SÖYLER', () {
    const cerceveSatiri =
        'Önceki günlerden devreden nakit dahil';

    testWidgets('EKSEN 1 — kasa kartı GÜNÜ, sheet PENCEREYİ yazarken satır çizilir',
        (tester) async {
      // Hiç kapanış yapmamış kurye: dün 50 ₺ topladı (para cebinde kaldı), bugün 30 ₺ topladı.
      // Ekran "Nakit 30,00 ₺" der, sheet "Topladığı 80,00 ₺" — ikisi de kendi çerçevesinde doğru.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 5000);
        await duneKaydir(db, kuryeId: 'k1');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 3000, musteri: 'Veli');
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await kapsamaGec(tester, 'Emre');
      await dokun(tester, find.text('Hesabı Kapat'));
      await sheetAnimasyonu(tester);

      final on = await tester.runAsync(
        () => DayClosingRepository(db).onizle(ClosingScope.courier, userId: 'k1'),
      );
      expect(on!.gunNakitKurus, 8000, reason: 'pencere dünü de kapsar (kapanış yok)');

      // İKİ RAKAM AYNI ANDA EKRANDA: sheet'in 80,00 ₺'si ile arkadaki kasa kartının 30,00 ₺'si.
      // Testin asıl konusu bu yan yanalık — açıklama satırı tam olarak bunun için var.
      expect(find.text(sipTutar(8000)), findsWidgets);
      expect(find.text(sipTutar(3000)), findsWidgets, reason: 'arkadaki kasa kartı GÜNÜ yazar');
      expect(find.text(cerceveSatiri), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('EKSEN 2 — ara tahsilat kartı BOŞken sheet "Teslim edilen" yazarsa satır çizilir',
        (tester) async {
      // Lead senaryosu: kurye dün 50 ₺ topladı, patron dün 20 ₺ ara tahsilat aldı, bugün hesap
      // kapatılıyor. BUGÜNÜN kartında hiç ara tahsilat yok (kart gün süzgeçli) ama sheet
      // "Teslim edilen 20,00 ₺" diyor (pencere düne sarkıyor). Uydurma değil, farklı çerçeve.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 5000);
        await CashHandoverRepository(db)
            .araTahsilat(fromUserId: 'k1', countedCashKurus: 2000);
        await duneKaydir(db, kuryeId: 'k1', devirlerDe: true);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await kapsamaGec(tester, 'Emre');

      // Kart GÜN süzgeçli: bugün hiç ara tahsilat yok, bölüm hiç çizilmiyor.
      expect(find.text('Ara Tahsilatlar'), findsNothing);

      await dokun(tester, find.text('Hesabı Kapat'));
      await sheetAnimasyonu(tester);

      final on = await tester.runAsync(
        () => DayClosingRepository(db).onizle(ClosingScope.courier, userId: 'k1'),
      );
      expect(on!.dusulenKurus, 2000, reason: 'pencerede dün teslim edilen para');

      expect(find.text('Teslim edilen'), findsOneWidget);
      expect(find.text('− ${sipTutar(2000)}'), findsOneWidget);
      expect(find.text(cerceveSatiri), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('ÇAKIŞAN GÜNDE satır ÇİZİLMEZ — çoğu gün böyle geçer, gürültü yapılmaz',
        (tester) async {
      // Kuryenin tüm hareketi BUGÜN: pencere ile gün aynı parayı kapsıyor, açıklanacak bir fark
      // yok. Koşulsuz çizilen bir uyarı, her akşam okunmayı bırakacak bir satır olurdu.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
        await CashHandoverRepository(db)
            .araTahsilat(fromUserId: 'k1', countedCashKurus: 6000);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await kapsamaGec(tester, 'Emre');

      // Kart bugünün tahsilatını gösteriyor — sheet'le aynı parayı konuşuyorlar.
      expect(find.text('Ara Tahsilatlar'), findsOneWidget);

      await dokun(tester, find.text('Hesabı Kapat'));
      await sheetAnimasyonu(tester);

      expect(find.text('Topladığı'), findsOneWidget, reason: 'üçlü yine çizilir');
      expect(find.text(cerceveSatiri), findsNothing);
      // Metnin PARÇASI da geçmemeli — satır kısaltılarak geri gelirse bu iddia onu yakalar.
      // ("devreden" tek başına aranamaz: not alanının ipucu metni de o kelimeyi taşıyor.)
      expect(find.textContaining('aynı aralık değil'), findsNothing);

      await kapat(tester);
    });
  });
}
