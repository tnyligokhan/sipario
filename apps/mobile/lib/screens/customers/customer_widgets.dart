// Müşteri ekranlarının paylaşılan küçük parçaları — CSS `.kd-row`, `.gs-kapali`, `.ym-err`,
// `.th-chip`, `.odeme-b`, `.odeme-grid`. Tek bir yerde durur ki liste/detay/sheet'ler aynı
// görsel dili konuşsun (ve dosyalar 500 satırın altında kalsın).

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Kuruşu girdi kutusuna yazılabilir metne çevirir ("12345" → "123,45"). Binlik ayracı YOK —
/// yeniden ayrıştırmada belirsizlik olmasın (parseKurus "1.234"ü binlik sayar).
String tutarGirdisi(int kurus) =>
    '${kurus ~/ 100},${(kurus % 100).toString().padLeft(2, '0')}';

/// Adres + bölgeyi tek gösterim metnine birleştirir — tasarım her yerde
/// `[adres.metin, adres.bolge].join(' — ')` yazıyor (liste satırı ve detaydaki koyu kart).
/// Bölge AYRI bir kolondur (`customer_addresses.region`); burada yalnız GÖSTERİM birleştirilir.
String? adresGosterimi(String? adresMetni, String? bolge) {
  final a = adresMetni?.trim() ?? '';
  final b = bolge?.trim() ?? '';
  if (a.isEmpty) return b.isEmpty ? null : b;
  return b.isEmpty ? a : '$a — $b';
}

/// CSS `.kd-row` — sheet başındaki "etiket / büyük tutar" satırı.
class SipTutarSatiri extends StatelessWidget {
  const SipTutarSatiri({
    super.key,
    required this.etiket,
    required this.kurus,
    required this.renk,
    this.sifirMetni,
    this.etiketEkle = false,
  });

  final String etiket;
  final int kurus;
  final Color renk;

  /// 0 iken tutar yerine yazılacak söz (tasarım: "Temiz").
  final String? sifirMetni;

  /// Tutarın sonuna bakiye etiketi ("Borç"/"Alacak") eklensin mi.
  final bool etiketEkle;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final deger = kurus == 0 && sifirMetni != null
        ? sifirMetni!
        : etiketEkle
            ? '${sipTutar(kurus.abs())} ${SipTokens.bakiyeEtiket(kurus)}'
            : sipTutar(kurus.abs());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(etiket, style: SipText.gsSatirEtiket.copyWith(color: t.ink2)),
          ),
          Text(deger, style: SipText.tutar20.copyWith(color: renk)),
        ],
      ),
    );
  }
}

/// CSS `.gs-kapali` — tek satırlık renkli durum şeridi.
class SipDurumSeridi extends StatelessWidget {
  const SipDurumSeridi({
    super.key,
    required this.metin,
    required this.ikon,
    required this.renk,
    required this.zemin,
  });

  final String metin;
  final String ikon;
  final Color renk;
  final Color zemin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: SipSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 11),
      decoration: BoxDecoration(color: zemin, borderRadius: SipRadius.br2),
      child: Row(
        children: [
          SipIcon(ikon, boyut: 15, kalinlik: 2.4, renk: renk),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(metin, style: SipText.metin(12.5, w: 700).copyWith(color: renk)),
          ),
        ],
      ),
    );
  }
}

/// CSS `.ym-err` — alan altındaki küçük hata/uyarı satırı.
class SipHataSatiri extends StatelessWidget {
  const SipHataSatiri({super.key, required this.metin, this.renk, this.ikon = SipIcons.alert});

  final String metin;
  final Color? renk;
  final String ikon;

  @override
  Widget build(BuildContext context) {
    final c = renk ?? context.sip.danger;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.sm),
      child: Row(
        children: [
          SipIcon(ikon, boyut: 13, kalinlik: 2.2, renk: c),
          const SizedBox(width: 5),
          Expanded(
            child: Text(metin, style: SipText.metin(12, w: 700).copyWith(color: c)),
          ),
        ],
      ),
    );
  }
}

/// CSS `.th-chip` — kenarlıklı hızlı seçim çipi (Tamamı / Yarısı).
class SipCip extends StatelessWidget {
  const SipCip({super.key, required this.etiket, required this.secili, required this.onTap});

  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: secili ? t.accentSoft : t.surface,
      basiliZemin: t.surface2,
      radius: SipRadius.brHap,
      kenarlik: Border.all(color: secili ? t.accent : t.line2, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: SipSpace.lg),
      child: Text(
        etiket,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SipText.metin(12, w: 700).copyWith(color: secili ? t.accent : t.ink2),
      ),
    );
  }
}

/// CSS `.odeme-b` — 44 yüksek seçim kutusu (ödeme tipi, düzeltme yönü).
class SipSecimKutusu extends StatelessWidget {
  const SipSecimKutusu({
    super.key,
    required this.etiket,
    required this.secili,
    required this.onTap,
  });

  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: secili ? t.accentSoft : t.surface2,
      basiliZemin: t.surface2,
      radius: SipRadius.br2,
      kenarlik: Border.all(color: secili ? t.accent : Colors.transparent, width: 1.5),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Text(
            etiket,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SipText.metin(13, w: secili ? 700 : 600)
                .copyWith(color: secili ? t.accent : t.ink2),
          ),
        ),
      ),
    );
  }
}

/// CSS `.odeme-grid` — Nakit / Kart / Havale. Veresiye burada YOK: o kasa gruplaması değil,
/// teslim akışında sipariş bağlamında sorulur.
class SipOdemeSecici extends StatelessWidget {
  const SipOdemeSecici({super.key, required this.secili, required this.onSec});

  final String secili;
  final ValueChanged<String> onSec;

  static const List<(String, String)> tipler = [
    ('nakit', 'Nakit'),
    ('kart', 'Kart'),
    ('havale', 'Havale'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tipler.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: SipSecimKutusu(
              etiket: tipler[i].$2,
              secili: secili == tipler[i].$1,
              onTap: () => onSec(tipler[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

/// CSS `.ym-lblrow` — "Adres" etiketi + sağda Konum Al bağlantısı / alınan konum çipi.
/// (`customer_form_screen.dart` 500 satırı aşınca buraya taşındı; oranın tek kullanıcısıdır.)
class AdresEtiketSatiri extends StatelessWidget {
  const AdresEtiketSatiri({
    super.key,
    required this.konumVar,
    required this.koordinat,
    required this.onKonumAl,
    this.calisiyor = false,
    this.onKonumGuncelle,
  });

  final bool konumVar;
  final String? koordinat;
  final VoidCallback onKonumAl;

  /// Adres aranıyor ya da cihaz konumu okunuyor. Süresiz bekleyen bir düğme "bozuk" sayılır;
  /// satır bu sırada ne diyeceğini söyler ve ikinci dokunuşu kabul etmez.
  final bool calisiyor;

  /// Cihazın BULUNDUĞU noktayı yazar (adresten kodlama sokağı bulur, kapıyı bulmaz).
  /// null ise güncelleme affordance'ı hiç çizilmez.
  final VoidCallback? onKonumGuncelle;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, SipSpace.x2, 0, SipSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text('ADRES', style: SipText.formEtiket.copyWith(color: t.muted)),
          ),
          // Flexible + ellipsis: koordinat + güncelle ikonu büyük yazı tipi ayarında satırı
          // taşırmasın (taşma çizgili kırmızı bant demektir, saha telefonunda utanç verici).
          if (calisiyor)
            Text('Konum aranıyor…', style: SipText.metin(11.5, w: 700).copyWith(color: t.muted))
          else if (konumVar)
            Flexible(
              child: SipDokun(
                onTap: onKonumGuncelle,
                radius: SipRadius.br1,
                padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SipIcon(SipIcons.check, boyut: 12, kalinlik: 2.8, renk: t.ok),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Konum alındı · ${koordinat!}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SipText.metin(11.5, w: 700).copyWith(color: t.ok),
                      ),
                    ),
                    if (onKonumGuncelle != null) ...[
                      const SizedBox(width: 5),
                      SipIcon(SipIcons.sync, boyut: 12, kalinlik: 2.2, renk: t.accent),
                    ],
                  ],
                ),
              ),
            )
          else
            SipDokun(
              onTap: onKonumAl,
              radius: SipRadius.br1,
              padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SipIcon(SipIcons.pin, boyut: 13, kalinlik: 2.2, renk: t.accent),
                  const SizedBox(width: 5),
                  Text(
                    'Konum Al',
                    style: SipText.metin(12, w: 800).copyWith(color: t.accent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Sesli giriş mikrofonu — metin alanlarının YANINDA
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Lucide `mic` (24×24). `SipIcons`a EKLENEMEDİ: `theme/icons.dart` bu ajanın dosyası değil.
/// Tema sahibi ekleyebildiğinde buradan silinip `SipIcons.mic` kullanılmalı — path birebir aynı.
const String kMikrofonIkonu =
    'M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3z|M19 10v2a7 7 0 0 1-14 0v-2|M12 19v3';

/// Alanın yanındaki mikrofon düğmesi.
///
/// PASİF ≠ GİZLİ: izin reddedildiyse ya da cihazda Türkçe tanıma yoksa düğme SOLUK çizilir ama
/// dokunulabilir kalır ve sebebini söyler (Oto Sırala ve Ara/WhatsApp düğmeleriyle aynı desen —
/// sessiz ölü düğme kullanıcıya "uygulama bozuk" dedirtiyor).
///
/// DİNLERKEN kullanıcı bunu görmek zorunda: zemin accent'e döner ve nabız gibi atan bir halka
/// çizilir. Sessizce dinleyen mikrofon hem güven sorunudur hem mağaza incelemesinde risktir.
class SesliGirisDugmesi extends StatelessWidget {
  const SesliGirisDugmesi({
    super.key,
    required this.dinliyor,
    required this.kapali,
    required this.onTap,
    this.alanAdi,
  });

  final bool dinliyor;

  /// İzin yok / cihazda tanıma yok — soluk çizilir, dokunuş gerekçeyi söyler.
  final bool kapali;

  final VoidCallback onTap;

  /// Erişilebilirlik etiketinde geçen alan adı ("Ad Soyad" → "Ad Soyad alanına sesle yaz").
  final String? alanAdi;

  /// DESIGN_SYSTEM dokunma hedefi alt sınırı.
  static const double cap = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final etiket = dinliyor
        ? 'Dinlemeyi durdur'
        : 'Sesle yaz${alanAdi == null ? '' : ' · $alanAdi'}';
    return Semantics(
      button: true,
      label: etiket,
      child: Opacity(
        opacity: kapali ? 0.62 : 1,
        child: SipDokun(
          onTap: onTap,
          zemin: dinliyor ? t.accent : t.surface2,
          basiliZemin: dinliyor ? t.accent : t.line2,
          radius: SipRadius.brHap,
          child: SizedBox.square(
            dimension: cap,
            child: Center(
              child: dinliyor
                  ? const _NabizHalkasi(child: SipIcon(kMikrofonIkonu,
                      boyut: 20, kalinlik: 2.1, renk: SipTokens.onHero))
                  : SipIcon(kMikrofonIkonu,
                      boyut: 20, kalinlik: 2.1, renk: kapali ? t.muted : t.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dinleme sırasında ikonun arkasında atan halka — "kayıt açık" işareti.
class _NabizHalkasi extends StatefulWidget {
  const _NabizHalkasi({required this.child});
  final Widget child;

  @override
  State<_NabizHalkasi> createState() => _NabizHalkasiState();
}

class _NabizHalkasiState extends State<_NabizHalkasi> with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _kontrol,
      builder: (context, ic) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 26 + 8 * _kontrol.value,
            height: 26 + 8 * _kontrol.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SipTokens.onHeroFill2,
            ),
          ),
          ic!,
        ],
      ),
      child: widget.child,
    );
  }
}

/// Etiket + alan + mikrofon üçlüsünün yerleşimi. Mikrofon alanın SAĞINDA, dikeyde ortalanmış;
/// çok satırlı alanda (Not) üste hizalanır ki kutu büyüdükçe düğme ortada asılı kalmasın.
class SesliAlanSatiri extends StatelessWidget {
  const SesliAlanSatiri({
    super.key,
    required this.alan,
    required this.mikrofon,
    this.ustHizala = false,
  });

  final Widget alan;
  final Widget mikrofon;
  final bool ustHizala;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          ustHizala ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Expanded(child: alan),
        const SizedBox(width: SipSpace.md),
        mikrofon,
      ],
    );
  }
}

/// Ödeme tipinin ekran etiketi (DB değeri değişmez — 'nakit'/'veresiye'/… durur).
/// s-veri.jsx `ODEME_TIPLERI`.
String odemeEtiketi(String paymentType) => switch (paymentType) {
      'nakit' => 'Nakit',
      'kart' => 'Kart',
      'havale' => 'Havale',
      'veresiye' => 'Veresiye',
      _ => paymentType,
    };

/// ISO8601 occurred_at → "14:35" (bugünse) veya "17.07 14:35". Saat cihaz yerelinde gösterilir;
/// kayıtta sunucu-düzeltilmiş metin OLDUĞU GİBİ durur (gösterim veriyi değiştirmez).
String defterSaati(String iso, {DateTime? simdi}) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final yerel = t.toLocal();
  final now = simdi ?? DateTime.now();
  final saat = '${_ikiHane(yerel.hour)}:${_ikiHane(yerel.minute)}';
  final ayniGun = yerel.year == now.year && yerel.month == now.month && yerel.day == now.day;
  return ayniGun ? saat : '${_ikiHane(yerel.day)}.${_ikiHane(yerel.month)} $saat';
}

String _ikiHane(int n) => n.toString().padLeft(2, '0');
