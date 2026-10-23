import 'package:flutter/foundation.dart';

/// Configuración compartida para hablar con el backend (NestJS).
///
/// Centraliza la detección de host/puerto para que [PlaceService] (lista de
/// lugares) y [Place] (miniaturas de `/place-images`, ver modelo) le
/// peguen siempre a la misma URL base, en vez de tener la misma lógica
/// copiada en dos archivos.
///
class ApiConfig {
  ApiConfig._();

  /// URL del backend desplegado en Render (SIN "/" al final y SIN "/api":
  /// el backend expone las rutas directo, ej. /places, /auth/register).
  /// Se puede sobreescribir al compilar: --dart-define=API_URL=https://...
  static const String _prodUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://mxguide-backend.onrender.com',
  );

  /// Para desarrollar contra tu backend local:
  /// flutter run --dart-define=USE_LOCAL=true
  static const bool _useLocal = bool.fromEnvironment('USE_LOCAL', defaultValue: false);

  /// Puerto del backend local (solo se usa con USE_LOCAL=true).
  static const port = 3000;

  static String get baseUrl {
    if (!_useLocal) return _prodUrl;
    if (kIsWeb) return 'http://localhost:$port';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:$port';
    return 'http://localhost:$port';
  }

  /// Render (plan gratis) duerme el servidor y la primera petición puede
  /// tardar ~50 s, por eso el timeout es largo.
  static const Duration timeout = Duration(seconds: 60);
}
