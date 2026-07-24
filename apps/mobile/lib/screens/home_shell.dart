import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/session.dart';
import '../data/app_database.dart';
import '../subscription/subscription_state.dart';
import '../sync/sync_service.dart';
import '../theme/tokens.dart';
import 'customers/customer_list_screen.dart';
import 'menu_tab.dart';
import 'orders/order_list_screen.dart';
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
  DateTime? _lastSyncAt; // yalnız gösterim (senkron kartındaki saat) — veri akışına dokunmaz

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
      setState(() {
        _lastSync = o;
        _lastSyncAt = DateTime.now();
      });
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
      MenuTab(
        db: widget.db,
        session: widget.session,
        sync: widget.sync,
        lastSync: _lastSync,
        lastSyncAt: _lastSyncAt,
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

