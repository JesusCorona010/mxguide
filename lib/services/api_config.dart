import 'package:flutter/foundation.dart';

/// Configuración compartida para hablar con el backend (NestJS).
///
/// Centraliza la detección de host/puerto para que [PlaceService] (lista de
/// lugares) y [Place] (miniaturas de `/place-images`, ver modelo) le
/// peguen siempre a la misma URL base, en vez de tener la misma lógica
/// copiada en dos archivos.
///
/// TODO(backend): si tu compañero despliega la API en otro lado (no en tu
/// máquina), cambia [port] o [baseUrl] por esa URL (por ejemplo, la de
/// Render/Railway).
class ApiConfig {
  ApiConfig._();

  /// Puerto donde corre el backend en local. Ajusta el puerto si tu
  /// compañero lo levantó en otro.
  static const port = 3000;

  /// Elige el host correcto según dónde corre la app:
  /// - Web/desktop: el backend corre en la misma máquina → localhost.
  /// - Emulador de Android: "localhost" del emulador NO es tu PC, así que
  ///   Android reserva 10.0.2.2 para apuntar a la máquina host.
  /// - Dispositivo físico (celular real): ni localhost ni 10.0.2.2 sirven,
  ///   hace falta la IP de tu compañero en la red local (ej. 192.168.x.x).
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:$port';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:$port';
    return 'http://localhost:$port';
  }
}