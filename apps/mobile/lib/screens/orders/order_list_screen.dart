import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/empty_state.dart';
import '../../theme/components/segmented.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../money.dart';
import '../team.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';

/// Sipariş sekmesi (yeniden tasarım — handoff Ekran 2): açık siparişler önce gelir (bayinin gün
/// içinde baktığı liste budur), segment filtresiyle teslim/tümüne geçilir. Kurye girişinde ek
/// "Benim" sekmesi. Görsel: sipariş kartı (müşteri + ürün özeti + durum rozeti + saat·ödeme + tutar).
/// Durum yönetimi/akış deseni + `watchOrders` sözleşmesi DEĞİŞMEDİ; item özeti additive akıştan.
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({
    super.key,
    required this.db,
    required this.writable,
    this.userRole,
    this.userId,
    this.canAssign = false,
  });

  final AppDatabase db;
  final bool writable;
  final String? userRole; // patron|operator|kurye
  final String? userId; // "Benim" filtresinin atama hedefi
  final bool canAssign; // sipariş detayında "Kuryeye ata" görünürlüğü (K2: yönetici + kurye var)

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  OrderFilter _filter = OrderFilter.acik;

  // Yardımcı akışlar bir kez abone edilir (filtre değişince yeniden abone olmasın/titremesin).
  // Sipariş akışı filtreye bağlı olduğundan build'de kalır.
  late final Stream<List<User>> _team = watchTeam(widget.db);
  late final Stream<Map<String, String>> _items = watchOrderItemsSummary(widget.db);

  bool get _kurye => widget.userRole == 'kurye';

  @override
  Widget build(BuildContext context) {
    // "Benim" yalnız kuryede — atama kullanmayan bayide boş bir sekme karşılamasın.
    final segments = <SipSegment<OrderFilter>>[
      if (_kurye) const SipSegment(value: OrderFilter.benim, label: 'Benim'),
      const SipSegment(value: OrderFilter.acik, label: 'Açık'),
      const SipSegment(value: OrderFilter.teslim, label: 'Teslim'),
      const SipSegment(value: OrderFilter.tumu, label: 'Tümü'),
    ];

    return Scaffold(
      backgroundColor: SipColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Siparişler', style: SipText.screenTitle),
                  const SizedBox(height: 14),
                  SipSegmented<OrderFilter>(
                    segments: segments,
                    selected: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
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

  Widget _body() {
    return StreamBuilder<List<User>>(
      stream: _team,
      initialData: const [],
      builder: (context, teamSnap) {
        final team = teamSnap.data ?? const <User>[];
        return StreamBuilder<Map<String, String>>(
          stream: _items,
          initialData: const {},
          builder: (context, itemsSnap) {
            final items = itemsSnap.data ?? const <String, String>{};
            return StreamBuilder<List<OrderListItem>>(
              stream: watchOrders(widget.db, _filter, assignedTo: widget.userId),
              builder: (context, snap) {
                final orders = snap.data;
                if (orders == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (orders.isEmpty) return _empty();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 104),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: SipSpace.gap),
                  itemBuilder: (context, i) {
                    final item = orders[i];
                    final kurye = item.order.assignedUserId == null
                        ? null
                        : (kullaniciAdi(team, item.order.assignedUserId) ?? 'Kurye');
                    return _OrderCard(
                      item: item,
                      itemsSummary: items[item.order.id],
                      kuryeName: kurye,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(
                          db: widget.db,
                          orderId: item.order.id,
                          writable: widget.writable,
                          canAssign: widget.canAssign,
                        ),
                      )),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _empty() {
    final (String title, String sub) = switch (_filter) {
      OrderFilter.acik => ('Açık sipariş yok', 'Telefon çalınca sağ alttan sipariş girin.'),
      OrderFilter.benim => ('Size atanmış açık sipariş yok', 'Günün işleri burada görünür.'),
      OrderFilter.teslim => ('Teslim edilen sipariş yok', 'Teslim edilenler burada listelenir.'),
      OrderFilter.tumu => ('Henüz sipariş yok', 'İlk siparişi sağ alttan ekleyin.'),
    };
    return SipEmptyState(icon: Icons.receipt_long_outlined, title: title, subtitle: sub);
  }
}

/// Sipariş kartı — müşteri + ürün özeti (üst), durum rozeti (sağ üst), saat·ödeme + tutar (alt).
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.item,
    required this.itemsSummary,
    required this.kuryeName,
    required this.onTap,
  });

  final OrderListItem item;
  final String? itemsSummary;
  final String? kuryeName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = item.order;
    final meta = [
      saatBicimi(o.occurredAt),
      if (o.paymentType != null) odemeTipiEtiketi(o.paymentType!),
      if (kuryeName != null) '→ $kuryeName',
      if (o.note != null && o.note!.isNotEmpty) o.note!,
    ].join(' · ');

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
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.customerName ?? 'Müşterisiz sipariş',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: SipText.cardTitle),
                          if (itemsSummary != null && itemsSummary!.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(itemsSummary!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SipText.secondary),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusBadge(status: o.status),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 11),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: SipColors.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SipText.muted.copyWith(fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Text(formatKurus(o.totalKurus), style: SipText.amount),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Durum rozeti — Açık (vurgu + nokta), Teslim (yeşil + onay), İptal (nötr). Liste diliyle aynı.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label, Widget lead) = switch (status) {
      'delivered' => (
          SipColors.okSoft,
          SipColors.ok,
          'Teslim',
          const Icon(Icons.check, size: 15, color: SipColors.ok),
        ),
      'cancelled' => (
          SipColors.s3,
          SipColors.t3,
          'İptal',
          const SizedBox.shrink(),
        ),
      _ => (
          SipColors.accSoft,
          SipColors.accFg,
          'Açık',
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: SipColors.accFg, shape: BoxShape.circle),
          ),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          lead,
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontFamily: sipFontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }
}

enum OrderFilter { benim, acik, teslim, tumu }

class OrderListItem {
  OrderListItem({required this.order, this.customerName});
  final Order order;
  final String? customerName;
}

/// Sipariş listesi sorgusu — müşteri adıyla birlikte, en yeni önce. Ekrandan bağımsız fonksiyon:
/// sorgu mantığı saf async testle sınanır (widget-test sahte zamanı drift akışlarında güvenilmez).
/// SÖZLEŞME: testler doğrudan çağırır — imza/davranış DEĞİŞMEZ.
Stream<List<OrderListItem>> watchOrders(AppDatabase db, OrderFilter filter, {String? assignedTo}) {
  final q = db.select(db.orders).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
  ]);
  q.where(db.orders.deletedAt.isNull());
  switch (filter) {
    case OrderFilter.benim:
      // Yalnız bana atanmış AÇIK siparişler (kurye günlük iş listesi). assignedTo null gelirse
      // hiçbir gerçek uuid ile eşleşmeyen sentinel → boş liste (kimseye atanmamış gösterilmez).
      q.where(db.orders.status.equals('open'));
      q.where(db.orders.assignedUserId.equals(assignedTo ?? '__none__'));
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

/// Sipariş başına ürün özeti (görüntü için; "2 × 19L Damacana · 1 × 10L"). Additive salt-okunur
/// akış — `watchOrders`'a dokunulmaz. Silinmiş satırlar hariç.
Stream<Map<String, String>> watchOrderItemsSummary(AppDatabase db) {
  final q = db.select(db.orderLines)..where((l) => l.deletedAt.isNull());
  return q.watch().map((lines) {
    final byOrder = <String, List<String>>{};
    for (final l in lines) {
      byOrder.putIfAbsent(l.orderId, () => []).add('${l.qty} × ${l.productName}');
    }
    return {for (final e in byOrder.entries) e.key: e.value.join(' · ')};
  });
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
