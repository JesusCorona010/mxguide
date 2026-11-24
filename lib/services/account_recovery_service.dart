import 'api_client.dart';

/// Recuperación de contraseña (rutas /account-recovery del backend).
///
/// El backend envía por correo un código de 6 caracteres (A-Z y 0-9).
/// Cuando cambien las rutas o los campos, solo hay que ajustar este archivo.
/// Nunca se debe usar el `devToken` que pudiera devolver /request: es solo de pruebas.
class AccountRecoveryService {
  AccountRecoveryService._();
  static final instance = AccountRecoveryService._();

  /// Longitud del código que escribe el usuario.
  static const codeLength = 6;

  final _api = ApiClient.instance;

  /// Pide que se envíe el código al correo. El backend responde lo mismo
  /// exista o no la cuenta (para no revelar qué correos están registrados).
  Future<void> requestCode(String email) async {
    await _api.post('/account-recovery/request', body: {'email': email});
  }

  /// Cambia la contraseña con el código recibido.
  ///
  /// La ruta recibe { token, newPassword }. [email] se recibe por si el backend
  /// pide algún día el correo junto al código.
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
