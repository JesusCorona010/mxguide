import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/chatbot_service.dart';
import '../../services/places_repository.dart';
import '../../theme/app_colors.dart';
import '../place_detail_screen.dart';

/// Chat con Mictlan: bienvenida con accesos rápidos y, después, la conversación
/// con tarjetas de lugares recomendados.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const ChatScreen(), fullscreenDialog: true);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chat = ChatbotService.instance;
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final value = text ?? _input.text;
    if (value.trim().isEmpty || _chat.isSending) return;
    _input.clear();
    _chat.send(value);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveFavorite(ChatPlace place) async {
    if (!AuthService.instance.isLoggedIn) {
      _snack('Inicia sesión para guardar tus favoritos');
      return;
    }
    try {
      await PlacesRepository.instance.addFavorite(place.id);
      _snack('Guardaste "${place.name}" en favoritos');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _openPlace(ChatPlace place) {
    Navigator.of(context).push(PlaceDetailScreen.route(place.id, name: place.name));
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Nueva conversación?'),
        content: const Text('Se borrará la plática actual con Mictlan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Empezar de nuevo')),
        ],
      ),
    );
    if (ok == true) _chat.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) {
        final messages = _chat.messages;
        final isEmpty = messages.isEmpty;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            leading: IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Row(
              children: [
                const _MictlanAvatar(size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mictlan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        _chat.isSending ? 'Escribiendo…' : 'Tu guía de viaje por México',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!isEmpty)
                IconButton(
                  tooltip: 'Nueva conversación',
                  icon: const Icon(Icons.add_comment_outlined),
                  onPressed: _chat.isSending ? null : _confirmReset,
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: isEmpty
                      ? _Welcome(onPick: _send)
                      : ListView.builder(
                          // Invertida: lo más nuevo siempre queda abajo, junto al teclado.
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          itemCount: messages.length + (_chat.isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_chat.isSending && index == 0) return _TypingBubble(slow: _chat.isSlow);
                            final message = messages[messages.length - 1 - (index - (_chat.isSending ? 1 : 0))];
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: message.isUser
                                  ? _UserBubble(text: message.text)
                                  : _BotMessage(
                                      message: message,
                                      onRetry: message.isError && _chat.canRetry && message == messages.last
                                          ? _chat.retry
                                          : null,
                                      onOpenPlace: _openPlace,
                                      onSavePlace: _saveFavorite,
                                    ),
                            );
                          },
                        ),
                ),
                if (!isEmpty && _chat.suggestions.isNotEmpty && !_chat.isSending)
                  _SuggestionChips(suggestions: _chat.suggestions, onPick: _send),
                _InputBar(
                  controller: _input,
                  focusNode: _inputFocus,
                  canSend: _input.text.trim().isNotEmpty && !_chat.isSending,
                  onSend: _send,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'Mictlan puede equivocarse. Confirma horarios y precios antes de ir.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────────── Bienvenida ─────────────

class _Welcome extends StatefulWidget {
  const _Welcome({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  bool? _hasLocation;

  @override
  void initState() {
    super.initState();
    ChatbotService.hasLocationPermission().then((value) {
      if (mounted) setState(() => _hasLocation = value);
    });
  }

  Future<void> _enableLocation() async {
    final ok = await ChatbotService.requestLocation();
    if (!mounted) return;
    setState(() => _hasLocation = ok);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin permiso de ubicación. Puedes activarlo en los ajustes del celular.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = AuthService.instance.user?.name.trim().split(RegExp(r'\s+')).first;

    final quick = <(IconData, Color, String, String)>[
      (Icons.place_outlined, colors.primary, '¿Qué hay cerca de mí?', '¿Qué lugares me recomiendas cerca de mí?'),
      (Icons.calendar_month_outlined, colors.tertiary, 'Arma mi itinerario', 'Ármame un itinerario de 2 días'),
      (Icons.restaurant_outlined, colors.secondary, 'Comida típica de la zona', '¿Qué comida típica debo probar?'),
      (Icons.military_tech_outlined, colors.onSurface, '¿Qué insignia me falta?', '¿Qué estados me recomiendas visitar para ganar insignias?'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        const Center(child: _MictlanAvatar(size: 96)),
        const SizedBox(height: 16),
        Text(
          name == null || name.isEmpty ? '¡Hola!\n¿A dónde vamos hoy?' : '¡Hola, $name!\n¿A dónde vamos hoy?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          'Soy Mictlan, tu guía de viaje. Te recomiendo lugares, armo itinerarios y te digo cómo llegar.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            for (final (icon, color, label, prompt) in quick)
              Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colors.outline),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.onPick(prompt),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 20, color: color),
                        ),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_hasLocation == false) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.near_me_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Usa tu ubicación para recomendarte lugares cercanos.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _enableLocation, child: const Text('Activar')),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────── Mensajes ─────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colors.onPrimary, height: 1.4),
          ),
        ),
      ),
    );
  }
}

class _BotMessage extends StatelessWidget {
  const _BotMessage({
    required this.message,
    required this.onRetry,
    required this.onOpenPlace,
    required this.onSavePlace,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;
  final ValueChanged<ChatPlace> onOpenPlace;
  final ValueChanged<ChatPlace> onSavePlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: message.isError ? colors.error.withAlpha(25) : colors.surface,
              border: Border.all(color: message.isError ? colors.error.withAlpha(120) : colors.outline),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(message.text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
                if (onRetry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (message.places.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: message.places.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final place = message.places[index];
                return _PlaceMiniCard(
                  place: place,
                  onOpen: () => onOpenPlace(place),
                  onSave: () => onSavePlace(place),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaceMiniCard extends StatelessWidget {
  const _PlaceMiniCard({required this.place, required this.onOpen, required this.onSave});

  final ChatPlace place;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final placeholder = ColoredBox(
      color: isDark ? AppExtraColors.imagePlaceholderDark : AppExtraColors.imagePlaceholderLight,
      child: Center(child: Icon(Icons.account_balance_rounded, color: colors.primary)),
    );
    final subtitle = [
      place.state,
      if (place.distanceKm != null) 'a ${place.distanceKm!.toStringAsFixed(1)} km',
    ].where((t) => t.isNotEmpty).join(' · ');

    return SizedBox(
      width: 170,
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outline),
        ),
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      ApiConfig.placeThumbnail(place.id),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => placeholder,
                      loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
                    ),
                    if (place.category.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppExtraColors.badgeOverlay,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            place.category,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Text(
                  place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.2),
                ),
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                      onPressed: onOpen,
                      child: const Text('Ver lugar'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Guardar en favoritos',
                    onPressed: onSave,
                    icon: Icon(Icons.favorite_border_rounded, color: colors.secondary, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.slow});

  final bool slow;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotOpacity(int index) {
    final phase = (_controller.value - index * 0.2) % 1.0;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.3 + 0.7 * wave;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Mictlan está escribiendo',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.outline),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Opacity(
                        // Cada punto se ilumina un poco después del anterior.
                        opacity: _dotOpacity(i),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: colors.onSurfaceVariant, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (widget.slow)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Mictlan se está despertando, puede tardar un poco…',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────── Barra inferior ─────────────

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: suggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          label: Text(suggestions[index]),
          onPressed: () => onPick(suggestions[index]),
          backgroundColor: colors.surface,
          side: BorderSide(color: colors.primary.withAlpha(110)),
          shape: const StadiumBorder(),
          labelStyle: theme.textTheme.labelLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Pregúntale a Mictlan…',
                counterText: '',
                filled: true,
                fillColor: colors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filled(
              tooltip: 'Enviar mensaje',
              onPressed: canSend ? onSend : null,
              icon: const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _MictlanAvatar extends StatelessWidget {
  const _MictlanAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: colors.tertiary, width: size * 0.05),
      ),
      child: Icon(Icons.auto_awesome_rounded, color: colors.onPrimary, size: size * 0.5),
    );
  }
}
