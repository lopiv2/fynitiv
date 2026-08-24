import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../library/application/image_url.dart';
import '../../../../library/application/library_providers.dart';

class SpotifyMusicView extends ConsumerWidget {
  const SpotifyMusicView({
    super.key,
    required this.skin,
    required this.serverUrl,
    required this.albumsAsync,
    required this.tracksAsync,
  });

  final MusicPlayerSkin skin;
  final String? serverUrl;
  final AsyncValue<List<dynamic>> albumsAsync;
  final AsyncValue<List<dynamic>> tracksAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final trendingAsync = ref.watch(spotifyTrendingSongsProvider);
    final artistsAsync = ref.watch(spotifyPopularArtistsProvider);

    return Container(
      color: skin.backgroundTop,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 24),
          // Sección 1: Canciones en tendencia
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.trendingSongs,
                    style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          trendingAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
            error: (e, _) => const SizedBox.shrink(),
            data: (songs) {
              if (songs.isEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(l10n.noResults, style: TextStyle(color: skin.textSecondary)));
              return SizedBox(
                height: 252,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: songs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => _SpotifySongCard(
                    item: songs[i],
                    serverUrl: serverUrl,
                    skin: skin,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // Sección 2: Artistas populares
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.popularArtists,
                    style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          artistsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
            error: (e, _) => const SizedBox.shrink(),
            data: (artists) {
              if (artists.isEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(l10n.noResults, style: TextStyle(color: skin.textSecondary)));
              return SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: artists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 18),
                  itemBuilder: (context, i) => _SpotifyArtistCard(
                    item: artists[i],
                    serverUrl: serverUrl,
                    skin: skin,
                  ),
                ),
              );
            },
          ),
          // Scrolls extra del preset si los hubiera (reutilizable MusicTrendingRow no usado aquí, pero se mantiene compatibilidad)
          // for (final s in skin.musicScrolls) MusicTrendingRow(scroll: s, skin: skin),
        ],
      ),
    );
  }
}

class _SpotifySongCard extends StatefulWidget {
  const _SpotifySongCard({required this.item, required this.serverUrl, required this.skin});
  final dynamic item;
  final String? serverUrl;
  final MusicPlayerSkin skin;

  @override
  State<_SpotifySongCard> createState() => _SpotifySongCardState();
}

class _SpotifySongCardState extends State<_SpotifySongCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final skin = widget.skin;
    final title = (item.name ?? '') as String;
    final artists = (item.artists is List) ? (item.artists as List).join(', ') : (item.artists?.toString() ?? '');
    final subtitle = artists.isNotEmpty ? artists : (item.album ?? '');
    // Heurística para badge E: si tiene marca explicit o cada 3 para demo
    final hasExplicit = (item.officialRating?.toString().toLowerCase().contains('explicit') ?? false) || title.toLowerCase().contains('explicit') || (title.hashCode % 3 == 0);

    final imageUrl = (widget.serverUrl != null && item.id != null)
        ? itemImageUrl(widget.serverUrl!, item, maxWidth: 400)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push('/player/${item.id}', extra: item),
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: imageUrl != null
                          ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: skin.accent.withValues(alpha: 0.15)))
                          : Container(color: const Color(0xFF2A2A2A), child: Icon(Icons.music_note, color: skin.textSecondary)),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.black.withValues(alpha: _hovered ? 0.08 : 0),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    right: 8,
                    bottom: _hovered ? 8 : 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _hovered ? 1 : 0,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: skin.accent,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: skin.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (hasExplicit) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF6A6A6A), borderRadius: BorderRadius.circular(2)),
                      child: const Text('E', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800, height: 1)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: skin.textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
                    ),
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

class _SpotifyArtistCard extends StatelessWidget {
  const _SpotifyArtistCard({required this.item, required this.serverUrl, required this.skin});
  final dynamic item;
  final String? serverUrl;
  final MusicPlayerSkin skin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = (item.name ?? '') as String;
    final imageUrl = (serverUrl != null && item.id != null)
        ? itemImageUrl(serverUrl!, item, maxWidth: 400)
        : null;

    return SizedBox(
      width: 132,
      child: Column(
        children: [
          ClipOval(
            child: SizedBox(
              width: 128,
              height: 128,
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _artistFallback(skin))
                  : _artistFallback(skin, letter: name.isNotEmpty ? name[0].toUpperCase() : '?'),
            ),
          ),
          const SizedBox(height: 10),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(l10n.artist, style: TextStyle(color: skin.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _artistFallback(MusicPlayerSkin skin, {String letter = '?'}) {
    return Container(
      color: const Color(0xFF2A2A2A),
      alignment: Alignment.center,
      child: Text(letter, style: TextStyle(color: skin.textSecondary, fontSize: 32, fontWeight: FontWeight.w700)),
    );
  }
}
