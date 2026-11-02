import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla el modo de tema de la app.
///
/// Arranca en [ThemeMode.system] (sigue al celular). Si el usuario toca el
/// botón de sol/luna o lo elige en Perfil > Apariencia, se fuerza claro u
/// oscuro, y la elección se recuerda para la próxima vez.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  static const _key = 'mxguide_theme_mode';

  /// Lee la elección guardada. Se llama una vez al abrir la app.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    value = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  /// Cambia al modo contrario del que se está viendo ahora.
  void toggle(Brightness current) {
    setMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Regresa a seguir el modo del celular.
  void useSystem() => setMode(ThemeMode.system);

  void setMode(ThemeMode mode) {
    value = mode;
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_key, mode.name));
  }
}

/// Instancia global para usarla desde cualquier pantalla.
final themeController = ThemeController();
