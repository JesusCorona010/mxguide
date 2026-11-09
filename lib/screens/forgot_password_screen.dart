import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/account_recovery_service.dart';
import '../services/api_client.dart';

enum _Step { email, code, done }

/// Recuperar contraseña: correo → código de 4 dígitos + nueva contraseña → listo.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Correo que el usuario ya había escrito en el login.
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _cooldownSeconds = 60;

  final _service = AccountRecoveryService.instance;
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail ?? '');
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;
  bool _busy = false;
  bool _obscure = true;
  String? _codeError;
  int _cooldown = 0;
  Timer? _timer;

  String get _email => _emailController.text.trim();

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ───────────── Validaciones ─────────────

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo electrónico';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) return 'Ingresa un correo válido';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu nueva contraseña';
    if (value.length < 6) return 'Debe tener al menos 6 caracteres';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
    if (value != _passwordController.text) return 'Las contraseñas no coinciden';
    return null;
  }

  // ───────────── Acciones ─────────────

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!resend && !_emailFormKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      await _service.requestCode(_email);
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _step = _Step.code;
        _codeError = null;
      });
      _startCooldown();
      if (resend) _showMessage('Te enviamos un código nuevo');
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    final codeOk = _codeController.text.length == AccountRecoveryService.codeLength;
    setState(() => _codeError = codeOk ? null : 'Escribe el código de 4 dígitos');
    final passwordsOk = _passwordFormKey.currentState!.validate();
    if (!codeOk || !passwordsOk) return;

    setState(() => _busy = true);
    try {
      await _service.resetPassword(
        email: _email,
        code: _codeController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _step = _Step.done);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  void _goBack() {
    if (_step == _Step.code) {
      setState(() => _step = _Step.email);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: colors.error,
          content: Text(message, style: TextStyle(color: colors.onError)),
        ),
      );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _step != _Step.code,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (_step != _Step.done)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
                      child: IconButton(
                        tooltip: 'Regresar',
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: _busy ? null : _goBack,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 52),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: switch (_step) {
                            _Step.email => _buildEmailStep(),
                            _Step.code => _buildCodeStep(),
                            _Step.done => _buildDoneStep(),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeader(
            icon: Icons.lock_reset_rounded,
            title: '¿Olvidaste tu contraseña?',
            subtitle: [
              TextSpan(
                text: 'Escribe el correo de tu cuenta y te enviaremos un código de 4 dígitos '
                    'para crear una nueva.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            validator: _validateEmail,
            onFieldSubmitted: (_) => _sendCode(),
            decoration: const InputDecoration(
              hintText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _busy ? null : _sendCode,
            child: _busy ? _Spinner(color: colors.onPrimary) : const Text('Enviar código'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '¿Te registraste con Google? Entra con el botón '),
                        TextSpan(
                          text: 'Continuar con Google',
                          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
                        ),
                        const TextSpan(text: ': tu cuenta no usa contraseña.'),
                      ],
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Volver a iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    return Form(
      key: _passwordFormKey,
      child: Column(
        key: const ValueKey('code'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            icon: Icons.mark_email_read_outlined,
            title: 'Revisa tu correo',
            subtitle: [
              const TextSpan(text: 'Enviamos un código de 4 dígitos a '),
              TextSpan(
                text: _email,
                style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
              ),
              const TextSpan(text: '. Escríbelo y elige tu nueva contraseña.'),
            ],
          ),
          const SizedBox(height: 24),
          _CodeInput(
            controller: _codeController,
            focusNode: _codeFocus,
            length: AccountRecoveryService.codeLength,
            hasError: _codeError != null,
            enabled: !_busy,
            onChanged: (_) => setState(() => _codeError = null),
          ),
          if (_codeError != null) ...[
            const SizedBox(height: 8),
            Text(
              _codeError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          Center(
            child: TextButton(
              onPressed: (_busy || _cooldown > 0) ? null : () => _sendCode(resend: true),
              child: Text(
                _cooldown > 0
                    ? 'Reenviar código en ${_cooldown ~/ 60}:${(_cooldown % 60).toString().padLeft(2, '0')}'
                    : 'Reenviar código',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _passwordField(
            controller: _passwordController,
            hint: 'Nueva contraseña',
            validator: _validatePassword,
            action: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _passwordField(
            controller: _confirmController,
            hint: 'Confirmar contraseña',
            validator: _validateConfirm,
            action: TextInputAction.done,
            onSubmitted: (_) => _resetPassword(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Rule(ok: password.length >= 6, text: 'Mínimo 6 caracteres'),
              const SizedBox(width: 16),
              _Rule(ok: confirm.isNotEmpty && confirm == password, text: 'Coinciden'),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _resetPassword,
            child: _busy ? _Spinner(color: colors.onPrimary) : const Text('Cambiar contraseña'),
          ),
        ],
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    required TextInputAction action,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_busy,
      obscureText: _obscure,
      textInputAction: action,
      autofillHints: const [AutofillHints.newPassword],
      validator: validator,
      onChanged: (_) => setState(() {}),
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }

  Widget _buildDoneStep() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      key: const ValueKey('done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withAlpha(46),
            ),
            child: Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primary),
                child: Icon(Icons.check_rounded, size: 52, color: colors.onPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          '¡Contraseña actualizada!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Ya puedes iniciar sesión con tu nueva contraseña.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Iniciar sesión'),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final List<InlineSpan> subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primary.withAlpha(41)),
          child: Icon(icon, size: 38, color: colors.primary),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: subtitle),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
        ),
      ],
    );
  }
}

/// Casillas del código. Un solo campo invisible recibe el teclado numérico y
/// las casillas solo muestran lo que se ha escrito.
class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? focusNode.requestFocus : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              final active = math.min(text.length, length - 1);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 58,
                        height: 66,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasError
                                ? colors.error
                                : (focusNode.hasFocus && i == active)
                                    ? colors.primary
                                    : colors.outline,
                            width: (hasError || (focusNode.hasFocus && i == active)) ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          i < text.length ? text[i] : '',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 240,
              height: 66,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                onChanged: onChanged,
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = ok ? colors.primary : colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined, size: 15, color: color),
        const SizedBox(width: 5),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    );
  }
}
