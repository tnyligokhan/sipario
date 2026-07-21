import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../money.dart';
import 'order_list_screen.dart' show odemeTipiEtiketi, saatBicimi;

/// Sipariş detayı + TESLİM KAPATMA. Teslim, ödeme tipini sorar ve `OrderRepository.deliver` ile
/// parayı/kuponu deftere tek transaction'da düşürür (FAZ 3/4). Teslim internetsiz saniyeler içinde
/// biter — hiçbir ağ çağrısı beklenmez (BRIEF); kayıt outbox'a düşer, senkron sonra taşır.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.db,
    required this.orderId,
    required this.writable,
  });

  final AppDatabase db;
  final String orderId;
  final bool writable;

  Stream<Order?> _order() =>
      (db.select(db.orders)..where((t) => t.id.equals(orderId))).watchSingleOrNull();

  Stream<List<OrderLine>> _lines() => (db.select(db.orderLines)
        ..where((t) => t.orderId.equals(orderId) & t.deletedAt.isNull()))
      .watch();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Order?>(
      stream: _order(),
      builder: (context, snap) {
        final order = snap.data;
        if (order == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sipariş'),
            actions: [
              if (writable && order.status == 'open')
                IconButton(
                  icon: const Icon(Icons.cancel_outlined),
                  tooltip: 'Siparişi iptal et',
                  onPressed: () => _iptalEt(context),
                ),
            ],
          ),
          body: StreamBuilder<List<OrderLine>>(
            stream: _lines(),
            builder: (context, lineSnap) {
              final lines = lineSnap.data ?? const <OrderLine>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _DurumSeridi(order: order),
                  const SizedBox(height: 8),
                  if (order.customerId != null)
                    FutureBuilder<Customer?>(
                      future: (db.select(db.customers)
                            ..where((t) => t.id.equals(order.customerId!)))
                          .getSingleOrNull(),
                      builder: (context, cs) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(cs.data?.name ?? '…'),
                        subtitle: cs.data == null ? null : Text('Bakiye: ${formatKurus(cs.data!.balanceKurus)}'),
                      ),
                    )
                  else
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_off_outlined),
                      title: Text('Müşterisiz sipariş'),
                    ),
                  const Divider(),
                  for (final l in lines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l.productName),
                      subtitle: Text('${formatKurus(l.unitPriceKurus)} × ${l.qty}'),
                      trailing: Text(formatKurus(l.lineTotalKurus)),
                    ),
                  const Divider(),
                  Row(
                    children: [
                      Text('Toplam', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text(formatKurus(order.totalKurus),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (order.note != null && order.note!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Not', style: Theme.of(context).textTheme.titleMedium),
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(order.note!)),
                  ],
                  const SizedBox(height: 24),
                  if (writable && order.status == 'open')
                    FilledButton.icon(
                      onPressed: () => _teslimEt(context, order, lines),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Teslim et'),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _teslimEt(BuildContext context, Order order, List<OrderLine> lines) async {
    final messenger = ScaffoldMessenger.of(context);
    final kuponBakiyesi = order.customerId == null ? null : await _kuponBakiyesi(order.customerId!);
    if (!context.mounted) return;

    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _OdemeTipiSayfasi(
        toplamKurus: order.totalKurus,
        musteriVar: order.customerId != null,
        kuponAdedi: kuponAdedi(lines),
        kuponBakiyesi: kuponBakiyesi,
      ),
    );
    if (secim == null) return;

    await OrderRepository(db).deliver(order.id, paymentType: secim);
    messenger.showSnackBar(SnackBar(
        content: Text('Teslim edildi — ${odemeTipiEtiketi(secim).toLowerCase()}.')));
  }

  Future<int> _kuponBakiyesi(String customerId) async {
    final row = await (db.select(db.couponBalances)
          ..where((t) => t.customerId.equals(customerId) & t.productId.equals('')))
        .getSingleOrNull();
    return row?.balanceQty ?? 0;
  }

  Future<void> _iptalEt(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sipariş iptal edilsin mi?'),
        content: const Text('Kayıt silinmez, iptal olarak işaretlenir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İptal et')),
        ],
      ),
    );
    if (onay == true) await OrderRepository(db).cancel(orderId);
  }
}

class _DurumSeridi extends StatelessWidget {
  const _DurumSeridi({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final (String etiket, Color renk) = switch (order.status) {
      'delivered' => ('Teslim edildi', Theme.of(context).colorScheme.tertiary),
      'cancelled' => ('İptal edildi', Theme.of(context).colorScheme.outline),
      _ => ('Açık', Theme.of(context).colorScheme.primary),
    };
    return Row(
      children: [
        Chip(label: Text(etiket), avatar: Icon(Icons.circle, size: 12, color: renk)),
        const SizedBox(width: 8),
        if (order.paymentType != null) Chip(label: Text(odemeTipiEtiketi(order.paymentType!))),
        const Spacer(),
        Text(saatBicimi(order.occurredAt), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Teslim ödeme tipi seçimi. Kuponda mevcut bakiye ve teslim sonrası kalan gösterilir; bakiye
/// yetmese bile teslim REDDEDİLMEZ (BRIEF: teslim edilmiş mal gerçektir — eksiye düşer, kırmızı
/// görünür, düzeltme kaydıyla kapanır).
class _OdemeTipiSayfasi extends StatelessWidget {
  const _OdemeTipiSayfasi({
    required this.toplamKurus,
    required this.musteriVar,
    required this.kuponAdedi,
    required this.kuponBakiyesi,
  });

  final int toplamKurus;
  final bool musteriVar;
  final int kuponAdedi;
  final int? kuponBakiyesi;

  @override
  Widget build(BuildContext context) {
    final kalan = (kuponBakiyesi ?? 0) - kuponAdedi;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Ödeme tipi'),
            subtitle: Text('Tutar: ${formatKurus(toplamKurus)}'),
          ),
          const Divider(height: 1),
          for (final tip in teslimOdemeTipleri(musteriVar: musteriVar))
            ListTile(
              leading: Icon(switch (tip) {
                'nakit' => Icons.payments_outlined,
                'kart' => Icons.credit_card,
                'havale' => Icons.account_balance_outlined,
                'veresiye' => Icons.menu_book_outlined,
                _ => Icons.confirmation_number_outlined,
              }),
              title: Text(odemeTipiEtiketi(tip)),
              subtitle: switch (tip) {
                'veresiye' => const Text('Borç deftere yazılır'),
                'kupon' => Text('$kuponAdedi adet düşer · kalan $kalan',
                    style: kalan < 0
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null),
                _ => const Text('Kasaya girer'),
              },
              onTap: () => Navigator.of(context).pop(tip),
            ),
          if (!musteriVar)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Veresiye ve kupon için siparişe müşteri bağlı olmalı.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

/// Teslimde sunulan ödeme tipleri. veresiye/kupon MÜŞTERİ ZORUNLU: borç ve kupon bir müşteriye
/// yazılır — müşterisiz veresiye kimseye ait olmayan bir borç kaydı üretirdi (defter tutarlılığı).
List<String> teslimOdemeTipleri({required bool musteriVar}) => [
      'nakit',
      'kart',
      'havale',
      if (musteriVar) 'veresiye',
      if (musteriVar) 'kupon',
    ];

/// Kuponla teslimde düşecek adet = aktif satırların adet toplamı (OrderRepository.deliver'ın
/// couponQty verilmediğinde uyguladığı kuralın AYNISI — ekran farklı bir sayı göstermemeli).
int kuponAdedi(List<OrderLine> lines) => lines.fold<int>(0, (s, l) => s + l.qty);
