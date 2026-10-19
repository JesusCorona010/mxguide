import '../config/api_config.dart';

/// Un lugar turístico tal como lo regresa GET /places.
class Place {
  final String id;
  final String name;
  final String shortDescription;
  final String stateId;

  /// Nombre del estado (la API solo manda el id; se resuelve con GET /states).
  final String state;
  final List<String> categories;
  final double latitude;
  final double longitude;
  final int relevance;
  final String? imageUrl;

  const Place({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.stateId,
    required this.state,
    required this.categories,
    required this.latitude,
    required this.longitude,
    required this.relevance,
    this.imageUrl,
  });

  /// Categoría principal, para la etiqueta de la tarjeta.
  String get category => categories.isEmpty ? 'Lugar' : categories.first;

  factory Place.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> stateNames = const {},
  }) {
    final id = json['id'] as String;
    final stateId = json['stateId'] as String? ?? '';
    final nestedState = json['state'];

    // categories: [{ category: { name: 'Histórico' } }, ...]
    final categories = <String>[
      for (final item in (json['categories'] as List? ?? const []))
        if (item is Map && item['category'] is Map && item['category']['name'] is String)
          item['category']['name'] as String,
    ];

    return Place(
      id: id,
      name: json['name'] as String? ?? '',
      shortDescription: json['shortDescription'] as String? ?? '',
      stateId: stateId,
      state: nestedState is Map && nestedState['name'] is String
          ? nestedState['name'] as String
          : stateNames[stateId] ?? '',
      categories: categories,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      relevance: (json['relevanceScore'] as num?)?.toInt() ?? 0,
      // Se usa la miniatura del backend: pesa mucho menos que la foto original.
      imageUrl: ApiConfig.placeThumbnail(id),
    );
  }
}