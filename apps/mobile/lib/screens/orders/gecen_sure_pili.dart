// AÇIK SİPARİŞİN BEKLEME SÜRESİ — "12 dk" pili (kullanıcı isteği 2026-07-29).
//
// Durum pilinin ("Açık") yerine geçer: hangi sekmede olduğu zaten listenin başlığında yazar,
// bayinin merak ettiği siparişin ne kadardır beklediğidir.
//
// NEDEN TEK BİR ZAMANLAYICI: süre kendiliğinden ilerlemeli, yoksa "3 dk" yazan bir sipariş
// ekran yeniden çizilene kadar öyle kalır ve YANLIŞ bilgi verir (listede veri değişmediği
// sürece Drift akışı yeni tik yayınlamaz). Her pilin kendi `Timer`ı olsaydı 40 açık siparişte
// 40 zamanlayıcı dönerdi; bunun yerine UYGULAMADA TEK bir zamanlayıcı bir `ValueNotifier`ı
// ilerletir, piller onu dinler. Dinleyici yoksa zamanlayıcı HİÇ kurulmaz ve son dinleyici
// gidince durur — arka planda boşuna pil yakan bir sayaç bırakmaz (Xiaomi dersi: sessizce
// çalışan şeyler pil raporunda görünür ve uygulama "şişman" damgası yer).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_queries.dart';

/// Dakikada bir ilerleyen paylaşılan "şimdi". Piller bunu dinler.
///
/// Aralık 60 sn: gösterim zaten dakika çözünürlüğünde, daha sık uyanmak hiçbir şey kazandırmaz.
/// İlk tik gecikmeli olduğu için pil ilk çizimde `DateTime.now()` ile doğru başlar.
class SureTikleyici extends ValueNotifier<DateTime> {
  SureTikleyici._() : super(DateTime.now());

  static final SureTikleyici ornek = SureTikleyici._();

  Timer? _zamanlayici;
  int _dinleyici = 0;

  /// Test kancası: sahte zamanda gerçek bir `Timer` kurmak testleri "pending timer" ile düşürür.
  /// Testler bunu `false` yapıp değeri elle ilerletir.
  static bool zamanlayiciAcik = true;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _dinleyici++;
    if (_dinleyici == 1 && zamanlayiciAcik) {
      _zamanlayici = Timer.periodic(const Duration(seconds: 60), (_) {
        value = DateTime.now();
      });
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _dinleyici--;
    if (_dinleyici <= 0) {
      _dinleyici = 0;
      _zamanlayici?.cancel();
      _zamanlayici = null;
    }
  }

  /// Testler için: zamanı elle ileri al.
  @visibleForTesting
  void tiklat(DateTime yeni) => value = yeni;
}

/// CSS `.pil` ölçüsünde, saat ikonlu süre pili. Yalnız AÇIK siparişte çizilir; teslim/iptal
/// edilmiş siparişte durum pili (`SipDurumPili`) kalır — orada geçen süre bir şey anlatmaz.
class GecenSurePili extends StatelessWidget {
  const GecenSurePili({super.key, required this.occurredAt});

  final String occurredAt;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return ValueListenableBuilder<DateTime>(
      valueListenable: SureTikleyici.ornek,
      builder: (context, simdi, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.lg, vertical: 3),
        decoration: BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.brHap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SipIcon(SipIcons.clock, boyut: 12, kalinlik: 2.2, renk: t.accent),
            const SizedBox(width: 4),
            Text(gecenSure(occurredAt, simdi: simdi),
                style: SipText.pil.copyWith(color: t.accent)),
          ],
        ),
      ),
    );
  }
}
