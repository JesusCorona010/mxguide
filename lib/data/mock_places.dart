import '../models/place.dart';

/// Datos de prueba mientras se conecta la API.
/// TODO(backend): reemplazar por los lugares que regrese la API.
const mockPlaces = <Place>[
  Place(
    id: '1',
    name: 'Zócalo de la Ciudad de México',
    state: 'Ciudad de México',
    category: 'Histórico',
    latitude: 19.4326,
    longitude: -99.1332,
  ),
  Place(
    id: '2',
    name: 'Bosque de Chapultepec',
    state: 'Ciudad de México',
    category: 'Natural',
    latitude: 19.4204,
    longitude: -99.1813,
  ),
  Place(
    id: '3',
    name: 'Zona Arqueológica de Teotihuacán',
    state: 'Estado de México',
    category: 'Histórico',
    latitude: 19.6925,
    longitude: -98.8438,
  ),
  Place(
    id: '4',
    name: 'Playa Paraíso, Tulum',
    state: 'Quintana Roo',
    category: 'Playa',
    latitude: 20.2114,
    longitude: -87.4654,
  ),
  Place(
    id: '5',
    name: 'Chichén Itzá',
    state: 'Yucatán',
    category: 'Histórico',
    latitude: 20.6843,
    longitude: -88.5678,
  ),
  Place(
    id: '6',
    name: 'Barrancas del Cobre',
    state: 'Chihuahua',
    category: 'Natural',
    latitude: 27.5261,
    longitude: -107.6862,
  ),
  Place(
    id: '7',
    name: 'San Miguel de Allende',
    state: 'Guanajuato',
    category: 'Pueblo Mágico',
    latitude: 20.9153,
    longitude: -100.7444,
  ),
  Place(
    id: '8',
    name: 'Cholula',
    state: 'Puebla',
    category: 'Pueblo Mágico',
    latitude: 19.0631,
    longitude: -98.3037,
  ),
];

const placeCategories = <String>['Todas', 'Histórico', 'Natural', 'Playa', 'Pueblo Mágico'];

const mexicanStates = <String>[
  'Aguascalientes', 'Baja California', 'Baja California Sur', 'Campeche',
  'Chiapas', 'Chihuahua', 'Ciudad de México', 'Coahuila', 'Colima', 'Durango',
  'Estado de México', 'Guanajuato', 'Guerrero', 'Hidalgo', 'Jalisco',
  'Michoacán', 'Morelos', 'Nayarit', 'Nuevo León', 'Oaxaca', 'Puebla',
  'Querétaro', 'Quintana Roo', 'San Luis Potosí', 'Sinaloa', 'Sonora',
  'Tabasco', 'Tamaulipas', 'Tlaxcala', 'Veracruz', 'Yucatán', 'Zacatecas',
];