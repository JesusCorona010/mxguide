import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/place.dart';
import '../services/place_service.dart';
import '../services/proximity_service.dart';
import '../theme/theme_controller.dart';
import 'explore_screen.dart';

/// Pantalla principal con la barra de navegación inferior y el botón "+".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _showNotifications = false;

  // Historial de avisos de cercanía, más reciente primero. Además de la
  // notificación del sistema (ProximityService), se guarda aquí para que
  // el usuario pueda revisarlos sin que se pierdan como un SnackBar.
  final List<_NotificationItem> _notifications = [];

  // El mensaje flotante que aparece justo cuando se dispara un aviso.
  // Se muestra solo, y al desaparecer ya queda contado en el badge de la
  // campanita (que lee _unreadCount de _notifications).
  _NotificationItem? _activeToast;
  bool _toastVisible = false;
  Timer? _toastTimer;

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  // IndexedStack mantiene el estado de cada pestaña (búsqueda, scroll, filtros)
  // aunque cambies de una a otra.
  static const _tabs = <Widget>[
    ExploreScreen(),
    _ComingSoonTab(icon: Icons.map_outlined, title: 'Mapa'),
    _ComingSoonTab(icon: Icons.emoji_events_outlined, title: 'Logros'),
    _ComingSoonTab(icon: Icons.person_outline_rounded, title: 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    // Notificaciones por cercanía: arranca en cuanto el usuario llega al
    // Home. Primero hay que traer los lugares de la API (ExploreScreen pide
    // los mismos, así que esto normalmente ya viene del caché de
    // PlaceService y no pega dos veces al backend). Si no hay permiso de
    // ubicación, o si falla la conexión con el backend, no truena: la
    // función simplemente se queda apagada.
    PlaceService.instance.fetchPlaces().then((places) {
      if (!mounted) return;
      ProximityService.instance.start(places: places, onPlaceNearby: _onPlaceNearby);
    }).catchError((_) {
      // Sin conexión al backend no hay lugares que vigilar; el resto de la
      // app sigue funcionando igual.
    });
  }

  @override
  void dispose() {
    ProximityService.instance.stop();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _onPlaceNearby(Place place, String message) {
    if (!mounted) return;
    final item = _NotificationItem(place: place, message: message, time: DateTime.now());

    setState(() {
      // 1. Se guarda de una vez (así el badge ya cuenta este aviso aunque
      //    el usuario no vea el flotante a tiempo).
      _notifications.insert(0, item);
      // 2. Y se muestra flotando un momento para que no se le pase.
      _activeToast = item;
      _toastVisible = true;
    });

    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _toastVisible = false);
    });
  }

  void _dismissToast() {
    _toastTimer?.cancel();
    if (!_toastVisible) return;
    setState(() => _toastVisible = false);
  }

  void _toggleNotifications() {
    setState(() => _showNotifications = !_showNotifications);
  }

  void _closeNotifications() {
    if (!_showNotifications) return;
    setState(() => _showNotifications = false);
  }

  void _markAllNotificationsRead() {
    setState(() {
      for (final item in _notifications) {
        item.read = true;
      }
    });
  }

  void _onNotificationTap(_NotificationItem item) {
    _toastTimer?.cancel();
    setState(() {
      item.read = true;
      _showNotifications = false;
      if (identical(item, _activeToast)) _toastVisible = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Detalle de "${item.place.name}" próximamente')));
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
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _tabs),
            // Tema y notificaciones flotan encima de cualquier pestaña, en
            // vez de vivir dentro del contenido de cada una (así no se
            // pierden al hacer scroll y están disponibles en toda la app).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _FloatingIconButton(
                        tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                        icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        onTap: () => themeController.toggle(theme.brightness),
                      ),
                      const SizedBox(width: 8),
                      _FloatingIconButton(
                        tooltip: 'Notificaciones',
                        icon: Icons.notifications_outlined,
                        badgeCount: _unreadCount,
                        onTap: _toggleNotifications,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_activeToast != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                top: _toastVisible ? MediaQuery.of(context).padding.top + 60 : -140,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _toastVisible ? 1 : 0,
                  child: _ProximityToast(
                    item: _activeToast!,
                    onTap: () => _onNotificationTap(_activeToast!),
                    onDismiss: _dismissToast,
                  ),
                ),
              ),
            if (_showNotifications) ...[
              // Barrera invisible: cierra el mensaje flotante al tocar fuera,
              // sin oscurecer la pantalla (no es un modal, es un flotante).
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeNotifications,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                right: 16,
                child: _NotificationDropdown(
                  notifications: _notifications,
                  onMarkAllRead: _markAllNotificationsRead,
                  onItemTap: _onNotificationTap,
                ),
              ),
            ],
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

/// Un aviso de "estás cerca de X lugar" guardado en el historial.
class _NotificationItem {
  _NotificationItem({required this.place, required this.message, required this.time, this.read = false});

  final Place place;
  final String message;
  final DateTime time;
  bool read;
}

/// El mensaje flotante que aparece justo cuando se dispara un aviso de
/// cercanía. Se desliza desde arriba, se queda unos segundos y desaparece
/// sola (o al tocarla) — el aviso ya quedó contado en la campanita.
class _ProximityToast extends StatelessWidget {
  const _ProximityToast({required this.item, required this.onTap, required this.onDismiss});

  final _NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Icon(Icons.location_on_rounded, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onDismiss,
                tooltip: 'Cerrar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón circular flotante (tema, notificaciones), con badge opcional.
class _FloatingIconButton extends StatelessWidget {
  const _FloatingIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, color: colors.primary, size: 22)),
                if (badgeCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(color: colors.secondary, shape: BoxShape.circle),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mensaje flotante con el historial de notificaciones, anclado bajo la
/// campanita (como un dropdown de escritorio, pero pensado para tocar).
class _NotificationDropdown extends StatelessWidget {
  const _NotificationDropdown({
    required this.notifications,
    required this.onMarkAllRead,
    required this.onItemTap,
  });

  final List<_NotificationItem> notifications;
  final VoidCallback onMarkAllRead;
  final ValueChanged<_NotificationItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasUnread = notifications.any((n) => !n.read);

    return Material(
      color: colors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Notificaciones', style: theme.textTheme.titleSmall)),
                  if (hasUnread)
                    TextButton(
                      onPressed: onMarkAllRead,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Marcar todas como leídas', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No tienes notificaciones',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return InkWell(
                      onTap: () => onItemTap(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: item.read ? colors.onSurfaceVariant : colors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estás cerca de ${item.place.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    item.message,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _timeAgo(item.time),
                                    style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            if (!item.read)
                              Container(
                                margin: const EdgeInsets.only(top: 4, left: 6),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(color: colors.tertiary, shape: BoxShape.circle),
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
      ),
    );
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} d';
}

/// Pestaña temporal para las secciones que aún no se diseñan.
class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colors.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Próximamente',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}