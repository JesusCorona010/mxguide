import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

// 👉 Para usar tu splash, descomenta este import
//    (ajusta el nombre de la clase si tu splash no se llama SplashScreen):
// import 'screens/splash_screen.dart';

void main() {
  runApp(const MxGuideApp());
}

class MxGuideApp extends StatelessWidget {
  const MxGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Se reconstruye cuando el usuario toca el botón de sol/luna.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'MXGuide',
          debugShowCheckedModeBanner: false,

          // Arranca siguiendo al celular; el botón de sol/luna lo puede forzar.
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,

          initialRoute: '/login',
          routes: {
            // 👉 Para arrancar con tu splash: descomenta la línea de abajo
            //    y cambia initialRoute a '/'.
            // '/': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
            '/home': (_) => const HomeScreen(),
          },
        );
      },
    );
  }
}