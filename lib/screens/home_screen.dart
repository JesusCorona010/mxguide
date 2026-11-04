import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'explore_screen.dart';
import 'map_screen.dart';
import 'achievements_screen.dart';
import 'profile/profile_screen.dart';
import 'add_screen.dart';
import '../services/nearby_alerts_service.dart';

/// Pantalla principal con la barra de navegación inferior y el botón "+".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Pestañas que ya se abrieron al menos una vez. El resto no se construye
  // todavía: así el mapa (que es pesado) arranca solo cuando entras a "Mapa".
  final Set<int> _opened = {0};

  static const _mapTab = 1;
  static const _achievementsTab = 2;

  // IndexedStack mantiene el estado de cada pestaña (búsqueda, scroll, filtros)
  // aunque cambies de una a otra, pero solo de las que ya abriste.
  late final List<Widget> _tabs = [
    const ExploreScreen(),
    const SizedBox.shrink(), // Mapa: se arma en build() para avisarle si está activo.
    const AchievementsScreen(),
    ProfileScreen(onOpenAchievements: () => _selectTab(_achievementsTab)),
  ];

  @override
  void initState() {
    super.initState();
    // Si el usuario dejó prendidos los avisos de lugares cercanos, arrancan.
    NearbyAlertsService.instance.restore();
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _opened.add(index);
    });
  }

  void _onAddPressed() {
    Navigator.of(context).push(AddScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              if (!_opened.contains(i))
                const SizedBox.shrink()
              else if (i == _mapTab)
                MapScreen(isActive: _currentIndex == _mapTab)
              else
                _tabs[i],
          ],
        ),
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
                onTap: () => _selectTab(0),
              ),
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'Mapa',
                selected: _currentIndex == 1,
                onTap: () => _selectTab(1),
              ),
              const SizedBox(width: 72), // Hueco para el botón "+".
              _NavItem(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events,
                label: 'Logros',
                selected: _currentIndex == 2,
                onTap: () => _selectTab(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                selected: _currentIndex == 3,
                onTap: () => _selectTab(3),
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
