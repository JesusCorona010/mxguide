import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/places_repository.dart';
import '../utils/text_utils.dart';

/// Tipo de lo que se va a guardar con el botón "+".
enum _Kind { place, restaurant, hotel }

/// Las tres vistas de la pantalla: agregar algo nuevo, ver mis favoritos o ver
/// las reseñas que he escrito.
enum _Mode { add, favorites, reviews }

extension on _Kind {
  String get label => switch (this) {
        _Kind.place => 'Lugar',
        _Kind.restaurant => 'Restaurante',
        _Kind.hotel => 'Hotel',
      };

  IconData get icon => switch (this) {
        _Kind.place => Icons.place_outlined,
        _Kind.restaurant => Icons.restaurant_outlined,
        _Kind.hotel => Icons.hotel_outlined,
      };
}

_Kind _kindFromName(String? name) =>
    _Kind.values.firstWhere((k) => k.name == name, orElse: () => _Kind.place);

/// Botón "+": guarda un lugar, restaurante u hotel como favorito y, si quiere,
/// deja una calificación de 1 a 5 estrellas y una reseña. Desde aquí también se
/// ven los favoritos y las reseñas del usuario.
class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AddScreen(),
      );

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _repository = PlacesRepository.instance;
  final _auth = AuthService.instance;
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();

  _Mode _mode = _Mode.add;
  _Kind _kind = _Kind.place;
  CatalogData? _catalog;
  bool _loadingCatalog = true;
  String? _catalogError;

  Place? _place; // Lugar elegido (solo para _Kind.place).
  String? _state; // Estado elegido (solo para restaurante u hotel).
  bool _favorite = true;
  int _rating = 0;
  bool _saving = false;

  // Vista "Favoritos".
  bool _favLoading = false;
  String? _favError;
  List<Place> _favPlaces = [];
  List<Map<String, dynamic>> _favLocal = [];

  // Vista "Reseñas".
  List<Map<String, dynamic>> _myReviews = [];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });
    try {
      final catalog = await _repository.loadCatalog();
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _catalogError = e.message);
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ───────────── Vistas: favoritos y reseñas ─────────────

  void _setMode(_Mode mode) {
    setState(() => _mode = mode);
    if (mode == _Mode.favorites) _loadFavorites();
    if (mode == _Mode.reviews) _loadReviews();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _favLoading = true;
      _favError = null;
    });
    try {
      final local = await _Store.read(_Store.favoritesKey);
      var places = <Place>[];
      if (_auth.isLoggedIn) {
        final results = await Future.wait([_repository.loadCatalog(), _repository.fetchFavoriteIds()]);
        final catalog = results[0] as CatalogData;
        final ids = results[1] as Set<String>;
        places = catalog.places.where((p) => ids.contains(p.id)).toList();
      }
      if (!mounted) return;
      setState(() {
        _favLocal = local;
        _favPlaces = places;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.logout();
      if (!mounted) return;
      setState(() => _favError = e.message);
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    final local = await _Store.read(_Store.reviewsKey);
    if (mounted) setState(() => _myReviews = local);
    if (!_auth.isLoggedIn) return;
    try {
      // Las reseñas de lugares viven en el servidor (GET /reviews/me);
      // restaurantes y hoteles, que la API aún no tiene, siguen siendo locales.
      final data = await ApiClient.instance.get('/reviews/me');
      final remote = <Map<String, dynamic>>[
        for (final item in (data as List? ?? const []))
          if (item is Map)
            {
              'id': item['id']?.toString() ?? '',
              'kind': _Kind.place.name,
              'name': (item['place'] is Map ? item['place']['name'] : null) ?? 'Lugar',
              'state': '',
              'rating': item['rating'] ?? 0,
              'comment': item['comment'] ?? '',
              'createdAt': item['createdAt']?.toString() ?? '',
            },
      ];
      final others = local.where((r) => r['kind'] != _Kind.place.name);
      final merged = [...remote, ...others]
        ..sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
      if (mounted) setState(() => _myReviews = merged);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.logout();
    } catch (_) {
      // Sin conexión: se queda la copia local.
    }
  }

  Future<void> _removeFavoritePlace(Place place) async {
    try {
      await _repository.removeFavorite(place.id);
      if (mounted) setState(() => _favPlaces.remove(place));
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.logout();
      if (mounted) _showMessage(e.message);
    }
  }

  Future<void> _removeFavoriteLocal(Map<String, dynamic> item) async {
    final updated = _favLocal.where((i) => i['id'] != item['id']).toList();
    await _Store.write(_Store.favoritesKey, updated);
    if (mounted) setState(() => _favLocal = updated);
  }

  /// Tocar un favorito lo manda al formulario para calificarlo o reseñarlo.
  void _reviewFavoritePlace(Place place) {
    setState(() {
      _mode = _Mode.add;
      _kind = _Kind.place;
      _place = place;
      _favorite = false; // Ya es favorito: aquí solo se califica.
      _rating = 0;
      _commentController.clear();
    });
  }

  // ───────────── Selectores ─────────────

  Future<void> _pickPlace() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final result = await showModalBottomSheet<Place>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PickerSheet<Place>(
        title: 'Elige un lugar',
        hint: 'Buscar por nombre o estado',
        items: catalog.places,
        label: (p) => p.name,
        subtitle: (p) => p.state.isEmpty ? p.category : '${p.state} · ${p.category}',
        searchText: (p) => '${p.name} ${p.state}',
      ),
    );
    if (result != null) setState(() => _place = result);
  }

  Future<void> _pickState() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PickerSheet<String>(
        title: 'Elige el estado',
        hint: 'Buscar estado',
        items: catalog.states,
        label: (s) => s,
        searchText: (s) => s,
      ),
    );
    if (result != null) setState(() => _state = result);
  }

  // ───────────── Guardar ─────────────

  Future<void> _save() async {
    final comment = _commentController.text.trim();
    final hasReview = _rating > 0 || comment.isNotEmpty;

    if (_kind == _Kind.place && _place == null) {
      return _showMessage('Elige el lugar que quieres guardar');
    }
    if (_kind != _Kind.place && _nameController.text.trim().isEmpty) {
      return _showMessage('Escribe el nombre del ${_kind == _Kind.hotel ? 'hotel' : 'restaurante'}');
    }
    if (!_favorite && !hasReview) {
      return _showMessage('Activa favorito o escribe una reseña para guardar');
    }
    if (comment.isNotEmpty && _rating == 0) {
      return _showMessage('Califica con estrellas para publicar tu reseña');
    }

    setState(() => _saving = true);
    try {
      if (_kind == _Kind.place) {
        await _savePlace(comment);
      } else {
        await _saveLocalItem(comment);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_successMessage(hasReview))));
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.logout();
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Lugares de la API: favorito y reseña van al backend (requieren sesión).
  Future<void> _savePlace(String comment) async {
    if (!_auth.isLoggedIn) {
      throw const ApiException('Inicia sesión para guardar favoritos y escribir reseñas');
    }
    final place = _place!;

    if (_favorite) {
      await _repository.addFavorite(place.id);
      // Ya quedó guardado: si la reseña falla, no se vuelve a intentar el favorito.
      if (mounted) setState(() => _favorite = false);
    }
    if (_rating > 0) {
      // Backend: POST /reviews con { placeId, rating, comment? } (requiere sesión).
      await ApiClient.instance.post(
        '/reviews',
        body: {
          'placeId': place.id,
          'rating': _rating,
          if (comment.isNotEmpty) 'comment': comment,
        },
      );
      await _recordReview(_Kind.place, place.name, place.state, comment);
    }
  }

  /// Copia local de la reseña, para poder listarla en la vista "Reseñas".
  ///
  /// TODO(backend): cuando exista GET /reviews/me, leer las reseñas del servidor.
  Future<void> _recordReview(_Kind kind, String name, String state, String comment) {
    return _Store.prepend(_Store.reviewsKey, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'kind': kind.name,
      'name': name,
      'state': state,
      'rating': _rating,
      'comment': comment,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Restaurantes y hoteles: la API aún no los tiene (ver el TODO de
  /// map_screen.dart), así que por ahora se guardan solo en el celular.
  Future<void> _saveLocalItem(String comment) async {
    final name = _nameController.text.trim();
    final state = _state ?? '';

    if (_favorite) {
      await _Store.prepend(_Store.favoritesKey, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'kind': _kind.name,
        'name': name,
        'state': state,
      });
    }
    if (_rating > 0) await _recordReview(_kind, name, state, comment);
  }

  String _successMessage(bool hasReview) {
    if (_kind == _Kind.place) {
      return hasReview ? 'Guardado y reseña publicada' : 'Guardado en favoritos';
    }
    return hasReview ? 'Guardado con tu reseña' : 'Guardado en favoritos';
  }

  // ───────────── Pantalla ─────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isPlace = _kind == _Kind.place;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Mode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Mode.add, icon: Icon(Icons.add_rounded), label: Text('Agregar')),
                  ButtonSegment(
                    value: _Mode.favorites,
                    icon: Icon(Icons.favorite_border_rounded),
                    label: Text('Favoritos'),
                  ),
                  ButtonSegment(
                    value: _Mode.reviews,
                    icon: Icon(Icons.rate_review_outlined),
                    label: Text('Reseñas'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (value) => _setMode(value.first),
              ),
            ),
            const SizedBox(height: 20),
            if (_mode == _Mode.add) ..._addForm(theme, colors, isPlace),
            if (_mode == _Mode.favorites) ..._favoritesView(theme, colors),
            if (_mode == _Mode.reviews) ..._reviewsView(theme, colors),
          ],
        ),
      ),
    );
  }

  List<Widget> _addForm(ThemeData theme, ColorScheme colors, bool isPlace) {
    return [
            Text('¿Qué quieres guardar?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Kind>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Kind.place, icon: Icon(Icons.place_outlined), label: Text('Lugar')),
                  ButtonSegment(
                    value: _Kind.restaurant,
                    icon: Icon(Icons.restaurant_outlined),
                    label: Text('Comida'),
                  ),
                  ButtonSegment(value: _Kind.hotel, icon: Icon(Icons.hotel_outlined), label: Text('Hotel')),
                ],
                selected: {_kind},
                onSelectionChanged: (value) => setState(() => _kind = value.first),
              ),
            ),
            const SizedBox(height: 20),
            if (isPlace) _placeField(theme) else ..._localFields(),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Guardar en favoritos'),
              secondary: Icon(
                _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: colors.secondary,
              ),
              value: _favorite,
              onChanged: (value) => setState(() => _favorite = value),
            ),
            const SizedBox(height: 8),
            Text('Tu calificación', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            _StarRating(value: _rating, onChanged: (value) => setState(() => _rating = value)),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reseña (opcional)',
                hintText: 'Cuéntanos cómo te fue',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: const Text('Guardar'),
            ),
    ];
  }

  List<Widget> _favoritesView(ThemeData theme, ColorScheme colors) {
    if (_favLoading && _favPlaces.isEmpty && _favLocal.isEmpty) {
      return const [Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))];
    }
    final widgets = <Widget>[];
    if (_favError != null) {
      widgets.add(Text(_favError!, style: TextStyle(color: colors.error)));
    }
    if (!_auth.isLoggedIn) {
      widgets.add(_Hint(icon: Icons.lock_outline_rounded, text: 'Inicia sesión para ver tus lugares favoritos.'));
    }
    if (_favPlaces.isNotEmpty) {
      widgets.add(Text('Lugares', style: theme.textTheme.titleMedium));
      widgets.add(const SizedBox(height: 8));
      for (final place in _favPlaces) {
        widgets.add(
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(Icons.place_rounded, color: colors.primary),
              title: Text(place.name),
              subtitle: Text(place.state.isEmpty ? place.category : '${place.state} · ${place.category}'),
              onTap: () => _reviewFavoritePlace(place),
              trailing: IconButton(
                tooltip: 'Quitar de favoritos',
                icon: Icon(Icons.favorite_rounded, color: colors.secondary),
                onPressed: () => _removeFavoritePlace(place),
              ),
            ),
          ),
        );
      }
      widgets.add(
        Text(
          'Toca un lugar para calificarlo o escribir una reseña.',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }
    if (_favLocal.isNotEmpty) {
      widgets.add(Text('Restaurantes y hoteles', style: theme.textTheme.titleMedium));
      widgets.add(const SizedBox(height: 8));
      for (final item in _favLocal) {
        final kind = _kindFromName(item['kind'] as String?);
        final state = item['state'] as String? ?? '';
        widgets.add(
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(kind.icon, color: colors.primary),
              title: Text(item['name'] as String? ?? ''),
              subtitle: Text(state.isEmpty ? kind.label : '${kind.label} · $state'),
              trailing: IconButton(
                tooltip: 'Quitar de favoritos',
                icon: Icon(Icons.favorite_rounded, color: colors.secondary),
                onPressed: () => _removeFavoriteLocal(item),
              ),
            ),
          ),
        );
      }
    }
    if (_favPlaces.isEmpty && _favLocal.isEmpty && _auth.isLoggedIn && _favError == null) {
      widgets.add(
        _Hint(
          icon: Icons.favorite_border_rounded,
          text: 'Aún no tienes favoritos. Guarda uno desde "Agregar" o con el corazón en Explorar.',
        ),
      );
    }
    return widgets;
  }

  List<Widget> _reviewsView(ThemeData theme, ColorScheme colors) {
    if (_myReviews.isEmpty) {
      return [
        _Hint(
          icon: Icons.rate_review_outlined,
          text: 'Aún no has escrito reseñas. Califica un lugar desde "Agregar".',
        ),
      ];
    }
    return [
      for (final review in _myReviews)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_kindFromName(review['kind'] as String?).icon, size: 20, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        review['name'] as String? ?? '',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= ((review['rating'] as num?)?.toInt() ?? 0)
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 20,
                        color: colors.tertiary,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _reviewMeta(review),
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                if ((review['comment'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(review['comment'] as String),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  String _reviewMeta(Map<String, dynamic> review) {
    final state = review['state'] as String? ?? '';
    final date = (review['createdAt'] as String? ?? '');
    final day = date.length >= 10 ? date.substring(0, 10) : '';
    return [if (state.isNotEmpty) state, if (day.isNotEmpty) day].join(' · ');
  }

  Widget _placeField(ThemeData theme) {
    if (_loadingCatalog) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_catalogError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_catalogError!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: _loadCatalog, child: const Text('Reintentar')),
        ],
      );
    }
    return _SelectField(
      label: 'Lugar',
      value: _place?.name,
      placeholder: 'Toca para elegir un lugar',
      icon: Icons.place_outlined,
      onTap: _pickPlace,
    );
  }

  List<Widget> _localFields() {
    final isHotel = _kind == _Kind.hotel;
    return [
      TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: isHotel ? 'Nombre del hotel' : 'Nombre del restaurante',
          prefixIcon: Icon(isHotel ? Icons.hotel_outlined : Icons.restaurant_outlined),
        ),
      ),
      const SizedBox(height: 14),
      if (_catalog != null)
        _SelectField(
          label: 'Estado (opcional)',
          value: _state,
          placeholder: 'Toca para elegir el estado',
          icon: Icons.map_outlined,
          onTap: _pickState,
        ),
    ];
  }
}

/// Campo que se ve como un input pero abre una lista para elegir.
class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    this.value,
  });

  final String label;
  final String placeholder;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          value ?? placeholder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: value == null ? colors.onSurfaceVariant : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Cinco estrellas tocables. Tocar la estrella ya elegida quita la calificación.
class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;

    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
            iconSize: 36,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
            color: color,
            icon: Icon(i <= value ? Icons.star_rounded : Icons.star_border_rounded),
            onPressed: () => onChanged(i == value ? 0 : i),
          ),
      ],
    );
  }
}

/// Hoja con buscador para elegir un elemento de una lista larga.
class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.hint,
    required this.items,
    required this.label,
    required this.searchText,
    this.subtitle,
  });

  final String title;
  final String hint;
  final List<T> items;
  final String Function(T) label;
  final String Function(T)? subtitle;
  final String Function(T) searchText;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = normalizeText(_query);
    final items = query.isEmpty
        ? widget.items
        : widget.items.where((i) => normalizeText(widget.searchText(i)).contains(query)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.title, style: theme.textTheme.titleMedium),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final subtitle = widget.subtitle?.call(item);
                        return ListTile(
                          title: Text(widget.label(item)),
                          subtitle: subtitle == null ? null : Text(subtitle),
                          onTap: () => Navigator.of(context).pop(item),
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

/// Mensaje vacío con ícono.
class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: colors.secondary),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Listas guardadas en el celular (restaurantes y hoteles favoritos, y copia de
/// las reseñas escritas desde esta pantalla).
class _Store {
  static const favoritesKey = 'mxguide_saved_items';
  static const reviewsKey = 'mxguide_my_reviews';

  static Future<List<Map<String, dynamic>>> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(key);
      if (raw == null) return [];
      return [
        for (final item in jsonDecode(raw) as List)
          if (item is Map<String, dynamic>) item,
      ];
    } catch (_) {
      return []; // Datos dañados: se empieza de cero.
    }
  }

  static Future<void> write(String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  static Future<void> prepend(String key, Map<String, dynamic> item) async {
    final items = await read(key);
    items.insert(0, item);
    await write(key, items);
  }
}
