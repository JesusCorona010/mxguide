import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Tipos de marcador que se muestran en el mapa.
enum MapPointType { place, hotel, restaurant }

extension MapPointTypeInfo on MapPointType {
  String get label => switch (this) {
        MapPointType.place => 'Lugares',
        MapPointType.hotel => 'Hoteles',
        MapPointType.restaurant => 'Restaurantes',
      };

  IconData get icon => switch (this) {
        MapPointType.place => Icons.account_balance_rounded,
        MapPointType.hotel => Icons.hotel_rounded,
        MapPointType.restaurant => Icons.restaurant_rounded,
      };

  /// Color del marcador según la paleta:
  /// lugares → Jungle Teal, hoteles → Jaguar Ochre, restaurantes → Sun Red.
  Color color(ColorScheme colors) => switch (this) {
        MapPointType.place => colors.primary,
        MapPointType.hotel => colors.tertiary,
        MapPointType.restaurant => colors.secondary,
      };

  Color onColor(ColorScheme colors) => switch (this) {
        MapPointType.place => colors.onPrimary,
        MapPointType.hotel => colors.onTertiary,
        MapPointType.restaurant => colors.onSecondary,
      };
}

/// Un punto en el mapa: lugar turístico, hotel o restaurante.
/// Los nombres de los campos del JSON son un ejemplo: ajústalos a la API.
class MapPoint {
  final String id;
  final String name;
  final MapPointType type;
  final double latitude;
  final double longitude;

  /// Texto corto debajo del nombre, por ejemplo "Histórico · Puebla".
  final String subtitle;
  final String? imageUrl;

  const MapPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.subtitle,
    this.imageUrl,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory MapPoint.fromJson(Map<String, dynamic> json) {
    return MapPoint(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      type: switch (json['type']) {
        'hotel' => MapPointType.hotel,
        'restaurant' => MapPointType.restaurant,
        _ => MapPointType.place,
      },
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      subtitle: json['subtitle'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }
}