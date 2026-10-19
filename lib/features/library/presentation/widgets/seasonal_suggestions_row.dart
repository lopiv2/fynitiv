import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/seasonal/active_seasonal_event.dart';
import '../../../../core/seasonal/seasonal_event.dart';
import '../../../../core/settings/seasonal_suggestions_controller.dart';
import '../../../../core/skin/home_scroll.dart';
import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/scroll_title.dart';
import '../../../../core/widgets/seasonal_card_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/library_providers.dart';
import '../../application/seasonal_suggestions_provider.dart';
import '../../domain/seasonal_suggestion.dart';
import 'content_row.dart';

/// Fila de contenido temático, activa únicamente en fechas seleccionadas.
///
/// [scroll] es la config de la sección (`LayoutSection.seasonal(...)`) y define
/// el aspecto de las tarjetas (poster/backdrop, meta, viñeta, logo, orden…),
/// igual que el resto de filas. El título es siempre el de la temática activa.
class SeasonalSuggestionsRow extends ConsumerWidget {
  const SeasonalSuggestionsRow({super.key, this.scroll});

  final HomeScroll? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La estación elegida manualmente (Apariencia o barra de debug) sustituye
    // a la del calendario, pero el interruptor de sugerencias sigue mandando.
    final enabled = ref.watch(seasonalSuggestionsEnabledProvider).value ?? true;
    if (!enabled) return const SizedBox.shrink();

    final event = ref.watch(activeSeasonalEventProvider);
    if (event == null) return const SizedBox.shrink();

    final cfg = scroll;
    final sort = cfg?.sort ?? HomeScrollSort.random;
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(seasonalSuggestionItemsProvider((event, sort)));
    final skin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);
    final title = seasonalEventTitle(l10n, event);
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
            showPlayIcon: cfg?.showPlayIcon ?? true,
            highlightTitleOnHover: cfg?.highlightTitleOnHover ?? false,
            cardBorderRadius: cfg?.cardBorderRadius,
            hoverScale: cfg?.hoverScale,
            cornerBadge: SeasonalCardBadge(asset: seasonalBadgeAsset(event)),
            onItemTap: (item) => _openItem(context, item, cfg),
            onItemImageTap: (item) => _openDetails(context, item),
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

  /// Tap de la tarjeta: detalle o reproducción según `tapAction` del scroll.
  void _openItem(BuildContext context, BaseItemDto item, HomeScroll? cfg) {
    if (cfg?.tapAction == HomeScrollTapAction.details) {
      _openDetails(context, item);
      return;
    }
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) return;
    context.push('/player/$itemId', extra: item);
  }

  void _openDetails(BuildContext context, BaseItemDto item) {
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) return;
    context.push('/home/details/$itemId', extra: item);
  }
}
