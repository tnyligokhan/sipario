// Sipario paylaşılan atomlar — YERLEŞİM SARMALAYICILARI.
// Kaynak CSS: `.ayar-kart`, `.gs-kasa`, `.ana-baslik`, `.md-baslik`, `.gs-baslik`, `.sdx-sec`,
// `.md-not`, `.srow-not`.

import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Kart ve bölüm sarmalayıcıları
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// CSS `.ayar-kart` / `.gs-kasa` — içinde ayraçlı satırlar taşıyan yüzey kartı.
class SipKart extends StatelessWidget {
  const SipKart({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: SipSpace.x3),
    this.radius = SipRadius.br2,
    this.zemin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final Color? zemin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: zemin ?? context.sip.surface,
        borderRadius: radius,
      ),
      child: child,
    );
  }
}

/// CSS `.ana-baslik` / `.md-baslik` / `.gs-baslik` — liste üstü bölüm başlığı.
class SipBolumBaslik extends StatelessWidget {
  const SipBolumBaslik(
    this.metin, {
    super.key,
    this.sag,
    this.ustBosluk = 20,
    this.altBosluk = 8,
  });

  final String metin;

  /// Sağdaki metin bağlantısı (CSS `.sdx-sec` içindeki `.sdx-link`).
  final Widget? sag;

  final double ustBosluk;
  final double altBosluk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, ustBosluk, 2, altBosluk),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              metin,
              style: SipText.bolumBaslik.copyWith(color: context.sip.ink),
            ),
          ),
          ?sag,
        ],
      ),
    );
  }
}

/// CSS `.md-not` / `.srow-not` — sarı zeminli not/uyarı kutusu.
class SipNotKutusu extends StatelessWidget {
  const SipNotKutusu({
    super.key,
    required this.metin,
    this.ikon = SipIcons.info,
    this.tur = SipNotTuru.uyari,
    this.onEtiket,
  });

  final String metin;
  final String ikon;
  final SipNotTuru tur;

  /// Metnin başına kalın olarak eklenecek etiket (CSS `.srow-not b`).
  final String? onEtiket;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final (zemin, renk) = switch (tur) {
      SipNotTuru.uyari => (t.warnSoft, t.warn),
      SipNotTuru.bilgi => (t.accentSoft, t.accent),
      SipNotTuru.hata => (t.dangerSoft, t.danger),
      SipNotTuru.basari => (t.okSoft, t.ok),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.br2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(ikon, boyut: 16, kalinlik: 2, renk: renk),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (onEtiket != null)
                    TextSpan(
                      text: '$onEtiket ',
                      style: SipText.not.copyWith(
                        color: renk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  TextSpan(text: metin),
                ],
              ),
              style: SipText.not.copyWith(
                color: tur == SipNotTuru.uyari ? t.ink2 : renk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum SipNotTuru { uyari, bilgi, hata, basari }

