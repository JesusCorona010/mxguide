import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place.dart';
import 'api_config.dart';

/// Se encarga de traer los lugares desde el backend (NestJS) por HTTP.
class PlaceService {
  PlaceService._();

  static final PlaceService instance = PlaceService._();

  List<Place>? _cache;

  /// Trae la lista de lugares. Guarda el resultado en memoria para no pegarle
  /// a la API cada vez que se abre la pantalla de Explorar; pasa
  /// [forceRefresh] en true (por ejemplo, en un "pull to refresh") para
  /// ignorar el caché y volver a pedirlos.
  Future<List<Place>> fetchPlaces({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    final uri = Uri.parse('${ApiConfig.baseUrl}/places');
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