import 'package:flutter/material.dart';

import '../models/achievement.dart';

/// Insignia circular de un estado.
///
/// Desbloqueada: la ilustración a color con una estrella.
/// Bloqueada: la misma ilustración en gris, apagada y con candado, para que
/// el usuario vea qué le falta por descubrir.
class AchievementMedal extends StatelessWidget {
  const AchievementMedal({
    super.key,
    required this.achievement,
    required this.unlocked,
    this.size = 60,
  });

  final StateAchievement achievement;
  final bool unlocked;
  final double size;

  /// Matriz para pasar la imagen a escala de grises.
  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = achievement.accent.color(colors);
    final badgeSize = size * 0.34;

    // Se decodifica al tamaño real en pantalla para no gastar memoria.
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();

    Widget image = Image.asset(
      achievement.badgeAsset,
      width: size,
      height: size,
      cacheWidth: cacheSize,
      fit: BoxFit.cover,
      // Si falta la imagen, se usa el ícono de antes para no romper la pantalla.
      errorBuilder: (context, error, stackTrace) => _FallbackMedal(
        icon: achievement.icon,
        color: accent,
        size: size,
      ),
    );

    if (!unlocked) {
      image = Opacity(
        opacity: isDark ? 0.35 : 0.45,
        child: ColorFiltered(colorFilter: _grayscale, child: image),
      );
    }

    return Semantics(
      label: unlocked
          ? 'Insignia ${achievement.title}, desbloqueada'
          : 'Insignia ${achievement.title}, bloqueada',
      image: true,
      child: SizedBox(
        width: size + 6,
        height: size + 6,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: accent.withAlpha(90),
                          blurRadius: size * 0.18,
                          offset: Offset(0, size * 0.06),
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(child: SizedBox(width: size, height: size, child: image)),
            ),
            if (!unlocked)
              Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  color: colors.surface.withAlpha(230),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outline),
                ),
                child: Icon(Icons.lock_rounded, size: size * 0.22, color: colors.onSurfaceVariant),
              ),
            if (unlocked)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: colors.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  child: Icon(Icons.star_rounded, size: badgeSize * 0.65, color: colors.onTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FallbackMedal extends StatelessWidget {
  const _FallbackMedal({required this.icon, required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(child: Icon(icon, size: size * 0.46, color: Colors.white)),
    );
  }
}
