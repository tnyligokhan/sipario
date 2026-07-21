import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/coupon_repository.dart';
import '../../repo/ledger_repository.dart';
import '../money.dart';
import '../orders/order_list_screen.dart' show odemeTipiEtiketi, saatBicimi;

/// DİLİM 3 — müşteri detayındaki DEFTER bölümü: hareket listesi + tahsilat + kupon satışı + düzeltme.
/// Sorgu mantığı ekrandan AYRI top-level fonksiyonlardadır (watchLedger/watchCouponBalance) — saf
/// async testle sınanır (widget-test sahte zamanı drift akışlarında güvenilmez; Dilim 1/2 dersi).
/// Para HER YERDE int kuruş; kullanıcı yazımı ↔ kuruş DÖNÜŞÜMÜ yalnız money.dart parseKurus/formatKurus.
/// Silme/EZME YOK (kırmızı çizgi #2): düzeltme yalnız ters kayıtla (LedgerRepository.duzeltme).

/// Müşterinin defter hareketleri — en yeni önce. occurred_at eşitse id (uuid7) son tiebreak.
Stream<List<LedgerEntry>> watchLedger(AppDatabase db, String customerId) {
  final q = db.select(db.ledgerEntries)..where((t) => t.customerId.equals(customerId));
  q.orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]);
  return q.watch();
}

/// Müşterinin toplam kupon bakiyesi (tüm ürünler + genel kupon). Eksiye düşebilir (DECISIONS:
/// teslim edilmiş mal gerçektir); UI eksiyi kırmızı gösterir ama hiçbir işlem engellenmez.
Stream<int> watchCouponBalance(AppDatabase db, String customerId) {
  return (db.select(db.couponBalances)..where((t) => t.customerId.equals(customerId)))
      .watch()
      .map((rows) => rows.fold<int>(0, (s, r) => s + r.balanceQty));
}

/// Defter hareketinin Türkçe etiketi (DB değeri değişmez — 'debit'/'payment'/... durur).
String defterHareketEtiketi(LedgerEntry e) {
  final tip = e.paymentType != null ? ' · ${odemeTipiEtiketi(e.paymentType!)}' : '';
  switch (e.entryType) {
    case 'debit':
      return e.relatedOrderId != null ? 'Sipariş borcu' : 'Borç';
    case 'payment':
      return 'Tahsilat$tip';
    case 'credit':
      return 'Alacak / indirim';
    case 'correction':
      return 'Düzeltme$tip';
    default:
      return e.entryType;
  }
}

/// İmzalı tutar metni: +borç, −ödeme (formatKurus negatifi zaten − ile yazar; pozitife + ekleriz).
String imzaliTutarText(int amountKurus) =>
    amountKurus > 0 ? '+${formatKurus(amountKurus)}' : formatKurus(amountKurus);

/// Defter bölümü — müşteri detayının ListView'ine gömülür (kendi başına scroll AÇMAZ; parent kaydırır).
class CustomerLedgerSection extends StatelessWidget {
  const CustomerLedgerSection({
    super.key,
    required this.db,
    required this.customerId,
    required this.writable,
  });

  final AppDatabase db;
  final String customerId;
  final bool writable;

  static const _saltOkunur = 'Salt-okunur kip: yeni kayıt eklenemez.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kupon bakiyesi + Kupon sat
        StreamBuilder<int>(
          stream: watchCouponBalance(db, customerId),
          builder: (context, snap) {
            final bakiye = snap.data ?? 0;
            final eksi = bakiye < 0;
            return Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Kupon: ', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '$bakiye adet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: eksi ? Theme.of(context).colorScheme.error : null,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: writable
                      ? () => _kuponSat(context)
                      : () => _snackbar(context, _saltOkunur),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Kupon sat'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Defter hareketleri', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: writable
                  ? () => _tahsilatAl(context)
                  : () => _snackbar(context, _saltOkunur),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Tahsilat al'),
            ),
          ],
        ),
        StreamBuilder<List<LedgerEntry>>(
          stream: watchLedger(db, customerId),
          builder: (context, snap) {
            final entries = snap.data;
            if (entries == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Henüz hareket yok. Tahsilat veya sipariş girildikçe burada görünür.'),
              );
            }
            return Column(
              children: [for (final e in entries) _HareketSatiri(e: e, onDuzelt: writable ? () => _duzelt(context, e) : null)],
            );
          },
        ),
      ],
    );
  }

  Future<void> _tahsilatAl(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sonuc = await showDialog<_TahsilatGirdi>(
      context: context,
      builder: (_) => const _TutarOdemeDialog(baslik: 'Tahsilat al', tutarEtiketi: 'Tutar'),
    );
    if (sonuc == null) return;
    await LedgerRepository(db).tahsilat(customerId, sonuc.kurus, sonuc.paymentType);
    messenger.showSnackBar(SnackBar(
        content: Text(
            'Tahsilat alındı — ${odemeTipiEtiketi(sonuc.paymentType).toLowerCase()} ${formatKurus(sonuc.kurus)}')));
  }

  Future<void> _kuponSat(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sonuc = await showDialog<_KuponGirdi>(
      context: context,
      builder: (_) => const _KuponSatDialog(),
    );
    if (sonuc == null) return;
    // Peşin paket satışı: grant(+adet) + defter debit&payment (net borç 0, kasa dolu). productId
    // null = genel kupon (teslimde de genel kupon '' düşülür — aynı gözden).
    await CouponRepository(db).kuponSat(
      customerId: customerId,
      qty: sonuc.qty,
      priceKurus: sonuc.priceKurus,
      paymentType: sonuc.paymentType,
    );
    messenger.showSnackBar(
        SnackBar(content: Text('${sonuc.qty} kupon satıldı — ${formatKurus(sonuc.priceKurus)}')));
  }

  Future<void> _duzelt(BuildContext context, LedgerEntry e) async {
    final messenger = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ters kayıtla düzelt'),
        content: Text(
            'Bu hareket SİLİNMEZ; etkisini sıfırlayan bir düzeltme kaydı eklenir '
            '(${defterHareketEtiketi(e)} ${imzaliTutarText(e.amountKurus)}). Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Düzelt')),
        ],
      ),
    );
    if (onay != true) return;
    // Ters işaret: kaydın etkisini sıfırla. payment_type repo tarafından otomatik kopyalanır
    // (bakiye + kasa birlikte düzelir).
    await LedgerRepository(db).duzeltme(e.id, -e.amountKurus, customerId: customerId);
    messenger.showSnackBar(const SnackBar(content: Text('Düzeltme kaydı eklendi.')));
  }

  void _snackbar(BuildContext context, String mesaj) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
}

class _HareketSatiri extends StatelessWidget {
  const _HareketSatiri({required this.e, this.onDuzelt});
  final LedgerEntry e;
  final VoidCallback? onDuzelt;

  @override
  Widget build(BuildContext context) {
    final artan = e.amountKurus > 0; // +borç → kırmızı; −ödeme → yeşil/nötr
    final renk = artan ? Theme.of(context).colorScheme.error : Colors.green.shade700;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_ikon(e.entryType)),
      title: Text(defterHareketEtiketi(e)),
      subtitle: Text([
        saatBicimi(e.occurredAt),
        if (e.note != null && e.note!.isNotEmpty) e.note!,
      ].join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(imzaliTutarText(e.amountKurus),
              style: TextStyle(color: renk, fontWeight: FontWeight.w600)),
          if (onDuzelt != null)
            PopupMenuButton<String>(
              onSelected: (_) => onDuzelt!(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'duzelt', child: Text('Ters kayıtla düzelt')),
              ],
            ),
        ],
      ),
    );
  }

  IconData _ikon(String entryType) => switch (entryType) {
        'debit' => Icons.trending_up,
        'payment' => Icons.payments_outlined,
        'credit' => Icons.discount_outlined,
        'correction' => Icons.undo,
        _ => Icons.receipt_long_outlined,
      };
}

class _TahsilatGirdi {
  _TahsilatGirdi(this.kurus, this.paymentType);
  final int kurus;
  final String paymentType;
}

class _KuponGirdi {
  _KuponGirdi(this.qty, this.priceKurus, this.paymentType);
  final int qty;
  final int priceKurus;
  final String paymentType;
}

/// Tutar + ödeme tipi (nakit/kart/havale) dialogu. Tutar parseKurus ile int kuruşa çevrilir; geçersiz
/// yazım SESSİZCE kabul edilmez (para). Ödeme tipleri kasa gruplamasıdır (veresiye/kupon burada YOK —
/// bunlar teslimde sipariş bağlamında sorulur).
class _TutarOdemeDialog extends StatefulWidget {
  const _TutarOdemeDialog({required this.baslik, required this.tutarEtiketi});
  final String baslik;
  final String tutarEtiketi;

  @override
  State<_TutarOdemeDialog> createState() => _TutarOdemeDialogState();
}

class _TutarOdemeDialogState extends State<_TutarOdemeDialog> {
  final _tutar = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _tip = 'nakit';

  @override
  void dispose() {
    _tutar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.baslik),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _tutar,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${widget.tutarEtiketi} *', suffixText: '₺'),
              validator: (v) {
                final k = parseKurus(v ?? '');
                if (k == null) return 'Geçerli bir tutar girin';
                if (k == 0) return 'Tutar sıfır olamaz';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _OdemeTipiSecici(secili: _tip, onChanged: (t) => setState(() => _tip = t)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _TahsilatGirdi(parseKurus(_tutar.text)!, _tip));
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Kupon satışı: adet + peşin paket fiyatı + ödeme tipi. Kupon peşin ödenen pakettir; fiyat zorunlu
/// (deftere debit&payment olarak yazılır). Genel kupon satılır (productId yok).
class _KuponSatDialog extends StatefulWidget {
  const _KuponSatDialog();

  @override
  State<_KuponSatDialog> createState() => _KuponSatDialogState();
}

class _KuponSatDialogState extends State<_KuponSatDialog> {
  final _adet = TextEditingController();
  final _fiyat = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _tip = 'nakit';

  @override
  void dispose() {
    _adet.dispose();
    _fiyat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kupon sat'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _adet,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Adet *', hintText: 'örn. 10'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Geçerli bir adet girin';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fiyat,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Paket fiyatı *', suffixText: '₺'),
              validator: (v) {
                final k = parseKurus(v ?? '');
                if (k == null) return 'Geçerli bir fiyat girin';
                if (k == 0) return 'Fiyat sıfır olamaz';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _OdemeTipiSecici(secili: _tip, onChanged: (t) => setState(() => _tip = t)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                  context, _KuponGirdi(int.parse(_adet.text.trim()), parseKurus(_fiyat.text)!, _tip));
            }
          },
          child: const Text('Sat'),
        ),
      ],
    );
  }
}

/// Ödeme tipi seçici (nakit/kart/havale) — kasa gruplaması. veresiye/kupon burada YOK.
class _OdemeTipiSecici extends StatelessWidget {
  const _OdemeTipiSecici({required this.secili, required this.onChanged});
  final String secili;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'nakit', label: Text('Nakit')),
          ButtonSegment(value: 'kart', label: Text('Kart')),
          ButtonSegment(value: 'havale', label: Text('Havale')),
        ],
        selected: {secili},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
