import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../repo/product_repository.dart';
import '../customers/customer_list_screen.dart' show watchCustomers;
import '../money.dart';
import '../products/product_list_screen.dart' show showProductDialog, watchProducts;

/// Yeni sipariş: müşteri (opsiyonel — tezgâh satışı müşterisiz olabilir), ürün satırları, not.
/// Ödeme tipi BURADA sorulmaz; teslim kapatılırken sorulur (BRIEF: mal gidince para konuşulur) —
/// böylece sipariş girişi telefonda birkaç dokunuşta biter.
class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key, required this.db, this.initialCustomerId});

  final AppDatabase db;
  final String? initialCustomerId;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _note = TextEditingController();
  final List<LineDraft> _lines = [];
  Customer? _customer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomerId != null) _loadInitialCustomer(widget.initialCustomerId!);
  }

  Future<void> _loadInitialCustomer(String id) async {
    final c = await (widget.db.select(widget.db.customers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (mounted && c != null) setState(() => _customer = c);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final picked = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(builder: (_) => _CustomerPickerScreen(db: widget.db)),
    );
    if (picked != null && mounted) setState(() => _customer = picked);
  }

  Future<void> _addFromCatalog() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ProductPickerSheet(db: widget.db),
    );
    if (product == null || !mounted) return;
    setState(() {
      final existing = _lines.indexWhere((l) => l.productId == product.id);
      if (existing >= 0) {
        _lines[existing].qty += 1;
      } else {
        _lines.add(LineDraft(
            productId: product.id, name: product.name, unitPriceKurus: product.unitPriceKurus));
      }
    });
  }

  Future<void> _addFreeLine() async {
    final draft = await showDialog<LineDraft>(
      context: context,
      builder: (ctx) => const _FreeLineDialog(),
    );
    if (draft != null && mounted) setState(() => _lines.add(draft));
  }

  Future<void> _save() async {
    if (_lines.isEmpty) return;
    setState(() => _busy = true);
    try {
      await OrderRepository(widget.db).create(
        customerId: _customer?.id,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        lines: _lines
            .map((l) => LineInput(
                  productId: l.productId,
                  productName: l.name,
                  unitPriceKurus: l.unitPriceKurus,
                  qty: l.qty,
                ))
            .toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sipariş kaydedildi.')));
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = toplamKurus(_lines);
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni sipariş')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_customer?.name ?? 'Müşteri seç'),
              subtitle: _customer == null
                  ? const Text('Tezgâh satışı için boş bırakabilirsiniz')
                  : Text(_customer!.balanceKurus > 0
                      ? 'Borç: ${formatKurus(_customer!.balanceKurus)}'
                      : 'Bakiye: ${formatKurus(_customer!.balanceKurus)}'),
              trailing: _customer == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Müşteriyi kaldır',
                      onPressed: () => setState(() => _customer = null),
                    ),
              onTap: _pickCustomer,
            ),
          ),
          const SizedBox(height: 8),
          Text('Ürünler', style: Theme.of(context).textTheme.titleMedium),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Satır yok — aşağıdan ürün ekleyin.'),
            ),
          for (var i = 0; i < _lines.length; i++) _lineTile(i),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _addFromCatalog,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Ürün ekle'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _addFreeLine,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Serbest satır'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Not',
              hintText: 'Ör. kapıya bırak, 3. kat',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Toplam', style: Theme.of(context).textTheme.labelMedium),
                    Text(formatKurus(total),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: (_busy || _lines.isEmpty) ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Siparişi kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineTile(int i) {
    final l = _lines[i];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l.name),
      subtitle: Text('${formatKurus(l.unitPriceKurus)} × ${l.qty}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Azalt',
            onPressed: () => setState(() {
              if (l.qty > 1) {
                l.qty -= 1;
              } else {
                _lines.removeAt(i);
              }
            }),
          ),
          Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Artır',
            onPressed: () => setState(() => l.qty += 1),
          ),
          SizedBox(
            width: 88,
            child: Text(formatKurus(l.unitPriceKurus * l.qty), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

/// Sipariş satırı taslağı (henüz kaydedilmemiş). Kaydedildiğinde `LineInput`'a çevrilir.
class LineDraft {
  LineDraft({this.productId, required this.name, required this.unitPriceKurus, this.qty = 1});
  final String? productId;
  final String name;
  final int unitPriceKurus;
  int qty;
}

/// Taslak satırların toplamı (int kuruş — kayan nokta YOK).
int toplamKurus(List<LineDraft> lines) =>
    lines.fold<int>(0, (s, l) => s + l.unitPriceKurus * l.qty);

/// Müşteri seçici — liste ekranının arama kuralını (son-10 telefon eşleşmesi) aynen kullanır.
class _CustomerPickerScreen extends StatefulWidget {
  const _CustomerPickerScreen({required this.db});
  final AppDatabase db;

  @override
  State<_CustomerPickerScreen> createState() => _CustomerPickerScreenState();
}

class _CustomerPickerScreenState extends State<_CustomerPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteri seç'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Ad veya telefon ara',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Customer>>(
        stream: watchCustomers(widget.db, _query),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return const Center(child: Text('Eşleşen müşteri yok.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => ListTile(
              title: Text(list[i].name),
              trailing: Text(formatKurus(list[i].balanceKurus)),
              onTap: () => Navigator.of(context).pop(list[i]),
            ),
          );
        },
      ),
    );
  }
}

/// Ürün seçici. Ürün yoksa doğrudan buradan eklenebilir — taze kurulumda bayi akıştan çıkmasın.
class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Product>>(
        stream: watchProducts(db),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) {
            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
          }
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Henüz ürün yok.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => showProductDialog(context, ProductRepository(db)),
                    icon: const Icon(Icons.add),
                    label: const Text('Ürün ekle'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => ListTile(
              title: Text(list[i].name),
              subtitle: Text('${formatKurus(list[i].unitPriceKurus)} / ${list[i].unit}'),
              onTap: () => Navigator.of(context).pop(list[i]),
            ),
          );
        },
      ),
    );
  }
}

/// Katalogda olmayan tek seferlik satır (ör. "boru tamiri"). Ürün kaydı OLUŞTURMAZ.
class _FreeLineDialog extends StatefulWidget {
  const _FreeLineDialog();

  @override
  State<_FreeLineDialog> createState() => _FreeLineDialogState();
}

class _FreeLineDialogState extends State<_FreeLineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController(text: '1');

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Serbest satır'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Açıklama *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Açıklama gerekli' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Birim fiyat *', suffixText: '₺'),
              validator: (v) => parseKurus(v ?? '') == null ? 'Geçerli bir fiyat girin' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Adet *'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return (n == null || n < 1) ? 'En az 1 adet' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              LineDraft(
                name: _name.text.trim(),
                unitPriceKurus: parseKurus(_price.text)!,
                qty: int.parse(_qty.text.trim()),
              ),
            );
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
