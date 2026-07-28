// Adres → konum adayları (CSS `.aday-*`, `.md-konum`; kaynak s-musteriler.jsx `adresAdaylari`).
//
// Tasarımın kuralı: konum adresten OTOMATİK atanmaz. Servis birden çok aday döner, doğrusunu
// KULLANICI seçer — yanlış algılanan bir adres yüzünden kurye yanlış kapıya gitmesin.
//
// Adaylar artık KENDİ SUNUCUMUZDAN gelir (`POST /geocode`), sağlayıcıya (Yandex/Google) doğrudan
// gidilmez: anahtar APK'ya gömülemez, aynı adres ikinci kez sorulmamalı ve sağlayıcı değişimi
// uygulama güncellemesi gerektirmemeli. Ekranlar bu dosyanın altındaki tek dikişten geçer.

import 'package:flutter/material.dart';

import '../../auth/session.dart';
import '../../data/app_database.dart';
import '../../sync/geocode_api.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Bir adres metni için önerilen konum. Koordinat GÖSTERİMİ daima 4 basamak (tasarım).
class AdresAdayi {
  const AdresAdayi({
    required this.metin,
    required this.lat,
    required this.lng,
    this.kesinlik = 'semt',
  });

  final String metin;
  final double lat;
  final double lng;

  /// 'bina' | 'sokak' | 'semt' — sunucunun sağlayıcıdan bağımsızlaştırdığı kademe.
  final String kesinlik;

  String get koordinat => konumMetni(lat, lng);

  /// Kapı kesinliği YOKSA kullanıcıya söylenir. "Sokak" kesinliğindeki bir pin kuryeyi doğru
  /// sokağa götürür ama doğru kapıya götürmez; bunu sessizce "konum kayıtlı" saymak, kuryenin
  /// güvendiği bir yanlış üretir.
  String? get kesinlikNotu => switch (kesinlik) {
        'bina' => null,
        'sokak' => 'sokak yaklaşık',
        _ => 'semt yaklaşık',
      };
}

/// Sonuç boş dönünce gösterilen cümle. İKİ ekranda da AYNI metin: iki kopya zamanla ayrışır ve
/// biri düzeltilip diğeri unutulur. "Bulunamadı" bir ARIZA değildir, kullanıcıya ne yapacağını
/// söyler — bu yüzden hata rengiyle değil yönlendirmeyle yazılır.
const String konumBulunamadiMesaji =
    'Bu adres bulunamadı — mahalle ve sokak adını biraz daha açık yazın.';

/// "36.8969, 30.7133" — hem aday satırında hem `.md-konum` çipinde aynı yazım.
String konumMetni(double lat, double lng) =>
    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

/// Adres metninden aday üreten TEK dikiş. Widget testleri bunu sahtesiyle değiştirir — ağ
/// çağrısı ekranların içine gömülmez (`sesliGirisUret` / `uriAcici` deseninin aynısı).
Future<List<AdresAdayi>> Function(AppDatabase db, String metin, String? bolge)
    adresAdaylariGetir = sunucudanAdresAdaylari;

/// Gerçek uygulama yolu: kendi API'mize sorar, sonucu ekranın anladığı biçime çevirir.
Future<List<AdresAdayi>> sunucudanAdresAdaylari(
  AppDatabase db,
  String metin,
  String? bolge,
) async {
  final m = metin.trim();
  if (m.length < 3) {
    // Sunucu da reddeder; buradan hiç çıkmaması bir tur ağ ve bir tur kota tasarrufudur.
    throw GeocodeException('Adres en az 3 karakter olmalı.');
  }

  final meta = await db.syncState();
  final token = meta.authToken;
  if (token == null) {
    throw GeocodeException('Adres araması için oturum gerekir.');
  }

  final adaylar = await GeocodeApi(baseUrl: Session.baseUrlOf(meta), token: token)
      .ara(m, bolge: bolge);

  return [
    for (final a in adaylar)
      AdresAdayi(metin: a.metin, lat: a.lat, lng: a.lng, kesinlik: a.kesinlik),
  ];
}

/// Adayları alttan açılan sayfada gösterir; kullanıcı birini seçerse onu döner.
Future<AdresAdayi?> konumSecSheet(BuildContext context, List<AdresAdayi> adaylar) {
  return sipSheet<AdresAdayi>(
    context,
    baslik: 'Konum Seç · API Sonuçları',
    govde: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdayBilgi(metin: 'Adres bazen yanlış algılanabilir — doğru olanı seçin.'),
        const SizedBox(height: SipSpace.xs),
        for (final a in adaylar)
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.sm),
            child: AdaySatiri(aday: a, onSec: () => Navigator.of(ctx).pop(a), okGoster: true),
          ),
      ],
    ),
  );
}

/// CSS `.aday-info` — aday listesinin üstündeki açıklama satırı.
class AdayBilgi extends StatelessWidget {
  const AdayBilgi({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SipIcon(SipIcons.info, boyut: 14, kalinlik: 2, renk: t.accent),
          const SizedBox(width: SipSpace.sm),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(11.5, w: 600).copyWith(color: t.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.aday-row` — ikon + adres + koordinat (+ opsiyonel sağ ok).
class AdaySatiri extends StatelessWidget {
  const AdaySatiri({
    super.key,
    required this.aday,
    required this.onSec,
    this.okGoster = false,
  });

  final AdresAdayi aday;
  final VoidCallback onSec;
  final bool okGoster;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokunAday(
      onTap: onSec,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.brHap),
            child: SipIcon(SipIcons.pin, boyut: 16, kalinlik: 2.1, renk: t.accent),
          ),
          const SizedBox(width: SipSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aday.metin,
                  style: SipText.metin(13, w: 700, h: 1.35).copyWith(color: t.ink),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text(
                      aday.koordinat,
                      style: SipText.tutar(11, w: 600).copyWith(color: t.muted),
                    ),
                    // Kapı kesinliği olmayan aday UYARIYLA gösterilir — kullanıcı iki aday
                    // arasında seçim yaparken hangisinin kapıyı bulduğunu bilmeli.
                    if (aday.kesinlikNotu != null) ...[
                      const SizedBox(width: SipSpace.sm),
                      Flexible(
                        child: Text(
                          '· ${aday.kesinlikNotu!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SipText.metin(11, w: 700).copyWith(color: t.warn),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (okGoster) ...[
            const SizedBox(width: SipSpace.md),
            SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2, renk: t.line2),
          ],
        ],
      ),
    );
  }
}

/// `.aday-row`un kenarlıklı yüzeyi — [SipDokun]a kenarlık + padding geçmenin kısayolu.
class SipDokunAday extends StatelessWidget {
  const SipDokunAday({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      basiliZemin: t.accentSoft,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: 11),
      kenarlik: Border.all(color: t.line, width: 1.5),
      child: child,
    );
  }
}
