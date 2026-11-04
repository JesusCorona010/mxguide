import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    await _startSession(data);
  }

  // Client ID tipo "Web" de Google Cloud (el mismo que GOOGLE_CLIENT_ID en Render).
  static const _googleWebClientId = '1025542032352-ol86rav0fs5q7rt2qhdcv8vipv4ajcij.apps.googleusercontent.com';
  bool _googleReady = false;

  /// Devuelve false si el usuario cancela. Lanza [ApiException] en otros errores.
  Future<bool> loginWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw const ApiException('El inicio con Google no está disponible en esta plataforma.');
    }
    if (_googleWebClientId.startsWith('PEGA_AQUI')) {
      throw const ApiException('Falta configurar el Web Client ID de Google.');
    }

    if (!_googleReady) {
      // debugPrint('serverClientId usado: $_googleWebClientId');
      await google.initialize(serverClientId: _googleWebClientId);
      _googleReady = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in: code=${e.code} description=${e.description}');
      throw ApiException(
        'Google: ${e.code.name}${e.description != null ? ' - ${e.description}' : ''}',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const ApiException('Google no entregó el token de sesión.');
    }

    final data = await _api.post('/auth/google', body: {'idToken': idToken});
    await _startSession(data);
    return true;
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

