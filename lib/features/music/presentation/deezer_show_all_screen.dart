import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/music_player_skin.dart';
import '../../../l10n/app_localizations.dart';
import '../application/deezer_providers.dart';
import 'deezer_preview_player.dart';

class DeezerShowAllScreen extends StatelessWidget {
  const DeezerShowAllScreen({
    super.key,
    required this.title,
    required this.skin,
    this.tracks = const [],
    this.artists = const [],
  });

  final String title;
  final MusicPlayerSkin skin;
  final List<DeezerTrack> tracks;
  final List<DeezerArtist> artists;

  @override
  Widget build(BuildContext context) {
    final isTracks = tracks.isNotEmpty;
    return Scaffold(
      backgroundColor: skin.backgroundTop,
      appBar: AppBar(
        backgroundColor: skin.backgroundTop,
        title: Text(title, style: TextStyle(color: skin.textPrimary)),
        iconTheme: IconThemeData(color: skin.textPrimary),
      ),
      body: isTracks
          ? GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.72),
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final t = tracks[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerPreviewPlayerScreen(track: t))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(skin.cardRadius), child: AspectRatio(aspectRatio: 1, child: t.cover.isNotEmpty ? Image.network(t.cover, fit: BoxFit.cover) : Container(color: skin.accent.withValues(alpha: 0.15)))),
                      const SizedBox(height: 8),
                      Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(t.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
                    ],
                  ),
                );
              },
            )
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.85),
              itemCount: artists.length,
              itemBuilder: (context, i) {
                final a = artists[i];
                return GestureDetector(
                  onTap: () => context.push('/music/artist/${Uri.encodeComponent(a.name)}', extra: a),
                  child: Column(
                    children: [
                      ClipOval(child: SizedBox(width: 120, height: 120, child: a.picture.isNotEmpty ? Image.network(a.picture, fit: BoxFit.cover) : Container(color: Colors.white12))),
                      const SizedBox(height: 8),
                      Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(AppLocalizations.of(context)!.artist, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
