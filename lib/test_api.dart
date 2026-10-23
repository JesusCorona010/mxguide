import 'services/api_service.dart';

Future<void> main() async {
  try {
    final places = await ApiService.getFeaturedPlaces(
      limit: 5,
    );

    print('Lugares destacados:');
    print(places);

    final categories = await ApiService.getCategories();

    print('Categorías:');
    print(categories);
  } catch (e) {
    print('Error al conectar con MXGuide: $e');
  }
}