import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../money.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';

/// Sipariş sekmesi: açık siparişler önce gelir (bayinin gün içinde baktığı liste budur),
/// sekmelerle teslim edilenlere ve tümüne geçilir. Yeni sipariş sağ alttan.
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key, required this.db, required this.writable});

  final AppDatabase db;
  final bool writable;

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  OrderFilter _filter = OrderFilter.acik;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişler'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<OrderFilter>(
              segments: const [
                ButtonSegment(value: OrderFilter.acik, label: Text('Açık')),
                ButtonSegment(value: OrderFilter.teslim, label: Text('Teslim')),
                ButtonSegment(value: OrderFilter.tumu, label: Text('Tümü')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<OrderListItem>>(
        stream: watchOrders(widget.db, _filter),
        builder: (context, snap) {
          final orders = snap.data;
          if (orders == null) return const Center(child: CircularProgressIndicator());
          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _filter == OrderFilter.acik
                      ? 'Açık sipariş yok.\nTelefon çalınca sağ alttan sipariş girin.'
                      : 'Kayıt yok.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = orders[i];
              return ListTile(
                leading: _StatusIcon(status: item.order.status),
                title: Text(item.customerName ?? 'Müşterisiz sipariş'),
                subtitle: Text([
                  saatBicimi(item.order.occurredAt),
                  if (item.order.paymentType != null) odemeTipiEtiketi(item.order.paymentType!),
                  if (item.order.note != null && item.order.note!.isNotEmpty) item.order.note!,
                ].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(formatKurus(item.order.totalKurus),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(
                      db: widget.db, orderId: item.order.id, writable: widget.writable),
                )),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.writable
            ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => OrderFormScreen(db: widget.db)))
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Salt-okunur kip: yeni kayıt eklenemez.'))),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Sipariş'),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      'delivered' => Icon(Icons.check_circle_outline, color: scheme.tertiary),
      'cancelled' => Icon(Icons.cancel_outlined, color: scheme.outline),
      _ => Icon(Icons.local_shipping_outlined, color: scheme.primary),
    };
  }
}

enum OrderFilter { acik, teslim, tumu }

class OrderListItem {
  OrderListItem({required this.order, this.customerName});
  final Order order;
  final String? customerName;
}

/// Sipariş listesi sorgusu — müşteri adıyla birlikte, en yeni önce. Ekrandan bağımsız fonksiyon:
/// sorgu mantığı saf async testle sınanır (widget-test sahte zamanı drift akışlarında güvenilmez).
Stream<List<OrderListItem>> watchOrders(AppDatabase db, OrderFilter filter) {
  final q = db.select(db.orders).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
  ]);
  q.where(db.orders.deletedAt.isNull());
  switch (filter) {
    case OrderFilter.acik:
      q.where(db.orders.status.equals('open'));
    case OrderFilter.teslim:
      q.where(db.orders.status.equals('delivered'));
    case OrderFilter.tumu:
      break;
  }
  q.orderBy([OrderingTerm.desc(db.orders.occurredAt), OrderingTerm.desc(db.orders.id)]);
  return q.watch().map((rows) => rows
      .map((r) => OrderListItem(
            order: r.readTable(db.orders),
            customerName: r.readTableOrNull(db.customers)?.name,
          ))
      .toList());
}

/// Ödeme tipinin ekran etiketi (veri değeri değişmez — DB'de 'nakit'/'veresiye'/... durur).
String odemeTipiEtiketi(String paymentType) => switch (paymentType) {
      'nakit' => 'Nakit',
      'kart' => 'Kart',
      'havale' => 'Havale',
      'veresiye' => 'Veresiye',
      'kupon' => 'Kupon',
      _ => paymentType,
    };

/// ISO8601 occurred_at → "14:35" (bugünse) veya "17.07 14:35". Saat cihaz yerelinde gösterilir;
/// kayıtta UTC/sunucu-düzeltilmiş metin OLDUĞU GİBİ durur (DECISIONS — gösterim veriyi değiştirmez).
String saatBicimi(String iso, {DateTime? simdi}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final local = t.toLocal();
  final now = simdi ?? DateTime.now();
  final saat = '${_ikiHane(local.hour)}:${_ikiHane(local.minute)}';
  final ayniGun = local.year == now.year && local.month == now.month && local.day == now.day;
  return ayniGun ? saat : '${_ikiHane(local.day)}.${_ikiHane(local.month)} $saat';
}

String _ikiHane(int n) => n.toString().padLeft(2, '0');
