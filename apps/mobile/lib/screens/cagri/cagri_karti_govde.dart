// Çağrı kartının ALT YARISI — CSS `.cagri-bal` + `.cagri-bilgi`/`.cagri-brow` + `.cagri-acts`.
// İskelet `cagri_karti.dart`'tadır; bu dosya 500 satır sınırı için ayrıldı.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'cagri_model.dart';

/// CSS `.cagri-bal` — yalnız bakiye 0 değilken çizilir.
class CagriBakiyeSeridi extends StatelessWidget {
  const CagriBakiyeSeridi({super.key, required this.kurus});

  final int kurus;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final renk = t.bakiyeRenk(kurus);
    return Container(
      margin: const EdgeInsets.only(top: SipSpace.x2),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: SipSpace.xl),
      decoration: BoxDecoration(
        color: t.bakiyeSoft(kurus),
        borderRadius: SipRadius.br2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // ÖNCELİK SIRASI (2026-07-27): dar kartta ya da büyük yazı tipinde şerit taşıyordu.
          // Kırpılacak olan ETİKETTİR, TUTAR DEĞİL: "AÇIK BO…" hâlâ anlaşılır, yarım okunan bir
          // borç rakamı esnafın defteriyle tutmayan bir sayı demektir (kırmızı çizgi #2'nin ruhu).
          // `Expanded` (eski `Spacer`ın yerine): etiket kalan alanın tamamını alır, yani tutar
          // eskisi gibi SAĞA yaslı kalır — görünüm değişmez, yalnız sıkışma yönü tanımlanmış olur.
          Expanded(
            // Etiketle tutar arasındaki boşluk BURADA, etiketin içinde: sabit bir `SizedBox`
            // olsaydı etiket tamamen sıkışsa bile o 8px yerini korur ve tutarı taşırırdı.
            child: Padding(
              padding: const EdgeInsets.only(right: SipSpace.md),
              child: Text(
                kurus > 0 ? 'AÇIK BORÇ' : 'ALACAĞI VAR',
                style: SipText.cagriBakiyeEtiket.copyWith(color: renk),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Text(
            sipTutar(kurus.abs()),
            style: SipText.cagriBakiyeDeger.copyWith(color: renk),
          ),
        ],
      ),
    );
  }
}

/// CSS `.cagri-bilgi` — adres, son hareket ve müşteri notu. Hiçbiri yoksa hiç çizilmez.
class CagriBilgiSatirlari extends StatelessWidget {
  const CagriBilgiSatirlari({super.key, required this.kisi});

  final CagriKisi kisi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final satirlar = <Widget>[];

    final adres = kisi.adres;
    if (adres != null && adres.isNotEmpty) {
      // Bölge kaldırıldı (2026-07-28): adres metni tek başına gösterilir.
      satirlar.add(
        _BilgiSatiri(
          ikon: SipIcons.pin,
          ikonRenk: kisi.konumVar ? t.ok : t.muted,
          metin: adres,
          // Kayıtlı konum varsa satır sonunda yeşil onay (tasarımdaki `check`).
          sag: kisi.konumVar
              ? SipIcon(SipIcons.check, boyut: 12, kalinlik: 3, renk: t.ok)
              : null,
        ),
      );
    }

    final son = kisi.sonHareket;
    if (son != null && son.isNotEmpty) {
      // Siparişin DURUMU satırın sonunda rozet olarak durur (2026-07-27 saha bulgusu: kart
      // son siparişi yazıyor ama "yolda mı, teslim mi" demiyordu). Rozet metnin İÇİNE
      // katılmaz: uzun sipariş dökümü kısaldığında ilk kaybolacak şey durum olurdu.
      final durum = kisi.sonSiparisDurumu;
      satirlar.add(
        _BilgiSatiri(
          ikon: kisi.sonHareketTuru == SonHareketTuru.defter
              ? SipIcons.book
              : SipIcons.box,
          ikonRenk: t.muted,
          metin: son,
          sag: durum == null || durum.isEmpty
              ? null
              : SipPil(
                  etiket: durum,
                  renk: _durumRenk(t, durum),
                  zemin: _durumZemin(t, durum),
                ),
        ),
      );
    }

    final not = kisi.not;
    if (not != null && not.isNotEmpty) {
      satirlar.add(
        _BilgiSatiri(
          ikon: SipIcons.info,
          ikonRenk: t.warn,
          metin: not,
          uyari: true,
        ),
      );
    }

    if (satirlar.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < satirlar.length; i++) ...[
            if (i > 0) const SizedBox(height: SipSpace.md),
            satirlar[i],
          ],
        ],
      ),
    );
  }
}

/// Durum rozetinin rengi — `SipDurumPili` ile aynı dil: teslim `ok`, iptal sönük, açık/yolda
/// `accent`. Eşleme metin üzerinden yapılır çünkü kart ham `status` değil, okunabilir sözcük
/// taşır (native kart da aynı sözcüğü yazar).
Color _durumRenk(SipTokens t, String durum) => switch (durum) {
      'Teslim edildi' => t.ok,
      'İptal edildi' => t.muted,
      _ => t.accent,
    };

Color _durumZemin(SipTokens t, String durum) => switch (durum) {
      'Teslim edildi' => t.okSoft,
      'İptal edildi' => t.line,
      _ => t.accentSoft,
    };

class _BilgiSatiri extends StatelessWidget {
  const _BilgiSatiri({
    required this.ikon,
    required this.ikonRenk,
    required this.metin,
    this.sag,
    this.uyari = false,
  });

  final String ikon;
  final Color ikonRenk;
  final String metin;
  final Widget? sag;

  /// CSS `.cagri-brow.warn` — sarı zeminli not satırı.
  final bool uyari;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final satir = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: SipIcon(ikon, boyut: 14, kalinlik: 2.1, renk: ikonRenk),
        ),
        const SizedBox(width: SipSpace.md),
        Expanded(
          child: Text(
            metin,
            style: SipText.cagriBilgi.copyWith(color: uyari ? t.warn : t.ink2),
          ),
        ),
        if (sag != null) ...[
          const SizedBox(width: SipSpace.sm),
          Padding(padding: const EdgeInsets.only(top: 2), child: sag!),
        ],
      ],
    );

    if (!uyari) return satir;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: t.warnSoft,
        borderRadius: SipRadius.br1,
      ),
      child: satir,
    );
  }
}

/// CSS `.cagri-acts` — düğme yüksekliği 50.
class CagriEylemler extends StatelessWidget {
  const CagriEylemler({
    super.key,
    required this.kisi,
    this.onSiparis,
    this.onDefter,
    this.onKaydet,
  });

  final CagriKisi kisi;
  final VoidCallback? onSiparis;
  final VoidCallback? onDefter;
  final VoidCallback? onKaydet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: kisi.kayitli
            ? [
                SipButon(
                  etiket: 'Sipariş Oluştur',
                  ikon: SipIcons.plus,
                  yukseklik: 50,
                  onTap: onSiparis,
                ),
                const SizedBox(height: SipSpace.md),
                SipButon(
                  etiket: 'Defteri Aç',
                  ikon: SipIcons.book,
                  tur: SipButonTuru.ikincil,
                  yukseklik: 50,
                  onTap: onDefter,
                ),
              ]
            : [
                SipButon(
                  etiket: 'Müşteri Olarak Kaydet',
                  ikon: SipIcons.userPlus,
                  yukseklik: 50,
                  onTap: onKaydet,
                ),
              ],
      ),
    );
  }
}
