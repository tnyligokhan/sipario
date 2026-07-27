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
