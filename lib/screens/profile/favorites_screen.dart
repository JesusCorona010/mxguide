import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/places_repository.dart';
import '../../widgets/place_card.dart';
import '../place_detail_screen.dart';

/// Perfil > Mis favoritos: los lugares que el usuario guardó (GET /favorites).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const FavoritesScreen());

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repository = PlacesRepository.instance;

  List<Place>? _places;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => _error = null);
    try {
      // Se cruzan los ids favoritos con el catálogo (que ya trae el nombre
      // del estado y la categoría de cada lugar).
      final results = await Future.wait([
        _repository.loadCatalog(refresh: refresh),
        _repository.fetchFavoriteIds(),
      ]);
      final catalog = results[0] as CatalogData;
      final ids = results[1] as Set<String>;
      if (!mounted) return;
      setState(() => _places = catalog.places.where((p) => ids.contains(p.id)).toList());
    } on ApiException catch (e) {
      if (e.isUnauthorized) await AuthService.instance.logout();
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _remove(Place place) async {
    final places = _places;
    if (places == null) return;
    final index = places.indexOf(place);
    setState(() => places.removeAt(index));

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repository.removeFavorite(place.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Quitaste "${place.name}" de favoritos'),
            action: SnackBarAction(label: 'Deshacer', onPressed: () => _undo(place, index)),
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => places.insert(index, place));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _undo(Place place, int index) async {
    final places = _places;
    if (places == null || !mounted) return;
    setState(() => places.insert(index > places.length ? places.length : index, place));
    try {
      await _repository.addFavorite(place.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => places.remove(place));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openPlace(Place place) async {
    await Navigator.of(context).push(PlaceDetailScreen.route(place.id, name: place.name));
    // Si le quitó el corazón desde el detalle, ya no debe salir aquí.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis favoritos')),
      body: SafeArea(
        top: false,
        child: _error != null && places == null
            ? _Message(
                icon: Icons.cloud_off_rounded,
                title: 'No pudimos cargar tus favoritos',
                message: _error!,
                action: FilledButton.tonal(onPressed: _load, child: const Text('Reintentar')),
              )
            : places == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    child: places.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 80),
                              _Message(
                                icon: Icons.favorite_border_rounded,
                                title: 'Aún no tienes favoritos',
                                message:
                                    'Toca el corazón de cualquier lugar en Explorar para guardarlo aquí.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: places.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final place = places[index];
                              return PlaceCard(
                                place: place,
                                isFavorite: true,
                                onFavoriteTap: () => _remove(place),
                                onTap: () => _openPlace(place),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colors.secondary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
