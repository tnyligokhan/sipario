// Sipario tasarım sistemi — TOKEN'lar (tek kaynak).
// SİPARİO 3.0 kimliği: tasarım Sipario.html `:root` ve `.app.koyu` bloklarının birebir
// Dart karşılığı. Koyu gece-mürekkep hero · aydınlık gövde · elektrik moru vurgu.
// Yüzeyler DÜZ (flat): gölge yok, katman ton farkıyla kurulur.
//
// KURAL: ekranlarda ham renk/ölçü/yarıçap KULLANILMAZ — her şey buradan gelir.
// Tema çalışma anında değiştiği için renkler `static const` DEĞİL, bir [ThemeExtension] içinde
// yaşar ve `context.sip.surface` biçiminde okunur.

import 'package:flutter/material.dart';

/// Başlık ve RAKAM fontu (CSS `--font-d`). Sora — değişken ağırlık, assets/fonts'a gömülü.
const String sipFontDisplay = 'Sora';

/// Gövde metni fontu (CSS `--font-b`). Hanken Grotesk — değişken ağırlık, gömülü.
const String sipFontBody = 'HankenGrotesk';

@immutable
class SipTokens extends ThemeExtension<SipTokens> {
  const SipTokens({
    required this.canvas,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.line2,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.hero,
    required this.hero2,
    required this.danger,
    required this.dangerSoft,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.koyu,
  });

  /// Telefon çerçevesinin dışı (mobilde görünmez; tam ekranda [bg] kullanılır).
  final Color canvas;

  /// Ekran zemini.
  final Color bg;

  /// Kart / liste satırı yüzeyi.
  final Color surface;

  /// İkincil yüzey — basılı hâl, input zemini, çip, segment rayı.
  final Color surface2;

  /// Birincil metin.
  final Color ink;

  /// İkincil metin.
  final Color ink2;

  /// Sönük metin / etiket.
  final Color muted;

  /// İnce ayraç.
  final Color line;

  /// Belirgin kenarlık.
  final Color line2;

  /// Marka vurgusu (elektrik moru).
  final Color accent;

  /// Vurgu dolgusu üstündeki metin.
  final Color accentInk;

  /// Vurgunun yumuşak zemini.
  final Color accentSoft;

  /// Koyu mürekkep blok — ana ekran hero'su, alt nav, çekmece, toast, giriş ekranı.
  final Color hero;

  /// Hero'nun basılı / ikincil tonu.
  final Color hero2;

  /// Borç · hata · yıkıcı eylem.
  final Color danger;
  final Color dangerSoft;

  /// Alacak · başarı · tamam.
  final Color ok;
  final Color okSoft;

  /// Uyarı · not.
  final Color warn;
  final Color warnSoft;

  /// Koyu tema mı? (Sistem çubuğu ikon parlaklığı ve tersine dönen jetonlar için.)
  final bool koyu;

  // ── Hero (DAİMA koyu) üzerindeki katmanlar — her iki temada da aynı ──────────────────────
  static const Color onHero = Color(0xFFFFFFFF);
  static const Color onHeroStrong = Color(0xD9FFFFFF); // %85
  static const Color onHeroMid = Color(0x8CFFFFFF); // %55
  static const Color onHeroSoft = Color(0x61FFFFFF); // %38
  static const Color onHeroFill = Color(0x12FFFFFF); // %7  — hero üstü çip zemini
  static const Color onHeroFill2 = Color(0x1FFFFFFF); // %12 — hero üstü seçili/basılı
  static const Color onHeroLine = Color(0x14FFFFFF); // %8  — hero üstü ayraç

  /// Alt navigasyonda SEÇİLİ OLMAYAN sekme ikonu (CSS `.altnav-b` → `rgba(255,255,255,.45)`).
  /// `onHeroMid`ten (%55) ayrı tutulur: gezinme ikonları metinden bir tık daha geride durmalı.
  static const Color onHeroIcon = Color(0x73FFFFFF); // %45

  /// Hero üstündeki en sönük öğe — çekmece satırlarının chevron'u
  /// (CSS `.cekr` → `rgba(255,255,255,.22)`).
  static const Color onHeroFaint = Color(0x38FFFFFF); // %22

  /// Çekmecedeki çıkış düğmesi (CSS `.cek-cikis`). Hero üstünde `danger` jetonu okunmadığı için
  /// tasarım kendi kırmızı tonunu kullanır.
  static const Color heroCikisFill = Color(0x29E0525A); // %16
  static const Color heroCikisFill2 = Color(0x47E0525A); // %28 — basılı
  static const Color heroCikisInk = Color(0xFFFF9FA3);

  /// Hero üstündeki canlı senkron noktası (CSS `.ana-sync i`).
  static const Color heroDot = Color(0xFF3DDC97);

  /// Çekmece istatistik pili (CSS `.lst-pil`).
  static const Color heroPill = Color(0xFFB3A6FF);

  /// Hero üstünde "konum yok" uyarısı (CSS `.md-konum.yok b`).
  static const Color onHeroWarn = Color(0xFFFFD79A);

  /// Perde — sheet · diyalog · çekmece · çağrı kartı (CSS `rgba(23,20,31,.45)`).
  static const Color scrim = Color(0x7317141F);

  /// AÇIK tema — tasarımın varsayılanı.
  static const SipTokens acik = SipTokens(
    canvas: Color(0xFFDDDCE4),
    bg: Color(0xFFF4F3F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEAE8F0),
    ink: Color(0xFF17141F),
    ink2: Color(0xFF47434F),
    muted: Color(0xFF8B8794),
    line: Color(0xFFE6E4EC),
    line2: Color(0xFFD2CFDB),
    accent: Color(0xFF5A45F0),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFECE9FE),
    hero: Color(0xFF17141F),
    hero2: Color(0xFF241F31),
    danger: Color(0xFFDF3F45),
    dangerSoft: Color(0xFFFCE9EA),
    ok: Color(0xFF1E9E6A),
    okSoft: Color(0xFFE3F4EC),
    warn: Color(0xFFC08415),
    warnSoft: Color(0xFFF9F0DC),
    koyu: false,
  );

  /// KOYU tema — CSS `.app.koyu` bloğu. Yalnız orada geçersiz kılınan jetonlar değişir;
  /// accent / danger / ok / warn ana tonları AYNI kalır (tasarım kararı).
  static const SipTokens koyuTema = SipTokens(
    canvas: Color(0xFF0B0A0E),
    bg: Color(0xFF141218),
    surface: Color(0xFF1E1B26),
    surface2: Color(0xFF2A2634),
    ink: Color(0xFFF2F0F7),
    ink2: Color(0xFFC9C5D4),
    muted: Color(0xFF8D8999),
    line: Color(0xFF2C2836),
    line2: Color(0xFF423C52),
    accent: Color(0xFF5A45F0),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFF2C2650),
    hero: Color(0xFF0D0B12),
    hero2: Color(0xFF1A1722),
    danger: Color(0xFFDF3F45),
    dangerSoft: Color(0xFF3A1D22),
    ok: Color(0xFF1E9E6A),
    okSoft: Color(0xFF17332A),
    warn: Color(0xFFC08415),
    warnSoft: Color(0xFF332A16),
    koyu: true,
  );

  /// Bakiye işaretine göre renk: +borç danger · −alacak ok · 0 temiz ink
  /// (s-arayuz.jsx `bakiyeDurum()`).
  Color bakiyeRenk(int kurus) => kurus > 0 ? danger : (kurus < 0 ? ok : ink);

  /// Bakiyenin yumuşak zemini — rozet/şerit arka planı.
  Color bakiyeSoft(int kurus) =>
      kurus > 0 ? dangerSoft : (kurus < 0 ? okSoft : surface2);

  /// Bakiye etiketi — tasarımdaki üç sözcük.
  static String bakiyeEtiket(int kurus) =>
      kurus > 0 ? 'Borç' : (kurus < 0 ? 'Alacak' : 'Temiz');

  /// Stepper düğmesi / toggle topuzu (CSS `.app.koyu .ys-stepper button`).
  Color get knob => koyu ? const Color(0xFF3A3548) : const Color(0xFFFFFFFF);

  /// Devre dışı birincil düğme (CSS `.btn-p:disabled` + koyu tema geçersiz kılması).
  Color get disabledFill => koyu ? const Color(0xFF423C52) : line2;
  Color get disabledInk =>
      koyu ? const Color(0x66FFFFFF) : const Color(0xFFFFFFFF);

  /// Toast — koyu temada tersine döner (CSS `.app.koyu .toast`).
  Color get toastFill => koyu ? ink : hero;
  Color get toastInk => koyu ? const Color(0xFF17141F) : onHero;

  @override
  SipTokens copyWith({
    Color? canvas,
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? ink,
    Color? ink2,
    Color? muted,
    Color? line,
    Color? line2,
    Color? accent,
    Color? accentInk,
    Color? accentSoft,
    Color? hero,
    Color? hero2,
    Color? danger,
    Color? dangerSoft,
    Color? ok,
    Color? okSoft,
    Color? warn,
    Color? warnSoft,
    bool? koyu,
  }) {
    return SipTokens(
      canvas: canvas ?? this.canvas,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      hero: hero ?? this.hero,
      hero2: hero2 ?? this.hero2,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      ok: ok ?? this.ok,
      okSoft: okSoft ?? this.okSoft,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      koyu: koyu ?? this.koyu,
    );
  }

  @override
  SipTokens lerp(ThemeExtension<SipTokens>? other, double t) {
    if (other is! SipTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SipTokens(
      canvas: c(canvas, other.canvas),
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      muted: c(muted, other.muted),
      line: c(line, other.line),
      line2: c(line2, other.line2),
      accent: c(accent, other.accent),
      accentInk: c(accentInk, other.accentInk),
      accentSoft: c(accentSoft, other.accentSoft),
      hero: c(hero, other.hero),
      hero2: c(hero2, other.hero2),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      ok: c(ok, other.ok),
      okSoft: c(okSoft, other.okSoft),
      warn: c(warn, other.warn),
      warnSoft: c(warnSoft, other.warnSoft),
      koyu: t < 0.5 ? koyu : other.koyu,
    );
  }
}

/// Köşe yarıçapları — CSS `--r1..--r4`.
abstract final class SipRadius {
  /// 12 — küçük çip · uyarı kutusu.
  static const double r1 = 12;

  /// 16 — liste satırı · input · standart kart.
  static const double r2 = 16;

  /// 22 — büyük kart · sheet üstü · çağrı kartı.
  static const double r3 = 22;

  /// 30 — hero eteği · giriş formu üstü.
  static const double r4 = 30;

  /// Tam yuvarlak (hap) — CSS `999px`.
  static const double hap = 999;

  static const BorderRadius br1 = BorderRadius.all(Radius.circular(r1));
  static const BorderRadius br2 = BorderRadius.all(Radius.circular(r2));
  static const BorderRadius br3 = BorderRadius.all(Radius.circular(r3));
  static const BorderRadius br4 = BorderRadius.all(Radius.circular(r4));
  static const BorderRadius brHap = BorderRadius.all(Radius.circular(hap));

  /// Hero eteği — yalnız alt köşeler yuvarlak.
  static const BorderRadius heroEtek = BorderRadius.only(
    bottomLeft: Radius.circular(r4),
    bottomRight: Radius.circular(r4),
  );

  /// Sheet — yalnız üst köşeler yuvarlak.
  static const BorderRadius sheetUst = BorderRadius.only(
    topLeft: Radius.circular(r3),
    topRight: Radius.circular(r3),
  );

  /// Çekmece — sağ köşeler yuvarlak (CSS `.cek`).
  static const BorderRadius cekmece = BorderRadius.only(
    topRight: Radius.circular(26),
    bottomRight: Radius.circular(26),
  );
}

/// Boşluk ölçeği — tasarımdaki tekrar eden padding/gap değerleri.
abstract final class SipSpace {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double x2 = 14;
  static const double x3 = 16;

  /// Ekran gövdesinin yatay iç boşluğu (CSS `.ekran-govde` → `0 18px`).
  static const double govde = 18;

  static const double x4 = 20;
  static const double x5 = 22;
  static const double x6 = 26;
}

/// `context.sip.accent` kısayolu. Tema uzantısı kayıtlı değilse AÇIK temaya düşer — böylece
/// widget testleri çıplak `MaterialApp` ile de patlamadan çalışır.
extension SipTokensContext on BuildContext {
  SipTokens get sip => Theme.of(this).extension<SipTokens>() ?? SipTokens.acik;
}
