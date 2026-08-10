// KURYE YETKİ ekranlarının PAYLAŞILAN parçaları — iki kip de bunları kullanır.
// Barrel: `../isletme_atomlari.dart` (ekranlar oradan import eder).
//
// İKİ KİP VARDIR ve aynı 13 satırı gösterirler:
//   • VARSAYILAN kipi (`tenant_settings`) — iki durumlu: açık / kapalı.
//   • KİŞİ kipi (`users` ezmeleri)        — ÜÇ durumlu: devral / açık / kapalı.
// Kategori kartının kabuğu (ikon, başlık, "N/13 Açık" rozeti) iki kipte de AYNIDIR; bu yüzden
// satır içeriğini `List<Widget>` olarak dışarıdan alır — kabuğu kopyalamak, iki kipin zamanla
// birbirinden görsel olarak ayrışması demekti.

import 'package:flutter/material.dart';

import '../../../theme/components/atoms.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Üç durumlu ezme seçimi
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Kişiye özel yetki satırının üç durumu. `KuryeIzinEzmeleri` alanlarındaki `bool?` ile birebir
/// eşleşir: [varsayilan] ↔ `null`, [acik] ↔ `true`, [kapali] ↔ `false`.
enum YetkiEzmeDurumu { varsayilan, acik, kapali }

/// `bool?` → durum. `null` DEVRALMA demektir, "kapalı" değil — ikisini karıştırmak, bayi
/// varsayılanını değiştirdiğinde kuryenin yetkisinin neden değişmediğini açıklanamaz kılar.
YetkiEzmeDurumu yetkiEzmeDurumu(bool? ezme) => switch (ezme) {
      null => YetkiEzmeDurumu.varsayilan,
      true => YetkiEzmeDurumu.acik,
      false => YetkiEzmeDurumu.kapali,
    };

/// Durum → `bool?` (yazma yönü).
bool? yetkiEzmeDegeri(YetkiEzmeDurumu durum) => switch (durum) {
      YetkiEzmeDurumu.varsayilan => null,
      YetkiEzmeDurumu.acik => true,
      YetkiEzmeDurumu.kapali => false,
    };

/// Üç durumlu seçim rayı — CSS `.segtab` dilinin üç hücreli hâli.
///
/// Her hücrenin SABİT bir [Key]'i vardır (`ezme-<anahtar>-varsayilan|acik|kapali`): ekranda
/// 13 satır × 3 hücre = 39 aynı etiketli hücre bulunur ve testin doğru olana dokunabilmesinin
/// tek güvenilir yolu anahtardır (metinle arama 13 eşleşme döndürür).
class UcDurumSecim extends StatelessWidget {
  const UcDurumSecim({
    super.key,
    required this.anahtar,
    required this.durum,
    required this.onSec,
  });

  /// Yetki satırının kimliği (ör. `tahsilat`) — hücre anahtarlarının ön eki.
  final String anahtar;

  final YetkiEzmeDurumu durum;
  final ValueChanged<YetkiEzmeDurumu> onSec;

  static const _etiketler = <YetkiEzmeDurumu, String>{
    YetkiEzmeDurumu.varsayilan: 'Varsayılan',
    YetkiEzmeDurumu.acik: 'Açık',
    YetkiEzmeDurumu.kapali: 'Kapalı',
  };

  static const _anahtarEkleri = <YetkiEzmeDurumu, String>{
    YetkiEzmeDurumu.varsayilan: 'varsayilan',
    YetkiEzmeDurumu.acik: 'acik',
    YetkiEzmeDurumu.kapali: 'kapali',
  };

  /// Testlerin dokunacağı hücre anahtarı — finder'ı elle kurmak yerine buradan üretilir.
  static Key hucreAnahtari(String anahtar, YetkiEzmeDurumu durum) =>
      Key('ezme-$anahtar-${_anahtarEkleri[durum]}');

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.brHap),
      child: Row(
        children: [
          for (final d in YetkiEzmeDurumu.values)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: d == YetkiEzmeDurumu.varsayilan ? 0 : 4),
                child: GestureDetector(
                  key: hucreAnahtari(anahtar, d),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSec(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: d == durum ? t.hero : Colors.transparent,
                      borderRadius: SipRadius.brHap,
                    ),
                    child: Text(
                      _etiketler[d]!,
                      style: SipText.metin(12.5, w: d == durum ? 700 : 600).copyWith(
                        color: d == durum ? SipTokens.onHero : t.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Rozet ve kategori kabuğu
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Hap biçimli küçük durum rozeti (CSS `.rozet`) — "Varsayılan · kapalı", "özel yetki", "3/13 Açık".
class YetkiRozeti extends StatelessWidget {
  const YetkiRozeti({
    super.key,
    required this.metin,
    required this.renk,
    required this.zemin,
    this.punto = 10.5,
  });

  final String metin;
  final Color renk;
  final Color zemin;
  final double punto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.brHap),
      child: Text(
        metin,
        style: SipText.metin(punto, w: 700).copyWith(color: renk),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Kategoriye göre ikon seçici — iki kip de aynı ikonları kullanır.
String yetkiKategoriIkonu(String kategori) => switch (kategori) {
      'Sipariş & Teslimat' => SipIcons.truck,
      'Kasa & Tahsilat' => SipIcons.wallet,
      'Gün Sonu & Devir' => SipIcons.clock,
      'Müşteri & KVKK' => SipIcons.phone,
      'Ürün & Stok' => SipIcons.box,
      'Çağrı & Ayarlar' => SipIcons.settings,
      _ => SipIcons.settings,
    };

/// Bir yetki kategorisinin kartı — ikon + başlık + sağ rozet + ayraçlı satırlar.
///
/// Satırları KENDİ üretmez: varsayılan kipinde iki durumlu toggle, kişi kipinde üç durumlu
/// seçim gelir. Kabuk ortak, içerik kipe özeldir.
class YetkiKategoriKarti extends StatelessWidget {
  const YetkiKategoriKarti({
    super.key,
    required this.kategoriAdi,
    required this.rozetMetni,
    required this.rozetVurgulu,
    required this.satirlar,
  });

  final String kategoriAdi;

  /// Sağ üstteki özet (ör. "2/4 Açık").
  final String rozetMetni;

  /// Rozet vurgulu mu (en az bir yetki açık) — kapalıyken sessiz gri.
  final bool rozetVurgulu;

  final List<Widget> satirlar;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: SipSpace.md),
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: SipSpace.xs),
            child: Row(
              children: [
                SipIkonKutu(
                  ikon: yetkiKategoriIkonu(kategoriAdi),
                  cap: 28,
                  ikonBoyut: 14,
                  kalinlik: 2.0,
                  radius: SipRadius.hap,
                  zemin: t.accentSoft,
                  renk: t.accent,
                ),
                const SizedBox(width: SipSpace.md),
                Expanded(
                  child: Text(
                    kategoriAdi,
                    style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  ),
                ),
                YetkiRozeti(
                  metin: rozetMetni,
                  renk: rozetVurgulu ? t.ok : t.muted,
                  zemin: rozetVurgulu ? t.okSoft : t.surface2,
                ),
              ],
            ),
          ),
          const SizedBox(height: SipSpace.xs),
          for (var i = 0; i < satirlar.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm),
                child: Divider(color: t.line, height: 1),
              ),
            satirlar[i],
          ],
        ],
      ),
    );
  }
}
