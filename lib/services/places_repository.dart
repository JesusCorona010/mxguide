import '../models/place.dart';
import 'api_client.dart';

/// Lugares, categorías y estados ya cargados desde la API.
class CatalogData {
  const CatalogData({
    required this.places,
    required this.categories,
    required this.states,
  });

  final List<Place> places;
  final List<String> categories;
  final List<String> states;
}

/// Acceso a los datos de lugares. Guarda el catálogo en memoria para que
/// Explorar y Mapa no lo descarguen dos veces.
class PlacesRepository {
  PlacesRepository._();
  static final instance = PlacesRepository._();

  final _api = ApiClient.instance;
  Future<CatalogData>? _catalog;

  Future<CatalogData> loadCatalog({bool refresh = false}) {
    final cached = _catalog;
    if (cached != null && !refresh) return cached;

    final future = _fetchCatalog();
    _catalog = future;
    // Si falla, se olvida para poder reintentar después.
    future.then((_) {}, onError: (Object _) {
      if (identical(_catalog, future)) _catalog = null;
    });
    return future;
  }

  Future<CatalogData> _fetchCatalog() async {
    final results = await Future.wait([
      _api.get('/places', query: {'limit': '2000'}),
      _api.get('/categories'),
      _api.get('/states'),
    ]);

    final stateNames = <String, String>{
      for (final s in (results[2] as List? ?? const []))
        if (s is Map) s['id'] as String: s['name'] as String,
    };

    final categories = <String>[
      for (final c in (results[1] as List? ?? const []))
        if (c is Map && c['name'] is String) c['name'] as String,
    ]..sort();

    final places = <Place>[
      for (final p in (results[0] as List? ?? const []))
        if (p is Map<String, dynamic>) Place.fromJson(p, stateNames: stateNames),
    ]..sort((a, b) => b.relevance.compareTo(a.relevance));

    return CatalogData(
      places: places,
      categories: categories,
      states: stateNames.values.toList()..sort(),
    );
  }

  // ───────────── Favoritos (requieren sesión) ─────────────

  Future<Set<String>> fetchFavoriteIds() async {
    final data = await _api.get('/favorites');
    return {
      for (final f in (data as List? ?? const []))
        if (f is Map && f['placeId'] is String) f['placeId'] as String,
    };
  }

  Future<void> addFavorite(String placeId) async {
    try {
      await _api.post('/favorites', body: {'placeId': placeId});
    } on ApiException catch (e) {
      if (e.statusCode == 409) return; // Ya estaba en favoritos.
      rethrow;
    }
  }

  Future<void> removeFavorite(String placeId) => _api.delete('/favorites/$placeId');
}