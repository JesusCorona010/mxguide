import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/chatbot_config.dart';
import 'auth_service.dart';

/// Un lugar que Mictlan recomendó (viene del catálogo de MXGuide).
class ChatPlace {
  const ChatPlace({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String state;
  final String category;
  final double? distanceKm;

  factory ChatPlace.fromJson(Map<String, dynamic> json) => ChatPlace(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        state: json['state'] as String? ?? '',
        category: json['category'] as String? ?? '',
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      );
}

enum ChatAuthor { user, bot }

class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    this.places = const [],
    this.isError = false,
  });

  final ChatAuthor author;
  final String text;
  final List<ChatPlace> places;

  /// Mensaje de error de la app (no se manda como historial al servidor).
  final bool isError;

  bool get isUser => author == ChatAuthor.user;
}

/// Conversación con Mictlan. Vive mientras la app está abierta, así que al
/// cerrar y volver a abrir la burbuja la plática sigue ahí.
class ChatbotService extends ChangeNotifier {
  ChatbotService._();
  static final instance = ChatbotService._();

  static const _bubbleKey = 'mxguide_chat_bubble_visible';

  final List<ChatMessage> _messages = [];
  List<String> _suggestions = const [];
  bool _isSending = false;
  bool _isSlow = false;
  bool _bubbleVisible = true;
  String? _lastFailedText;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get suggestions => _suggestions;
  bool get isSending => _isSending;

  /// true si la respuesta está tardando (el servidor se está despertando).
  bool get isSlow => _isSlow;
  bool get bubbleVisible => _bubbleVisible;
  bool get canRetry => _lastFailedText != null && !_isSending;

  // ───────────── Burbuja ─────────────

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _bubbleVisible = prefs.getBool(_bubbleKey) ?? true;
    notifyListeners();
  }

  Future<void> setBubbleVisible(bool visible) async {
    _bubbleVisible = visible;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bubbleKey, visible);
  }

  // ───────────── Conversación ─────────────

  void reset() {
    _messages.clear();
    _suggestions = const [];
    _lastFailedText = null;
    notifyListeners();
  }

  Future<void> retry() async {
    final text = _lastFailedText;
    if (text == null || _isSending) return;
    // Quita el mensaje de error y vuelve a intentar con el mismo texto.
    if (_messages.isNotEmpty && _messages.last.isError) _messages.removeLast();
    await _ask(text, addUserMessage: false);
  }

  Future<void> send(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _isSending) return;
    await _ask(clean.length > 1000 ? clean.substring(0, 1000) : clean, addUserMessage: true);
  }

  Future<void> _ask(String text, {required bool addUserMessage}) async {
    // El historial se arma ANTES de agregar el mensaje nuevo (y en un
    // reintento, sin la pregunta que falló, que ya estaba en la lista).
    final previous = _messages.where((m) => !m.isError).toList();
    if (!addUserMessage && previous.isNotEmpty && previous.last.isUser) previous.removeLast();
    final history = previous.reversed
        .take(ChatbotConfig.historyLimit)
        .toList()
        .reversed
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    if (addUserMessage) _messages.add(ChatMessage(author: ChatAuthor.user, text: text));
    _isSending = true;
    _isSlow = false;
    _lastFailedText = null;
    _suggestions = const [];
    notifyListeners();

    final slowTimer = Timer(const Duration(seconds: 6), () {
      _isSlow = true;
      notifyListeners();
    });

    try {
      final location = await _currentLocation();
      final firstName = AuthService.instance.user?.name.trim().split(RegExp(r'\s+')).first;

      final response = await http
          .post(
            Uri.parse('${ChatbotConfig.baseUrl}/chat'),
            headers: {
              'Content-Type': 'application/json',
              if (ChatbotConfig.apiKey.isNotEmpty) 'x-api-key': ChatbotConfig.apiKey,
            },
            body: jsonEncode({
              'message': text,
              if (history.isNotEmpty) 'history': history,
              if (firstName != null && firstName.isNotEmpty) 'userName': firstName,
              if (location != null) 'location': {'lat': location.latitude, 'lng': location.longitude},
            }),
          )
          .timeout(ChatbotConfig.timeout);

      if (response.statusCode != 200) throw _ChatError(_errorFor(response.statusCode));

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      _messages.add(
        ChatMessage(
          author: ChatAuthor.bot,
          text: (data['reply'] as String? ?? '').trim(),
          places: [
            for (final p in (data['places'] as List? ?? const []))
              if (p is Map<String, dynamic>) ChatPlace.fromJson(p),
          ],
        ),
      );
      _suggestions = [
        for (final s in (data['suggestions'] as List? ?? const []))
          if (s is String) s,
      ];
    } catch (error) {
      _lastFailedText = text;
      final message = switch (error) {
        _ChatError(:final message) => message,
        TimeoutException() => 'Mictlan tardó demasiado en responder. Intenta de nuevo.',
        _ => 'No pudimos conectar con Mictlan. Revisa tu internet.',
      };
      _messages.add(ChatMessage(author: ChatAuthor.bot, text: message, isError: true));
    } finally {
      slowTimer.cancel();
      _isSending = false;
      _isSlow = false;
      notifyListeners();
    }
  }

  static String _errorFor(int status) => switch (status) {
        401 => 'El chat no está bien configurado (llave inválida).',
        429 => 'Vas muy rápido. Espera un momento y vuelve a preguntar.',
        503 => 'Mictlan está descansando un momento. Intenta de nuevo en un rato.',
        _ => 'Algo salió mal (código $status). Intenta de nuevo.',
      };

  /// Ubicación solo si el usuario YA dio permiso; nunca lo pide aquí.
  static Future<Position?> _currentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// Pide permiso de ubicación (botón "Activar" de la bienvenida).
  static Future<bool> requestLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}

class _ChatError implements Exception {
  const _ChatError(this.message);
  final String message;
}
