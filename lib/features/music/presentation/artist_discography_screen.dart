import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../library/application/library_providers.dart';
import 'widgets/artist_discography.dart';

/// Discografía completa del artista (destino de "Mostrar todos"):
/// mismos chips de filtro y parrilla de carátulas cuadradas.
class ArtistDiscographyScreen extends ConsumerStatefulWidget {
  const ArtistDiscographyScreen({
    super.key,
    required this.artistName,
    required this.albums,
  });

  final String artistName;
  final List<BaseItemDto> albums;

  @override
  ConsumerState<ArtistDiscographyScreen> createState() =>
      _ArtistDiscographyScreenState();
}

class _ArtistDiscographyScreenState
    extends ConsumerState<ArtistDiscographyScreen> {
  DiscographyFilter _filter = DiscographyFilter.popular;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final visible = filterDiscography(widget.albums, _filter);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          l10n.discography,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Text(
              widget.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DiscographyChips(
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      l10n.noAlbums,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, i) => AlbumCard(
                      album: visible[i],
                      serverUrl: serverUrl,
                      width: double.infinity,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
