// AYARLAR → İŞLETME — bayinin KENDİ bilgileri: profil, iletişim, sipariş kodu tercihi.
//
// YALNIZ PATRON (operatör de dahil DEĞİL). Bu kapı bilinçli olarak `rol == 'patron'` string'ine
// bakar, `RolYetkileri.isletmeAbonelikAyarlari` alanına değil — matriste o alan TANIMLI ama bu
// yüzeyde hiç kullanılmıyordu ve iki ölçütü birden canlı tutmak, birinin sessizce ayrışması
// demekti. Kapı ÇAĞIRANDADIR (ayarlar hub'ı satırı hiç çizmez); burası ikinci kapı değil,
// sayfanın kendi sözleşmesidir: bu sayfayı açan patron olmalıdır.
//
// MAĞAZA KURALI: abonelik / ödeme / satın alma / fiyat / üyelik bağlantısı OLAMAZ.

import 'package:flutter/material.dart';

import '../../../data/app_database.dart';
import '../../../repo/tenant_settings_repository.dart';
import '../../../theme/components/atoms.dart';
import '../../../theme/components/states.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../isletme_atomlari.dart';
import '../isletme_profili_ekrani.dart';
import '../siparis_kodu_ayari.dart';

class IsletmeAyarlariEkrani extends StatelessWidget {
  const IsletmeAyarlariEkrani({
    super.key,
    required this.db,
    required this.writable,
  });

  final AppDatabase db;
  final bool writable;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(baslik: 'İşletme', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              // Ad/iletişim özeti `tenant_settings`ten CANLI okunur — profil ekranında
              // kaydedilince buraya geri dönmeden güncellenir.
              child: StreamBuilder<TenantSetting?>(
                stream: TenantSettingsRepository(db).watch(),
                builder: (context, snap) => _Govde(
                  db: db,
                  writable: writable,
                  profil: snap.data,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({required this.db, required this.writable, required this.profil});

  final AppDatabase db;
  final bool writable;

  /// `tenant_settings` satırı; henüz kaydedilmediyse null.
  final TenantSetting? profil;

  @override
  Widget build(BuildContext context) {
    final ad = (profil?.businessName ?? '').trim();
    final sahip = (profil?.ownerName ?? '').trim();
    final telefon = (profil?.phone ?? '').trim();
    final iletisim = [
      if (sahip.isNotEmpty) sahip,
      if (telefon.isNotEmpty) sipTelefon(telefon),
    ].join(' · ');

    return SipGovde(
      children: [
        const SipBolumBaslik('Kimlik', ustBosluk: 18),
        AyarKarti(satirlar: [
          AyarSatiri(
            ikon: SipIcons.home,
            baslik: ad.isEmpty ? 'İşletme profili' : ad,
            altBaslik: iletisim.isEmpty ? 'Bilgileri tamamlayın' : iletisim,
            sag: SipMetinButon(
              etiket: 'Düzenle',
              zemin: context.sip.surface2,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => IsletmeProfiliEkrani(db: db, writable: writable),
                ),
              ),
            ),
          ),
        ]),

        const SipBolumBaslik('Sipariş', ustBosluk: 18),
        AyarKarti(satirlar: [
          SiparisKoduSatiri(db: db, writable: writable),
        ]),
      ],
    );
  }
}
