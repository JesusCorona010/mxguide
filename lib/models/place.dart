import '../services/api_config.dart';

/// Un lugar turístico.
///
/// `fromJson` sabe leer tanto la forma real de la API (`state` como objeto
/// `{id, name}`, `categories` como arreglo, `images` como arreglo de
/// `PlaceImage` `{url, order}` — ver el README del backend, sección
/// "Modelo de datos") como la forma plana de los datos de prueba
/// (`mock_places.dart`), para no tener que mantener dos modelos distintos.
class Place {
  final String id;
  final String name;
  final String state;

  /// Categoría "principal" (la primera de [categories]), para no romper el
  /// filtro de una sola categoría que ya usa ExploreScreen.
  final String category;

  /// Todas las categorías del lugar, por si algún día se muestran todas
  /// (por ahora la UI solo usa [category]).
  final List<String> categories;

  /// URLs de Cloudinary de las imágenes del lugar, ya ordenadas por el
  /// campo `order` que manda el backend. Puede venir vacía mientras no se
  /// le suba ninguna foto al lugar (`POST /uploads/places/:placeId/image`).
  final List<String> images;

  /// Portada del lugar: la primera imagen "real" que haya subido un admin a
  /// Cloudinary ([images], vía `POST /uploads/places/:placeId/image`). Si no
  /// tiene ninguna usable (vacío, o la única que trae es el link viejo de
  /// `commons.wikimedia.org/wiki/Special:FilePath/...` del seed de ejemplo —
  /// ese link es una redirección de MediaWiki sin cabecera CORS, así que el
  /// navegador la bloquea y la imagen nunca carga), cae a la miniatura
  /// automática que el backend saca de Wikipedia/Wikimedia Commons por el
  /// nombre del lugar (`GET /place-images/:id` — ver README del backend,
  /// sección "Miniaturas de lugares"). Esa ruta regresa la imagen ya
  /// decodificada desde el propio backend, así que no hay CORS que resolver
  /// en el front.
  ///
  /// Si el backend todavía no le generó miniatura a este lugar (falta
  /// correr `npm run sync-images` una vez, ver README) esa URL responde
  /// 404 — PlaceCard ya sabe mostrar su placeholder cuando `Image.network`
  /// falla, así que no truena, solo se ve sin foto hasta que se sincronice.
  String? get imageUrl {
    final usable = images.where((url) => !_isBrokenWikimediaLink(url));
    if (usable.isNotEmpty) return usable.first;
    return '${ApiConfig.baseUrl}/place-images/$id';
  }

  /// Coordenadas del lugar, usadas por el mapa y por las notificaciones de
  /// cercanía. Pueden venir nulas mientras el backend no las incluya.
  final double? latitude;
  final double? longitude;

  const Place({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    this.categories = const [],
    this.images = const [],
    this.latitude,
    this.longitude,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    // `state`: la API real lo manda como objeto { id, name } (ver GET
    // /states). Si algún día llega como string plano, también lo aceptamos.
    final rawState = json['state'];
    final stateName = switch (rawState) {
      Map<String, dynamic> map => map['name'] as String? ?? '',
      String value => value,
      _ => '',
    };

    // `categories`: arreglo de categorías del lugar. Cada elemento puede
    // venir directo como { id, name, icon } (igual que GET /categories), o
    // envuelto como { category: { id, name, icon } } si el backend llega a
    // exponer la tabla intermedia PlaceCategory tal cual — aceptamos ambas
    // formas para no tronar si cambian el shape de un lado al otro.
    final rawCategories = json['categories'] as List<dynamic>? ?? const [];
    final categoryNames = rawCategories
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final inner = item['category'];
          final name = inner is Map<String, dynamic> ? inner['name'] : item['name'];
          return name as String? ?? '';
        })
        .where((name) => name.isNotEmpty)
        .toList();

    // Compatibilidad con un campo `category` plano (un solo string), por si
    // algún endpoint viejo todavía lo manda así en vez de `categories`.
    final fallbackCategory = json['category'] as String?;

    // `images`: arreglo de PlaceImage { url, order }. Se ordenan por
    // `order` y se descartan entradas sin url.
    final rawImages = (json['images'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) {
        final orderA = (a['order'] as num?) ?? 0;
        final orderB = (b['order'] as num?) ?? 0;
        return orderA.compareTo(orderB);
      });
    final imageUrls = rawImages
        .map((item) => item['url'] as String?)
        .whereType<String>()
        .toList();

    return Place(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      state: stateName,
      category: categoryNames.isNotEmpty ? categoryNames.first : (fallbackCategory ?? ''),
      categories: categoryNames,
      images: imageUrls,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// `https://commons.wikimedia.org/wiki/Special:FilePath/<archivo>` es una
/// página de redirección de MediaWiki (no el archivo en sí) que no manda
/// cabecera `Access-Control-Allow-Origin` — por eso Flutter Web la bloquea
/// por CORS y la imagen nunca carga (ver consola: "has been blocked by CORS
/// policy"). El seed de ejemplo del backend todavía trae algunos lugares con
/// este link. En vez de "repararlo" a mano en el front (que implicaría
/// calcular el hash MD5 del nombre del archivo para armar la URL directa en
/// `upload.wikimedia.org`, y agregar una dependencia solo para eso), lo
/// tratamos como si el lugar no tuviera imagen y dejamos que [imageUrl]
/// caiga al endpoint de miniaturas del propio backend (`/place-images/:id`).
bool _isBrokenWikimediaLink(String url) =>
    url.startsWith('https://commons.wikimedia.org/wiki/Special:FilePath/') ||
    url.startsWith('http://commons.wikimedia.org/wiki/Special:FilePath/');