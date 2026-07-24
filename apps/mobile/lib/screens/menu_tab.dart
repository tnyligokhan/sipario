import 'package:flutter/material.dart';

import '../auth/session.dart';
import '../data/app_database.dart';
import '../phase0/phase0_screen.dart';
import '../sync/sync_service.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'cash_handover_screen.dart';
import 'day_end_screen.dart';
import 'orders/order_list_screen.dart' show saatBicimi;
import 'products/product_list_screen.dart';
import 'team.dart';

/// EKRAN 4 — Menü sekmesi (yeniden tasarım; home_shell'den 500-satır sınırı için ayrıldı).
/// Görsel: ekran başlığı + profil kartı + senkron durum kartı (renkli nokta + etiket + saat —
/// DESIGN_SYSTEM "Senkron durumu") + bölüm etiketli kart satırları. Davranış/kapılar (K2 yetki
/// gizleme, tek kişilik bayi, mağaza kuralı) DEĞİŞMEDİ; yalnız görünüm yenilendi.
class MenuTab extends StatelessWidget {
  const MenuTab({
    super.key,
    required this.db,
    required this.session,
    required this.sync,
    required this.lastSync,
    required this.lastSyncAt,
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
  final DateTime? lastSyncAt;
  final bool writable;
  final RolYetkileri yetki;
  final String? userId;
  final String? userRole;
  final VoidCallback onLoggedOut;

  @override
  Widget build(BuildContext context) {
    // İşletme bölümü tamamen boşsa etiketi de çizme (kurye + userId yok gibi uç durum).
    final isletmeVar = yetki.urunYonetimi || yetki.gunSonu || (yetki.kasaDevri && userId != null);
    return Scaffold(
      backgroundColor: SipColors.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<SyncMetaData>(
          future: db.syncState(),
          builder: (context, snap) {
            final meta = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, 4, SipSpace.lg),
                  child: Text('Menü', style: SipText.screenTitle),
                ),
                if (meta != null) ...[
                  _ProfilKarti(meta: meta),
                  const SizedBox(height: SipSpace.gap),
                ],
                _SenkronKarti(lastSync: lastSync, lastSyncAt: lastSyncAt, sync: sync),
                if (isletmeVar) ...[
                  const _BolumEtiketi('İŞLETME'),
                  // Ürün yönetimi yönetici işidir (K2) — kuryede gizli.
                  if (yetki.urunYonetimi)
                    _MenuKarti(
                      ikon: Icons.inventory_2_outlined,
                      baslik: 'Ürünler',
                      altyazi: 'Sipariş satırlarında çıkan ürün listesi',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProductListScreen(db: db, writable: writable),
                      )),
                    ),
                  // Gün sonu özeti yönetici işidir (K2) — kuryede gizli.
                  if (yetki.gunSonu)
                    _MenuKarti(
                      ikon: Icons.point_of_sale_outlined,
                      baslik: 'Gün sonu',
                      altyazi: 'Kasa · veresiye · kupon özeti (salt-okunur)',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DayEndScreen(db: db),
                      )),
                    ),
                  // Kasa devri: kurye HER ZAMAN (kendi devri), yönetici yalnız aktif kurye varken (K2).
                  // Tek kişilik bayide bu giriş HİÇ görünmez (BRIEF). userId yoksa devir yapılamaz.
                  if (yetki.kasaDevri && userId != null)
                    _MenuKarti(
                      ikon: Icons.account_balance_wallet_outlined,
                      baslik: 'Kasa devri',
                      altyazi: 'Gün sonu nakit devri (kurye → patron)',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CashHandoverScreen(
                          db: db,
                          userId: userId!,
                          userRole: userRole,
                          writable: writable,
                        ),
                      )),
                    ),
                ],
                const _BolumEtiketi('UYGULAMA'),
                _MenuKarti(
                  ikon: Icons.phone_in_talk_outlined,
                  baslik: 'Arayan tanıma kurulumu ve ölçüm',
                  altyazi: 'Kurulum sihirbazı, izinler, gecikme ölçümleri',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => Phase0Screen(db: db)),
                  ),
                ),
                const _BolumEtiketi('HESAP'),
                _MenuKarti(
                  ikon: Icons.logout,
                  baslik: 'Çıkış yap',
                  altyazi: 'Yerel kayıtlar cihazda kalır',
                  tehlike: true,
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
      ),
    );
  }
}

/// Profil kartı — bayi adı + kullanıcı (rol). Liste kartlarıyla aynı yüzey dili; aksiyon yok.
class _ProfilKarti extends StatelessWidget {
  const _ProfilKarti({required this.meta});
  final SyncMetaData meta;

  @override
  Widget build(BuildContext context) {
    final altyazi = [
      if (meta.userName != null) meta.userName!,
      if (meta.userRole != null) '(${meta.userRole})',
    ].join(' ');
    return Container(
      decoration: BoxDecoration(
        color: SipColors.s1,
        borderRadius: SipRadius.cardBr,
        border: Border.all(color: SipColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: SipColors.s3, shape: BoxShape.circle),
            child: const Icon(Icons.storefront_outlined, size: 22, color: SipColors.accFg),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(meta.tenantName ?? 'Bayi',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: SipText.cardTitle),
                if (altyazi.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(altyazi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SipText.secondary.copyWith(fontSize: 13.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Senkron durum kartı — renkli nokta (yeşil ok / kırmızı hata / soluk henüz-yok) + etiket + saat
/// (DESIGN_SYSTEM "Senkron durumu (Menü)"). Karta dokunmak = "Şimdi senkronla".
class _SenkronKarti extends StatelessWidget {
  const _SenkronKarti({required this.lastSync, required this.lastSyncAt, required this.sync});
  final SyncOutcome? lastSync;
  final DateTime? lastSyncAt;
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final nokta = lastSync == null
        ? SipColors.t3
        : (lastSync!.ok ? SipColors.ok : SipColors.err);
    final saat = lastSyncAt != null ? ' · ${saatBicimi(lastSyncAt!.toIso8601String())}' : '';
    final durum = lastSync == null
        ? 'Bu oturumda henüz senkron olmadı'
        : (lastSync!.ok
            ? 'Son senkron başarılı$saat'
            : 'Son senkron başarısız — tekrar denenecek$saat');
    return Material(
      color: SipColors.s1,
      borderRadius: SipRadius.cardBr,
      child: InkWell(
        borderRadius: SipRadius.cardBr,
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final o = await sync.syncNow();
          messenger.showSnackBar(SnackBar(
            content: Text(o.ok
                ? 'Senkron tamam${o.pushed > 0 ? ' (${o.pushed} kayıt gönderildi)' : ''}'
                : 'Sunucuya ulaşılamadı; kayıtlar bekliyor, otomatik denenecek'),
          ));
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: SipRadius.cardBr,
            border: Border.all(color: SipColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: nokta, shape: BoxShape.circle),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Şimdi senkronla', style: SipText.cardTitle),
                      const SizedBox(height: 3),
                      Text(durum,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SipText.secondary.copyWith(fontSize: 13.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.sync, size: 20, color: SipColors.accFg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm etiketi — VERSAL, harf aralıklı (sectionLabel).
class _BolumEtiketi extends StatelessWidget {
  const _BolumEtiketi(this.etiket);
  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, SipSpace.xl, 4, SipSpace.sm),
      child: Text(etiket, style: SipText.sectionLabel),
    );
  }
}

/// Menü giriş kartı — sol yuvarlatılmış ikon kutusu + başlık/altyazı + sağda ok. `tehlike`
/// çıkış gibi dikkat isteyen girişleri kırmızı ikonla ayırır (metin rengi nötr kalır).
class _MenuKarti extends StatelessWidget {
  const _MenuKarti({
    required this.ikon,
    required this.baslik,
    this.altyazi,
    this.tehlike = false,
    required this.onTap,
  });

  final IconData ikon;
  final String baslik;
  final String? altyazi;
  final bool tehlike;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.gap),
      child: Material(
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
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tehlike ? SipColors.debtSoft : SipColors.s3,
                      borderRadius: SipRadius.smBr,
                    ),
                    child: Icon(ikon,
                        size: 21, color: tehlike ? SipColors.debt : SipColors.accFg),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(baslik,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: SipText.cardTitle),
                        if (altyazi != null) ...[
                          const SizedBox(height: 3),
                          Text(altyazi!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SipText.secondary.copyWith(fontSize: 13.5)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right, size: 20, color: SipColors.t3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
