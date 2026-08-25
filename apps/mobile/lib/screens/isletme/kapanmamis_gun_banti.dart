// KAPANMAMIŞ GÜN BANDI + LİSTESİ (kullanıcı isteği 2026-08-21).
//
// "Kapanmayan günler bir sonraki güne aktarılıyor. Bunu bu şekilde değil de 'kapanmayan
// gün/günleriniz var' şeklinde göstermeliyiz."
//
// ══ BANT NE SÖYLER, NE SÖYLEMEZ ═════════════════════════════════════════════════════════════
// Söyler: KAÇ gün kapanmamış ve nereye dokunulacağı.
// SÖYLEMEZ: tutar. Bant gün özetinin en üstünde durur ve altındaki kartlar zaten para
// konuşuyor; oraya bir de "devreden 5.500 ₺" yazmak, hangi rakamın hangi güne ait olduğunu
// bulanıklaştırırdı. Tutar LİSTEDE, gün gün yazar — orada bir belirsizlik kalmaz.
//
// ══ NEDEN AYRI DOSYA ════════════════════════════════════════════════════════════════════════
// `day_end_screen.dart` 410 satır ve 500 sınırına yakın; bant + liste + satır üç widget demek.
// Ayrıca listeyi geçmiş gün ekranı da açabilsin diye ekrandan bağımsız durması gerekiyordu.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/kapanmamis_gunler.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_arsivi.dart' show gunTamBasligi;

/// Gün Özeti'nin tepesindeki uyarı bandı. Kapanmamış gün YOKSA hiç çizilmez.
///
/// SAYIYI KENDİ OKUR (`FutureBuilder`), çağıran ekranın görünüm modeline eklenmedi ve bu
/// bilinçli: `GunSonuGorunumu` seçili KAPSAMIN o GÜNE ait fotoğrafıdır; kapanmamış günler ise
/// kapsamdan da seçili günden de bağımsızdır. Oraya iliştirmek, kapsam her değiştiğinde
/// yeniden hesaplanan ve hiçbir kapsama ait olmayan bir alan üretirdi.
class KapanmamisGunBandi extends StatelessWidget {
  const KapanmamisGunBandi({
    super.key,
    required this.db,
    required this.onGunSec,
    this.yenilemeAnahtari = 0,
  });

  final AppDatabase db;

  /// Bir güne dokunulunca çağrılır — o günü açmak ÇAĞIRANIN işi (bu widget gezinme bilmez).
  final ValueChanged<DateTime> onGunSec;

  /// Değeri değişince sayı yeniden okunur. Gün kapatıldıktan sonra bandın kendiliğinden
  /// kaybolması için çağıran bunu artırır — akış (`watch`) kurmak dört tabloyu birden izlemek
  /// demekti ve bant o kadar sık değişen bir şey değil.
  final int yenilemeAnahtari;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      // ValueKey: `yenilemeAnahtari` değişince FutureBuilder yeni bir future'a bağlanır.
      key: ValueKey(yenilemeAnahtari),
      future: KapanmamisGunlerRepository(db).sayi(),
      builder: (context, snap) {
        final sayi = snap.data ?? 0;
        if (sayi <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(SipSpace.govde, 0, SipSpace.govde, SipSpace.lg),
          child: _Bant(
            sayi: sayi,
            onTap: () => kapanmamisGunlerSheet(context, db: db, onGunSec: onGunSec),
          ),
        );
      },
    );
  }
}

class _Bant extends StatelessWidget {
  const _Bant({required this.sayi, required this.onTap});

  final int sayi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.warnSoft,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 13),
      child: Row(
        children: [
          SipIcon(SipIcons.alert, boyut: 17, kalinlik: 2.2, renk: t.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sayi == 1 ? 'Kapatmadığınız bir gün var' : 'Kapatmadığınız $sayi gün var',
                  style: SipText.metin(13.5, w: 800).copyWith(color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kalan nakit kuryede sayılmaya devam eder. Görmek için dokunun.',
                  style: SipText.metin(12).copyWith(color: t.ink2),
                ),
              ],
            ),
          ),
          SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2.2, renk: t.muted),
        ],
      ),
    );
  }
}

/// Kapanmamış günlerin listesi. Bir güne dokunmak sheet'i kapatır ve [onGunSec]'i çağırır.
Future<void> kapanmamisGunlerSheet(
  BuildContext context, {
  required AppDatabase db,
  required ValueChanged<DateTime> onGunSec,
}) =>
    sipSheet<void>(
      context,
      baslik: 'Kapanmamış günler',
      govde: (ctx) => FutureBuilder<List<KapanmamisGun>>(
        future: KapanmamisGunlerRepository(db).bul(),
        builder: (ctx, snap) {
          final liste = snap.data;
          if (liste == null) return const SipIskelet(adet: 3);
          if (liste.isEmpty) {
            return const SipBosDurum(
              ikon: SipIcons.check,
              baslik: 'Kapanmamış gün yok',
              aciklama: 'Son on dört günün hesabı kapatılmış',
            );
          }
          // AÇIKLAMA KUTUSU KALDIRILDI (2026-08-21 kullanıcı isteği): "kapatmasam ne olur"
          // sorusunun cevabı bandın alt satırında zaten bir cümleyle yazıyor; listeye ikinci
          // kez yazmak, dokunduğu şeyi ona bir daha anlatmaktı.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final k in liste)
                _GunSatiri(
                  kayit: k,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onGunSec(k.gun);
                  },
                ),
            ],
          );
        },
      ),
    );

class _GunSatiri extends StatelessWidget {
  const _GunSatiri({required this.kayit, required this.onTap});

  final KapanmamisGun kayit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.sm),
      child: SipDokun(
        onTap: onTap,
        zemin: t.bg,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gunTamBasligi(kayit.gun),
                    style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${kayit.teslimat} teslimat, ${sipTutar(kayit.kasaKurus)}',
                    style: SipText.metin(12).copyWith(color: t.ink2),
                  ),
                  // ENGEL SATIRDA YAZAR: kapatılamayan bir günü sessizce listede bırakmak,
                  // bayiyi "dokundum, kapat düğmesi yok" ile baş başa bırakırdı.
                  if (!kayit.kapatilabilir) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${kayit.acikSiparis} açık sipariş var',
                      style: SipText.metin(12, w: 700).copyWith(color: t.warn),
                    ),
                  ],
                ],
              ),
            ),
            SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2.2, renk: t.muted),
          ],
        ),
      ),
    );
  }
}
