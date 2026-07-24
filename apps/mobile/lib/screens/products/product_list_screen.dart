import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/product_repository.dart';
import '../../theme/components/empty_state.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../money.dart';

/// Ürün listesi (Menü → Ürünler): ekle / düzenle / pasifle. Ürünler senkronla da gelir; taze kurulumda
/// bayinin ilk ürününü buradan girmesi gerekir — yoksa sipariş ekranı boş kalır.
/// Silme YOK, PASİFLEME var (geçmiş sipariş satırları ad/fiyatı kendi içinde taşır, bozulmaz).
///
/// EKRAN 5 — yeniden tasarım: SafeArea + ekran başlığı + canlı sayaç + kart satırları (gün sonu/menü
/// diliyle aynı). Davranış (FAB + salt-okunur kapısı, popup aksiyonları, diyalog, sorgu) DEĞİŞMEDİ.
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key, required this.db, required this.writable});

  final AppDatabase db;
  final bool writable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SipColors.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Product>>(
          stream: watchProducts(db, activeOnly: false),
          builder: (context, snap) {
            final products = snap.data;
            final aktif = products?.where((p) => p.isActive).length ?? 0;
            final pasif = (products?.length ?? 0) - aktif;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ürünler', style: SipText.screenTitle),
                      const SizedBox(height: 6),
                      Text(
                        products == null
                            ? ''
                            : '$aktif aktif ürün${pasif > 0 ? ' · $pasif pasif' : ''}',
                        style: SipText.secondary,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: products == null
                      ? const Center(child: CircularProgressIndicator())
                      : products.isEmpty
                          ? const SipEmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'Henüz ürün yok',
                              subtitle:
                                  'Sağ alttan ekleyin — sipariş satırları buradan seçilir.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 2, 14, 96),
                              itemCount: products.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: SipSpace.gap),
                              itemBuilder: (context, i) => _UrunKarti(
                                product: products[i],
                                writable: writable,
                                db: db,
                              ),
                            ),
                ),
              ],
            );
          },
        ),
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

/// Ürün kartı — sol ikon kutusu + ad/birim, sağda fiyat (amount, tabular). Pasif ürün soluk +
/// üstü çizili ad + "Pasif" çipi taşır; fiyat görünür kalır (bilgi kaybolmaz, yalnız soluklaşır).
class _UrunKarti extends StatelessWidget {
  const _UrunKarti({required this.product, required this.writable, required this.db});

  final Product product;
  final bool writable;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Material(
      color: SipColors.s1,
      borderRadius: SipRadius.cardBr,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: SipRadius.cardBr,
          border: Border.all(color: SipColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 6, 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: SipColors.s3,
                  borderRadius: SipRadius.smBr,
                ),
                child: Icon(Icons.water_drop_outlined,
                    size: 21, color: p.isActive ? SipColors.accFg : SipColors.t3),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: p.isActive
                          ? SipText.cardTitle
                          : SipText.cardTitle.copyWith(
                              color: SipColors.t3,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: SipColors.t3,
                            ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text('/ ${p.unit}',
                            style: SipText.secondary.copyWith(fontSize: 13.5)),
                        if (!p.isActive) ...[
                          const SizedBox(width: SipSpace.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: const BoxDecoration(
                              color: SipColors.s3,
                              borderRadius: SipRadius.smBr,
                            ),
                            child: Text('Pasif',
                                style: SipText.muted.copyWith(color: SipColors.t2)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatKurus(p.unitPriceKurus),
                style: p.isActive
                    ? SipText.amount
                    : SipText.amount.copyWith(color: SipColors.t3),
              ),
              if (writable)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: SipColors.t3),
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
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
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
