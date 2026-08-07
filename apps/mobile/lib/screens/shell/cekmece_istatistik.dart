// Çekmecedeki istatistik kartları — Sipario.html `.lst-grid`, `.lst-kart`.
//
// `cekmece.dart`'tan ayrıldı (500 satır sınırı). Bu bölüm ROL KAPISININ arkasındadır: çağıran
// yalnız yönetici rollerinde çizer, kurye'de hiç kurmaz.
//
// LİSANS KARTI DAİMA ÇİZİLİR: tasarımda `.lst-grid` her zaman iki kartlıdır
// (`s-bilesenler.jsx:110-123`) ve abonelik durumu bu uygulamanın omurgası — bilinmiyorsa
// "bilinmiyor" yazılır, kart yok sayılmaz (kullanıcı "lisansım ne oldu"yu boş çekmeceden
// okuyamaz). Sayı UYDURULMAZ: bilinmeyen hâlde rakam yerine "—" basılır.
//
// OTO-SIRALAMA kartı ise `null` iken hiç çizilmez: onun bilinmeyen hâli bir ORAN çubuğu ister
// (kaç hak / aylık kota) ve iki bilinmeyenden çubuk uydurulamaz.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Lisans + oto-sıralama kartlarının ızgarası. Lisans kartı daima var.
class CekmeceIstatistikleri extends StatelessWidget {
  const CekmeceIstatistikleri({
    super.key,
    this.lisansBitisi,
    this.otoSiralamaHakki,
    this.otoSiralamaAylik,
  });

  /// Abonelik bitişi (SyncMeta `validUntilIso`). null → kart "bilinmiyor" hâlinde çizilir.
  final DateTime? lisansBitisi;

  final int? otoSiralamaHakki;
  final int? otoSiralamaAylik;

  @override
  Widget build(BuildContext context) {
    final kartlar = <Widget>[
      _LisansKarti(bitis: lisansBitisi),
      if (otoSiralamaHakki != null)
        _IstatKarti(
          ikon: SipIcons.bolt,
          pil: otoSiralamaAylik == null ? null : 'Aylık $otoSiralamaAylik',
          deger: '$otoSiralamaHakki',
          birim: 'hak',
          etiket: 'Oto sıralama bakiyesi',
          oran: otoSiralamaAylik == null || otoSiralamaAylik == 0
              ? null
              : (otoSiralamaHakki! / otoSiralamaAylik!).clamp(0.0, 1.0),
          renk: SipTokens.heroPill,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, SipSpace.lg, 2, 2),
      // IntrinsicHeight şart: çekmece gövdesi ListView (sınırsız yükseklik) ve `stretch`
      // orada ölçüsüz kalıp layout'u düşürüyor. CSS `.lst-grid` iki kartı eşit boyda ister.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < kartlar.length; i++) ...[
              if (i > 0) const SizedBox(width: SipSpace.md),
              Expanded(child: kartlar[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lisans kartı — kalan gün SyncMeta `validUntilIso`'dan hesaplanır. Metin NÖTR
/// (mağaza kuralı: fiyat/satın alma/yenileme çağrısı YOK).
///
/// [bitis] null iken kart "bilinmiyor" hâlinde çizilir: rakam yerine "—", çubuk yok, renk nötr.
class _LisansKarti extends StatelessWidget {
  const _LisansKarti({required this.bitis});

  final DateTime? bitis;

  static const List<String> _aylar = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    final b = bitis;
    if (b == null) {
      return const _IstatKarti(
        ikon: SipIcons.clock,
        pil: 'Bilinmiyor',
        deger: '—',
        etiket: 'Lisans · bağlantı kurulunca netleşir',
        renk: SipTokens.onHeroMid,
      );
    }
    final kalan = b.difference(DateTime.now().toUtc()).inDays;
    final gecerli = kalan > 0;
    return _IstatKarti(
      ikon: gecerli ? SipIcons.check : SipIcons.clock,
      pil: gecerli ? 'Aktif' : 'Süre doldu',
      pilOk: gecerli,
      deger: '${kalan > 0 ? kalan : 0}',
      birim: 'gün',
      etiket: 'Lisans · bitiş ${b.day} ${_aylar[b.month - 1]} ${b.year}',
      oran: gecerli ? (kalan / 365).clamp(0.0, 1.0) : 0,
      renk: gecerli ? SipTokens.heroDot : context.sip.danger,
    );
  }
}

/// CSS `.lst-kart`.
class _IstatKarti extends StatelessWidget {
  const _IstatKarti({
    required this.ikon,
    required this.deger,
    required this.etiket,
    required this.renk,
    this.birim,
    this.pil,
    this.pilOk = false,
    this.oran,
  });

  final String ikon;
  final String deger;

  /// Rakamın yanındaki küçük birim ("gün", "hak"). Bilinmeyen değerde null.
  final String? birim;
  final String etiket;
  final Color renk;
  final String? pil;
  final bool pilOk;
  final double? oran;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(SipSpace.xl, 11, SipSpace.xl, SipSpace.xl),
      decoration: const BoxDecoration(
        color: SipTokens.onHeroFill,
        borderRadius: SipRadius.br2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: pilOk ? 0.16 : 0.25),
                  shape: BoxShape.circle,
                ),
                child: SipIcon(ikon, boyut: 13, kalinlik: 2.4, renk: renk),
              ),
              if (pil != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: renk.withValues(alpha: pilOk ? 0.14 : 0.25),
                      borderRadius: SipRadius.brHap,
                    ),
                    child: Text(
                      trBuyuk(pil!),
                      style: SipText.istatPil.copyWith(color: renk),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SipSpace.sm),
          Text.rich(
            TextSpan(
              text: deger,
              children: [
                if (birim != null)
                  TextSpan(
                    text: ' $birim',
                    style: SipText.metin(11, w: 600).copyWith(color: SipTokens.onHeroMid),
                  ),
              ],
            ),
            style: SipText.istatDeger.copyWith(color: SipTokens.onHero),
          ),
          const SizedBox(height: SipSpace.xs),
          Text(
            etiket,
            style: SipText.istatEtiket.copyWith(color: SipTokens.onHeroMid),
          ),
          if (oran != null) ...[
            const SizedBox(height: SipSpace.xs),
            ClipRRect(
              borderRadius: SipRadius.brHap,
              child: LinearProgressIndicator(
                value: oran,
                minHeight: 4,
                backgroundColor: SipTokens.onHeroLine,
                valueColor: AlwaysStoppedAnimation(renk),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
