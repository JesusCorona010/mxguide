import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Fuentes de la app. Si luego cambian, solo se modifica aquí.
class AppFonts {
  AppFonts._();

  /// Títulos (display, headline y title).
  static const titles = 'Montserrat';

  /// Todo lo demás (textos, botones, inputs, etiquetas).
  static const body = 'Nunito';
}

/// Temas de MXGuide.
///
/// Mapeo de la paleta al ColorScheme:
///  - primary   → Jungle Teal  (botones, links, elementos activos)
///  - secondary → Sun Red      (acentos: la "X" del logo, favoritos, "Regístrate")
///  - tertiary  → Jaguar Ochre (botón central "+", destacados)
///  - onSurfaceVariant → texto secundario
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.jungleTealDark : AppColors.jungleTealLight,
      onPrimary: isDark ? AppColors.textPrimaryLight : Colors.white,
      secondary: isDark ? AppColors.sunRedDark : AppColors.sunRedLight,
      onSecondary: isDark ? AppColors.textPrimaryLight : Colors.white,
      tertiary: isDark ? AppColors.jaguarOchreDark : AppColors.jaguarOchreLight,
      onTertiary: AppColors.textPrimaryLight,
      error: isDark ? AppColors.errorDark : AppColors.errorLight,
      onError: isDark ? AppColors.textPrimaryLight : Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
    );

    // ───────────── Tipografía ─────────────
    // Nunito para todo, y encima Montserrat para los estilos de título.
    final baseText = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    final bodyText = GoogleFonts.getTextTheme(AppFonts.body, baseText);

    TextStyle? title(TextStyle? style) => style == null
        ? null
        : GoogleFonts.getFont(AppFonts.titles, textStyle: style, fontWeight: FontWeight.w700);

    final textTheme = bodyText
        .copyWith(
          displayLarge: title(bodyText.displayLarge),
          displayMedium: title(bodyText.displayMedium),
          displaySmall: title(bodyText.displaySmall),
          headlineLarge: title(bodyText.headlineLarge),
          headlineMedium: title(bodyText.headlineMedium),
          headlineSmall: title(bodyText.headlineSmall),
          titleLarge: title(bodyText.titleLarge),
          titleMedium: title(bodyText.titleMedium),
          titleSmall: title(bodyText.titleSmall),
        )
        .apply(bodyColor: textPrimary, displayColor: textPrimary);

    final buttonText = GoogleFonts.getFont(
      AppFonts.body,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(scheme.primary, 2),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 2),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: buttonText.copyWith(fontSize: 14),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}