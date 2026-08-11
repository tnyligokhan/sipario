import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/repo/order_repository.dart';

/// FAVORİ ÜRÜNLER + SEPET SATIR NOTU — veri katmanı sözleşmesi (kullanıcı isteği 2026-08-11).
///
/// Favori listesi müşteri satırının İÇİNDE bir JSON dizidir (ayrı tablo değil). Bu karar bir
/// bedelle gelir ve testlerin çoğu o bedeli kilitler: müşteri satırı bu uygulamada HER YERDE
/// okunur (arayan-tanıma, sipariş formu, borçlular). Bozuk bir JSON'da atılacak tek istisna
/// bir müşteriyi değil, O EKRANIN TAMAMINI kaybettirir — bu yüzden çözümleme hiçbir girdide
/// çökmemelidir.
void main() {
  group('favoriIdleriCoz() — hiçbir girdide çökmez', () {
    test('null ve boş metin boş listedir', () {
      expect(favoriIdleriCoz(null), isEmpty);
      expect(favoriIdleriCoz(''), isEmpty);
      expect(favoriIdleriCoz('   '), isEmpty);
    });

    test('bozuk JSON boş listedir — ekran açılmaya devam eder', () {
      expect(favoriIdleriCoz('{bu json değil'), isEmpty);
      expect(favoriIdleriCoz('["a", '), isEmpty);
    });

    test('dizi olmayan JSON boş listedir (nesne / sayı / metin)', () {
      expect(favoriIdleriCoz('{"a":1}'), isEmpty);
      expect(favoriIdleriCoz('42'), isEmpty);
      expect(favoriIdleriCoz('"urun-1"'), isEmpty);
    });

    test('dizi içindeki metin olmayan elemanlar ATLANIR, gerisi okunur', () {
      expect(favoriIdleriCoz('["a", 5, null, {"x":1}, "b"]'), ['a', 'b']);
    });

    test('SIRA KORUNUR — bayinin tercihidir, alfabetik değil', () {
      expect(favoriIdleriCoz('["z-urun","a-urun","m-urun"]'), ['z-urun', 'a-urun', 'm-urun']);
    });
  });

  group('favoriIdleriDuzelt() — yazım öncesi normalleştirme', () {
    test('tekrarlar teklenir ve İLK görülen sıra korunur', () {
      // Aynı ürünü ikinci kez eklemek onu SONA taşımamalı — bayi listeyi sürükleyerek dizer.
      expect(favoriIdleriDuzelt(['a', 'b', 'a', 'c', 'b']), ['a', 'b', 'c']);
    });

    test('boş / yalnız boşluk elemanlar elenir, kenar boşlukları kırpılır', () {
      expect(favoriIdleriDuzelt(['  a  ', '', '   ', 'b']), ['a', 'b']);
    });

    test('üst sınır uygulanır', () {
      final cok = List.generate(kFavoriUstSinir + 5, (i) => 'urun-$i');
      expect(favoriIdleriDuzelt(cok), hasLength(kFavoriUstSinir));
      expect(favoriIdleriDuzelt(cok).first, 'urun-0', reason: 'baştan kesilir, sondan değil');
    });
  });

  group('favoriUrunleriOku() — id → ürün çözümü', () {
    Future<AppDatabase> kur({required String favoriJson}) async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: 'u-1',
            name: 'Damacana 19 L',
            unitPriceKurus: 4500,
            updatedOccurredAt: '2026-08-11T00:00:00.000Z',
          ));
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: 'u-2',
            name: 'Küçük Su',
            unitPriceKurus: 500,
            isActive: const Value(false), // "stokta yok"
            updatedOccurredAt: '2026-08-11T00:00:00.000Z',
          ));
      await db.into(db.customers).insert(CustomersCompanion.insert(
            id: 'm-1',
            name: 'Kadir Doğan',
            favoriteProductIds: Value(favoriJson),
            updatedOccurredAt: '2026-08-11T00:00:00.000Z',
          ));
      return db;
    }

    test('ÇÖZÜLEMEYEN id sessizce elenir — silinmiş ürün favoride kalmış olabilir', () async {
      final db = await kur(favoriJson: '["u-1","silinmis-urun","u-2"]');
      addTearDown(db.close);

      final urunler = await favoriUrunleriOku(db, 'm-1');
      expect(urunler.map((u) => u.id), ['u-1', 'u-2']);
    });

    test('BAYİNİN SIRASI korunur — katalog sırası değil', () async {
      final db = await kur(favoriJson: '["u-2","u-1"]');
      addTearDown(db.close);

      expect((await favoriUrunleriOku(db, 'm-1')).map((u) => u.id), ['u-2', 'u-1']);
    });

    test('"stokta yok" ürün LİSTEDE KALIR — bayinin her zamanki siparişi kaybolmaz', () async {
      // `isActive` bilinçli olarak filtrelenmiyor: soluk çizmek ekranın kararıdır, burada
      // elemek bayiye ürünü stok işareti yüzünden sessizce kaybettirirdi.
      final db = await kur(favoriJson: '["u-2"]');
      addTearDown(db.close);

      expect((await favoriUrunleriOku(db, 'm-1')).single.id, 'u-2');
    });

    test('favorisi olmayan müşteride boş liste — bölüm çizilmeyecek', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.customers).insert(CustomersCompanion.insert(
            id: 'm-9',
            name: 'Yeni Müşteri',
            updatedOccurredAt: '2026-08-11T00:00:00.000Z',
          ));

      expect(await favoriUrunleriOku(db, 'm-9'), isEmpty);
    });
  });

  group('sepet satır notu — uçtan uca yazım', () {
    Future<AppDatabase> kur() async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.syncMeta).insertOnConflictUpdate(const SyncMetaCompanion(
            id: Value(1),
            deviceId: Value('cihaz-A'),
          ));
      return db;
    }

    test('not SATIRA yazılır ve outbox payload\'ında satır nesnesi içinde gider', () async {
      final db = await kur();
      addTearDown(db.close);

      final siparisId = await OrderRepository(db).create(lines: [
        LineInput(
          productName: 'Damacana 19 L',
          unitPriceKurus: 4500,
          qty: 2,
          note: 'buzlu olsun',
        ),
        LineInput(productName: 'Küçük Su', unitPriceKurus: 500, qty: 1),
      ]);

      // Yerel satır
      final satirlar = await (db.select(db.orderLines)
            ..where((t) => t.orderId.equals(siparisId)))
          .get();
      final notlu = satirlar.firstWhere((s) => s.productName == 'Damacana 19 L');
      final notsuz = satirlar.firstWhere((s) => s.productName == 'Küçük Su');
      expect(notlu.note, 'buzlu olsun');
      expect(notsuz.note, isNull, reason: 'not girilmeyen satır NULL kalır, boş metin değil');

      // ⭐ Sunucuya gidecek olay: not satır nesnesinin İÇİNDE. Siparişin kendi `note`u ayrı
      // bir alandır ve karıştırılırsa bayi "buzlu olsun"u siparişin tamamına yazılmış görür.
      final olay = await db.select(db.outbox).getSingle();
      final payload = jsonDecode(olay.payload) as Map<String, Object?>;
      final lines = (payload['lines'] as List).cast<Map<String, Object?>>();
      final payloadNotlu =
          lines.firstWhere((l) => l['product_name'] == 'Damacana 19 L');
      expect(payloadNotlu['note'], 'buzlu olsun');
      expect(payload['note'], isNull, reason: 'sipariş notu satır notundan AYRI alandır');
    });
  });
}
