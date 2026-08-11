// Sipariş ekranlarının PAYLAŞILAN parçaları — yeni sipariş (`.ys-*`), sipariş detayı (`.sd-*`,
// `.sdx-*`) ve düzenleme sheet'i aynı kart/satır/toplam dilini kullanıyor; tek yerde duruyorlar.
// Kaynak: Sipario.html 259–331 + s-siparisler.jsx.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'satir_notu.dart';

// Detay/özet kartı ve serbest satır sheet'i ayrı dosyada (500 satır sınırı); çağıranlar tek
// `order_parts.dart` import'uyla ikisine de erişsin. Satır notu da öyle: rozet + normalleştirme
// + girme sheet'i `satir_notu.dart`ta birlikte durur.
export 'order_sd_parts.dart';
export 'satir_notu.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Taslak satır — henüz kaydedilmemiş sipariş kalemi
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Sipariş satırı taslağı. Kaydedildiğinde `LineInput`'a çevrilir.
/// SERBEST satır = katalog dışı tek seferlik iş → [productId] null, [qty] 1; kaydedilirken
/// `OrderLines.isCustom = true` yazılır (sözleşme — bayrak açık, çünkü silinmiş ürünün satırı da
/// null productId taşır ve o serbest satır DEĞİLDİR).
class LineDraft {
  LineDraft({
    this.productId,
    required this.name,
    required this.unitPriceKurus,
    this.qty = 1,
    this.unit,
    this.note,
  });

  final String? productId;
  final String name;
  final int unitPriceKurus;

  /// Ürün birimi ("adet"/"koli"/"kg") — satırda saklanır (o anki gerçek). Serbest satırda null.
  final String? unit;

  int qty;

  /// SATIR NOTU — "buzlu olsun", "kapıya bırak" (kullanıcı isteği 2026-08-11).
  ///
  /// Sipariş notundan AYRIDIR ve onun yerine geçmez: sipariş notu teslimatın tamamına dairdir
  /// (kapı kodu, saat), satır notu tek KALEME dairdir. İkisini tek alanda toplamak, üç kalemli
  /// bir siparişte "buzlu olsun"un hangi kaleme ait olduğunu okuyana tahmin ettirirdi.
  ///
  /// BOŞ METİN null'a düşürülür (`notuNormalle`): "" ile null iki ayrı durum değildir ve
  /// sepette boş bir not rozeti çizdirirdi.
  String? note;

  bool get notVar => (note ?? '').trim().isNotEmpty;

  bool get serbest => productId == null;

  /// CSS `.ys-birim` / `.sd-birim` — sepet satırının alt yazısı.
  String get birimEtiketi => serbest ? 'tek seferlik' : (unit ?? 'adet');
}

/// Taslak satırların toplamı (int kuruş — kayan nokta YOK).
int toplamKurus(List<LineDraft> lines) =>
    lines.fold<int>(0, (s, l) => s + l.unitPriceKurus * l.qty);


// ═══════════════════════════════════════════════════════════════════════════════════════════
// Adım göstergesi — CSS `.ys-adimlar`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// 1-tabanlı [adim] ile üç durumlu rozet şeridi: geçilmiş (ok, yeşil), aktif (accent), bekleyen.
class AdimGostergesi extends StatelessWidget {
  const AdimGostergesi({super.key, required this.adimlar, required this.adim});

  final List<String> adimlar;
  final int adim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.govde, SipSpace.lg, SipSpace.govde, 2),
      child: Row(
        children: [
          for (var i = 0; i < adimlar.length; i++) ...[
            if (i > 0) const SizedBox(width: SipSpace.sm),
            Expanded(
              child: _AdimRozeti(
                etiket: adimlar[i],
                sira: i + 1,
                aktif: adim == i + 1,
                gecildi: adim > i + 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdimRozeti extends StatelessWidget {
  const _AdimRozeti({
    required this.etiket,
    required this.sira,
    required this.aktif,
    required this.gecildi,
  });

  final String etiket;
  final int sira;
  final bool aktif;
  final bool gecildi;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final metinRenk = gecildi ? t.ok : (aktif ? t.accent : t.muted);
    final zemin = aktif ? t.accentSoft : t.surface;
    final noktaZemin = gecildi ? t.ok : (aktif ? t.accent : t.line2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xs, vertical: 7),
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.brHap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: noktaZemin, shape: BoxShape.circle),
            child: gecildi
                ? const SipIcon(SipIcons.check,
                    boyut: 11, kalinlik: 3, renk: SipTokens.onHero)
                : Text('$sira',
                    style: SipText.metin(10, w: 800).copyWith(color: SipTokens.onHero)),
          ),
          const SizedBox(width: SipSpace.sm),
          Flexible(
            child: Text(
              etiket,
              style: SipText.metin(11, w: 700).copyWith(color: metinRenk),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Kesik çizgili ekleme düğmesi + boş durum — CSS `.ys-ekle`, `.ys-bos`
// ═══════════════════════════════════════════════════════════════════════════════════════════

class YsEkleDugmesi extends StatelessWidget {
  const YsEkleDugmesi({super.key, required this.etiket, required this.onTap, this.ikon});

  final String etiket;
  final VoidCallback? onTap;
  final String? ikon;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.sm),
      child: SipDokun(
        onTap: onTap,
        basiliZemin: t.accentSoft,
        radius: SipRadius.br2,
        kenarlik: Border.all(color: t.line2, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (ikon != null) ...[
              SipIcon(ikon!, boyut: 20, kalinlik: 2.3, renk: t.accent),
              const SizedBox(width: SipSpace.md),
            ],
            Flexible(
              child: Text(etiket,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class YsBosDurum extends StatelessWidget {
  const YsBosDurum({super.key, required this.metin, this.ikon = SipIcons.box});

  final String metin;
  final String ikon;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          SipIcon(ikon, boyut: 30, kalinlik: 1.5, renk: t.line2),
          const SizedBox(height: 9),
          Text(metin,
              textAlign: TextAlign.center,
              style: SipText.metin(13, w: 500).copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sepet satırı ve adet stepper'ı — CSS `.ys-satir`, `.ys-stepper`, `.ys-sil`
// ═══════════════════════════════════════════════════════════════════════════════════════════

class YsSatiri extends StatelessWidget {
  const YsSatiri({
    super.key,
    required this.ad,
    required this.altMetin,
    required this.tutarKurus,
    this.adet,
    this.onAzalt,
    this.onArtir,
    this.onSil,
    this.zemin,
    this.not,
    this.onNot,
  });

  final String ad;

  /// CSS `.ys-birim` — birim adı ya da serbest satırda "tek seferlik".
  final String altMetin;

  final int tutarKurus;

  /// null ise stepper çizilmez (serbest satır) ve yerine [onSil] düğmesi gelir.
  final int? adet;
  final VoidCallback? onAzalt;
  final VoidCallback? onArtir;
  final VoidCallback? onSil;
  final Color? zemin;

  /// SATIR NOTU — doluysa rozet çizilir. [onNot] verilmezse not yüzeyi salt-okunurdur.
  final String? not;
  final VoidCallback? onNot;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 11),
      decoration: BoxDecoration(color: zemin ?? t.surface, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad,
                    style: SipText.metin(13.5, w: 600).copyWith(color: t.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(altMetin, style: SipText.metin(10.5, w: 500).copyWith(color: t.muted)),
                // Not yüzeyi satırın İÇİNDE durur — ayrı bir kutu/şerit açmak sepeti iki kat
                // uzatır ve dokunuş hedefini kalemden koparırdı.
                if (not != null || onNot != null)
                  SatirNotuYuzeyi(not: not, onTap: onNot),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.lg),
          if (adet != null)
            YsStepper(adet: adet!, onAzalt: onAzalt, onArtir: onArtir)
          else if (onSil != null)
            SipIkonButon(
              ikon: SipIcons.x,
              cap: 30,
              ikonBoyut: 16,
              kalinlik: 2.2,
              renk: t.muted,
              etiket: 'Satırı sil',
              onTap: onSil,
            ),
          const SizedBox(width: SipSpace.lg),
          SizedBox(
            // CSS `.ys-satir-tt { min-width: 66px }` (_sayfa.html:521).
            width: 66,
            child: Text(
              sipTutar(tutarKurus),
              textAlign: TextAlign.right,
              style: SipText.tutar(13).copyWith(color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.ys-stepper` — hap ray + iki 28'lik yuvarlak düğme. Adet 1 iken azaltma düğmesi
/// tasarımdaki gibi KIRMIZI ÇARPI olur (bir daha basınca satır silinir).
class YsStepper extends StatelessWidget {
  const YsStepper({super.key, required this.adet, this.onAzalt, this.onArtir});

  final int adet;
  final VoidCallback? onAzalt;
  final VoidCallback? onArtir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final sonSatir = adet <= 1;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.brHap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Yuvarlak(
            ikon: sonSatir ? SipIcons.x : SipIcons.down,
            renk: sonSatir ? t.danger : t.ink,
            etiket: sonSatir ? 'Satırı sil' : 'Azalt',
            onTap: onAzalt,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SipSpace.md),
            child: SizedBox(
              width: 18,
              child: Text('$adet',
                  textAlign: TextAlign.center,
                  style: SipText.metin(13.5, w: 700).copyWith(color: t.ink)),
            ),
          ),
          _Yuvarlak(
            ikon: SipIcons.plus,
            renk: t.ink,
            etiket: 'Artır',
            onTap: onArtir,
          ),
        ],
      ),
    );
  }
}

class _Yuvarlak extends StatelessWidget {
  const _Yuvarlak({required this.ikon, required this.renk, required this.etiket, this.onTap});

  final String ikon;
  final Color renk;
  final String etiket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: etiket,
      child: SipDokun(
        onTap: onTap,
        zemin: t.knob,
        basiliZemin: t.line,
        radius: SipRadius.brHap,
        child: SizedBox.square(
          dimension: 28,
          child: Center(child: SipIcon(ikon, boyut: 14, kalinlik: 2.6, renk: renk)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Alt toplam çubuğu — CSS `.ys-alt`, `.ys-toplam`, `.ys-uyari`
// ═══════════════════════════════════════════════════════════════════════════════════════════

class YsAltCubugu extends StatelessWidget {
  const YsAltCubugu({
    super.key,
    required this.toplamKurus,
    required this.buton,
    this.uyari,
    this.uyariAnahtar = '',
  });

  final int toplamKurus;
  final Widget buton;

  /// CSS `.ys-uyari` — sarsıntı animasyonlu kırmızı şerit.
  final String? uyari;

  /// Sarsıntıyı yeniden tetikleyen anahtar: AYNI uyarı tekrar gösterilse de değeri değişirse
  /// animasyon baştan oynar (kullanıcı ikinci kez bastığını görsün).
  final String uyariAnahtar;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      margin: const EdgeInsets.fromLTRB(SipSpace.x3, SipSpace.lg, SipSpace.x3, SipSpace.x5),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: SipRadius.br3,
        // CSS `box-shadow: 0 16px 34px -20px rgba(23,20,31,.4)` (_sayfa.html:524). Negatif
        // yayılma → Flutter'da spreadRadius negatif; çubuk sayfadan kalkık dursun.
        boxShadow: const [
          BoxShadow(
            color: Color(0x6617141F),
            offset: Offset(0, 16),
            blurRadius: 34,
            spreadRadius: -20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (uyari != null) ...[
            SarsintiKutusu(
              anahtar: '$uyariAnahtar|${uyari!}',
              child: _UyariSeridi(metin: uyari!),
            ),
            const SizedBox(height: SipSpace.lg),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TOPLAM',
                        style: SipText.metin(10.5, w: 700).copyWith(color: t.muted)),
                    Text(sipTutar(toplamKurus),
                        style: SipText.tutar21.copyWith(color: t.ink)),
                  ],
                ),
              ),
              const SizedBox(width: SipSpace.lg),
              buton,
            ],
          ),
        ],
      ),
    );
  }
}

class _UyariSeridi extends StatelessWidget {
  const _UyariSeridi({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.dangerSoft, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          SipIcon(SipIcons.alert, boyut: 15, kalinlik: 2.2, renk: t.danger),
          const SizedBox(width: 7),
          Expanded(
            child: Text(metin, style: SipText.metin(12.5, w: 700).copyWith(color: t.danger)),
          ),
        ],
      ),
    );
  }
}

/// CSS `@keyframes sshake` — 0,34 sn yatay sarsıntı. [anahtar] değişince yeniden oynar.
class SarsintiKutusu extends StatelessWidget {
  const SarsintiKutusu({super.key, required this.anahtar, required this.child});

  final String anahtar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(anahtar),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      builder: (context, v, ic) {
        // Sönümlenen sinüs — CSS'teki 4 adımlı ±5px sarsıntının sürekli karşılığı.
        final kayma = (1 - v) * 5 * math.sin(v * 12);
        return Transform.translate(offset: Offset(kayma, 0), child: ic);
      },
      child: child,
    );
  }
}
