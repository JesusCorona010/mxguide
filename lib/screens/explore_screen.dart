import 'package:flutter/material.dart';

import '../data/mock_places.dart' show placeCategories, mexicanStates;
import '../models/place.dart';
import '../services/place_service.dart';
import '../theme/app_colors.dart';
import '../widgets/place_card.dart';

/// Pestaña "Explorar": buscador, filtros por categoría y estado, y lista de lugares.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _allStatesKey = '__todos__';

  final _searchController = TextEditingController();

  List<Place> _places = [];
  bool _loading = true;
  String? _error;

  String _query = '';
  String _category = placeCategories.first; // 'Todas'
  String? _state; // null = todos los estados
  final Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final places = await PlaceService.instance.fetchPlaces(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _places = places;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar con el servidor. Revisa que el backend esté corriendo.';
        _loading = false;
      });
    }
  }

  // ───────────── Filtros ─────────────

  static const _accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};

  /// Minúsculas y sin acentos, para que "teotihuacan" encuentre "Teotihuacán".
  String _normalize(String text) {
    var result = text.toLowerCase().trim();
    _accents.forEach((from, to) => result = result.replaceAll(from, to));
    return result;
  }

  List<Place> get _filteredPlaces {
    final query = _normalize(_query);
    return _places.where((place) {
      final matchesCategory = _category == placeCategories.first || place.category == _category;
      final matchesState = _state == null || place.state == _state;
      final matchesQuery = query.isEmpty ||
          _normalize(place.name).contains(query) ||
          _normalize(place.state).contains(query);
      return matchesCategory && matchesState && matchesQuery;
    }).toList();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = placeCategories.first;
      _state = null;
    });
  }

  // ───────────── Acciones ─────────────

  void _toggleFavorite(Place place) {
    // TODO(backend): guardar el favorito en la API.
    setState(() {
      if (!_favorites.remove(place.id)) _favorites.add(place.id);
    });
  }

  void _openPlace(Place place) {
    // TODO: navegar a la pantalla de detalle del lugar.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Detalle de "${place.name}" próximamente')));
  }

  Future<void> _pickState() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _StatePickerSheet(selected: _state, allStatesKey: _allStatesKey),
    );
    if (result == null) return; // Cerró la hoja sin elegir.
    setState(() => _state = result == _allStatesKey ? null : result);
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _loadPlaces(forceRefresh: true),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final places = _filteredPlaces;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // La celda de la grilla mezcla una imagen que escala con el ancho
          // (aspect ratio 1.1) y un texto de alto fijo debajo. Un
          // childAspectRatio fijo no puede describir eso a la vez en celular
          // y en una ventana ancha de escritorio — por eso antes quedaba un
          // hueco negro abajo del texto en pantallas anchas. Aquí se calcula
          // el alto exacto de la celda (imagen + texto) según el ancho real
          // disponible, para que siempre cierre justo, sin importar el
          // tamaño de pantalla.
          const crossAxisCount = 2;
          const horizontalPadding = 20.0; // el mismo de SliverPadding de abajo
          const crossAxisSpacing = 12.0;
          const imageAspectRatio = 1.1; // debe hacer match con PlaceCard(dense: true)
          const textBlockHeight = 56.0; // padding (8+8) + hasta 2 líneas de texto

          final gridWidth = constraints.maxWidth - horizontalPadding * 2;
          final columnWidth =
              (gridWidth - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
          final cardHeight = columnWidth / imageAspectRatio + textBlockHeight;

          return _buildContent(places, crossAxisCount, cardHeight);
        },
      ),
    );
  }

  Widget _buildContent(List<Place> places, int crossAxisCount, double cardHeight) {
    return RefreshIndicator(
      onRefresh: () => _loadPlaces(forceRefresh: true),
      child: CustomScrollView(
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
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Alto exacto (no un aspect ratio fijo) para que la celda
                  // cierre justo con la imagen + el texto, sin hueco extra.
                  mainAxisExtent: cardHeight,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final place = places[index];
                    return PlaceCard(
                      place: place,
                      isFavorite: _favorites.contains(place.id),
                      onFavoriteTap: () => _toggleFavorite(place),
                      onTap: () => _openPlace(place),
                      dense: true,
                    );
                  },
                  childCount: places.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "MXGuide" + saludo. El botón de tema y la campanita de notificaciones
/// viven flotando en HomeScreen (arriba de todas las pestañas), no aquí.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
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
    );
  }
}

/// Chips horizontales: Todas, Histórico, Natural, Playa...
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

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
        itemCount: placeCategories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = placeCategories[index];
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
  const _StatePickerSheet({required this.selected, required this.allStatesKey});

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
                for (final state in mexicanStates) option(state, state, state == selected),
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