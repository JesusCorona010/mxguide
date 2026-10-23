<<<<<<< HEAD
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'api_client.dart';

/// Maneja la sesión: login, registro, cerrar sesión y recordar el token.
/// Es un ChangeNotifier para que las pantallas se enteren cuando cambia.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final instance = AuthService._();

  static const _tokenKey = 'mxguide_auth_token';

  final _api = ApiClient.instance;

  AppUser? _user;

  /// Datos del usuario (puede tardar un poco en llegar al abrir la app).
  AppUser? get user => _user;

  bool get isLoggedIn => _api.token != null;

  /// Se llama al abrir la app. Lee el token guardado al instante y pide los
  /// datos del usuario en segundo plano, para no dejar la app en blanco
  /// mientras el servidor despierta.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return;

    _api.token = token;
    unawaited(refreshUser());
  }

  Future<void> login({required String email, required String password}) async {
    final data = await _api.post('/auth/login', body: {'email': email, 'password': password});
    await _startSession(data);
  }

=======
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Habla con /auth del backend (NestJS).
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// POST /auth/register
  ///
  /// Si el RegisterDto del backend usa otros nombres de campo, cámbialos
  /// SOLO en el `body` de abajo.
>>>>>>> 90b522e (Conexion con Backend)
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
<<<<<<< HEAD
    final data = await _api.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    await _startSession(data);
  }

  /// Vuelve a pedir los datos del usuario. Si el token ya no sirve, cierra sesión.
  Future<void> refreshUser() async {
    try {
      final data = await _api.get('/auth/me');
      if (data is Map<String, dynamic>) {
        _user = AppUser.fromJson(data);
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) await logout();
      // Otros errores (sin internet, servidor dormido): se conserva la sesión.
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _api.token = null;
    _user = null;
    notifyListeners();
  }

  Future<void> _startSession(dynamic data) async {
    final token = data is Map ? data['accessToken'] as String? : null;
    if (token == null) {
      throw const ApiException('El servidor no regresó una sesión válida.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _api.token = token;
    notifyListeners();
    await refreshUser();
  }
}
=======
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/register');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(ApiConfig.timeout);
    } catch (_) {
      throw AuthException(
        'No se pudo conectar con el servidor. Revisa tu internet e intenta de nuevo.',
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) return;

    throw AuthException(_extractMessage(response));
  }

  String _extractMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final msg = decoded is Map ? decoded['message'] : null;
      if (msg is List && msg.isNotEmpty) return msg.join('\n');
      if (msg is String && msg.isNotEmpty) return msg;
    } catch (_) {}
    if (response.statusCode == 409) return 'Ese correo ya está registrado';
    return 'Error del servidor (${response.statusCode})';
  }
}
>>>>>>> 90b522e (Conexion con Backend)
