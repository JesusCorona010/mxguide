import 'package:flutter/material.dart';

import '../screens/chat/chat_screen.dart';

/// Botón chico de Mictlan (una mini burbuja) que va junto al botón de modo
/// claro/oscuro en Explorar y en el Mapa. Abre el chat aunque la burbuja
/// flotante esté oculta, así el usuario nunca se queda sin acceso al asistente.
class ChatShortcutButton extends StatelessWidget {
  const ChatShortcutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: 'Abrir chat con Mictlan',
      onPressed: () => Navigator.of(context).push(ChatScreen.route()),
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: colors.tertiary, width: 2),
        ),
        child: Icon(Icons.auto_awesome_rounded, size: 18, color: colors.onPrimary),
      ),
    );
  }
}
