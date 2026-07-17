import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/customer_repository.dart';
import 'customer_form_screen.dart' show normalizePhoneTR;
import 'customer_list_screen.dart' show formatKurus;

/// Müşteri detayı: bakiye, telefonlar, adresler, not; ad/not düzenleme ve telefon ekleme.
/// Defter hareket listesi ve tahsilat Dilim 3'te (repository hazır).
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.db,
    required this.customerId,
    required this.writable,
  });

  final AppDatabase db;
  final String customerId;
  final bool writable;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final CustomerRepository _repo = CustomerRepository(widget.db);

  Stream<Customer?> _customer() => (widget.db.select(widget.db.customers)
        ..where((t) => t.id.equals(widget.customerId)))
      .watchSingleOrNull();

  Stream<List<CustomerPhone>> _phones() => (widget.db.select(widget.db.customerPhones)
        ..where((t) => t.customerId.equals(widget.customerId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
      .watch();

  Stream<List<CustomerAddressesData>> _addresses() => (widget.db.select(widget.db.customerAddresses)
        ..where((t) => t.customerId.equals(widget.customerId) & t.deletedAt.isNull()))
      .watch();

  Future<void> _editNameNote(Customer c) async {
    final name = TextEditingController(text: c.name);
    final note = TextEditingController(text: c.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteriyi düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Ad soyad / ünvan')),
            const SizedBox(height: 8),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Not')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      await _repo.rename(widget.customerId,
          name: name.text.trim(), note: note.text.trim().isEmpty ? null : note.text.trim());
    }
  }

  Future<void> _addPhone() async {
    final phone = TextEditingController();
    final label = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Telefon ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Telefon', hintText: '05xx xxx xx xx'),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: label,
                decoration: const InputDecoration(labelText: 'Etiket', hintText: 'ev / iş / cep')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle')),
        ],
      ),
    );
    if (saved != true) return;
    final normalized = normalizePhoneTR(phone.text);
    if (normalized == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Geçersiz telefon numarası')));
      }
      return;
    }
    await _repo.addPhone(widget.customerId,
        PhoneInput(phoneE164: normalized, label: label.text.trim().isEmpty ? null : label.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Customer?>(
      stream: _customer(),
      builder: (context, snap) {
        final c = snap.data;
        if (c == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final borclu = c.balanceKurus > 0;
        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              if (widget.writable)
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editNameNote(c)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(borclu ? 'Veresiye borcu' : 'Bakiye',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        formatKurus(c.balanceKurus),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: borclu
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Telefonlar', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (widget.writable)
                    TextButton.icon(
                        onPressed: _addPhone,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ekle')),
                ],
              ),
              StreamBuilder<List<CustomerPhone>>(
                stream: _phones(),
                builder: (context, snap) {
                  final phones = snap.data ?? const [];
                  if (phones.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Telefon yok — arayınca tanımak için ekleyin.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final p in phones)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone_outlined),
                          title: Text(p.phoneE164),
                          subtitle: p.label == null ? null : Text(p.label!),
                          trailing: p.isPrimary ? const Icon(Icons.star, size: 18) : null,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text('Adresler', style: Theme.of(context).textTheme.titleMedium),
              StreamBuilder<List<CustomerAddressesData>>(
                stream: _addresses(),
                builder: (context, snap) {
                  final list = snap.data ?? const [];
                  if (list.isEmpty) {
                    return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8), child: Text('Adres yok.'));
                  }
                  return Column(
                    children: [
                      for (final a in list)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.home_outlined),
                          title: Text(a.addressText),
                          subtitle: a.label == null ? null : Text(a.label!),
                        ),
                    ],
                  );
                },
              ),
              if (c.note != null && c.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Not', style: Theme.of(context).textTheme.titleMedium),
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(c.note!)),
              ],
            ],
          ),
        );
      },
    );
  }
}
