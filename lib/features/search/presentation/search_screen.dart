import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/backdrop_card.dart';
import '../application/search_providers.dart';

/// Búsqueda global del menú: al escribir muestra los resultados en
/// [BackdropCard] (misma tarjeta que el resto de la app, con sus datos
/// por tipo: año/géneros en pelis-series, S:E en episodios, artista en
/// audio...). Tocar la tarjeta reproduce con el reproductor adecuado
/// (vídeo/audio en `/player`, álbum/artista en Música, resto en detalle).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  String _term = '';

  @override
  void initState() {
    super.initState();
    // El autofocus puede dispararse durante la transición de rama (IndexedStack)
    // y perderse: se reasegura el foco en el primer frame para que el caret
    // parpadeante aparezca siempre al entrar en buscar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_searchFocus.hasFocus) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _term = _controller.text);
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    setState(() => _term = value);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _term = '');
    _searchFocus.requestFocus();
  }

  /// Detalle genérico (imagen de la tarjeta y fallback de tipos no
  /// reproducibles directamente: series, personas, libros, LiveTV...).
  void _openDetails(BaseItemDto item) {
    final id = item.id;
    if (id == null || id.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      unawaited(
        EasyLoading.showError(
          l10n.playbackFailed,
          dismissOnTap: true,
          maskType: EasyLoadingMaskType.none,
        ),
      );
      return;
    }
    if (item.type == BaseItemKind.person) {
      context.push('/home/person/$id', extra: item);
      return;
    }
    if (item.type == BaseItemKind.musicArtist) {
      final name = (item.name ?? '').trim();
      if (name.isNotEmpty) {
        context.push(
          '/music/artist/${Uri.encodeComponent(name)}',
          extra: {'jellyfin': item},
        );
        return;
      }
    }
    if (item.type == BaseItemKind.musicAlbum) {
      context.push('/music/album/$id', extra: item);
      return;
    }
    if (item.type == BaseItemKind.playlist) {
      context.push('/music/playlist/$id', extra: item);
      return;
    }
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
  }

  /// Reproducción según el tipo: vídeo y audio van al reproductor
  /// adecuado (`/player` resuelve vídeo con media_kit y audio con SoLoud),
  /// álbum/artista/lista van a su pantalla de Música y el resto al detalle.
  void _openItem(BaseItemDto item) {
    final id = item.id;
    // Debug temporal: tipo encontrado -> ruta elegida, para ajustar
    // redirecciones (qué va a player, a música o a detalle).
    debugPrint('[Search] tap ${item.type?.name} "${item.name}" id=$id');
    if (id == null || id.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      unawaited(
        EasyLoading.showError(
          l10n.playbackFailed,
          dismissOnTap: true,
          maskType: EasyLoadingMaskType.none,
        ),
      );
      return;
    }
    switch (item.type) {
      case BaseItemKind.movie:
      case BaseItemKind.episode:
      case BaseItemKind.video:
      case BaseItemKind.trailer:
      case BaseItemKind.audio:
      case BaseItemKind.musicVideo:
        context.push('/player/$id', extra: item);
      case BaseItemKind.musicAlbum:
        context.push('/music/album/$id', extra: item);
      case BaseItemKind.playlist:
        context.push('/music/playlist/$id', extra: item);
      case BaseItemKind.musicArtist:
        final name = (item.name ?? '').trim();
        if (name.isEmpty) {
          context.push('/home/details/$id', extra: item);
        } else {
          context.push(
            '/music/artist/${Uri.encodeComponent(name)}',
            extra: {'jellyfin': item},
          );
        }
      case BaseItemKind.series:
      case BaseItemKind.season:
      case BaseItemKind.person:
        _openDetails(item);
      case BaseItemKind.book:
      case BaseItemKind.audioBook:
      case BaseItemKind.tvChannel:
      case BaseItemKind.tvProgram:
      case BaseItemKind.liveTvChannel:
      case BaseItemKind.liveTvProgram:
      default:
        _openDetails(item);
    }
  }

  /// Etiqueta del tipo de resultado para el subtítulo de la tarjeta
  /// (persona, artista, canción, película...). Reutiliza cadenas
  /// existentes (`season`, `artist`) cuando encajan.
  String _typeLabel(AppLocalizations l10n, BaseItemKind? kind) {
    switch (kind) {
      case BaseItemKind.movie:
        return l10n.searchTypeMovie;
      case BaseItemKind.series:
        return l10n.searchTypeSeries;
      case BaseItemKind.season:
        return l10n.season;
      case BaseItemKind.episode:
        return l10n.searchTypeEpisode;
      case BaseItemKind.audio:
        return l10n.searchTypeSong;
      case BaseItemKind.musicAlbum:
        return l10n.searchTypeAlbum;
      case BaseItemKind.musicArtist:
        return l10n.artist;
      case BaseItemKind.person:
        return l10n.searchTypePerson;
      case BaseItemKind.playlist:
        return l10n.searchTypePlaylist;
      case BaseItemKind.book:
        return l10n.searchTypeBook;
      case BaseItemKind.audioBook:
        return l10n.searchTypeAudioBook;
      case BaseItemKind.tvChannel:
      case BaseItemKind.liveTvChannel:
        return l10n.searchTypeChannel;
      case BaseItemKind.tvProgram:
      case BaseItemKind.liveTvProgram:
        return l10n.searchTypeProgram;
      case BaseItemKind.video:
        return l10n.searchTypeVideo;
      case BaseItemKind.musicVideo:
        return l10n.searchTypeMusicVideo;
      case BaseItemKind.trailer:
        return l10n.searchTypeTrailer;
      default:
        return kind?.name ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final query = _term.trim();
    final results = ref.watch(searchHintsProvider(query));

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: TextSelectionTheme(
                data: const TextSelectionThemeData(
                  // Azul corporativo (igual que hovers/LED): el texto blanco
                  // sigue legible sobre el resaltado.
                  selectionColor: Color(0xFF2B7FFF),
                  selectionHandleColor: Colors.white,
                  cursorColor: Colors.white,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _searchFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  // Caret y selección explícitos: no dependen del tema del skin.
                  showCursor: true,
                  cursorWidth: 2,
                  cursorColor: Colors.white,
                  enableInteractiveSelection: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.clearFilter,
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                            ),
                            onPressed: _clear,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    _onChanged(value);
                  },
                  onSubmitted: _onSubmitted,
                ),
              ),
            ),
            Expanded(
              child: query.isEmpty
                  ? Center(
                      child: Text(
                        l10n.searchDescription,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : results.when(
                      loading: () => const Center(child: AppLoader()),
                      error: (e, _) => Center(
                        child: Text(
                          l10n.noResultsForQuery(query),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                      data: (list) => list.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noResultsForQuery(query),
                                style: const TextStyle(color: Colors.white54),
                              ),
                            )
                          : FocusTraversalGroup(
                              policy: ReadingOrderTraversalPolicy(),
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  12,
                                  24,
                                  24,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 325,
                                      mainAxisSpacing: 22,
                                      crossAxisSpacing: 20,
                                      // Backdrop 16:9 + título/subtítulo.
                                      childAspectRatio: 1.25,
                                    ),
                                itemCount: list.length,
                                itemBuilder: (context, i) {
                                  final item = list[i];
                                  // Hover universal en todas las tarjetas
                                  // (foco TV + escala + Enter del mando).
                                  return AppHover(
                                    effect: AppHoverEffect.scale,
                                    config: AppHoverConfig.scaleOnly(
                                      scale: 1.04,
                                      radius: BorderRadius.circular(12),
                                    ),
                                    onTap: () => _openItem(item),
                                    child: BackdropCard(
                                      item: item,
                                      serverUrl: serverUrl,
                                      hoverExtension: true,
                                      subtitleOverride: _typeLabel(
                                        l10n,
                                        item.type,
                                      ),
                                      onTap: () => _openItem(item),
                                      onImageTap: () => _openDetails(item),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
