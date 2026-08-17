// Sipariş ekranlarının PAYLAŞILAN parçaları — yeni sipariş (`.ys-*`), sipariş detayı (`.sd-*`,
// `.sdx-*`) ve düzenleme sheet'i aynı kart/satır/toplam dilini kullanıyor; tek yerde duruyorlar.
// Kaynak: Sipario.html 259–331 + s-siparisler.jsx.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

// Detay/özet kartı ve serbest satır sheet'i ayrı dosyada (500 satır sınırı); çağıranlar tek
// `order_parts.dart` import'uyla ikisine de erişsin. Satır notu da öyle: rozet + normalleştirme
// + girme sheet'i `satir_notu.dart`ta birlikte durur.
//
// Sepet satırı (`.ys-satir`) ve alt toplam çubuğu (`.ys-alt`) de aynı gerekçeyle ayrıldı: bu dosya
// 582 satıra çıkmıştı. İkisi de kendi içinde kapalı parçalar — burada kalanlarla (taslak satır,
// adım göstergesi, ekleme düğmesi, boş durum) tek bir sembol paylaşmıyorlardı.
export 'order_alt_cubugu.dart';
export 'order_sd_parts.dart';
export 'order_sepet_satiri.dart';
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
///
/// GEÇİLMİŞ ROZETLER DOKUNULABİLİR ([onAdim] verilirse). Şerit bir sekme çubuğuna benziyor ve
/// kullanıcı ona öyle davranıyordu: "Kalemler"e basıp geri dönmeyi deniyor, hiçbir şey olmuyordu.
/// Düğmeye benzeyen ama çalışmayan bir yüzey, arayüzün geri kalanına duyulan güveni de düşürür.
/// İLERİ atlama YOK: henüz geçilmemiş adım eksik veriyle açılırdı (müşterisiz kalem, boş sepetle
/// özet); ileri gitmenin tek yolu adımın kendi birincil düğmesidir.
class AdimGostergesi extends StatelessWidget {
  const AdimGostergesi({
    super.key,
    required this.adimlar,
    required this.adim,
    this.onAdim,
  });

  final List<String> adimlar;
  final int adim;

  /// 1-tabanlı adım numarasıyla çağrılır. null dönen/verilmeyen adımlar dokunulamaz çizilir.
  final ValueChanged<int>? onAdim;

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
                onTap: (onAdim != null && adim > i + 1) ? () => onAdim!(i + 1) : null,
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
    this.onTap,
  });

  final String etiket;
  final int sira;
  final bool aktif;
  final bool gecildi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final metinRenk = gecildi ? t.ok : (aktif ? t.accent : t.muted);
    final zemin = aktif ? t.accentSoft : t.surface;
    final noktaZemin = gecildi ? t.ok : (aktif ? t.accent : t.line2);

    return Semantics(
      button: onTap != null,
      selected: aktif,
      label: etiket,
      child: SipDokun(
        onTap: onTap,
        zemin: zemin,
        basiliZemin: t.surface2,
        radius: SipRadius.brHap,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.xs, vertical: 7),
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

