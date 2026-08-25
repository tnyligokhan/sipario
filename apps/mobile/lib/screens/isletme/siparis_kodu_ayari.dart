// SİPARİŞ SATIRINDA HANGİ KOD GÖRÜNSÜN — bayi tercihi (kullanıcı isteği 2026-07-29:
// "isteyen firma siparişte müşteri kodu, isteyen firma sipariş kodu görsün, bunu ayarlardan
// kendi ayarlayabilsin").
//
// NEDEN AYRI DOSYA: `ayarlar_ekrani.dart` 502 satırdı (depo sınırı 500) ve bu satır onu daha da
// büyütecekti. Ayar EKRANI düzen işi yapar; tek bir tercihin okunması/yazılması ayrı bir konudur.
//
// NEDEN KİRACI AYARI (cihaz-yerel değil): iki telefonlu bir bayide aynı liste iki farklı numara
// gösterirdi ve "abi sende 102 yazıyor bende #248" telefon trafiği doğardı. Tercih senkronla
// iner; `tutamacSagdaTercihi` gibi cihaz-yerel olanlar EL ALIŞKANLIĞIDIR (sol/sağ el), bu ise
// bayinin İŞ SÖZLÜĞÜDÜR — ortak olmalı.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../orders/order_queries.dart' show watchSiparisKoduTercihi;
import '../orders/order_sheets.dart' show SecimSatiri;
import 'isletme_atomlari.dart';

/// Tercihin ekranda görünen adı. Tek yerde: satırın alt başlığı ile sheet'teki seçenek aynı
/// sözcüğü kullanmak zorundadır, yoksa kullanıcı seçtiğinin karşılığını göremez.
String siparisKoduEtiketi(String tercih) =>
    tercih == 'siparis' ? 'Sipariş kodu (#248)' : 'Müşteri kodu (102)';

class SiparisKoduSatiri extends StatelessWidget {
  const SiparisKoduSatiri({super.key, required this.db, this.writable = true});

  final AppDatabase db;
  final bool writable;

  Future<void> _sec(BuildContext context, String mevcut) async {
    if (!writable) {
      SipToast.goster(context, 'Aboneliğiniz sona erdiği için ayar değiştirilemiyor');
      return;
    }
    final secim = await sipSheet<String>(
      context,
      baslik: 'Sipariş Satırındaki Kod',
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in const ['musteri', 'siparis'])
            SecimSatiri(
              etiket: siparisKoduEtiketi(t),
              ikon: t == 'siparis' ? SipIcons.list : SipIcons.user,
              secili: t == mevcut,
              onTap: () => Navigator.of(ctx).pop(t),
            ),
        ],
      ),
    );
    if (secim == null || secim == mevcut || !context.mounted) return;
    await TenantSettingsRepository(db).siparisKoduTercihiKaydet(secim);
    if (!context.mounted) return;
    SipToast.goster(context, 'Sipariş satırında ${siparisKoduEtiketi(secim)} gösterilecek');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: watchSiparisKoduTercihi(db),
      initialData: 'musteri',
      builder: (context, snap) {
        final mevcut = snap.data ?? 'musteri';
        return AyarSatiri(
          ikon: SipIcons.list,
          baslik: 'Sipariş satırındaki kod',
          // Alt başlık SEÇİLİ değeri yazar: bir ayarın ne olduğunu görmek için ona
          // dokunmak gerekiyorsa, o ayar gizlidir.
          altBaslik: siparisKoduEtiketi(mevcut),
          onTap: () => _sec(context, mevcut),
        );
      },
    );
  }
}
