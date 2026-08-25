// GÜN ÖZETİ'NİN TEPE BLOĞU — tek iri rakam + üç istatistik (yeniden tasarım, 2026-08-25).
//
// ══ NEDEN VAR ═══════════════════════════════════════════════════════════════════════════════
// Ekran eskiden doğrudan "Kasa Özeti" kartıyla açılıyordu: dört satır, dördü de aynı puntoda,
// hiçbiri diğerinden önemli değil. Oysa bayinin akşam sorduğu TEK soru var — "çekmecede ne
// olmalı?" — ve o rakam ekranda hiç yazmıyordu; bayi nakitten ara tahsilatı, giderleri ve
// kuryelerde kalanı kafasında çıkarmak zorundaydı. Tepe bloğu o çıkarmayı ekrana taşır.
//
// ══ RAKAM EKRANDA HESAPLANMAZ ═══════════════════════════════════════════════════════════════
// [GunOzetiBasligi.beklenen] `DayClosingRepository.onizle`den gelir — yani kapanış sheet'inin
// gösterdiği ve arşive donan tutarla AYNI koddan. Burada bir çıkarma yapsaydık, "Günü Kapat"a
// basan bayi bir kare sonra BAŞKA bir rakam görürdü ve ikisine de güvenmezdi.
//
// ══ NULL BEKLENEN = O KAPSAMDA BÖYLE BİR BÜYÜKLÜK YOK ═══════════════════════════════════════
// "Elemanlar" ve patronun "Kendi işlemlerim" kapsamları birer OKUMA kapsamıdır; `day_closings`
// onları tanımaz ve orada "kasada olması gereken" diye bir mutabakat yoktur. O hâlde blok
// başlığı da rakamı da değişir (günün tahsilat toplamına döner) — sıfır yazmak, olmayan bir
// mutabakat iddia etmek olurdu.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class GunOzetiBasligi extends StatelessWidget {
  const GunOzetiBasligi({
    super.key,
    required this.beklenen,
    required this.tahsilat,
    required this.gider,
    required this.teslimat,
    required this.veresiye,
    required this.kapsamKapali,
    required this.gunKapali,
  });

  /// Kasada olması gereken nakit; null ise bu kapsamda tanımlı DEĞİLDİR (bkz. dosya başlığı).
  final int? beklenen;

  /// Günün TAHSİLAT toplamı (üç ödeme türü).
  final int tahsilat;

  /// Kasadan çıkan gider (POZİTİF kuruş).
  final int gider;

  final int teslimat;

  /// O gün yazılan veresiye (POZİTİF kuruş).
  final int veresiye;

  final bool kapsamKapali;
  final bool gunKapali;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final mutabakat = beklenen != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(color: t.hero, borderRadius: SipRadius.br3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trBuyuk(mutabakat ? 'Kasada olması gereken' : 'Toplam tahsilat'),
                      style: SipText.metin(10.5, w: 800).copyWith(
                        color: SipTokens.onHeroMid,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  // KİLİT ROZETİ RAKAMIN YANINDA: kapanmış bir kapsamda bu tutar artık
                  // "olması gereken" değil "donmuş olan"dır ve bunu söyleyen işaret rakamla
                  // aynı bakışta okunmalı. Ayrıntılı cümle aşağıdaki şeritte kalır.
                  if (kapsamKapali)
                    const SipIcon(SipIcons.lock,
                        boyut: 14, kalinlik: 2.2, renk: SipTokens.onHeroMid),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                sipTutar(mutabakat ? beklenen! : tahsilat),
                style: SipText.tutar(30, w: 800).copyWith(color: SipTokens.onHero),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: SipTokens.onHeroLine),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _AltDeger(
                      etiket: 'Tahsilat',
                      deger: sipTutar(tahsilat),
                      renk: SipTokens.onHeroStrong,
                    ),
                  ),
                  // GİDER YALNIZ VARSA YAZILIR: "Gider 0,00 ₺" her akşam cevapsız bir soru
                  // olurdu (kasa kartındaki iskonto satırıyla aynı kural).
                  if (gider != 0)
                    Expanded(
                      child: _AltDeger(
                        etiket: 'Gider',
                        deger: '− ${sipTutar(gider)}',
                        renk: SipTokens.onHeroWarn,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: SipSpace.md),
        Row(
          children: [
            Expanded(
              child: _Kutu(
                ikon: SipIcons.truck,
                deger: sipSayi(teslimat),
                etiket: 'teslimat',
              ),
            ),
            const SizedBox(width: SipSpace.md),
            Expanded(
              child: _Kutu(
                ikon: SipIcons.book,
                deger: sipTutar(veresiye),
                etiket: 'veresiye',
                renk: veresiye > 0 ? t.danger : null,
              ),
            ),
            const SizedBox(width: SipSpace.md),
            Expanded(
              child: _Kutu(
                ikon: gunKapali ? SipIcons.lock : SipIcons.clock,
                deger: gunKapali ? 'Kapalı' : 'Açık',
                etiket: 'gün hesabı',
                renk: gunKapali ? t.ok : t.warn,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Hero bloğunun alt satırındaki küçük değer.
///
/// DOKUNULAMAZ ve bu bilinçli: aynı dökümü açan İKİNCİ bir yol olmaz. Tahsilatın satır satır
/// dökümü kasa kartındaki ödeme türü satırlarında ve "Günün Teslimatları" bölümündedir; buraya
/// üçüncü bir kapı koymak, bayiye "acaba bunlar farklı listeler mi" sorusunu sordururdu.
class _AltDeger extends StatelessWidget {
  const _AltDeger({
    required this.etiket,
    required this.deger,
    required this.renk,
  });

  final String etiket;
  final String deger;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiket,
          style: SipText.metin(11, w: 600).copyWith(color: SipTokens.onHeroSoft),
        ),
        const SizedBox(height: 2),
        Text(deger, style: SipText.tutar(15, w: 700).copyWith(color: renk)),
      ],
    );
  }
}

/// Hero'nun altındaki üç küçük istatistik kutusundan biri.
class _Kutu extends StatelessWidget {
  const _Kutu({
    required this.ikon,
    required this.deger,
    required this.etiket,
    this.renk,
  });

  final String ikon;
  final String deger;
  final String etiket;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SipIcon(ikon, boyut: 15, kalinlik: 2, renk: renk ?? t.muted),
          const SizedBox(height: 7),
          Text(
            deger,
            style: SipText.tutar(14, w: 700).copyWith(color: renk ?? t.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            etiket,
            style: SipText.metin(10.5, w: 600).copyWith(color: t.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
