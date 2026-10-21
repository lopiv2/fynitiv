import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/home_scroll.dart';
import '../../../../core/skin/layout_section.dart';
import '../../../../core/skin/skin.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/genre_localizer.dart';

/// Títulos ofrecidos en el editor de scrolls custom (contenido + libre).
/// Se excluyen los built-in (`continueWatching`, `nextUp`...) y `seasonal`
/// (su `resolve` no está implementado).
const _customTitles = [
  HomeScrollTitle.actionMovies,
  HomeScrollTitle.familyMovies,
  HomeScrollTitle.romanticMovies,
  HomeScrollTitle.animationMovies,
  HomeScrollTitle.realities,
  HomeScrollTitle.animeSeries,
  HomeScrollTitle.nostalgia,
  HomeScrollTitle.dramas,
  HomeScrollTitle.comedies,
  HomeScrollTitle.actionAdventure,
  HomeScrollTitle.musicals,
  HomeScrollTitle.foodCooking,
  HomeScrollTitle.travel,
  HomeScrollTitle.sciFi,
  HomeScrollTitle.western,
  HomeScrollTitle.crime,
  HomeScrollTitle.horror,
  HomeScrollTitle.superHero,
  HomeScrollTitle.custom,
];

/// Editor de scrolls custom del skin Custom para Inicio y VOD.
///
/// Widget genérico reutilizable: recibe el [draft] actual y emite el skin
/// actualizado vía [onChanged]. Solo debe mostrarse cuando el skin activo es
/// el preset `custom`; los colores usados son los del propio [draft]
/// (definidos en Apariencia).
class CustomSkinSection extends StatelessWidget {
  const CustomSkinSection({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final Skin draft;
  final ValueChanged<Skin> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.customSkin,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.customSkinHint,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.showBannerRow,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            Switch(
              value: draft.showNewReleasesBanner,
              onChanged: (v) => onChanged(
                draft.copyWith(showNewReleasesBanner: v),
              ),
            ),
          ],
        ),
        Text(
          l10n.showBannerRowHint,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 10),
        _GroupBlock(
          title: l10n.homeCustomRows,
          layout: draft.homeLayout,
          onChangedLayout: (layout) =>
              onChanged(draft.copyWith(homeLayout: layout)),
          onAddSlider: () {
            onChanged(
              draft.copyWith(
                homeLayout: [
                  ...draft.homeLayout,
                  const LayoutSection.featuredSlider(),
                ],
                showNewReleasesBanner: true,
              ),
            );
            unawaited(
              EasyLoading.showToast(
                l10n.sliderAdded,
                toastPosition: EasyLoadingToastPosition.bottom,
                maskType: EasyLoadingMaskType.none,
                dismissOnTap: true,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _GroupBlock(
          title: l10n.vodCustomRows,
          layout: draft.vodLayout,
          onChangedLayout: (layout) =>
              onChanged(draft.copyWith(vodLayout: layout)),
          onAddSlider: () {
            onChanged(
              draft.copyWith(
                vodLayout: [
                  ...draft.vodLayout,
                  const LayoutSection.featuredSlider(),
                ],
                showNewReleasesBanner: true,
              ),
            );
            unawaited(
              EasyLoading.showToast(
                l10n.sliderAdded,
                toastPosition: EasyLoadingToastPosition.bottom,
                maskType: EasyLoadingMaskType.none,
                dismissOnTap: true,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Bloque de un grupo (Inicio o VOD): lista las secciones `custom` y
/// `featuredSlider` con añadir / editar (solo scrolls) / eliminar / subir /
/// bajar. Las built-ins de contenido (continue, nextUp...) no se gestionan.
class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.title,
    required this.layout,
    required this.onChangedLayout,
    required this.onAddSlider,
  });

  final String title;
  final List<LayoutSection> layout;
  final ValueChanged<List<LayoutSection>> onChangedLayout;
  final VoidCallback onAddSlider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final managed = <int>[];
    for (var i = 0; i < layout.length; i++) {
      final type = layout[i].type;
      if (type == LayoutSectionType.custom ||
          type == LayoutSectionType.featuredSlider) {
        managed.add(i);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            ScaleButton(
              selectedScale: 1.05,
              borderRadius: BorderRadius.circular(12),
              onPressed: () => _openDialog(context, null, (scroll) {
                onChangedLayout([
                  ...layout,
                  LayoutSection.custom(scroll),
                ]);
                unawaited(
                  EasyLoading.showToast(
                    l10n.customRowAdded,
                    toastPosition: EasyLoadingToastPosition.bottom,
                    maskType: EasyLoadingMaskType.none,
                    dismissOnTap: true,
                  ),
                );
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      l10n.addCustomRow,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.addSlider,
              child: ScaleButton(
                selectedScale: 1.05,
                borderRadius: BorderRadius.circular(12),
                onPressed: onAddSlider,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.view_carousel_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (managed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              l10n.noCustomRows,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          )
        else
          for (final index in managed)
            if (layout[index].type == LayoutSectionType.custom)
              _CustomRowTile(
              scroll: layout[index].scroll!,
              canUp: index > 0,
              canDown: index < layout.length - 1,
              onEdit: () => _openDialog(
                context,
                layout[index].scroll,
                (scroll) {
                  final next = [...layout];
                  next[index] = LayoutSection.custom(scroll);
                  onChangedLayout(next);
                  unawaited(
                    EasyLoading.showToast(
                      l10n.customRowUpdated,
                      toastPosition: EasyLoadingToastPosition.bottom,
                      maskType: EasyLoadingMaskType.none,
                      dismissOnTap: true,
                    ),
                  );
                },
              ),
              onUp: () {
                final next = [...layout];
                final tmp = next[index - 1];
                next[index - 1] = next[index];
                next[index] = tmp;
                onChangedLayout(next);
              },
              onDown: () {
                final next = [...layout];
                final tmp = next[index + 1];
                next[index + 1] = next[index];
                next[index] = tmp;
                onChangedLayout(next);
              },
              onDelete: () {
                final next = [...layout]..removeAt(index);
                onChangedLayout(next);
                unawaited(
                  EasyLoading.showToast(
                    l10n.customRowRemoved,
                    toastPosition: EasyLoadingToastPosition.bottom,
                    maskType: EasyLoadingMaskType.none,
                    dismissOnTap: true,
                  ),
                );
              },
            )
            else
              _SliderTile(
                canUp: index > 0,
                canDown: index < layout.length - 1,
                onUp: () {
                  final next = [...layout];
                  final tmp = next[index - 1];
                  next[index - 1] = next[index];
                  next[index] = tmp;
                  onChangedLayout(next);
                },
                onDown: () {
                  final next = [...layout];
                  final tmp = next[index + 1];
                  next[index + 1] = next[index];
                  next[index] = tmp;
                  onChangedLayout(next);
                },
                onDelete: () {
                  final next = [...layout]..removeAt(index);
                  onChangedLayout(next);
                  unawaited(
                    EasyLoading.showToast(
                      l10n.sliderRemoved,
                      toastPosition: EasyLoadingToastPosition.bottom,
                      maskType: EasyLoadingMaskType.none,
                      dismissOnTap: true,
                    ),
                  );
                },
              ),
      ],
    );
  }

  Future<void> _openDialog(
    BuildContext context,
    HomeScroll? initial,
    ValueChanged<HomeScroll> onSave,
  ) async {
    final result = await showDialog<HomeScroll>(
      context: context,
      builder: (context) => _CustomRowDialog(initial: initial),
    );
    if (result != null) onSave(result);
  }
}

/// Fila del editor con el universal [AppHover] (hover + foco TV).
class _CustomRowTile extends StatelessWidget {
  const _CustomRowTile({
    required this.scroll,
    required this.canUp,
    required this.canDown,
    required this.onEdit,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
  });

  final HomeScroll scroll;
  final bool canUp;
  final bool canDown;
  final VoidCallback onEdit;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title =
        HomeScrollTitle.resolve(l10n, scroll.titleKey, scroll.customTitle);
    final subtitle = [
      scroll.genres.map((g) => localizeJellyGenre(g, l10n)).join(', '),
      scroll.types
          .map(
            (t) => t == BaseItemKind.series
                ? l10n.searchTypeSeries
                : l10n.searchTypeMovie,
          )
          .join(', '),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppHover(
        effect: AppHoverEffect.highlight,
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (canUp)
                IconButton(
                  tooltip: l10n.moveUp,
                  icon: const Icon(Icons.arrow_upward,
                      size: 18, color: Colors.white70),
                  onPressed: onUp,
                ),
              if (canDown)
                IconButton(
                  tooltip: l10n.moveDown,
                  icon: const Icon(Icons.arrow_downward,
                      size: 18, color: Colors.white70),
                  onPressed: onDown,
                ),
              IconButton(
                tooltip: l10n.delete,
                icon:
                    const Icon(Icons.delete_outline, size: 18, color: Colors.white70),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila del editor para un slider destacado: sin edición (usa los ajustes de
/// banner del skin), solo subir / bajar / eliminar. Sin [AppHover] con tap
/// para no capturar foco TV en una fila sin acción.
class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.canUp,
    required this.canDown,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
  });

  final bool canUp;
  final bool canDown;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.view_carousel_outlined,
              size: 18,
              color: Colors.white70,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.featuredSliderName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (canUp)
              IconButton(
                tooltip: l10n.moveUp,
                icon: const Icon(Icons.arrow_upward,
                    size: 18, color: Colors.white70),
                onPressed: onUp,
              ),
            if (canDown)
              IconButton(
                tooltip: l10n.moveDown,
                icon: const Icon(Icons.arrow_downward,
                    size: 18, color: Colors.white70),
                onPressed: onDown,
              ),
            IconButton(
              tooltip: l10n.delete,
              icon:
                  const Icon(Icons.delete_outline, size: 18, color: Colors.white70),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para añadir o editar un scroll custom.
class _CustomRowDialog extends StatefulWidget {
  const _CustomRowDialog({this.initial});

  final HomeScroll? initial;

  @override
  State<_CustomRowDialog> createState() => _CustomRowDialogState();
}

class _CustomRowDialogState extends State<_CustomRowDialog> {
  late HomeScrollTitle _titleKey;
  late TextEditingController _nameController;
  late Set<JellyGenre> _genres;
  late Set<BaseItemKind> _types;
  late HomeScrollCardType _cardType;
  late HomeScrollSort _sort;
  late double _limit;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    // Fila nueva: título libre y ningún género marcado. El título sigue a
    // los chips (coincidencia exacta) o se escribe a mano; así nunca nace
    // una fila "Acción" con otros géneros.
    _titleKey = initial?.titleKey ?? HomeScrollTitle.custom;
    if (!_customTitles.contains(_titleKey)) {
      _titleKey = HomeScrollTitle.custom;
    }
    _nameController =
        TextEditingController(text: initial?.customTitle ?? '');
    _genres = {...?initial?.genres};
    final initialTypes = initial?.types ??
        const [BaseItemKind.movie, BaseItemKind.series];
    _types = initialTypes
        .where((t) => t == BaseItemKind.movie || t == BaseItemKind.series)
        .toSet();
    if (_types.isEmpty) {
      _types = {BaseItemKind.movie, BaseItemKind.series};
    }
    _cardType = initial?.cardType ?? HomeScrollCardType.poster;
    _sort = initial?.sort ?? HomeScrollSort.random;
    _limit = (initial?.limit ?? 20).clamp(5, 40).toDouble();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_genres.isEmpty) {
      unawaited(
        EasyLoading.showToast(
          AppLocalizations.of(context)!.needGenre,
          toastPosition: EasyLoadingToastPosition.bottom,
          maskType: EasyLoadingMaskType.none,
          dismissOnTap: true,
        ),
      );
      return;
    }
    final initial = widget.initial;
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    // Nombre libre: si se dejó vacío, se titula con sus géneros traducidos
    // (p. ej. "Comedia, Drama") en vez de mostrar la clave en crudo.
    final freeTitle = name.isNotEmpty
        ? name
        : _genres.map((g) => localizeJellyGenre(g, l10n)).join(', ');
    Navigator.of(context).pop(
      HomeScroll(
        titleKey: _titleKey,
        customTitle: _titleKey == HomeScrollTitle.custom && freeTitle.isNotEmpty
            ? freeTitle
            : null,
        genres: _genres.toList(),
        types: _types.toList(),
        limit: _limit.round(),
        bottomVignette: initial?.bottomVignette ?? false,
        bottomVignetteHeight: initial?.bottomVignetteHeight ?? 56,
        bottomVignetteOpacity: initial?.bottomVignetteOpacity ?? 0.72,
        cardType: _cardType,
        imageSource: initial?.imageSource ?? RowImageSource.primary,
        metaOverlay: initial?.metaOverlay ?? false,
        metaAlignment: initial?.metaAlignment ?? RowMetaAlign.left,
        showNewBadge: initial?.showNewBadge ?? false,
        showLogo: initial?.showLogo ?? false,
        logoPosition: initial?.logoPosition ?? RowLogoPosition.top,
        logoSize: initial?.logoSize,
        hideTitle: initial?.hideTitle ?? false,
        hideYear: initial?.hideYear ?? false,
        showHoverOverlay: initial?.showHoverOverlay ?? true,
        showPlayIcon: initial?.showPlayIcon ?? true,
        highlightTitleOnHover: initial?.highlightTitleOnHover ?? false,
        cardBorderRadius: initial?.cardBorderRadius,
        hoverScale: initial?.hoverScale,
        showSeeMore: initial?.showSeeMore ?? true,
        sort: _sort,
        tapAction: initial?.tapAction ?? HomeScrollTapAction.details,
        yearFrom: initial?.yearFrom,
        yearTo: initial?.yearTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNew = widget.initial == null;
    return AlertDialog(
      title: Text(isNew ? l10n.addCustomRow : l10n.editCustomRow),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<HomeScrollTitle>(
                initialValue: _titleKey,
                decoration:
                    InputDecoration(labelText: l10n.customRowTitle),
                items: [
                  for (final t in _customTitles)
                    DropdownMenuItem(
                      value: t,
                      child: Text(
                        t == HomeScrollTitle.custom
                            ? l10n.customName
                            : HomeScrollTitle.resolve(l10n, t),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _titleKey = v;
                    // El título manda: autofiltra sus géneros por defecto para
                    // que lo mostrado y lo filtrado coincidan. Sin valores
                    // (títulos sin género directo) se respeta lo ya elegido.
                    final defaults = defaultGenresForTitle[v];
                    if (defaults != null && defaults.isNotEmpty) {
                      _genres = defaults.toSet();
                    }
                  });
                },
              ),
              if (_titleKey == HomeScrollTitle.custom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.customName),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.genres,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.genreNamesHint,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final genre in JellyGenre.values)
                    FilterChip(
                      label: Text(localizeJellyGenre(genre, l10n)),
                      selected: _genres.contains(genre),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _genres.add(genre);
                        } else {
                          _genres.remove(genre);
                        }
                        // Los chips mandan: si la combinación elegida coincide
                        // exactamente con un título conocido, el título la
                        // sigue (p. ej. {comedia} → "Comedias"). Se respeta
                        // el nombre libre solo si ya se escribió; las
                        // combinaciones libres sin nombre se titulan al
                        // guardar con sus géneros traducidos.
                        final match = titleForGenres(_genres);
                        if (match != null &&
                            (_titleKey != HomeScrollTitle.custom ||
                                _nameController.text.trim().isEmpty)) {
                          _titleKey = match;
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.types,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text(l10n.searchTypeMovie),
                    selected: _types.contains(BaseItemKind.movie),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _types.add(BaseItemKind.movie);
                      } else if (_types.length > 1) {
                        _types.remove(BaseItemKind.movie);
                      }
                    }),
                  ),
                  FilterChip(
                    label: Text(l10n.searchTypeSeries),
                    selected: _types.contains(BaseItemKind.series),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _types.add(BaseItemKind.series);
                      } else if (_types.length > 1) {
                        _types.remove(BaseItemKind.series);
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.cardImageType,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              SegmentedButton<HomeScrollCardType>(
                segments: [
                  ButtonSegment(
                    value: HomeScrollCardType.poster,
                    label: Text(l10n.poster),
                  ),
                  ButtonSegment(
                    value: HomeScrollCardType.backdrop,
                    label: Text(l10n.backdrop),
                  ),
                ],
                selected: {_cardType},
                onSelectionChanged: (s) =>
                    setState(() => _cardType = s.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<HomeScrollSort>(
                initialValue: _sort,
                decoration: InputDecoration(labelText: l10n.customSort),
                items: [
                  DropdownMenuItem(
                    value: HomeScrollSort.alphabetical,
                    child: Text(l10n.sortAZ),
                  ),
                  DropdownMenuItem(
                    value: HomeScrollSort.recent,
                    child: Text(l10n.sortRecent),
                  ),
                  DropdownMenuItem(
                    value: HomeScrollSort.rating,
                    child: Text(l10n.sortRating),
                  ),
                  DropdownMenuItem(
                    value: HomeScrollSort.added,
                    child: Text(l10n.sortAdded),
                  ),
                  DropdownMenuItem(
                    value: HomeScrollSort.random,
                    child: Text(l10n.sortRandom),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _sort = v);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(l10n.customLimit)),
                  Expanded(
                    flex: 2,
                    child: Slider(
                      value: _limit,
                      min: 5,
                      max: 40,
                      divisions: 7,
                      label: '${_limit.round()}',
                      onChanged: (v) => setState(() => _limit = v),
                    ),
                  ),
                  Text('${_limit.round()}'),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
