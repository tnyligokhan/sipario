// Sipario paylaşılan atomlar — DOKUNMA YÜZEYİ VE DÜĞMELER.
// Kaynak CSS: `:active` durumları, `.btn`, `.btn-p`, `.btn-s`, `.btn-d`, `.ust-metin`, `.ust-ikon`.

import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Basılabilir yüzey — CSS `:active { background: var(--surface-2) }` davranışı
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Tasarımdaki kart/satır dokunma geri bildirimi: Material dalgası DEĞİL, zeminin bir ton
/// koyulaşması. [InkWell] yerine bu kullanılır — tasarımda hiçbir yerde ripple yok.
class SipDokun extends StatefulWidget {
  const SipDokun({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.zemin,
    this.basiliZemin,
    this.radius = SipRadius.br2,
    this.padding,
    this.kenarlik,
    this.olcekle = false,
    this.basiliOlcek = 0.98,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Normal zemin. Verilmezse saydam.
  final Color? zemin;

  /// Basılıyken zemin. Verilmezse `surface2`.
  final Color? basiliZemin;

  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? kenarlik;

  /// CSS `:active { transform: scale(...) }` olan öğeler için (FAB, stepper, pos-tile).
  final bool olcekle;

  /// [olcekle] açıkken basılı ölçek. Tasarımda tek bir değer YOKTUR, öğeye göre değişir:
  /// `.btn` .98 · `.pos-tile` .97 · `.pos-stepper button` .95 · `.altnav-fab`/`.pos-barkod` .94.
  /// Varsayılan en yaygın olan `.btn` değeridir; farklı olan çağrı yeri kendi ölçeğini verir.
  final double basiliOlcek;

  @override
  State<SipDokun> createState() => _SipDokunState();
}

class _SipDokunState extends State<SipDokun> {
  bool _basili = false;

  void _ayarla(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_basili != v) setState(() => _basili = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final aktif = widget.onTap != null || widget.onLongPress != null;
    final zemin = _basili && aktif
        ? (widget.basiliZemin ?? t.surface2)
        : (widget.zemin ?? Colors.transparent);

    Widget govde = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: widget.radius,
        border: widget.kenarlik,
      ),
      child: widget.child,
    );

    if (widget.olcekle) {
      govde = AnimatedScale(
        scale: _basili && aktif ? widget.basiliOlcek : 1,
        duration: const Duration(milliseconds: 70),
        child: govde,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _ayarla(true),
      onTapUp: (_) => _ayarla(false),
      onTapCancel: () => _ayarla(false),
      child: govde,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Düğmeler — CSS `.btn`, `.btn-p`, `.btn-s`, `.btn-d`
// ═══════════════════════════════════════════════════════════════════════════════════════════

enum SipButonTuru {
  /// `.btn-p` — accent dolgu.
  birincil,

  /// `.btn-s` — surface-2 dolgu.
  ikincil,

  /// `.btn-d` — danger dolgu.
  tehlike,
}

/// CSS `filter: brightness(k)` karşılığı — RGB kanallarını [k] ile çarpar. Siyaha doğru
/// `1 - k` oranında karıştırmak kanalları tam olarak [k] ile çarpmaya denktir.
Color _parlaklik(Color c, double k) => Color.lerp(c, const Color(0xFF000000), 1 - k)!;

/// CSS `.btn` — 48 yüksek, r2 köşe, gölgesiz, basılıyken hafif küçülür.
class SipButon extends StatelessWidget {
  const SipButon({
    super.key,
    required this.etiket,
    this.onTap,
    this.tur = SipButonTuru.birincil,
    this.ikon,
    this.yukseklik = 48,
    this.genisle = true,
    this.yatayPadding,
    this.yukleniyor = false,
  });

  final String etiket;
  final VoidCallback? onTap;
  final SipButonTuru tur;

  /// [SipIcons] anahtarı.
  final String? ikon;

  final double yukseklik;

  /// `true` ise satırı doldurur (CSS `width: 100%`).
  final bool genisle;

  /// `genisle: false` iken yanlardan iç boşluk (CSS `padding: 0 22px`).
  final double? yatayPadding;

  final bool yukleniyor;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final pasif = onTap == null || yukleniyor;

    final (Color zemin, Color murekkep) = switch (tur) {
      SipButonTuru.birincil => (
          pasif ? t.disabledFill : t.accent,
          pasif ? t.disabledInk : t.accentInk
        ),
      SipButonTuru.ikincil => (t.surface2, pasif ? t.muted : t.ink),
      SipButonTuru.tehlike => (
          pasif ? t.disabledFill : t.danger,
          const Color(0xFFFFFFFF)
        ),
    };

    final icerik = yukleniyor
        ? SizedBox.square(
            dimension: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(murekkep),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (ikon != null) ...[
                SipIcon(ikon!, boyut: 18, kalinlik: 2, renk: murekkep),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  etiket,
                  style: SipText.buton.copyWith(color: murekkep),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    // CSS `.btn-p:active { filter: brightness(.92) }` — bu filtre YALNIZ birincil düğmede var;
    // `.btn-s` / `.btn-d` basılıyken sadece küçülür, zemini değişmez.
    final basiliZemin = tur == SipButonTuru.birincil ? _parlaklik(zemin, 0.92) : zemin;

    return SipDokun(
      onTap: pasif ? null : onTap,
      zemin: zemin,
      basiliZemin: basiliZemin,
      radius: SipRadius.br2,
      olcekle: true,
      child: SizedBox(
        height: yukseklik,
        width: genisle ? double.infinity : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: genisle ? 0 : (yatayPadding ?? 22)),
          child: Center(child: icerik),
        ),
      ),
    );
  }
}

/// CSS `.ust-metin` / `.sdx-link` — hap biçimli, yüzey zeminli küçük metin düğmesi.
class SipMetinButon extends StatelessWidget {
  const SipMetinButon({
    super.key,
    required this.etiket,
    this.onTap,
    this.ikon,
    this.zemin,
    this.renk,
  });

  final String etiket;
  final VoidCallback? onTap;
  final String? ikon;
  final Color? zemin;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final c = renk ?? t.accent;
    return SipDokun(
      onTap: onTap,
      zemin: zemin ?? t.surface,
      radius: SipRadius.brHap,
      padding: EdgeInsets.symmetric(
        horizontal: ikon == null ? 13 : 14,
        vertical: ikon == null ? 8 : 9,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[
            SipIcon(ikon!, boyut: 15, kalinlik: 2, renk: c),
            const SizedBox(width: 6),
          ],
          Text(etiket, style: SipText.ustMetin.copyWith(color: c)),
        ],
      ),
    );
  }
}

/// CSS `.ust-ikon` / `.sheet-x` / `.cek-x` — yuvarlak ikon düğmesi.
class SipIkonButon extends StatelessWidget {
  const SipIkonButon({
    super.key,
    required this.ikon,
    this.onTap,
    this.cap = 38,
    this.ikonBoyut = 22,
    this.kalinlik = 2.1,
    this.zemin,
    this.renk,
    this.etiket,
  });

  final String ikon;
  final VoidCallback? onTap;
  final double cap;
  final double ikonBoyut;
  final double kalinlik;
  final Color? zemin;
  final Color? renk;

  /// Erişilebilirlik etiketi (CSS `aria-label`).
  final String? etiket;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: etiket,
      child: SipDokun(
        onTap: onTap,
        zemin: zemin ?? t.surface,
        radius: SipRadius.brHap,
        child: SizedBox.square(
          dimension: cap,
          child: Center(
            child: SipIcon(
              ikon,
              boyut: ikonBoyut,
              kalinlik: kalinlik,
              renk: renk ?? t.ink,
            ),
          ),
        ),
      ),
    );
  }
}

