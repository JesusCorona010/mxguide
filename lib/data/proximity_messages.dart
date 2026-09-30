import 'dart:math';

/// Frases para el aviso de "estás cerca de un lugar", separadas por
/// categoría para que no se sienta siempre el mismo mensaje. Si la
/// categoría del lugar no tiene frases propias, se usa [_defaultMessages].
///
/// TODO: si se agregan categorías nuevas a mockPlaces, agregar aquí sus
/// propias frases (o se van a la genérica).
const Map<String, List<String>> _messagesByCategory = {
  'Histórico': [
    'La historia te espera aquí. ¿Le echamos un vistazo?',
    'Este lugar tiene siglos de historia, justo enfrente de ti.',
  ],
  'Natural': [
    'Un poco de naturaleza no le cae mal a nadie. ¿Nos acercamos?',
    'Aire fresco y buena vista, a unos pasos de aquí.',
  ],
  'Playa': [
    'Arena y mar cerquita. ¿Se antoja una parada?',
    'Esa playa no se visita sola. ¡Vamos!',
  ],
  'Pueblo Mágico': [
    'Un Pueblo Mágico te queda a la vuelta. Vale la pena el desvío.',
    'Calles con encanto cerca de ti, ideal para una caminata.',
  ],
};

/// Se usan cuando la categoría del lugar no está en el mapa de arriba.
const List<String> _defaultMessages = [
  'Es un buen momento para visitarlo.',
];

final _random = Random();

/// Regresa una frase al azar para la categoría del lugar (o una genérica
/// si esa categoría todavía no tiene frases propias).
String proximityMessageFor(String category) {
  final options = _messagesByCategory[category] ?? _defaultMessages;
  return options[_random.nextInt(options.length)];
}
