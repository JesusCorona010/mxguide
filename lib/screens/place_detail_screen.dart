import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/achievements_data.dart';
import '../models/achievement.dart';
import '../models/place_detail.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/chatbot_service.dart';
import '../services/places_repository.dart';
import '../services/progress_service.dart';
import '../theme/app_colors.dart';
import '../utils/text_utils.dart';
import 'achievement_unlocked_screen.dart';
import 'chat/chat_screen.dart';

/// Detalle de un lugar turístico: fotos, información, insignia del estado,
/// cómo llegar, preguntas a Mictlan y reseñas.
class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({super.key, required this.placeId, this.initialName});

  final String placeId;

  /// Nombre para mostrar mientras carga (viene de la tarjeta que se tocó).
  final String? initialName;

  static Route<void> route(String placeId, {String? name}) =>
      MaterialPageRoute(builder: (_) => PlaceDetailScreen(placeId: placeId, initialName: name));

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final _api = ApiClient.instance;
  final _progress = ProgressService.instance;

  PlaceDetail? _place;
  List<PlaceReview> _reviews = const [];
  String? _error;
  bool _isFavorite = false;
  bool _favBusy = false;
  bool _expanded = false;
  bool _showAllReviews = false;
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _progress.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ───────────── Datos ─────────────

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _api.get('/places/${Uri.encodeComponent(widget.placeId)}');
      if (data is! Map<String, dynamic>) throw const ApiException('El lugar no tiene información.');
      if (!mounted) return;
      setState(() => _place = PlaceDetail.fromJson(data));
      // Reseñas y favorito no deben impedir ver el lugar si fallan.
      await Future.wait([_loadReviews(), _loadFavorite()]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final data = await _api.get('/places/${Uri.encodeComponent(widget.placeId)}/reviews');
      if (!mounted) return;
      setState(() {
        _reviews = [
          for (final r in (data as List? ?? const []))
            if (r is Map<String, dynamic>) PlaceReview.fromJson(r),
        ];
      });
    } on ApiException {
      // Sin reseñas visibles, pero el resto de la pantalla funciona.
    }
  }

  Future<void> _loadFavorite() async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final ids = await PlacesRepository.instance.fetchFavoriteIds();
      if (mounted) setState(() => _isFavorite = ids.contains(widget.placeId));
    } on ApiException {
      // Se queda como "no favorito".
    }
  }

  // ───────────── Acciones ─────────────

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleFavorite() async {
    if (!AuthService.instance.isLoggedIn) {
      _snack('Inicia sesión para guardar tus favoritos');
      return;
    }
    if (_favBusy) return;
    final wasFavorite = _isFavorite;
    setState(() {
      _isFavorite = !wasFavorite;
      _favBusy = true;
    });
    try {
      if (wasFavorite) {
        await PlacesRepository.instance.removeFavorite(widget.placeId);
      } else {
        await PlacesRepository.instance.addFavorite(widget.placeId);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isFavorite = wasFavorite);
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  StateAchievement? _achievementFor(PlaceDetail place) {
    final state = normalizeText(place.state);
    for (final a in stateAchievements) {
      if (normalizeText(a.state) == state) return a;
    }
    return null;
  }

  Future<void> _markVisited(PlaceDetail place) async {
    if (_progress.hasVisitedPlace(place.id)) {
      _snack('Ya está en tus lugares visitados');
      return;
    }
    final newBadge = await _progress.registerVisit(place.state, placeId: place.id);
    if (!mounted) return;
    final achievement = _achievementFor(place);
    if (newBadge && achievement != null) {
      await Navigator.of(context).push(
        AchievementUnlockedScreen.route(
          achievement: achievement,
          visitedStates: _progress.visitedStates.length,
          totalStates: stateAchievements.length,
        ),
      );
    } else {
      _snack('¡Agregado a tus lugares visitados!');
    }
  }

  Future<void> _openMaps(PlaceDetail place, {bool directions = false}) async {
    final coords = '${place.latitude},${place.longitude}';
    final uri = directions
        ? Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': coords})
        : Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': coords});
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('No se pudo abrir Google Maps');
    } catch (_) {
      _snack('No se pudo abrir Google Maps');
    }
  }

  void _askMictlan(PlaceDetail place, String question) {
    ChatbotService.instance.send('Sobre ${place.name} (${place.locationLabel}): $question');
    Navigator.of(context).push(ChatScreen.route());
  }

  Future<void> _writeReview(PlaceDetail place) async {
    if (!AuthService.instance.isLoggedIn) {
      _snack('Inicia sesión para escribir una reseña');
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewSheet(placeId: place.id, placeName: place.name),
    );
    if (sent == true) {
      _snack('¡Gracias por tu reseña!');
      await _loadReviews();
    }
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final place = _place;

    if (place == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.initialName ?? 'Lugar', maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 52, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.tonal(onPressed: _load, child: const Text('Reintentar')),
                    ],
                  ),
                ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final achievement = _achievementFor(place);
    final visited = _progress.hasVisitedPlace(place.id);
    final badgeUnlocked = achievement != null && _progress.hasVisited(achievement.state);
    final average = _reviews.isEmpty ? null : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 320,
              backgroundColor: colors.surface,
              foregroundColor: colors.onSurface,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: _RoundButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Regresar',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _RoundButton(
                    icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    tooltip: _isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
                    color: const Color(0xFFFF8A80),
                    onPressed: _toggleFavorite,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _Gallery(
                  images: place.images,
                  index: _photo,
                  onChanged: (i) => setState(() => _photo = i),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Encabezado ──
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [for (final c in place.categories.take(3)) _Tag(label: c)],
                    ),
                    const SizedBox(height: 8),
                    Text(place.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (place.locationLabel.isNotEmpty)
                          _IconText(icon: Icons.place_outlined, text: place.locationLabel),
                        if (average != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 18, color: colors.tertiary),
                              const SizedBox(width: 3),
                              Text(
                                average.toStringAsFixed(1),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                ' · ${_reviews.length} ${_reviews.length == 1 ? 'reseña' : 'reseñas'}',
                                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // ── Insignia del estado ──
                    if (achievement != null) ...[
                      const SizedBox(height: 18),
                      _BadgeCard(achievement: achievement, unlocked: badgeUnlocked),
                    ],

                    // ── Datos rápidos ──
                    if (place.openingHours != null || place.entryCost != null) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          if (place.openingHours != null)
                            Expanded(
                              child: _InfoTile(icon: Icons.schedule_rounded, label: 'Horario', value: place.openingHours!),
                            ),
                          if (place.openingHours != null && place.entryCost != null) const SizedBox(width: 10),
                          if (place.entryCost != null)
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.confirmation_number_outlined,
                                label: 'Entrada',
                                value: place.entryCost!,
                              ),
                            ),
                        ],
                      ),
                    ],

                    // ── Botones ──
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                            onPressed: () => _openMaps(place, directions: true),
                            icon: const Icon(Icons.navigation_rounded, size: 20),
                            label: const Text('Cómo llegar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: visited ? colors.primary.withAlpha(30) : null,
                              side: BorderSide(color: colors.primary, width: 1.5),
                            ),
                            onPressed: () => _markVisited(place),
                            icon: Icon(visited ? Icons.check_circle_rounded : Icons.check_rounded, size: 20),
                            label: Text(visited ? '¡Visitado!' : 'Ya lo visité'),
                          ),
                        ),
                      ],
                    ),

                    // ── Descripción ──
                    if (place.description.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      const _SectionTitle('Sobre este lugar'),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topCenter,
                        child: Text(
                          place.description,
                          maxLines: _expanded ? null : 4,
                          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                        ),
                      ),
                      if (place.description.length > 180)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            onPressed: () => setState(() => _expanded = !_expanded),
                            child: Text(_expanded ? 'Leer menos' : 'Leer más'),
                          ),
                        ),
                    ],

                    // ── Ubicación ──
                    const SizedBox(height: 22),
                    const _SectionTitle('Ubicación'),
                    _LocationCard(place: place, onOpen: () => _openMaps(place)),

                    // ── Mictlan ──
                    const SizedBox(height: 22),
                    _AskMictlanCard(onAsk: (q) => _askMictlan(place, q)),

                    // ── Cerca de aquí ──
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle('Cerca de aquí')),
                        _Tag(label: 'Pronto', accent: colors.tertiary),
                      ],
                    ),
                    Text(
                      // TODO(backend): hoteles y restaurantes cercanos cuando exista la API.
                      'Muy pronto verás hoteles y restaurantes cerca de este lugar.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),

                    // ── Reseñas ──
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle('Reseñas')),
                        TextButton.icon(
                          onPressed: () => _writeReview(place),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Escribir reseña'),
                        ),
                      ],
                    ),
                    if (_reviews.isEmpty)
                      Text(
                        'Aún no hay reseñas. ¡Sé el primero en contar cómo te fue!',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                      )
                    else ...[
                      _RatingSummary(reviews: _reviews, average: average!),
                      const SizedBox(height: 12),
                      for (final review in _showAllReviews ? _reviews : _reviews.take(3)) ...[
                        _ReviewCard(review: review),
                        const SizedBox(height: 10),
                      ],
                      if (_reviews.length > 3 && !_showAllReviews)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                          onPressed: () => setState(() => _showAllReviews = true),
                          child: Text('Ver las ${_reviews.length} reseñas'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────── Piezas ─────────────

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(backgroundColor: const Color(0x8C0A1A2F)),
      icon: Icon(icon, color: color ?? Colors.white),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.images, required this.index, required this.onChanged});

  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final placeholder = ColoredBox(
      color: isDark ? AppExtraColors.imagePlaceholderDark : AppExtraColors.imagePlaceholderLight,
      child: Center(child: Icon(Icons.photo_outlined, size: 48, color: theme.colorScheme.primary)),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: onChanged,
          itemBuilder: (context, i) => Image.network(
            images[i],
            fit: BoxFit.cover,
            semanticLabel: 'Foto ${i + 1} de ${images.length}',
            errorBuilder: (context, error, stackTrace) => placeholder,
            loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
          ),
        ),
        if (images.length > 1) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length && i < 8; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == index ? Colors.white : Colors.white70,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xB30A1A2F), borderRadius: BorderRadius.circular(12)),
              child: Text(
                '${index + 1} / ${images.length}',
                style: theme.textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.accent});

  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: color.withAlpha(32), borderRadius: BorderRadius.circular(14)),
      child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color))),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.achievement, required this.unlocked});

  final StateAchievement achievement;
  final bool unlocked;

  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget badge = Image.asset(
      achievement.badgeAsset,
      width: 60,
      height: 60,
      errorBuilder: (context, error, stackTrace) => Icon(achievement.icon, size: 40, color: colors.tertiary),
    );
    if (!unlocked) badge = Opacity(opacity: 0.55, child: ColorFiltered(colorFilter: _grayscale, child: badge));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiary.withAlpha(28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.tertiary.withAlpha(90)),
      ),
      child: Row(
        children: [
          ClipOval(child: badge),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INSIGNIA DE ${achievement.state.toUpperCase()}',
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                Text(achievement.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  unlocked
                      ? '¡Desbloqueada! Ya es parte de tu pasaporte.'
                      : 'Marca este lugar como visitado para desbloquearla.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.place, required this.onOpen});

  final PlaceDetail place;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final address = [place.address, place.locationLabel].where((t) => t.isNotEmpty).join('\n');

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: colors.primary.withAlpha(30), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.map_outlined, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                address.isEmpty ? 'Ver ubicación en el mapa' : address,
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.35),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(onPressed: onOpen, child: const Text('Abrir en Maps')),
          ],
        ),
      ),
    );
  }
}

class _AskMictlanCard extends StatelessWidget {
  const _AskMictlanCard({required this.onAsk});

  final ValueChanged<String> onAsk;

  static const _questions = ['¿Qué debo llevar?', '¿A qué hora conviene ir?', 'Arma un día aquí'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const navy = AppColors.textPrimaryLight;
    const teal = AppColors.jungleTealDark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.jungleTealLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.jaguarOchreDark, width: 2),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pregúntale a Mictlan',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Resuelve tus dudas sobre este lugar',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in _questions)
                ActionChip(
                  label: Text(q),
                  onPressed: () => onAsk(q),
                  backgroundColor: navy,
                  side: const BorderSide(color: Color(0xFF2F6F69)),
                  shape: const StadiumBorder(),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(color: teal, fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.reviews, required this.average});

  final List<PlaceReview> reviews;
  final double average;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Column(
              children: [
                Text(average.toStringAsFixed(1), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                _Stars(rating: average.round()),
                Text(
                  '${reviews.length} ${reviews.length == 1 ? 'reseña' : 'reseñas'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text('$stars', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: reviews.where((r) => r.rating == stars).length / reviews.length,
                              minHeight: 7,
                              backgroundColor: colors.outline.withAlpha(120),
                              color: colors.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Semantics(
      label: '$rating de 5 estrellas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: color),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final PlaceReview review;

  static const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = review.createdAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: colors.primary,
                child: Text(
                  review.initials,
                  style: theme.textTheme.labelLarge?.copyWith(color: colors.onPrimary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    if (date != null)
                      Text(
                        '${date.day} ${_months[date.month - 1]} ${date.year}',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              _Stars(rating: review.rating, size: 15),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// Hoja para escribir una reseña (POST /reviews).
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.placeId, required this.placeName});

  final String placeId;
  final String placeName;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_rating == 0) {
      setState(() => _error = 'Elige cuántas estrellas le das');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/reviews', body: {
        'placeId': widget.placeId,
        'rating': _rating,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿Cómo te fue en ${widget.placeName}?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
                  iconSize: 36,
                  onPressed: _sending ? null : () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: colors.tertiary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            enabled: !_sending,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Cuéntales a otros viajeros (opcional)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: colors.error)),
            ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _sending ? null : _send,
            child: _sending
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.onPrimary),
                  )
                : const Text('Publicar reseña'),
          ),
        ],
      ),
    );
  }
}
