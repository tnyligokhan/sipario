// GÜN SONU ekranının kart parçaları — tasarım s-gunsonu.jsx + Sipario.html
// `.gs-veresiye`, `.gs-vtop`, `.gs-temiz`, `.gs-arow`, `.gs-engel`.
//
// Hepsi salt gösterimdir: gelen değeri çizer, hiçbir para hesabı yapmaz (hesap `gun_sonu_ozet.dart`
// üzerinden repo'lardadır).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/day_end_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_kapatma_sheet.dart';
import 'isletme_atomlari.dart';

/// CSS `.gs-veresiye` — toplam açık borç + borçlu dökümü (çoktan aza).
class VeresiyeKarti extends StatelessWidget {
  const VeresiyeKarti({super.key, required this.borc});

  final BorcDurumu borc;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return DegerKarti(
      satirlar: [
        // CSS `.gs-vtop`
        DegerSatiri(
          etiket: 'Toplam açık borç',
          deger: sipTutar(borc.toplamAcikBorc),
          degerRengi: borc.toplamAcikBorc > 0 ? t.danger : t.ink,
        ),
        if (borc.borclular.isEmpty)
          // CSS `.gs-temiz`
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                SipIcon(SipIcons.check, boyut: 16, kalinlik: 2.4, renk: t.ok),
                const SizedBox(width: SipSpace.md),
                Text(
                  'Borçlu müşteri yok',
                  style: SipText.metin(13, w: 700).copyWith(color: t.ok),
                ),
              ],
            ),
          )
        else
          for (final b in borc.borclular)
            DegerSatiri(
              etiket: b.name,
              deger: sipTutar(b.balanceKurus),
              degerRengi: t.danger,
            ),
      ],
    );
  }
}

/// CSS `.gs-arow` — arşiv satırı. [kapsamAdi] gün hesabında "Gün hesabı", kuryede kuryenin adı.
class ArsivSatiri extends StatelessWidget {
  const ArsivSatiri({super.key, required this.kapanis, required this.kapsamAdi, this.onTap});

  final DayClosing kapanis;
  final String kapsamAdi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final k = kapanis;
    final farkli = k.countedCashKurus != null && k.diffKurus != 0;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          SipIkonKutu(
            ikon: SipIcons.lock,
            cap: 30,
            ikonBoyut: 15,
            zemin: t.surface2,
            renk: t.muted,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kapsamAdi,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${gunSaatBicimi(k.occurredAt)} · ${k.deliveryCount} teslimat'
                    '${farkli ? ' · fark ${sipTutar(k.diffKurus)}' : ''}',
                    style: SipText.yardimci.copyWith(color: t.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Text(
            sipTutar(k.totalCollectedKurus),
            style: SipText.tutar(13.5).copyWith(color: t.ink),
          ),
          const SizedBox(width: SipSpace.sm),
          SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2, renk: t.line2),
        ],
      ),
    );
  }
}

/// CSS `.gs-engel` — kapatmayı durduran uyarı.
///
/// ÜÇ engel vardır ve hepsi aynı kutuyu kullanır (en temelden başlayarak):
///  1. [rolEngeli] — kullanıcının bu kapsamı kapatma yetkisi yok (K2): kurye gün hesabını ya da
///     başka bir kuryenin hesabını kapatamaz.
///  2. [acikSiparis] > 0 — o kapsamda hâlâ teslim edilmemiş sipariş var.
///  3. [acikKuryeler] dolu — GÜN hesabı kapatılmak isteniyor ama kuryelerin bir kısmı
///     hesabını kapatmış, bir kısmı kapatmamış (tasarım `gunEngel`). Yarım kalmış devir.
class KapatmaEngeli extends StatelessWidget {
  const KapatmaEngeli({
    super.key,
    this.rolEngeli = false,
    this.acikSiparis = 0,
    this.acikKuryeler = const [],
  });

  final bool rolEngeli;
  final int acikSiparis;
  final List<String> acikKuryeler;

  @override
  Widget build(BuildContext context) {
    final metin = rolEngeli
        ? 'Bu hesabı yönetici kapatır; siz yalnız kendi kurye hesabınızı kapatabilirsiniz.'
        : acikSiparis > 0
            ? 'Önce açık siparişleri kapatın: $acikSiparis açık sipariş var.'
            : 'Önce açık kurye hesaplarını kapatın: ${acikKuryeler.join(', ')}';
    return _EngelKutusu(metin: metin);
  }
}

class _EngelKutusu extends StatelessWidget {
  const _EngelKutusu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.warnSoft, borderRadius: SipRadius.br1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(SipIcons.alert, boyut: 14, kalinlik: 2.2, renk: t.warn),
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12, w: 600, h: 1.45).copyWith(color: t.warn),
            ),
          ),
        ],
      ),
    );
  }
}
