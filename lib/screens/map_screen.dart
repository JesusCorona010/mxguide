import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/map_point.dart';
import '../models/place.dart';
import '../services/api_client.dart';
import '../services/places_repository.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../utils/text_utils.dart';

/// Pestaña "Mapa": lugares, hoteles y restaurantes con Google Maps.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.isActive = true});

  /// true cuando la pestaña "Mapa" es la que se está viendo. Mientras está en
  /// false (el usuario está en otra pestaña) el mapa no se toca al cambiar el
  /// tema: lo actualiza hasta que vuelve a entrar, para no trabar la app.
  final bool isActive;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Vista de todo México mientras no tengamos la ubicación del usuario.
  static const _defaultCenter = LatLng(23.6345, -102.5528);
  static const _defaultZoom = 5.0;
  // Zoom al acercarse a un lugar o a la ubicación del usuario.
  static const _closeZoom = 14.0;

  GoogleMapController? _mapController;
  final _searchController = TextEditingController();

  // Por ahora la API solo tiene lugares turísticos.
  // TODO(backend): agregar hoteles y restaurantes cuando existan en la API.
  List<MapPoint> _points = const [];
  bool _isLoadingPoints = true;

  // Los filtros arrancan apagados: el usuario elige qué quiere ver.
  final Set<MapPointType> _activeTypes = {};
  String _query = '';
  MapPoint? _selected;

  // Ruta dentro de la app.
  List<LatLng> _route = const [];
  double? _routeMeters;
  double? _routeSeconds;
  bool _routeWalking = true;
  bool _routeLoading = false;
  LatLng? _userLocation;
  bool _isLocating = false;

  // Íconos de los marcadores (se dibujan con los colores del tema actual).
  Map<String, BitmapDescriptor> _markerIcons = {};
  Brightness? _iconsBrightness;

  // Los íconos de cada modo se dibujan una sola vez y se reutilizan, así
  // cambiar de tema seguido no vuelve a dibujarlos.
  final Map<Brightness, Map<String, BitmapDescriptor>> _iconCache = {};

  // Marcadores ya armados. Si no cambió nada, se reusa el mismo conjunto para
  // que el mapa no tenga que actualizar todos los marcadores en cada rebuild.
  Set<Marker> _markersCache = const {};
  List<MapPoint>? _markersPoints;
  Map<String, BitmapDescriptor>? _markersIcons;
  String? _markersSelectedId;

  // Modo (oscuro o no) con el que se pintó el mapa por última vez.
  bool? _mapDark;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  /// El backend guarda restaurantes como 'Gastronomía' y hoteles como 'Hospedaje'.
  MapPointType _typeOf(Place place) {
    final cats = place.categories.map(normalizeText).toList();
    if (cats.any((c) => c.contains('hospedaje') || c.contains('hotel'))) {
      return MapPointType.hotel;
    }
    if (cats.any((c) => c.contains('gastronomia') || c.contains('restaurante'))) {
      return MapPointType.restaurant;
    }
    return MapPointType.place;
  }

  Future<void> _loadPoints() async {
    setState(() => _isLoadingPoints = true);
    try {
      final catalog = await PlacesRepository.instance.loadCatalog();
      if (!mounted) return;
      setState(() {
        _points = [
          for (final place in catalog.places)
            MapPoint(
              id: place.id,
              name: place.name,
              type: _typeOf(place),
              latitude: place.latitude,
              longitude: place.longitude,
              subtitle: [place.category, place.state].where((t) => t.isNotEmpty).join(' · '),
              imageUrl: place.imageUrl,
            ),
        ];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            action: SnackBarAction(label: 'Reintentar', onPressed: _loadPoints),
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoadingPoints = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isActive) _syncWithTheme();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al volver a la pestaña se ponen al día los íconos si el tema cambió.
    if (widget.isActive && !oldWidget.isActive) _syncWithTheme();
  }

  void _syncWithTheme() {
    final theme = Theme.of(context);
    if (_iconsBrightness != theme.brightness) {
      _iconsBrightness = theme.brightness;
      _buildMarkerIcons(theme.colorScheme, theme.brightness);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ───────────── Marcadores ─────────────

  Future<void> _buildMarkerIcons(ColorScheme colors, Brightness brightness) async {
    final cached = _iconCache[brightness];
    if (cached != null) {
      // Sin setState: se llama justo antes de un build, que ya usará estos íconos.
      _markerIcons = cached;
      return;
    }
    final icons = <String, BitmapDescriptor>{};
    for (final type in MapPointType.values) {
      for (final selected in [false, true]) {
        icons['${type.name}_$selected'] = await _renderMarker(
          icon: _outlinedIcon(type),
          color: type.color(colors),
          outline: colors.surface,
          selected: selected,
        );
      }
    }
    _iconCache[brightness] = icons;
    // Si el tema cambió mientras se dibujaban, estos íconos ya no son los actuales.
    if (mounted && _iconsBrightness == brightness) setState(() => _markerIcons = icons);
  }

  IconData _outlinedIcon(MapPointType type) {
    switch (type) {
      case MapPointType.place:
        return Icons.account_balance_outlined;
      case MapPointType.hotel:
        return Icons.hotel_outlined;
      case MapPointType.restaurant:
        return Icons.restaurant_outlined;
    }
  }

  /// Dibuja el marcador minimalista: ícono de línea sin fondo; al seleccionarlo,
  /// más grande y con un círculo tenue detrás.
  Future<BitmapDescriptor> _renderMarker({
    required IconData icon,
    required Color color,
    required Color outline,
    required bool selected,
  }) async {
    const ratio = 3.0;
    final logical = selected ? 52.0 : 36.0;
    final px = logical * ratio;
    final center = Offset(px / 2, px / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (selected) {
      canvas.drawCircle(center, px / 2, Paint()..color = color.withAlpha(60));
    }

    TextPainter glyph(TextStyle extra) => TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: (selected ? 30.0 : 24.0) * ratio,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
            ).merge(extra),
          ),
        )..layout();

    final halo = glyph(TextStyle(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * ratio
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
    ));
    final fill = glyph(TextStyle(color: color));
    final offset = center - Offset(fill.width / 2, fill.height / 2);
    halo.paint(canvas, offset);
    fill.paint(canvas, offset);

    final image = await recorder.endRecording().toImage(px.round(), px.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: ratio);
  }

  Set<Marker> _buildMarkers(List<MapPoint> points) {
    if (_markerIcons.isEmpty) return {};

    final selectedId = _selected?.id;
    if (identical(_markersIcons, _markerIcons) &&
        _markersSelectedId == selectedId &&
        _samePoints(_markersPoints, points)) {
      return _markersCache;
    }

    final markers = {
      for (final point in points)
        Marker(
          markerId: MarkerId(point.id),
          position: LatLng(point.latitude, point.longitude),
          anchor: const Offset(0.5, 0.5),
          icon: _markerIcons['${point.type.name}_${point.id == _selected?.id}']!,
          onTap: () => _selectPoint(point, moveMap: false),
        ),
    };

    _markersCache = markers;
    _markersPoints = points;
    _markersIcons = _markerIcons;
    _markersSelectedId = selectedId;
    return markers;
  }

  bool _samePoints(List<MapPoint>? a, List<MapPoint> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  // ───────────── Datos ─────────────

  List<MapPoint> get _visiblePoints {
    final query = normalizeText(_query);
    return _points.where((point) {
      // Si se busca por nombre, se encuentra aunque el filtro esté apagado.
      final matchesType = _activeTypes.contains(point.type) || query.isNotEmpty;
      final matchesQuery = query.isEmpty || normalizeText(point.name).contains(query);
      return matchesType && matchesQuery;
    }).toList();
  }

  double? _distanceTo(MapPoint point) {
    final user = _userLocation;
    if (user == null) return null;
    return Geolocator.distanceBetween(
      user.latitude,
      user.longitude,
      point.latitude,
      point.longitude,
    );
  }

  /// "450 m · 6 min" o "2.3 km · 29 min" (caminando a ~80 m por minuto).
  String? _distanceText(MapPoint point) {
    final meters = _distanceTo(point);
    if (meters == null) return null;
    final distance =
        meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
    final minutes = (meters / 80).ceil();
    final time = minutes < 60 ? '$minutes min' : '${(minutes / 60).toStringAsFixed(1)} h';
    return '$distance · $time';
  }

  // ───────────── Acciones ─────────────

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _selectPoint(MapPoint point, {bool moveMap = true}) {
    setState(() {
      if (_selected?.id != point.id) _clearRoute();
      _selected = point;
    });
    if (moveMap) _moveCameraTo(LatLng(point.latitude, point.longitude));
  }

  /// Centra el mapa en [target] sin alejarlo si el usuario ya estaba más cerca.
  Future<void> _moveCameraTo(LatLng target) async {
    final controller = _mapController;
    if (controller == null) return;
    final zoom = await controller.getZoomLevel();
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(target, math.max(zoom, _closeZoom)),
    );
  }

  void _toggleType(MapPointType type) {
    setState(() {
      if (!_activeTypes.remove(type)) _activeTypes.add(type);
      // Si el lugar seleccionado quedó oculto, se quita la selección.
      if (_selected != null && !_activeTypes.contains(_selected!.type)) {
        _selected = null;
        _clearRoute();
      }
    });
  }

  void _onSearchSubmitted(String _) {
    final results = _visiblePoints;
    if (results.isEmpty) {
      _showMessage('No encontramos resultados en el mapa');
      return;
    }
    FocusScope.of(context).unfocus();
    _selectPoint(results.first);
  }

  Future<void> _goToMyLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('Activa la ubicación de tu dispositivo');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Necesitamos tu ubicación para mostrarte lo que tienes cerca');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = location);
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, _closeZoom));
    } catch (_) {
      if (mounted) _showMessage('No pudimos obtener tu ubicación');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _clearRoute() {
    _route = const [];
    _routeMeters = null;
    _routeSeconds = null;
  }

  /// Traza la ruta dentro de la app (OpenStreetMap, sin llave de API).
  Future<void> _openDirections(MapPoint point) async {
    if (_routeLoading) return;
    if (_userLocation == null) {
      await _goToMyLocation();
      if (_userLocation == null) return;
    }
    setState(() => _routeLoading = true);
    try {
      final from = _userLocation!;
      final profile = _routeWalking ? 'routed-foot/route/v1/foot' : 'routed-car/route/v1/driving';
      final uri = Uri.parse(
        'https://routing.openstreetmap.de/$profile/'
        '${from.longitude},${from.latitude};${point.longitude},${point.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List? ?? const [];
      if (routes.isEmpty) {
        _showMessage('No encontramos una ruta hasta ese lugar');
        return;
      }
      final best = routes.first as Map<String, dynamic>;
      final coords = (best['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (!mounted) return;
      setState(() {
        _route = coords;
        _routeMeters = (best['distance'] as num).toDouble();
        _routeSeconds = (best['duration'] as num).toDouble();
      });
      _fitRoute(coords);
    } catch (_) {
      if (mounted) _showMessage('No se pudo trazar la ruta. Revisa tu conexión');
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  void _fitRoute(List<LatLng> points) {
    if (points.length < 2) return;
    var minLat = points.first.latitude, maxLat = minLat;
    var minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        80,
      ),
    );
  }

  void _setRouteMode(bool walking) {
    if (_routeWalking == walking) return;
    setState(() => _routeWalking = walking);
    final point = _selected;
    if (point != null && _route.isNotEmpty) _openDirections(point);
  }

  void _openDetails(MapPoint point) {
    // TODO: navegar a la pantalla de detalle del lugar.
    _showMessage('Detalle de "${point.name}" próximamente');
  }

  Future<void> _showNearbyList() async {
    final points = [..._visiblePoints];
    if (_userLocation != null) {
      points.sort((a, b) => _distanceTo(a)!.compareTo(_distanceTo(b)!));
    }

    final picked = await showModalBottomSheet<MapPoint>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _NearbyListSheet(points: points, distanceText: _distanceText),
    );
    if (picked != null) _selectPoint(picked);
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Con la pestaña oculta el mapa conserva el estilo anterior.
    if (widget.isActive || _mapDark == null) _mapDark = isDark;
    final points = _visiblePoints;
    final user = _userLocation;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultCenter,
                  zoom: _defaultZoom,
                ),
                onMapCreated: (controller) => _mapController = controller,
                polylines: {
                  if (_route.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: _route,
                      color: Theme.of(context).colorScheme.primary,
                      width: 6,
                      jointType: JointType.round,
                      startCap: Cap.roundCap,
                      endCap: Cap.roundCap,
                    ),
                },
                // '[]' es el estilo por defecto; con null el mapa no quitaba el oscuro.
                style: _mapDark! ? _darkMapStyle : '[]',
                markers: _buildMarkers(points),
                minMaxZoomPreference: const MinMaxZoomPreference(4, 19),
                myLocationEnabled: user != null,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onTap: (_) => FocusScope.of(context).unfocus(),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      children: [
                        _MapSearchBar(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          onSubmitted: _onSearchSubmitted,
                          onClear: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                        const SizedBox(height: 10),
                        _LayerChips(active: _activeTypes, onToggle: _toggleType),
                        if (_activeTypes.isEmpty && !_isLoadingPoints) ...[
                          const SizedBox(height: 10),
                          const _HintPill(text: 'Elige arriba qué quieres ver en el mapa'),
                        ],
                        if (_isLoadingPoints) ...[
                          const SizedBox(height: 10),
                          const _LoadingPill(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_route.isNotEmpty || _routeLoading)
                Positioned(
                  left: 16,
                  right: 80,
                  bottom: 16,
                  child: _RoutePanel(
                    loading: _routeLoading,
                    walking: _routeWalking,
                    meters: _routeMeters,
                    seconds: _routeSeconds,
                    onMode: _setRouteMode,
                    onClose: () => setState(_clearRoute),
                  ),
                ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _MyLocationButton(loading: _isLocating, onPressed: _goToMyLocation),
              ),
            ],
          ),
        ),
        _SelectedPointCard(
          point: _selected,
          distanceText: _selected == null ? null : _distanceText(_selected!),
          onSeeList: _showNearbyList,
          onEnableLocation: _goToMyLocation,
          onDirections: _openDirections,
          onDetails: _openDetails,
        ),
      ],
    );
  }
}

// ───────────── Widgets ─────────────

class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.loading,
    required this.walking,
    required this.meters,
    required this.seconds,
    required this.onMode,
    required this.onClose,
  });

  final bool loading;
  final bool walking;
  final double? meters;
  final double? seconds;
  final ValueChanged<bool> onMode;
  final VoidCallback onClose;

  String get _summary {
    if (meters == null || seconds == null) return 'Calculando ruta…';
    final km = meters! < 1000 ? '${meters!.round()} m' : '${(meters! / 1000).toStringAsFixed(1)} km';
    final min = (seconds! / 60).ceil();
    final time = min < 60 ? '$min min' : '${min ~/ 60} h ${min % 60} min';
    return '$km · $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            if (loading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(walking ? Icons.directions_walk_rounded : Icons.directions_car_rounded,
                  color: colors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Caminando',
              icon: Icon(Icons.directions_walk_rounded,
                  color: walking ? colors.primary : colors.onSurfaceVariant),
              onPressed: () => onMode(true),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'En auto',
              icon: Icon(Icons.directions_car_rounded,
                  color: !walking ? colors.primary : colors.onSurfaceVariant),
              onPressed: () => onMode(false),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Quitar ruta',
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 3,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(14),
      color: colors.surface,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar en el mapa...',
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.outline),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
              IconButton(
                tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: colors.primary,
                ),
                onPressed: () => themeController.toggle(theme.brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerChips extends StatelessWidget {
  const _LayerChips({required this.active, required this.onToggle});

  final Set<MapPointType> active;
  final ValueChanged<MapPointType> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MapPointType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = MapPointType.values[index];
          final isActive = active.contains(type);
          return FilterChip(
            selected: isActive,
            onSelected: (_) => onToggle(type),
            showCheckmark: false,
            avatar: Icon(
              type.icon,
              size: 18,
              color: isActive ? colors.onPrimary : type.color(colors),
            ),
            label: Text(type.label),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: isActive ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: colors.primary,
            backgroundColor: colors.surface,
            side: isActive ? BorderSide.none : BorderSide(color: colors.outline),
            shape: const StadiumBorder(),
            elevation: 2,
            shadowColor: Colors.black26,
          );
        },
      ),
    );
  }
}

class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outline),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Icon(Icons.my_location_rounded, color: colors.primary, semanticLabel: 'Mi ubicación'),
          ),
        ),
      ),
    );
  }
}

class _SelectedPointCard extends StatelessWidget {
  const _SelectedPointCard({
    required this.point,
    required this.distanceText,
    required this.onSeeList,
    required this.onEnableLocation,
    required this.onDirections,
    required this.onDetails,
  });

  final MapPoint? point;
  final String? distanceText;
  final VoidCallback onSeeList;
  final VoidCallback onEnableLocation;
  final ValueChanged<MapPoint> onDirections;
  final ValueChanged<MapPoint> onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = point;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      // Espacio extra abajo para que el botón "+" no tape los botones.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Cerca de ti', style: theme.textTheme.titleSmall)),
              TextButton(onPressed: onSeeList, child: const Text('Ver lista')),
            ],
          ),
          if (selected == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Toca un marcador para ver sus detalles.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            )
          else ...[
            Row(
              children: [
                _PointThumbnail(point: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      if (distanceText != null)
                        Row(
                          children: [
                            Icon(Icons.directions_walk_rounded, size: 15, color: colors.primary),
                            const SizedBox(width: 2),
                            Text(
                              distanceText!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      else
                        GestureDetector(
                          onTap: onEnableLocation,
                          child: Text(
                            'Activa tu ubicación para ver la distancia',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => onDirections(selected),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Cómo llegar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => onDetails(selected),
                    child: const Text('Ver detalles'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PointThumbnail extends StatelessWidget {
  const _PointThumbnail({required this.point, this.size = 58});

  final MapPoint point;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final placeholder = ColoredBox(
      color: isDark ? AppExtraColors.imagePlaceholderDark : AppExtraColors.imagePlaceholderLight,
      child: Center(child: Icon(point.type.icon, color: point.type.color(colors), size: size * 0.45)),
    );

    final url = point.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

class _NearbyListSheet extends StatelessWidget {
  const _NearbyListSheet({required this.points, required this.distanceText});

  final List<MapPoint> points;
  final String? Function(MapPoint) distanceText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Cerca de ti', style: theme.textTheme.titleMedium),
          ),
          Expanded(
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'No hay resultados con los filtros actuales.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: points.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final point = points[index];
                      final distance = distanceText(point);
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: _PointThumbnail(point: point, size: 48),
                        title: Text(point.name, style: theme.textTheme.titleSmall),
                        subtitle: Text(
                          distance == null ? point.subtitle : '${point.subtitle}\n$distance',
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        isThreeLine: distance != null,
                        onTap: () => Navigator.of(context).pop(point),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pastilla pequeña de "Cargando lugares..." sobre el mapa.
class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: Colors.black38,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Cargando lugares...', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
/// Estilo oscuro de Google Maps (se aplica cuando la app está en modo oscuro).
const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';
