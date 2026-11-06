import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/navigation/play_routing.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../../library/application/library_providers.dart';
import '../../seerr/application/seerr_providers.dart';
import '../../seerr/domain/seerr_models.dart';
import '../../seerr/presentation/widgets/seerr_poster_grid.dart';
import '../application/franchise_providers.dart';
import '../domain/curated_franchise.dart';

/// Pantalla de una franquicia curada: sus títulos en el orden del catálogo,
/// con las películas que tienes y las que faltan (pedibles desde Seerr).
class FranchiseScreen extends ConsumerWidget {
  const FranchiseScreen({super.key, required this.franchiseId});

  final String franchiseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);
    final language = Localizations.localeOf(context).languageCode;
    final catalog = ref.watch(franchiseCatalogProvider).value;
    final franchise = catalog?.byId(franchiseId);
    final entriesAsync = ref.watch(franchiseEntriesProvider(franchiseId));
    final entries = entriesAsync.value ?? const <FranchiseEntry>[];
    final externalAsync = ref.watch(franchiseExternalProvider(franchiseId));
    final externals = externalAsync.value ?? emptyFranchiseExternal;
    final sortOrder = ref.watch(franchiseSortOrderProvider);
    final orderedEntries = sortedFranchiseEntries(entries, sortOrder);
    final owned = entries.where((e) => e.isOwned).length;

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: libraryPageTopPadding(context, skin)),
            LibraryPageHeader(
              title: franchise?.nameFor(language) ?? l10n.franchises,
              subtitle: entries.isEmpty
                  ? null
                  : l10n.franchiseProgress(owned, entries.length),
            ),
            if (orderedEntries.isNotEmpty)
              _FranchiseOrderBar(
                order: sortOrder,
                onChanged: (order) =>
                    ref.read(franchiseSortOrderProvider.notifier).set(order),
              ),
            Expanded(
              child: entriesAsync.isLoading && entries.isEmpty
                  ? const Center(child: AppLoader())
                  : entries.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noResults,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : SeerrPosterGrid(
                      entries: [
                        for (var i = 0; i < orderedEntries.length; i++)
                          _gridEntry(
                            context,
                            l10n,
                            serverUrl,
                            language,
                            orderedEntries[i],
                            external: franchiseExternalFor(
                              externals,
                              orderedEntries[i].item,
                            ),
                            ordinal: sortOrder == FranchiseSortOrder.story
                                ? i + 1
                                : null,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  SeerrPosterGridEntry _gridEntry(
    BuildContext context,
    AppLocalizations l10n,
    String? serverUrl,
    String language,
    FranchiseEntry entry, {
    SeerrMedia? external,
    int? ordinal,
  }) {
    final owned = entry.owned;
    if (owned != null) {
      return SeerrPosterGridEntry(
        item: owned,
        imageUrl: serverUrl == null ? null : itemImageUrl(serverUrl, owned),
        hoverActionLabel: l10n.details,
        hoverExtension: true,
        cornerBadge: ordinal == null ? null : _CornerBadges(ordinal: ordinal),
        onTap: () => pushDetailForType(context, owned),
      );
    }

    final media =
        external ??
        SeerrMedia(
          tmdbId: entry.item.tmdbId,
          mediaType: entry.item.type,
          title: entry.item.titleFor(language),
          date: entry.item.year?.toString(),
        );
    return SeerrPosterGridEntry(
      item: seerrMediaToBaseItem(media),
      imageUrl: media.posterUrl(),
      hoverActionLabel: l10n.seerrRequest,
      hoverExtension: true,
      cornerBadge: _CornerBadges(
        ordinal: ordinal,
        missingLabel: l10n.notInLibrary,
      ),
      onTap: () =>
          context.push('/seerr/${media.mediaType.value}/${media.tmdbId}'),
    );
  }
}

/// Barra de orden de la franquicia: estreno (por año) o cronológico.
class _FranchiseOrderBar extends StatelessWidget {
  const _FranchiseOrderBar({required this.order, required this.onChanged});

  final FranchiseSortOrder order;
  final ValueChanged<FranchiseSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _OrderChip(
            label: l10n.sortByRelease,
            selected: order == FranchiseSortOrder.release,
            onSelected: () => onChanged(FranchiseSortOrder.release),
          ),
          _OrderChip(
            label: l10n.sortChronological,
            selected: order == FranchiseSortOrder.story,
            onSelected: () => onChanged(FranchiseSortOrder.story),
          ),
        ],
      ),
    );
  }
}

class _OrderChip extends StatelessWidget {
  const _OrderChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.white.withValues(alpha: 0.14),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: BorderSide(color: selected ? Colors.white24 : Colors.white10),
      showCheckmark: false,
    );
  }
}

/// Número de posición narrativa (solo en orden cronológico) sobre un
/// triángulo de esquina como el de la referencia, y si falta, el badge de
/// "no está en tu biblioteca" debajo.
class _CornerBadges extends StatelessWidget {
  const _CornerBadges({this.ordinal, this.missingLabel});

  final int? ordinal;
  final String? missingLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El PosterCard coloca el cornerBadge a 6px de la esquina; se
        // compensa para que el triángulo quede enrasado con el borde.
        if (ordinal != null)
          Transform.translate(
            offset: const Offset(-6, -6),
            child: _OrderBadge(number: ordinal!),
          ),
        if (missingLabel != null) ...[
          if (ordinal != null) const SizedBox(height: 2),
          _MissingBadge(label: missingLabel!),
        ],
      ],
    );
  }
}

/// Triángulo de esquina con el número de la posición narrativa encima.
class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final fontSize = number >= 10 ? 26.0 : 33.0;
    return IgnorePointer(
      child: SizedBox(
        width: 76,
        height: 68,
        child: CustomPaint(
          painter: _CornerTrianglePainter(),
          child: Align(
            alignment: const Alignment(-0.62, -0.62),
            child: Text(
              '$number',
              style: TextStyle(
                color: const Color(0xFF6FE9F2),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                height: 1,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Triángulo rectángulo en la esquina superior izquierda de la tarjeta.
class _CornerTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF0B323A).withValues(alpha: 0.96),
          const Color(0xFF0B323A).withValues(alpha: 0.78),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Badge de esquina para los títulos que aún no están en Jellyfin.
class _MissingBadge extends StatelessWidget {
  const _MissingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
