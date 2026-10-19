import 'dart:async';
import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/places_repository.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../utils/text_utils.dart';
import '../widgets/place_card.dart';

/// Pestaña "Explorar": buscador, filtros por categoría y estado, y lista de lugares.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _allStatesKey = '__todos__';
  static const _allCategories = 'Todas';

  final _searchController = TextEditingController();
  final _repository = PlacesRepository.instance;
  final _auth = AuthService.instance;

  CatalogData? _catalog;
  bool _isLoading = true;
  bool _isServerSlow = false;
  String? _error;

  String _query = '';
  String _category = _allCategories;
  String? _state; // null = todos los estados
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    _load();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ───────────── Carga de datos ─────────────

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isServerSlow = false;
    });

    // Si tarda más de 4 s, avisamos que el servidor está despertando.
    final slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isServerSlow = true);
    });

    try {
      final catalog = await _repository.loadCatalog(refresh: refresh);
      if (!mounted) return;
      setState(() => _catalog = catalog);
      await _loadFavorites();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_catalog == null) {
        setState(() => _error = e.message);
      } else {
        _showMessage(e.message);
      }
    } finally {
      slowTimer.cancel();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavorites() async {
    if (!_auth.isLoggedIn) {
      if (mounted) setState(() => _favorites = {});
      return;
    }
    try {
      final ids = await _repository.fetchFavoriteIds();
      if (mounted) setState(() => _favorites = ids);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.logout();
    }
  }

  void _onAuthChanged() => _loadFavorites();

  // ───────────── Filtros ─────────────

  List<Place> get _filteredPlaces {
    final places = _catalog?.places ?? const <Place>[];
    final query = normalizeText(_query);
    return places.where((place) {
      final matchesCategory = _category == _allCategories || place.categories.contains(_category);
      final matchesState = _state == null || place.state == _state;
      final matchesQuery = query.isEmpty ||
          normalizeText(place.name).contains(query) ||
          normalizeText(place.state).contains(query);
      return matchesCategory && matchesState && matchesQuery;
    }).toList();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = _allCategories;
      _state = null;
    });
  }

  // ───────────── Acciones ─────────────

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleFavorite(Place place) async {
    if (!_auth.isLoggedIn) {
      _showMessage('Inicia sesión para guardar tus favoritos');
      return;
    }

    final wasFavorite = _favorites.contains(place.id);
    // Se actualiza al instante y, si la API falla, se revierte.
    setState(() {
      if (wasFavorite) {
        _favorites.remove(place.id);
      } else {
        _favorites.add(place.id);
      }
    });

    try {
      if (wasFavorite) {
        await _repository.removeFavorite(place.id);
      } else {
        await _repository.addFavorite(place.id);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favorites.add(place.id);
        } else {
          _favorites.remove(place.id);
        }
      });
      if (e.isUnauthorized) await _auth.logout();
      _showMessage(e.message);
    }
  }

  void _openPlace(Place place) {
    // TODO: navegar a la pantalla de detalle del lugar (GET /places/:id).
    _showMessage('Detalle de "${place.name}" próximamente');
  }

  Future<void> _pickState() async {
    final states = _catalog?.states ?? const <String>[];
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _StatePickerSheet(
        states: states,
        selected: _state,
        allStatesKey: _allStatesKey,
      ),
    );
    if (result == null) return; // Cerró la hoja sin elegir.
    setState(() => _state = result == _allStatesKey ? null : result);
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;

    if (catalog == null) {
      return SafeArea(
        child: _error != null
            ? _ErrorState(message: _error!, onRetry: _load)
            : _LoadingState(isServerSlow: _isServerSlow),
      );
    }

    final places = _filteredPlaces;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Buscar lugares...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Borrar búsqueda',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _CategoryChips(
              categories: [_allCategories, ...catalog.categories],
              selected: _category,
              onSelected: (category) => setState(() => _category = category),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            sliver: SliverToBoxAdapter(
              child: _StateSelector(selected: _state, onTap: _pickState),
            ),
          ),
          if (places.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(onReset: _resetFilters),
            )
          else
            SliverPadding(
              // Espacio extra abajo para que el botón "+" no tape la última tarjeta.
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList.separated(
                itemCount: places.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final place = places[index];
                  return PlaceCard(
                    place: place,
                    isFavorite: _favorites.contains(place.id),
                    onFavoriteTap: () => _toggleFavorite(place),
                    onTap: () => _openPlace(place),
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// "MXGuide" + saludo + botón para cambiar entre claro y oscuro.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'M'),
                    TextSpan(text: 'X', style: TextStyle(color: colors.secondary)),
                    const TextSpan(text: 'Guide'),
                  ],
                ),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '¿A dónde vamos hoy?',
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
          onPressed: () => themeController.toggle(theme.brightness),
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}

/// Chips horizontales: Todas, Histórico, Natural, Playa...
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (_) => onSelected(category),
            showCheckmark: false,
            selectedColor: colors.primary,
            backgroundColor: isDark ? AppExtraColors.chipDark : AppExtraColors.chipLight,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: isSelected ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }
}

/// Campo que abre la lista de estados.
class _StateSelector extends StatelessWidget {
  const _StateSelector({required this.selected, required this.onTap});

  final String? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected ?? 'Todos los estados',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Icon(Icons.expand_more_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior con la lista de estados de México.
class _StatePickerSheet extends StatelessWidget {
  const _StatePickerSheet({
    required this.states,
    required this.selected,
    required this.allStatesKey,
  });

  final List<String> states;
  final String? selected;
  final String allStatesKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget option(String label, String value, bool isSelected) {
      return ListTile(
        title: Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? colors.primary : colors.onSurface,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check_rounded, color: colors.primary) : null,
        onTap: () => Navigator.of(context).pop(value),
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Elige un estado', style: theme.textTheme.titleMedium),
          ),
          Expanded(
            child: ListView(
              children: [
                option('Todos los estados', allStatesKey, selected == null),
                for (final state in states) option(state, state, state == selected),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Se muestra cuando ningún lugar coincide con los filtros.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore_rounded, size: 56, color: colors.tertiary),
          const SizedBox(height: 12),
          Text('No encontramos lugares', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            'Prueba con otra búsqueda o cambia los filtros.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onReset, child: const Text('Quitar filtros')),
        ],
      ),
    );
  }
}

/// Pantalla de carga mientras llegan los lugares.
class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.isServerSlow});

  final bool isServerSlow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              isServerSlow ? 'Despertando al jaguar...' : 'Cargando lugares...',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (isServerSlow) ...[
              const SizedBox(height: 6),
              Text(
                'El servidor estaba descansando. La primera carga puede tardar hasta un minuto.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Se muestra si no se pudieron cargar los lugares.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            Icon(Icons.cloud_off_rounded, size: 56, color: colors.secondary),
            const SizedBox(height: 12),
            Text('No pudimos cargar los lugares', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}