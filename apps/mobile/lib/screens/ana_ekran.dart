// ANA EKRAN — s-ana.jsx + Sipario.html `.ana-*`, `.bento*`, `.akt-*`.
//
// Koyu mürekkep hero (selam + SAHİP ADI + menü + senkron çipi) · bento özet ızgarası · birincil
// CTA · "Son aktivite" listesi. Rakamlar GERÇEK veriden gelir (bkz. shell/ana_ozet.dart) — demo
// sabiti yok.
//
// HERO'DA İŞLETME ADI DEĞİL SAHİP ADI YAZAR: `s-ana.jsx:21` `{ISLETME.sahip}` ('Mehmet Usta').
// CSS sınıfı `.ana-isletme` adını taşır ama içeriği sahiptir; işletme adı ÇEKMECEDE kullanılır
// (`s-bilesenler.jsx:100`). Selamın ("Günaydın") altına firma unvanı değil kişinin adı gelir.
//
// 4. bento kutusu "Son Arama" (`s-ana.jsx:45`): verisi `cagri/cagri_gunlugu.dart`taki
// [sonAramaAkisi]. Kutuya dokunmanın kuralı `s-uygulama.jsx:90` (`onAramaAc`) — numara
// KAYITLIYSA müşteri detayı, KAYITSIZSA çağrı kartı. Kararı bu ekran vermez, [onArama] ile
// kabuğa devreder (çağrı günlüğü ne müşteri ekranını ne çağrı kartını tanır).

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../sync/sync_service.dart';
import '../theme/components/atoms.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'cagri/cagri_model.dart';
import 'shell/alt_nav.dart';
import 'shell/ana_bento.dart';
import 'shell/ana_ozet.dart';

class AnaEkran extends StatelessWidget {
  const AnaEkran({
    super.key,
    required this.db,
    required this.sahipAdi,
    required this.onMenu,
    required this.onSekme,
    required this.onYeniSiparis,
    required this.onArama,
    required this.onSiparisAc,
    required this.onBorclular,
    this.sonSenkron,
    this.sonSenkronAt,
  });

  final AppDatabase db;

  /// Selamın altındaki ad — kullanıcının kendi adı (tasarım `ISLETME.sahip`).
  final String sahipAdi;

  final VoidCallback onMenu;
  final ValueChanged<SipSekme> onSekme;
  final VoidCallback onYeniSiparis;

  /// "Son Arama" kutusuna dokunulduğunda. Kayıtlı/kayıtsız ayrımını kabuk yapar.
  final ValueChanged<AramaKaydi> onArama;

  /// "Son aktivite" satırına dokunulduğunda: sipariş sekmesine geçilir VE detay açılır
  /// (`s-uygulama.jsx:89` — `setTab('siparis')` + `setSipDetay(veri)`). Detay sheet'i sipariş
  /// katmanının işi; bu ekran yalnız kimliği devreder.
  final ValueChanged<String> onSiparisAc;

  /// "Borçlular" bento kutusu — borçlu müşteriler ekranını kabuk açar (yazma yetkisi orada
  /// bilinir; bu ekran yalnız niyeti devreder, `onArama`/`onSiparisAc` deseninin aynısı).
  final VoidCallback onBorclular;

  final SyncOutcome? sonSenkron;
  final DateTime? sonSenkronAt;

  static String selam(DateTime simdi) {
    if (simdi.hour < 12) return 'Günaydın';
    if (simdi.hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Hero(
          sahipAdi: sahipAdi,
          onMenu: onMenu,
          sonSenkron: sonSenkron,
          sonSenkronAt: sonSenkronAt,
        ),
        Expanded(
          child: StreamBuilder<AnaOzet>(
            stream: watchAnaOzet(db),
            builder: (context, snap) {
              final o = snap.data ?? const AnaOzet();
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    SipSpace.govde, SipSpace.x3, SipSpace.govde, SipSpace.x4),
                children: [
                  AnaBento(
                    db: db,
                    ozet: o,
                    onSekme: onSekme,
                    onArama: onArama,
                    onBorclular: onBorclular,
                  ),
                  const SizedBox(height: SipSpace.xl),
                  _Cta(onTap: onYeniSiparis),
                  SipBolumBaslik('Son aktivite', ustBosluk: SipSpace.x4),
                  _SonAktivite(db: db, onSiparisAc: onSiparisAc),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// CSS `.ana-hero` — alt köşeleri r4 yuvarlak koyu blok.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.sahipAdi,
    required this.onMenu,
    required this.sonSenkron,
    required this.sonSenkronAt,
  });

  final String sahipAdi;
  final VoidCallback onMenu;
  final SyncOutcome? sonSenkron;
  final DateTime? sonSenkronAt;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        SipSpace.x5,
        SipSpace.x6 + MediaQuery.paddingOf(context).top,
        SipSpace.x5,
        SipSpace.x4,
      ),
      decoration: BoxDecoration(color: t.hero, borderRadius: SipRadius.heroEtek),
      child: DefaultTextStyle(
        style: TextStyle(color: SipTokens.onHero, fontFamily: sipFontBody),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AnaEkran.selam(DateTime.now()),
                        style: SipText.selam.copyWith(color: SipTokens.onHeroMid),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sahipAdi,
                        style: SipText.isletme.copyWith(color: SipTokens.onHero),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SipSpace.xl),
                SipIkonButon(
                  ikon: SipIcons.menu,
                  cap: 40,
                  ikonBoyut: 20,
                  kalinlik: 2,
                  zemin: SipTokens.onHeroFill,
                  renk: SipTokens.onHero,
                  etiket: 'Menü',
                  onTap: onMenu,
                ),
              ],
            ),
            const SizedBox(height: SipSpace.x3),
            _SyncCipi(sonuc: sonSenkron, zaman: sonSenkronAt),
          ],
        ),
      ),
    );
  }
}

/// CSS `.ana-sync` — renkli nokta + durum metni.
class _SyncCipi extends StatelessWidget {
  const _SyncCipi({required this.sonuc, required this.zaman});

  final SyncOutcome? sonuc;
  final DateTime? zaman;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final ok = sonuc?.ok ?? false;
    final saat = zaman == null
        ? ''
        : ' · ${zaman!.hour.toString().padLeft(2, '0')}:'
            '${zaman!.minute.toString().padLeft(2, '0')}';
    final metin = sonuc == null
        ? 'Senkron bekleniyor'
        : (ok ? 'Senkron güncel$saat' : 'Bağlantı yok · tekrar denenecek');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.sm),
      decoration: const BoxDecoration(
        color: SipTokens.onHeroFill,
        borderRadius: SipRadius.brHap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: sonuc == null
                  ? SipTokens.onHeroSoft
                  : (ok ? SipTokens.heroDot : t.danger),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(metin, style: SipText.syncCip.copyWith(color: SipTokens.onHeroMid)),
        ],
      ),
    );
  }
}

/// CSS `.ana-cta` — hero zeminli birincil eylem.
class _Cta extends StatelessWidget {
  const _Cta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.hero,
      basiliZemin: t.hero2,
      radius: SipRadius.br3,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x3, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            child: SipIcon(SipIcons.plus, boyut: 20, kalinlik: 2.4, renk: t.accentInk),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Yeni Sipariş',
              style: SipText.anaCta.copyWith(color: SipTokens.onHero),
            ),
          ),
          const SipIcon(SipIcons.chevR,
              boyut: 18, kalinlik: 2.2, renk: SipTokens.onHeroMid),
        ],
      ),
    );
  }
}

/// CSS `.akt-list` / `.ana-bos` — son teslim edilen siparişler.
class _SonAktivite extends StatelessWidget {
  const _SonAktivite({required this.db, required this.onSiparisAc});

  final AppDatabase db;
  final ValueChanged<String> onSiparisAc;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<List<SonHareket>>(
      stream: watchSonHareketler(db),
      builder: (context, snap) {
        final list = snap.data ?? const <SonHareket>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, SipSpace.md, 2, SipSpace.md),
            child: Text(
              'Bugün henüz hareket yok.',
              style: SipText.metin(13).copyWith(color: t.muted),
            ),
          );
        }
        return Column(
          children: [
            for (final h in list)
              Padding(
                padding: const EdgeInsets.only(bottom: SipSpace.sm),
                child: SipDokun(
                  onTap: () => onSiparisAc(h.siparisId),
                  zemin: t.surface,
                  radius: SipRadius.br2,
                  padding: const EdgeInsets.symmetric(
                      horizontal: SipSpace.x2, vertical: SipSpace.xl),
                  child: Row(
                    children: [
                      SipIkonKutu(
                        ikon: SipIcons.check,
                        cap: 30,
                        ikonBoyut: 15,
                        kalinlik: 2.4,
                        zemin: t.okSoft,
                        renk: t.ok,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              h.musteriAd,
                              style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            // Alt satır ÜRÜN DÖKÜMÜ + ödeme tipidir (`s-ana.jsx:67`
                            // `{siparisOzet(o)} · {ODEME_TIPLERI[o.odeme].label}`), saat DEĞİL:
                            // "bugün ne sattım"ın cevabı saatte değil kalemde.
                            Text(
                              [h.satirOzeti, odemeEtiketi(h.odemeTipi)]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style: SipText.metin(11.5).copyWith(color: t.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SipSpace.lg),
                      Text(
                        sipTutar(h.tutarKurus),
                        style: SipText.tutar(13).copyWith(color: t.ink),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
