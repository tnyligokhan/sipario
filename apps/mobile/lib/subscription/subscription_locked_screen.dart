// FAZ 5a — NÖTR kilit ekranı (mağaza kuralı, BRIEF/DECISIONS — PAZARLIKSIZ).
//
// Apple 3.1.3(f) + Google Play ödeme politikası gereği mobil uygulamada:
//  - fiyat YOK, "abone ol" butonu YOK, ödeme/kayıt sitesine link ya da çağrı YOK.
// Yalnız nötr bilgi metni gösterilir. Üyelik/ödeme/hesap yönetimi YALNIZ web sitesinde yaşar.
//
// Görünüm: Sipario.html `.kilit*` (66'lık accent-soft daire + başlık + gövde + bitiş satırı +
// "Kayıtları Görüntüle"). Kabuğun içine gömülür (kendi Scaffold'u yoktur), çünkü kilitliyken de
// çekmece ve alt navigasyon erişilebilir kalır.
//
// Gövde metni tasarımın (`s-giris.jsx:65-67`) metnidir: kullanıcıya NE YAPABİLECEĞİNİ söyler
// (okuma açık, yazma kapalı) ve kimle görüşeceğini gösterir. İkisi de nötr — satın almaya
// yönlendirme, fiyat, bağlantı YOK.

import 'package:flutter/material.dart';

import '../theme/components/atoms.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class SubscriptionLockedScreen extends StatelessWidget {
  const SubscriptionLockedScreen({super.key, this.bitis, this.onKayitlar});

  /// Abonelik bitişi (SyncMeta `validUntilIso`). null ise satır çizilmez — uydurma tarih basılmaz.
  final DateTime? bitis;

  /// "Kayıtları Görüntüle" (tasarım `s-giris.jsx:69`) — kilit gövdesini kapatıp mevcut kayıtlara
  /// döner. Salt-okunur kipte veri OKUNABİLİR olmalı; kilidi tek çıkışsız duvar yapmak veriyi
  /// erişilemez gösteriyordu. Kabuk vermezse düğme çizilmez (rota sahibi KABUKTUR).
  final VoidCallback? onKayitlar;

  static const List<String> _aylar = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.accentSoft, shape: BoxShape.circle),
              child: SipIcon(SipIcons.info, boyut: 38, kalinlik: 1.6, renk: t.accent),
            ),
            const SizedBox(height: SipSpace.x3),
            Text(
              'Aboneliğiniz sona erdi',
              style: SipText.kilitBaslik.copyWith(color: t.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 9),
            // NÖTR metin — satın almaya yönlendirme YOK (mağaza kuralı). Yalnız bilgilendirme.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                'Uygulama şu an salt-okunur kipte. Mevcut kayıtlarınızı görüntüleyebilir, ancak '
                'yeni sipariş, tahsilat veya değişiklik yapamazsınız. Erişiminizi sürdürmek için '
                'işletme yöneticinizle görüşün.',
                style: SipText.kilitMetin.copyWith(color: t.ink2),
                textAlign: TextAlign.center,
              ),
            ),
            if (bitis != null) ...[
              const SizedBox(height: SipSpace.x3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SipIcon(SipIcons.clock, boyut: 15, kalinlik: 2, renk: t.muted),
                  const SizedBox(width: 7),
                  Text(
                    'Bitiş: ${bitis!.day} ${_aylar[bitis!.month - 1]} ${bitis!.year}',
                    style: SipText.metin(12, w: 600).copyWith(color: t.muted),
                  ),
                ],
              ),
            ],
            if (onKayitlar != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SipButon(
                  etiket: 'Kayıtları Görüntüle',
                  tur: SipButonTuru.ikincil,
                  genisle: false,
                  onTap: onKayitlar,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
