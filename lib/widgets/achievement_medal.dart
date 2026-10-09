import 'package:flutter/material.dart';

import '../models/achievement.dart';

/// Medalla circular. Si está bloqueada se ve gris con candado.
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

  static const _lockedBgLight = Color(0xFFE4E8E6);
  static const _lockedBgDark = Color(0xFF262B2B);
  static const _lockedIconLight = Color(0xFF9AA8AF);
  static const _lockedIconDark = Color(0xFF5F6B70);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = achievement.accent.color(colors);

    final background = unlocked ? accent : (isDark ? _lockedBgDark : _lockedBgLight);
    final iconColor = unlocked ? Colors.white : (isDark ? _lockedIconDark : _lockedIconLight);
    final badgeSize = size * 0.34;

    return Semantics(
      label: unlocked
          ? 'Medalla ${achievement.title}, desbloqueada'
          : 'Medalla ${achievement.title}, bloqueada',
      child: SizedBox(
        width: size + 6,
        height: size + 6,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: unlocked ? colors.tertiary : colors.outline,
                  width: size * 0.05,
                ),
                boxShadow: unlocked
                    ? [BoxShadow(color: accent.withAlpha(90), blurRadius: size * 0.18, offset: Offset(0, size * 0.06))]
                    : null,
              ),
              child: Icon(
                unlocked ? achievement.icon : Icons.lock_rounded,
                size: size * 0.46,
                color: iconColor,
              ),
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