// Sipario tasarım sistemi — TOKEN'lar (tek kaynak).
// Claude Design handoff'undan (design_handoff/) çıkarıldı; DESIGN_SYSTEM.md bu dosyayı özetler.
// KURAL: ekranlarda ham renk/ölçü/yarıçap KULLANILMAZ — her şey buradan gelir.
//
// Palet felsefesi: simsiyah değil, KATMANLI koyu yüzeyler (elevation'ı renk taşır); su temalı
// tek vurgu rengi (Azur); borçluyu bir bakışta ayıran kırmızı. Rakamlar her yerde tabular.

import 'package:flutter/material.dart';

/// Uygulama fontu — IBM Plex Sans (assets/fonts, OFL). Ağırlıklar: 400/600/700 gömülü,
/// 500 istenirse Flutter en yakınına düşer.
const String sipFontFamily = 'IBMPlexSans';

/// Renk token'ları. Yarı saydam çizgi/soft renkler bilinçlidir: altlarındaki katmanlı yüzey
/// görünsün diye (M3 ColorScheme'e sığmayan bu değerler doğrudan buradan okunur).
abstract final class SipColors {
  // — Yüzeyler (elevation'ı koyuluk taşır) —
  static const Color bg = Color(0xFF0C1015); // zemin / scaffold
  static const Color s1 = Color(0xFF141A21); // yüzey 1 — kart, alt gezinme, appbar
  static const Color s2 = Color(0xFF1C242D); // yüzey 2 — arama alanı, segment rayı, popup kartı
  static const Color s3 = Color(0xFF28323C); // yüzey 3 — avatar, ikincil buton, çip

  // — Çizgiler (yarı saydam; katmanın üstünde ince ayrım) —
  static const Color line = Color(0x12FFFFFF); // beyaz %7 — kart kenarı
  static const Color line2 = Color(0x1FFFFFFF); // beyaz %12 — daha belirgin kenar

  // — Metin —
  static const Color t1 = Color(0xFFEEF2F5); // birincil
  static const Color t2 = Color(0xFF9AA6B2); // ikincil
  static const Color t3 = Color(0xFF5F6975); // soluk

  // — Vurgu (su · Azur; handoff'ta Turkuaz/Deniz mavisi alternatifleri var) —
  static const Color acc = Color(0xFF23A9E0); // FAB · seçili tab · birincil aksiyon
  static const Color accFg = Color(0xFF54C4EE); // koyu üstünde ikon/yazı
  static const Color accInk = Color(0xFF06131B); // vurgu dolgusu üstünde yazı/ikon (koyu)
  static const Color accSoft = Color(0x2623A9E0); // %15 — seçili zemin

  // — Durum —
  static const Color debt = Color(0xFFE85640); // borç (== err)
  static const Color debtSoft = Color(0x29E85640); // %16
  static const Color ok = Color(0xFF41B883); // başarılı / alacak
  static const Color okInk = Color(0xFF06231B); // ok dolgusu üstünde yazı (koyu)
  static const Color okSoft = Color(0x2641B883); // %15 — teslim rozeti / temiz şerit
  static const Color warn = Color(0xFFE7A93C); // uyarı
  static const Color warnSoft = Color(0x26E7A93C); // %15
  static const Color err = debt;

  // — ColorScheme için opak yardımcılar (M3 slotları saydam sevmez) —
  static const Color outline = Color(0xFF3A434D);
  static const Color outlineVariant = Color(0xFF232B33);
}

/// Köşe yarıçapları (handoff "Yumuşak" varsayılanı; "Keskin" varyantı: 10/8/12/10).
abstract final class SipRadius {
  static const double card = 16; // kart · birincil buton
  static const double sm = 11; // bakiye rozeti · küçük çip
  static const double fab = 18; // FAB
  static const double input = 15; // arama / metin alanı
  static const double sheet = 22; // popup / alt sayfa

  static const BorderRadius cardBr = BorderRadius.all(Radius.circular(card));
  static const BorderRadius smBr = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius inputBr = BorderRadius.all(Radius.circular(input));
  static const BorderRadius sheetBr = BorderRadius.all(Radius.circular(sheet));
}

/// Aralık ölçeği (8pt tabanlı; handoff'taki sık kullanılan ara değerler dahil).
abstract final class SipSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double gap = 10; // liste kartları arası
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 22;
  static const double section = 26;
}
