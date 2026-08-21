// Çekmecedeki LİSANS / OTO-SIRALAMA durum şeridi.
//
// ══ NEDEN KART DEĞİL ŞERİT (kullanıcı geri bildirimi 2026-08-13) ═══════════════════════════
// Bu bilgi bir tur boyunca iki BÜYÜK kart olarak çizildi: 30 punto rakam, renkli pil, ilerleme
// çubuğu, iki satır etiket — toplam ~110 punto yükseklik. Önizleme PNG'sinde ölçüldüğünde
// sonuç netti: kartlar bir GEZİNME menüsünün en gürültülü öğesiydi ve menü bir kontrol
// paneline benziyordu. Kullanıcı da aynı şeyi söyledi ("gereksiz büyükler").
//
// Bilgi KAYBOLMADI, ağırlığı düştü: aynı üç gerçek (kalan gün · bitiş tarihi · kalan hak) tek
// satırlık iki çipte duruyor, ~44 punto. Menü bir hedef listesidir; durum orada BAKILIR,
// okunmaz — ayrıntı Ayarlar → Hakkında sayfasında zaten metin olarak var.
//
// ROL KAPISI ÇAĞIRANDADIR: yalnız yönetici rollerinde çizilir, kuryede hiç kurulmaz.
//
// SAYI UYDURULMAZ: bilinmeyen hâlde rakam yerine "—" basılır ve çip "bilinmiyor" der. Lisans
// çipi DAİMA çizilir (abonelik bu uygulamanın omurgası, boş çekmeceden okunamaz); oto-sıralama
// çipi ise veri yokken hiç çizilmez — onun bilinmeyen hâli bir ORAN ister ve iki bilinmeyenden
// oran uydurulamaz.

import 'package:flutter/material.dart';

import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class CekmeceIstatistikleri extends StatelessWidget {
  const CekmeceIstatistikleri({
    super.key,
    this.lisansBitisi,
    this.otoSiralamaHakki,
    this.otoSiralamaAylik,
  });

  /// Abonelik bitişi (SyncMeta `validUntilIso`). null → çip "bilinmiyor" hâlinde çizilir.
  final DateTime? lisansBitisi;

  final int? otoSiralamaHakki;
  final int? otoSiralamaAylik;

  static const List<String> _aylar = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final b = lisansBitisi;

    final Widget lisans;
    if (b == null) {
      lisans = const _Cip(
        ikon: SipIcons.clock,
        deger: '—',
        alt: 'Bitiş tarihi bilinmiyor',
        renk: SipTokens.onHeroMid,
      );
    } else {
      final kalan = b.difference(DateTime.now().toUtc()).inDays;
      final gecerli = kalan > 0;
      lisans = _Cip(
        ikon: gecerli ? SipIcons.check : SipIcons.alert,
        deger: '${gecerli ? kalan : 0} gün',
        alt: '${b.day} ${_aylar[b.month - 1]} ${b.year} tarihine kadar',
        renk: gecerli ? SipTokens.heroDot : t.danger,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.md),
      child: Row(
        children: [
          Expanded(child: lisans),
          if (otoSiralamaHakki != null) ...[
            const SizedBox(width: SipSpace.md),
            Expanded(
              child: _Cip(
                ikon: SipIcons.bolt,
                deger: '$otoSiralamaHakki hak',
                alt: otoSiralamaAylik == null
                    ? 'Oto sıralama'
                    : 'Oto sıralama, ayda $otoSiralamaAylik',
                renk: SipTokens.heroPill,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tek durum çipi: renkli ikon + değer + altında küçük açıklama.
class _Cip extends StatelessWidget {
  const _Cip({
    required this.ikon,
    required this.deger,
    required this.alt,
    required this.renk,
  });

  final String ikon;
  final String deger;
  final String alt;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: SipTokens.onHeroFill,
        borderRadius: SipRadius.br2,
      ),
      child: Row(
        children: [
          SipIcon(ikon, boyut: 14, kalinlik: 2.2, renk: renk),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  deger,
                  style: SipText.tutar(13, w: 800).copyWith(color: SipTokens.onHero),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  alt,
                  style: SipText.metin(9.5, w: 600).copyWith(color: SipTokens.onHeroSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
