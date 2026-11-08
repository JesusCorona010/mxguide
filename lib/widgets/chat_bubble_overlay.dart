import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/chat/chat_screen.dart';
import '../services/chatbot_service.dart';

/// Burbuja flotante de Mictlan (estilo Mercado Pago) encima de [child].
///
/// - Tócala para abrir el chat.
/// - Arrástrala a donde quieras: al soltarla se pega al borde más cercano.
/// - Arrástrala a la X de abajo para ocultarla (se vuelve a activar en Perfil).
class ChatBubbleOverlay extends StatefulWidget {
  const ChatBubbleOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<ChatBubbleOverlay> createState() => _ChatBubbleOverlayState();
}

class _ChatBubbleOverlayState extends State<ChatBubbleOverlay> {
  static const _size = 60.0;
  static const _margin = 12.0;
  static const _closeSize = 64.0;
  static const _teaserKey = 'mxguide_chat_teaser_seen';

  final _chat = ChatbotService.instance;

  Offset? _position;
  bool _dragging = false;
  bool _overClose = false;
  bool _showTeaser = false;
  Timer? _teaserTimer;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChatChanged);
    _maybeShowTeaser();
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _teaserTimer?.cancel();
    super.dispose();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
  }

  /// La primera vez, un globito invita a usar el chat por unos segundos.
  Future<void> _maybeShowTeaser() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_teaserKey) ?? false) return;
    await prefs.setBool(_teaserKey, true);
    if (!mounted) return;
    setState(() => _showTeaser = true);
    _teaserTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showTeaser = false);
    });
  }

  // ───────────── Geometría ─────────────

  Rect _bounds(Size area, EdgeInsets padding) => Rect.fromLTRB(
        _margin,
        padding.top + _margin,
        area.width - _size - _margin,
        // Se deja libre la parte de abajo para el botón "+" de la barra.
        area.height - _size - 40,
      );

  Offset _clamp(Offset p, Rect b) => Offset(
        p.dx.clamp(b.left, math.max(b.left, b.right)).toDouble(),
        p.dy.clamp(b.top, math.max(b.top, b.bottom)).toDouble(),
      );

  Offset _closeCenter(Size area) => Offset(area.width / 2, area.height - 70);

  bool _isOverClose(Offset bubble, Size area) =>
      (bubble + const Offset(_size / 2, _size / 2) - _closeCenter(area)).distance < _closeSize;

  // ───────────── Gestos ─────────────

  void _openChat() {
    setState(() => _showTeaser = false);
    Navigator.of(context).push(ChatScreen.route());
  }

  void _onPanUpdate(DragUpdateDetails details, Size area, Rect bounds) {
    final next = Offset(
      ((_position ?? Offset.zero).dx + details.delta.dx).clamp(0.0, math.max(0.0, area.width - _size)).toDouble(),
      ((_position ?? Offset.zero).dy + details.delta.dy).clamp(0.0, math.max(0.0, area.height - _size)).toDouble(),
    );
    final over = _isOverClose(next, area);
    if (over && !_overClose) HapticFeedback.mediumImpact();
    setState(() {
      _position = next;
      _dragging = true;
      _overClose = over;
      _showTeaser = false;
    });
  }

  void _onPanEnd(Size area, Rect bounds) {
    if (_overClose) {
      setState(() {
        _dragging = false;
        _overClose = false;
        _position = null; // La próxima vez vuelve a su lugar de siempre.
      });
      _chat.setBubbleVisible(false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Ocultaste a Mictlan. Puedes activarlo en Perfil.'),
            action: SnackBarAction(label: 'Deshacer', onPressed: () => _chat.setBubbleVisible(true)),
          ),
        );
      return;
    }

    // Se pega al borde izquierdo o derecho, el que quede más cerca.
    final current = _position ?? bounds.bottomRight;
    final snapX = current.dx + _size / 2 < area.width / 2 ? bounds.left : bounds.right;
    setState(() {
      _dragging = false;
      _position = _clamp(Offset(snapX, current.dy), bounds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final bounds = _bounds(area, padding);
        // Posición inicial: abajo a la derecha, arriba de la barra.
        final position = _dragging
            ? (_position ?? bounds.bottomRight)
            : _clamp(_position ?? Offset(bounds.right, bounds.bottom - 70), bounds);
        final onLeft = position.dx + _size / 2 < area.width / 2;
        final close = _closeCenter(area);

        return Stack(
          children: [
            widget.child,
            if (_chat.bubbleVisible) ...[
              // Zona para soltar y ocultar la burbuja.
              Positioned(
                left: close.dx - _closeSize / 2,
                top: close.dy - _closeSize / 2,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _dragging ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: AnimatedScale(
                      scale: _overClose ? 1.2 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: _CloseTarget(size: _closeSize, active: _overClose),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                left: position.dx,
                top: position.dy,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    _position ??= position;
                    _onPanUpdate(d, area, bounds);
                  },
                  onPanEnd: (_) => _onPanEnd(area, bounds),
                  child: AnimatedScale(
                    scale: _overClose ? 0.8 : (_dragging ? 1.08 : 1),
                    duration: const Duration(milliseconds: 120),
                    child: _Bubble(size: _size, busy: _chat.isSending, onTap: _openChat),
                  ),
                ),
              ),
              if (_showTeaser && !_dragging)
                Positioned(
                  top: position.dy + 8,
                  left: onLeft ? position.dx + _size + 8 : null,
                  right: onLeft ? null : area.width - position.dx + 8,
                  child: _Teaser(onTap: _openChat),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.busy, required this.onTap});

  final double size;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Abrir chat con Mictlan, tu guía de viaje',
      child: Material(
        color: colors.primary,
        shape: CircleBorder(side: BorderSide(color: colors.tertiary, width: 3)),
        elevation: 6,
        shadowColor: Colors.black54,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: colors.onPrimary, size: size * 0.46),
                // Mientras Mictlan piensa, un anillo girando alrededor.
                if (busy)
                  SizedBox(
                    width: size - 6,
                    height: size - 6,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.onPrimary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseTarget extends StatelessWidget {
  const _CloseTarget({required this.size, required this.active});

  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active ? colors.error : const Color(0xCC0A1A2F),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(Icons.close_rounded, color: active ? colors.onError : Colors.white, size: 30),
    );
  }
}

class _Teaser extends StatelessWidget {
  const _Teaser({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFF0A1A2F),
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: '¿No sabes a dónde ir?\n', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: 'Pregúntale a Mictlan, tu guía de viaje.'),
                ],
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, height: 1.35),
            ),
          ),
        ),
      ),
    );
  }
}
