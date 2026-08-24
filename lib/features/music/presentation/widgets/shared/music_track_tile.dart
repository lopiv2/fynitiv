import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/scale_button.dart';
import '../../../../library/application/image_url.dart';

/// Tile reutilizable tematizable por skin para una pista.
class MusicTrackTile extends StatelessWidget {
  const MusicTrackTile({
    super.key,
    required this.track,
    required this.serverUrl,
    required this.skin,
    required this.onTap,
  });

  final BaseItemDto track;
  final String? serverUrl;
  final MusicPlayerSkin skin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (track.artists?.isNotEmpty == true) track.artists!.join(', '),
      if (track.album != null) track.album!,
    ].join(' · ');
    final density = switch (skin.listDensity) {
      MusicListDensity.compact => 6.0,
      MusicListDensity.comfortable => 10.0,
      MusicListDensity.spacious => 14.0,
    };
    return ScaleButton(
      onPressed: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: density),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(skin.cardRadius.clamp(0, 12)),
              child: SizedBox(
                width: 48,
                height: 48,
                child: serverUrl != null
                    ? Image.network(
                        itemImageUrl(serverUrl!, track),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: skin.accent.withValues(alpha: 0.2),
                          alignment: Alignment.center,
                          child: Text(
                            (track.name ?? '?').substring(0, 1).toUpperCase(),
                            style: TextStyle(color: skin.textPrimary),
                          ),
                        ),
                      )
                    : Container(color: skin.accent.withValues(alpha: 0.2)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: skin.textPrimary, fontSize: 15)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: skin.textSecondary, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_arrow_rounded, color: skin.textSecondary),
          ],
        ),
      ),
    );
  }
}
