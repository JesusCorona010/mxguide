import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Progreso del viajero: estados visitados (insignias), lugares visitados y
/// reseñas. Lo comparten Logros y Perfil, así siempre muestran lo mismo.
///
/// TODO(backend): por ahora se guarda solo en el celular. Cuando la API
/// tenga visitas y "mis reseñas", cargar aquí los datos del servidor.
class ProgressService extends ChangeNotifier {
  ProgressService._();
  static final instance = ProgressService._();

  static const _statesKey = 'mxguide_visited_states';
  static const _placesKey = 'mxguide_visited_places_count';

  final Set<String> _visitedStates = {};
  int _visitedPlaces = 0;
  int _reviews = 0;

  Set<String> get visitedStates => Set.unmodifiable(_visitedStates);
  int get visitedPlaces => _visitedPlaces;
  int get reviews => _reviews;

  bool hasVisited(String state) => _visitedStates.contains(state);

  /// Se llama una vez al abrir la app.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _visitedStates
      ..clear()
      ..addAll(prefs.getStringList(_statesKey) ?? const []);
    _visitedPlaces = prefs.getInt(_placesKey) ?? 0;
    notifyListeners();
  }

  /// Registra la visita a un lugar del [state]. Regresa true si con esto se
  /// desbloqueó una insignia nueva (primer lugar visitado de ese estado).
  Future<bool> registerVisit(String state) async {
    final isNewState = _visitedStates.add(state);
    _visitedPlaces++;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_statesKey, _visitedStates.toList());
    await prefs.setInt(_placesKey, _visitedPlaces);
    return isNewState;
  }

  /// Borra el progreso guardado (al cerrar sesión, para que la siguiente
  /// cuenta en este celular empiece de cero).
  Future<void> clear() async {
    _visitedStates.clear();
    _visitedPlaces = 0;
    _reviews = 0;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statesKey);
    await prefs.remove(_placesKey);
  }
}
