/// Configuración de la API de MXGuide.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl =
      'https://mxguide-backend.onrender.com';

  /// Render puede tardar en despertar si el servicio está inactivo.
  static const Duration timeout = Duration(seconds: 60);

  /// Miniatura de un lugar.
  static String placeThumbnail(String placeId) =>
      '$baseUrl/place-images/$placeId';
}
