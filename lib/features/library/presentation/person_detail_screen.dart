import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/entity_portrait.dart';
import '../../../core/widgets/info_block.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../application/image_url.dart';
import '../application/library_providers.dart';
import 'widgets/content_row.dart';

/// Detalle de una persona (actor, director...): solo información,
/// sin reproducir nada. Arriba la ficha (foto, nacimiento,
/// fallecimiento, biografía) y debajo el carrusel de filmografía
/// (películas y series donde aparece).
class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({super.key, required this.person});

  final BaseItemDto person;

  void _openRelated(BuildContext context, BaseItemDto item) {
    final id = item.id;
    if (id == null || id.isEmpty) return;
    switch (item.type) {
      case BaseItemKind.movie:
      case BaseItemKind.episode:
      case BaseItemKind.video:
      case BaseItemKind.trailer:
      case BaseItemKind.audio:
      case BaseItemKind.musicVideo:
        context.push('/player/$id', extra: item);
      case BaseItemKind.season:
        final target = seriesDetailTarget(item);
        final targetId = target.id;
        if (targetId != null && targetId.isNotEmpty) {
          context.push(
            '/home/details/$targetId',
            extra: targetId == id ? item : target,
          );
        } else {
          context.push('/home/details/$id', extra: item);
        }
      default:
        context.push('/home/details/$id', extra: item);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final personId = person.id ?? '';
    // Ficha completa (biografía, fechas, lugar) vía jellyfin_dart.
    final detailAsync = ref.watch(itemDetailProvider(personId));
    final detail = detailAsync.value ?? person;
    final serverUrl = ref.watch(authServerUrlProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final topPadding = libraryPageTopPadding(context, skin);
    final filmo = ref.watch(
      personFilmographyProvider((personId, person.name ?? '')),
    );
    final filmoItems = filmo.value ?? const <BaseItemDto>[];

    final portraitUrl = serverUrl == null || personId.isEmpty
        ? null
        : itemImageUrl(serverUrl, detail, maxWidth: 600);
    final born = detail.premiereDate;
    final died = detail.endDate;
    // El lugar puede venir troceado en varios segmentos: se juntan.
    final birthplace = (detail.productionLocations ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');
    final bio = (detail.overview ?? '').trim();
    // Fecha larga sin día de semana ("10 de marzo de 1994" / "March 10, 1994").
    final fullDate = DateFormat.yMMMMd(l10n.localeName).format;
    // Debug temporal: qué fechas trae Jellyfin para esta persona.
    debugPrint(
      '[PersonDetail] "${detail.name}" fromDetail=${detailAsync.value != null} '
      'premiere=$born end=$died places=${detail.productionLocations} '
      'year=${detail.productionYear}',
    );

    final infoChildren = <Widget>[];
    final hasPlace = birthplace.isNotEmpty;
    if (born != null) {
      // Jellyfin guarda solo-fecha como medianoche local del servidor en UTC
      // (ej. 10 mar 00:00+01:00 -> 09 mar 23:00Z): al mostrar en UTC saldría
      // el día anterior, así que se pasa a hora local como hace Jellyfin web.
      final text = StringBuffer(fullDate(born.toLocal()));
      if (hasPlace) text.write(' · $birthplace');
      infoChildren.add(
        MetaLine(label: l10n.personBorn, value: text.toString()),
      );
    } else {
      // Respaldo: si no hay fecha completa, al menos año y/o lugar.
      final fallback = StringBuffer();
      final birthYear = detail.productionYear;
      if (birthYear != null) fallback.write('$birthYear');
      if (hasPlace) {
        if (fallback.isNotEmpty) fallback.write(' · ');
        fallback.write(birthplace);
      }
      if (fallback.isNotEmpty) {
        infoChildren.add(
          MetaLine(label: l10n.personBorn, value: fallback.toString()),
        );
      }
    }
    if (died != null) {
      infoChildren.add(
        MetaLine(
          label: l10n.personDied,
          value: fullDate(died.toLocal()),
        ),
      );
    }
    infoChildren.add(
      Padding(
        padding: EdgeInsets.only(top: infoChildren.isEmpty ? 0 : 16),
        child: InfoBody(
          title: l10n.personBiography,
          body: bio.isEmpty ? l10n.personNoBiography : bio,
        ),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infoChildren,
    );

    return Scaffold(
      body: DashboardBackground(
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SizedBox(height: topPadding),
              LibraryPageHeader(title: detail.name ?? ''),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 640;
                    final portrait = EntityPortrait(
                      url: portraitUrl,
                      name: detail.name ?? '',
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [portrait, const SizedBox(height: 16), info],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        portrait,
                        const SizedBox(width: 24),
                        Expanded(child: info),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 120),
              if (filmo.isLoading && filmoItems.isEmpty)
                const SizedBox(height: 220, child: Center(child: AppLoader()))
              else if (filmoItems.isNotEmpty)
                ContentRow(
                  title: l10n.personFilmography,
                  items: filmoItems,
                  serverUrl: serverUrl,
                  height: 215,
                  cardWidth: 320,
                  useBackdrop: true,
                  onItemTap: (item) => _openRelated(context, item),
                  onItemImageTap: (item) {
                    final id = item.id;
                    if (id == null || id.isEmpty) return;
                    if (item.type == BaseItemKind.season) {
                      final target = seriesDetailTarget(item);
                      final targetId = target.id;
                      if (targetId != null && targetId.isNotEmpty) {
                        context.push(
                          '/home/details/$targetId',
                          extra: targetId == id ? item : target,
                        );
                        return;
                      }
                    }
                    context.push('/home/details/$id', extra: item);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
