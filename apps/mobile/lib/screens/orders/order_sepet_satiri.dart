// SEPET SATIRI ve adet stepper'ı — CSS `.ys-satir`, `.ys-stepper`, `.ys-sil`.
// Kaynak: Sipario.html 259–331 + s-siparisler.jsx.
//
// NEDEN AYRI DOSYA: `order_parts.dart` 582 satıra çıkmıştı (500 satır kuralı). Sepet satırı kendi
// içinde kapalı bir parçadır — yeni sipariş formu, düzenleme sheet'i ve serbest satır sheet'i onu
// aynı imzayla çizer; dosyadaki başka hiçbir parçayı çağırmaz, çağıran da olmaz.
// `order_parts.dart` bu dosyayı yeniden dışa aktarır: çağıranlar tek import ile erişmeye devam eder.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'satir_notu.dart';

class YsSatiri extends StatelessWidget {
  const YsSatiri({
    super.key,
    required this.ad,
    required this.altMetin,
    required this.tutarKurus,
    this.adet,
    this.onAzalt,
    this.onArtir,
    this.onSil,
    this.zemin,
    this.not,
    this.onNot,
  });

  final String ad;

  /// CSS `.ys-birim` — birim adı ya da serbest satırda "tek seferlik".
  final String altMetin;

  final int tutarKurus;

  /// null ise stepper çizilmez (serbest satır) ve yerine [onSil] düğmesi gelir.
  final int? adet;
  final VoidCallback? onAzalt;
  final VoidCallback? onArtir;
  final VoidCallback? onSil;
  final Color? zemin;

  /// SATIR NOTU — doluysa rozet çizilir. [onNot] verilmezse not yüzeyi salt-okunurdur.
  final String? not;
  final VoidCallback? onNot;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 11),
      decoration: BoxDecoration(color: zemin ?? t.surface, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad,
                    style: SipText.metin(13.5, w: 600).copyWith(color: t.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                // Birim ve not AYNI SATIRDA. Not yüzeyi eskiden alta üçüncü bir satır açıyordu:
                // sepetteki her kalem 3 satır yer kaplıyor, dört kalemlik bir sipariş ekranı
                // taşırıyordu. İkisi de kalemin "künyesi" — yan yana okunurlar.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(altMetin,
                        style: SipText.metin(10.5, w: 500).copyWith(color: t.muted)),
                    if (not != null || onNot != null) ...[
                      const SizedBox(width: SipSpace.lg),
                      Flexible(child: SatirNotuYuzeyi(not: not, onTap: onNot)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.lg),
          if (adet != null)
            YsStepper(adet: adet!, onAzalt: onAzalt, onArtir: onArtir)
          else if (onSil != null)
            SipIkonButon(
              ikon: SipIcons.x,
              cap: 30,
              ikonBoyut: 16,
              kalinlik: 2.2,
              renk: t.muted,
              etiket: 'Satırı sil',
              onTap: onSil,
            ),
          const SizedBox(width: SipSpace.lg),
          SizedBox(
            // CSS `.ys-satir-tt { min-width: 66px }` (_sayfa.html:521).
            width: 66,
            child: Text(
              sipTutar(tutarKurus),
              textAlign: TextAlign.right,
              style: SipText.tutar(13).copyWith(color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.ys-stepper` — hap ray + iki 28'lik yuvarlak düğme. Adet 1 iken azaltma düğmesi
/// tasarımdaki gibi KIRMIZI ÇARPI olur (bir daha basınca satır silinir).
class YsStepper extends StatelessWidget {
  const YsStepper({super.key, required this.adet, this.onAzalt, this.onArtir});

  final int adet;
  final VoidCallback? onAzalt;
  final VoidCallback? onArtir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final sonSatir = adet <= 1;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.brHap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Yuvarlak(
            ikon: sonSatir ? SipIcons.x : SipIcons.down,
            renk: sonSatir ? t.danger : t.ink,
            etiket: sonSatir ? 'Satırı sil' : 'Azalt',
            onTap: onAzalt,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SipSpace.md),
            child: SizedBox(
              width: 18,
              child: Text('$adet',
                  textAlign: TextAlign.center,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink)),
            ),
          ),
          _Yuvarlak(
            ikon: SipIcons.plus,
            renk: t.ink,
            etiket: 'Artır',
            onTap: onArtir,
          ),
        ],
      ),
    );
  }
}

class _Yuvarlak extends StatelessWidget {
  const _Yuvarlak({required this.ikon, required this.renk, required this.etiket, this.onTap});

  final String ikon;
  final Color renk;
  final String etiket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: etiket,
      child: SipDokun(
        onTap: onTap,
        zemin: t.knob,
        basiliZemin: t.line,
        radius: SipRadius.brHap,
        child: SizedBox.square(
          dimension: 28,
          child: Center(child: SipIcon(ikon, boyut: 14, kalinlik: 2.6, renk: renk)),
        ),
      ),
    );
  }
}
