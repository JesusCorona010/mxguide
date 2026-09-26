/// Un lugar turístico. Los nombres de los campos del JSON son un ejemplo:
/// ajústalos a lo que devuelva la API de tu compañero.
class Place {
  final String id;
  final String name;
  final String state;
  final String category;
  final String? imageUrl;

  const Place({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    this.imageUrl,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? '',
      category: json['category'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }
}