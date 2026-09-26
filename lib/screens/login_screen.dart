import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  bool get _isBusy => _isLoading || _isGoogleLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ───────────── Validaciones ─────────────

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo electrónico';
    final isValid = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);
    if (!isValid) return 'Ingresa un correo válido';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
    if (value.length < 6) return 'Debe tener al menos 6 caracteres';
    return null;
  }

  // ───────────── Acciones ─────────────

  Future<void> _login() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    // if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO(backend): aquí va la llamada real de autenticación.
    // Por ahora simulamos una espera y navegamos directo.
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _isLoading = false);
    _goToHome();
  }

  Future<void> _loginWithGoogle() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoading = true);

    // TODO(backend): aquí va el flujo de Google Sign-In.
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    _goToHome();
  }

  void _goToHome() => Navigator.of(context).pushReplacementNamed('/home');

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature estará disponible pronto')));
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Íconos de la barra de estado claros u oscuros según el tema.
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  // Centra el contenido verticalmente, pero permite scroll
                  // cuando aparece el teclado.
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Header(),
                              const SizedBox(height: 32),
                              _buildEmailField(),
                              const SizedBox(height: 14),
                              _buildPasswordField(),
                              _buildForgotPassword(),
                              const SizedBox(height: 8),
                              _buildLoginButton(),
                              const SizedBox(height: 24),
                              const _OrDivider(),
                              const SizedBox(height: 24),
                              _buildGoogleButton(),
                              const SizedBox(height: 28),
                              _buildRegisterRow(),
                              _buildGuestButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      enabled: !_isBusy,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      validator: _validateEmail,
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
      decoration: const InputDecoration(
        hintText: 'Correo electrónico',
        prefixIcon: Icon(Icons.mail_outline_rounded),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      enabled: !_isBusy,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      validator: _validatePassword,
      onFieldSubmitted: (_) => _login(),
      decoration: InputDecoration(
        hintText: 'Contraseña',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => _showComingSoon('Recuperar contraseña'),
        child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildLoginButton() {
    final colors = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: _login,
      child: _isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.onPrimary),
            )
          : const Text('Iniciar sesión'),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _loginWithGoogle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isGoogleLoading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Image.asset(
              'assets/images/google_logo.png',
              width: 22,
              height: 22,
              // Si aún no agregas el logo de Google, muestra un ícono temporal.
              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, size: 28),
            ),
          const SizedBox(width: 12),
          const Text('Continuar con Google'),
        ],
      ),
    );
  }

  Widget _buildRegisterRow() {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('¿No tienes cuenta?', style: TextStyle(color: colors.onSurfaceVariant)),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colors.secondary),
          // TODO: cambiar por Navigator.pushNamed(context, '/register') cuando exista.
          onPressed: () => _showComingSoon('El registro'),
          child: const Text('Regístrate'),
        ),
      ],
    );
  }

  Widget _buildGuestButton() {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
      onPressed: _isBusy ? null : _goToHome,
      child: const Text(
        'Explorar como invitado',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

/// Logo del jaguar + nombre + eslogan.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Image.asset(
          'assets/images/mxguide_icono.png',
          height: 110,
          semanticLabel: 'Logo de MXGuide',
        ),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'M'),
              TextSpan(text: 'X', style: TextStyle(color: colors.secondary)),
              const TextSpan(text: 'Guide'),
            ],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'México en tus manos',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Línea divisoria con el texto "o continúa con".
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: colors.outline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'o continúa con',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: colors.outline)),
      ],
    );
  }
}