import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  ApiService._();

  static Future<dynamic> _get(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http
        .get(uri)
        .timeout(ApiConfig.timeout);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Error ${response.statusCode}: ${response.body}',
      );
    }

    return jsonDecode(response.body);
  }

  static Future<dynamic> getFeaturedPlaces({
    int limit = 10,
  }) {
    return _get('/places/featured?limit=$limit');
  }

  static Future<dynamic> getPlaces({
    String? category,
    String? stateId,
    int page = 1,
    int limit = 20,
  }) {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (category != null && category.isNotEmpty)
        'category': category,
      if (stateId != null && stateId.isNotEmpty)
        'stateId': stateId,
    };

    return _get(
      '/places?${Uri(queryParameters: query).query}',
    );
  }

  static Future<dynamic> getNearbyPlaces({
    required double lat,
    required double lng,
    double radius = 25,
    int limit = 20,
  }) {
    final query = Uri(queryParameters: {
      'lat': '$lat',
      'lng': '$lng',
      'radius': '$radius',
      'limit': '$limit',
    }).query;

    return _get('/places/nearby?$query');
  }

  static Future<dynamic> getPlace(String id) {
    return _get('/places/${Uri.encodeComponent(id)}');
  }

  static Future<dynamic> getCategories() {
    return _get('/categories');
  }

  static Future<dynamic> getStates() {
    return _get('/states');
  }

  static Future<dynamic> getPlaceReviews(String id) {
    return _get(
      '/places/${Uri.encodeComponent(id)}/reviews',
    );
  }
}