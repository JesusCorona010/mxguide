/// Configuración del chatbot Mictlan (servicio aparte: repo mxguide-chatbot).
///
/// Se puede cambiar sin tocar código al compilar:
///   flutter run --dart-define=CHATBOT_URL=https://... --dart-define=CHATBOT_API_KEY=...
class ChatbotConfig {
  ChatbotConfig._();

  /// URL del servicio en Render (SIN "/" al final).
  static const String baseUrl = String.fromEnvironment(
    'CHATBOT_URL',
    defaultValue: 'https://mxguide-chatbot.onrender.com',
  );

  /// Valor de CHAT_API_KEY en Render (header x-api-key). Vacío si no se usa.
  static const String apiKey = String.fromEnvironment('CHATBOT_API_KEY');

  /// Render (plan gratis) duerme el servicio; la primera respuesta puede tardar.
  static const Duration timeout = Duration(seconds: 70);

  /// Cuántos mensajes anteriores se mandan como contexto.
  static const int historyLimit = 12;
}
