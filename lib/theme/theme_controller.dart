import 'package:flutter/material.dart';

/// Controla el modo de tema de la app.
///
/// Arranca en [ThemeMode.system] (sigue al celular). Si el usuario toca el
/// botón de sol/luna, se fuerza claro u oscuro.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  /// Cambia al modo contrario del que se está viendo ahora.
  void toggle(Brightness current) {
    value = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
  }

  /// Regresa a seguir el modo del celular.
  void useSystem() => value = ThemeMode.system;
}

/// Instancia global para usarla desde cualquier pantalla.
final themeController = ThemeController();