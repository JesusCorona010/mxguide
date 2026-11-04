/// Configuración de la API de MXGuide.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl =
      'https://mxguide-backend.onrender.com';

  /// Render puede tardar en despertar si el servicio está inactivo.
  static const Duration timeout = Duration(seconds: 60);

  /// ID de cliente de Google tipo "Aplicación web": el mismo que el backend
  /// tiene en GOOGLE_CLIENT_ID. Sin él, el botón de Google no puede arrancar.
  /// Se puede poner aquí o al correr: --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  /// Miniatura de un lugar.
  static String placeThumbnail(String placeId) =>
      '$baseUrl/place-images/$placeId';
}
