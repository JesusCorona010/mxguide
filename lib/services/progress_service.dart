import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Progreso del viajero: estados visitados (insignias), lugares visitados y
/// reseñas. Lo comparten Logros y Perfil, así siempre muestran lo mismo.
///
/// Cada cuenta tiene su propio progreso guardado en el celular (y el modo
/// invitado el suyo), así al cerrar sesión y entrar con otra cuenta no se
/// mezclan las insignias.
///
/// TODO(backend): por ahora se guarda solo en el celular. Cuando la API
/// tenga visitas y "mis reseñas", cargar aquí los datos del servidor.
class ProgressService extends ChangeNotifier {
  ProgressService._();
  static final instance = ProgressService._();

  static const _guestScope = 'guest';

  // Llaves de versiones anteriores, compartidas por todas las cuentas.
  static const _legacyKeys = [
    'mxguide_visited_states',
    'mxguide_visited_places_count',
    'mxguide_visited_place_ids',
  ];

  final Set<String> _visitedStates = {};
  final Set<String> _visitedPlaceIds = {};
  int _visitedPlaces = 0;
  int _reviews = 0;
  bool _welcomeBadgeDone = false;
  bool _welcomeLocationAsked = false;

  String? _scope;
  int _loadId = 0;
  Future<void>? _loading;

  Set<String> get visitedStates => Set.unmodifiable(_visitedStates);
  int get visitedPlaces => _visitedPlaces;
  int get reviews => _reviews;

  /// true cuando ya se le dio (o se intentó dar) la insignia de su estado
  /// al entrar por primera vez con esta cuenta.
  bool get welcomeBadgeDone => _welcomeBadgeDone;

  /// true si ya se le pidió la ubicación para la insignia de bienvenida.
  bool get welcomeLocationAsked => _welcomeLocationAsked;

  bool hasVisited(String state) => _visitedStates.contains(state);

  /// true si el usuario ya marcó este lugar como visitado.
  bool hasVisitedPlace(String placeId) => _visitedPlaceIds.contains(placeId);

  String _key(String name) => 'mxguide_${_scope ?? _guestScope}_$name';

  /// Se llama al abrir la app y cada vez que cambia la sesión. Carga el
  /// progreso de la cuenta actual (o del invitado). Regresa true si la
  /// cuenta cambió respecto a la que estaba cargada.
  Future<bool> syncWithSession() async {
    final scope = scopeForToken(ApiClient.instance.token);
    if (scope == _scope) {
      // Misma cuenta: si todavía se está cargando, se espera a que termine.
      await _loading;
      return false;
    }
    _scope = scope;
    final future = _loadScope(++_loadId);
    _loading = future;
    await future;
    return true;
  }

  Future<void> _loadScope(int loadId) async {

    // Mientras carga, no se muestra el progreso de la cuenta anterior.
    _visitedStates.clear();
    _visitedPlaceIds.clear();
    _visitedPlaces = 0;
    _reviews = 0;
    _welcomeBadgeDone = false;
    _welcomeLocationAsked = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (loadId != _loadId) return; // Cambió de cuenta otra vez mientras cargaba.

    for (final key in _legacyKeys) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }

    _visitedStates.addAll(prefs.getStringList(_key('visited_states')) ?? const []);
    _visitedPlaceIds.addAll(prefs.getStringList(_key('visited_place_ids')) ?? const []);
    _visitedPlaces = prefs.getInt(_key('visited_places_count')) ?? 0;
    _welcomeBadgeDone = prefs.getBool(_key('welcome_badge_done')) ?? false;
    _welcomeLocationAsked = prefs.getBool(_key('welcome_location_asked')) ?? false;
    notifyListeners();
  }

  /// Alias para el arranque de la app.
  Future<void> load() => syncWithSession();

  /// Identificador de la cuenta dentro del token JWT (campo "sub").
  /// Sin token (invitado) o si no se puede leer, regresa "guest".
  static String scopeForToken(String? token) {
    if (token == null) return _guestScope;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return _guestScope;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final sub = payload is Map ? payload['sub'] : null;
      if (sub is String && sub.isNotEmpty) {
        return 'user_${sub.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')}';
      }
    } catch (_) {
      // Token con formato inesperado: se trata como invitado.
    }
    return _guestScope;
  }

  /// Registra la visita a un lugar del [state]. Regresa true si con esto se
  /// desbloqueó una insignia nueva (primer lugar visitado de ese estado).
  /// Si viene [placeId], cada lugar cuenta una sola vez.
  Future<bool> registerVisit(String state, {String? placeId}) async {
    if (placeId != null && !_visitedPlaceIds.add(placeId)) return false;
    final isNewState = state.isNotEmpty && _visitedStates.add(state);
    _visitedPlaces++;
    notifyListeners();
    await _save();
    return isNewState;
  }

  /// Desbloquea la insignia de un estado sin contar un lugar visitado
  /// (la insignia de bienvenida). Regresa true si era nueva.
  Future<bool> unlockState(String state) async {
    final isNew = state.isNotEmpty && _visitedStates.add(state);
    if (isNew) {
      notifyListeners();
      await _save();
    }
    return isNew;
  }

  Future<void> markWelcomeBadgeDone() async {
    _welcomeBadgeDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key('welcome_badge_done'), true);
  }

  Future<void> markWelcomeLocationAsked() async {
    _welcomeLocationAsked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key('welcome_location_asked'), true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key('visited_states'), _visitedStates.toList());
    await prefs.setInt(_key('visited_places_count'), _visitedPlaces);
    await prefs.setStringList(_key('visited_place_ids'), _visitedPlaceIds.toList());
  }
}
