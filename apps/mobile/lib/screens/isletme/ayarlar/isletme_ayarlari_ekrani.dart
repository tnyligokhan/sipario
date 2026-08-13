// AYARLAR → İŞLETME — dükkânın kendi ayarları: kimlik, tahsilat, mesajlar, sipariş.
//
// ══ SAYFA BİR HUB'DIR, FORM DEĞİL (kullanıcı eleştirisi 2026-08-13) ════════════════════════
// Eskiden buradaki tek satır ("Düzenle") YEDİ konuyu tek forma açıyordu. Kullanıcı haklı olarak
// sordu: mesaj şablonları ve fiş bölümü neden İşletme Kimliği'nin içinde? Cevap: olmamalıydı.
// Artık her konu kendi satırı ve kendi ekranı:
//
//   Kimlik   → ad, yetkili, iletişim, vergi, çalışma saatleri   (isletme_profili_ekrani.dart)
//   Tahsilat → IBAN, alıcı adı, fiş notu (pasif)                (tahsilat_ayarlari_ekrani.dart)
//   Mesajlar → müşteriye giden hazır metinler, N tane           (mesaj_sablonlari_ekrani.dart)
//   Sipariş  → sipariş kodu tercihi                             (siparis_kodu_ayari.dart)
//
// Bölünme yalnız görsel değil: her ekran `save`e YALNIZ kendi alanlarını verir, geri kalanına
// dokunmaz. Tek form olduğu sürece iki cihazın çevrimdışı düzenlemesi birbirini eziyordu.
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
import 'mesaj_sablonlari_ekrani.dart';
import 'tahsilat_ayarlari_ekrani.dart';

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

    // Her satır KENDİ DURUMUNU özetler: bayi hangi ayarın eksik olduğunu içeri girmeden görür.
    // "Düzenle" düğmeleriyle dolu bir liste bunu yapamaz — hepsi aynı görünür, hiçbiri bilgi
    // vermez.
    final iban = ibanOkunur(profil?.iban);
    final sablonOzel = (profil?.reminderTemplate ?? '').trim().isNotEmpty;

    return SipGovde(
      children: [
        const SipBolumBaslik('Kimlik', ustBosluk: 18),
        AyarKarti(satirlar: [
          AyarSatiri(
            ikon: SipIcons.home,
            baslik: ad.isEmpty ? 'İşletme kimliği' : ad,
            altBaslik: iletisim.isEmpty ? 'Bilgileri tamamlayın' : iletisim,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IsletmeProfiliEkrani(db: db, writable: writable),
              ),
            ),
          ),
        ]),

        const SipBolumBaslik('Para', ustBosluk: 18),
        AyarKarti(satirlar: [
          AyarSatiri(
            ikon: SipIcons.wallet,
            baslik: 'Tahsilat',
            // IBAN'IN VARLIĞI ÖZETTE GÖRÜNÜR: borç hatırlatma düğmesi IBAN yoksa çalışmıyor ve
            // bayi nedenini ancak borçlular ekranında öğreniyordu.
            altBaslik: iban.isEmpty ? 'IBAN girilmedi' : iban,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TahsilatAyarlariEkrani(db: db, writable: writable),
              ),
            ),
          ),
        ]),

        const SipBolumBaslik('Müşteriye giden', ustBosluk: 18),
        AyarKarti(satirlar: [
          AyarSatiri(
            ikon: SipIcons.chat,
            baslik: 'Mesajlar',
            altBaslik: sablonOzel
                ? '${kMesajSablonlari.length} şablon · özelleştirilmiş'
                : '${kMesajSablonlari.length} şablon · varsayılan metin',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MesajSablonlariEkrani(db: db, writable: writable),
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
