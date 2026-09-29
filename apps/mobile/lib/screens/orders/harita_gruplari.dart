// HARİTADA KİŞİ GRUPLARI — patron hem kendi siparişlerini hem kuryelerinkini AYRIŞTIRILMIŞ
// görür (kullanıcı kararı 2026-09-29).
//
// ══ AYRIŞTIRMA NASIL GÖRÜNÜR ════════════════════════════════════════════════════════════════
//  • RENK: her kişinin durakları kendi renginde; kuryenin canlı konum pini de aynı renkte.
//    Patron "mavi pinler Ali'nin" diye okur, pine dokunmadan kimde olduğunu bilir.
//  • NUMARA: her kişinin rotası 1'den başlar. Tek sıra (1..20) üç kişinin rotasını tek rota
//    gibi gösterirdi; oysa Ali'nin 1. durağı ile Veli'nin 1. durağı aynı anda gidilecek yerlerdir.
//  • ÇİZGİ: her kişinin kesikli rotası kendi renginde, kendi başlangıcından (patron: telefonu,
//    kurye: canlı konumu). Gerçek yol çizgisi yalnız TEK kişi gösterilirken istenir — her grup
//    için ayrı paralı çağrı açmamak için.
//  • ŞERİT: üstte kişi çipleri. Dokunulan çip haritayı yalnız o kişiye indirger; "Hepsi" geri
//    açar. Oto sıralama da seçili çipe uyar (`oto_siralama.dart`).
//
// SAF KURULUM: [grupluIcerik] widget kurmadan birim testiyle sınanır.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'harita_icerigi.dart';
import 'harita_sorgulari.dart';
import 'siparis_gruplari.dart';

/// Gösterilen gruplardan haritanın içeriğini kurar.
///
/// [renkler] grup anahtarı → renk. [kuryeler] canlı kuryeler (renkleri zaten verilmiş).
/// Tek grup gösteriliyorsa rota tek çizgidir (yol çizgisi [yol] ile birlikte) ve o grup bir
/// kuryeninse rotanın başı kuryenin TAZE konumudur. Çok grupta her grubun kendi kesikli çizgisi.
HaritaIcerigi grupluIcerik({
  required List<SiparisGrubu<HaritaDuragi>> gruplar,
  required Map<String, Color> renkler,
  HaritaNoktasi? cihaz,
  List<KuryeIsareti> kuryeler = const [],
  String? seciliDurakId,
  List<HaritaNoktasi>? yol,
}) {
  HaritaNoktasi? basi(SiparisGrubu<HaritaDuragi> g) {
    if (g.kendi) return null; // cihaz — HaritaIcerigi.rotaBaslangici kendisi seçer
    for (final k in kuryeler) {
      if (k.id == g.kullaniciId && k.taze) return k.nokta;
    }
    return null;
  }

  final duraklar = [
    for (final g in gruplar)
      for (var i = 0; i < g.ogeler.length; i++)
        DurakIsareti(
          id: g.ogeler[i].orderId,
          no: i + 1,
          nokta: HaritaNoktasi(g.ogeler[i].lat, g.ogeler[i].lng),
          ad: g.ogeler[i].baslik,
          // Tek grupta renk yalnız kuryeye odaklanıldıysa değişir ("Siz" temanın vurgusudur)
          // ve grup anahtarı boştur (`DurakIsareti.grup` sözleşmesi).
          renk: g.kendi && gruplar.length == 1 ? null : renkler[g.anahtar],
          grup: gruplar.length > 1 ? g.anahtar : '',
        ),
  ];

  if (gruplar.length <= 1) {
    final g = gruplar.isEmpty ? null : gruplar.single;
    return HaritaIcerigi(
      duraklar: duraklar,
      cihaz: cihaz,
      kuryeler: kuryeler,
      seciliDurakId: seciliDurakId,
      yol: yol,
      rotaBasi: g == null ? null : basi(g),
      rotaRengi: g == null || g.kendi ? null : renkler[g.anahtar],
    );
  }

  // Çok grup: her grubun başlangıcı + durakları. Kendi grubunun başı cihazdır ama yalnız
  // duraklara yakınsa (evdeki patron rotanın başı değildir, `rotaBaslangici` kuralı).
  List<HaritaNoktasi> cizgi(SiparisGrubu<HaritaDuragi> g) {
    final noktalar = [for (final d in g.ogeler) HaritaNoktasi(d.lat, d.lng)];
    final bas = g.kendi
        ? HaritaIcerigi(
            cihaz: cihaz,
            duraklar: [
              for (final d in g.ogeler)
                DurakIsareti(id: d.orderId, no: 0, nokta: HaritaNoktasi(d.lat, d.lng), ad: ''),
            ],
          ).rotaBaslangici
        : basi(g);
    return [?bas, ...noktalar];
  }

  return HaritaIcerigi(
    duraklar: duraklar,
    cihaz: cihaz,
    kuryeler: kuryeler,
    seciliDurakId: seciliDurakId,
    cokluRota: true,
    rotalar: [
      for (final g in gruplar) HaritaRotasi(noktalar: cizgi(g), renk: renkler[g.anahtar]),
    ],
  );
}

/// Üstteki kişi şeridi: "Hepsi" + her grup (renk noktası, ad, durak sayısı).
class HaritaGrupSeridi extends StatelessWidget {
  const HaritaGrupSeridi({
    super.key,
    required this.gruplar,
    required this.renkler,
    required this.secili,
    required this.onSec,
  });

  final List<SiparisGrubu<HaritaDuragi>> gruplar;
  final Map<String, Color> renkler;

  /// Seçili grup anahtarı; null = hepsi.
  final String? secili;
  final ValueChanged<String?> onSec;

  @override
  Widget build(BuildContext context) {
    final toplam = gruplar.fold<int>(0, (s, g) => s + g.ogeler.length);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.govde, vertical: 7),
        children: [
          _GrupCipi(
            etiket: 'Hepsi',
            sayi: toplam,
            secili: secili == null,
            onTap: () => onSec(null),
          ),
          for (final g in gruplar)
            _GrupCipi(
              key: ValueKey('harita-grup-${g.anahtar}'),
              etiket: g.ad,
              sayi: g.ogeler.length,
              renk: renkler[g.anahtar],
              secili: secili == g.anahtar,
              // Seçili çipe yeniden dokunmak seçimi kaldırır — "Hepsi"ni aramaya gerek kalmaz.
              onTap: () => onSec(secili == g.anahtar ? null : g.anahtar),
            ),
        ],
      ),
    );
  }
}

class _GrupCipi extends StatelessWidget {
  const _GrupCipi({
    super.key,
    required this.etiket,
    required this.sayi,
    required this.secili,
    required this.onTap,
    this.renk,
  });

  final String etiket;
  final int sayi;
  final bool secili;
  final VoidCallback onTap;

  /// Grubun rengi — noktası çizilir. "Hepsi"nde null.
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(right: SipSpace.sm),
      child: Semantics(
        button: true,
        selected: secili,
        child: SipDokun(
          onTap: onTap,
          zemin: secili ? t.ink : t.surface,
          basiliZemin: t.surface2,
          radius: SipRadius.brHap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (renk != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                etiket,
                style: SipText.metin(12.5, w: 700).copyWith(color: secili ? t.bg : t.ink),
              ),
              const SizedBox(width: 5),
              Text(
                '$sayi',
                style: SipText.metin(12, w: 600).copyWith(color: secili ? t.bg : t.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
