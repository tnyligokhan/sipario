// ALT TOPLAM ÇUBUĞU ve uyarı şeridi — CSS `.ys-alt`, `.ys-toplam`, `.ys-uyari`.
// Kaynak: Sipario.html 259–331 + s-siparisler.jsx.
//
// NEDEN AYRI DOSYA: `order_parts.dart` 582 satıra çıkmıştı (500 satır kuralı). Çubuk ekranın
// SABİT alt katmanıdır — sepet satırıyla hiçbir şey paylaşmaz, kendi ölçüleri ve kendi
// animasyonu (`SarsintiKutusu`) vardır. `order_parts.dart` bu dosyayı yeniden dışa aktarır:
// çağıranlar tek import ile erişmeye devam eder.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class YsAltCubugu extends StatelessWidget {
  const YsAltCubugu({
    super.key,
    required this.toplamKurus,
    required this.buton,
    this.uyari,
    this.uyariAnahtar = '',
    this.yanEylem,
  });

  final int toplamKurus;
  final Widget buton;

  /// CSS `.ys-uyari` — sarsıntı animasyonlu kırmızı şerit.
  final String? uyari;

  /// Sarsıntıyı yeniden tetikleyen anahtar: AYNI uyarı tekrar gösterilse de değeri değişirse
  /// animasyon baştan oynar (kullanıcı ikinci kez bastığını görsün).
  final String uyariAnahtar;

  /// Birincil düğmenin SOLUNDA, onunla aynı satırda duran ikincil eylem (özet adımında kurye
  /// çipi). Verilirse toplam KENDİ SATIRINA çıkar — üç şeyi tek satıra sığdırmak, en dar
  /// telefonda ya tutarı ya düğmeyi kırpardı.
  ///
  /// CSS'te bunun karşılığı zaten var: `.ys-alt` sarmalı (`flex-wrap`) açık ve `.ys-uyari`
  /// `flex-basis: 100%` ile tam satır kaplıyor (_sayfa.html:524,699) — yani çubuk çok satırlı
  /// olacak şekilde tasarlanmış.
  final Widget? yanEylem;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      margin: const EdgeInsets.fromLTRB(SipSpace.x3, SipSpace.lg, SipSpace.x3, SipSpace.x5),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: SipRadius.br3,
        // CSS `box-shadow: 0 16px 34px -20px rgba(23,20,31,.4)` (_sayfa.html:524). Negatif
        // yayılma → Flutter'da spreadRadius negatif; çubuk sayfadan kalkık dursun.
        boxShadow: const [
          BoxShadow(
            color: Color(0x6617141F),
            offset: Offset(0, 16),
            blurRadius: 34,
            spreadRadius: -20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (uyari != null) ...[
            SarsintiKutusu(
              anahtar: '$uyariAnahtar|${uyari!}',
              child: _UyariSeridi(metin: uyari!),
            ),
            const SizedBox(height: SipSpace.lg),
          ],
          if (yanEylem == null)
            // Tek eylem: toplam solda dikey (etiket üstte), düğme sağda — CSS `.ys-toplam`.
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TOPLAM',
                          style: SipText.metin(10.5, w: 700).copyWith(color: t.muted)),
                      Text(sipTutar(toplamKurus),
                          style: SipText.tutar21.copyWith(color: t.ink)),
                    ],
                  ),
                ),
                const SizedBox(width: SipSpace.lg),
                buton,
              ],
            )
          else ...[
            // İki eylem: toplam tam satır (etiket sol, tutar sağ — fişteki gibi), eylemler alt
            // satırda yan yana. Aynı `.ys-toplam` puntoları, yalnız ekseni yatay.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text('TOPLAM',
                      style: SipText.metin(10.5, w: 700).copyWith(color: t.muted)),
                ),
                const SizedBox(width: SipSpace.lg),
                Text(sipTutar(toplamKurus), style: SipText.tutar21.copyWith(color: t.ink)),
              ],
            ),
            const SizedBox(height: SipSpace.xl),
            Row(
              children: [
                Expanded(child: yanEylem!),
                const SizedBox(width: SipSpace.lg),
                buton,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UyariSeridi extends StatelessWidget {
  const _UyariSeridi({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.dangerSoft, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          SipIcon(SipIcons.alert, boyut: 15, kalinlik: 2.2, renk: t.danger),
          const SizedBox(width: 7),
          Expanded(
            child: Text(metin, style: SipText.metin(12.5, w: 700).copyWith(color: t.danger)),
          ),
        ],
      ),
    );
  }
}

/// CSS `@keyframes sshake` — 0,34 sn yatay sarsıntı. [anahtar] değişince yeniden oynar.
class SarsintiKutusu extends StatelessWidget {
  const SarsintiKutusu({super.key, required this.anahtar, required this.child});

  final String anahtar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(anahtar),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      builder: (context, v, ic) {
        // Sönümlenen sinüs — CSS'teki 4 adımlı ±5px sarsıntının sürekli karşılığı.
        final kayma = (1 - v) * 5 * math.sin(v * 12);
        return Transform.translate(offset: Offset(kayma, 0), child: ic);
      },
      child: child,
    );
  }
}
