import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/library/application/image_url.dart';
import '../../features/library/application/library_providers.dart';

/// Logo del artista (Jellyfin) con respaldo a texto si no tiene logo.
///
/// 1) Intenta el logo de [artistEntity] si se aporta.
/// 2) Si no, resuelve el artista por nombre ([artistEntityByNameProvider]).
/// 3) Si tampoco hay logo, muestra el nombre con [textStyle].
class ArtistLogoName extends ConsumerWidget {
  const ArtistLogoName({
    super.key,
    required this.artistName,
    this.artistEntity,
    required this.serverUrl,
    this.logoHeight = 56,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.maxWidth,
  });

  final String artistName;
  final BaseItemDto? artistEntity;
  final String? serverUrl;
  final double logoHeight;
  final TextStyle? textStyle;
  final TextAlign textAlign;

  /// Ancho máximo del logo: los logos de Jellyfin suelen ser panorámicos y
  /// en ventanas anchas sprawlean ocupando toda la cabecera (parece
  /// centrado); acotarlo lo deja en bloque a la izquierda.
  final double? maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = Text(
      artistName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style:
          textStyle ??
          const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
    );
    if (artistName.trim().isEmpty) return const SizedBox.shrink();
    if (serverUrl == null || serverUrl!.isEmpty) return fallback;
    // 1) Logo directo de la entidad aportada.
    final directUrl = artistEntity != null
        ? itemLogoUrl(serverUrl!, artistEntity!)
        : null;
    if (directUrl != null) return _logoImage(directUrl, fallback);
    // 2) Resolver el artista por nombre.
    final async = ref.watch(artistEntityByNameProvider(artistName));
    return async.when(
      data: (entity) {
        final url = entity != null ? itemLogoUrl(serverUrl!, entity) : null;
        if (url == null) return fallback;
        return _logoImage(url, fallback);
      },
      loading: () => fallback,
      error: (_, _) => fallback,
    );
  }

  Widget _logoImage(String url, Widget fallback) {
    final image = Image.network(
      url,
      height: logoHeight,
      fit: BoxFit.contain,
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      errorBuilder: (_, _, _) => fallback,
    );
    final capped = maxWidth == null
        ? image
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: Align(alignment: Alignment.centerLeft, child: image),
          );
    return capped;
  }
}
