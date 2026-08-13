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
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.govde, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── DURUM ROZETİ ──────────────────────────────────────────────────────────
              // Başlıktan ÖNCE bir durum etiketi: kullanıcı ekrana baktığı ilk yarım saniyede
              // "uygulama bozulmadı, KİPİ değişti" bilgisini alır. Eski tasarımda bu ancak
              // paragrafın ikinci cümlesinde söyleniyordu.
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.warnSoft,
                    borderRadius: SipRadius.brHap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SipIcon(SipIcons.lock, boyut: 13, kalinlik: 2.2, renk: t.warn),
                      const SizedBox(width: 6),
                      Text(
                        trBuyuk('Salt-okunur kip'),
                        style: SipText.metin(10.5, w: 800)
                            .copyWith(color: t.warn, letterSpacing: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SipSpace.xl),
              Text(
                'Aboneliğiniz sona erdi',
                style: SipText.kilitBaslik.copyWith(color: t.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Verileriniz yerinde duruyor ve silinmez.',
                style: SipText.kilitMetin.copyWith(color: t.ink2),
                textAlign: TextAlign.center,
              ),

              // ── NE AÇIK / NE KAPALI ───────────────────────────────────────────────────
              // TEK YOĞUN PARAGRAF YERİNE İKİ SATIR. Eski metin üç bilgiyi (okuma açık, yazma
              // kapalı, kiminle görüşülür) tek blokta veriyordu ve kullanıcının "ben şimdi ne
              // yapabiliyorum" sorusunun cevabı cümlenin ortasında kalıyordu. Karşıtlık ancak
              // yan yana konunca okunur.
              const SizedBox(height: SipSpace.x3),
              _DurumSatiri(
                ikon: SipIcons.check,
                renk: t.ok,
                baslik: 'Açık',
                metin: 'Müşteriler, siparişler, defter ve gün özeti — hepsi okunabilir.',
              ),
              const SizedBox(height: SipSpace.md),
              _DurumSatiri(
                ikon: SipIcons.ban,
                renk: t.muted,
                baslik: 'Kapalı',
                metin: 'Yeni sipariş, tahsilat ve değişiklik kaydedilemez.',
              ),

              if (bitis != null) ...[
                const SizedBox(height: SipSpace.x3),
                Align(
                  alignment: Alignment.center,
                  child: Row(
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
                ),
              ],

              // NÖTR YÖNLENDİRME (mağaza kuralı — PAZARLIKSIZ): fiyat, "abone ol", ödeme
              // sitesine bağlantı ya da çağrı YOK. Yalnız kiminle görüşüleceği söylenir.
              const SizedBox(height: SipSpace.x3),
              Text(
                'Erişiminizi sürdürmek için işletme yöneticinizle görüşün.',
                style: SipText.metin(12.5, w: 600, h: 1.5).copyWith(color: t.muted),
                textAlign: TextAlign.center,
              ),

              if (onKayitlar != null) ...[
                const SizedBox(height: SipSpace.x3),
                // BİRİNCİL DÜĞME: bu ekrandaki TEK eylem ve tamamen zararsız (okuma). Eskiden
                // ikincil çizilip ortada küçük duruyordu — kilit ekranı çıkışsız bir duvar gibi
                // görünüyordu. Kullanıcının buradan çıkıp işine dönebilmesi asıl mesele.
                SipButon(etiket: 'Kayıtları Görüntüle', onTap: onKayitlar),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Açık / Kapalı" satırı: renkli ikon kutusu + başlık + tek cümlelik açıklama.
class _DurumSatiri extends StatelessWidget {
  const _DurumSatiri({
    required this.ikon,
    required this.renk,
    required this.baslik,
    required this.metin,
  });

  final String ikon;
  final Color renk;
  final String baslik;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.lg, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(ikon, boyut: 16, kalinlik: 2.3, renk: renk),
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  baslik,
                  style: SipText.metin(12.5, w: 800).copyWith(color: renk),
                ),
                const SizedBox(height: 2),
                Text(
                  metin,
                  style: SipText.metin(12, w: 500, h: 1.45).copyWith(color: t.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
