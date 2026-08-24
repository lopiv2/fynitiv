import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../library/presentation/widgets/poster_card.dart';

/// Grid reutilizable de álbumes tematizable por skin.
class MusicAlbumGrid extends ConsumerWidget {
  const MusicAlbumGrid({
    super.key,
    required this.albums,
    required this.serverUrl,
    required this.skin,
  });

  final List<BaseItemDto> albums;
  final String? serverUrl;
  final MusicPlayerSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (albums.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.noAlbums, style: TextStyle(color: skin.textSecondary)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 20,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final album = albums[i];
        return PosterCard(
          item: album,
          serverUrl: serverUrl,
          onTap: () => context.push('/music/album/${album.id}', extra: album),
        );
      },
    );
  }
}
