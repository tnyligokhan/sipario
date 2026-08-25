import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/screens/products/birimler.dart';
import 'package:sipario/screens/products/product_form_sheet.dart';

import 'support/ekran_yardimcilari.dart';

/// ÜRÜN BİRİMİ — serbest metinden açılır menüye geçiş (kullanıcı isteği 2026-08-11).
///
/// BU DOSYANIN ASIL İDDİASI VERİ KAYBI YASAĞIDIR. Birim bugüne kadar serbest metindi ve sahadaki
/// ürünler listede olmayan değerler taşıyor ("damacana", "şişe", "büyük boy"). Bir menüye geçmek,
/// o değerleri sessizce "adet"e düşüren bir dönüşüm DEĞİLDİR: bayi ürün kartını yalnızca fiyatını
/// düzeltmek için açtığında biriminin değişmesi, ancak müşteri sorunca fark edilecek bir hatadır.
///
/// Kalan testler menünün kendisini kilitler. Liste içeriği bir ÜRÜN KARARIDIR (2026-08-11'de
/// kullanıcı seçti); burada içeriğin kendisi değil, listenin TEK KAYNAK olduğu ve saklanan
/// değerin gösterimden ayrı durduğu sınanır.
void main() {
  group('birimBul() — saklanan değerin menü karşılığı', () {
    test('listedeki değeri bulur', () {
      expect(birimBul('adet')?.etiket, 'Adet');
      expect(birimBul('koli')?.etiket, 'Koli');
    });

    test('büyük/küçük harf duyarsızdır — sahadan "ADET" de gelebilir', () {
      expect(birimBul('Adet')?.deger, 'adet');
      expect(birimBul('ADET')?.deger, 'adet');
    });

    test('TÜRKÇE küçültme: "LİTRE" eşleşir — Dart\'ın toLowerCase\'i yerelden bağımsızdır', () {
      // 'İ' için Dart birleşik nokta üretir ve eşleşme sessizce kaçardı; bu yüzden dosyada
      // elle küçültme var. Test o kararın hâlâ yerinde olduğunu kilitler.
      expect(birimBul('LİTRE')?.deger, 'litre');
    });

    test('listede OLMAYAN değer için null döner — uydurma eşleşme YOK', () {
      expect(birimBul('damacana'), isNull);
      expect(birimBul('şişe'), isNull);
      expect(birimBul(null), isNull);
    });
  });

  group('kBirimler — tek kaynak', () {
    test('saklanan değerler küçük harf ve TEKİL', () {
      final degerler = kBirimler.map((b) => b.deger).toList();
      expect(degerler, degerler.map((d) => d.toLowerCase()).toList());
      expect(degerler.toSet(), hasLength(degerler.length), reason: 'tekrar eden birim yok');
    });

    test('varsayılan birim listede vardır', () {
      // Varsayılan listede olmasaydı, YENİ ürün açan bayi daha ilk karede "listede olmayan
      // değer" durumuna düşerdi.
      expect(birimBul(kVarsayilanBirim), isNotNull);
    });
  });

  group('ürün formu — sahadaki serbest birim KORUNUR', () {
    Future<AppDatabase> kur(String birim) async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: 'u-1',
            name: 'Damacana 19 L',
            unitPriceKurus: 4500,
            unit: Value(birim),
            updatedOccurredAt: '2026-08-11T00:00:00.000Z',
          ));
      return db;
    }

    Future<Product> urun(WidgetTester tester, AppDatabase db) async =>
        (await tester.runAsync(
          () => (db.select(db.products)..where((t) => t.id.equals('u-1'))).getSingle(),
        ))!;

    /// Formu DÜZENLEME kipinde açar. Ürün sheet açılmadan ÖNCE okunur: `sheetAc`in geri çağrısı
    /// senkron bir gövdede çalışır ve içinde drift beklemek sahte zamanda asılırdı.
    Future<void> formuAc(WidgetTester tester, AppDatabase db) async {
      final mevcut = await urun(tester, db);
      await sheetAc(tester, (ctx) => urunFormuAc(ctx, db: db, urun: mevcut));
    }

    testWidgets('LİSTEDE OLMAYAN birim ("damacana") kart açılıp kaydedilince AYNEN kalır',
        (tester) async {
      // ⭐ Bu dosyanın varlık sebebi. "Listede yoksa varsayılana düş" diye tek bir dal
      // eklenseydi bu test kırmızıya döner; ürün kartı sessizce "adet"e düşerdi.
      final db = await kur('damacana');
      await formuAc(tester, db);

      // Kullanıcı yalnız FİYATI düzeltiyor — birime hiç dokunmuyor.
      await tester.enterText(find.byType(TextField).at(1), '50');
      await tester.pump();
      await dokun(tester, find.text('Kaydet'));

      expect((await urun(tester, db)).unit, 'damacana');

      await kapat(tester);
    });

    testWidgets('listedeki birim de dokunulmadan korunur', (tester) async {
      final db = await kur('koli');
      await formuAc(tester, db);

      await tester.enterText(find.byType(TextField).at(1), '50');
      await tester.pump();
      await dokun(tester, find.text('Kaydet'));

      expect((await urun(tester, db)).unit, 'koli');

      await kapat(tester);
    });
  });
}
