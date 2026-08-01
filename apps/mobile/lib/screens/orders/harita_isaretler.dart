// HARİTANIN İŞARETLERİ — numaralı durak pini, cihaz pini ve konumsuz siparişler bandı.
//
// NEDEN AYRI DOSYA: `siparis_harita.dart` verinin, kameranın ve "Oto Sırala" akışının yeri;
// bunlar ise saf çizimdir (durumları yok, yalnız çizerler). "Oto Sırala" düğmesi haritaya
// taşınınca ekran dosyası 500 satırı aştı — bölünme oradan geldi. `harita_kontrolleri.dart`a
// konmadılar: orası KONTROL düğmelerinin yeri, bunlar ise haritanın İÇERİĞİ.
//
// Bu semboller `siparis_harita.dart` üzerinden de dışa verilir (`export`): mevcut testler ve
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
                '$adet sipariş konumsuz — haritada yok',
                style: SipText.metin(12, w: 600).copyWith(color: t.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numaralı durak işaretçisi — accent zemin, accentInk rakam (tasarımın vurgu jetonları).
class DurakPini extends StatelessWidget {
  const DurakPini({
    super.key,
    required this.sira,
    required this.baslik,
    required this.onTap,
  });

  final int sira;

  /// Erişilebilirlik etiketi: ekran okuyucu "3. durak · Ayşe Yılmaz" der. Sayı tek başına
  /// haritada hangi müşteriyi işaret ettiğini söylemez.
  final String baslik;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: '$sira. durak · $baslik',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.accent,
            shape: BoxShape.circle,
            // İnce açık halka: koyu karoların üstünde pin kaybolmasın.
            border: Border.all(color: t.accentInk, width: 2),
          ),
          child: Text(
            '$sira',
            style: SipText.tutar(13, w: 800).copyWith(color: t.accentInk),
          ),
        ),
      ),
    );
  }
}

/// Cihazın bulunduğu nokta — duraklardan AYRI görünür (içi dolu küçük nokta, halkalı).
/// Numarası yoktur: rota duraklardan oluşur, kurye bir durak değildir.
class CihazPini extends StatelessWidget {
  const CihazPini({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      label: 'Bulunduğunuz konum',
      child: Container(
        decoration: BoxDecoration(
          color: t.ok,
          shape: BoxShape.circle,
          border: Border.all(color: SipTokens.onHero, width: 3),
        ),
      ),
    );
  }
}
