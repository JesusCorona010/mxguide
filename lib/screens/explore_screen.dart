import 'package:flutter/material.dart';

import '../data/mock_places.dart';
import '../models/place.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
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

  // TODO(backend): cargar desde la API en lugar de los datos de prueba.
  final List<Place> _places = mockPlaces;

  String _query = '';
  String _category = placeCategories.first; // 'Todas'
  String? _state; // null = todos los estados
  final Set<String> _favorites = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final places = _filteredPlaces;

    return SafeArea(
      bottom: false,
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