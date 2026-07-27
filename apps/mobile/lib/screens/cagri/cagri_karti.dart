// Çağrı kartının FLUTTER karşılığı — tasarım s-cagri.jsx + Sipario.html `.cagri-*`.
//
// NEREDE KULLANILIR: uygulama önplandayken gelen çağrı ve Ayarlar'daki "çağrı simülasyonu".
// Telefon çalarken gerçek cihazda çizilen kart BU DEĞİL — o saf Kotlin'dir
// (android/.../CallerCard.kt), çünkü çağrı anında Flutter motoru başlatılmaz. İki kartın
// görünümü elle aynı tutulur; ölçü değiştirirsen Kotlin tarafını da güncelle.
//
// Kartın parçaları 500 satır sınırı için iki dosyaya ayrıldı:
//   `cagri_karti_baslik.dart` → üst şerit + kim satırı
//   `cagri_karti_govde.dart`  → bakiye şeridi + bilgi satırları + eylemler

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'cagri_karti_baslik.dart';
import 'cagri_karti_govde.dart';
import 'cagri_model.dart';

/// Kartın kapanma sebebi. Gezinme kararını çağıran verir — bu ekran `lib/screens/orders`
/// ya da `lib/screens/customers` altındaki ekranları TANIMAZ.
enum CagriEylemi { kapat, siparis, defter, kaydet }

/// Çağrı kartını perde üstünde açar (CSS `.cagri-overlay`).
///
/// Muaf numaralarda kart HİÇ AÇILMAZ ve `null` döner — s-uygulama.jsx'teki kural:
/// muaf listesi son 10 hane üzerinden karşılaştırılır. (Gerçek cihazda aynı kapı native
/// tarafta, `CallerCard.muafMi` ile kurulur; kart çizilmeden önce çalışır.)
Future<CagriEylemi?> cagriKartiGoster(
  BuildContext context, {
  required CagriKisi kisi,
  Iterable<String> muafNumaralar = const [],
  DateTime? baslangic,
}) {
  if (numaraMuafMi(kisi.numara, muafNumaralar)) {
    return Future<CagriEylemi?>.value();
  }
  return showGeneralDialog<CagriEylemi>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Çağrı kartını kapat',
    barrierColor: Colors.transparent, // perde aşağıdaki BackdropFilter ile çizilir
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, _) => _CagriPerde(kisi: kisi, baslangic: baslangic),
    transitionBuilder: (ctx, anim, _, child) {
      // CSS `cUp`: translateY(22) scale(.96) opacity .4 → 0/1/1
      final e = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.2, 0.8, 0.2, 1),
      );
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(e),
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(e),
            child: child,
          ),
        ),
      );
    },
  );
}

/// CSS `.cagri-overlay` — bulanık perde, kart dikey ortada, yanlardan 16 boşluk.
class _CagriPerde extends StatelessWidget {
  const _CagriPerde({required this.kisi, this.baslangic});

  final CagriKisi kisi;
  final DateTime? baslangic;

  @override
  Widget build(BuildContext context) {
    void kapat(CagriEylemi e) => Navigator.of(context).pop(e);

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => kapat(CagriEylemi.kapat),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: SipTokens.scrim,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: SipSpace.x3),
            child: GestureDetector(
              // Kartın kendisine dokunmak kapatmaz (JSX `stopPropagation`).
              onTap: () {},
              child: CagriKarti(
                kisi: kisi,
                baslangic: baslangic,
                onKapat: () => kapat(CagriEylemi.kapat),
                onSiparis: () => kapat(CagriEylemi.siparis),
                onDefter: () => kapat(CagriEylemi.defter),
                onKaydet: () => kapat(CagriEylemi.kaydet),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CSS `.cagri-kart` — perdesiz kartın kendisi. Testlerde ve gömülü kullanımda
/// doğrudan bu widget kurulabilir.
class CagriKarti extends StatelessWidget {
  const CagriKarti({
    super.key,
    required this.kisi,
    this.baslangic,
    this.onKapat,
    this.onSiparis,
    this.onDefter,
    this.onKaydet,
  });

  final CagriKisi kisi;

  /// Çağrının başladığı an; verilirse üst şeritte süre saniye saniye işler.
  final DateTime? baslangic;

  final VoidCallback? onKapat;
  final VoidCallback? onSiparis;
  final VoidCallback? onDefter;
  final VoidCallback? onKaydet;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        SipSpace.govde,
        SipSpace.govde,
        SipSpace.govde,
        SipSpace.x4,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: SipRadius.br3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CagriUstSerit(baslangic: baslangic, onKapat: onKapat),
          CagriKimSatiri(kisi: kisi),
          if (kisi.kayitli) ...[
            if (kisi.bakiyeKurus != 0) CagriBakiyeSeridi(kurus: kisi.bakiyeKurus),
            CagriBilgiSatirlari(kisi: kisi),
          ],
          CagriEylemler(
            kisi: kisi,
            onSiparis: onSiparis,
            onDefter: onDefter,
            onKaydet: onKaydet,
          ),
        ],
      ),
    );
  }
}
