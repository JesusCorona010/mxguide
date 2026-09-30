import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/place.dart';

/// Se encarga de traer los lugares desde el backend (NestJS) por HTTP.
///
/// TODO(backend): si tu compañero despliega la API en otro lado (no en tu
/// máquina), cambia [_baseUrl] por esa URL (por ejemplo, la de Render/Railway).
class PlaceService {
  PlaceService._();

  static final PlaceService instance = PlaceService._();

  /// Puerto/host donde corre el backend en local. Ajusta el puerto si tu
  /// compañero lo levantó en otro.
  static const _port = 3000;

  /// Elige el host correcto según dónde corre la app:
  /// - Web/desktop: el backend corre en la misma máquina → localhost.
  /// - Emulador de Android: "localhost" del emulador NO es tu PC, así que
  ///   Android reserva 10.0.2.2 para apuntar a la máquina host.
  /// - Dispositivo físico (celular real): ni localhost ni 10.0.2.2 sirven,
  ///   hace falta la IP de tu compañero en la red local (ej. 192.168.x.x).
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:$_port';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:$_port';
    return 'http://localhost:$_port';
  }

  List<Place>? _cache;

  /// Trae la lista de lugares. Guarda el resultado en memoria para no pegarle
  /// a la API cada vez que se abre la pantalla de Explorar; pasa
  /// [forceRefresh] en true (por ejemplo, en un "pull to refresh") para
  /// ignorar el caché y volver a pedirlos.
  Future<List<Place>> fetchPlaces({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    final uri = Uri.parse('$_baseUrl/places');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('El servidor respondió ${response.statusCode} al pedir /places');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    final places = decoded
        .map((item) => Place.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    _cache = places;
    return places;
  }
}
