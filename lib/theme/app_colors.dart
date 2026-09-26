import 'package:flutter/material.dart';

/// Paleta oficial de MXGuide.
/// No uses estos colores directo en los widgets: usa Theme.of(context).colorScheme
/// para que cambien solos entre modo claro y oscuro.
class AppColors {
  AppColors._();

  // ───────────── Light mode ─────────────
  static const sunRedLight = Color(0xFFD32F2F);
  static const jungleTealLight = Color(0xFF00796B);
  static const jaguarOchreLight = Color(0xFFD87B1E);

  static const backgroundLight = Color(0xFFF5F5F0);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF0A1A2F);
  static const textSecondaryLight = Color(0xFF607D8B);
  static const borderLight = Color(0xFFCFD6DA);
  static const errorLight = Color(0xFFB3261E);

  // ───────────── Dark mode ─────────────
  static const sunRedDark = Color(0xFFE57373);
  static const jungleTealDark = Color(0xFF4DB6AC);
  static const jaguarOchreDark = Color(0xFFFFB74D);

  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const textPrimaryDark = Color(0xFFFFFFFF);
  static const textSecondaryDark = Color(0xFFB0BEC5);
  static const borderDark = Color(0xFF333333);
  static const errorDark = Color(0xFFF2B8B5);
}

/// Colores extra que no vienen en la paleta base pero se derivan de ella.
class AppExtraColors {
  AppExtraColors._();

  /// Fondo de los chips de filtro no seleccionados.
  static const chipLight = Color(0xFFE4ECEA);
  static const chipDark = Color(0xFF262B2B);

  /// Fondo mientras carga (o falla) la imagen de un lugar.
  static const imagePlaceholderLight = Color(0xFFE0E6E4);
  static const imagePlaceholderDark = Color(0xFF263238);

  /// Fondo de la etiqueta de categoría sobre las fotos (azul marino al 75%).
  static const badgeOverlay = Color(0xBF0A1A2F);
}