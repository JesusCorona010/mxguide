import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../data/proximity_messages.dart';
import '../models/place.dart';

/// Avisa al usuario, con una notificación local, cuando su posición entra
/// en el radio de alguno de los lugares que se le pasan a [start].
///
/// Corre solo mientras la app está abierta (foreground): no usa geofencing
/// en segundo plano a propósito, porque eso exige el permiso de ubicación
/// "siempre" en Android/iOS, que ambas tiendas revisan mucho y que no
/// aporta nada extra para la demo de este sprint.
class ProximityService {
  ProximityService._();

  static final ProximityService instance = ProximityService._();

  /// Radio, en metros, dentro del cual se considera que el usuario "está
  /// cerca" de un lugar.
  static const double radiusMeters = 800;

  /// Cuánto esperar antes de volver a avisar del mismo lugar si el usuario
  /// se queda ahí (para no espamear con la misma notificación).
  static const Duration cooldown = Duration(hours: 2);

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _webPollTimer;
  final Map<String, DateTime> _lastNotifiedAt = {};
  bool _starting = false;
  bool _active = false;
  List<Place> _places = [];

  bool get isActive => _active;

  /// Cambia la lista de lugares que se vigilan (por ejemplo, cuando Explorar
  /// termina de cargarlos desde la API, o al hacer un refresh). No hace
  /// falta reiniciar el listener de ubicación: el próximo chequeo ya usa la
  /// lista nueva.
  void updatePlaces(List<Place> places) {
    _places = places;
  }

  /// Se llama una vez cuando arranca el Home (usuario ya logueado o en modo
  /// invitado). [places] es la lista de lugares a vigilar (normalmente la
  /// que devolvió la API). Pide los permisos necesarios y, si todo salió
  /// bien, empieza a escuchar la ubicación. Si el usuario niega el permiso,
  /// no truena: simplemente la función se queda apagada.
  Future<void> start({
    required List<Place> places,
    required void Function(Place place, String message) onPlaceNearby,
  }) async {
    _places = places;
    if (_active || _starting) return;
    _starting = true;

    try {
      try {
        await _initNotifications();
      } catch (_) {
        // flutter_local_notifications no tiene soporte en Flutter Web (por
        // eso no truena, pero tampoco muestra la notificación del sistema
        // ahí). El resto — flotante, historial, badge — no depende de esta
        // librería y sigue funcionando igual.
      }

      final hasLocationPermission = await _ensureLocationPermission();
      if (!hasLocationPermission) return;

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 75, // Solo recalcula si el usuario se movió ~75 m.
      );

      if (kIsWeb) {
        // En Flutter Web, el stream de geolocator (watchPosition del
        // navegador) truena de forma intermitente con algunas versiones de
        // Chromium — sobre todo al usar la ubicación simulada de DevTools.
        // Para no depender de eso, en Web se hace polling simple con
        // getCurrentPosition en vez de un stream continuo.
        _webPollTimer?.cancel();
        _webPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          try {
            final position = await Geolocator.getCurrentPosition(locationSettings: locationSettings);
            _checkNearbyPlaces(position, onPlaceNearby);
          } catch (_) {
            // Fallo puntual (por ejemplo, el navegador tardó en responder);
            // se vuelve a intentar en el siguiente tick, cada 5 s.
          }
        });
      } else {
        _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) => _checkNearbyPlaces(position, onPlaceNearby),
          onError: (_) {
            // Un error puntual del stream no debe tumbar el listener.
          },
        );
      }
      _active = true;
    } finally {
      _starting = false;
    }
  }

  /// Apaga el listener de ubicación (por ejemplo, al cerrar sesión o si el
  /// usuario desactiva el aviso desde Perfil).
  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _webPollTimer?.cancel();
    _webPollTimer = null;
    _active = false;
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);

    // Android 13+ pide el permiso de notificaciones en tiempo de ejecución.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;

    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  void _checkNearbyPlaces(Position position, void Function(Place place, String message) onPlaceNearby) {
    for (final place in _places) {
      final lat = place.latitude;
      final lng = place.longitude;
      if (lat == null || lng == null) continue;

      final distance = Geolocator.distanceBetween(position.latitude, position.longitude, lat, lng);
      if (distance > radiusMeters) continue;

      final lastNotified = _lastNotifiedAt[place.id];
      if (lastNotified != null && DateTime.now().difference(lastNotified) < cooldown) continue;

      _lastNotifiedAt[place.id] = DateTime.now();
      // Una frase al azar según la categoría del lugar (ver
      // proximity_messages.dart) — la misma frase se usa en la notificación
      // del sistema y en el flotante/historial dentro de la app.
      final message = proximityMessageFor(place.category);
      // Sin await a propósito (no debe bloquear el resto de lugares); si la
      // plataforma no soporta notificaciones del sistema (Web), se ignora.
      unawaited(_showNotification(place, message).catchError((_) {}));
      onPlaceNearby(place, message);
    }
  }

  Future<void> _showNotification(Place place, String message) async {
    const androidDetails = AndroidNotificationDetails(
      'proximity_channel',
      'Lugares cercanos',
      channelDescription: 'Avisa cuando estás cerca de una atracción turística registrada en MXGuide',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _notifications.show(
      place.id.hashCode,
      '¡Estás cerca de ${place.name}!',
      message,
      details,
      payload: place.id,
    );
  }
}
