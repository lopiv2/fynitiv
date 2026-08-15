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
import '../../library/presentation/widgets/poster_card.dart';

/// Music Player: álbumes y canciones de la biblioteca de música.
class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final albums = ref.watch(musicAlbumsProvider);
    final tracks = ref.watch(musicTracksProvider);

    return Scaffold(
      body: DashboardBackground(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(
                l10n.music,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _SectionTitle(title: l10n.albums),
            albums.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: AppLoader()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('$e')),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.noResults,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final album = list[i];
                        return PosterCard(
                          item: album,
                          serverUrl: serverUrl,
                          onTap: () => context.push(
                            '/music/album/${album.id}',
                            extra: album,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: l10n.songs),
            tracks.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: AppLoader()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('$e')),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.noResults,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: Colors.white12,
                      ),
                      itemBuilder: (context, i) {
                        final track = list[i];
                        return _TrackTile(
                          track: track,
                          serverUrl: serverUrl,
                          onTap: () => context.push(
                            '/player/${track.id}',
                            extra: track,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista de las canciones de un álbum concreto (/music/album/:albumId).
class MusicAlbumScreen extends ConsumerWidget {
  const MusicAlbumScreen({super.key, required this.albumId, this.album});

  final String albumId;

  /// Álbum del que viene la navegación (título e imagen mientras carga).
  final BaseItemDto? album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final tracks = ref.watch(libraryItemsProvider(albumId));
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    final title = album?.name ?? '';

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  if (album != null && serverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        itemImageUrl(serverUrl, album!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  if (album != null) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tracks.when(
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noResults,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: Colors.white12,
                        ),
                        itemBuilder: (context, i) {
                          final track = list[i];
                          final index =
                              (track.indexNumber ?? i + 1).toString();
                          return ListTile(
                            leading: Text(
                              index,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            title: Text(
                              track.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: track.artists?.isNotEmpty == true
                                ? Text(
                                    track.artists!.join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            trailing: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white54,
                            ),
                            onTap: () => context.push(
                              '/player/${track.id}',
                              extra: track,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de sección dentro de una pantalla.
class _SectionTitle extends ConsumerWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        title,
        style: TextStyle(
          color: skin?.textPrimary ?? Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Fila de una canción en la lista de canciones.
class _TrackTile extends ConsumerWidget {
  const _TrackTile({
    required this.track,
    required this.serverUrl,
    required this.onTap,
  });

  final BaseItemDto track;
  final String? serverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final subtitle = <String>[
      if (track.artists?.isNotEmpty == true) track.artists!.join(', '),
      if (track.album != null) track.album!,
    ].join(' · ');

    return ScaleButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: serverUrl != null
                    ? Image.network(
                        itemImageUrl(serverUrl!, track),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _TrackFallback(
                          track: track,
                          color: fallbackColor,
                        ),
                      )
                    : _TrackFallback(
                        track: track,
                        color: fallbackColor,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

/// Relleno de una canción sin carátula.
class _TrackFallback extends StatelessWidget {
  const _TrackFallback({required this.track, required this.color});

  final BaseItemDto track;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = (track.name ?? '?').substring(0, 1).toUpperCase();
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }
}
