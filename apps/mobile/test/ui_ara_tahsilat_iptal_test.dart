// ARA TAHSİLAT İPTALİ — EKRAN (kullanıcı kararı 2026-08-13).
//
// "Yönetici bir ara tahsilatı iptal edebilir. İptal GERÇEK SİLME DEĞİLDİR: orijinal satır listede
// KALIR, 'iptal edildi' işaretlenir, üstü çizili çizilir ve toplamlardan düşer."
//
// Burada çivilenen kararlar:
//  1. İPTAL YETKİSİ ARA TAHSİLAT ALMAKLA AYNI ANAHTARDADIR (`yetkiler().gunuKapatma`): kurye
//     görünümünde satır DOKUNULABİLİR DEĞİLDİR — pasif değil, dokunma yüzeyi HİÇ YOKTUR.
//  2. ONAY ADIMI ZORUNLUDUR: satır kaydırılan bir listenin ortasında duruyor ve iptalin iptali
//     yoktur (append-only). Vazgeçilirse HİÇBİR kayıt yazılmaz.
//  3. İptalli satır SOLGUN + ÜSTÜ ÇİZİLİ çizilir. Solgunluk tek başına yetmez: solgun bir para
//     rakamı "ikincil bilgi" diye de okunabilir ve bayi onu toplama katardı.
//  4. Sayaç ile toplam AYNI kümeyi sayar — "2 tahsilat" derken altında tek tahsilatın tutarını
//     göstermek, bayiye hangisinin doğru olduğunu soramayacağı iki rakam vermektir.
//  5. İptalli satır TEKRAR iptal edilemez (dokunma yüzeyi kalkar): ikinci iptal parayı ikinci kez
//     geri verirdi.
//
// ⚠️ İŞARET CHEVRON DEĞİL `ban`: chevron "burada bir DÖKÜM var" der (ödeme türü satırları tam
// olarak öyle çalışıyor). Buradaki dokunuş bir DÜZELTME başlatıyor; chevron koymak bayiyi detay
// sanıp dokunduğu yerde "iptal edilsin mi?" diyaloğuyla karşılaştırırdı.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/cash_handover_repository.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/isletme/gun_sonu_kartlari.dart' show AraTahsilatKarti;
import 'package:sipario/screens/isletme/isletme_atomlari.dart';
import 'package:sipario/theme/components/atoms.dart';
import 'package:sipario/theme/icons.dart';

import 'support/ara_tahsilat_yardimcilari.dart';
import 'support/ekran_yardimcilari.dart';

void main() {
  /// Emre 90,00 ₺ topladı; patron 40,00 + 20,00 iki ara tahsilat aldı. Dönen id'ler sırayla
  /// birinci ve ikinci tahsilattır.
  ///
  /// İKİ TAHSİLAT, çünkü tek tahsilatlı kurulumda "iptal toplamdan düşer" iddiası 0'a karşı
  /// ölçülür ve 0 her hatayı yutar. Tutarlar da AYRIK seçildi: `find.text('40,00 ₺')` tek bir
  /// satıra düşsün, toplam satırıyla karışmasın.
  Future<(String, String)> ikiTahsilat(WidgetTester tester, AppDatabase db) =>
      tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await nakitTeslim(db, kuryeId: 'k1', tutarKurus: 9000);
        final devirler = CashHandoverRepository(db);
        final birinci = await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 4000);
        final ikinci = await devirler.araTahsilat(fromUserId: 'k1', countedCashKurus: 2000);
        return (birinci, ikinci);
      }).then((v) => v!);

  /// Onay diyaloğunun açılma/kapanma animasyonunu bitirir.
  ///
  /// `akislariBekle` tek başına YETMEZ: o, gerçek zamanda bekleyip `pump()` çağırıyor ve
  /// süresiz `pump()` sahte saati İLERLETMİYOR. Rota animasyonu 0'da kalırsa diyaloğun düğmeleri
  /// ağaçta olsalar bile dokunulamaz (`sheetAnimasyonu` ile aynı ders).
  Future<void> diyalogAnimasyonu(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await akislariBekle(tester);
  }

  /// [tutar] kuruş değerini gösteren ara TAHSİLAT satırı — TOPLAM satırı HARİÇ.
  ///
  /// ⚠️ TUTARA GÖRE ARAMAK TEK BAŞINA YETMEZ ve bu, bu dosyanın ilk koşusunda "Too many
  /// elements" diye patladı: kart, tahsilat satırlarının ALTINA aynı biçimde bir toplam satırı
  /// çiziyor ve bir tahsilat iptal edilince toplam, ayakta kalan satırın tutarına EŞİTLENİYOR
  /// (40,00 iptal → toplam 20,00 → ayakta duran 20,00'lık satırla aynı rakam). Tutarları "ayrık
  /// seçtik" diye güvenmek, tam da iptali ölçen testte çöker.
  ///
  /// Ölçüt o yüzden rakam değil ROL: `toplam` bayrağı satırın hangi cümleyi kurduğunu söylüyor.
  Finder satir(int tutar) => find.byWidgetPredicate(
        (w) => w is DegerSatiri && w.deger == sipTutar(tutar) && !w.toplam,
        description: 'tahsilat satırı ${sipTutar(tutar)} (toplam satırı değil)',
      );

  group('İptalli satır ekranda', () {
    testWidgets('"iptal edildi" yazar, üstü çizili çizilir, toplam ve sayaç DÜŞER',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final (birinci, _) = await ikiTahsilat(tester, db);
      await tester.runAsync(
          () => CashHandoverRepository(db).araTahsilatIptal(handoverId: birinci));

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      // Satır DURUYOR (silinmedi) ve iptalli olduğunu SÖYLÜYOR.
      expect(find.text(sipTutar(4000)), findsOneWidget, reason: 'kanıt görünür kalır');
      expect(find.textContaining('iptal edildi'), findsOneWidget);

      // FARK METNİ YERİNİ "iptal edildi"ye BIRAKIR: fark, duran bir tahsilatın kuryede ne
      // bıraktığını anlatır ("kuryede kalan 50,00 ₺"). Geri alınmış bir tahsilatın yanında o
      // cümle düpedüz yanlıştır — o para kuryede kalmadı, TAMAMI kuryeye geri döndü.
      expect(find.textContaining('kuryede kalan ${sipTutar(5000)}'), findsNothing);
      expect(find.textContaining('kuryede kalan ${sipTutar(3000)}'), findsOneWidget,
          reason: 'ayakta duran ikinci tahsilatın farkı yerinde kalır');

      // SOLGUNLUK TEK BAŞINA YETMEZ — üstü çizili tutar "bu rakam toplamın içinde değil"
      // cümlesini ikinci bir açıklama satırı açmadan söyler.
      final iptalliTutar = tester.widget<Text>(
        find.descendant(of: satir(4000), matching: find.text(sipTutar(4000))),
      );
      expect(iptalliTutar.style?.decoration, TextDecoration.lineThrough);
      final durauTutar = tester.widget<Text>(
        find.descendant(of: satir(2000), matching: find.text(sipTutar(2000))),
      );
      expect(durauTutar.style?.decoration, isNot(TextDecoration.lineThrough),
          reason: 'iptalsiz satır normal çizilir');

      // SAYAÇ VE TOPLAM AYNI KÜMEYİ SAYAR.
      expect(find.text('1 ara tahsilatın toplamı'), findsOneWidget,
          reason: 'iptalli satır sayaca girmez');
      // ÖLÇÜM KARTIN İÇİNE DARALTILDI (2026-08-25): ekranın tepesindeki özet bloğu da para
      // yazıyor ve aynı rakam orada da çıkabiliyor. Bu testin sorusu "ara tahsilat KARTI ne
      // diyor" — ekranın tamamında kaç kez geçtiği değil.
      expect(
        find.descendant(
            of: find.byType(AraTahsilatKarti), matching: find.text(sipTutar(2000))),
        findsNWidgets(2),
        reason: 'ayakta duran satır + toplam; iptal edilen 40,00 ₺ toplamdan düştü',
      );

      await kapat(tester);
    });

    testWidgets('İPTALLİ satır TEKRAR iptal edilemez — dokunma yüzeyi kalkar', (tester) async {
      // İkinci bir iptal parayı ikinci kez geri verirdi.
      final db = AppDatabase(NativeDatabase.memory());
      final (birinci, _) = await ikiTahsilat(tester, db);
      await tester.runAsync(
          () => CashHandoverRepository(db).araTahsilatIptal(handoverId: birinci));

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      expect(tester.widget<DegerSatiri>(satir(4000)).onTap, isNull);
      expect(tester.widget<DegerSatiri>(satir(2000)).onTap, isNotNull,
          reason: 'duran tahsilat hâlâ iptal edilebilir');

      await kapat(tester);
    });
  });

  group('Yetki kapısı — iptali yalnız yönetici yapar', () {
    testWidgets('PATRON satırı dokunulabilir görür ve işaret `ban`dır', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ikiTahsilat(tester, db);

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));

      final s = tester.widget<DegerSatiri>(satir(4000));
      expect(s.onTap, isNotNull);
      // İşaret ARKASINDAKİ DAVRANIŞIN karşılığı olmak zorunda: chevron "detay açılır" der.
      // `ban` bilinçli olarak `trash` DEĞİL — bu ekranda hiçbir şey silinmiyor.
      expect(s.sagIkon, SipIcons.ban);
      expect(s.sagIkon, isNot(SipIcons.right));

      await kapat(tester);
    });

    testWidgets('KURYE görünümünde satıra dokunmak İPTAL AÇMAZ', (tester) async {
      // Ara tahsilatı yalnız yönetici alır (2026-08-13); geri almak da aynı anahtardadır. Kurye
      // kendi tahsilatını silebilseydi, kayıt tek taraflı bir beyana dönerdi.
      //
      // KAPI PASİF DÜĞME DEĞİL, YOKLUKTUR: `onTap == null` olunca satır `SipDokun`a hiç
      // sarılmıyor, yani dokunulacak bir yüzey kalmıyor.
      final db = AppDatabase(NativeDatabase.memory());
      await ikiTahsilat(tester, db);

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'kurye', kullaniciId: 'k1'));

      expect(find.text('Emre için kasa özeti'), findsOneWidget,
          reason: 'ekranın geri kalanı kuryeye AÇIK kalır — kaldırılan yetki, kapatılan ekran değil');
      expect(tester.widget<DegerSatiri>(satir(4000)).onTap, isNull);

      await dokun(tester, find.text(sipTutar(4000)));
      await diyalogAnimasyonu(tester);

      expect(find.text('Ara tahsilat iptal edilsin mi?'), findsNothing);
      expect(find.text('İptal Et'), findsNothing);
      final satirlar = await tester.runAsync(() => db.select(db.cashHandovers).get());
      expect(satirlar, hasLength(2), reason: 'ters satır yazılmadı');

      await kapat(tester);
    });
  });

  group('Onay adımı', () {
    testWidgets('VAZGEÇİLİRSE hiçbir kayıt yazılmaz', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await ikiTahsilat(tester, db);

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text(sipTutar(4000)));
      await diyalogAnimasyonu(tester);

      expect(find.text('Ara tahsilat iptal edilsin mi?'), findsOneWidget);
      // Metin ÜÇ ŞEYİ birden söyler (kurye · saat · tutar): aynı kuryeden gün içinde birden çok
      // tahsilat alınıyor ve "Bu tahsilat iptal edilsin mi?" hangisini sorduğunu söylemezdi.
      expect(find.textContaining('Emre kuryesinden'), findsOneWidget);
      expect(find.textContaining(sipTutar(4000)), findsWidgets);
      // Kullanıcı SİLİNMEDİĞİNİ onay anında öğrenir — sonradan "kaydım gitti mi?" diye sormasın.
      expect(find.textContaining('yine kuryede sayılacak'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);

      await dokun(tester, find.text('Vazgeç'));
      await diyalogAnimasyonu(tester);

      final satirlar = await tester.runAsync(() => db.select(db.cashHandovers).get());
      expect(satirlar, hasLength(2), reason: 'vazgeçmek bir para hareketi yazmaz');
      expect(find.textContaining('iptal edildi'), findsNothing);
      expect(find.text('2 ara tahsilatın toplamı'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('ONAY VERİLİNCE ters satır yazılır ve ekran kendini günceller', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final (birinci, _) = await ikiTahsilat(tester, db);

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text(sipTutar(4000)));
      await diyalogAnimasyonu(tester);

      await dokun(tester, find.text('İptal Et'));
      await akislariBekle(tester, tur: 10);

      // DEFTER: ters satır yazıldı, orijinal SİLİNMEDİ.
      final satirlar = await tester.runAsync(() => db.select(db.cashHandovers).get());
      expect(satirlar, hasLength(3));
      final ters = satirlar!.firstWhere((r) => r.reversesHandoverId != null);
      expect(ters.reversesHandoverId, birinci);
      expect(ters.countedCashKurus, -4000);
      expect(ters.fromUserId, 'k1', reason: 'para kuryenin cebine geri döner');

      // EKRAN: satır yerinde ama artık iptalli; toplam ve sayaç düştü. Toast metni ('40,00 ₺
      // tahsilat iptal edildi') ayrı bir cümledir; satır etiketi de aynı sözü taşır.
      expect(find.textContaining('iptal edildi'), findsWidgets);
      expect(find.text('1 ara tahsilatın toplamı'), findsOneWidget);
      expect(tester.widget<Text>(find.text(sipTutar(4000))).style?.decoration,
          TextDecoration.lineThrough);

      await kapat(tester);
    });
  });
}
