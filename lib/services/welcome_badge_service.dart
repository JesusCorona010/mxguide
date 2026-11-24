import 'package:geolocator/geolocator.dart';

import '../data/achievements_data.dart';
import '../models/achievement.dart';
import '../utils/text_utils.dart';
import 'places_repository.dart';
import 'progress_service.dart';

/// Insignia de bienvenida: la primera vez que una cuenta (o el invitado)
/// entra a la app, se le regala la insignia del estado donde está.
///
/// El estado se deduce del lugar del catálogo más cercano a su ubicación,
/// así no hace falta ningún servicio extra de geocodificación.
class WelcomeBadgeService {
  WelcomeBadgeService._();
  static final instance = WelcomeBadgeService._();

  /// Si está más lejos que esto de cualquier lugar del catálogo, se asume
  /// que está fuera de México y no se da insignia.
  static const _maxDistanceMeters = 250000.0;

  bool _running = false;

  /// Regresa la insignia si se acaba de desbloquear; null en cualquier otro
  /// caso (ya la tenía, sin permiso de ubicación, sin internet, etc.).
  Future<StateAchievement?> tryGrant() async {
    final progress = ProgressService.instance;
    if (_running || progress.welcomeBadgeDone) return null;
    _running = true;
    try {
      final position = await _currentPosition(progress);
      if (position == null) return null;

      final catalog = await PlacesRepository.instance.loadCatalog();
      String? nearestState;
      var nearestDistance = double.infinity;
      for (final place in catalog.places) {
        if (place.state.isEmpty || (place.latitude == 0 && place.longitude == 0)) continue;
        final d = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          place.latitude,
          place.longitude,
        );
        if (d < nearestDistance) {
          nearestDistance = d;
          nearestState = place.state;
        }
      }

      // Ya se resolvió la ubicación: no se vuelve a intentar con esta cuenta.
      await progress.markWelcomeBadgeDone();
      if (nearestState == null || nearestDistance > _maxDistanceMeters) return null;

      final achievement = _achievementFor(nearestState);
      if (achievement == null) return null;
      final isNew = await progress.unlockState(achievement.state);
      return isNew ? achievement : null;
    } catch (_) {
      // Sin internet o el servidor dormido: se intenta la próxima vez.
      return null;
    } finally {
      _running = false;
    }
  }

  /// Pide el permiso de ubicación una sola vez por cuenta; después solo
  /// lo usa si ya estaba concedido.
  Future<Position?> _currentPosition(ProgressService progress) async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && !progress.welcomeLocationAsked) {
      await progress.markWelcomeLocationAsked();
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      // Nunca va a poder: se da por resuelto para no insistir.
      await progress.markWelcomeBadgeDone();
      return null;
    }
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }

  static StateAchievement? _achievementFor(String state) {
    final target = normalizeText(state);
    for (final a in stateAchievements) {
      if (normalizeText(a.state) == target) return a;
    }
    return null;
  }
}
