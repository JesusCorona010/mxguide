import 'package:flutter/material.dart';

import '../../data/achievements_data.dart';
import '../../models/achievement.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/chatbot_service.dart';
import '../../services/nearby_alerts_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/achievement_medal.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'favorites_screen.dart';
import 'help_screen.dart';
import 'profile_widgets.dart';

/// Pestaña "Perfil": datos del usuario, progreso, insignias y menú.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onOpenAchievements});

  /// Cambia a la pestaña de Logros (la maneja el Home).
  final VoidCallback onOpenAchievements;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final progress = ProgressService.instance;
    final alerts = NearbyAlertsService.instance;
    final chatbot = ChatbotService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([auth, progress, alerts, themeController, chatbot]),
      builder: (context, _) {
        final isLoggedIn = auth.isLoggedIn;
        final user = auth.user;

        return SafeArea(
          bottom: false,
          child: ListView(
            // Espacio abajo para que el botón "+" no tape el final.
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              Text(
                'Perfil',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (isLoggedIn)
                _ProfileHeader(user: user, visitedStates: progress.visitedStates.length)
              else
                const _GuestCard(),
              const SizedBox(height: 12),
              _StatsRow(
                badges: progress.visitedStates.length,
                places: progress.visitedPlaces,
                reviews: progress.reviews,
              ),
              const SizedBox(height: 24),
              SectionTitle(
                'Mis insignias',
                trailing: TextButton(onPressed: onOpenAchievements, child: const Text('Ver todas')),
              ),
              _BadgesStrip(visited: progress.visitedStates, onTap: onOpenAchievements),
              const SizedBox(height: 24),
              const SectionTitle('Mi actividad'),
              MenuSection(
                children: [
                  MenuTile(
                    icon: Icons.favorite_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                    title: 'Mis favoritos',
                    subtitle: 'Los lugares que guardaste',
                    onTap: () => isLoggedIn
                        ? Navigator.of(context).push(FavoritesScreen.route())
                        : _askToLogin(context, 'guardar tus lugares favoritos'),
                  ),
                  MenuTile(
                    icon: Icons.emoji_events_rounded,
                    title: 'Logros e insignias',
                    subtitle: '${progress.visitedStates.length} de ${stateAchievements.length} estados',
                    onTap: onOpenAchievements,
                  ),
                  MenuTile(
                    icon: Icons.rate_review_rounded,
                    title: 'Mis reseñas',
                    subtitle: 'Tus opiniones y fotos',
                    trailing: const SoonTag(),
                    // TODO(backend): falta GET /reviews/me para listar las reseñas del usuario.
                    onTap: () => _comingSoon(context, 'Mis reseñas'),
                  ),
                ],
              ),
              if (isLoggedIn) ...[
                const SizedBox(height: 24),
                const SectionTitle('Cuenta'),
                MenuSection(
                  children: [
                    MenuTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Información de la cuenta',
                      subtitle: 'Nombre, correo y fecha de registro',
                      onTap: () => Navigator.of(context).push(AccountScreen.route()),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const SectionTitle('Preferencias'),
              MenuSection(
                children: [
                  MenuTile(
                    icon: Icons.palette_outlined,
                    title: 'Apariencia',
                    subtitle: _themeLabel(themeController.value),
                    onTap: () => _pickTheme(context),
                  ),
                  MenuTile(
                    icon: Icons.near_me_rounded,
                    title: 'Avisos de lugares cercanos',
                    subtitle: 'Te avisamos cuando estés cerca de una atracción',
                    showChevron: false,
                    onTap: () => _toggleAlerts(context, !alerts.enabled),
                    trailing: Switch(
                      value: alerts.enabled,
                      onChanged: (value) => _toggleAlerts(context, value),
                    ),
                  ),
                  MenuTile(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Burbuja de Balam',
                    subtitle: 'Tu guía de viaje flotando en la app',
                    showChevron: false,
                    onTap: () => chatbot.setBubbleVisible(!chatbot.bubbleVisible),
                    trailing: Switch(
                      value: chatbot.bubbleVisible,
                      onChanged: chatbot.setBubbleVisible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle('Ayuda'),
              MenuSection(
                children: [
                  MenuTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Preguntas frecuentes',
                    onTap: () => Navigator.of(context).push(HelpScreen.route()),
                  ),
                  MenuTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Acerca de MXGuide',
                    onTap: () => Navigator.of(context).push(AboutScreen.route()),
                  ),
                ],
              ),
              if (isLoggedIn) ...[
                const SizedBox(height: 24),
                MenuSection(
                  children: [
                    MenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Cerrar sesión',
                      color: Theme.of(context).colorScheme.error,
                      showChevron: false,
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'MXGuide v$appVersion',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────────── Acciones ─────────────

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Igual que el celular',
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
      };

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  static void _comingSoon(BuildContext context, String feature) =>
      _snack(context, '$feature estará disponible pronto');

  static void _askToLogin(BuildContext context, String reason) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Inicia sesión para $reason'),
          action: SnackBarAction(
            label: 'Entrar',
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
          ),
        ),
      );
  }

  static Future<void> _toggleAlerts(BuildContext context, bool value) async {
    final ok = await NearbyAlertsService.instance.setEnabled(value);
    if (!ok && context.mounted) {
      _snack(context, 'Necesitamos permiso de ubicación para avisarte de lugares cercanos');
    }
  }

  static Future<void> _pickTheme(BuildContext context) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final current = themeController.value;
        return SafeArea(
          child: RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (mode) => Navigator.of(context).pop(mode),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text('Apariencia', style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final (mode, icon) in const [
                  (ThemeMode.system, Icons.smartphone_rounded),
                  (ThemeMode.light, Icons.light_mode_outlined),
                  (ThemeMode.dark, Icons.dark_mode_outlined),
                ])
                  RadioListTile<ThemeMode>(
                    value: mode,
                    secondary: Icon(icon),
                    title: Text(_themeLabel(mode)),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) themeController.setMode(selected);
  }

  static Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Podrás volver a entrar cuando quieras con tu correo y contraseña.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}

// ───────────── Widgets ─────────────

/// Tarjeta azul marino con avatar, nombre, correo y rango.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.visitedStates});

  final AppUser? user;
  final int visitedStates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = rankFor(visitedStates);
    final user = this.user;

    const navy = AppColors.textPrimaryLight;
    const ochre = AppColors.jaguarOchreDark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: ochre.withAlpha(40), shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatar(initials: user?.initials ?? '…', size: 68),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Cargando tu perfil…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (user != null)
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ochre.withAlpha(45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(rank.icon, size: 15, color: ochre),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                rank.name,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: ochre,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user?.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Viajero desde ${formatMonthYear(user!.createdAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark),
                        ),
                      ],
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

/// Lo que ve quien entró como invitado.
class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: colors.primary.withAlpha(30), shape: BoxShape.circle),
                child: Icon(Icons.person_outline_rounded, size: 30, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explorando como invitado', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Crea tu cuenta para guardar favoritos, escribir reseñas y no perder tus insignias.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  child: const Text('Iniciar sesión'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/register'),
                  child: const Text('Crear cuenta'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.badges, required this.places, required this.reviews});

  final int badges;
  final int places;
  final int reviews;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(icon: Icons.military_tech_rounded, value: '$badges/${stateAchievements.length}', label: 'Insignias'),
        const SizedBox(width: 8),
        _Stat(icon: Icons.check_circle_rounded, value: '$places', label: 'Lugares'),
        const SizedBox(width: 8),
        _Stat(icon: Icons.rate_review_rounded, value: '$reviews', label: 'Reseñas'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
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
                Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Fila horizontal con las insignias ganadas (o las primeras por ganar).
class _BadgesStrip extends StatelessWidget {
  const _BadgesStrip({required this.visited, required this.onTap});

  final Set<String> visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final unlocked = stateAchievements.where((a) => visited.contains(a.state)).toList();
    final showLocked = unlocked.isEmpty;
    final List<StateAchievement> items = showLocked ? stateAchievements.take(6).toList() : unlocked;

    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final achievement = items[index];
                    return SizedBox(
                      width: 70,
                      child: Column(
                        children: [
                          AchievementMedal(achievement: achievement, unlocked: !showLocked, size: 60),
                          const SizedBox(height: 4),
                          Text(
                            achievement.state,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (showLocked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(
                    'Visita un lugar de cualquier estado para ganar tu primera insignia.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
