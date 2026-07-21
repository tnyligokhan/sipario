import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/outbox.dart' show phoneLast10;
import '../../repo/customer_repository.dart';
import '../money.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

/// Müşteri listesi + arama. Arama hem ada hem telefona bakar (telefon girildiyse son-10 hane
/// normalizasyonuyla — arayan tanımadaki eşleşme kuralının aynısı). Bakiye rozeti: + borç kırmızı.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, required this.db, required this.writable});

  final AppDatabase db;
  final bool writable;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<List<Customer>> _watch() => watchCustomers(widget.db, _query);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteriler'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Ad veya telefon ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Customer>>(
        stream: _watch(),
        builder: (context, snap) {
          final customers = snap.data;
          if (customers == null) return const Center(child: CircularProgressIndicator());
          if (customers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _query.isEmpty
                      ? 'Henüz müşteri yok.\nSağ alttan ilk müşterinizi ekleyin —\ntelefon çaldığında ekranda tanıyacaksınız.'
                      : 'Eşleşen müşteri bulunamadı.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: customers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = customers[i];
              return ListTile(
                title: Text(c.name),
                subtitle: c.note == null || c.note!.isEmpty ? null : Text(c.note!, maxLines: 1),
                trailing: _BalanceBadge(kurus: c.balanceKurus),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CustomerDetailScreen(
                      db: widget.db, customerId: c.id, writable: widget.writable),
                )),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.writable
            ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CustomerFormScreen(repo: CustomerRepository(widget.db))))
            : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Salt-okunur kip: yeni kayıt eklenemez.'))),
        icon: const Icon(Icons.person_add),
        label: const Text('Müşteri'),
      ),
    );
  }
}

/// Bakiye rozeti. İşaret kuralı defterle aynı: + = müşteri borçlu (kırmızı), − = alacaklı, 0 = nötr.
class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({required this.kurus});
  final int kurus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    if (kurus > 0) {
      color = scheme.error;
    } else if (kurus < 0) {
      color = scheme.tertiary;
    } else {
      color = scheme.outline;
    }
    return Text(
      formatKurus(kurus),
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

/// Müşteri listesi sorgusu (arşivsizler, ada göre sıralı). Boş sorgu = hepsi; sorguda 3+ rakam
/// varsa telefon araması (son-10 normalizasyonlu LIKE — arayan tanımanın eşleşme kuralı), yoksa
/// ad araması. Ekrandan bağımsız fonksiyon: sorgu mantığı saf async testle sınanır (widget-test
/// zamanlaması drift akışlarında güvenilmez — bkz. test/ui_dilim1_test.dart notu).
Stream<List<Customer>> watchCustomers(AppDatabase db, String query) {
  final q = query.trim();
  if (q.isEmpty) {
    return (db.select(db.customers)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  var digits = q.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 3) {
    // Kullanıcı yazımını numara gövdesine indir: +90/90 ülke kodu ve baştaki 0 atılır — DB'de
    // phone_last10 '5321112233' biçimindedir; '0532...' yazımı aynen bırakılsa eşleşme kaçar.
    if (digits.startsWith('90') && digits.length > 10) digits = digits.substring(2);
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    final frag = phoneLast10(digits);
    final join = db.select(db.customers).join([
      innerJoin(db.customerPhones, db.customerPhones.customerId.equalsExp(db.customers.id)),
    ])
      ..where(db.customers.deletedAt.isNull() & db.customerPhones.phoneLast10.like('%$frag%'))
      ..orderBy([OrderingTerm.asc(db.customers.name)]);
    return join.watch().map((rows) =>
        {for (final r in rows) r.readTable(db.customers).id: r.readTable(db.customers)}
            .values
            .toList());
  }

  return (db.select(db.customers)
        ..where((t) => t.deletedAt.isNull() & t.name.like('%$q%'))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();
}
