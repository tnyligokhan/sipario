// Sipario tasarım sistemi — TEMA (ThemeData).
// Jetonları (tokens.dart) ve tipografiyi (typography.dart) Material 3 ThemeData'ya bağlar; asıl
// jeton taşıyıcısı [SipTokens] uzantısıdır (`context.sip`). ThemeData yalnız hazır Material
// widget'larının (input/buton/dialog/snackbar) tasarıma uymasını sağlar.
//
// İKİ TEMA: [acik] tasarımın varsayılanıdır, [koyu] CSS `.app.koyu` bloğudur. Kullanıcı
// Ayarlar'dan değiştirir; seçim yerelde saklanır (bkz. tema_deposu.dart).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/form.dart';
import 'tokens.dart';
import 'typography.dart';

abstract final class SipTheme {
  static ThemeData acik() => _kur(SipTokens.acik, Brightness.light);

  static ThemeData koyu() => _kur(SipTokens.koyuTema, Brightness.dark);

  /// Sistem çubukları (durum + gezinme) tema ile birlikte döner. Ana ekranın hero'su koyu
  /// olduğundan durum çubuğu ikonları AÇIK temada bile beyazdır — bunu ekran kendi
  /// [AnnotatedRegion]'ıyla ayarlar; burada varsayılan verilir.
  static SystemUiOverlayStyle sistemCubuklari(SipTokens t) => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: t.koyu ? Brightness.light : Brightness.dark,
        statusBarBrightness: t.koyu ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: t.bg,
        systemNavigationBarIconBrightness:
            t.koyu ? Brightness.light : Brightness.dark,
      );

  static ThemeData _kur(SipTokens t, Brightness parlaklik) {
    final scheme = ColorScheme(
      brightness: parlaklik,
      primary: t.accent,
      onPrimary: t.accentInk,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: t.accent,
      secondary: t.accent,
      onSecondary: t.accentInk,
      secondaryContainer: t.accentSoft,
      onSecondaryContainer: t.accent,
      tertiary: t.ok,
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: t.okSoft,
      onTertiaryContainer: t.ok,
      error: t.danger,
      onError: const Color(0xFFFFFFFF),
      errorContainer: t.dangerSoft,
      onErrorContainer: t.danger,
      surface: t.surface,
      onSurface: t.ink,
      surfaceContainerLowest: t.bg,
      surfaceContainerLow: t.bg,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.surface2,
      surfaceContainerHighest: t.surface2,
      onSurfaceVariant: t.ink2,
      outline: t.line2,
      outlineVariant: t.line,
      shadow: const Color(0xFF000000),
      scrim: SipTokens.scrim,
      inverseSurface: t.hero,
      onInverseSurface: SipTokens.onHero,
      inversePrimary: t.accentSoft,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: parlaklik,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,

      // Tasarımda hiçbir yerde ripple YOK — dokunma geri bildirimi zeminin bir ton
      // koyulaşmasıdır (bkz. components/dokunma.dart). Material dalgası kapatılır.
      splashFactory: NoSplash.splashFactory,

      // Gövde fontu varsayılan; başlık/rakam stilleri SipText üzerinden nokta atışı verilir.
      fontFamily: sipFontBody,
      extensions: <ThemeExtension<dynamic>>[t],

      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(
            fontFamily: sipFontBody,
            bodyColor: t.ink,
            displayColor: t.ink,
          )
          .copyWith(
            titleLarge: SipText.ustBaslik,
            titleMedium: SipText.bolumBaslik,
            titleSmall: SipText.govdeKalin,
            bodyLarge: SipText.input,
            bodyMedium: SipText.govde,
            bodySmall: SipText.yardimci,
            labelLarge: SipText.buton,
          )
          .apply(bodyColor: t.ink, displayColor: t.ink),

      iconTheme: IconThemeData(color: t.ink2, size: 22),

      // Tasarımda AppBar yok — her ekran kendi `Ust` başlığını çizer. Yine de bir yerde
      // kullanılırsa zeminle kaynaşsın.
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: SipText.ustBaslik.copyWith(color: t.ink),
      ),

      // CSS .s-input — saydam kenarlık, surface-2 zemin; odakta accent kenarlık + surface zemin.
      //
      // ÖLÇÜLER [SipInputOlcu]'DAN GELİR. Uygulamadaki her girdi [SipInput] atomudur; bu blok
      // yalnız `labelText`/`errorText` kullanan çıplak `TextField`ler (bkz. phase0_screen.dart)
      // için vardır. Sayılar burada TEKRAR YAZILMAZ — yoksa girdi ölçüsünün iki kaynağı olur
      // ve biri düzeltilirken diğeri sessizce eskir.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface2,
        isDense: true,
        visualDensity: VisualDensity.standard,
        contentPadding: EdgeInsets.symmetric(
          horizontal: SipInputOlcu.yatayDolgu,
          vertical: SipInputOlcu.dikeyDolgu(
            SipText.input,
            SipInputOlcu.yukseklik,
          ),
        ),
        hintStyle: SipText.input.copyWith(color: t.muted),
        labelStyle: SipText.formEtiket.copyWith(color: t.muted),
        floatingLabelStyle: SipText.formEtiket.copyWith(color: t.accent),
        errorStyle: SipText.yardimci.copyWith(color: t.danger),
        border: SipInputOlcu.kenar(Colors.transparent),
        enabledBorder: SipInputOlcu.kenar(Colors.transparent),
        disabledBorder: SipInputOlcu.kenar(Colors.transparent),
        focusedBorder: SipInputOlcu.kenar(t.accent),
        errorBorder: SipInputOlcu.kenar(t.danger),
        focusedErrorBorder: SipInputOlcu.kenar(t.danger),
      ),

      // CSS .btn-p — 48 yüksek, r2 köşe, gölgesiz.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentInk,
          disabledBackgroundColor: t.disabledFill,
          disabledForegroundColor: t.disabledInk,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          textStyle: SipText.buton,
          shape: const RoundedRectangleBorder(borderRadius: SipRadius.br2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          textStyle: SipText.link,
          shape: const RoundedRectangleBorder(borderRadius: SipRadius.br2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          backgroundColor: t.surface2,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide.none,
          textStyle: SipText.buton,
          shape: const RoundedRectangleBorder(borderRadius: SipRadius.br2),
        ),
      ),

      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: SipRadius.br3),
        titleTextStyle: SipText.diyalogBaslik.copyWith(color: t.ink),
        contentTextStyle: SipText.diyalogMesaj.copyWith(color: t.ink2),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: SipRadius.sheetUst),
      ),

      // Tasarımda SnackBar yerine ortalanmış hap "toast" var (bkz. components/toast.dart).
      // Kaçan çağrılar da hiç değilse doğru görünsün.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.toastFill,
        contentTextStyle: SipText.toast.copyWith(color: t.toastInk),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: SipRadius.brHap),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.surface2,
        circularTrackColor: t.surface2,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : t.knob,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.line2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: t.ink2,
        textColor: t.ink,
        titleTextStyle: SipText.govdeKalin.copyWith(color: t.ink),
        subtitleTextStyle: SipText.yardimci.copyWith(color: t.muted),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: SipRadius.br2),
        textStyle: SipText.govdeKalin.copyWith(color: t.ink),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.accent,
        selectionColor: t.accentSoft,
        selectionHandleColor: t.accent,
      ),
    );
  }
}
