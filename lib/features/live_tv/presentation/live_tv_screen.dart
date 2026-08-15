import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../../library/application/library_providers.dart';

/// Live TV: canales en directo del servidor Jellyfin.
class LiveTvScreen extends ConsumerWidget {
  const LiveTvScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final channels = ref.watch(liveTvChannelsProvider);

    return Scaffold(
      body: DashboardBackground(
        child: channels.when(
          loading: () => const Center(child: AppLoader()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => list.isEmpty
              ? Center(
                  child: Text(
                    l10n.noResults,
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                      child: Text(
                        l10n.liveTv,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final channel = list[i];
                          return _ChannelCard(
                            channel: channel,
                            serverUrl: serverUrl,
                            onTap: () => context.push(
                              '/player/${channel.id}',
                              extra: channel,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Tarjeta de canal de TV en directo (imagen 16:9 + nombre).
class _ChannelCard extends ConsumerWidget {
  const _ChannelCard({
    required this.channel,
    required this.serverUrl,
    required this.onTap,
  });

  final BaseItemDto channel;
  final String? serverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final url =
        serverUrl != null ? itemImageUrl(serverUrl!, channel) : null;

    return ScaleButton(
      selectedScale: 1.05,
      borderRadius: BorderRadius.circular(radius + 2),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius * 1.5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url != null)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _ChannelFallback(
                        channel: channel,
                        color: fallbackColor,
                        accent: accent,
                      ),
                    )
                  else
                    _ChannelFallback(
                      channel: channel,
                      color: fallbackColor,
                      accent: accent,
                    ),
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(Icons.circle, color: Colors.redAccent, size: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            channel.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Relleno cuando el canal no tiene imagen.
class _ChannelFallback extends StatelessWidget {
  const _ChannelFallback({
    required this.channel,
    required this.color,
    required this.accent,
  });

  final BaseItemDto channel;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final initial = (channel.name ?? '?').substring(0, 1).toUpperCase();
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: accent,
          fontSize: 48,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
