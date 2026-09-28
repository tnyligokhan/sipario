// HARİTANIN BANTLARI — konumsuz siparişler bandı.
//
// Durak ve cihaz pinleri 2026-09-28'e dek bu dosyada Flutter widget'ı olarak dururdu; harita
// MapLibre'ye geçince motorun kendi vektör katmanları oldular (`harita_maplibre.dart`). Bant
// haritanın DIŞINDA, başlığın altında durduğu için widget olarak kaldı.
//
// Bu sembol `siparis_harita.dart` üzerinden de dışa verilir (`export`): mevcut testler ve
// çağıranlar harita ekranını tek dosyadan tanıyor, o yüzey SÖZLEŞMEDİR.

import 'package:flutter/material.dart';

import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Koordinatsız açık siparişleri duyuran NÖTR bant. Hata değildir (kimse yanlış bir şey yapmadı),
/// bu yüzden danger değil sönük yüzey rengiyle çizilir — ama görünürdür.
class KonumsuzBant extends StatelessWidget {
  const KonumsuzBant({super.key, required this.adet});

  final int adet;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.govde, 0, SipSpace.govde, SipSpace.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.md),
        decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.br1),
        child: Row(
          children: [
            SipIcon(SipIcons.info, boyut: 15, kalinlik: 2, renk: t.muted),
            const SizedBox(width: SipSpace.md),
            Expanded(
              child: Text(
                // Metin SÖZLEŞMEDİR (testler bu cümleyi arar).
                '$adet siparişin konumu yok, haritada görünmüyor',
                style: SipText.metin(12, w: 600).copyWith(color: t.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

