import 'package:flutter/material.dart';

import '../utils/text_utils.dart';

/// Color de acento de la medalla (se toma del tema para respetar claro/oscuro).
enum MedalAccent { teal, red, ochre }

extension MedalAccentColors on MedalAccent {
  Color color(ColorScheme colors) => switch (this) {
        MedalAccent.teal => colors.primary,
        MedalAccent.red => colors.secondary,
        MedalAccent.ochre => colors.tertiary,
      };

  Color onColor(ColorScheme colors) => switch (this) {
        MedalAccent.teal => colors.onPrimary,
        MedalAccent.red => colors.onSecondary,
        MedalAccent.ochre => colors.onTertiary,
      };
}

/// Medalla que se gana al visitar por primera vez un lugar de un estado.
class StateAchievement {
  final String state;
  final String title;

  /// Frase que se muestra al desbloquearla.
  final String description;
  final IconData icon;
  final MedalAccent accent;

  const StateAchievement({
    required this.state,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
  });

  /// Imagen de la insignia en assets/badges, por ejemplo
  /// "Ciudad de México" → assets/badges/ciudad_de_mexico.webp.
  String get badgeAsset => 'assets/badges/${normalizeText(state).replaceAll(' ', '_')}.webp';
}

/// Rango del usuario según cuántos estados ha visitado.
class TravelerRank {
  final String name;
  final int minStates;
  final IconData icon;

  const TravelerRank({required this.name, required this.minStates, required this.icon});
}