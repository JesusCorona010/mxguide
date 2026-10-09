import 'package:flutter/material.dart';
import '../data/achievements_data.dart';
import '../models/achievement.dart';
import '../theme/app_colors.dart';
import '../widgets/achievement_medal.dart';
import 'achievement_unlocked_screen.dart';

enum _MedalFilter { all, unlocked, locked }

/// Pestaña "Logros": rango del viajero, contadores y medallas por estado.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  // TODO(backend): obtener de la API los estados visitados y los contadores.
  final Set<String> _visitedStates = {
    'Ciudad de México',
    'Puebla',
    'Estado de México',
    'Oaxaca',
    'Yucatán',
  };
  final int _visitedPlaces = 23;
  final int _reviews = 4;

  _MedalFilter _filter = _MedalFilter.all;

  bool _isUnlocked(StateAchievement a) => _visitedStates.contains(a.state);

  List<StateAchievement> get _filteredAchievements {
    final list = stateAchievements.where((a) {
      return switch (_filter) {
        _MedalFilter.all => true,
        _MedalFilter.unlocked => _isUnlocked(a),
        _MedalFilter.locked => !_isUnlocked(a),
      };
    }).toList();

    // Desbloqueadas primero, luego en orden alfabético.
    list.sort((a, b) {
      final byUnlocked = (_isUnlocked(b) ? 1 : 0) - (_isUnlocked(a) ? 1 : 0);
      return byUnlocked != 0 ? byUnlocked : a.state.compareTo(b.state);
    });
    return list;
  }

  /// Desbloquea una medalla y muestra la celebración.
  /// TODO(backend): esto debe dispararse cuando el usuario marque como
  /// visitado un lugar de un estado nuevo.
  Future<void> _unlock(StateAchievement achievement) async {
    setState(() => _visitedStates.add(achievement.state));
    await Navigator.of(context).push(
      AchievementUnlockedScreen.route(
        achievement: achievement,
        visitedStates: _visitedStates.length,
        totalStates: stateAchievements.length,
      ),
    );
  }

  void _showDetails(StateAchievement achievement) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _MedalDetailsSheet(
        achievement: achievement,
        unlocked: _isUnlocked(achievement),
        onSimulateVisit: () {
          Navigator.of(sheetContext).pop();
          _unlock(achievement);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final achievements = _filteredAchievements;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Logros', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    'Tu pasaporte por México',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  _RankCard(visitedStates: _visitedStates.length, totalStates: stateAchievements.length),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatTile(icon: Icons.place_rounded, value: _visitedStates.length, label: 'Estados'),
                      const SizedBox(width: 8),
                      _StatTile(icon: Icons.check_circle_rounded, value: _visitedPlaces, label: 'Lugares'),
                      const SizedBox(width: 8),
                      _StatTile(icon: Icons.rate_review_rounded, value: _reviews, label: 'Reseñas'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterChips(
              selected: _filter,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            sliver: SliverGrid.builder(
              itemCount: achievements.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisExtent: 150,
                crossAxisSpacing: 4,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                final unlocked = _isUnlocked(achievement);
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showDetails(achievement),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Column(
                      children: [
                        AchievementMedal(achievement: achievement, unlocked: unlocked),
                        const SizedBox(height: 8),
                        Text(
                          achievement.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: unlocked ? colors.onSurface : colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          achievement.state,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta azul marino con el rango actual y el progreso.
class _RankCard extends StatelessWidget {
  const _RankCard({required this.visitedStates, required this.totalStates});

  final int visitedStates;
  final int totalStates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = rankFor(visitedStates);
    final next = nextRankFor(visitedStates);
    final progress = totalStates == 0 ? 0.0 : visitedStates / totalStates;

    const navy = AppColors.textPrimaryLight;
    const ochre = AppColors.jaguarOchreDark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          // Círculo decorativo.
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(color: ochre.withAlpha(40), shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.jaguarOchreLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(rank.icon, size: 30, color: navy),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TU RANGO',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ochre,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            rank.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    color: ochre,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$visitedStates',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' de $totalStates estados'),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        next == null
                            ? '¡Rango máximo!'
                            : 'Siguiente: ${next.name} (${next.minStates - visitedStates} más)',
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: colors.primary),
                const SizedBox(width: 4),
                Text('$value', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _MedalFilter selected;
  final ValueChanged<_MedalFilter> onSelected;

  static const _labels = {
    _MedalFilter.all: 'Todos',
    _MedalFilter.unlocked: 'Desbloqueados',
    _MedalFilter.locked: 'Por descubrir',
  };

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
        itemCount: _labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _labels.keys.elementAt(index);
          final isSelected = filter == selected;
          return ChoiceChip(
            label: Text(_labels[filter]!),
            selected: isSelected,
            onSelected: (_) => onSelected(filter),
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

/// Hoja inferior con el detalle de una medalla.
class _MedalDetailsSheet extends StatelessWidget {
  const _MedalDetailsSheet({
    required this.achievement,
    required this.unlocked,
    required this.onSimulateVisit,
  });

  final StateAchievement achievement;
  final bool unlocked;
  final VoidCallback onSimulateVisit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementMedal(achievement: achievement, unlocked: unlocked, size: 92),
            const SizedBox(height: 14),
            Text(achievement.title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              achievement.state,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              unlocked
                  ? achievement.description
                  : 'Visita cualquier lugar de ${achievement.state} para desbloquear esta medalla.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
            ),
            if (!unlocked) ...[
              const SizedBox(height: 20),
              // TODO(backend): quitar este botón cuando el desbloqueo sea real.
              OutlinedButton.icon(
                onPressed: onSimulateVisit,
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Simular visita (demo)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}