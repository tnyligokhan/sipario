import 'dart:io';

// `show Value`: drift'in `isNull` yardımcısı matcher'ınkiyle çakışır ve bu dosyanın iddiası
// "kolon NULL mı" olduğu için matcher'ınki kazanmalı.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// v17→v18 — SEPET SATIR NOTU (`order_lines.note`) + FAVORİ ÜRÜNLER
/// (`customers.favorite_product_ids`).
///
/// `migration_v15_test.dart` ve `migration_v17_test.dart` ile aynı aileden ve AYNI ARIZAYA karşı:
/// 2026-08-09'da 13 kolon `tenant_settings`e eklendi, `onUpgrade` yazıldı ama `schemaVersion`
/// artırılmadı — sahadaki cihazlarda ALTER TABLE'lar HİÇ koşmadı ve o tabloya dokunan her sorgu
/// patladı. Bellek içi veritabanıyla koşan yüzlerce test bunu göremez: hepsi `onCreate` yolundan
/// geçer ve orada şema her zaman tamdır. Bu dosya tam olarak "önceki sürümü kurulu olan cihaz"
/// yolundan geçer.
///
/// BU GÖÇÜN KENDİNE ÖZGÜ RİSKİ: `order_lines` sipariş DETAYININ okuduğu tablodur. Kolon eksik
/// kalırsa yalnız not görünmez değil, **sipariş satırlarını çeken sorgu komple patlar** — yani
/// bayi siparişi açamaz.
void main() {
  test(
      'v17→v18: order_lines.note ve customers.favorite_product_ids sahadaki cihaza EKLENİR, '
      'eski sipariş/müşteri verisi aynen durur, yeni kolonlar NULL gelir ve favori çözümü '
      'boş listeye düşer (uydurma favori YOK)', () async {
    final file = File(p.join(
      Directory.systemTemp.path,
      'sipario_v17v18_${DateTime.now().microsecondsSinceEpoch}.db',
    ));
    if (file.existsSync()) file.deleteSync();

    // 1) Güncel şemayla kur + korunması gereken veriyi yaz.
    final v18 = AppDatabase(NativeDatabase(file));
    await v18.into(v18.customers).insert(CustomersCompanion.insert(
          id: 'm-1',
          name: 'Kadir Doğan',
          balanceKurus: const Value(128000),
          updatedOccurredAt: '2026-08-11T00:00:00.000Z',
        ));
    await v18.into(v18.orders).insert(OrdersCompanion.insert(
          id: 's-1',
          customerId: const Value('m-1'),
          occurredAt: '2026-08-11T10:00:00.000Z',
        ));
    await v18.into(v18.orderLines).insert(OrderLinesCompanion.insert(
          id: 'sr-1',
          orderId: 's-1',
          productName: 'Damacana 19 L',
          unitPriceKurus: 4500,
          qty: 2,
          lineTotalKurus: 9000,
        ));
    await v18.close();

    // 2) Dosyayı v17'ye GERİ SAR: iki kolonu düşür, damgayı 17 yap. Sahadaki bir cihazın
    //    yükseltmeden önceki diskteki hâli birebir budur.
    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE order_lines DROP COLUMN note');
    raw.execute('ALTER TABLE customers DROP COLUMN favorite_product_ids');
    raw.execute('PRAGMA user_version = 17');
    raw.close();

    // 3) Yeniden aç → onUpgrade(from: 17, to: 18) koşmalı.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) file.deleteSync();
    });

    Future<Set<String>> kolonlar(String tablo) => db
        .customSelect('PRAGMA table_info($tablo)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toSet());

    expect(await kolonlar('order_lines'), contains('note'));
    expect(await kolonlar('customers'), contains('favorite_product_ids'));

    // Eski veri AYNEN duruyor (additif migration; para ve sipariş korunur).
    final musteri = await (db.select(db.customers)..where((t) => t.id.equals('m-1'))).getSingle();
    expect(musteri.name, 'Kadir Doğan');
    expect(musteri.balanceKurus, 128000);

    final satir = await (db.select(db.orderLines)..where((t) => t.id.equals('sr-1'))).getSingle();
    expect(satir.productName, 'Damacana 19 L');
    expect(satir.lineTotalKurus, 9000);

    // ⭐ Yeni kolonlar NULL: "not yok" ve "favorisi yok" gerçek durumlardır, uydurulmaz.
    expect(satir.note, isNull);
    expect(musteri.favoriteProductIds, isNull);

    // Ve favori çözümü NULL'da çökmeden boş listeye düşer — yükseltmeden hemen sonraki ilk
    // karede müşteri kartı açılabilmelidir.
    expect(favoriIdleriCoz(musteri.favoriteProductIds), isEmpty);

    // ⭐ ASIL İDDİA: sipariş satırlarını çeken sorgunun kendisi. Kolon eksikken bu satır
    // `SqliteException(1): no such column: order_lines.note` ile kırmızı yanardı ve sahada
    // bayi siparişi HİÇ açamazdı.
    final satirlar =
        await (db.select(db.orderLines)..where((t) => t.orderId.equals('s-1'))).get();
    expect(satirlar, hasLength(1));
  });
}
