import 'package:flutter/material.dart';

import 'profile_widgets.dart';

/// Versión que se muestra en Perfil y en Acerca de.
/// Mantenerla igual que `version:` en pubspec.yaml.
const appVersion = '1.0.0';

/// Perfil > Acerca de MXGuide.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const AboutScreen());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de MXGuide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Image.asset('assets/images/mxguide_icono.png', height: 96, semanticLabel: 'Logo de MXGuide'),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'M'),
                TextSpan(text: 'X', style: TextStyle(color: colors.secondary)),
                const TextSpan(text: 'Guide'),
              ],
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            'México en tus manos · Versión $appVersion',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text(
            'MXGuide reúne los lugares turísticos de México para que descubras destinos, '
            'planees tu visita y lleves el registro de tu recorrido. Gana una insignia por '
            'cada estado que visites y conviértete en Jaguar Legendario.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Equipo'),
          const MenuSection(
            children: [
              _TeamTile(names: 'Jesús Corona · Giovanny Morgan', role: 'Frontend'),
              _TeamTile(names: 'Carlos Hernández · Marcos Cárcamo', role: 'Backend'),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'MXGuide',
                applicationVersion: appVersion,
              ),
              child: const Text('Licencias de código abierto'),
            ),
          ),
          Text(
            'Hecho en México',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.names, required this.role});

  final String names;
  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      leading: Icon(Icons.groups_rounded, color: colors.primary),
      title: Text(names, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(role, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
    );
  }
}
