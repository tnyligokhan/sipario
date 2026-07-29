// GÜN SONU — GEÇMİŞ GÜNLER ve GÜN DETAYI (kullanıcı isteği 2026-07-29).
//
// Şikâyet: "arşivde gün hesabı gün hesabı yazmak yerine 28.07 29.07 gibi ilgili günün tarihi
// olmalı, tıklandığında hesaplardan ekstra olarak kaç ürün satıldı gibi şeyler gözükmeli,
// kuryelerin detayını ilgili günün içinde seçerek görmek daha mantıklı."
//
// Üç karar burada çivileniyor:
//  1. Liste HAREKET OLAN her günden doğar — kapatılmamış gün de listelenir (işaretli).
//  2. Ürün dökümü YALNIZ teslim edilenleri sayar (kasa özetiyle aynı küme).
//  3. Kurye kırılımı günün İÇİNDEDİR ve o gün işi olmayan kurye çizilmez.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';
import 'package:sipario/screens/isletme/gun_arsivi.dart';
import 'package:sipario/screens/isletme/gun_detay_ekrani.dart';

import 'support/ekran_yardimcilari.dart';

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

  group('gecmisGunler — hareket olan HER gün', () {
    test('kapatılmamış gün de listelenir ve işaretlenir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await gunEkle(db, dun, urun: 'Damacana', adet: 2, birimKurus: 4500);
      await gunEkle(db, onceki, urun: 'Damacana', adet: 1, birimKurus: 4500);
      // Kapanış kaydı DOĞRUDAN yazılır: `kapat()` damgayı ŞİMDİ koyar (ürün doğrusu budur —
      // gün sonu o gün kapatılır, geçmişe dönük kapatma yoktur), dolayısıyla geçmiş bir günün
      // kapanmış hâlini kurmanın tek yolu kaydı o günün damgasıyla yazmaktır.
      await db.into(db.dayClosings).insert(DayClosingsCompanion.insert(
            id: 'kapanis-dun',
            scope: 'day',
            occurredAt: _damga(dun),
            countedCashKurus: const Value(9000),
          ));

      final gunler = await gecmisGunler(db, bugun: bugun);

      // Yeni üstte.
      expect(gunler.map((g) => g.gun), [dun, onceki]);
      expect(gunler.first.kapatildi, isTrue);
      expect(gunler.last.kapatildi, isFalse,
          reason: 'kapatılmamış gün DÜŞMEZ — yoksa o günün cirosu okunamaz hâle gelirdi');
      expect(gunler.first.tahsilat, 9000);
      expect(gunler.first.teslimat, 1);

      await db.close();
    });

    test('BUGÜN listede yoktur — kendi kartı var', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await gunEkle(db, bugun, urun: 'Damacana', adet: 1, birimKurus: 4500);

      expect(await gecmisGunler(db, bugun: bugun), isEmpty);

      await db.close();
    });

    test('hiç hareket yoksa liste boştur', () async {
      final db = AppDatabase(NativeDatabase.memory());
      expect(await gecmisGunler(db, bugun: bugun), isEmpty);
      await db.close();
    });
  });

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

  group('Gün detay ekranı', () {
    testWidgets('tarih başlığı · ürün dökümü · kasa özeti çizilir', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await gunEkle(db, dun, urun: 'Damacana', adet: 4, birimKurus: 4500);
      });

      await ekranaKoy(tester, GunDetayEkrani(db: db, gun: dun));
      await akislariBekle(tester, tur: 6);

      expect(find.text('28.07 Salı'), findsOneWidget);
      expect(find.text('28 Temmuz 2026, Salı'), findsOneWidget);
      expect(find.text('Damacana ×4'), findsOneWidget);
      expect(find.text('Toplam · 4 adet'), findsOneWidget);
      expect(find.text('Toplam Tahsilat · 1 teslimat'), findsOneWidget);

      await kapat(tester);
    });
  });

  group('Tarih biçimleri', () {
    test('liste başlığı gün + gün adı, detay başlığı tam tarih', () {
      expect(gunBasligi(DateTime(2026, 7, 28)), '28.07 Salı');
      expect(gunTamBasligi(DateTime(2026, 7, 28)), '28 Temmuz 2026, Salı');
      // Tek haneli gün/ay iki haneye dolgulanır — liste sütunu kaymasın.
      expect(gunBasligi(DateTime(2026, 1, 5)), '05.01 Pazartesi');
    });
  });
}
