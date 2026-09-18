import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/entity_portrait.dart';

/// Tarjeta universal estilo Spotify para scrolls y parrillas de música:
/// fondo que se ilumina en hover, carátula cuadrada o circular, logo de
/// esquina opcional, play que sube en hover y título + subtítulo.
///
/// Unifica en un solo widget con opciones lo que antes eran seis tarjetas
/// casi idénticas (tendencias Deezer/Jellyfin, artistas, playlists,
/// recién añadidos y relacionados).
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showExplicit = false,
    this.imageUrl,
    this.fallbackIcon = Icons.music_note,
    this.fallbackText,
    this.fallbackBackground = const Color(0xFF2A2A2A),
    this.fallbackIconColor,
    this.circular = false,
    this.width = 160,
    this.imageSize,
    this.padding = const EdgeInsets.all(8),
    this.imageRadius = 6,
    this.badgeAsset,
    this.badgeSize = 16,
    this.playSize = 44,
    this.playBackground = const Color(0xFF1DB954),
    this.cardNormal = const Color(0xFF181818),
    this.cardHovered = const Color(0xFF282828),
    this.textPrimary = Colors.white,
    this.textSecondary = Colors.white54,
    this.titleSize = kCardTitleFontSize,
    this.titleWeight = FontWeight.w600,
    this.subtitleSize = kCardSubtitleFontSize,
    this.centerText = false,
    this.dimOnHover = false,
  });

  /// Título (nombre de pista, álbum, artista o playlist).
  final String title;

  /// Segunda línea (artista, "Artista", "Playlist"...).
  final String subtitle;

  /// Acción al pulsar (reproducir, abrir detalle...).
  final VoidCallback onTap;

  /// Muestra la pastilla "E" delante del subtítulo.
  final bool showExplicit;

  /// URL de la carátula/foto. Vacía o nula = respaldo.
  final String? imageUrl;

  /// Icono del respaldo cuadrado (si [fallbackText] es nulo).
  final IconData fallbackIcon;

  /// Letra del respaldo cuadrado (ej. inicial del artista). Nulo = icono.
  final String? fallbackText;

  /// Fondo del respaldo cuadrado.
  final Color fallbackBackground;

  /// Color del icono/letra del respaldo. Nulo = [textSecondary].
  final Color? fallbackIconColor;

  /// Foto circular (artistas) en vez de carátula cuadrada.
  final bool circular;

  /// Ancho de la tarjeta (`double.infinity` en parrillas).
  final double width;

  /// Lado fijo de la imagen. Nulo = cuadrada a todo el ancho disponible.
  final double? imageSize;

  final EdgeInsets padding;

  /// Radio de la carátula cuadrada.
  final double imageRadius;

  /// Logo de esquina (asset Deezer/Jellyfin). Nulo = sin logo.
  final String? badgeAsset;

  final double badgeSize;

  final double playSize;
  final Color playBackground;
  final Color cardNormal;
  final Color cardHovered;
  final Color textPrimary;
  final Color textSecondary;
  final double titleSize;
  final FontWeight titleWeight;
  final double subtitleSize;
  final bool centerText;

  /// Oscurece la imagen al hacer hover (carátulas cuadradas).
  final bool dimOnHover;

  /// Navegación por defecto a la página del artista (para tarjetas de
  /// artista sin [onTap] explícito).
  static void openArtist(BuildContext context, String artistName, Object? extra) {
    context.push('/music/artist/${Uri.encodeComponent(artistName)}', extra: extra);
  }

  Widget _fallback(Color iconColor) {
    return Container(
      color: fallbackBackground,
      alignment: Alignment.center,
      child: fallbackText != null && fallbackText!.isNotEmpty
          ? Text(
              fallbackText!,
              style: TextStyle(
                color: iconColor,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(fallbackIcon, color: iconColor),
    );
  }

  Widget _image(Color iconColor) {
    if (circular) {
      // EntityPortrait ya trae respaldo de iniciales.
      return EntityPortrait(
        name: title,
        url: imageUrl,
        width: imageSize ?? 116,
        circular: true,
        memCacheWidth: 400,
      );
    }
    final hasUrl = (imageUrl ?? '').isNotEmpty;
    final content = hasUrl
        ? Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(iconColor),
          )
        : _fallback(iconColor);
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(imageRadius),
      child: content,
    );
    if (imageSize != null) {
      return SizedBox(width: imageSize, height: imageSize, child: clipped);
    }
    return AspectRatio(aspectRatio: 1, child: clipped);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = fallbackIconColor ?? textSecondary;
    return AppHover(
      effect: AppHoverEffect.highlight,
      config: AppHoverConfig(
        highlightNormal: cardNormal,
        highlightHovered: cardHovered,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerText
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final hovered =
                      AppHoverScope.of(context)?.hovered ?? false;
                  return Stack(
                    children: [
                      _image(iconColor),
                      if (dimOnHover)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: circular
                                  ? null
                                  : BorderRadius.circular(imageRadius),
                              shape: circular
                                  ? BoxShape.circle
                                  : BoxShape.rectangle,
                              color: Colors.black.withValues(
                                alpha: hovered ? 0.08 : 0,
                              ),
                            ),
                          ),
                        ),
                      if (badgeAsset != null)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Image.asset(
                            badgeAsset!,
                            height: badgeSize,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      Positioned(
                        right: circular ? 6 : 8,
                        bottom: hovered ? 8 : 0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: hovered ? 1 : 0,
                          child: Container(
                            width: playSize,
                            height: playSize,
                            decoration: BoxDecoration(
                              color: playBackground,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: playSize - 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: centerText ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: titleSize,
                  fontWeight: titleWeight,
                ),
              ),
              const SizedBox(height: 2),
              if (showExplicit)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A6A6A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'E',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: centerText
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: subtitleSize,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign:
                      centerText ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: subtitleSize,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
