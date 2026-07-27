// Çekmece menü — s-bilesenler.jsx `Cekmece` + Sipario.html `.cek*`, `.lst-*`.
//
// Hero zeminli, soldan açılan panel; sağ köşeleri 26 yuvarlak. Material `Drawer` KULLANILMAZ:
// tasarımın perde tonu, köşe yarıçapı ve alt eylem çubuğu onunla kurulamıyor.
//
// ROL KAPISI (K2 — pazarlıksız): `kurye` rolünde YÖNETİM bölümü ve istatistik kartları HİÇ
// çizilmez (koşullu görünürlük değil, hiç render edilmez).
//
// MENÜ bölümü DAİMA dört satırdır (`s-bilesenler.jsx:77-82`). Dördüncü satırın yalnız ETİKETİ
// role göre değişir: yöneticide tasarımdaki "Gün Sonu & Kasa Devri", kuryede "Kasa Devri".
// Gerekçe: kullanıcı kararı (2026-07-26) kasa devri satırının yalnız kuryede kalmasıydı; ayrı
// bir satır olarak bırakılsaydı kuryede iki satır AYNI yere (Gün Sonu sekmesi) gidecekti —
// kasa devri ekranı kaldırıldığından ayrı bir hedefi kalmadı.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'alt_nav.dart';
import 'cekmece_istatistik.dart';

/// Çekmeceden açılan tam-sayfa hedefler (sekme DEĞİL — üstüne push edilirler).
enum CekmeceGiris { urunler, kuryeler, muaf, ayarlar, sihirbaz }

class SipCekmece extends StatelessWidget {
  const SipCekmece({
    super.key,
    required this.acik,
    required this.onKapat,
    required this.isletmeAdi,
    required this.rol,
    required this.aktif,
    required this.onTab,
    required this.onGiris,
    required this.onCikis,
    required this.onDestek,
    this.sonSenkron,
    this.urunlerGorunur = true,
    this.lisansBitisi,
    this.otoSiralamaHakki,
    this.otoSiralamaAylik,
  });

  final bool acik;
  final VoidCallback onKapat;

  final String isletmeAdi;

  /// `patron` | `operator` | `kurye` | null.
  final String? rol;

  final SipSekme aktif;
  final ValueChanged<SipSekme> onTab;
  final ValueChanged<CekmeceGiris> onGiris;
  final VoidCallback onCikis;
  final VoidCallback onDestek;

  final DateTime? sonSenkron;

  final bool urunlerGorunur;

  /// Abonelik bitişi (SyncMeta `validUntilIso`). null iken kart "bilinmiyor" hâlinde çizilir.
  final DateTime? lisansBitisi;

  /// Oto-sıralama hakkı. Sunucu bu alanı henüz göndermiyor; null iken kart çizilmez
  /// (uydurma veri basılmaz).
  final int? otoSiralamaHakki;
  final int? otoSiralamaAylik;

  bool get _kurye => rol == 'kurye';

  static String rolAdi(String? rol) => switch (rol) {
        'patron' => 'Yönetici',
        'operator' => 'Operatör',
        'kurye' => 'Kurye',
        _ => 'Tek kişilik',
      };

  @override
  Widget build(BuildContext context) {
    final genislik = (MediaQuery.sizeOf(context).width * 0.84).clamp(240.0, 330.0);
    return IgnorePointer(
      ignoring: !acik,
      child: Stack(
        children: [
          // CSS .cek-scrim
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onKapat,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                color: acik ? SipTokens.scrim : Colors.transparent,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: const Cubic(0.2, 0.8, 0.2, 1),
            left: acik ? 0 : -genislik,
            top: 0,
            bottom: 0,
            width: genislik,
            child: _Panel(cekmece: this),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.cekmece});

  final SipCekmece cekmece;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final c = cekmece;
    return Material(
      color: t.hero,
      borderRadius: SipRadius.cekmece,
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle(
        style: TextStyle(color: SipTokens.onHero, fontFamily: sipFontBody),
        child: Column(
          children: [
            _Baslik(cekmece: c),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(SipSpace.x2, SipSpace.sm, SipSpace.x2, SipSpace.x2),
                children: [
                  const _Bolum('Menü'),
                  _Satir(
                    ikon: SipIcons.home,
                    etiket: 'Ana Sayfa',
                    secili: c.aktif == SipSekme.ana,
                    onTap: () => c.onTab(SipSekme.ana),
                  ),
                  _Satir(
                    ikon: SipIcons.users,
                    etiket: 'Müşteriler',
                    secili: c.aktif == SipSekme.musteri,
                    onTap: () => c.onTab(SipSekme.musteri),
                  ),
                  _Satir(
                    ikon: SipIcons.list,
                    etiket: 'Siparişler',
                    secili: c.aktif == SipSekme.siparis,
                    onTap: () => c.onTab(SipSekme.siparis),
                  ),
                  // Dördüncü MENÜ satırı: kuryede kendi devri, yöneticide tasarımdaki birleşik
                  // etiket. İkisi de AYNI sekmeye gider (dosya başındaki gerekçe).
                  _Satir(
                    ikon: c._kurye ? SipIcons.hand : SipIcons.wallet,
                    etiket: c._kurye ? 'Kasa Devri' : 'Gün Sonu & Kasa Devri',
                    secili: c.aktif == SipSekme.gunSonu,
                    onTap: () => c.onTab(SipSekme.gunSonu),
                  ),
                  // ROL KAPISI: kuryede YÖNETİM bölümü ve istatistik kartları HİÇ çizilmez.
                  if (!c._kurye) ...[
                    const _Bolum('Yönetim'),
                    if (c.urunlerGorunur)
                      _Satir(
                        ikon: SipIcons.box,
                        etiket: 'Ürünler',
                        git: true,
                        onTap: () => c.onGiris(CekmeceGiris.urunler),
                      ),
                    _Satir(
                      ikon: SipIcons.truck,
                      etiket: 'Kuryeler',
                      git: true,
                      onTap: () => c.onGiris(CekmeceGiris.kuryeler),
                    ),
                    _Satir(
                      ikon: SipIcons.phoneOff,
                      etiket: 'Muaf Telefonlar',
                      git: true,
                      onTap: () => c.onGiris(CekmeceGiris.muaf),
                    ),
                    CekmeceIstatistikleri(
                      lisansBitisi: c.lisansBitisi,
                      otoSiralamaHakki: c.otoSiralamaHakki,
                      otoSiralamaAylik: c.otoSiralamaAylik,
                    ),
                  ],
                  // Tasarımda UYGULAMA bölümü TEK satırdır: Ayarlar (s-bilesenler.jsx `Cekmece`).
                  // Tema anahtarı, arayan-tanıma kurulumu ve gecikme ölçümleri bir süre burada
                  // geçici olarak duruyordu (Ayarlar ekranı henüz yazılmamıştı); hepsi artık
                  // Ayarlar'ın kendi bölümlerinde yaşıyor, çekmece tasarıma döndü.
                  const _Bolum('Uygulama'),
                  _Satir(
                    ikon: SipIcons.settings,
                    etiket: 'Ayarlar',
                    git: true,
                    onTap: () => c.onGiris(CekmeceGiris.ayarlar),
                  ),
                ],
              ),
            ),
            _AltCubuk(onDestek: c.onDestek, onCikis: c.onCikis),
          ],
        ),
      ),
    );
  }
}

/// CSS `.cek-head` — logo + işletme adı + rol/senkron + kapat.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.cekmece});

  final SipCekmece cekmece;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final c = cekmece;
    final saat = c.sonSenkron == null
        ? 'senkron bekliyor'
        : 'senkron ${_ss(c.sonSenkron!)}';
    return Container(
      padding: EdgeInsets.fromLTRB(
        SipSpace.govde,
        SipSpace.x6 + MediaQuery.paddingOf(context).top,
        SipSpace.govde,
        SipSpace.x3,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SipTokens.onHeroLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(SipSpace.x2),
            ),
            child: SipIcon(SipIcons.phoneCall, boyut: 21, kalinlik: 2.2, renk: t.accentInk),
          ),
          const SizedBox(width: SipSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.isletmeAdi,
                  style: SipText.cekmeceIsletme.copyWith(color: SipTokens.onHero),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${SipCekmece.rolAdi(c.rol)} · $saat',
                  style: SipText.cekmeceRol.copyWith(color: SipTokens.onHeroMid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SipIkonButon(
            ikon: SipIcons.x,
            cap: 34,
            ikonBoyut: 19,
            kalinlik: 2.2,
            zemin: SipTokens.onHeroFill,
            renk: SipTokens.onHeroStrong,
            etiket: 'Kapat',
            onTap: c.onKapat,
          ),
        ],
      ),
    );
  }

  static String _ss(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// CSS `.cek-sec` — bölüm etiketi (BÜYÜK HARF).
class _Bolum extends StatelessWidget {
  const _Bolum(this.etiket);

  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SipSpace.lg, SipSpace.x3, SipSpace.lg, 7),
      child: Text(
        trBuyuk(etiket),
        style: SipText.cekmeceBolum.copyWith(color: SipTokens.onHeroSoft),
      ),
    );
  }
}

/// CSS `.cekr` — menü satırı. [secili] accent dolgulu; [git] sağda chevron gösterir.
class _Satir extends StatelessWidget {
  const _Satir({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.secili = false,
    this.git = false,
  });

  final String ikon;
  final String etiket;
  final VoidCallback onTap;
  final bool secili;
  final bool git;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SipDokun(
        onTap: onTap,
        zemin: secili ? t.accent : Colors.transparent,
        basiliZemin: secili ? t.accent : SipTokens.onHeroFill,
        radius: BorderRadius.circular(13),
        padding: const EdgeInsets.all(SipSpace.xl),
        child: Row(
          children: [
            SipIcon(
              ikon,
              boyut: 19,
              kalinlik: secili ? 2.3 : 1.9,
              renk: secili ? SipTokens.onHero : SipTokens.onHeroMid,
            ),
            const SizedBox(width: SipSpace.xl),
            Expanded(
              child: Text(
                etiket,
                style: SipText.cekmeceSatir.copyWith(
                  color: secili ? SipTokens.onHero : SipTokens.onHeroStrong,
                  fontWeight: secili ? FontWeight.w800 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (git)
              const SipIcon(SipIcons.chevR,
                  boyut: 16, kalinlik: 2, renk: SipTokens.onHeroFaint),
          ],
        ),
      ),
    );
  }
}

/// Tema anahtarı — tasarımda Ayarlar ekranındaydı; o ekran henüz yok, tercih burada yaşıyor.

/// CSS `.cek-alt` — destek düğmesi + çıkış.
class _AltCubuk extends StatelessWidget {
  const _AltCubuk({required this.onDestek, required this.onCikis});

  final VoidCallback onDestek;
  final VoidCallback onCikis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: EdgeInsets.fromLTRB(
        SipSpace.x2,
        SipSpace.lg,
        SipSpace.x2,
        SipSpace.x3 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SipTokens.onHeroLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SipDokun(
              onTap: onDestek,
              zemin: t.accent,
              basiliZemin: t.accent,
              radius: BorderRadius.circular(13),
              olcekle: true,
              padding: const EdgeInsets.all(13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SipIcon(SipIcons.chat, boyut: 17, kalinlik: 2, renk: t.accentInk),
                  const SizedBox(width: SipSpace.md),
                  // Çekmece en fazla 330 geniş; metin ölçeği büyütülmüş cihazda etiket
                  // düğmeyi taşırıyor — esnek bırakılır, kesilirse üç noktayla biter.
                  Flexible(
                    child: Text(
                      'Sipario Destek Hattı',
                      style: SipText.metin(13, w: 700).copyWith(color: t.accentInk),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Semantics(
            button: true,
            label: 'Çıkış Yap',
            child: SipDokun(
              onTap: onCikis,
              zemin: SipTokens.heroCikisFill,
              basiliZemin: SipTokens.heroCikisFill2,
              radius: BorderRadius.circular(13),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: SipIcon(SipIcons.power,
                      boyut: 18, kalinlik: 2.1, renk: SipTokens.heroCikisInk),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
