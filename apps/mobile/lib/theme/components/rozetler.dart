// Sipario paylaşılan atomlar — ROZETLER, PİLLER, AVATAR, İKON KUTUSU.
// Kaynak CSS: `.pill`, `.mrow-bal`, `.mrow-av`, `.cagri-av`, `.bento-ikon`, `.akt-ic`, `.krow-ic`.

import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';
import 'bicim.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Rozetler
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// CSS `.pill` — küçük durum pili (Açık / Teslim / İptal).
class SipPil extends StatelessWidget {
  const SipPil({
    super.key,
    required this.etiket,
    required this.renk,
    required this.zemin,
  });

  final String etiket;
  final Color renk;
  final Color zemin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.brHap),
      child: Text(etiket, style: SipText.pil.copyWith(color: renk)),
    );
  }
}

/// Sipariş durumu pili — s-veri.jsx `SIP_DURUM` eşlemesi.
/// `acik` accent · `teslim` ok · `iptal` sönük.
class SipDurumPili extends StatelessWidget {
  const SipDurumPili({super.key, required this.durum});

  /// `open|delivered|cancelled` (DB) veya `acik|teslim|iptal` (tasarım) — ikisi de kabul edilir.
  final String durum;

  static ({String etiket, bool ok, bool iptal}) _coz(String d) => switch (d) {
        'delivered' || 'teslim' => (etiket: 'Teslim', ok: true, iptal: false),
        'cancelled' || 'iptal' => (etiket: 'İptal', ok: false, iptal: true),
        _ => (etiket: 'Açık', ok: false, iptal: false),
      };

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final d = _coz(durum);
    final renk = d.iptal ? t.muted : (d.ok ? t.ok : t.accent);
    final zemin = d.iptal ? t.line : (d.ok ? t.okSoft : t.accentSoft);
    return SipPil(etiket: d.etiket, renk: renk, zemin: zemin);
  }
}

/// CSS `.mrow-bal` — liste satırındaki bakiye çipi: renkli nokta + tutar.
/// Bakiye 0 ise hiç çizilmez (tasarımda temiz müşteride çip yok).
class SipBakiyeCipi extends StatelessWidget {
  const SipBakiyeCipi({super.key, required this.kurus, this.gizleSifir = true});

  final int kurus;
  final bool gizleSifir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    if (kurus == 0 && gizleSifir) return const SizedBox.shrink();
    final renk = t.bakiyeRenk(kurus);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        // CSS: color-mix(in srgb, currentColor 8%, transparent)
        color: renk.withValues(alpha: 0.08),
        borderRadius: SipRadius.brHap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            sipTutar(kurus.abs()),
            style: SipText.satirTutar.copyWith(color: renk),
          ),
        ],
      ),
    );
  }
}

/// CSS `.mrow-av` / `.cagri-av` — baş harf avatarı.
class SipAvatar extends StatelessWidget {
  const SipAvatar({
    super.key,
    required this.ad,
    this.cap = 38,
    this.radius = 12,
    this.zemin,
    this.renk,
    this.stil,
  });

  final String ad;
  final double cap;
  final double radius;
  final Color? zemin;
  final Color? renk;
  final TextStyle? stil;

  /// s-arayuz.jsx `Baş()` — ilk iki sözcüğün baş harfleri.
  static String basHarfler(String ad) {
    final p = ad.trim().split(RegExp(r'\s+'));
    final a = p.isNotEmpty && p[0].isNotEmpty ? p[0][0] : '';
    final b = p.length > 1 && p[1].isNotEmpty ? p[1][0] : '';
    return trBuyuk(a + b);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: cap,
      height: cap,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: zemin ?? t.accentSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        basHarfler(ad),
        style: (stil ?? SipText.avatar).copyWith(color: renk ?? t.accent),
      ),
    );
  }
}

/// CSS `.bento-ikon` / `.akt-ic` / `.krow-ic` — yuvarlak ikon kutusu.
class SipIkonKutu extends StatelessWidget {
  const SipIkonKutu({
    super.key,
    required this.ikon,
    this.cap = 38,
    this.ikonBoyut = 18,
    this.kalinlik = 2,
    this.zemin,
    this.renk,
    this.radius,
  });

  final String ikon;
  final double cap;
  final double ikonBoyut;
  final double kalinlik;
  final Color? zemin;
  final Color? renk;

  /// Verilmezse tam yuvarlak.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: cap,
      height: cap,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: zemin ?? t.accentSoft,
        borderRadius: BorderRadius.circular(radius ?? SipRadius.hap),
      ),
      child: SipIcon(
        ikon,
        boyut: ikonBoyut,
        kalinlik: kalinlik,
        renk: renk ?? t.accent,
      ),
    );
  }
}

