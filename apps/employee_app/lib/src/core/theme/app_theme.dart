import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const canvasNight = Color(0xFF000000);
  static const canvasNightSoft = Color(0xFF0A0A0A);
  static const canvasLight = Color(0xFFFFFFFF);
  static const canvasCool = Color(0xFFF0F0FA);
  static const hairlineOnDark = Color(0xFF3A3A3F);
  static const hairlineOnLight = Color(0xFFE0E0E8);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryMute = Color(0xFFF0F0FA);
  static const ink = Color(0xFF000000);
  static const inkMute = Color(0xFF5A5A5F);
  static const error = Color(0xFFFF6B6B);

  static const _fontFallback = ['Arial Narrow', 'Arial', 'Verdana'];

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: onPrimary,
      secondary: onPrimaryMute,
      surface: canvasNightSoft,
      onPrimary: canvasNight,
      onSecondary: canvasNight,
      onSurface: onPrimary,
      error: error,
      onError: canvasNight,
      outline: hairlineOnDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvasNight,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: canvasNightSoft,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: hairlineOnDark),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvasNightSoft,
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(color: onPrimary),
        errorBorder: _inputBorder(color: error),
        focusedErrorBorder: _inputBorder(color: error),
        labelStyle: _microText(onPrimaryMute),
        hintStyle: _bodyText(onPrimaryMute),
        prefixIconColor: onPrimaryMute,
        suffixIconColor: onPrimaryMute,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _ghostButtonStyle(onPrimary, canvasNight),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _ghostButtonStyle(onPrimary, canvasNight),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(onPrimary, canvasNight),
      ),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle(onPrimary)),
      iconButtonTheme: IconButtonThemeData(style: _iconButtonStyle(onPrimary)),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(side: BorderSide(color: hairlineOnDark)),
        backgroundColor: canvasNightSoft,
        selectedColor: onPrimary.withValues(alpha: 0.12),
        labelStyle: _microText(onPrimary),
        side: const BorderSide(color: hairlineOnDark),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: hairlineOnDark,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: canvasNight,
        indicatorColor: onPrimary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => _microText(
            states.contains(WidgetState.selected) ? onPrimary : onPrimaryMute,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? onPrimary
                : onPrimaryMute,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: canvasNightSoft,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: hairlineOnDark),
        ),
        textStyle: _bodyText(onPrimary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: _segmentedButtonStyle(onPrimary, canvasNight),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: canvasNightSoft,
        contentTextStyle: _bodyText(onPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: hairlineOnDark),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: onPrimary,
        circularTrackColor: hairlineOnDark,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onPrimary,
        textColor: onPrimary,
        subtitleTextStyle: _bodyText(onPrimaryMute),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = darkTheme;
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: ink,
        secondary: inkMute,
        surface: canvasLight,
        onPrimary: canvasLight,
        onSecondary: canvasLight,
        onSurface: ink,
        error: error,
        onError: canvasLight,
        outline: hairlineOnLight,
      ),
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvasLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: canvasLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: hairlineOnLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvasLight,
        border: _inputBorder(color: hairlineOnLight),
        enabledBorder: _inputBorder(color: hairlineOnLight),
        focusedBorder: _inputBorder(color: ink),
        errorBorder: _inputBorder(color: error),
        focusedErrorBorder: _inputBorder(color: error),
        labelStyle: _microText(inkMute),
        hintStyle: _bodyText(inkMute),
        prefixIconColor: inkMute,
        suffixIconColor: inkMute,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      textTheme: _textTheme(Brightness.light),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _ghostButtonStyle(ink, canvasLight),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _ghostButtonStyle(ink, canvasLight),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(ink, canvasCool),
      ),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle(ink)),
      iconButtonTheme: IconButtonThemeData(style: _iconButtonStyle(ink)),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(side: BorderSide(color: hairlineOnLight)),
        backgroundColor: canvasLight,
        selectedColor: canvasCool,
        labelStyle: _microText(ink),
        side: const BorderSide(color: hairlineOnLight),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: hairlineOnLight,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: canvasLight,
        indicatorColor: canvasCool,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) =>
              _microText(states.contains(WidgetState.selected) ? ink : inkMute),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? ink : inkMute,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: canvasLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: hairlineOnLight),
        ),
        textStyle: _bodyText(ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: _segmentedButtonStyle(ink, canvasLight),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: _bodyText(canvasLight),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ink,
        circularTrackColor: hairlineOnLight,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ink,
        textColor: ink,
        subtitleTextStyle: _bodyText(inkMute),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final displayColor = isDark ? onPrimary : ink;
    final bodyColor = isDark ? onPrimaryMute : inkMute;

    return GoogleFonts.robotoCondensedTextTheme().copyWith(
      displayLarge: TextStyle(
        color: displayColor,
        fontFamilyFallback: _fontFallback,
        fontSize: 52,
        height: 0.95,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
      displayMedium: TextStyle(
        color: displayColor,
        fontFamilyFallback: _fontFallback,
        fontSize: 38,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      headlineLarge: TextStyle(
        color: displayColor,
        fontFamilyFallback: _fontFallback,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.96,
      ),
      titleLarge: TextStyle(
        color: displayColor,
        fontFamilyFallback: _fontFallback,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.96,
      ),
      bodyLarge: TextStyle(
        color: bodyColor,
        fontFamilyFallback: _fontFallback,
        fontSize: 16,
        height: 1.7,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.32,
      ),
      bodyMedium: TextStyle(
        color: bodyColor,
        fontFamilyFallback: _fontFallback,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.32,
      ),
      bodySmall: TextStyle(
        color: bodyColor,
        fontFamilyFallback: _fontFallback,
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: displayColor,
        fontFamilyFallback: _fontFallback,
        fontSize: 13,
        height: 0.94,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.17,
      ),
      labelMedium: _microText(displayColor),
      labelSmall: _microText(bodyColor),
    );
  }

  static TextStyle _bodyText(Color color) {
    return GoogleFonts.robotoCondensed(
      color: color,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.32,
    ).copyWith(fontFamilyFallback: _fontFallback);
  }

  static TextStyle _microText(Color color) {
    return GoogleFonts.robotoCondensed(
      color: color,
      fontSize: 12,
      height: 2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.96,
    ).copyWith(fontFamilyFallback: _fontFallback);
  }

  static ButtonStyle _ghostButtonStyle(Color foreground, Color canvas) {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foreground.withValues(alpha: 0.06);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foreground.withValues(alpha: 0.42);
        }
        return foreground;
      }),
      overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: 0.08)),
      side: WidgetStateProperty.resolveWith((states) {
        final alpha = states.contains(WidgetState.disabled) ? 0.18 : 1.0;
        return BorderSide(color: foreground.withValues(alpha: alpha));
      }),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.robotoCondensed(
          fontSize: 13,
          height: 0.94,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.17,
        ).copyWith(fontFamilyFallback: _fontFallback),
      ),
      surfaceTintColor: WidgetStatePropertyAll(canvas),
    );
  }

  static ButtonStyle _filledButtonStyle(Color foreground, Color background) {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return background.withValues(alpha: 0.4);
        }
        return background == canvasNight ? foreground : background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foreground.withValues(alpha: 0.42);
        }
        return background == canvasNight ? canvasNight : foreground;
      }),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.robotoCondensed(
          fontSize: 13,
          height: 0.94,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.17,
        ).copyWith(fontFamilyFallback: _fontFallback),
      ),
    );
  }

  static ButtonStyle _textButtonStyle(Color foreground) {
    return TextButton.styleFrom(
      foregroundColor: foreground,
      textStyle: GoogleFonts.robotoCondensed(
        fontSize: 13,
        height: 0.94,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.17,
      ).copyWith(fontFamilyFallback: _fontFallback),
    );
  }

  static ButtonStyle _iconButtonStyle(Color foreground) {
    return IconButton.styleFrom(
      foregroundColor: foreground,
      shape: const CircleBorder(),
    );
  }

  static ButtonStyle _segmentedButtonStyle(Color foreground, Color canvas) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return foreground.withValues(alpha: 0.12);
        }
        return canvas;
      }),
      foregroundColor: WidgetStatePropertyAll(foreground),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: foreground.withValues(
            alpha: states.contains(WidgetState.selected) ? 0.72 : 0.28,
          ),
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.robotoCondensed(
          fontSize: 13,
          height: 0.94,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.17,
        ).copyWith(fontFamilyFallback: _fontFallback),
      ),
    );
  }

  static OutlineInputBorder _inputBorder({Color color = hairlineOnDark}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: color),
    );
  }
}
