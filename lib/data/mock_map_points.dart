import '../models/map_point.dart';

/// Puntos de prueba alrededor del centro de Puebla.
/// TODO(backend): reemplazar por GET /places/nearby (y hoteles/restaurantes).
const mockMapPoints = <MapPoint>[
  MapPoint(
    id: 'p1',
    name: 'Zócalo de Puebla',
    type: MapPointType.place,
    latitude: 19.0433,
    longitude: -98.1981,
    subtitle: 'Histórico · Puebla',
  ),
  MapPoint(
    id: 'p2',
    name: 'Biblioteca Palafoxiana',
    type: MapPointType.place,
    latitude: 19.0426,
    longitude: -98.1972,
    subtitle: 'Histórico · Puebla',
  ),
  MapPoint(
    id: 'p3',
    name: 'Barrio del Artista',
    type: MapPointType.place,
    latitude: 19.0453,
    longitude: -98.1937,
    subtitle: 'Cultural · Puebla',
  ),
  MapPoint(
    id: 'p4',
    name: 'Callejón de los Sapos',
    type: MapPointType.place,
    latitude: 19.0405,
    longitude: -98.1935,
    subtitle: 'Histórico · Puebla',
  ),
  MapPoint(
    id: 'p5',
    name: 'Templo de Santo Domingo',
    type: MapPointType.place,
    latitude: 19.0474,
    longitude: -98.1978,
    subtitle: 'Histórico · Puebla',
  ),
  MapPoint(
    id: 'h1',
    name: 'Hotel Casona del Centro',
    type: MapPointType.hotel,
    latitude: 19.0447,
    longitude: -98.2004,
    subtitle: 'Hotel · 4 estrellas',
  ),
  MapPoint(
    id: 'h2',
    name: 'Hotel Portal Poblano',
    type: MapPointType.hotel,
    latitude: 19.0418,
    longitude: -98.1956,
    subtitle: 'Hotel · 3 estrellas',
  ),
  MapPoint(
    id: 'r1',
    name: 'Fonda La Talavera',
    type: MapPointType.restaurant,
    latitude: 19.0440,
    longitude: -98.1955,
    subtitle: 'Cocina poblana',
  ),
  MapPoint(
    id: 'r2',
    name: 'Mole y Tradición',
    type: MapPointType.restaurant,
    latitude: 19.0411,
    longitude: -98.1990,
    subtitle: 'Cocina mexicana',
  ),
];