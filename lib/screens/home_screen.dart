import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'explore_screen.dart';
import 'map_screen.dart';
import 'achievements_screen.dart';
import 'profile/profile_screen.dart';
import '../services/nearby_alerts_service.dart';
import '../widgets/chat_bubble_overlay.dart';

/// Pantalla principal con la barra de navegación inferior y el botón "+".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _achievementsTab = 2;

  // IndexedStack mantiene el estado de cada pestaña (búsqueda, scroll, filtros)
  // aunque cambies de una a otra.
  late final List<Widget> _tabs = [
    const ExploreScreen(),
    const MapScreen(),
    const AchievementsScreen(),
    ProfileScreen(onOpenAchievements: () => setState(() => _currentIndex = _achievementsTab)),
  ];

  @override
  void initState() {
    super.initState();
    // Si el usuario dejó prendidos los avisos de lugares cercanos, arrancan.
    NearbyAlertsService.instance.restore();
  }

  void _onAddPressed() {
    // TODO: definir qué hace el botón "+" (agregar lugar, reseña, etc.).
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Esta función estará disponible pronto')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        // La burbuja de Balam flota encima de todas las pestañas.
        body: ChatBubbleOverlay(child: IndexedStack(index: _currentIndex, children: _tabs)),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Agregar',
          onPressed: _onAddPressed,
          backgroundColor: colors.tertiary,
          foregroundColor: colors.onTertiary,
          elevation: 2,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          height: 68,
          padding: EdgeInsets.zero,
          color: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Explorar',
                selected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'Mapa',
                selected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(width: 72), // Hueco para el botón "+".
              _NavItem(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events,
                label: 'Logros',
                selected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                selected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
