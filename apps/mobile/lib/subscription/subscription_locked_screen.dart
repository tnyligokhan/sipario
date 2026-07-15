import 'package:flutter/material.dart';

/// FAZ 5a — NÖTR kilit ekranı (mağaza kuralı, BRIEF/DECISIONS — PAZARLIKSIZ).
///
/// Apple 3.1.3(f) + Google Play ödeme politikası gereği mobil uygulamada:
///  - fiyat YOK, "abone ol" butonu YOK, ödeme/kayıt sitesine link ya da çağrı YOK.
/// Yalnız nötr bilgi metni gösterilir. Üyelik/ödeme/hesap yönetimi YALNIZ web sitesinde yaşar.
///
/// Bu MİNİMAL placeholder'dır; UI detayı (marka, görsel) sonraki iş. Sunucu tek "süresi doldu"
/// durumu döner; bu ekran o durumun mobil (nötr) yüzüdür — web'de ticari ekran gösterilir.
class SubscriptionLockedScreen extends StatelessWidget {
  const SubscriptionLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.outline),
                const SizedBox(height: 24),
                Text(
                  'Aboneliğiniz sona erdi',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // NÖTR metin — satın almaya yönlendirme YOK (mağaza kuralı). Yalnız bilgilendirme.
                Text(
                  'Yeni kayıt girişi şu anda kapalı. Verileriniz güvende ve korunuyor. '
                  'Devam etmek için destek ekibinizle iletişime geçin.',
                  style: theme.textTheme.bodyMedium,
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
