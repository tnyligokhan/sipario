// SUNUCUYA SON ULAŞMA şeridi (lead kararı 2026-08-06).
//
// SORUN: kurye çevrimdışıyken kendi hesabını kapatırsa, telefonu patronun BAŞKA bir cihazdan
// aldığı ara tahsilatı bilmediği için arşive gerçek dışı bir "beklenen nakit" dondurur — ve
// kayıtlar append-only olduğu için o yalan kalıcı olur.
//
// REDDEDİLEN ÇÖZÜM: kapanışı çevrimiçi-zorunlu yapmak. BRIEF'in kırmızı çizgisi "uygulama
// internetsiz TAM çalışır"; bodrumdaki kuryeyi kasa kapatamaz hâle getiremeyiz.
//
// SEÇİLEN ÇÖZÜM: borç BİLİNÇLİ tutulur, yalnız GÖRÜNÜR kılınır. Burada çivilenenler:
//  1. Bayatken uyarılır ama kapatma ENGELLENMEZ — karar bayinin.
//  2. Metin DÜRÜST: "sunucuya son ulaşma". "Son senkron" / "Veriler güncel" / "Senkronize"
//     yazmak, damganın vermediği bir garanti vermek olur (damga satırlar UYGULANMADAN önce
//     yazılıyor). Bu depo aynı dersi güncelleme bandında aldı: her şeye "Çevrimdışı" diyen bir
//     gösterge, göstergesizlikten kötüdür. O yüzden bu üç ifadenin YOKLUĞU da sınanıyor.
//  3. Hiç temas yoksa "0 dk önce" DEĞİL, "hiç ulaşmadı" yazar — bilinmezlik tazelik değildir.
//  4. Gün kapanışında şerit YALNIZ bayatken çizilir; kurye kapanışında taze durum da söylenir.
//
// NEDEN AYRI DOSYA: `ui_ara_tahsilat_test.dart` bu grupla 520 satıra çıktı (depo sınırı 500).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/day_end_screen.dart';
import 'package:sipario/screens/isletme/senkron_seridi.dart';
import 'package:sipario/theme/components/atoms.dart';

import 'support/ekran_yardimcilari.dart';

void main() {
  /// Sunucudan son yanıtın geldiği anı kurar — `SyncEngine.pull()` her turda tam olarak bu alanı
  /// yazar. Damga [dakikaOnce] dakika geriye konur; hiç çağrılmazsa "hiç temas yok" hâli kalır.
  ///
  /// TESLİMAT KURULMUYOR: bu dosyanın sorusu tazelik şeridi, para değil. Ara tahsilat düğmesi
  /// aktif kurye + açık gün ile çizilir, kapatma düğmesi de öyle — nakit olmadan da her iki
  /// sheet açılıyor ve şerit görünüyor. Kurulumu küçük tutmak, kırıldığında NEDENİ tek yerde
  /// bırakır.
  Future<void> temasYaz(AppDatabase db, int dakikaOnce) async {
    await db.syncState(); // satır yoksa oluşsun
    await (db.update(db.syncMeta)..where((t) => t.id.equals(1))).write(
      SyncMetaCompanion(
        lastServerTimeIso: Value(
          DateTime.now().toUtc().subtract(Duration(minutes: dakikaOnce)).toIso8601String(),
        ),
        serverTimeOffsetMs: const Value(0),
      ),
    );
  }

  /// KURYE KAPSAMININ kapanış sheet'ini açar — ama PATRON olarak.
  ///
  /// 2026-08-11'de kurye kendi hesabını kapatma yetkisini kaybetti (kullanıcı kararı); bu
  /// testlerin konusu olan tazelik şeridi ise kapsamın kendisine aittir, kapatan kişiye değil.
  /// Bu yüzden testler kaldırılmadı, aynı kapsam YÖNETİCİ yolundan sürülüyor: iddia ("kurye
  /// kapsamı kapatılırken şerit ne der") olduğu gibi duruyor.
  Future<void> kuryeKapanisiAc(WidgetTester tester, AppDatabase db) async {
    await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
    await dokun(tester, find.text('Emre')); // kapsam segmenti: Tümü · Emre
    await dokun(tester, find.text('Hesabı Kapat'));
    await sheetAnimasyonu(tester);
  }

  group('Kurye kapanışı', () {
    testWidgets('BAYAT: uyarı çıkar ama kapatma ENGELLENMEZ', (tester) async {
      // Kritik olan ikinci yarısı: bodrumdaki kuryeyi kasa kapatamaz hâle getiremeyiz.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await temasYaz(db, 45); // eşik 10 dk
      });

      await kuryeKapanisiAc(tester, db);

      expect(find.textContaining('Sunucuya son ulaşma: 45 dk önce'), findsOneWidget);
      expect(find.textContaining('henüz inmemiş olabilir'), findsOneWidget);

      // DÜRÜST DİL: tamamlanmışlık iddiası YOK.
      expect(find.textContaining('Veriler güncel'), findsNothing);
      expect(find.textContaining('Senkronize'), findsNothing);
      expect(find.textContaining('Son senkron'), findsNothing);

      // ENGEL YOK: sayım girilince düğme çalışır.
      await tester.enterText(find.byType(TextField).first, '90');
      await akislariBekle(tester);
      final dugme =
          tester.widget<SipButon>(find.widgetWithText(SipButon, 'Kapat ve Arşivle'));
      expect(dugme.onTap, isNotNull,
          reason: 'bayatlık SÖYLENİR, kapatma engellenmez — karar bayinin');

      await kapat(tester);
    });

    testWidgets('TAZE: sessiz bilgi satırı, uyarı cümlesi yok', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await temasYaz(db, 2);
      });

      await kuryeKapanisiAc(tester, db);

      expect(find.textContaining('Sunucuya son ulaşma: 2 dk önce'), findsOneWidget);
      expect(find.textContaining('henüz inmemiş olabilir'), findsNothing,
          reason: 'tazeyken uyarı cümlesi çizilmez');

      await kapat(tester);
    });

    testWidgets('HİÇ TEMAS YOK: "0 dk önce" değil, "hiç ulaşmadı" yazar', (tester) async {
      // Bilinmezlik tazelik değildir; ama "0 dk önce" demek de bilmediğimizi bildiğimiz sanmaktır.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'p1', ad: 'Patron', rol: 'patron');
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
      });

      await kuryeKapanisiAc(tester, db);

      expect(find.textContaining('sunucuya hiç ulaşmadı'), findsOneWidget);
      expect(find.textContaining('0 dk önce'), findsNothing);

      await kapat(tester);
    });
  });

  group('Gün kapanışı — koşullu', () {
    testWidgets('BAYATKEN uyarır (risk kurye ile simetrik)', (tester) async {
      // Kurye kendi telefonundan da ara tahsilat teslim edebiliyor; "günü kapatan cihaz zaten
      // tahsilatı alan cihazdır" varsayımı tutmuyor. Geri döndürülemez bir kilidin önünde
      // gerçek bir riski söylemek gürültü değildir.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await temasYaz(db, 45);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text('Günü Kapat'));
      await sheetAnimasyonu(tester);

      expect(find.textContaining('Sunucuya son ulaşma: 45 dk önce'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('TAZEYKEN hiç çizilmez — her gece gürültü olurdu', (tester) async {
      // Patronun HER GECE gördüğü sheet'e "3 dk önce" satırı eklemek, iki günde görünmez olan
      // bir satır üretir — ve o satır gerçekten gerektiğinde de görünmez olur.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await temasYaz(db, 2);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await dokun(tester, find.text('Günü Kapat'));
      await sheetAnimasyonu(tester);

      expect(find.textContaining('Sunucuya son ulaşma'), findsNothing);
      expect(find.text('Beklenen nakit'), findsOneWidget, reason: 'sheet yine de açıldı');

      await kapat(tester);
    });
  });

  group('Ara tahsilat sheet\'i', () {
    testWidgets('şerit burada da görünür — beklenen tutar yine yerelden çıkıyor',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await kuryeEkle(db, id: 'k1', ad: 'Emre');
        await temasYaz(db, 45);
      });

      await ekranaKoy(tester, DayEndScreen(db: db, rol: 'patron', kullaniciId: 'p1'));
      await tester.tap(find.text('Emre'));
      await akislariBekle(tester, tur: 6);
      await dokun(tester, find.text('Ara Tahsilat'));
      await sheetAnimasyonu(tester);

      expect(find.textContaining('Sunucuya son ulaşma: 45 dk önce'), findsOneWidget);

      await kapat(tester);
    });
  });

  group('Süre biçimi', () {
    test('kaba biçim — yaklaşık bir ölçüme sahte kesinlik verilmez', () {
      expect(senkronSuresi(const Duration(seconds: 20)), 'az önce');
      expect(senkronSuresi(const Duration(minutes: 12)), '12 dk önce');
      expect(senkronSuresi(const Duration(hours: 3)), '3 sa önce');
      expect(senkronSuresi(const Duration(days: 2)), '2 gün önce');
    });
  });
}
