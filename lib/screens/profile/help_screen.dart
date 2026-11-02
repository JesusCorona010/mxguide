import 'package:flutter/material.dart';

import 'profile_widgets.dart';

/// Perfil > Ayuda: preguntas frecuentes.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const HelpScreen());

  static const _faqs = <(String, String)>[
    (
      '¿Cómo gano insignias?',
      'Cada estado de México tiene su propia insignia. La desbloqueas la primera vez que '
          'visitas un lugar turístico de ese estado. Entre más estados conozcas, más sube tu rango.',
    ),
    (
      '¿Qué son los rangos?',
      'Tu rango de viajero depende de cuántos estados has visitado: empiezas como Turista '
          'Curioso y, al completar los 32 estados, llegas a Jaguar Legendario.',
    ),
    (
      '¿Cómo guardo un lugar en favoritos?',
      'Toca el corazón en la tarjeta de cualquier lugar en Explorar. Los encuentras en '
          'Perfil > Mis favoritos. Necesitas haber iniciado sesión.',
    ),
    (
      '¿Para qué sirven los avisos de lugares cercanos?',
      'Si los activas en Perfil, la app usa tu ubicación para avisarte cuando estás cerca '
          'de una atracción. Puedes apagarlos cuando quieras.',
    ),
    (
      'La app tarda en cargar los lugares, ¿es normal?',
      'Sí, la primera vez del día puede tardar hasta un minuto mientras el servidor se '
          'despierta. Después carga rápido.',
    ),
    (
      '¿Puedo usar la app sin cuenta?',
      'Sí, con el modo invitado puedes explorar los lugares y el mapa. Para guardar favoritos '
          'y reseñas necesitas crear una cuenta.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionTitle('Preguntas frecuentes'),
          MenuSection(
            children: [
              for (final (question, answer) in _faqs)
                Theme(
                  // Quita las líneas que ExpansionTile dibuja al abrirse.
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: colors.primary,
                    collapsedIconColor: colors.onSurfaceVariant,
                    title: Text(
                      question,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        answer,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
