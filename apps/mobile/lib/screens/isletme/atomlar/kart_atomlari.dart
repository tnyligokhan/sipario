// İŞLETME ekran ailesinin KART ve ALT ÇUBUK parçaları.
// Kaynak CSS: tasarım Sipario.html — her bileşenin başında sınıf adı yazılıdır.
// Barrel: `../isletme_atomlari.dart` (ekranlar oradan import eder).

import 'package:flutter/material.dart';

import '../../../theme/components/atoms.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CSS `.gs-kasa` / `.gs-krow` — ayraçlı değer satırları taşıyan kart
// ═══════════════════════════════════════════════════════════════════════════════════════════

class DegerKarti extends StatelessWidget {
  const DegerKarti({super.key, required this.satirlar});

  final List<Widget> satirlar;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x3),
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      child: Column(
        children: [
          for (var i = 0; i < satirlar.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == satirlar.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: t.line)),
              ),
              child: satirlar[i],
            ),
        ],
      ),
    );
  }
}

/// CSS `.gs-krow` (+ `.toplam` varyantı).
class DegerSatiri extends StatelessWidget {
  const DegerSatiri({
    super.key,
    required this.etiket,
    required this.deger,
    this.toplam = false,
    this.degerRengi,
    this.onTap,
    this.gecersiz = false,
  });

  final String etiket;
  final String deger;

  /// CSS `.gs-krow.toplam` — etiket koyulaşır, değer 15.5 ve accent olur.
  final bool toplam;

  final Color? degerRengi;

  /// Satır ARTIK GEÇERLİ DEĞİL (iptal edilmiş ara tahsilat, 2026-08-13): tutar ÜSTÜ ÇİZİLİ ve
  /// solgun çizilir, etiket de solar.
  ///
  /// NEDEN SATIR SİLİNMİYOR: para kayıtları silinmez (BRIEF kırmızı çizgi #2) — olay olmuştur ve
  /// kanıtı görünür kalmalıdır. Üstü çizili tutar, "bu rakam toplamın içinde değil" cümlesini
  /// ikinci bir açıklama satırı açmadan söyler; solgunluk tek başına yeterli DEĞİLDİ, çünkü
  /// solgun bir para rakamı "ikincil bilgi" diye de okunabilir ve bayi onu toplama katardı.
  ///
  /// [degerRengi] ile birlikte kullanılırsa geçersizlik KAZANIR: iptal edilmiş bir tutarı
  /// kırmızı/vurgulu çizmek, geri alınmış bir parayı hâlâ bir iddia gibi gösterirdi.
  final bool gecersiz;

  /// Verilirse satır DOKUNULABİLİR olur ve sağına chevron çizilir (kullanıcı isteği
  /// 2026-08-11: ödeme türüne dokununca o günün dökümü açılır).
  ///
  /// CHEVRON KOŞULSUZ DEĞİL: dokunulamayan satırda çizilseydi bayi her rakamın altında bir
  /// döküm arar, bulamayınca satırın bozuk olduğunu sanırdı. Görünen işaret, var olan
  /// davranışın karşılığıdır.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final govde = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiket,
              style: SipText.gsSatirEtiket.copyWith(
                color: gecersiz ? t.muted : (toplam ? t.ink : t.ink2),
                fontWeight: toplam ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: SipSpace.lg),
          Text(
            deger,
            style: (toplam ? SipText.gsToplamDeger : SipText.gsSatirDeger).copyWith(
              color: gecersiz ? t.muted : (degerRengi ?? (toplam ? t.accent : t.ink)),
              decoration: gecersiz ? TextDecoration.lineThrough : null,
              decorationColor: gecersiz ? t.muted : null,
              decorationThickness: gecersiz ? 1.6 : null,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            SipIcon(SipIcons.right, boyut: 13, kalinlik: 2.2, renk: t.muted),
          ],
        ],
      ),
    );

    if (onTap == null) return govde;
    return SipDokun(onTap: onTap, radius: SipRadius.br1, child: govde);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CSS `.ayar-kart` / `.ayar-row` — ikon + başlık + alt açıklama + chevron/toggle
// ═══════════════════════════════════════════════════════════════════════════════════════════

class AyarKarti extends StatelessWidget {
  const AyarKarti({super.key, required this.satirlar});

  final List<Widget> satirlar;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: SipSpace.xs),
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br3),
      child: Column(
        children: [
          for (var i = 0; i < satirlar.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == satirlar.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: t.line)),
              ),
              child: satirlar[i],
            ),
        ],
      ),
    );
  }
}

class AyarSatiri extends StatelessWidget {
  const AyarSatiri({
    super.key,
    required this.baslik,
    this.altBaslik,
    this.ikon,
    this.onTap,
    this.sag,
  });

  final String baslik;
  final String? altBaslik;

  /// [SipIcons] anahtarı; verilmezse ikon kutusu çizilmez (CSS `.ayar-row.salt` sürümü).
  final String? ikon;

  final VoidCallback? onTap;

  /// Sağdaki öğe; verilmezse [onTap] varken chevron çizilir.
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: 13),
      child: Row(
        children: [
          if (ikon != null) ...[
            SipIkonKutu(ikon: ikon!, cap: 34, ikonBoyut: 18, kalinlik: 1.9),
            const SizedBox(width: SipSpace.xl),
          ] else
            const SizedBox(width: SipSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  baslik,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                ),
                if (altBaslik != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      altBaslik!,
                      style: SipText.yardimci.copyWith(color: t.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.lg),
          sag ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : SipIcon(SipIcons.chevR, boyut: 17, kalinlik: 2, renk: t.line2)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CSS `.ys-alt` — ekranın altına sabitlenen eylem çubuğu
// ═══════════════════════════════════════════════════════════════════════════════════════════

class AltCubuk extends StatelessWidget {
  const AltCubuk({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.x3, SipSpace.lg, SipSpace.x3, SipSpace.x5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: SipRadius.br3,
          border: Border.all(color: t.line),
        ),
        child: Wrap(
          spacing: SipSpace.lg,
          runSpacing: SipSpace.lg,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

/// CSS `.ys-toplam` — alt çubuğun sol tarafındaki "etiket + iri tutar" bloğu.
class AltCubukToplam extends StatelessWidget {
  const AltCubukToplam({super.key, required this.etiket, required this.deger});

  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          trBuyuk(etiket),
          style: SipText.metin(10.5, w: 700).copyWith(color: t.muted, letterSpacing: 0.63),
        ),
        Text(deger, style: SipText.tutar21.copyWith(color: t.ink)),
      ],
    );
  }
}
