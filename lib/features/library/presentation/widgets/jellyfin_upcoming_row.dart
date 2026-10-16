import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/skin/home_scroll.dart';
import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/scroll_title.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/library_providers.dart';
import 'content_row.dart';

/// Fila "Próximamente": placeholders `.disc` de Jellyfin (`IsPlaceHolder`),
/// es decir contenido conocido por el servidor pero sin media todavía.
///
/// [scroll] es la config de la sección (`LayoutSection.upcoming(...)`).
class JellyfinUpcomingRow extends ConsumerWidget {
  const JellyfinUpcomingRow({super.key, this.scroll});

  final HomeScroll? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(jellyfinUpcomingProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);
    final cfg = scroll;
    final title = l10n.comingSoon;
    final useBackdrop = cfg?.cardType == HomeScrollCardType.backdrop
        ? true
        : cfg?.cardType == HomeScrollCardType.poster
        ? false
        : skin?.cardImageType == CardImageType.backdrop;

    return items.when(
      data: (values) {
        if (values.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: kBetweenSectionsGap),
          child: ContentRow(
            title: title,
            items: values,
            serverUrl: serverUrl,
            height: (skin?.homeRowHeight ?? 270) * (skin?.homeCardScale ?? 1),
            cardWidth:
                (skin?.homeCardWidth ?? 150) * (skin?.homeCardScale ?? 1),
            itemSpacing: skin?.itemSpacing,
            useBackdrop: useBackdrop,
            cardLogo: skin?.cardLogo,
            showBottomVignette: cfg?.bottomVignette ?? false,
            bottomVignetteHeight: cfg?.bottomVignetteHeight ?? 56,
            bottomVignetteOpacity: cfg?.bottomVignetteOpacity ?? 0.72,
            showMetaOverlay: cfg?.metaOverlay ?? false,
            imageSource: cfg?.imageSource,
            showNewBadge: cfg?.showNewBadge ?? false,
            showStackLogo: cfg?.showLogo ?? false,
            logoPosition: cfg?.logoPosition ?? RowLogoPosition.top,
            metaAlignment: cfg?.metaAlignment ?? RowMetaAlign.left,
            logoSize: cfg?.logoSize,
            hideTitle: cfg?.hideTitle ?? false,
            hideYear: cfg?.hideYear ?? false,
            showHoverOverlay: cfg?.showHoverOverlay ?? true,
            // Esta fila ES la de placeholders: no se excluyen.
            excludePlaceholders: false,
            // Los placeholders no se reproducen: sin icono de play.
            showPlayIcon: cfg?.showPlayIcon ?? false,
            highlightTitleOnHover: cfg?.highlightTitleOnHover ?? false,
            cardBorderRadius: cfg?.cardBorderRadius,
            hoverScale: cfg?.hoverScale,
            onItemTap: (item) => _open(context, item),
            onItemImageTap: (item) => _open(context, item),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(top: kBetweenSectionsGap, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScrollTitle(title: title),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 100, child: Center(child: AppLoader())),
          ],
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _open(BuildContext context, BaseItemDto item) {
    final id = item.id;
    if (id == null || id.isEmpty) return;
    context.push('/home/details/$id', extra: item);
  }
}
