import 'api_client.dart';

/// Recuperación de contraseña (rutas /account-recovery del backend).
///
/// TODO(backend): hoy el backend genera un token largo y no envía correo. Se
/// va a cambiar para usar un código de 4 dígitos enviado al correo del usuario.
/// Cuando cambien las rutas o los campos, solo hay que ajustar este archivo.
/// Nunca se debe usar el `devToken` que hoy devuelve /request: es solo de pruebas.
class AccountRecoveryService {
  AccountRecoveryService._();
  static final instance = AccountRecoveryService._();

  /// Longitud del código que escribe el usuario.
  static const codeLength = 4;

  final _api = ApiClient.instance;

  /// Pide que se envíe el código al correo. El backend responde lo mismo
  /// exista o no la cuenta (para no revelar qué correos están registrados).
  Future<void> requestCode(String email) async {
    await _api.post('/account-recovery/request', body: {'email': email});
  }

  /// Cambia la contraseña con el código recibido.
  ///
  /// TODO(backend): hoy la ruta recibe { token, newPassword }. [email] se
  /// recibe para cuando el código de 4 dígitos necesite ir junto al correo.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post(
      '/account-recovery/reset',
      body: {'token': code, 'newPassword': newPassword},
    );
  }
}
