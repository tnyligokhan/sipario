import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/session.dart';
import '../data/app_database.dart';
import '../phase0/phase0_screen.dart';
import '../subscription/subscription_state.dart';
import '../sync/sync_service.dart';
import 'customers/customer_list_screen.dart';

/// Ana kabuk: alt gezinme (Müşteriler | Siparişler | Menü) + abonelik durum şeridi + senkron durumu.
/// Kurye adımlarının tek kişilik bayide gizlenmesi (BRIEF) ilgili ekranların işidir (Dilim 4).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.db,
    required this.session,
    required this.sync,
    required this.onLoggedOut,
  });

  final AppDatabase db;
  final Session session;
  final SyncService sync;
  final VoidCallback onLoggedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  AccessLevel _access = AccessLevel.full;
  StreamSubscription<SyncOutcome>? _syncSub;
  SyncOutcome? _lastSync;

  @override
  void initState() {
    super.initState();
    _refreshAccess();
    _syncSub = widget.sync.status.listen((o) {
      if (!mounted) return;
      setState(() => _lastSync = o);
      _refreshAccess(); // sunucu yanıtı abonelik önbelleğini tazelemiş olabilir
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshAccess() async {
    final meta = await widget.db.syncState();
    final now = SubscriptionState.estimateServerNow(
      serverTimeOffsetMs: meta.serverTimeOffsetMs,
      lastServerTimeIso: meta.lastServerTimeIso,
    );
    final level = SubscriptionState.evaluate(
      estimatedServerNow: now,
      validUntil: meta.validUntilIso != null ? DateTime.tryParse(meta.validUntilIso!) : null,
      status: meta.subscriptionStatus,
    );
    if (mounted && level != _access) setState(() => _access = level);
  }

  bool get writable => SubscriptionState.writable(_access);

  @override
  Widget build(BuildContext context) {
    final pages = [
      CustomerListScreen(db: widget.db, writable: writable),
      const _OrdersPlaceholder(),
      _MenuTab(
        db: widget.db,
        session: widget.session,
        sync: widget.sync,
        lastSync: _lastSync,
        onLoggedOut: widget.onLoggedOut,
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (_access != AccessLevel.full) _SubscriptionBanner(access: _access),
          Expanded(child: pages[_tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Müşteriler'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Siparişler'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Menü'),
        ],
      ),
    );
  }
}

/// Abonelik şeridi — NÖTR metin (BRIEF mağaza kuralı: fiyat/abone ol/link YOK).
class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner({required this.access});
  final AccessLevel access;

  @override
  Widget build(BuildContext context) {
    final readOnly = access == AccessLevel.readOnly;
    return Material(
      color: readOnly
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(readOnly ? Icons.lock_outline : Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  readOnly
                      ? 'Aboneliğiniz sona erdi; kayıtlar salt-okunur. Destek alın.'
                      : 'Abonelik süreniz doldu görünüyor; bağlantı kurulunca netleşecek.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersPlaceholder extends StatelessWidget {
  const _OrdersPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Siparişler')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Sipariş ekranları bir sonraki sürümde.', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _MenuTab extends StatelessWidget {
  const _MenuTab({
    required this.db,
    required this.session,
    required this.sync,
    required this.lastSync,
    required this.onLoggedOut,
  });

  final AppDatabase db;
  final Session session;
  final SyncService sync;
  final SyncOutcome? lastSync;
  final VoidCallback onLoggedOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menü')),
      body: FutureBuilder<SyncMetaData>(
        future: db.syncState(),
        builder: (context, snap) {
          final meta = snap.data;
          return ListView(
            children: [
              if (meta != null)
                ListTile(
                  leading: const Icon(Icons.storefront),
                  title: Text(meta.tenantName ?? 'Bayi'),
                  subtitle: Text([
                    if (meta.userName != null) meta.userName!,
                    if (meta.userRole != null) '(${meta.userRole})',
                  ].join(' ')),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Şimdi senkronla'),
                subtitle: lastSync == null
                    ? null
                    : Text(lastSync!.ok
                        ? 'Son senkron başarılı'
                        : 'Son senkron başarısız — tekrar denenecek'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final o = await sync.syncNow();
                  messenger.showSnackBar(SnackBar(
                    content: Text(o.ok
                        ? 'Senkron tamam${o.pushed > 0 ? ' (${o.pushed} kayıt gönderildi)' : ''}'
                        : 'Sunucuya ulaşılamadı; kayıtlar bekliyor, otomatik denenecek'),
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_in_talk_outlined),
                title: const Text('Arayan tanıma kurulumu ve ölçüm'),
                subtitle: const Text('Kurulum sihirbazı, izinler, gecikme ölçümleri'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const Phase0Screen()),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Çıkış yap'),
                subtitle: const Text('Yerel kayıtlar cihazda kalır'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Çıkış yapılsın mı?'),
                      content: const Text('Kayıtlarınız cihazda kalır; tekrar girişte devam edersiniz.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkış yap')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await session.logout();
                    onLoggedOut();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
