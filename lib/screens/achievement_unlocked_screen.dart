import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/achievement.dart';
import '../theme/app_colors.dart';
import '../widgets/achievement_medal.dart';

/// Celebración a pantalla completa al desbloquear una medalla.
class AchievementUnlockedScreen extends StatefulWidget {
  const AchievementUnlockedScreen({
    super.key,
    required this.achievement,
    required this.visitedStates,
    required this.totalStates,
  });

  final StateAchievement achievement;
  final int visitedStates;
  final int totalStates;

  /// Abre la pantalla con una transición de desvanecido.
  static Route<void> route({
    required StateAchievement achievement,
    required int visitedStates,
    required int totalStates,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => AchievementUnlockedScreen(
        achievement: achievement,
        visitedStates: visitedStates,
        totalStates: totalStates,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  State<AchievementUnlockedScreen> createState() => _AchievementUnlockedScreenState();
}

class _AchievementUnlockedScreenState extends State<AchievementUnlockedScreen>
    with TickerProviderStateMixin {
  late final AnimationController _medalController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _confettiController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  late final Animation<double> _medalScale =
      CurvedAnimation(parent: _medalController, curve: Curves.elasticOut);
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _medalController,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _medalController.forward();
    _confettiController.forward();
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _medalController.dispose();
    _glowController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _share() {
    // TODO: compartir en redes (por ejemplo con el paquete share_plus).
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Compartir estará disponible pronto')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievement = widget.achievement;

    const navy = AppColors.textPrimaryLight;
    const ochre = AppColors.jaguarOchreDark;
    const teal = AppColors.jungleTealDark;

    // La medalla siempre se dibuja con los colores "oscuros" porque el fondo es azul marino.
    final darkTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: AppColors.jungleTealDark,
        secondary: AppColors.sunRedDark,
        tertiary: AppColors.jaguarOchreDark,
        onTertiary: navy,
        surface: navy,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: navy,
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) => CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _confettiController.value,
                      colors: const [teal, AppColors.sunRedDark, ochre, AppColors.jungleTealLight],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Medalla con brillo pulsante.
                        Center(
                          child: AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              final glow = 0.6 + _glowController.value * 0.4;
                              return Container(
                                width: 190,
                                height: 190,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ochre.withAlpha((30 * glow).round()),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ochre.withAlpha((70 * glow).round()),
                                      blurRadius: 60 * glow,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: child,
                              );
                            },
                            child: ScaleTransition(
                              scale: _medalScale,
                              child: Theme(
                                data: darkTheme,
                                child: AchievementMedal(
                                  achievement: achievement,
                                  unlocked: true,
                                  size: 110,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        FadeTransition(
                          opacity: _textFade,
                          child: Column(
                            children: [
                              Text(
                                '¡LOGRO DESBLOQUEADO!',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: ochre,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                achievement.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                achievement.description,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondaryDark,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.place_rounded, size: 18, color: teal),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${achievement.state} · Estado ${widget.visitedStates} de ${widget.totalStates}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 36),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal,
                                  foregroundColor: navy,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('¡A seguir explorando!'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white30),
                                ),
                                onPressed: _share,
                                icon: const Icon(Icons.share_rounded, size: 20),
                                label: const Text('Compartir logro'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confeti que cae desde arriba, dibujado a mano (sin paquetes extra).
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  // Semilla fija: las piezas siempre son las mismas y no "brincan" entre frames.
  static final List<_Piece> _pieces = List.generate(70, (i) => _Piece.random(math.Random(i * 7 + 3)));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = piece.x * size.width + math.sin(t * math.pi * 4 + piece.sway) * 18;
      final y = -20 + t * (size.height + 40) * piece.speed;
      final opacity = t > 0.8 ? (1 - t) / 0.2 : 1.0;

      paint.color = colors[i % colors.length].withAlpha((255 * opacity).round());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation + t * math.pi * 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: piece.width, height: piece.height),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

class _Piece {
  _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.rotation,
    required this.sway,
    required this.width,
    required this.height,
  });

  factory _Piece.random(math.Random r) => _Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        speed: 0.8 + r.nextDouble() * 0.5,
        rotation: r.nextDouble() * math.pi,
        sway: r.nextDouble() * math.pi * 2,
        width: 6 + r.nextDouble() * 6,
        height: 8 + r.nextDouble() * 8,
      );

  final double x;
  final double delay;
  final double speed;
  final double rotation;
  final double sway;
  final double width;
  final double height;
}