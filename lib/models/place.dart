/// Un lugar turístico. Los nombres de los campos del JSON son un ejemplo:
/// ajústalos a lo que devuelva la API de tu compañero.
class Place {
  final String id;
  final String name;
  final String state;
  final String category;
  final String? imageUrl;

  /// Coordenadas del lugar, usadas por el mapa y por las notificaciones de
  /// cercanía. Pueden venir nulas mientras el backend no las incluya.
  final double? latitude;
  final double? longitude;

  const Place({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    this.imageUrl,
    this.latitude,
    this.longitude,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? '',
      category: json['category'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}