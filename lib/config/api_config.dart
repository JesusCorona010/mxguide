/// Configuración de la API de MXGuide. Si cambia la URL, solo se modifica aquí.
class ApiConfig {
  ApiConfig._();

  static const baseUrl = 'https://mxguide-backend.onrender.com';

  /// El plan gratuito de Render "duerme" el servidor y la primera petición
  /// puede tardar casi un minuto en despertarlo.
  static const timeout = Duration(seconds: 60);

  /// Miniatura ligera de un lugar (la sirve el backend desde su base de datos).
  static String placeThumbnail(String placeId) => '$baseUrl/place-images/$placeId';
}