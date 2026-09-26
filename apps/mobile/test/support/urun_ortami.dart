// ÜRÜN TESTLERİNİN FİKSTÜRÜ — bellek içi veritabanı + kayıtlı ürün + silme olayının okunması.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/product_repository.dart';

class UrunOrtami {
  UrunOrtami() : db = AppDatabase(NativeDatabase.memory());

  final AppDatabase db;

  late final ProductRepository repo = ProductRepository(db);

  Future<String> ekle(String ad, {int kurus = 4500}) =>
      repo.create(name: ad, unitPriceKurus: kurus);

  Future<Product> oku(String id) =>
      (db.select(db.products)..where((t) => t.id.equals(id))).getSingle();

  /// Ürün için giden kutusuna yazılan SON olay (op + çözülmüş yük).
  Future<({String op, Map<String, dynamic> yuk})> sonOlay(String id) async {
    final satirlar = await (db.select(db.outbox)
          ..where((t) => t.entityType.equals('product') & t.entityId.equals(id)))
        .get();
    final son = satirlar.last;
    return (op: son.op, yuk: jsonDecode(son.payload) as Map<String, dynamic>);
  }

  Future<void> kapat() => db.close();
}
