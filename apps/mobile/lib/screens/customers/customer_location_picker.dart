// Adres → konum adayları (CSS `.aday-*`, `.md-konum`; kaynak s-musteriler.jsx `adresAdaylari`).
//
// Tasarımın kuralı: konum adresten OTOMATİK atanmaz. Servis birden çok aday döner, doğrusunu
// KULLANICI seçer — yanlış algılanan bir adres yüzünden kurye yanlış kapıya gitmesin.
// Aşağıdaki [adresAdaylari] bir YER TUTUCU'dur (tasarımdaki mock'un birebir karşılığı); gerçek
// coğrafi kodlama servisi geldiğinde yalnız bu fonksiyon değişir, ekranlar aynı kalır.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Bir adres metni için önerilen konum. Koordinat GÖSTERİMİ daima 4 basamak (tasarım).
class AdresAdayi {
  const AdresAdayi({required this.metin, required this.lat, required this.lng});

  final String metin;
  final double lat;
  final double lng;

  String get koordinat => konumMetni(lat, lng);
}

/// "36.8969, 30.7133" — hem aday satırında hem `.md-konum` çipinde aynı yazım.
String konumMetni(double lat, double lng) =>
    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

/// Adres metninden aday üretir (yer tutucu servis — s-musteriler.jsx `adresAdaylari`).
List<AdresAdayi> adresAdaylari(String metin, String? bolge) {
  final b = (bolge == null || bolge.trim().isEmpty) ? 'Muratpaşa' : bolge.trim();
  final m = metin.trim();
  if (m.isEmpty) return const [];
  final sokak = m.replaceAll(RegExp(r'no:?\s*\d+.*', caseSensitive: false), '').trim()
      .replaceAll(RegExp(r',$'), '');
  return [
    AdresAdayi(metin: '$m, $b / Antalya', lat: 36.8969, lng: 30.7133),
    AdresAdayi(metin: '$sokak Sk., $b / Antalya', lat: 36.9014, lng: 30.7221),
    AdresAdayi(metin: '$m (yakın: $b Pazar Yeri), Antalya', lat: 36.8891, lng: 30.7042),
  ];
}

/// Adayları alttan açılan sayfada gösterir; kullanıcı birini seçerse onu döner.
Future<AdresAdayi?> konumSecSheet(BuildContext context, List<AdresAdayi> adaylar) {
  return sipSheet<AdresAdayi>(
    context,
    baslik: 'Konum Seç · API Sonuçları',
    govde: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdayBilgi(metin: 'Adres bazen yanlış algılanabilir — doğru olanı seçin.'),
        const SizedBox(height: SipSpace.xs),
        for (final a in adaylar)
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.sm),
            child: AdaySatiri(aday: a, onSec: () => Navigator.of(ctx).pop(a), okGoster: true),
          ),
      ],
    ),
  );
}

/// CSS `.aday-info` — aday listesinin üstündeki açıklama satırı.
class AdayBilgi extends StatelessWidget {
  const AdayBilgi({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SipIcon(SipIcons.info, boyut: 14, kalinlik: 2, renk: t.accent),
          const SizedBox(width: SipSpace.sm),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(11.5, w: 600).copyWith(color: t.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.aday-row` — ikon + adres + koordinat (+ opsiyonel sağ ok).
class AdaySatiri extends StatelessWidget {
  const AdaySatiri({
    super.key,
    required this.aday,
    required this.onSec,
    this.okGoster = false,
  });

  final AdresAdayi aday;
  final VoidCallback onSec;
  final bool okGoster;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokunAday(
      onTap: onSec,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.brHap),
            child: SipIcon(SipIcons.pin, boyut: 16, kalinlik: 2.1, renk: t.accent),
          ),
          const SizedBox(width: SipSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aday.metin,
                  style: SipText.metin(13, w: 700, h: 1.35).copyWith(color: t.ink),
                ),
                const SizedBox(height: 1),
                Text(
                  aday.koordinat,
                  style: SipText.tutar(11, w: 600).copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          if (okGoster) ...[
            const SizedBox(width: SipSpace.md),
            SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2, renk: t.line2),
          ],
        ],
      ),
    );
  }
}

/// `.aday-row`un kenarlıklı yüzeyi — [SipDokun]a kenarlık + padding geçmenin kısayolu.
class SipDokunAday extends StatelessWidget {
  const SipDokunAday({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      basiliZemin: t.accentSoft,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: 11),
      kenarlik: Border.all(color: t.line, width: 1.5),
      child: child,
    );
  }
}
