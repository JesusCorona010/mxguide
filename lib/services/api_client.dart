import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Cliente HTTP único para toda la app. Agrega el token de sesión
/// automáticamente y convierte los errores del backend en [ApiException].
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  final http.Client _http = http.Client();

  /// Token JWT de la sesión actual (lo administra AuthService).
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, {Object? body}) => _send(
        () => _http.post(
          _uri(path),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<dynamic> delete(String path) =>
      _send(() => _http.delete(_uri(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const ApiException('El servidor tardó demasiado en responder. Intenta de nuevo.');
    } catch (_) {
      throw const ApiException('No pudimos conectar con el servidor. Revisa tu internet.');
    }

    final body = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    throw ApiException(_errorMessage(body, response.statusCode), statusCode: response.statusCode);
  }

  static dynamic _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// El backend responde errores como { statusCode, message, ... } y a veces
  /// `message` viene anidado o como lista (errores de validación).
  static String _errorMessage(dynamic body, int status) {
    dynamic message = body is Map ? body['message'] : null;
    if (message is Map) message = message['message'];
    if (message is List && message.isNotEmpty) message = message.first;
    if (message is String && message.isNotEmpty) return message;

    return switch (status) {
      401 => 'Tu sesión expiró. Inicia sesión de nuevo.',
      404 => 'No encontramos lo que buscabas.',
      429 => 'Demasiadas peticiones. Espera un momento e intenta de nuevo.',
      _ => 'Ocurrió un error inesperado (código $status).',
    };
  }
}