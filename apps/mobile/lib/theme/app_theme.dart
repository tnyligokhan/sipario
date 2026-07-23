// Sipario tasarım sistemi — TEMA (ThemeData).
// Token'ları (tokens.dart) + tipografiyi (typography.dart) Material 3 ThemeData'ya bağlar.
// Böylece hazır Material widget'ları (buton/dialog/appbar/nav/input) ekran başına stil yazmadan
// tasarıma uyar; bespoke öğeler SipColors/SipText'i doğrudan kullanır.

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class SipTheme {
  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: SipColors.acc,
      onPrimary: SipColors.accInk,
      primaryContainer: Color(0xFF0E3648),
      onPrimaryContainer: SipColors.accFg,
      secondary: SipColors.accFg,
      onSecondary: SipColors.accInk,
      secondaryContainer: Color(0xFF14323F),
      onSecondaryContainer: Color(0xFFCDE9F6),
      tertiary: SipColors.ok,
      onTertiary: SipColors.okInk,
      tertiaryContainer: Color(0xFF123A2C),
      onTertiaryContainer: Color(0xFF8FE0BE),
      error: SipColors.err,
      onError: Colors.white,
      errorContainer: Color(0xFF3A1A15),
      onErrorContainer: Color(0xFFF3B4AA),
      surface: SipColors.s1,
      onSurface: SipColors.t1,
      surfaceContainerLowest: SipColors.bg,
      surfaceContainerLow: SipColors.s1,
      surfaceContainer: SipColors.s2,
      surfaceContainerHigh: SipColors.s3,
      surfaceContainerHighest: Color(0xFF313B45),
      onSurfaceVariant: SipColors.t2,
      outline: SipColors.outline,
      outlineVariant: SipColors.outlineVariant,
    );

    final textTheme = buildSipTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: SipColors.bg,
      canvasColor: SipColors.bg,
      fontFamily: sipFontFamily,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: SipColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: SipText.screenTitle,
        iconTheme: IconThemeData(color: SipColors.t1),
      ),

      // Alt gezinme — handoff: seçilide hap (pill) göstergesi + vurgu ikon/etiket.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SipColors.s1,
        surfaceTintColor: Colors.transparent,
        indicatorColor: SipColors.accSoft,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? SipColors.accFg : SipColors.t3,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => SipText.navLabel.copyWith(
              color: s.contains(WidgetState.selected) ? SipColors.accFg : SipColors.t3,
            )),
      ),

      // FAB — genişletilmiş, vurgu dolgu, koyu yazı, yumuşak köşe.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: SipColors.acc,
        foregroundColor: SipColors.accInk,
        elevation: 6,
        focusElevation: 6,
        hoverElevation: 8,
        highlightElevation: 10,
        extendedTextStyle: TextStyle(
            fontFamily: sipFontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(SipRadius.fab))),
      ),

      // Arama / metin alanı — yüzey 2 dolgu, kenarlıksız, yuvarlak.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SipColors.s2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: SipColors.t3, fontSize: 16),
        prefixIconColor: SipColors.t3,
        suffixIconColor: SipColors.t3,
        border: OutlineInputBorder(borderRadius: SipRadius.inputBr, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: SipRadius.inputBr,
            borderSide: const BorderSide(color: SipColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: SipRadius.inputBr,
            borderSide: const BorderSide(color: SipColors.acc, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: SipRadius.inputBr,
            borderSide: const BorderSide(color: SipColors.err)),
      ),

      cardTheme: CardThemeData(
        color: SipColors.s1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: SipRadius.cardBr,
          side: const BorderSide(color: SipColors.line),
        ),
      ),

      dividerTheme: const DividerThemeData(color: SipColors.line, thickness: 1, space: 1),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SipColors.acc,
          foregroundColor: SipColors.accInk,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
              fontFamily: sipFontFamily, fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: SipRadius.cardBr),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: SipColors.accFg),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SipColors.t1,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: SipColors.line2),
          shape: RoundedRectangleBorder(borderRadius: SipRadius.cardBr),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: SipColors.s3,
        contentTextStyle: const TextStyle(color: SipColors.t1, fontFamily: sipFontFamily),
        shape: RoundedRectangleBorder(borderRadius: SipRadius.smBr),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: SipColors.s2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: SipRadius.sheetBr),
        titleTextStyle: const TextStyle(
            fontFamily: sipFontFamily, fontSize: 19, fontWeight: FontWeight.w700, color: SipColors.t1),
        contentTextStyle: const TextStyle(
            fontFamily: sipFontFamily, fontSize: 15, color: SipColors.t2, height: 1.5),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: SipColors.t2,
        textColor: SipColors.t1,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SipColors.s2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: SipRadius.sheetBr),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: SipColors.s3,
        side: BorderSide.none,
        labelStyle: const TextStyle(
            fontFamily: sipFontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: SipColors.t2),
        shape: RoundedRectangleBorder(borderRadius: SipRadius.smBr),
      ),
    );
  }
}
