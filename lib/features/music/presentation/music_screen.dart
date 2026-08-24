import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/music_player_skin_controller.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/poster_card.dart';
import 'widgets/music_skins/apple_music_view.dart';
import 'widgets/music_skins/jellyfin_classic_music_view.dart';
import 'widgets/music_skins/spotify_music_view.dart';
import 'widgets/music_skins/tidal_music_view.dart';
import 'widgets/music_skins/youtube_music_view.dart';

/// Music Player: álbumes y canciones de la biblioteca de música.
/// Usa exclusivamente el skin del music player (no el global).
class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverUrl = ref.watch(authServerUrlProvider);
    final albums = ref.watch(musicAlbumsProvider);
    final tracks = ref.watch(musicTracksProvider);
    final musicSkinAsync = ref.watch(musicPlayerSkinControllerProvider);
    final musicSkin = musicSkinAsync.value;

    if (musicSkin == null) {
      return const Scaffold(body: Center(child: AppLoader()));
    }

    final Widget view = switch (musicSkin.id) {
      'spotify' => SpotifyMusicView(
          skin: musicSkin,
          serverUrl: serverUrl,
          albumsAsync: albums,
          tracksAsync: tracks,
        ),
      'apple_music' => AppleMusicView(
          skin: musicSkin,
          serverUrl: serverUrl,
          albumsAsync: albums,
          tracksAsync: tracks,
        ),
      'youtube_music' => YoutubeMusicView(
          skin: musicSkin,
          serverUrl: serverUrl,
          albumsAsync: albums,
          tracksAsync: tracks,
        ),
      'tidal' => TidalMusicView(
          skin: musicSkin,
          serverUrl: serverUrl,
          albumsAsync: albums,
          tracksAsync: tracks,
        ),
      _ => JellyfinClassicMusicView(
          skin: musicSkin,
          serverUrl: serverUrl,
          albumsAsync: albums,
          tracksAsync: tracks,
        ),
    };

    return Scaffold(
      body: DashboardBackground(child: view),
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
    final musicSkin = ref.watch(musicPlayerSkinControllerProvider).value;
    // Jellyfin Classic mantiene layout histórico; el resto usa skin de música.
    if (musicSkin != null && musicSkin.id == 'jellyfin_classic') {
      return _JellyfinDefaultAlbumView(
        album: album,
        albumId: albumId,
        serverUrl: serverUrl,
        tracks: tracks,
      );
    }
    final mSkin = musicSkin;
    final textPrimary = mSkin?.textPrimary ?? Colors.white;
    final textSecondary = mSkin?.textSecondary ?? Colors.white70;
    final title = album?.name ?? '';
    final bgTop = mSkin?.backgroundTop ?? const Color(0xFF0A0A0A);
    final bgBottom = mSkin?.backgroundBottom ?? const Color(0xFF1A1A1A);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      tooltip: l10n.back,
                      style: IconButton.styleFrom(
                        backgroundColor: textPrimary.withValues(alpha: 0.08),
                        foregroundColor: textPrimary,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/music');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (album != null && serverUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(mSkin?.cardRadius ?? 10),
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
                ],
              ),
            ),
            Expanded(
              child: tracks.when(
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => Center(child: Text('$e', style: TextStyle(color: textSecondary))),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noResults,
                          style: TextStyle(color: textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: textSecondary.withValues(alpha: 0.15)),
                        itemBuilder: (context, i) {
                          final track = list[i];
                          final index = (track.indexNumber ?? i + 1).toString();
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
                            trailing: Icon(
                              Icons.play_arrow_rounded,
                              color: mSkin?.accent ?? Colors.white54,
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

/// Layout Jellyfin para el skin default — replica la captura:
/// portada a la izquierda solapada, logo grande arriba-derecha, barra gris
/// con título/artista/metadata y acciones, y lista de pistas con duración.
class _JellyfinDefaultAlbumView extends ConsumerWidget {
  const _JellyfinDefaultAlbumView({
    required this.album,
    required this.albumId,
    required this.serverUrl,
    required this.tracks,
  });

  final BaseItemDto? album;
  final String albumId;
  final String? serverUrl;
  final AsyncValue<List<BaseItemDto>> tracks;

  String _formatMs(int ms) {
    final totalSec = ms ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final albumItem = album;
    final artist =
        (albumItem?.albumArtists?.firstOrNull?.name ??
                albumItem?.artists?.firstOrNull ??
                '')
            .trim();
    final title = albumItem?.name ?? '';
    // Logo grande: usa nombre del artista en mayúsculas como en la captura.
    final logoText = artist.isNotEmpty
        ? artist.toUpperCase()
        : (albumItem?.albumArtist ?? '').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: tracks.when(
        loading: () => const Center(child: AppLoader()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: Colors.white54)),
        ),
        data: (list) {
          final totalMs = list.fold<int>(
            0,
            (p, e) => p + (e.runTimeTicks ?? 0) ~/ 10000,
          );
          final count = list.length;
          final minutes = totalMs > 0
              ? '${_formatMs(totalMs).split(':').first}m'
              : '';
          final year = albumItem?.productionYear?.toString() ?? '';
          final rating = albumItem?.communityRating != null
              ? '★ ${albumItem!.communityRating!.toStringAsFixed(1)}'
              : '';
          final genre = albumItem?.genres?.firstOrNull ?? 'Dance-Pop';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // COLUMNA IZQUIERDA: flecha y carátula más grande, de arriba a abajo.
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              tooltip: l10n.back,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/music'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 320,
                          height: 320,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: serverUrl != null && albumItem != null
                              ? Image.network(
                                  itemImageUrl(serverUrl!, albumItem),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      Container(color: const Color(0xFF1A1A1A)),
                                )
                              : Container(color: const Color(0xFF1A1A1A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // COLUMNA DERECHA: nombre artista arriba del todo y debajo resto.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre artista arriba del todo (como LADY GAGA en captura).
                        if (logoText.isNotEmpty)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              logoText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                height: 0.9,
                              ),
                            ),
                          ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.07,
                        ),
                        // Barra gris con info del álbum.
                        // Row con column izquierda (título/artista/metadata) y botones a la derecha centrados en la misma fila que el autor.
                        Container(
                          color: const Color(0xFF1A1A1A),
                          padding: EdgeInsets.fromLTRB(
                            MediaQuery.of(context).size.width * 0.03,
                            16,
                            16,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isNotEmpty ? title : '—',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (artist.isNotEmpty)
                                          Text(
                                            artist,
                                            style: const TextStyle(
                                              color: Color(0xFF3DDC84),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '$count pistas',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (minutes.isNotEmpty) ...[
                                              const Text(
                                                '  ',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              Text(
                                                minutes,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                            if (year.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                year,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                            if (rating.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                rating,
                                                style: const TextStyle(
                                                  color: Color(0xFFFFC107),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: list.isEmpty
                                            ? null
                                            : () => context.push(
                                                '/player/${list.first.id}',
                                                extra: list.first,
                                              ),
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Icons.explore_outlined,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Icons.shuffle_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Icons.favorite_border_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Icons.more_vert_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Todo desde Wrap hasta abajo con mismo padding izq (16) que título/autor de la barra.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(50, 0, 26, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 4,
                                children: [
                                  for (final t in [
                                    'MusicBrainz Album',
                                    'MusicBrainz Album Artist',
                                    'MusicBrainz Release Group',
                                  ])
                                    Text(
                                      t,
                                      style: const TextStyle(
                                        color: Color(0xFF2E7D32),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text(
                                    'Género',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Text(
                                    genre,
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Lista de pistas como tabla.
                              Column(
                                children: [
                                  for (var i = 0; i < list.length; i++)
                                    _JellyfinTrackRow(
                                      index: (list[i].indexNumber ?? i + 1)
                                          .toString(),
                                      track: list[i],
                                      onTap: () => context.push(
                                        '/player/${list[i].id}',
                                        extra: list[i],
                                      ),
                                    ),
                                  if (list.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'Sin pistas',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 56),
                              if (albumItem != null)
                                _MoreArtistAlbums(
                                  album: albumItem,
                                  serverUrl: serverUrl,
                                ),
                              const SizedBox(height: 24),
                              const Text(
                                'Más como este',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JellyfinTrackRow extends StatelessWidget {
  const _JellyfinTrackRow({
    required this.index,
    required this.track,
    required this.onTap,
  });
  final String index;
  final BaseItemDto track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dur = track.runTimeTicks != null ? (track.runTimeTicks! ~/ 10000) : 0;
    final ms = dur;
    final m = (ms ~/ 60000);
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final durStr = ms > 0 ? '$m:$s' : '4:29';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                index,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                track.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              durStr,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Icon(
              Icons.more_vert_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreArtistAlbums extends ConsumerWidget {
  const _MoreArtistAlbums({required this.album, required this.serverUrl});
  final BaseItemDto album;
  final String? serverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final more = ref.watch(artistAlbumsProvider(album));
    final artist =
        (album.albumArtist?.trim().isNotEmpty == true
                ? album.albumArtist!.trim()
                : (album.artists?.firstOrNull?.trim() ?? ''))
            .trim();
    final title = artist.isNotEmpty
        ? 'Más álbumes de $artist'
        : 'Más álbumes del artista';
    return more.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final item = list[i];
                  return SizedBox(
                    width: 130,
                    child: PosterCard(
                      item: item,
                      serverUrl: serverUrl,
                      onTap: () =>
                          context.push('/music/album/${item.id}', extra: item),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
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
                        errorBuilder: (_, _, _) =>
                            _TrackFallback(track: track, color: fallbackColor),
                      )
                    : _TrackFallback(track: track, color: fallbackColor),
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
                    style: TextStyle(color: textPrimary, fontSize: 15),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.play_arrow_rounded, color: Colors.white54),
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
