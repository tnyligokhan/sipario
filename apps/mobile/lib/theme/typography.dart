// Sipario tasarım sistemi — TİPOGRAFİ.
// Handoff ölçeği: ekran başlığı 27/700, kart başlığı 17.5/600, ikincil 14/400, tutar 18/700…
// Rakam taşıyan her stil TABULAR (font-feature 'tnum') — defterle kuruş hizası için.

import 'package:flutter/material.dart';

import 'tokens.dart';

const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

/// Tasarıma özgü, anlamına göre adlandırılmış metin stilleri. Ekranlar renk/boyutu buradan alır.
abstract final class SipText {
  static const TextStyle screenTitle = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: SipColors.t1,
    height: 1.1,
  );

  /// Kart başlığı — müşteri adı, sipariş müşterisi (17.5/600).
  static const TextStyle cardTitle = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 17.5,
    fontWeight: FontWeight.w600,
    color: SipColors.t1,
    height: 1.2,
  );

  /// İkincil satır — telefon, ürün özeti (14/400, ikincil renk, tabular).
  static const TextStyle secondary = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SipColors.t2,
    fontFeatures: _tnum,
  );

  /// Soluk küçük metin — meta, altyazı (12.5/500, tabular).
  static const TextStyle muted = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: SipColors.t3,
    fontFeatures: _tnum,
  );

  /// Tutar — kart sağındaki toplam (18/700, tabular).
  static const TextStyle amount = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: SipColors.t1,
    fontFeatures: _tnum,
  );

  /// Bakiye rozeti metni (15/700, tabular) — renk çağıran tarafta.
  static const TextStyle badge = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontFeatures: _tnum,
  );

  /// Alt gezinme etiketi (11.5/600).
  static const TextStyle navLabel = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  );

  /// Bölüm etiketi — VERSAL, harf aralıklı (11/600).
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: SipColors.t3,
  );

  /// Boş-durum başlığı (18/600) ve altyazısı (14.5/400).
  static const TextStyle emptyTitle = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: SipColors.t1,
    height: 1.3,
  );
  static const TextStyle emptyBody = TextStyle(
    fontFamily: sipFontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    color: SipColors.t2,
    height: 1.5,
  );
}

/// Material widget'larının varsayılan görünümü için TextTheme — IBM Plex Sans + tasarım ölçeği.
/// (Bespoke öğeler SipText'i doğrudan kullanır; bu tema düğme/dialog/appbar gibi hazır widget'ları
/// tutarlı kılar.)
TextTheme buildSipTextTheme() {
  return const TextTheme(
    headlineSmall: SipText.screenTitle,
    titleLarge: SipText.screenTitle,
    titleMedium: SipText.cardTitle,
    titleSmall: TextStyle(
        fontFamily: sipFontFamily, fontSize: 15, fontWeight: FontWeight.w600, color: SipColors.t1),
    bodyLarge: TextStyle(
        fontFamily: sipFontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: SipColors.t1),
    bodyMedium: SipText.secondary,
    bodySmall: SipText.muted,
    labelLarge: TextStyle(
        fontFamily: sipFontFamily, fontSize: 15, fontWeight: FontWeight.w600),
    labelMedium: SipText.navLabel,
    labelSmall: SipText.sectionLabel,
  ).apply(fontFamily: sipFontFamily);
}
