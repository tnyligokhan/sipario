// Alt navigasyon — s-bilesenler.jsx `AltNav` + Sipario.html `.altnav*`.
//
// Hero zeminli hap; 5 yuva: Ana · Müşteri · [FAB] · Sipariş · Gün Sonu. Seçili sekme genişler
// (CSS `flex: 1 → 2`, geçiş .26s) ve etiketi görünür olur. Material `NavigationBar` KULLANILMAZ:
// tasarımın hap gövdesi, ortadaki taşan FAB'ı ve genişleyen sekmesi onunla kurulamıyor.
//
// FAB TEK DOKUNUŞLA YENİ SİPARİŞE GİDER (`s-bilesenler.jsx:55` — className sabit, durum yok).
// Bir ara sürümde CSS'teki `.fabpop*` ailesine bakılıp açılır menü + 45° dönüş uygulanmıştı;
// o kuralları HİÇBİR JSX kullanmıyor (ölü CSS, kupon sınıflarıyla aynı kalıp) — kaldırıldı.
//
// YUVA SAYISI ROLE BAĞLI DEĞİLDİR: tasarımda `AltNav` her zaman 5 yuvadır, rol yalnız çekmecenin
// YÖNETİM bölümünü etkiler. Gün Sonu yuvası kuryede de kalır (kullanıcı kararı, 2026-07-26);
// sağ grup tek sekmeye düşünce hap navigasyonun simetrisi de bozuluyordu.

import 'package:flutter/material.dart';

import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Kabuğun ana sekmeleri. Sıra tasarımdaki soldan sağa sıradır.
enum SipSekme { ana, musteri, siparis, gunSonu }

class SipAltNav extends StatelessWidget {
  const SipAltNav({
    super.key,
    required this.aktif,
    required this.onSec,
    required this.onYeniSiparis,
  });

  final SipSekme aktif;
  final ValueChanged<SipSekme> onSec;

  /// FAB'a dokunma. null ise FAB **çizilir ama pasiftir** (abonelik kilidi): tasarımın kilit
  /// dalında da `AltNav` tam çizilir (`s-uygulama.jsx:87`), FAB'ı silmek yerleşimi atlatırdı.
  final VoidCallback? onYeniSiparis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    return Container(
      margin: EdgeInsets.fromLTRB(
        SipSpace.x3,
        SipSpace.lg,
        SipSpace.x3,
        SipSpace.x5 + MediaQuery.paddingOf(context).bottom,
      ),
      padding: const EdgeInsets.all(SipSpace.sm),
      decoration: BoxDecoration(color: t.hero, borderRadius: SipRadius.brHap),
      child: Row(
        children: [
          Expanded(
            child: _Grup(
              sekmeler: const [SipSekme.ana, SipSekme.musteri],
              aktif: aktif,
              onSec: onSec,
            ),
          ),
          const SizedBox(width: SipSpace.sm),
          _Fab(onTap: onYeniSiparis),
          const SizedBox(width: SipSpace.sm),
          Expanded(
            child: _Grup(
              sekmeler: const [SipSekme.siparis, SipSekme.gunSonu],
              aktif: aktif,
              onSec: onSec,
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.altnav-grup` — iki sekmelik yarım. Seçili olan 2/3, diğeri 1/3 genişlik alır
/// (CSS `flex: 2` / `flex: 1`); geçiş [AnimatedContainer] ile .26s.
class _Grup extends StatelessWidget {
  const _Grup({required this.sekmeler, required this.aktif, required this.onSec});

  final List<SipSekme> sekmeler;
  final SipSekme aktif;
  final ValueChanged<SipSekme> onSec;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kutu) {
        final kullanilabilir = kutu.maxWidth - SipSpace.sm; // aradaki boşluk
        final seciliVar = sekmeler.contains(aktif);
        return Row(
          children: [
            for (var i = 0; i < sekmeler.length; i++) ...[
              if (i > 0) const SizedBox(width: SipSpace.sm),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: const Cubic(0.2, 0.8, 0.2, 1),
                width: !seciliVar
                    ? kullanilabilir / 2
                    : (sekmeler[i] == aktif ? kullanilabilir * 2 / 3 : kullanilabilir / 3),
                child: _Sekme(
                  sekme: sekmeler[i],
                  secili: sekmeler[i] == aktif,
                  onSec: onSec,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// CSS `.altnav-b` — ikon (+ seçiliyken etiket), hap zemin.
class _Sekme extends StatelessWidget {
  const _Sekme({required this.sekme, required this.secili, required this.onSec});

  final SipSekme sekme;
  final bool secili;
  final ValueChanged<SipSekme> onSec;

  static ({String ikon, String etiket}) bilgi(SipSekme s) => switch (s) {
        SipSekme.ana => (ikon: SipIcons.home, etiket: 'Ana'),
        SipSekme.musteri => (ikon: SipIcons.users, etiket: 'Müşteri'),
        SipSekme.siparis => (ikon: SipIcons.list, etiket: 'Sipariş'),
        SipSekme.gunSonu => (ikon: SipIcons.wallet, etiket: 'Gün Sonu'),
      };

  @override
  Widget build(BuildContext context) {
    final b = bilgi(sekme);
    return Semantics(
      button: true,
      selected: secili,
      label: b.etiket,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSec(sekme),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
            color: secili ? SipTokens.onHeroFill2 : Colors.transparent,
            borderRadius: SipRadius.brHap,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SipIcon(
                b.ikon,
                boyut: 21,
                kalinlik: secili ? 2.3 : 1.9,
                renk: secili ? SipTokens.onHero : SipTokens.onHeroIcon,
              ),
              if (secili)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: Text(
                      b.etiket,
                      style: SipText.metin(12.5, w: 700)
                          .copyWith(color: SipTokens.onHero),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CSS `.altnav-fab` — accent dolgulu daire, doğrudan yeni siparişe gider.
/// [onTap] null iken sönük ve dokunulamaz çizilir (yerleşim aynı kalır).
class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final pasif = onTap == null;
    return Semantics(
      button: true,
      enabled: !pasif,
      label: 'Yeni sipariş',
      child: Opacity(
        opacity: pasif ? 0.4 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            child: SipIcon(SipIcons.plus, boyut: 26, kalinlik: 2.3, renk: t.accentInk),
          ),
        ),
      ),
    );
  }
}

