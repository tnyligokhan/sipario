import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/product_repository.dart';
import '../money.dart';

/// Ürün listesi (Menü → Ürünler): ekle / düzenle / pasifle. Ürünler senkronla da gelir; taze kurulumda
/// bayinin ilk ürününü buradan girmesi gerekir — yoksa sipariş ekranı boş kalır.
/// Silme YOK, PASİFLEME var (geçmiş sipariş satırları ad/fiyatı kendi içinde taşır, bozulmaz).
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key, required this.db, required this.writable});

  final AppDatabase db;
  final bool writable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ürünler')),
      body: StreamBuilder<List<Product>>(
        stream: watchProducts(db, activeOnly: false),
        builder: (context, snap) {
          final products = snap.data;
          if (products == null) return const Center(child: CircularProgressIndicator());
          if (products.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz ürün yok.\nSağ alttan ekleyin — sipariş satırları buradan seçilir.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = products[i];
              return ListTile(
                title: Text(p.name,
                    style: p.isActive ? null : const TextStyle(decoration: TextDecoration.lineThrough)),
                subtitle: Text(p.isActive ? '${formatKurus(p.unitPriceKurus)} / ${p.unit}' : 'Pasif'),
                trailing: writable
                    ? PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'duzenle') {
                            await showProductDialog(context, ProductRepository(db), product: p);
                          } else if (v == 'pasifle') {
                            await ProductRepository(db).deactivate(p.id);
                          } else if (v == 'aktif') {
                            await ProductRepository(db).update(p.id,
                                name: p.name,
                                unitPriceKurus: p.unitPriceKurus,
                                unit: p.unit,
                                isActive: true);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                          if (p.isActive)
                            const PopupMenuItem(value: 'pasifle', child: Text('Pasifle'))
                          else
                            const PopupMenuItem(value: 'aktif', child: Text('Yeniden aktif et')),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: writable
            ? () => showProductDialog(context, ProductRepository(db))
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Salt-okunur kip: yeni kayıt eklenemez.'))),
        icon: const Icon(Icons.add),
        label: const Text('Ürün'),
      ),
    );
  }
}

/// Ürün ekleme/düzenleme diyaloğu. Fiyat kullanıcı yazımından kuruşa `parseKurus` ile çevrilir;
/// geçersiz yazım SESSİZCE kabul edilmez (para).
Future<void> showProductDialog(BuildContext context, ProductRepository repo, {Product? product}) async {
  final name = TextEditingController(text: product?.name ?? '');
  final price = TextEditingController(
      text: product == null ? '' : (product.unitPriceKurus / 100).toStringAsFixed(2).replaceAll('.', ','));
  final unit = TextEditingController(text: product?.unit ?? 'adet');
  final formKey = GlobalKey<FormState>();

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(product == null ? 'Yeni ürün' : 'Ürünü düzenle'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ürün adı *', hintText: '19 L damacana'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad gerekli' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Birim fiyat *', suffixText: '₺'),
              validator: (v) {
                final k = parseKurus(v ?? '');
                if (k == null) return 'Geçerli bir fiyat girin';
                if (k == 0) return 'Fiyat sıfır olamaz';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: unit,
              decoration: const InputDecoration(labelText: 'Birim', hintText: 'adet / koli'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );

  if (saved != true) return;
  final kurus = parseKurus(price.text)!;
  final unitText = unit.text.trim().isEmpty ? 'adet' : unit.text.trim();
  if (product == null) {
    await repo.create(name: name.text.trim(), unitPriceKurus: kurus, unit: unitText);
  } else {
    await repo.update(product.id,
        name: name.text.trim(), unitPriceKurus: kurus, unit: unitText, isActive: product.isActive);
  }
}

/// Ürün sorgusu (ada göre sıralı, arşivsiz). Ekrandan bağımsız — saf async testle sınanır
/// (widget-test sahte zamanı drift akışlarında güvenilmez; bkz. test/ui_dilim1_test.dart notu).
Stream<List<Product>> watchProducts(AppDatabase db, {bool activeOnly = true}) {
  final q = db.select(db.products)..where((t) => t.deletedAt.isNull());
  if (activeOnly) q.where((t) => t.isActive.equals(true));
  q.orderBy([(t) => OrderingTerm.asc(t.name)]);
  return q.watch();
}
