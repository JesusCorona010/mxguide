import 'package:flutter/material.dart';
import '../models/achievement.dart';

/// Las 32 medallas, una por estado.
const stateAchievements = <StateAchievement>[
  StateAchievement(
    state: 'Aguascalientes',
    title: 'Espíritu de la Feria',
    description: 'Llegaste a la tierra de la Feria de San Marcos. ¡Que empiece la fiesta!',
    icon: Icons.celebration_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Baja California',
    title: 'Viento del Pacífico',
    description: 'Sentiste la brisa del Pacífico y el sabor del Valle de Guadalupe.',
    icon: Icons.air_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Baja California Sur',
    title: 'Susurro de Ballenas',
    description: 'Donde el desierto besa el mar. Las ballenas ya saben tu nombre.',
    icon: Icons.water_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Campeche',
    title: 'Guardián de la Muralla',
    description: 'Recorriste la ciudad amurallada. Ningún pirata se atreve contigo.',
    icon: Icons.fort_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Chiapas',
    title: 'Voz de la Selva',
    description: 'La selva te dio la bienvenida entre cascadas y ciudades mayas.',
    icon: Icons.forest_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Chihuahua',
    title: 'Titán de las Barrancas',
    description: 'Te asomaste a las barrancas más profundas. Nada te detiene.',
    icon: Icons.terrain_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Ciudad de México',
    title: 'Corazón de Tenochtitlan',
    description: 'Caminaste sobre la gran Tenochtitlan. El corazón de México late contigo.',
    icon: Icons.location_city_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Coahuila',
    title: 'Alma del Desierto',
    description: 'Dunas, viñedos y dinosaurios. El desierto te reconoce como suyo.',
    icon: Icons.wb_twilight_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Colima',
    title: 'Fuego del Volcán',
    description: 'Estuviste a los pies del Volcán de Fuego. Tu espíritu arde más que nunca.',
    icon: Icons.local_fire_department_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Durango',
    title: 'Sombra del Oeste',
    description: 'Pisaste la tierra del cine western. Eres la estrella de esta película.',
    icon: Icons.movie_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Estado de México',
    title: 'Guardián del Sol',
    description: 'Subiste al lugar donde nacieron los dioses. El Sol te guarda.',
    icon: Icons.wb_sunny_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Guanajuato',
    title: 'Leyenda del Callejón',
    description: 'Entre callejones y leyendas, ahora tú también eres parte de la historia.',
    icon: Icons.auto_stories_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Guerrero',
    title: 'Sol del Pacífico',
    description: 'Clavados, playas y atardeceres dorados. El Pacífico brilla por ti.',
    icon: Icons.beach_access_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Hidalgo',
    title: 'Espíritu de los Prismas',
    description: 'Descubriste los prismas basálticos y el sabor del paste. ¡Brillas!',
    icon: Icons.diamond_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Jalisco',
    title: 'Corazón de Mariachi',
    description: 'Tierra de mariachi y tequila. Tu corazón ya canta en jalisciense.',
    icon: Icons.music_note_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Michoacán',
    title: 'Alas de Monarca',
    description: 'Millones de mariposas monarca volaron para recibirte. Eres parte de su viaje.',
    icon: Icons.emoji_nature_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Morelos',
    title: 'Eterna Primavera',
    description: 'Llegaste a la tierra de la eterna primavera. Aquí siempre florece algo.',
    icon: Icons.local_florist_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Nayarit',
    title: 'Espíritu Wixárika',
    description: 'Los colores wixárikas y las playas de la Riviera Nayarit ya son tuyos.',
    icon: Icons.palette_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Nuevo León',
    title: 'Leyenda Regia',
    description: 'Conquistaste la Sultana del Norte a la sombra del Cerro de la Silla.',
    icon: Icons.landscape_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Oaxaca',
    title: 'Espíritu Guelaguetza',
    description: 'Mezcal, mole y Guelaguetza. Oaxaca te entregó su alma.',
    icon: Icons.festival_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Puebla',
    title: 'Alma de Talavera',
    description: 'Pisaste tierra poblana por primera vez. Ahora el mole y la Talavera corren por tus venas.',
    icon: Icons.color_lens_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Querétaro',
    title: 'Guardián de la Peña',
    description: 'Estuviste ante la Peña de Bernal, uno de los monolitos más grandes del mundo.',
    icon: Icons.filter_hdr_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Quintana Roo',
    title: 'Alma Caribeña',
    description: 'Arena blanca y mar turquesa. El Caribe mexicano ahora vive en ti.',
    icon: Icons.waves_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'San Luis Potosí',
    title: 'Guardián de la Huasteca',
    description: 'Cascadas turquesa y jardines surrealistas. La Huasteca te abrió sus puertas.',
    icon: Icons.park_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Sinaloa',
    title: 'Perla del Pacífico',
    description: 'Mazatlán y su malecón te consintieron. Eres la nueva perla del Pacífico.',
    icon: Icons.set_meal_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Sonora',
    title: 'Forjado por el Sol',
    description: 'Carne asada, desierto y Mar de Cortés. Sonora te forjó con su sol.',
    icon: Icons.whatshot_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Tabasco',
    title: 'Guardián Olmeca',
    description: 'Estuviste frente a frente con las cabezas olmecas. La cultura madre te saluda.',
    icon: Icons.face_rounded,
    accent: MedalAccent.ochre,
  ),
  StateAchievement(
    state: 'Tamaulipas',
    title: 'Vigía del Golfo',
    description: 'Recorriste playas y sierras del Golfo. Nada escapa de tu mirada.',
    icon: Icons.sailing_rounded,
    accent: MedalAccent.teal,
  ),
  StateAchievement(
    state: 'Tlaxcala',
    title: 'Guerrero Tlaxcalteca',
    description: 'Tierra de guerreros que nunca se rindieron. Ahora eres uno de ellos.',
    icon: Icons.shield_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Veracruz',
    title: 'Son Jarocho',
    description: 'Al ritmo del son jarocho y con un lechero en la mano. ¡Veracruz te baila!',
    icon: Icons.queue_music_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Yucatán',
    title: 'Guardián del Cenote',
    description: 'Te sumergiste en el mundo maya. Los cenotes guardan tu secreto.',
    icon: Icons.water_drop_rounded,
    accent: MedalAccent.red,
  ),
  StateAchievement(
    state: 'Zacatecas',
    title: 'Corazón de Plata',
    description: 'La ciudad de cantera rosa y minas de plata. Brillas como su plata.',
    icon: Icons.star_rounded,
    accent: MedalAccent.ochre,
  ),
];

/// Rangos del viajero, de menor a mayor.
const travelerRanks = <TravelerRank>[
  TravelerRank(name: 'Turista Curioso', minStates: 0, icon: Icons.explore_rounded),
  TravelerRank(name: 'Viajero de Caminos', minStates: 2, icon: Icons.hiking_rounded),
  TravelerRank(name: 'Explorador del Sol', minStates: 5, icon: Icons.wb_sunny_rounded),
  TravelerRank(name: 'Trotamundos Azteca', minStates: 10, icon: Icons.public_rounded),
  TravelerRank(name: 'Guardián de México', minStates: 16, icon: Icons.shield_rounded),
  TravelerRank(name: 'Leyenda Nacional', minStates: 24, icon: Icons.auto_awesome_rounded),
  TravelerRank(name: 'Jaguar Legendario', minStates: 32, icon: Icons.pets_rounded),
];

TravelerRank rankFor(int visitedStates) =>
    travelerRanks.lastWhere((rank) => visitedStates >= rank.minStates);

/// El siguiente rango, o null si ya es Jaguar Legendario.
TravelerRank? nextRankFor(int visitedStates) {
  for (final rank in travelerRanks) {
    if (rank.minStates > visitedStates) return rank;
  }
  return null;
}