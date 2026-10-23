import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
<<<<<<< HEAD
import 'services/auth_service.dart';
=======
>>>>>>> 90b522e (Conexion con Backend)
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

// 👉 Para usar tu splash, descomenta este import
//    (ajusta el nombre de la clase si tu splash no se llama SplashScreen):
// import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si el usuario ya había iniciado sesión, entra directo al Home.
  await AuthService.instance.restoreSession();

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

          // Idioma de la app: español de México.
          locale: const Locale('es', 'MX'),
          supportedLocales: const [Locale('es', 'MX'), Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          initialRoute: AuthService.instance.isLoggedIn ? '/home' : '/login',
          routes: {
            // 👉 Para arrancar con tu splash: descomenta la línea de abajo,
            //    cambia initialRoute a '/' y que el splash decida a dónde ir
            //    con AuthService.instance.isLoggedIn.
            // '/': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/home': (_) => const HomeScreen(),
          },
        );
      },
    );
  }
}