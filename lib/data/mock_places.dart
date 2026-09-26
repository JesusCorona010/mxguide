import '../models/place.dart';

/// Datos de prueba mientras se conecta la API.
/// TODO(backend): reemplazar por los lugares que regrese la API.
const mockPlaces = <Place>[
  Place(id: '1', name: 'Zócalo de la Ciudad de México', state: 'Ciudad de México', category: 'Histórico'),
  Place(id: '2', name: 'Bosque de Chapultepec', state: 'Ciudad de México', category: 'Natural'),
  Place(id: '3', name: 'Zona Arqueológica de Teotihuacán', state: 'Estado de México', category: 'Histórico'),
  Place(id: '4', name: 'Playa Paraíso, Tulum', state: 'Quintana Roo', category: 'Playa'),
  Place(id: '5', name: 'Chichén Itzá', state: 'Yucatán', category: 'Histórico'),
  Place(id: '6', name: 'Barrancas del Cobre', state: 'Chihuahua', category: 'Natural'),
  Place(id: '7', name: 'San Miguel de Allende', state: 'Guanajuato', category: 'Pueblo Mágico'),
  Place(id: '8', name: 'Cholula', state: 'Puebla', category: 'Pueblo Mágico'),
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