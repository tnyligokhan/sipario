// MESAJ METNİ ARAÇ ÇUBUĞU VE ÖNİZLEME (kullanıcı isteği 2026-11-06, 1.17.0).
//
// Bayi WhatsApp'ın işaretlerini ezberlemez: metni seçer, düğmeye dokunur. Önizleme müşterinin
// göreceği biçimi gösterir. Kurallar `data/whatsapp_metni.dart`ta, burada yalnız çizim vardır.

import 'package:flutter/material.dart';

import '../../data/whatsapp_metni.dart';
import '../../theme/components/atoms.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Biçim düğmeleri. Düğmenin etiketi kendi biçimiyle yazılır: bayi ne yaptığını okumadan görür.
class WhatsappBicimCubugu extends StatelessWidget {
  const WhatsappBicimCubugu({super.key, required this.controller, this.onDegis});

  final TextEditingController controller;
  final VoidCallback? onDegis;

  void _uygula(TextEditingValue Function(WhatsappDuzenleyici d) islem) {
    controller.value = islem(WhatsappDuzenleyici(controller.value));
    onDegis?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.md),
      child: Wrap(
        spacing: SipSpace.sm,
        runSpacing: SipSpace.sm,
        children: [
          for (final b in WhatsappBicim.values)
            _BicimDugmesi(
              etiket: b.etiket,
              stil: WhatsappMetinStili.uygula(const TextStyle(), {b}),
              onTap: () => _uygula((d) => d.bicimle(b)),
            ),
          for (final b in WhatsappSatirBicimi.values)
            _BicimDugmesi(etiket: b.etiket, onTap: () => _uygula((d) => d.satirBicimle(b))),
        ],
      ),
    );
  }
}

class _BicimDugmesi extends StatelessWidget {
  const _BicimDugmesi({required this.etiket, required this.onTap, this.stil});

  final String etiket;
  final VoidCallback onTap;
  final TextStyle? stil;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      child: SipDokun(
        onTap: onTap,
        zemin: t.surface2,
        basiliZemin: t.line,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          etiket,
          style: SipText.metin(12, w: 600).copyWith(color: t.ink2).merge(stil),
        ),
      ),
    );
  }
}

/// Biçim kümesinin metin stiline karşılığı.
abstract final class WhatsappMetinStili {
  static TextStyle uygula(TextStyle taban, Set<WhatsappBicim> bicimler) => taban.copyWith(
        fontWeight: bicimler.contains(WhatsappBicim.kalin) ? FontWeight.w800 : null,
        fontStyle: bicimler.contains(WhatsappBicim.italik) ? FontStyle.italic : null,
        decoration:
            bicimler.contains(WhatsappBicim.ustuCizili) ? TextDecoration.lineThrough : null,
        fontFamily: bicimler.contains(WhatsappBicim.tekAralikli) ? 'monospace' : null,
      );
}

/// [metin]i müşterinin WhatsApp'ta göreceği biçimde çizer. Metin yer tutucuları çözülmüş olmalı.
class WhatsappOnizleme extends StatelessWidget {
  const WhatsappOnizleme({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final taban = SipText.metin(13.5, w: 500, h: 1.45).copyWith(color: t.ink);
    return Container(
      padding: const EdgeInsets.all(SipSpace.xl),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final satir in WhatsappSatiri.ayir(metin)) _satir(t, taban, satir),
        ],
      ),
    );
  }

  Widget _satir(SipTokens t, TextStyle taban, WhatsappSatiri satir) {
    final yazi = Text.rich(TextSpan(
      style: taban,
      children: [
        if (satir.onek.isNotEmpty) TextSpan(text: satir.onek),
        for (final p in satir.parcalar)
          TextSpan(text: p.metin, style: WhatsappMetinStili.uygula(taban, p.bicimler)),
      ],
    ));
    if (satir.tur != WhatsappSatirBicimi.alinti) return yazi;
    return Container(
      padding: const EdgeInsets.only(left: SipSpace.md),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: t.line2, width: 3))),
      child: yazi,
    );
  }
}
