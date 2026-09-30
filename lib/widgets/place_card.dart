import 'package:flutter/material.dart';

import '../models/place.dart';
import '../theme/app_colors.dart';

/// Tarjeta de un lugar: foto, categoría, nombre, estado y botón de favorito.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.isFavorite,
    required this.onFavoriteTap,
    this.onTap,
    this.dense = false,
  });

  final Place place;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback? onTap;

  /// true = versión compacta para la grilla de 3 columnas: imagen casi
  /// cuadrada, sin la fila de estado, y el corazón como botón chico sobre
  /// la imagen en vez de una fila aparte (si no, no cabe en una celda tan
  /// angosta).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: dense ? 1.1 : 2.2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PlaceImage(url: place.imageUrl),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _CategoryBadge(label: place.category, compact: dense),
                  ),
                  if (dense)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _FavoriteOverlayButton(
                        isFavorite: isFavorite,
                        onTap: onFavoriteTap,
                      ),
                    ),
                ],
              ),
            ),
            if (dense)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Text(
                  place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: 14, color: colors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  place.state,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: colors.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
                      onPressed: onFavoriteTap,
                      icon: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: colors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteOverlayButton extends StatelessWidget {
  const _FavoriteOverlayButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppExtraColors.badgeOverlay,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  const _PlaceImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) return const _ImagePlaceholder();

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _ImagePlaceholder(loading: true),
      errorBuilder: (context, error, stackTrace) =>
          const _ImagePlaceholder(icon: Icons.broken_image_outlined),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.loading = false, this.icon = Icons.image_outlined});

  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: isDark ? AppExtraColors.imagePlaceholderDark : AppExtraColors.imagePlaceholderLight,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(icon, size: 36, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: AppExtraColors.badgeOverlay,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (compact ? Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9) : Theme.of(context).textTheme.labelSmall)?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}