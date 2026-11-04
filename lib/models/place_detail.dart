import '../config/api_config.dart';

/// Un lugar con toda su información (GET /places/:id).
class PlaceDetail {
  const PlaceDetail({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.longDescription,
    required this.state,
    required this.municipality,
    required this.address,
    required this.categories,
    required this.latitude,
    required this.longitude,
    required this.images,
    this.openingHours,
    this.entryCost,
  });

  final String id;
  final String name;
  final String shortDescription;
  final String longDescription;
  final String state;
  final String municipality;
  final String address;
  final List<String> categories;
  final double latitude;
  final double longitude;

  /// URLs de fotos; si el lugar no tiene, se usa la miniatura del backend.
  final List<String> images;
  final String? openingHours;
  final String? entryCost;

  String get category => categories.isEmpty ? 'Lugar' : categories.first;

  /// Descripción completa, o la corta si no hay larga.
  String get description => longDescription.isNotEmpty ? longDescription : shortDescription;

  String get locationLabel => [municipality, state].where((t) => t.isNotEmpty).join(', ');

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final state = json['state'];

    final images = <String>[
      for (final img in (json['images'] as List? ?? const []))
        if (img is Map && img['url'] is String && (img['url'] as String).isNotEmpty) img['url'] as String
        else if (img is String && img.isNotEmpty) img,
    ];

    return PlaceDetail(
      id: id,
      name: json['name'] as String? ?? '',
      shortDescription: json['shortDescription'] as String? ?? '',
      longDescription: json['longDescription'] as String? ?? '',
      state: state is Map && state['name'] is String ? state['name'] as String : '',
      municipality: json['municipality'] as String? ?? '',
      address: json['address'] as String? ?? '',
      categories: [
        for (final item in (json['categories'] as List? ?? const []))
          if (item is Map && item['category'] is Map && item['category']['name'] is String)
            item['category']['name'] as String,
      ],
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      images: images.isEmpty ? [ApiConfig.placeThumbnail(id)] : images,
      openingHours: _text(json['openingHours']),
      entryCost: _cost(json['entryCost']),
    );
  }

  /// Convierte a texto lo que venga (texto, número u objeto) y descarta vacíos.
  static String? _text(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  /// "0" → "Gratis", "95" → "$95 MXN"; si ya es texto, se respeta.
  static String? _cost(dynamic value) {
    final text = _text(value);
    if (text == null) return null;
    final number = num.tryParse(text);
    if (number == null) return text;
    if (number == 0) return 'Gratis';
    final pretty = number == number.roundToDouble() ? number.toInt().toString() : number.toStringAsFixed(2);
    return '\$$pretty MXN';
  }
}

/// Una reseña (GET /places/:id/reviews).
class PlaceReview {
  const PlaceReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.userName,
    this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;
  final String userName;
  final DateTime? createdAt;

  String get initials {
    final parts = userName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return PlaceReview(
      id: json['id']?.toString() ?? '',
      rating: ((json["rating"] as num?)?.toInt() ?? 0).clamp(0, 5).toInt(),
      comment: json['comment'] as String? ?? '',
      userName: user is Map && user['name'] is String ? user['name'] as String : 'Viajero',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
    );
  }
}
