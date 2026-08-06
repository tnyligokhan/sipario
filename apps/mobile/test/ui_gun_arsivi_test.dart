// GÜN ÖZETİ — GEÇMİŞ GÜN EKRANI (kullanıcı kararı 2026-08-06).
//
// "Geçmişi gün sonu içinden ayrı bir şekilde açalım — aynı teslim edilen siparişlerde yaptığımız
// gibi tarihten ileri geri yaparak günlere bakmak daha pratik."
//
// ÖNCEKİ HÂLİ (2026-07-29): gövdede "hareket olan günler" listesi vardı, bir güne dokunmak ayrı
// bir detay ekranı açıyordu. Liste + detay iki katmanı, ‹ › oklarıyla TEK katmana indi.
//
// Burada çivilenen kararlar:
//  1. Ekran DÜNDE açılır; ileri ok BUGÜNÜ GEÇEMEZ.
//  2. Kapatılmamış geçmiş gün de gösterilir — ama bant sayım yapılmadığını söyler.
//  3. Ürün dökümü YALNIZ teslim edilenleri sayar (kasa özetiyle aynı küme).
//  4. Kapsam segmenti geçmişte de çalışır; kurye YALNIZ kendini görür (K2).
//  5. Boş gün ile boş KAPSAM ayrı cümlelerdir.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/isletme/gecmis_gun_ekrani.dart';
import 'package:sipario/screens/isletme/gun_arsivi.dart';

import 'support/ekran_yardimcilari.dart';
// Yalnız `semantikDugme`: iki yardımcı dosya da `kapat` tanımlıyor, tam import belirsizlik olur.
import 'support/kabuk_yardimcilari.dart' show semantikDugme;

/// Belirli bir TR gününe düşen ISO damgası (öğlen — gün sınırına yakın oynamalardan uzak).
String _damga(DateTime gun) =>
    DateTime.utc(gun.year, gun.month, gun.day, 9).toIso8601String();

void main() {
  final bugun = DateTime(2026, 7, 29);
  final dun = DateTime(2026, 7, 28);
  final onceki = DateTime(2026, 7, 27);

  /// Verilen güne teslim edilmiş bir sipariş + tahsilat yazar.
  ///
  /// Repo damgayı `correctedNowIso` ile KENDİ koyar (istemci saatini uydurmaz — doğru tasarım),
  /// bu yüzden geçmişe kayıt yazmanın tek yolu oluşturduktan sonra damgayı geri almaktır.
  /// Sipariş VE onun defter satırı birlikte kaydırılır: ikisi ayrı günde kalırsa teslimat
  /// sayısı bir güne, tahsilat başka güne düşer ve test gerçekte olmayan bir durumu sınar.
  Future<void> gunEkle(
    AppDatabase db,
    DateTime gun, {
    required String urun,
    required int adet,
    required int birimKurus,
    String odeme = 'nakit',
    String? kuryeId,
  }) async {
    final cid = await CustomerRepository(db).create(name: 'M-${gun.day}-$urun-$birimKurus');
    final oid = await OrderRepository(db).create(
      customerId: cid,
      lines: [LineInput(productName: urun, unitPriceKurus: birimKurus, qty: adet)],
    );
    if (kuryeId != null) await OrderRepository(db).assign(oid, kuryeId);
    await OrderRepository(db).deliver(oid, paymentType: odeme, collectedByUserId: kuryeId);

    final damga = _damga(gun);
    await (db.update(db.orders)..where((t) => t.id.equals(oid)))
        .write(OrdersCompanion(occurredAt: Value(damga)));
    await (db.update(db.ledgerEntries)..where((t) => t.relatedOrderId.equals(oid)))
        .write(LedgerEntriesCompanion(occurredAt: Value(damga)));
  }

  group('satilanUrunler — yalnız teslim edilenler', () {
    test('çok satandan aza sıralanır, adet ve tutar toplanır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await gunEkle(db, dun, urun: 'Bardak Su', adet: 3, birimKurus: 700);
      await gunEkle(db, dun, urun: 'Damacana', adet: 5, birimKurus: 4500);
      await gunEkle(db, dun, urun: 'Damacana', adet: 2, birimKurus: 4500);

      final urunler = await satilanUrunler(db, dun);

      expect(urunler.map((u) => u.ad), ['Damacana', 'Bardak Su']);
      expect(urunler.first.adet, 7, reason: 'aynı ürün AD üzerinden birleşir');
      expect(urunler.first.tutar, 7 * 4500);
      expect(urunler.last.adet, 3);

      await db.close();
    });

    test('AÇIK sipariş sayılmaz — kasa özetiyle aynı kümeye bakılır', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final cid = await CustomerRepository(db).create(name: 'Bekleyen');
      final oid = await OrderRepository(db).create(
        customerId: cid,
        lines: [LineInput(productName: 'Damacana', unitPriceKurus: 4500, qty: 9)],
      );
      await (db.update(db.orders)..where((t) => t.id.equals(oid)))
          .write(OrdersCompanion(occurredAt: Value(_damga(dun))));

      expect(await satilanUrunler(db, dun), isEmpty,
          reason: 'teslim edilmemiş mal henüz satılmış değildir');

      await db.close();
    });
  });

  group('gunDetayi — kurye kırılımı', () {
    test('o gün işi OLMAYAN kurye kartı çizilmez', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));
      await db.into(db.users).insert(UsersCompanion.insert(
          id: 'k2', name: 'Hakan', role: 'kurye', status: 'active'));
      await gunEkle(db, dun,
          urun: 'Damacana', adet: 2, birimKurus: 4500, kuryeId: 'k1');

      final d = await gunDetayi(db, dun);

      expect(d.kuryeler.map((k) => k.ad), ['Emre'],
          reason: 'izinli kuryenin sıfırlarla dolu kartı ekranı uzatır');
      expect(d.kuryeler.single.teslimat, 1);
      expect(d.kuryeler.single.farkKurus, isNull,
          reason: 'sayım yapılmadıysa "fark 0" YAZILMAZ — mutabık göstermek olurdu');

      await db.close();
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════════════════
  // GEÇMİŞ EKRANI (kullanıcı kararı 2026-08-06) — liste + detay iki katmanı, TEK katmanlı gün
  // gezinmesine dönüştü: "aynı teslim edilen siparişlerde yaptığımız gibi tarihten ileri geri
  // yaparak günlere bakmak daha pratik."
  // ═════════════════════════════════════════════════════════════════════════════════════════

  group('Geçmiş ekranı — gün gezinmesi', () {
    testWidgets('DÜNDE açılır; kasa özeti ve ürün dökümü çizilir', (tester) async {
      // Ekran dünde açılır çünkü BUGÜNÜN özeti zaten bir önceki ekrandır; geçmişe bakmak için
      // her açılışta bir kez geri okuna basmak angarya olurdu.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await gunEkle(db, dun, urun: 'Damacana', adet: 4, birimKurus: 4500);
      });

      await ekranaKoy(tester, GecmisGunEkrani(db: db, bugun: bugun));
      await akislariBekle(tester, tur: 6);

      expect(find.text('28 Temmuz 2026, Salı'), findsOneWidget,
          reason: 'başlık altı seçili günü yazar');
      expect(find.text('Damacana ×4'), findsOneWidget);
      expect(find.text('Toplam · 4 adet'), findsOneWidget);
      expect(find.text('Toplam Tahsilat · 1 teslimat'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('sol ok bir gün geri gider, sağ ok geri getirir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await gunEkle(db, dun, urun: 'Damacana', adet: 4, birimKurus: 4500);
        await gunEkle(db, onceki, urun: 'Bardak Su', adet: 3, birimKurus: 700);
      });

      await ekranaKoy(tester, GecmisGunEkrani(db: db, bugun: bugun));
      await akislariBekle(tester, tur: 6);
      expect(find.text('Damacana ×4'), findsOneWidget);

      await tester.tap(semantikDugme('Önceki gün'));
      await akislariBekle(tester, tur: 6);

      expect(find.text('27 Temmuz 2026, Pazartesi'), findsOneWidget);
      expect(find.text('Bardak Su ×3'), findsOneWidget);
      expect(find.text('Damacana ×4'), findsNothing, reason: 'gün değişti, veri de değişmeli');

      await tester.tap(semantikDugme('Sonraki gün'));
      await akislariBekle(tester, tur: 6);

      expect(find.text('28 Temmuz 2026, Salı'), findsOneWidget);
      expect(find.text('Damacana ×4'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('İLERİ OK BUGÜNÜ GEÇEMEZ — bugüne gelince pasifleşir', (tester) async {
      // Yarının teslimatı yoktur; boş bir ekranda "acaba veri mi kayboldu" diye düşündürmek,
      // engellemekten pahalıdır. Sınır `SiparisTarihSeridi` içinde TEK yerde tanımlı.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await gunEkle(db, bugun, urun: 'Damacana', adet: 1, birimKurus: 4500);
      });

      await ekranaKoy(tester, GecmisGunEkrani(db: db, bugun: bugun));
      await akislariBekle(tester, tur: 6);

      // Dünden bugüne bir adım: ileri ok hâlâ açık olmalı.
      await tester.tap(semantikDugme('Sonraki gün'));
      await akislariBekle(tester, tur: 6);
      expect(find.text('29 Temmuz 2026, Çarşamba'), findsOneWidget);

      // Bugündeyiz: bir adım daha ileri HİÇBİR ŞEY yapmaz (tarih sabit kalır).
      await tester.tap(semantikDugme('Sonraki gün'));
      await akislariBekle(tester, tur: 6);
      expect(find.text('29 Temmuz 2026, Çarşamba'), findsOneWidget,
          reason: 'bugünün ötesine geçilemez');
      expect(find.text('30 Temmuz 2026, Perşembe'), findsNothing);

      await kapat(tester);
    });

    testWidgets('KAPATILMAMIŞ geçmiş gün de gösterilir — bant uyarır', (tester) async {
      // Kullanıcı kararı 2026-07-29: bayi bir günü kapatmayı unuttuğunda o günün cirosunun
      // okunamaz hâle gelmesi, en çok ihtiyaç duyulan anda veriyi gizlerdi. Rakam GÖSTERİLİR,
      // ama sayım yapılmadığı SÖYLENİR.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await gunEkle(db, dun, urun: 'Damacana', adet: 2, birimKurus: 4500);
      });

      await ekranaKoy(tester, GecmisGunEkrani(db: db, bugun: bugun));
      await akislariBekle(tester, tur: 6);

      expect(find.textContaining('Bu gün kapatılmadı'), findsOneWidget);
      expect(find.text('Toplam Tahsilat · 1 teslimat'), findsOneWidget,
          reason: 'kapatılmamış gün de rakamlarını gösterir');

      await kapat(tester);
    });

    testWidgets('KAPATILMIŞ geçmiş gün yeşil bant + kapanış kaydı gösterir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await gunEkle(db, dun, urun: 'Damacana', adet: 2, birimKurus: 4500);
        await db.into(db.dayClosings).insert(DayClosingsCompanion.insert(
              id: 'kapanis-dun',
              scope: 'day',
              occurredAt: _damga(dun),
              countedCashKurus: const Value(9000),
            ));
      });

      await ekranaKoy(tester, GecmisGunEkrani(db: db, bugun: bugun));
      await akislariBekle(tester, tur: 6);

      expect(find.textContaining('kapatıldı ve arşivlendi'), findsOneWidget);
      expect(find.textContaining('Bu gün kapatılmadı'), findsNothing);
      expect(find.text('Kapanış Kayıtları'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('HAREKETSİZ günde nötr boş durum çizilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await gunEkle(db, onceki, urun: 'Damacana', adet: 2, birimKurus: 4500);
      });

      // Ekran DÜNDE açılır; hareket bir gün öncesinde, yani dün boş.
      await ekranaKoy(tester, GecmisGunEkrani(db: db, bugun: bugun));
      await akislariBekle(tester, tur: 6);

      expect(find.text('Bu güne ait hareket yok'), findsOneWidget);
      expect(find.text('Kasa Özeti'), findsNothing,
          reason: 'boş günde sıfırlarla dolu kart gürültüdür');

      await kapat(tester);
    });

    testWidgets('KURYE kapsam segmentinde YALNIZ kendini görür (K2)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k1', name: 'Emre', role: 'kurye', status: 'active'));
        await db.into(db.users).insert(UsersCompanion.insert(
            id: 'k2', name: 'Hakan', role: 'kurye', status: 'active'));
        await gunEkle(db, dun,
            urun: 'Damacana', adet: 2, birimKurus: 4500, kuryeId: 'k1');
      });

      await ekranaKoy(
        tester,
        GecmisGunEkrani(db: db, bugun: bugun, rol: 'kurye', kullaniciId: 'k1'),
      );
      await akislariBekle(tester, tur: 6);

      expect(find.text('Emre'), findsOneWidget, reason: 'kendi kapsamı segmentte durur');
      expect(find.text('Hakan'), findsNothing,
          reason: 'kurye başka kuryenin kasasını OKUYAMAZ — göremediğini de kapatamaz');

      await kapat(tester);
    });
  });

  group('Tarih biçimi', () {
    test('başlık altı TAM tarih yazar — yıl dahil', () {
      // Yıl BURADA yazılır (gezinme şeridindeki kısa etiketin aksine): geçmişe ok ok gidilirken
      // hangi yılda olunduğu tek başına ay/gün'den okunamaz.
      expect(gunTamBasligi(DateTime(2026, 7, 28)), '28 Temmuz 2026, Salı');
      expect(gunTamBasligi(DateTime(2026, 1, 5)), '5 Ocak 2026, Pazartesi');
    });
  });
}
