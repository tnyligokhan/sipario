import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/outbox.dart' show phoneLast10;
import '../../repo/customer_repository.dart';
import '../../theme/components/balance_badge.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

/// Müşteri listesi + arama (yeniden tasarım — handoff Ekran 1). Arama hem ada hem telefona bakar
/// (telefon girildiyse son-10 hane normalizasyonuyla — arayan tanımadaki eşleşme kuralının aynısı).
/// Görsel: kart satırları (avatar + ad + telefon), sağda bakiye rozeti; başlıkta borçlu sayısı.
/// Durum yönetimi/akış deseni Faz 2'den DEĞİŞMEDİ; yalnız görsel katman yenilendi.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, required this.db, required this.writable, this.yetki});

  final AppDatabase db;
  final bool writable;

  /// Rol bazlı yetki (K2 — Dilim 4). null → tam yetki (giriş öncesi/test yolu); detayda kupon
  /// satışı/düzeltme kapıları buradan gelir.
  final RolYetkileri? yetki;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _search = TextEditingController();
  String _query = '';
  // Başlıktaki borçlu sayısı — bir kez abone ol (tuş başına yeniden abonelik/titreme olmasın).
  late final Stream<int> _debtCount = watchDebtCount(widget.db);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SipColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              debtCount: _debtCount,
              search: _search,
              query: _query,
              onChanged: (v) => setState(() => _query = v),
              onClear: () {
                _search.clear();
                setState(() => _query = '');
              },
            ),
            Expanded(
              child: StreamBuilder<List<CustomerRow>>(
                stream: watchCustomerRows(widget.db, _query),
                builder: (context, snap) {
                  final rows = snap.data;
                  if (rows == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (rows.isEmpty) {
                    return _EmptyCustomers(searching: _query.trim().isNotEmpty);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 104),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: SipSpace.gap),
                    itemBuilder: (context, i) => _CustomerCard(
                      row: rows[i],
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CustomerDetailScreen(
                          db: widget.db,
                          customerId: rows[i].customer.id,
                          writable: widget.writable,
                          yetki: widget.yetki,
                        ),
                      )),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

/// Başlık + borçlu sayısı çipi + arama alanı.
class _Header extends StatelessWidget {
  const _Header({
    required this.debtCount,
    required this.search,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final Stream<int> debtCount;
  final TextEditingController search;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Müşteriler', style: SipText.screenTitle)),
              // Borçlu sayısı rozeti — canlı; borçlu yoksa hiç görünmez (handoff).
              StreamBuilder<int>(
                stream: debtCount,
                builder: (context, snap) {
                  final n = snap.data ?? 0;
                  if (n == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: SipColors.debtSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: SipColors.debt, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text('$n borçlu',
                            style: SipText.muted
                                .copyWith(color: SipColors.debt, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: search,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 16, color: SipColors.t1),
            decoration: InputDecoration(
              hintText: 'Ad veya telefon ara',
              prefixIcon: const Icon(Icons.search, size: 22),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: onClear),
            ),
          ),
        ],
      ),
    );
  }
}

/// Müşteri kartı — avatar (baş harfler) + ad + telefon, sağda bakiye rozeti.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.row, required this.onTap});

  final CustomerRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = row.customer;
    final secondary = row.phone != null ? formatPhoneTR(row.phone!) : (c.note ?? '');
    return Material(
      color: SipColors.s1,
      borderRadius: SipRadius.cardBr,
      child: InkWell(
        borderRadius: SipRadius.cardBr,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: SipRadius.cardBr,
            border: Border.all(color: SipColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                _Avatar(name: c.name),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SipText.cardTitle),
                      if (secondary.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SipText.secondary.copyWith(fontSize: 13.5)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                BalanceBadge(kurus: c.balanceKurus),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: SipColors.s3, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: const TextStyle(
            fontFamily: sipFontFamily, fontSize: 15, fontWeight: FontWeight.w700, color: SipColors.t2),
      ),
    );
  }
}

/// Boş durum — yönlendirici mesaj (handoff dilinde).
class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SipColors.s2,
                shape: BoxShape.circle,
                border: Border.all(color: SipColors.line),
              ),
              child: Icon(searching ? Icons.search_off : Icons.group_outlined,
                  size: 40, color: SipColors.t3),
            ),
            const SizedBox(height: 22),
            Text(searching ? 'Sonuç bulunamadı' : 'Henüz müşteri yok',
                textAlign: TextAlign.center, style: SipText.emptyTitle),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'Farklı bir ad veya numara deneyin.'
                  : 'Sağ alttan ilk müşterinizi ekleyin — telefon çaldığında ekranda tanıyacaksınız.',
              textAlign: TextAlign.center,
              style: SipText.emptyBody,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ad → baş harfler (ilk iki kelimenin ilk harfi, Türkçe büyük harf). Salt görsel.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final a = parts[0].characters.first;
  final b = parts.length > 1 ? parts[1].characters.first : '';
  return (a + b).toUpperCase();
}

/// E164/ham numarayı TR yazımına biçimler: "+905327710863" → "0532 771 08 63". 10 haneye
/// inmiyorsa girdiyi olduğu gibi döner (kısmî/yabancı numara).
String formatPhoneTR(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  final n = d.length >= 10 ? d.substring(d.length - 10) : d;
  if (n.length != 10) return raw;
  return '0${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6, 8)} ${n.substring(8, 10)}';
}

/// Müşteri + birincil telefon satırı (yeniden tasarım listesi için). `watchCustomers`'a DOKUNULMADI
/// (testler ona bağlı); bu ADDITIVE, salt-okunur sorgu birincil telefonu LEFT JOIN'le ekler.
typedef CustomerRow = ({Customer customer, String? phone});

Stream<List<CustomerRow>> watchCustomerRows(AppDatabase db, String query) {
  final q = query.trim();

  // Görüntü telefonu: birincili tercih et (isPrimary desc), silinmişleri dışla. LEFT join —
  // telefonu olmayan müşteri de listede kalır.
  final sel = db.select(db.customers).join([
    leftOuterJoin(
      db.customerPhones,
      db.customerPhones.customerId.equalsExp(db.customers.id) &
          db.customerPhones.deletedAt.isNull(),
    ),
  ]);

  if (q.isEmpty) {
    sel.where(db.customers.deletedAt.isNull());
  } else {
    var digits = q.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 3) {
      // Telefon araması — arayan tanımayla AYNI son-10 normalizasyonu.
      if (digits.startsWith('90') && digits.length > 10) digits = digits.substring(2);
      while (digits.startsWith('0')) {
        digits = digits.substring(1);
      }
      final frag = phoneLast10(digits);
      // EXISTS: herhangi bir telefonu eşleşen müşteri (görüntü telefonu yine birincil kalır).
      final match = db.selectOnly(db.customerPhones)
        ..addColumns([db.customerPhones.id])
        ..where(db.customerPhones.customerId.equalsExp(db.customers.id) &
            db.customerPhones.deletedAt.isNull() &
            db.customerPhones.phoneLast10.like('%$frag%'));
      sel.where(db.customers.deletedAt.isNull() & existsQuery(match));
    } else {
      sel.where(db.customers.deletedAt.isNull() & db.customers.name.like('%$q%'));
    }
  }

  sel.orderBy([
    OrderingTerm.asc(db.customers.name),
    OrderingTerm.desc(db.customerPhones.isPrimary),
  ]);

  return sel.watch().map((rows) {
    final byId = <String, CustomerRow>{};
    for (final r in rows) {
      final c = r.readTable(db.customers);
      final p = r.readTableOrNull(db.customerPhones);
      final existing = byId[c.id];
      if (existing == null) {
        byId[c.id] = (customer: c, phone: p?.phoneE164);
      } else if (existing.phone == null && p != null) {
        byId[c.id] = (customer: c, phone: p.phoneE164);
      }
    }
    return byId.values.toList();
  });
}

/// Başlıktaki "N borçlu" rozeti için canlı sayım (bakiyesi + olan müşteriler).
Stream<int> watchDebtCount(AppDatabase db) {
  final count = db.customers.id.count();
  final q = db.selectOnly(db.customers)
    ..addColumns([count])
    ..where(db.customers.deletedAt.isNull() & db.customers.balanceKurus.isBiggerThanValue(0));
  return q.watchSingle().map((r) => r.read(count) ?? 0);
}

/// Müşteri listesi sorgusu (arşivsizler, ada göre sıralı). Boş sorgu = hepsi; sorguda 3+ rakam
/// varsa telefon araması (son-10 normalizasyonlu LIKE — arayan tanımanın eşleşme kuralı), yoksa
/// ad araması. Ekrandan bağımsız fonksiyon: sorgu mantığı saf async testle sınanır (widget-test
/// zamanlaması drift akışlarında güvenilmez — bkz. test/ui_dilim1_test.dart notu).
///
/// NOT: liste ekranı artık `watchCustomerRows`'u (telefonlu) kullanır; bu fonksiyon KORUNDU çünkü
/// testler doğrudan onu çağırır (arama/normalizasyon sözleşmesi).
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
