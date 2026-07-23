import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/session.dart';
import '../data/app_database.dart';
import '../phase0/phase0_screen.dart';
import '../subscription/subscription_state.dart';
import '../sync/sync_service.dart';
import '../theme/tokens.dart';
import 'cash_handover_screen.dart';
import 'customers/customer_list_screen.dart';
import 'day_end_screen.dart';
import 'orders/order_list_screen.dart';
import 'products/product_list_screen.dart';
import 'team.dart';

/// Ana kabuk: alt gezinme (Müşteriler | Siparişler | Menü) + abonelik durum şeridi + senkron durumu.
/// Rol bazlı görünüm (Dilim 4, K2): oturumdaki kullanıcının rolü + bayide aktif kurye olup olmadığı
/// `yetkiler()`e verilir; ürün/gün-sonu/kupon/düzeltme/atama/kasa-devri kapıları buradan türer.
/// **Tek kişilik bayide kurye adımları HİÇ render edilmez** (BRIEF — pazarlıksız): aktif kurye yoksa
/// atama ve (yönetici için) kasa devri girişi görünmez.
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
  String? _userRole;
  String? _userId;
  List<User> _kuryeler = const [];
  StreamSubscription<SyncOutcome>? _syncSub;
  StreamSubscription<List<User>>? _kuryeSub;
  SyncOutcome? _lastSync;

  @override
  void initState() {
    super.initState();
    _refreshMeta();
    // Aktif kurye varlığı "tek kişilik bayi" kararının dayanağıdır (K2 kuryeVar). Ekip listesi
    // senkronla (team bloğu) değiştikçe kapılar canlı güncellenir.
    _kuryeSub = watchAktifKuryeler(widget.db).listen((k) {
      if (!mounted) return;
      setState(() => _kuryeler = k);
    });
    _syncSub = widget.sync.status.listen((o) {
      if (!mounted) return;
      setState(() => _lastSync = o);
      _refreshMeta(); // sunucu yanıtı abonelik önbelleğini + oturum bilgisini tazelemiş olabilir
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _kuryeSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshMeta() async {
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
    if (!mounted) return;
    if (level != _access || meta.userRole != _userRole || meta.userId != _userId) {
      setState(() {
        _access = level;
        _userRole = meta.userRole;
        _userId = meta.userId;
      });
    }
  }

  bool get writable => SubscriptionState.writable(_access);

  /// Rol + kurye varlığından türeyen görünüm yetkileri (K2). Kurye yoksa yönetici için atama/kasa
  /// devri kapalıdır (tek kişilik gizleme).
  RolYetkileri get _yetki => yetkiler(rol: _userRole, kuryeVar: _kuryeler.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final yetki = _yetki;
    final pages = [
      CustomerListScreen(db: widget.db, writable: writable, yetki: yetki),
      OrderListScreen(
        db: widget.db,
        writable: writable,
        userRole: _userRole,
        userId: _userId,
        canAssign: yetki.atama,
      ),
      _MenuTab(
        db: widget.db,
        session: widget.session,
        sync: widget.sync,
        lastSync: _lastSync,
        writable: writable,
        yetki: yetki,
        userId: _userId,
        userRole: _userRole,
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
          NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Müşteriler'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Siparişler'),
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
    // Nötr bilgi şeridi (BRIEF mağaza kuralı: fiyat/abone-ol/link YOK). Renk token'lardan.
    final fg = readOnly ? SipColors.debt : SipColors.warn;
    return Material(
      color: readOnly ? SipColors.debtSoft : SipColors.warnSoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(readOnly ? Icons.lock_outline : Icons.info_outline, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  readOnly
                      ? 'Aboneliğiniz sona erdi; kayıtlar salt-okunur. Destek alın.'
                      : 'Abonelik süreniz doldu görünüyor; bağlantı kurulunca netleşecek.',
                  style: const TextStyle(color: SipColors.t1, fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
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
    required this.writable,
    required this.yetki,
    required this.userId,
    required this.userRole,
    required this.onLoggedOut,
  });

  final AppDatabase db;
  final Session session;
  final SyncService sync;
  final SyncOutcome? lastSync;
  final bool writable;
  final RolYetkileri yetki;
  final String? userId;
  final String? userRole;
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
              // Ürün yönetimi yönetici işidir (K2) — kuryede gizli.
              if (yetki.urunYonetimi)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Ürünler'),
                  subtitle: const Text('Sipariş satırlarında çıkan ürün listesi'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductListScreen(db: db, writable: writable),
                  )),
                ),
              // Gün sonu özeti yönetici işidir (K2) — kuryede gizli.
              if (yetki.gunSonu)
                ListTile(
                  leading: const Icon(Icons.point_of_sale_outlined),
                  title: const Text('Gün sonu'),
                  subtitle: const Text('Kasa · veresiye · kupon özeti (salt-okunur)'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DayEndScreen(db: db),
                  )),
                ),
              // Kasa devri: kurye HER ZAMAN (kendi devri), yönetici yalnız aktif kurye varken (K2).
              // Tek kişilik bayide bu giriş HİÇ görünmez (BRIEF). userId yoksa devir yapılamaz.
              if (yetki.kasaDevri && userId != null)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Kasa devri'),
                  subtitle: const Text('Gün sonu nakit devri (kurye → patron)'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CashHandoverScreen(
                      db: db,
                      userId: userId!,
                      userRole: userRole,
                      writable: writable,
                    ),
                  )),
                ),
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
                  MaterialPageRoute(builder: (_) => Phase0Screen(db: db)),
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
