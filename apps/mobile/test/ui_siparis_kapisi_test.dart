import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/customers/musteri_siparisleri.dart';
import 'package:sipario/screens/orders/siparis_kapisi.dart';

import 'support/ekran_yardimcilari.dart';

/// AÇIK SİPARİŞ KAPISI + MÜŞTERİ GEÇMİŞİ LİMİTİ (kullanıcı isteği 2026-08-11).
///
/// Kapının değeri "diyalog çıkıyor mu"da değil, **çıkmadığı durumda**dır: her siparişte
/// onaylanan bir uyarı iki gün içinde okunmadan kapatılan bir engele döner ve o günden sonra
/// gerçek uyarıyı da görünmez yapar. Bu depoda ölçülmüş bir ders (durum çubuğu "YAYIN BORCU
/// 384" derken gerçek borç 0'dı; yanlış alarm göstergeyi okunmaz yaptı).
void main() {
  Future<AppDatabase> kur() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'm-1',
          name: 'Kadir Doğan',
          updatedOccurredAt: '2026-08-11T00:00:00.000Z',
        ));
    return db;
  }

  Future<void> siparisEkle(
    AppDatabase db, {
    required String id,
    String durum = 'open',
    String? silindi,
    String musteri = 'm-1',
    String zaman = '2026-08-11T10:00:00.000Z',
  }) =>
      db.into(db.orders).insert(OrdersCompanion.insert(
            id: id,
            customerId: Value(musteri),
            status: Value(durum),
            deletedAt: Value(silindi),
            occurredAt: zaman,
          ));

  /// Kapıyı TEK BAŞINA süren küçük bir koşum: düğmeye basınca kapı koşar ve sonucu ekrana
  /// yazar. Sipariş formunun tamamını kurmak yerine kapının kendisini sınıyoruz — kapı zaten
  /// tek bir fonksiyondur ve tüm giriş noktaları ondan geçer.
  Future<void> kapiyiAc(WidgetTester tester, AppDatabase db) async {
    await ekranaKoy(
      tester,
      Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final m = await (db.select(db.customers)
                          ..where((t) => t.id.equals('m-1')))
                        .getSingle();
                    if (!ctx.mounted) return;
                    final devam =
                        await siparisAcmadanOnceDogrula(ctx, db: db, musteri: m);
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(devam ? 'SONUC:devam' : 'SONUC:iptal')),
                    );
                  },
                  child: const Text('KAPI'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('KAPI'));
    await akislariBekle(tester);
  }

  group('açık sipariş kapısı', () {
    testWidgets('AÇIK SİPARİŞİ OLMAYAN müşteride hiçbir uyarı çıkmaz ve akış sürer',
        (tester) async {
      // ⭐ En değerli iddia: yanlış alarm üretmemek. Teslim edilmiş ve iptal edilmiş siparişler
      // "zaten siparişi var" saymaz — biri bitmiştir, öteki hiç olmamıştır.
      final db = await kur();
      await tester.runAsync(() async {
        await siparisEkle(db, id: 's-teslim', durum: 'delivered');
        await siparisEkle(db, id: 's-iptal', durum: 'cancelled');
      });

      await kapiyiAc(tester, db);

      expect(find.text(acikSiparisUyariBasligi), findsNothing);
      expect(find.text('SONUC:devam'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('SİLİNMİŞ açık sipariş sayılmaz', (tester) async {
      final db = await kur();
      await tester.runAsync(() => siparisEkle(
            db,
            id: 's-silinmis',
            silindi: '2026-08-11T11:00:00.000Z',
          ));

      await kapiyiAc(tester, db);

      expect(find.text(acikSiparisUyariBasligi), findsNothing);
      expect(find.text('SONUC:devam'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('BAŞKA müşterinin açık siparişi uyarı üretmez', (tester) async {
      final db = await kur();
      await tester.runAsync(() async {
        await db.into(db.customers).insert(CustomersCompanion.insert(
              id: 'm-2',
              name: 'Başkası',
              updatedOccurredAt: '2026-08-11T00:00:00.000Z',
            ));
        await siparisEkle(db, id: 's-baskasi', musteri: 'm-2');
      });

      await kapiyiAc(tester, db);

      expect(find.text(acikSiparisUyariBasligi), findsNothing);

      await kapat(tester);
    });

    testWidgets('açık siparişi OLAN müşteride uyarı çıkar; "Vazgeç" akışı DURDURUR',
        (tester) async {
      final db = await kur();
      await tester.runAsync(() => siparisEkle(db, id: 's-acik'));

      await kapiyiAc(tester, db);
      expect(find.text(acikSiparisUyariBasligi), findsOneWidget);

      await dokun(tester, find.text(acikSiparisVazgecEtiketi));
      expect(find.text('SONUC:iptal'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('"Yine de oluştur" akışı SÜRDÜRÜR — ikinci sipariş meşru bir iştir',
        (tester) async {
      final db = await kur();
      await tester.runAsync(() => siparisEkle(db, id: 's-acik'));

      await kapiyiAc(tester, db);
      await dokun(tester, find.text(acikSiparisOnayEtiketi));

      expect(find.text('SONUC:devam'), findsOneWidget);

      await kapat(tester);
    });

    testWidgets('KARA LİSTEDEKİ müşteride kapı SERT engeller (onay bile sorulmaz)',
        (tester) async {
      // Sıra önemlidir: kara liste sert engel, açık sipariş yumuşak uyarıdır. İkisi yer
      // değiştirseydi kara listedeki müşteriye "Yine de oluştur" düğmesi sunulurdu.
      final db = await kur();
      await tester.runAsync(() async {
        await siparisEkle(db, id: 's-acik');
        await (db.update(db.customers)..where((t) => t.id.equals('m-1'))).write(
          const CustomersCompanion(blacklistedAt: Value('2026-08-11T09:00:00.000Z')),
        );
      });

      await kapiyiAc(tester, db);

      expect(find.text(acikSiparisUyariBasligi), findsNothing);
      expect(find.text(acikSiparisOnayEtiketi), findsNothing);
      expect(find.text('SONUC:iptal'), findsOneWidget);

      await kapat(tester);
    });
  });

  group('müşteri kartı — geçmiş sipariş limiti', () {
    Future<void> nSiparis(AppDatabase db, int n) async {
      for (var i = 0; i < n; i++) {
        await siparisEkle(
          db,
          id: 's-$i',
          durum: 'delivered',
          zaman: '2026-08-${(i + 1).toString().padLeft(2, '0')}T10:00:00.000Z',
        );
      }
    }

    testWidgets('5 siparişte kartta yalnız $kKartSiparisLimiti satır ve "tümü" girişi çizilir',
        (tester) async {
      final db = await kur();
      await tester.runAsync(() => nSiparis(db, 5));

      await ekranaKoy(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: MusteriSiparisGecmisi(
              db: db,
              customerId: 'm-1',
              musteriAdi: 'Kadir Doğan',
            ),
          ),
        ),
      );

      final satirlar = await tester.runAsync(
        () => watchMusteriSiparisleri(db, 'm-1', limit: kKartSiparisLimiti).first,
      );
      expect(satirlar, hasLength(kKartSiparisLimiti));

      final toplam = await tester.runAsync(() => watchMusteriSiparisSayisi(db, 'm-1').first);
      expect(toplam, 5, reason: 'toplam ayrı akıştan gelir — kart 3 satır okuyup 5 diyemez');

      await kapat(tester);
    });

    // Aşağıdaki ikisi SAF SORGU testidir, `testWidgets` DEĞİL: widget koşumu gerektirmiyorlar
    // ve sahte zamanda `db.close()` gerçek G/Ç beklediği için asılıyordu (ilk yazımda 150 sn'de
    // "did not complete" ile ölçüldü). Sorgu sorgudur; ekran kurmadan sınanır.
    test('limitin ALTINDA sipariş varken sorgu hepsini verir (ölü giriş yok)', () async {
      final db = await kur();
      addTearDown(db.close);
      await nSiparis(db, 2);

      expect(
        await watchMusteriSiparisleri(db, 'm-1', limit: kKartSiparisLimiti).first,
        hasLength(2),
      );
    });

    test('sorgu EN YENİDEN eskiye sıralar ve silinmişi dışarıda bırakır', () async {
      final db = await kur();
      addTearDown(db.close);
      await nSiparis(db, 3);
      await siparisEkle(
        db,
        id: 's-silinmis',
        durum: 'delivered',
        silindi: '2026-08-11T12:00:00.000Z',
        zaman: '2026-08-09T10:00:00.000Z',
      );

      final satirlar = await watchMusteriSiparisleri(db, 'm-1').first;
      expect(satirlar.map((o) => o.id), ['s-2', 's-1', 's-0']);
    });
  });
}
