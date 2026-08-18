// Sipario tasarım sistemi — TOKEN'lar (tek kaynak).
// SİPARİO 3.0 kimliği: koyu gece-mürekkep hero · aydınlık gövde · elektrik moru vurgu.
// Yüzeyler DÜZ (flat): gölge yok, katman ton farkıyla kurulur.
//
// AÇIK tema tasarımın `:root` bloğunun birebir Dart karşılığıdır.
// KOYU tema ARTIK `.app.koyu`nun kopyası DEĞİLDİR (bkz. [koyuTema] başlığı) — CSS'e bakıp
// "Dart sapmış" diye geri almayın, sapma kasıtlıdır ve ölçülmüştür.
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

  /// KOYU tema — MARKAYA SADIK ama GÖZE YUMUŞAK (karar 2026-08-19; ölçüm DESIGN_SYSTEM.md).
  ///
  /// Eskiden `.app.koyu` CSS bloğunun birebir kopyasıydı: açık temanın doymuş elektrik moru
  /// (`#5A45F0`) koyu zemine olduğu gibi taşınıyordu. Ölçüm bunun iki ayrı arıza olduğunu
  /// gösterdi: (1) mor, koyu yüzeyde 2,9:1'de kalıyordu — WCAG AA'nın (4,5:1) ALTINDA, yani
  /// vurgu okunmuyordu; (2) OKLCH kroması 0,242 ile paletin en doymuş rengiydi ve koyu zeminde
  /// doymuş mavi-mor "optik titreşim" üretir (göz kırmızıyı ve moru aynı anda odaklayamaz).
  /// İkisi birden "koyu tema gözümü yoruyor" şikâyetinin ta kendisidir.
  ///
  /// Üç kural (Material'ın koyu tema rehberiyle aynı yönde):
  ///   1. VURGU KOYUDA AÇILIR. Marka moru hue'sunu korur, AÇILIR ve doygunluğu düşer
  ///      (OKLCH L .53→.75, C .242→.12). Üstündeki mürekkep buna bağlı olarak TERSİNE döner:
  ///      koyuda `accentInk` beyaz değil, KOYUDUR. Aynısı danger/ok/warn için de geçerli —
  ///      onların dolgu mürekkebi [durumInk]'tir.
  ///   2. MOR HER YERDE DEĞİL. Nötrlerin mor tenti yarıya indi (kroma ~.026 → ~.010): ekran
  ///      artık mor bir sis değil, nötr kömür; mor yalnız VURGU ve HERO'da görünür. Markanın
  ///      görünürlüğü azalmaz, gürültüsü azalır.
  ///   3. BEYAZ IŞIK KISILIR. `ink` 16,5:1'den 13,5:1'e indi. Saf beyaza yakın metin koyu
  ///      zeminde "halation" (harflerin etrafında hale) yapar; astigmatlı okurda bu doğrudan
  ///      göz yorgunluğudur. 13,5:1 hâlâ AAA'nın çok üstünde.
  ///
  /// Değişmeyen: AÇIK tema. Şikâyet koyu taraftaydı, açık taraf tasarımın `:root`'u kalır.
  static const SipTokens koyuTema = SipTokens(
    canvas: Color(0xFF09090C),
    bg: Color(0xFF161519),
    surface: Color(0xFF212026),
    surface2: Color(0xFF2E2D34),
    ink: Color(0xFFDEDDE2),
    ink2: Color(0xFFB9B8BE),
    muted: Color(0xFF909097),
    line: Color(0xFF302F36),
    line2: Color(0xFF484650),
    accent: Color(0xFFA9A0F4),
    accentInk: Color(0xFF151422),
    accentSoft: Color(0xFF2B2940),
    hero: Color(0xFF100E18),
    hero2: Color(0xFF1C1A26),
    danger: Color(0xFFE7827C),
    dangerSoft: Color(0xFF442524),
    ok: Color(0xFF6AC796),
    okSoft: Color(0xFF193426),
    warn: Color(0xFFE2B466),
    warnSoft: Color(0xFF3B2C13),
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
  Color get knob => koyu ? const Color(0xFF37363C) : const Color(0xFFFFFFFF);

  /// Devre dışı birincil düğme (CSS `.btn-p:disabled` + koyu tema geçersiz kılması).
  Color get disabledFill => koyu ? const Color(0xFF414048) : line2;
  Color get disabledInk =>
      koyu ? const Color(0x66FFFFFF) : const Color(0xFFFFFFFF);

  /// DURUM DOLGUSU üstündeki mürekkep — `danger` / `ok` / `warn` bir ZEMİN olarak
  /// kullanıldığında (tehlike düğmesi, senkron bandı, sihirbaz rozeti) üstüne bu renk yazılır.
  /// Açık temada beyazdır — yani eski davranış. Koyu temada durum renkleri AÇILDIĞI için
  /// beyaz üstlerinde okunmaz (1,3:1); mürekkep koyuya döner. `accentInk`in durum renkleri
  /// için karşılığıdır; ayrı bir jeton olmasının sebebi vurgu ile durumun bağımsız
  /// ayarlanabilmesidir.
  Color get durumInk => koyu ? const Color(0xFF16151E) : const Color(0xFFFFFFFF);

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
