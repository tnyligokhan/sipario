// Müşteri eylemleri — CSS `.srow-acts`: Ara · WhatsApp · Konum.
//
// SAHA HATASI (2026-07-27): üç düğme de yalnız toast gösteriyordu ("… aranıyor"), hiçbir şey
// açmıyordu. Tasarımın `ping` davranışı prototipten olduğu gibi taşınmış, gerçek eylem "Faz 6"ya
// bırakılmıştı. Bayi düğmeye basıp telefonun açılmasını bekliyor; açılmayınca ürün bozuk görünüyor.
//
// Artık gerçekten harici uygulama açılır (`url_launcher`). Kurallar:
//  • Telefon uluslararası biçime çevrilir (TR: baştaki 0 yerine +90) — WhatsApp ham "0532…"
//    numarasıyla sohbet AÇMAZ, sessizce boş ekran verir.
//  • Hedef uygulama yoksa ÇÖKME YOK: `url_launcher` ActivityNotFoundException'ı yutar ve false
//    döner; biz de Türkçe tek cümleyle nedenini söyleriz.
//  • Veri yoksa (telefonsuz/konumsuz müşteri) düğme GİZLENMEZ, PASİF çizilir ve dokunulunca
//    nedenini söyler — tasarımın "dokunuşu yutma" ilkesi (s-siparisler.jsx:24).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_queries.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Saf yardımcılar — numara normalleştirme ve URI kurma (widget'sız, doğrudan test edilir)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Ham telefonu E.164'e çevirir; çevrilemezse `null`.
///
/// Saklama zaten E.164'tür (`customer_phones.phone_e164`) AMA saha verisi elle girilir:
/// "0532 415 22 90", "532 415 22 90", "+90 532…", "0090532…" hepsi görülür. Kural TR içindir
/// (kullanıcı isteği): baştaki 0 düşer, +90 gelir. Ülke kodu zaten yazılmışsa dokunulmaz.
///
/// Belirsiz kalan girdide `null` DÖNER — yanlış bir numarayı aramak, hiç aramamaktan kötüdür.
String? telefonE164(String? ham) {
  if (ham == null) return null;
  var d = ham.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;

  // "+90…" ve "0090…" aynı şeyi söyler: ülke kodu zaten yazılmış.
  final ulkeKoduVar = ham.trimLeft().startsWith('+') || d.startsWith('00');
  if (d.startsWith('00')) d = d.substring(2);
  if (ulkeKoduVar) return d.length >= 11 ? '+$d' : null;

  if (d.startsWith('0')) d = d.substring(1); // TR yerel yazım: 0532…
  if (d.length == 12 && d.startsWith('90')) return '+$d';
  if (d.length == 10) return '+90$d';
  return null;
}

/// Telefon uygulaması. `tel:` şeması Android/iOS'ta çevirici ekranını açar (arama BAŞLATMAZ —
/// `CALL_PHONE` izni gerekirdi ve kırmızı çizgi #6'ya yaklaşırdı; kullanıcı yeşil tuşa basar).
Uri telUri(String e164) => Uri(scheme: 'tel', path: e164);

/// WhatsApp — önce uygulamanın kendi şeması, olmazsa `wa.me` (tarayıcı üzerinden uygulamayı açar).
/// Sıra önemlidir: `wa.me` WhatsApp yüklüyken de tarayıcı üzerinden dolaşır.
///
/// [mesaj] verilirse sohbet HAZIR METİNLE açılır — ama GÖNDERMEZ. WhatsApp'ın `text` parametresi
/// metni giriş kutusuna koyar, gönderme tuşuna kullanıcı basar. Bu bilinçli ve doğru: bayi
/// mesajı görmeden müşterisine para isteyen bir metin gitmemeli (üstelik otomatik gönderim
/// WhatsApp'ın kendi arayüzünde zaten mümkün değildir).
///
/// Metin `Uri` yapıcısının `queryParameters`ıyla kodlanır: Türkçe harfler, satır sonu ve `&`
/// elle kaçırılmaya çalışılırsa (eski `?text=` birleştirmesi) mesaj sessizce kırpılır.
List<Uri> whatsappUriler(String e164, {String? mesaj}) {
  final sade = e164.replaceAll(RegExp(r'\D'), ''); // wa.me "+" kabul etmez
  final metin = (mesaj ?? '').trim();
  final sorgu = metin.isEmpty ? null : {'text': metin};
  return [
    Uri(scheme: 'whatsapp', host: 'send', queryParameters: {
      'phone': sade,
      ...?sorgu,
    }),
    Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$sade',
      queryParameters: sorgu,
    ),
  ];
}

/// Harita — önce `geo:` (yüklü HERHANGİ bir harita uygulaması yakalar), olmazsa Google Maps web.
/// Koordinat `toStringAsFixed` ile yazılır: Dart bu metotta daima nokta ayırıcı kullanır, cihaz
/// yereli virgüle geçse bile URI bozulmaz.
List<Uri> haritaUriler(double lat, double lng, {String? etiket}) {
  final k = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  final ad = Uri.encodeComponent((etiket ?? '').isEmpty ? k : etiket!);
  return [
    Uri.parse('geo:$k?q=$k($ad)'),
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$k'),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Açma yolu — tek dikiş yeri (testler burayı değiştirir)
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Tek bir URI'yi açmayı dener; açıldıysa `true`.
typedef UriAcici = Future<bool> Function(Uri uri);

/// Gerçek açıcı. Widget testlerinde platform eklentisi YOKTUR — testler bunu sahteler
/// (`cagriKopruAcik` deseninin ikizi: köprü tek değişkende, çağıran taraf bilmez).
UriAcici uriAcici = _urlLauncherIle;

Future<bool> _urlLauncherIle(Uri uri) async {
  try {
    return await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
  } on Object {
    // Eklenti yoksa (test/masaüstü) ya da hedef uygulama yoksa: ÇÖKME YOK, "açılamadı".
    return false;
  }
}

/// Adayları SIRAYLA dener, ilk açılan kazanır. Hiçbiri açılmazsa `false`.
Future<bool> uriAc(List<Uri> adaylar) async {
  for (final u in adaylar) {
    if (await uriAcici(u)) return true;
  }
  return false;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Eylemler — başarıda `null`, aksi hâlde kullanıcıya gösterilecek TÜRKÇE gerekçe döner
// ═══════════════════════════════════════════════════════════════════════════════════════════

Future<String?> musteriyiAra(String? telefon) async {
  final n = telefonE164(telefon);
  if (n == null) return 'Müşterinin kayıtlı telefonu yok';
  return await uriAc([telUri(n)]) ? null : 'Telefon uygulaması açılamadı';
}

Future<String?> whatsappAc(String? telefon, {String? mesaj}) async {
  final n = telefonE164(telefon);
  if (n == null) return 'Müşterinin kayıtlı telefonu yok';
  return await uriAc(whatsappUriler(n, mesaj: mesaj))
      ? null
      : 'WhatsApp açılamadı — telefonda yüklü değil';
}

Future<String?> konumuHaritadaAc(AdresBilgi? adres, {String? etiket}) async {
  if (adres == null || !adres.konumVar) {
    return 'Konum kayıtlı değil — müşteri detayından alın';
  }
  final acildi = await uriAc(haritaUriler(adres.lat!, adres.lng!, etiket: etiket));
  return acildi ? null : 'Harita uygulaması açılamadı';
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CSS `.srow-acts` — üç eylem düğmesi
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Sipariş satırının eylem şeridi. Veri yoksa düğme PASİF çizilir ama dokunulabilir kalır:
/// dokunuş nedenini söyler (sessiz ölü düğme, kullanıcıya "uygulama bozuk" dedirtiyordu).
class MusteriEylemSeridi extends StatelessWidget {
  const MusteriEylemSeridi({
    super.key,
    required this.musteriAd,
    required this.telefon,
    required this.adres,
    this.onBildir,
  });

  final String musteriAd;
  final String? telefon;
  final AdresBilgi? adres;

  /// Sonucu kullanıcıya duyurur (toast). Başarıda ÇAĞRILMAZ — hedef uygulama zaten öne gelir,
  /// üstüne bir de bildirim göstermek gürültü olur.
  final ValueChanged<String>? onBildir;

  /// Eylemi çalıştırır ve gerekçe dönerse duyurur. `context.mounted` kontrolü şart: kullanıcı
  /// harici uygulamaya geçerken bu satır listeden düşmüş olabilir.
  Future<void> _calistir(BuildContext context, Future<String?> Function() eylem) async {
    final gerekce = await eylem();
    if (gerekce == null || !context.mounted) return;
    onBildir?.call(gerekce);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final telVar = telefonE164(telefon) != null;
    final konumVar = adres?.konumVar ?? false;

    return Row(
      children: [
        Expanded(
          child: _EylemDugmesi(
            ikon: SipIcons.phone,
            ikonRenk: telVar ? t.accent : t.muted,
            etiket: 'Ara',
            soluk: !telVar,
            onTap: () => _calistir(context, () => musteriyiAra(telefon)),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _EylemDugmesi(
            ikon: SipIcons.wa,
            // CSS `.srow-acts` WhatsApp yeşili (marka rengi — jetonlaştırılmaz).
            ikonRenk: telVar ? const Color(0xFF1FA855) : t.muted,
            ikonKalinlik: 1.9,
            etiket: 'WhatsApp',
            soluk: !telVar,
            onTap: () => _calistir(context, () => whatsappAc(telefon)),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _EylemDugmesi(
            ikon: SipIcons.pin,
            ikonRenk: konumVar ? t.ok : t.muted,
            etiket: 'Konum',
            soluk: !konumVar,
            kenarlik: konumVar ? t.okSoft : null,
            onay: konumVar,
            onTap: () =>
                _calistir(context, () => konumuHaritadaAc(adres, etiket: musteriAd)),
          ),
        ),
      ],
    );
  }
}

class _EylemDugmesi extends StatelessWidget {
  const _EylemDugmesi({
    required this.ikon,
    required this.ikonRenk,
    required this.etiket,
    required this.onTap,
    this.ikonKalinlik = 2.1,
    this.soluk = false,
    this.kenarlik,
    this.onay = false,
  });

  final String ikon;
  final Color ikonRenk;
  final String etiket;
  final VoidCallback onTap;
  final double ikonKalinlik;
  final bool soluk;
  final Color? kenarlik;
  final bool onay;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Opacity(
      opacity: soluk ? 0.62 : 1,
      child: Semantics(
        button: true,
        enabled: !soluk,
        label: etiket,
        child: SipDokun(
          onTap: onTap,
          zemin: t.surface2,
          basiliZemin: t.line2,
          radius: SipRadius.brHap,
          kenarlik: kenarlik == null ? null : Border.all(color: kenarlik!),
          child: SizedBox(
            // DESIGN_SYSTEM: ikon butonu 38 — dokunma hedefi alt sınırı.
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SipIcon(ikon, boyut: 15, kalinlik: ikonKalinlik, renk: ikonRenk),
                const SizedBox(width: SipSpace.sm),
                Flexible(
                  child: Text(
                    etiket,
                    style: SipText.metin(12, w: 700).copyWith(color: t.ink2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onay) ...[
                  const SizedBox(width: SipSpace.xs),
                  SipIcon(SipIcons.check, boyut: 11, kalinlik: 3, renk: t.ok),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
