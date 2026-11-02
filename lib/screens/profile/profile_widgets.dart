import 'package:flutter/material.dart';

/// Piezas visuales que comparten las pantallas de Perfil.

const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "22 de octubre de 2026".
String formatLongDate(DateTime date) => '${date.day} de ${_months[date.month - 1]} de ${date.year}';

/// "octubre de 2026".
String formatMonthYear(DateTime date) => '${_months[date.month - 1]} de ${date.year}';

/// Círculo con las iniciales del usuario.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.initials, this.size = 64});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: colors.tertiary, width: size * 0.05),
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.onPrimary,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

/// Título pequeño en mayúsculas arriba de cada grupo del menú.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Tarjeta que agrupa varias opciones del menú, separadas por una línea.
class MenuSection extends StatelessWidget {
  const MenuSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: colors.outline),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Una opción del menú: ícono, texto, subtítulo opcional y flecha.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Color del ícono y del texto (por ejemplo rojo para "Cerrar sesión").
  final Color? color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = color ?? colors.primary;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: accent.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: accent),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: color ?? colors.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
      trailing: trailing ??
          (showChevron ? Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant) : null),
    );
  }
}

/// Etiqueta "Pronto" para opciones que aún no están listas.
class SoonTag extends StatelessWidget {
  const SoonTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.tertiary.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Pronto',
        style: theme.textTheme.labelSmall?.copyWith(color: colors.tertiary, fontWeight: FontWeight.w800),
      ),
    );
  }
}
