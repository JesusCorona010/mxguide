import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'places_repository.dart';
import 'proximity_service.dart';

/// Preferencia de "avisarme cuando esté cerca de un lugar".
/// Se prende o apaga desde Perfil y se recuerda entre sesiones.
class NearbyAlertsService extends ChangeNotifier {
  NearbyAlertsService._();
  static final instance = NearbyAlertsService._();

  static const _key = 'mxguide_nearby_alerts';

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Se llama al entrar al Home: si el usuario lo dejó prendido, arranca.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? false;
    notifyListeners();
    if (_enabled) await _start();
  }

  /// Prende o apaga los avisos. Regresa false si no se pudo prender
  /// (por ejemplo, porque el usuario negó el permiso de ubicación).
  Future<bool> setEnabled(bool value) async {
    if (value) {
      await _start();
      if (!ProximityService.instance.isActive) return false;
    } else {
      ProximityService.instance.stop();
    }

    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    return true;
  }

  Future<void> _start() async {
    try {
      final catalog = await PlacesRepository.instance.loadCatalog();
      await ProximityService.instance.start(
        places: catalog.places,
        // La notificación del sistema la muestra ProximityService.
        onPlaceNearby: (_, _) {},
      );
    } catch (_) {
      // Sin internet o sin permiso: se queda apagado sin tronar la app.
    }
  }
}
