import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import 'profile_widgets.dart';

/// Perfil > Información de la cuenta: datos que regresa GET /auth/me.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const AccountScreen());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Información de la cuenta')),
      body: ListenableBuilder(
        listenable: AuthService.instance,
        builder: (context, _) {
          final user = AuthService.instance.user;
          if (user == null) return const Center(child: CircularProgressIndicator());

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(child: UserAvatar(initials: user.initials, size: 84)),
              const SizedBox(height: 24),
              MenuSection(
                children: [
                  _InfoTile(icon: Icons.person_outline_rounded, label: 'Nombre', value: user.name),
                  _InfoTile(
                    icon: Icons.mail_outline_rounded,
                    label: 'Correo electrónico',
                    value: user.email,
                    copyable: true,
                  ),
                  _InfoTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Miembro desde',
                    value: user.createdAt == null ? '—' : formatLongDate(user.createdAt!),
                  ),
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Tipo de cuenta',
                    value: user.isAdmin ? 'Administrador' : 'Viajero',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // TODO(backend): agregar PATCH /auth/me para editar nombre y contraseña.
                      'Pronto podrás cambiar tu nombre y tu contraseña desde aquí.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      ),
      subtitle: Text(value, style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurface)),
      trailing: copyable
          ? IconButton(
              tooltip: 'Copiar',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Correo copiado')));
              },
            )
          : null,
    );
  }
}
