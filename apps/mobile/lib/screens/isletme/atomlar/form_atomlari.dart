// İŞLETME ekran ailesinin FORM ve LİSTE parçaları.
// Kaynak CSS: tasarım Sipario.html — her bileşenin başında sınıf adı yazılıdır.
// Barrel: `../isletme_atomlari.dart` (ekranlar oradan import eder).

import 'package:flutter/material.dart';

import '../../../theme/components/atoms.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CSS `.ys-ekle` — kesik çizgili "yeni … ekle" düğmesi
// ═══════════════════════════════════════════════════════════════════════════════════════════

class EkleSatiri extends StatelessWidget {
  const EkleSatiri({super.key, required this.etiket, this.onTap});

  final String etiket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return CustomPaint(
      painter: _KesikliCerceve(renk: t.line2, radius: SipRadius.r2),
      child: SipDokun(
        onTap: onTap,
        basiliZemin: t.accentSoft,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SipIcon(SipIcons.plus, boyut: 20, kalinlik: 2.3, renk: t.accent),
            const SizedBox(width: SipSpace.md),
            Text(
              etiket,
              style: SipText.metin(13.5, w: 700).copyWith(color: t.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// CSS `border: 1.5px dashed var(--line-2)` — Flutter'da hazırı yok, çizilir.
class _KesikliCerceve extends CustomPainter {
  const _KesikliCerceve({required this.renk, required this.radius});

  final Color renk;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final firca = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = renk;
    final yol = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
        Radius.circular(radius),
      ));
    for (final olcum in yol.computeMetrics()) {
      var mesafe = 0.0;
      while (mesafe < olcum.length) {
        final bitis = (mesafe + 5).clamp(0.0, olcum.length);
        canvas.drawPath(olcum.extractPath(mesafe, bitis), firca);
        mesafe += 9; // 5 çizgi + 4 boşluk
      }
    }
  }

  @override
  bool shouldRepaint(_KesikliCerceve eski) => eski.renk != renk;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CSS `.ym-err` — form alanı altındaki tek satır hata/bilgi
// ═══════════════════════════════════════════════════════════════════════════════════════════

class AlanNotu extends StatelessWidget {
  const AlanNotu(this.metin, {super.key, this.tur = AlanNotuTuru.hata});

  final String metin;
  final AlanNotuTuru tur;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final (renk, ikon) = switch (tur) {
      AlanNotuTuru.hata => (t.danger, SipIcons.alert),
      AlanNotuTuru.uyari => (t.warn, SipIcons.info),
      AlanNotuTuru.bilgi => (t.muted, SipIcons.info),
    };
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: SipIcon(ikon, boyut: 13, kalinlik: 2.2, renk: renk),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12, w: 700).copyWith(color: renk),
            ),
          ),
        ],
      ),
    );
  }
}

enum AlanNotuTuru { hata, uyari, bilgi }

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CSS `.aktif-toggle` / `.xiaomi-toggle` — topuz SOLDA, etiket sağda
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// `lib/theme/components/atoms.dart` içindeki [SipToggle] topuzu SAĞA koyar (ayar satırı dili).
/// Tasarımın form içi anahtarı ters dizilidir; bu yüzden ayrı bileşen.
class AktifToggle extends StatelessWidget {
  const AktifToggle({
    super.key,
    required this.acik,
    required this.etiket,
    required this.onDegis,
    this.ustBosluk = 16,
    this.altEtiket,
  });

  final bool acik;
  final String etiket;
  final ValueChanged<bool> onDegis;
  final double ustBosluk;

  /// İkinci satır: anahtarın SONUCUNU anlatan kısa cümle (kurye yetkileri, 2026-08-04).
  /// null iken hiç çizilmez — tek satırlık eski kullanımlar aynen kalır.
  final String? altEtiket;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: EdgeInsets.only(top: ustBosluk),
      child: SipDokun(
        onTap: () => onDegis(!acik),
        zemin: t.surface2,
        basiliZemin: t.line,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
        child: Row(
          children: [
            SipKnob(acik: acik),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    etiket,
                    style: SipText.metin(13, w: 600).copyWith(color: t.ink2),
                  ),
                  if (altEtiket != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        altEtiket!,
                        style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CSS `.urow` — ürün / kurye liste satırı
// ═══════════════════════════════════════════════════════════════════════════════════════════

class UrunSatiri extends StatelessWidget {
  const UrunSatiri({
    super.key,
    required this.bas,
    required this.ad,
    this.altSatir,
    this.altEk,
    this.sag,
    this.pasif = false,
    this.onTap,
  });

  /// Soldaki görsel/ikon (42×42 küçük görsel ya da `.krow-ic` yuvarlağı).
  final Widget bas;

  final String ad;

  /// CSS `.urow-birim` — birim ya da telefon.
  final String? altSatir;

  /// CSS `.urow-bk` — birimin devamına eklenen ikinci bilgi (barkod).
  final String? altEk;

  /// CSS `.urow-fiyat` — sağdaki tutar; yoksa yalnız chevron çizilir.
  final String? sag;

  /// CSS `.urow.pasif` — satır sönükleşir (opacity .55) ve "PASİF" rozeti eklenir.
  final bool pasif;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Opacity(
      opacity: pasif ? 0.55 : 1,
      child: SipDokun(
        onTap: onTap,
        zemin: t.surface,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            bas,
            const SizedBox(width: SipSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ad,
                          style: SipText.metin(14, w: 700).copyWith(color: t.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pasif) ...[
                        const SizedBox(width: SipSpace.md),
                        // CSS `.urow-pasif` — BÜYÜK HARF rozet.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.surface2,
                            borderRadius: SipRadius.brHap,
                          ),
                          child: Text(
                            'PASİF',
                            style: SipText.rozetKucuk.copyWith(color: t.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (altSatir != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text.rich(
                        TextSpan(
                          text: altSatir,
                          children: [
                            if (altEk != null)
                              TextSpan(
                                text: ' · $altEk',
                                style: SipText.tutar(10.5, w: 500).copyWith(color: t.muted),
                              ),
                          ],
                        ),
                        style: SipText.metin(11.5, w: 500).copyWith(color: t.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (sag != null) ...[
              const SizedBox(width: SipSpace.lg),
              Text(sag!, style: SipText.tutar(13.5).copyWith(color: t.ink)),
            ],
            const SizedBox(width: SipSpace.md),
            SipIcon(SipIcons.chevR, boyut: 18, kalinlik: 2, renk: t.line2),
          ],
        ),
      ),
    );
  }
}

/// Henüz gelmemiş bir özelliğin bölüm başlığı: başlık + "Çok yakında" rozeti.
///
/// NEDEN VAR (2026-08-13): bazı alanlar veri katmanında hazır ama onları TÜKETEN özellik
/// yazılmadı — ilk örnek fiş alt notu (`tenant_settings.receipt_note` yazılıyor, senkron
/// taşıyor, ama uygulamada fiş diye bir çıktı yok). Böyle bir alanı normal görünümde bırakmak
/// tutulmayan bir söz verir: bayi doldurur, kaydeder, sonucu hiçbir yerde göremez ve ürünün
/// bozuk olduğunu düşünür.
///
/// ALANI SİLMEK YERİNE İŞARETLEMEK bilinçli bir tercihtir: veri katmanı yerinde kalır (özellik
/// gelince tek satırla açılır) ve arada girilmiş değerler kaybolmaz. Rozet, alanın PASİF
/// çizilmesiyle BİRLİKTE kullanılır — yalnız rozet koyup alanı yazılabilir bırakmak, aynı
/// yanlış sözü kibarca vermek olurdu.
class CokYakindaBaslik extends StatelessWidget {
  const CokYakindaBaslik(this.baslik, {super.key, this.ustBosluk = 20});

  final String baslik;
  final double ustBosluk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: EdgeInsets.only(top: ustBosluk, bottom: 8),
      child: Row(
        children: [
          Text(
            baslik,
            style: SipText.bolumBaslik.copyWith(color: t.muted),
          ),
          const SizedBox(width: SipSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.brHap),
            child: Text(
              'Çok yakında',
              style: SipText.metin(10.5, w: 700).copyWith(color: t.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
