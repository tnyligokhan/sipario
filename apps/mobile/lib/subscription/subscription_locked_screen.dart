import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// FAZ 5a — NÖTR kilit ekranı (mağaza kuralı, BRIEF/DECISIONS — PAZARLIKSIZ).
///
/// Apple 3.1.3(f) + Google Play ödeme politikası gereği mobil uygulamada:
///  - fiyat YOK, "abone ol" butonu YOK, ödeme/kayıt sitesine link ya da çağrı YOK.
/// Yalnız nötr bilgi metni gösterilir. Üyelik/ödeme/hesap yönetimi YALNIZ web sitesinde yaşar.
///
/// Görsel: boş-durum diliyle (daire ikon + başlık + gövde) tasarım sistemine uyar; metinler
/// NÖTR kaldı. Sunucu tek "süresi doldu" durumu döner; bu ekran o durumun mobil yüzüdür.
class SubscriptionLockedScreen extends StatelessWidget {
  const SubscriptionLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SipColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SipColors.s2,
                    shape: BoxShape.circle,
                    border: Border.all(color: SipColors.line),
                  ),
                  child: const Icon(Icons.lock_outline, size: 40, color: SipColors.t3),
                ),
                const SizedBox(height: SipSpace.xxl),
                const Text(
                  'Aboneliğiniz sona erdi',
                  style: SipText.emptyTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SipSpace.md),
                // NÖTR metin — satın almaya yönlendirme YOK (mağaza kuralı). Yalnız bilgilendirme.
                const Text(
                  'Yeni kayıt girişi şu anda kapalı. Verileriniz güvende ve korunuyor. '
                  'Devam etmek için destek ekibinizle iletişime geçin.',
                  style: SipText.emptyBody,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
