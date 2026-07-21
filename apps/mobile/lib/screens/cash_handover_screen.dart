import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../repo/cash_handover_repository.dart';
import 'money.dart';
import 'orders/order_list_screen.dart' show saatBicimi;
import 'team.dart';

/// DİLİM 4 — KASA DEVRİ ekranı. Kurye gün sonu SAYILAN nakiti girer; sistemin BEKLEDİĞİ nakit
/// (`onizle` — collected_by=kurye, period_start'tan beri toplanan nakit) ile farkı KANIT olarak
/// kaydedilir. Kayıt append-only (repo öyle yazar); düzeltme YENİ devirle, asla ezme (BRIEF).
/// Fark ≠ 0 kırmızı görünür ama devir REDDEDİLMEZ — "eksik para görünür kalmalı" (BRIEF).
///
/// Beklenen değer submit anında `devret` içinde YENİDEN hesaplanır (anlık snapshot); ekran yalnız
/// önizler (aynı `onizle` kodundan). Görünürlük home_shell'de kapılır (K2): kurye kendi devrini
/// yapar; yönetici yalnız aktif kurye varken (tek kişilik bayide bu ekrana giriş HİÇ yoktur).
/// Kurye kendi geçmişini, yönetici (patron/operator) TÜM devirleri görür.
class CashHandoverScreen extends StatefulWidget {
  const CashHandoverScreen({
    super.key,
    required this.db,
    required this.userId,
    required this.writable,
    this.userRole,
  });

  final AppDatabase db;
  final String userId; // devreden (from_user) = daima oturumdaki kullanıcı
  final bool writable;
  final String? userRole; // 'kurye' → yalnız kendi geçmişi; yönetici → tüm devirler

  @override
  State<CashHandoverScreen> createState() => _CashHandoverScreenState();
}

class _CashHandoverScreenState extends State<CashHandoverScreen> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  String? _devralanId;
  late Future<HandoverOnizleme> _onizle;

  @override
  void initState() {
    super.initState();
    _onizle = CashHandoverRepository(widget.db).onizle(widget.userId);
  }

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _kurye => widget.userRole == 'kurye';

  Future<void> _devret(int expected) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!widget.writable) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Salt-okunur kip: kasa devri yapılamaz.')));
      return;
    }
    final counted = parseKurus(_counted.text);
    if (counted == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Sayılan nakit tutarını girin.')));
      return;
    }
    await CashHandoverRepository(widget.db).devret(
      fromUserId: widget.userId,
      toUserId: _devralanId,
      countedCashKurus: counted,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (!mounted) return;
    _counted.clear();
    _note.clear();
    setState(() {
      _devralanId = null;
      // Devir sonrası pencere yeni devrin occurred_at'ine kayar → beklenen sıfırlanır.
      _onizle = CashHandoverRepository(widget.db).onizle(widget.userId);
    });
    messenger.showSnackBar(const SnackBar(content: Text('Kasa devredildi.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasa devri')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<HandoverOnizleme>(
            future: _onizle,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _DevirFormu(
                expected: snap.data!.expectedKurus,
                counted: _counted,
                note: _note,
                writable: widget.writable,
                devralanId: _devralanId,
                yoneticiler: watchYoneticiler(widget.db),
                onDevralanChanged: (v) => setState(() => _devralanId = v),
                onCountedChanged: () => setState(() {}),
                onDevret: () => _devret(snap.data!.expectedKurus),
              );
            },
          ),
          const Divider(height: 32),
          Text('Geçmiş devirler', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Gecmis(db: widget.db, fromUserId: _kurye ? widget.userId : null),
        ],
      ),
    );
  }
}

/// Devir formu: sayılan nakit + beklenen + canlı fark + devralan + not + "Kasayı devret".
class _DevirFormu extends StatelessWidget {
  const _DevirFormu({
    required this.expected,
    required this.counted,
    required this.note,
    required this.writable,
    required this.devralanId,
    required this.yoneticiler,
    required this.onDevralanChanged,
    required this.onCountedChanged,
    required this.onDevret,
  });

  final int expected;
  final TextEditingController counted;
  final TextEditingController note;
  final bool writable;
  final String? devralanId;
  final Stream<List<User>> yoneticiler;
  final ValueChanged<String?> onDevralanChanged;
  final VoidCallback onCountedChanged;
  final VoidCallback onDevret;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final girilen = parseKurus(counted.text);
    final fark = girilen == null ? null : girilen - expected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Satir(etiket: 'Beklenen nakit', deger: formatKurus(expected)),
            const SizedBox(height: 12),
            TextField(
              controller: counted,
              enabled: writable,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onCountedChanged(),
              decoration: const InputDecoration(
                labelText: 'Sayılan nakit',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            if (fark != null)
              _Satir(
                etiket: 'Fark',
                deger: formatKurus(fark),
                // Fark kanıttır: eksik/fazla kırmızı görünür ama devir engellenmez (BRIEF).
                renk: fark != 0 ? scheme.error : null,
                vurgu: true,
              ),
            const SizedBox(height: 12),
            StreamBuilder<List<User>>(
              stream: yoneticiler,
              builder: (context, snap) {
                final list = snap.data ?? const <User>[];
                if (list.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String?>(
                  initialValue: devralanId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Devralan (opsiyonel)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('—')),
                    for (final u in list)
                      DropdownMenuItem<String?>(value: u.id, child: Text(u.name)),
                  ],
                  onChanged: writable ? onDevralanChanged : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              enabled: writable,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDevret,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Kasayı devret'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Geçmiş devirler listesi. fromUserId verilirse (kurye) yalnız onun devirleri; null (yönetici)
/// ise tüm devirler. Devralan adı team aynasından çözülür.
class _Gecmis extends StatelessWidget {
  const _Gecmis({required this.db, required this.fromUserId});

  final AppDatabase db;
  final String? fromUserId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<User>>(
      stream: watchTeam(db),
      builder: (context, teamSnap) {
        final team = teamSnap.data ?? const <User>[];
        return StreamBuilder<List<CashHandover>>(
          stream: watchCashHandovers(db, fromUserId: fromUserId),
          builder: (context, snap) {
            final rows = snap.data;
            if (rows == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Henüz kasa devri yok.'),
              );
            }
            return Column(
              children: [
                for (final h in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text('Sayılan ${formatKurus(h.countedCashKurus)}'
                        ' · Beklenen ${formatKurus(h.expectedCashKurus)}'),
                    subtitle: Text([
                      saatBicimi(h.occurredAt),
                      if (h.toUserId != null)
                        'Devralan: ${kullaniciAdi(team, h.toUserId) ?? '—'}',
                      if (h.note != null && h.note!.isNotEmpty) h.note!,
                    ].join(' · ')),
                    trailing: Text(
                      'Fark ${formatKurus(h.diffKurus)}',
                      style: TextStyle(
                        color: h.diffKurus != 0 ? scheme.error : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({required this.etiket, required this.deger, this.vurgu = false, this.renk});
  final String etiket;
  final String deger;
  final bool vurgu;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final stil = (vurgu
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(color: renk, fontWeight: vurgu ? FontWeight.bold : null);
    return Row(
      children: [
        Expanded(child: Text(etiket, style: stil)),
        Text(deger, style: stil),
      ],
    );
  }
}

/// Kasa devri geçmişi sorgusu (ekrandan bağımsız — saf async testle sınanır). fromUserId verilirse
/// yalnız o kullanıcının devirleri (kurye kendi geçmişi); null ise tümü (yönetici). En yeni önce.
Stream<List<CashHandover>> watchCashHandovers(AppDatabase db, {String? fromUserId}) {
  final q = db.select(db.cashHandovers)
    ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
  if (fromUserId != null) {
    q.where((t) => t.fromUserId.equals(fromUserId));
  }
  return q.watch();
}
