// Kurulum sihirbazının paylaşılan parçaları — Sipario.html `.siz-*` ve `.izb-*`.
// Ekranın kendisi izin_sihirbazi.dart'ta; burası yalnız görsel yapı taşları (500 satır sınırı).

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// CSS `.siz-ilerle` — üstte 4px ilerleme çubuğu (bar accent, ray surface-2).
class SihirbazIlerleme extends StatelessWidget {
  const SihirbazIlerleme({super.key, required this.oran});

  /// 0..1
  final double oran;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      label: 'Kurulum ilerlemesi',
      value: '%${(oran * 100).round()}',
      child: SizedBox(
        height: 4,
        child: LayoutBuilder(
          builder: (context, kutu) => Stack(
            children: [
              Container(color: t.surface2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: const Cubic(0.2, 0.8, 0.2, 1),
                width: kutu.maxWidth * oran.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(SipRadius.hap),
                    bottomRight: Radius.circular(SipRadius.hap),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CSS `.siz-logo` renk varyantları.
enum SihirbazLogoTuru { marka, basari, hata }

/// CSS `.siz-logo` — 66'lık yuvarlatılmış kare. [nabiz] true iken `.calis` animasyonu.
class SihirbazLogo extends StatefulWidget {
  const SihirbazLogo({
    super.key,
    required this.ikon,
    this.tur = SihirbazLogoTuru.marka,
    this.nabiz = false,
  });

  final String ikon;
  final SihirbazLogoTuru tur;
  final bool nabiz;

  @override
  State<SihirbazLogo> createState() => _SihirbazLogoState();
}

class _SihirbazLogoState extends State<SihirbazLogo>
    with SingleTickerProviderStateMixin {
  // `late final … = ifade` YAZILMAZ: nabız kapalıyken hiçbir yol denetleyiciye dokunmaz ve
  // tembel başlatıcı ilk kez dispose() içinde koşar — o anda element deaktive olduğundan
  // SingleTickerProviderStateMixin'in TickerMode araması patlar. Kurulum initState'te yapılır.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    if (widget.nabiz) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant SihirbazLogo eski) {
    super.didUpdateWidget(eski);
    if (widget.nabiz && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.nabiz && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final (zemin, murekkep) = switch (widget.tur) {
      SihirbazLogoTuru.marka => (t.accent, t.accentInk),
      // Durum dolgusunun mürekkebi temaya bağlıdır: açıkta beyaz, koyuda koyu (bkz. durumInk).
      SihirbazLogoTuru.basari => (t.ok, t.durumInk),
      SihirbazLogoTuru.hata => (t.danger, t.durumInk),
    };
    final kutu = Container(
      width: 66,
      height: 66,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(21)),
      child: SipIcon(widget.ikon, boyut: 34, kalinlik: 2.1, renk: murekkep),
    );
    if (!widget.nabiz) return kutu;
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.06).animate(_c),
      child: kutu,
    );
  }
}

/// CSS `.izb-ic` — izin adımının 70'lik yuvarlak ikonu; verilmişse dolu yeşil.
class IzinIkonu extends StatelessWidget {
  const IzinIkonu({super.key, required this.ikon, required this.verildi});

  final String ikon;
  final bool verildi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 70,
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: verildi ? t.ok : t.accentSoft,
        shape: BoxShape.circle,
      ),
      child: SipIcon(
        verildi ? SipIcons.check : ikon,
        boyut: 40,
        kalinlik: 1.9,
        renk: verildi ? t.durumInk : t.accent,
      ),
    );
  }
}

/// CSS `.siz-h1`.
class SihirbazBaslik extends StatelessWidget {
  const SihirbazBaslik(this.metin, {super.key});

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: SipSpace.x4),
        child: Text(
          metin,
          style: SipText.sihirbazBaslik.copyWith(color: context.sip.ink),
          textAlign: TextAlign.center,
        ),
      );
}

/// CSS `.siz-p` — açıklama paragrafı (max 34ch).
class SihirbazMetin extends StatelessWidget {
  const SihirbazMetin(this.metin, {super.key});

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: SipSpace.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            metin,
            style: SipText.sihirbazMetin.copyWith(color: context.sip.ink2),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

/// CSS `.izb-zorunlu` / `.izb-verildi` / `.siz-guven` — hap rozet.
class SihirbazRozet extends StatelessWidget {
  const SihirbazRozet({
    super.key,
    required this.etiket,
    required this.renk,
    required this.zemin,
    this.ikon,
    this.buyukHarf = false,
    this.ustBosluk = SipSpace.md,
  });

  final String etiket;
  final Color renk;
  final Color zemin;
  final String? ikon;
  final bool buyukHarf;
  final double ustBosluk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: ustBosluk),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ikon == null ? 10 : SipSpace.x2,
          vertical: ikon == null ? 3 : SipSpace.md,
        ),
        decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.brHap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              SipIcon(ikon!, boyut: 15, kalinlik: 2.4, renk: renk),
              const SizedBox(width: 7),
            ],
            Text(
              buyukHarf ? trBuyuk(etiket) : etiket,
              style: (buyukHarf ? SipText.izinZorunlu : SipText.izinDurum)
                  .copyWith(color: renk),
            ),
          ],
        ),
      ),
    );
  }
}

// `SihirbazNot` (CSS `.siz-not` madde kutusu) KALDIRILDI: tasarımın hiçbir ekranı kullanmıyor
// (`.siz-not` CSS'te tanımlı ama ölü) ve tek tüketicisi olan MIUI/pil "maddeler" listesi de
// adım tanımından çıktı — izin gerekçesi tek cümledir.

/// CSS `.siz-atla-btn` — sönük düz metin düğmesi.
class SihirbazAtlaButonu extends StatelessWidget {
  const SihirbazAtlaButonu({super.key, required this.etiket, required this.onTap});

  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              etiket,
              style: SipText.metin(13, w: 600).copyWith(color: context.sip.muted),
            ),
          ),
        ),
      ),
    );
  }
}
