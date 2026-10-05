import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/audio/game_bg_player.dart';
import '../../../core/audio/game_ost_player.dart';
import '../../../core/audio/app_volume_provider.dart';
import '../../music/application/soloud_music_provider.dart';
import '../../downloads/application/download_manager_provider.dart';
import '../../../core/settings/game_bg_music_controller.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../core/widgets/app_hover_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/volume_slider.dart';
import '../../../core/widgets/marquee_text.dart';
import '../../../l10n/app_localizations.dart';
import '../application/ost_providers.dart';
import '../application/romm_providers.dart';
import '../data/emulator_launcher.dart';
import '../data/platform_machine_asset_resolver.dart';
import '../domain/game_ost_track.dart';
import '../domain/romm_game.dart';
import '../domain/romm_platform.dart';
import 'widgets/game_box3d_scene_viewer.dart';
import 'widgets/game_rating_row.dart';
import 'widgets/ost_favorite_button.dart';

/// Detalle de un juego de ROMM con estilo Origin/EA (Mirror's Edge Catalyst).
/// Mantiene toda la funcionalidad previa: Play (streaming), Descargar,
/// OST (Music API de ROMM), last_played y mute.
class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with WidgetsBindingObserver {
  bool _launching = false;
  StreamSubscription<GameOstTrack?>? _ostSub;
  GameOstTrack? _currentTrack;
  bool _ostStarted = false;
  // True cuando este detalle calló el fondo para ceder la voz al OST; solo
  // entonces hay que reanudarlo al salir (sin OST el fondo sigue sonando).
  bool _bgSuspended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
      () =>
          ref.read(rommRepositoryProvider)?.markPlayed(widget.gameId).then((_) {
            ref.invalidate(rommContinuePlayingProvider);
          }),
    );
    // Corta el player global de música (Jellyfin) para que la voz SoLoud no
    // se solape. El fondo de juego NO se corta aquí: solo se cede al OST si
    // el juego tiene banda sonora (ver _maybeStartOst).
    Future.microtask(() {
      try {
        ref.read(soloudMusicProvider.notifier).stop(resumeBackground: false);
      } catch (_) {}
    });
    _ostSub = GameOstPlayer.instance.currentTrackStream.listen((track) {
      if (mounted) setState(() => _currentTrack = track);
    });
    _currentTrack = GameOstPlayer.instance.currentTrack;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ostSub?.cancel();
    GameOstPlayer.instance.stop();
    // Solo se retoma el fondo si este detalle lo había cedido al OST; si el
    // juego no tenía OST, el fondo nunca se cortó y sigue sonando.
    if (_bgSuspended) {
      GameBgPlayer.instance.resumeListsAfterDetail();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El OST sigue sonando aunque la app pierda el foco; al volver se
    // recupera por si el sistema lo cortó (llamada, etc.).
    if (state == AppLifecycleState.resumed) {
      GameOstPlayer.instance.resumeIfNeeded();
      _killResidentEmulator();
    }
  }

  /// RetroArch puede quedar residente tras cerrar (bug de ciertos cores). Si
  /// volvemos a la app con un juego marcado como "en ejecución", forzamos la
  /// limpieza; al matar el proceso, su `exitCode` completa y el estado se
  /// limpia (y dispara el sync) por el handler habitual.
  void _killResidentEmulator() {
    if (ref.read(gameRunningProvider) == null) return;
    final image = EmulatorLauncher.lastImageName;
    if (image == null || image.isEmpty) return;
    unawaited(EmulatorLauncher.killByImage(image));
  }

  /// Visor de portada 3D con `flutter_scene`.
  Widget _coverViewer(
    RommGame game,
    Map<String, String>? headers,
    double width,
    double height,
  ) {
    return GameCoverViewerScene(
      game: game,
      headers: headers,
      width: width,
      height: height,
    );
  }

  void _maybeStartOst(List<GameOstTrack> tracks) {
    if (_ostStarted) return;
    // Sin banda sonora: el fondo de juego debe seguir/hacer sonar la música
    // de la rama (idempotente si ya estaba dentro). No se marca como
    // arrancado: si una carga posterior trae pistas, el OST aún puede sonar.
    if (tracks.isEmpty) {
      GameBgPlayer.instance.enter();
      return;
    }
    // Con OST: callar el fondo y ceder la voz al OST del juego.
    _ostStarted = true;
    _bgSuspended = true;
    GameBgPlayer.instance.suspendForDetail();
    final muted = ref.read(gameBgMutedProvider);
    final repo = ref.read(rommRepositoryProvider);
    GameOstPlayer.instance.setAuthToken(repo?.token);
    GameOstPlayer.instance.setMuted(muted);
    GameOstPlayer.instance.setVolume(
      ref.read(appVolumeProvider).clamp(0, 100).toDouble() / 100,
    );
    GameOstPlayer.instance.playQueue(tracks);
  }

  Future<void> _playLocal(RommGame game) async {
    final l10n = AppLocalizations.of(context)!;
    if (_launching) return;
    if (ref.read(gameRunningProvider) == game.id) return;
    setState(() => _launching = true);
    try {
      final result = await ref.read(localPlayControllerProvider).play(
            game,
            doneMessage: l10n.gamesDownloaded,
            failMessage: l10n.downloadFailed,
            coreDownloadingMessage: l10n.gamesLocalCoreDownloading,
            syncSavesMessage: l10n.gamesLocalSyncSaves,
          );
      if (!mounted) return;
      switch (result.status) {
        case LocalPlayStatus.launched:
          final repo = ref.read(rommRepositoryProvider);
          if (repo != null) {
            unawaited(
              repo
                  .markPlayed(game.id)
                  .then((_) => ref.invalidate(rommContinuePlayingProvider)),
            );
          }
        case LocalPlayStatus.downloading:
          unawaited(EasyLoading.showInfo(l10n.gamesLocalDownloading));
        case LocalPlayStatus.noFile:
          unawaited(EasyLoading.showError(l10n.gamesLocalNoFile));
        case LocalPlayStatus.noEmulator:
          unawaited(EasyLoading.showError(l10n.gamesLocalNoEmulator));
        case LocalPlayStatus.coreMissing:
          unawaited(EasyLoading.showError(l10n.gamesLocalCoreMissing));
        case LocalPlayStatus.error:
          unawaited(
            EasyLoading.showError(
              result.message == null
                  ? l10n.gamesLocalLaunchError
                  : '${l10n.gamesLocalLaunchError}\n${result.message}',
            ),
          );
        case LocalPlayStatus.downloaded:
          break;
      }
    } catch (e) {
      if (mounted) {
        unawaited(EasyLoading.showError('${l10n.gamesLocalLaunchError}\n$e'));
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<void> _download(RommGame game) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(rommRepositoryProvider);
    unawaited(
      repo
          ?.markPlayed(game.id)
          .then((_) => ref.invalidate(rommContinuePlayingProvider)),
    );
    final fileName = game.firstFile;
    if (repo == null || fileName == null || fileName.isEmpty) {
      if (mounted) {
        unawaited(EasyLoading.showError(l10n.gamesNoFile));
      }
      return;
    }
    // El progreso/pausa/cancel vive en el gestor global (barra inferior).
    try {
      await ref
          .read(downloadManagerProvider.notifier)
          .enqueue(
            url: repo.downloadUrl(game.id, fileName),
            fileName: fileName,
            sourceLabel: game.name,
            headers: {
              if (repo.token?.trim().isNotEmpty == true)
                'Authorization': 'Bearer ${repo.token!.trim()}',
            },
            doneMessage: l10n.gamesDownloaded,
            failMessage: l10n.downloadFailed,
          );
    } catch (e) {
      if (mounted) {
        unawaited(EasyLoading.showError('${l10n.downloadFailed}\n$e'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen<bool>(gameBgMutedProvider, (prev, muted) {
      GameOstPlayer.instance.setMuted(muted);
    });
    ref.listen<AsyncValue<List<GameOstTrack>>>(
      ostTracksProvider(widget.gameId),
      (prev, next) {
        final tracks = next.value;
        if (tracks != null) _maybeStartOst(tracks);
      },
    );
    final ostAsync = ref.watch(ostTracksProvider(widget.gameId));
    ostAsync.whenData((tracks) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeStartOst(tracks),
      );
    });

    final game = ref.watch(rommGameProvider(widget.gameId));
    final token = ref.watch(rommRepositoryProvider)?.token;
    final headers = token != null && token.isNotEmpty
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;
    final skin = ref.watch(skinControllerProvider).value;
    final topPadding = libraryPageTopPadding(context, skin);
    final mediaTop = MediaQuery.of(context).padding.top;
    final barInset = (topPadding - mediaTop).clamp(0, double.infinity);

    return Scaffold(
      backgroundColor: const Color(0xFF02070D),
      body: game.when(
        loading: () => const Center(child: AppLoader()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ),
        data: (g) {
          final wide = MediaQuery.sizeOf(context).width >= 760;
          // Ancho fijo de la columna izquierda en wide (carátula y player).
          // Para ajustar anchos a futuro basta tocar este valor.
          const detailLeftW = 400.0;
          // Fondo: primera captura de ROMM; fallback a la carátula como antes.
          final coverUrl = (g.screenshotUrl?.isNotEmpty == true)
              ? g.screenshotUrl
              : g.coverLargeUrl;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop: captura del juego como hero art (igual que Mirror's Edge)
              if (coverUrl != null && coverUrl.isNotEmpty)
                Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  headers: headers,
                  errorBuilder: (_, _, _) =>
                      Container(color: const Color(0xFF0B1220)),
                )
              else
                Container(color: const Color(0xFF0B1220)),

              // Gradiente inferior oscuro para legibilidad (como en Origin)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF02070D),
                      Color(0xE602070D),
                      Color(0x9902070D),
                      Color(0x0002070D),
                    ],
                    stops: [0, 0.28, 0.56, 0.86],
                  ),
                ),
              ),
              // Velo lateral sutil
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x6602070D), Color(0x0002070D)],
                    stops: [0, 0.45],
                  ),
                ),
              ),

              SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: barInset + mediaTop + 6),
                          // Top bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: l10n.back,
                                  onPressed: () => context.pop(),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /*SizedBox(
                            height: compact ? 12 : constraints.maxHeight * 0.18,
                          ),*/

                          // Hero block: poster + info (or stacked in compact)
                          // Wide: izq = carátula + Now Playing (mismo ancho), der = info + lista
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 20 : 60,
                              0,
                              compact ? 20 : 36,
                              0,
                            ),
                            child: compact
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _coverViewer(g, headers, 200, 282),
                                      const SizedBox(height: 12),
                                      _OstNowPlayingCard(
                                        ostAsync: ostAsync,
                                        currentTrack: _currentTrack,
                                        game: g,
                                      ),
                                      const SizedBox(height: 20),
                                      _GameHeroInfo(
                                        game: g,
                                        headers: headers,
                                        launching: _launching,
                                        downloading: ref.watch(
                                          downloadManagerProvider.select(
                                            (m) => m.values.any(
                                              (t) =>
                                                  t.fileName == g.firstFile &&
                                                  t.isActive,
                                            ),
                                          ),
                                        ),
                                         onPlay: () => _playLocal(g),
                                         onDownload: () => _download(g),
                                         compact: true,
                                      ),
                                      const SizedBox(height: 18),
                                      _OriginDescription(
                                        game: g,
                                        compact: true,
                                      ),
                                      const SizedBox(height: 16),
                                      _OstTrackList(
                                        ostAsync: ostAsync,
                                        currentTrack: _currentTrack,
                                        game: g,
                                      ),
                                    ],
                                  )
                                // Wide: dos filas. Superior: carátula | datos+descripción.
                                // Inferior: player OST | lista de temas. Izquierda con
                                // ancho fijo (detailLeftW) y derecha Expanded: para
                                // ajustar anchos a futuro basta tocar detailLeftW.
                                : Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: detailLeftW,
                                            child: Center(
                                              child: _coverViewer(
                                                g,
                                                headers,
                                                340,
                                                480,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 28),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _GameHeroInfo(
                                                  game: g,
                                                  headers: headers,
                                                  launching: _launching,
                                                  downloading: ref.watch(
                                                    downloadManagerProvider
                                                        .select(
                                                          (m) => m.values.any(
                                                            (t) =>
                                                                t.fileName ==
                                                                    g.firstFile &&
                                                                t.isActive,
                                                          ),
                                                        ),
                                                  ),
                                        onPlay: () => _playLocal(g),
                                                  onDownload: () =>
                                                      _download(g),
                                                  compact: false,
                                                ),
                                                const SizedBox(height: 18),
                                                _OriginDescription(
                                                  game: g,
                                                  compact: false,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: detailLeftW,
                                            child: _OstNowPlayingCard(
                                              ostAsync: ostAsync,
                                              currentTrack: _currentTrack,
                                              game: g,
                                              compact: false,
                                            ),
                                          ),
                                          const SizedBox(width: 28),
                                          Expanded(
                                            child: _OstTrackList(
                                              ostAsync: ostAsync,
                                              currentTrack: _currentTrack,
                                              game: g,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),

                          SizedBox(height: wide ? 28 : 24),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime? d) {
  if (d == null) return '';
  final locale = AppLocalizations.of(context)?.localeName;
  return DateFormat.yMd(locale).format(d.toLocal());
}

// ---------------------------------------------------------------------------
// Poster 2D/3D: ver widgets/game_box3d_scene_viewer.dart (GameCoverViewerScene).

// ---------------------------------------------------------------------------
// Hero info: title + stats + buttons (Origin layout)

/// Cabecera del hero: logo (wheel) del juego si RomM lo envía, con fallback
/// al título en texto cuando no hay logo, sigue cargando o falla la carga.
class _GameTitle extends StatelessWidget {
  const _GameTitle({
    required this.game,
    required this.headers,
    required this.compact,
  });

  final RommGame game;
  final Map<String, String>? headers;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logo = game.logoUrl ?? '';
    if (logo.isEmpty) return _titleText();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: compact ? 300 : 460,
        maxHeight: compact ? 72 : 140,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image.network(
          logo,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          headers: headers,
          semanticLabel: game.name,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _titleText(),
          errorBuilder: (_, _, _) => _titleText(),
        ),
      ),
    );
  }

  Widget _titleText() {
    return Text(
      game.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 22 : 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
      ),
    );
  }
}

class _GameHeroInfo extends ConsumerWidget {
  const _GameHeroInfo({
    required this.game,
    required this.headers,
    required this.launching,
    required this.downloading,
    required this.onPlay,
    required this.onDownload,
    required this.compact,
  });

  final RommGame game;
  final Map<String, String>? headers;
  final bool launching;
  final bool downloading;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lastPlayedLabel = game.lastPlayed != null
        ? _formatDate(context, game.lastPlayed)
        : l10n.gameNever;
    // Time Played no disponible en RomM -> mimic Origin: Not Played / Played
    final timePlayedValue = game.lastPlayed != null ? '—' : l10n.gameNotPlayed;
    // Logo de máquina para la fila de plataforma (mismo resolver que las cards).
    final machineAsset = PlatformMachineAssetResolver.resolve(
      RommPlatform(
        id: game.platformId,
        slug: game.platformSlug,
        name: game.platformDisplayName,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GameTitle(game: game, headers: headers, compact: compact),
        const SizedBox(height: 10),
        // Fila plataforma: logo de máquina + nombre (breadcrumb bajo el título).
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (machineAsset != null)
              Image.asset(
                machineAsset,
                width: 40,
                height: 26,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (machineAsset != null) const SizedBox(width: 8),
            Flexible(
              child: Text(
                game.platformDisplayName.isEmpty
                    ? '—'
                    : game.platformDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Stats row like Origin: 4 cols
        Wrap(
          spacing: compact ? 20 : 28,
          runSpacing: 12,
          children: [
            _Stat(label: l10n.gameTimePlayed, value: timePlayedValue),
            _Stat(label: l10n.gameLastPlayed, value: lastPlayedLabel),
            _Stat(
              label: l10n.gameReleaseDate,
              value: game.firstReleaseDate != null
                  ? _formatDate(context, game.firstReleaseDate)
                  : '—',
            ),
            _Stat(
              label: l10n.platformOnDisk,
              value: formatBytes(game.fsSizeBytes),
            ),
            GameCommunityRating(average: game.averageRating),
            GameUserRating(game: game),
          ],
        ),
        const SizedBox(height: 18),
        // Buttons Origin style: Jugar (si hay archivo y la plataforma está
        // configurada para jugar) + Descargar (siempre).
        Builder(
          builder: (context) {
            final platformReady =
                ref
                    .watch(platformPlayReadinessProvider)
                    .value?[game.platformSlug] ??
                false;
            final canPlay = game.firstFile != null && platformReady;
            final busy = ref.watch(gameRunningProvider) == game.id;
            return Row(
              children: [
                if (canPlay) ...[
                  _OriginButton(
                    label: busy ? l10n.gameRunning : l10n.gameInstall,
                    primary: true,
                    loading: launching,
                    disabled: busy,
                    onTap: onPlay,
                  ),
                  const SizedBox(width: 10),
                ],
                _OriginButton(
                  label: l10n.gameOptions,
                  primary: false,
                  loading: downloading,
                  onTap: onDownload,
                ),
                if (canPlay) ...[
                  const SizedBox(width: 10),
                  _GamePlayToggles(gameId: game.id),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Toggles persistentes por juego: subtítulos y pantalla completa.
class _GamePlayToggles extends ConsumerStatefulWidget {
  const _GamePlayToggles({required this.gameId});

  final int gameId;

  @override
  ConsumerState<_GamePlayToggles> createState() => _GamePlayTogglesState();
}

class _GamePlayTogglesState extends ConsumerState<_GamePlayToggles> {
  bool _subtitles = false;
  bool _fullscreen = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final opts =
        await ref.read(gamePlayOptionsStoreProvider).read(widget.gameId);
    if (!mounted) return;
    setState(() {
      _subtitles = opts.subtitles;
      _fullscreen = opts.fullscreen;
      _loaded = true;
    });
  }

  Future<void> _toggleSubtitles() async {
    setState(() => _subtitles = !_subtitles);
    await ref
        .read(gamePlayOptionsStoreProvider)
        .setSubtitles(widget.gameId, _subtitles);
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    await ref
        .read(gamePlayOptionsStoreProvider)
        .setFullscreen(widget.gameId, _fullscreen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_loaded) return const SizedBox.shrink();
    final accent = ref.watch(skinControllerProvider).value?.accent ??
        const Color(0xFF2B7FFF);
    Widget toggle({
      required bool on,
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: on ? accent : Colors.white54),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        toggle(
          on: _subtitles,
          icon: _subtitles ? Icons.subtitles : Icons.subtitles_off,
          tooltip: l10n.gameSubtitles,
          onTap: _toggleSubtitles,
        ),
        toggle(
          on: _fullscreen,
          icon: _fullscreen ? Icons.fullscreen : Icons.fullscreen_exit,
          tooltip: l10n.gameFullscreen,
          onTap: _toggleFullscreen,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _OriginButton extends ConsumerWidget {
  const _OriginButton({
    required this.label,
    required this.primary,
    required this.onTap,
    this.loading = false,
    this.disabled = false,
  });
  final String label;
  final bool primary;
  final VoidCallback onTap;
  final bool loading;
  final bool disabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Coherencia con el resto de la app: usa AppHover / AppHoverButton.
    // Primario (Jugar) con el acento del skin, secundario (Descargar) oscuro
    // con borde de acento. Respeta el skin para radius y acento.
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    // Texto legible sobre el acento (negro solo en acentos muy claros).
    final onAccent = accent.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    final primaryHover = Color.lerp(accent, Colors.black, 0.15) ?? accent;
    final effect = primary
        ? AppHoverEffect.highlightWithScale
        : AppHoverEffect.scaleHighlightOutline;
    final config = primary
        ? AppHoverConfig(
            borderRadius: BorderRadius.circular(radius.clamp(8, 12).toDouble()),
            highlightNormal: accent,
            highlightHovered: primaryHover,
            scale: 1.04,
          )
        : AppHoverConfig.scaleHighlightOutline(
            radius: BorderRadius.circular(radius.clamp(8, 12).toDouble()),
            highlightNormal: const Color(0xFF363B43),
            highlightHovered: const Color(0xFF404752),
            outlineColor: accent.withValues(alpha: 0.45),
            outlineHoveredColor: accent,
            outlineWidth: 1,
            outlineHoveredWidth: 1.5,
            scale: 1.04,
          );

    if (disabled) {
      return Opacity(
        opacity: 0.5,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? accent : const Color(0xFF363B43),
            borderRadius: config.borderRadius,
            border: primary
                ? null
                : Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                primary ? Icons.play_arrow_rounded : Icons.download_rounded,
                size: primary ? 20 : 18,
                color: primary ? onAccent : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: primary ? onAccent : Colors.white,
                  fontSize: 14,
                  fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (loading) {
      return AppHover(
        effect: AppHoverEffect.highlightWithScale,
        config: config,
        onTap: () {},
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? accent : const Color(0xFF363B43),
            borderRadius: config.borderRadius,
            border: primary
                ? null
                : Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? onAccent : Colors.white,
            ),
          ),
        ),
      );
    }

    if (primary) {
      return AppHoverButton.filled(
        label: label,
        icon: Icons.play_arrow_rounded,
        onPressed: onTap,
        effect: effect,
        backgroundColor: accent,
        textColor: onAccent,
        iconSize: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        config: config,
        textStyle: TextStyle(
          color: onAccent,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      );
    }

    return AppHoverButton.filled(
      label: label,
      icon: Icons.download_rounded,
      onPressed: onTap,
      effect: effect,
      backgroundColor: const Color(0xFF363B43),
      textColor: Colors.white,
      iconSize: 18,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      config: config,
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Description block (overview + Key Features) — scrollable like Origin
// Altura fija + RawScrollbar para que el texto largo haga scroll independiente.

class _OriginDescription extends StatefulWidget {
  const _OriginDescription({required this.game, this.compact = false});
  final RommGame game;
  final bool compact;

  @override
  State<_OriginDescription> createState() => _OriginDescriptionState();
}

class _OriginDescriptionState extends State<_OriginDescription> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overview = (widget.game.summary ?? '').trim();
    if (overview.isEmpty) {
      return const SizedBox.shrink();
    }

    // Altura fija: en compact un poco más alta, en wide limita para no tapar el hero
    final maxH = widget.compact ? 320.0 : 200.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: RawScrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 4,
        radius: const Radius.circular(2),
        thumbColor: Colors.white38,
        trackColor: Colors.white12,
        trackBorderColor: Colors.transparent,
        child: SingleChildScrollView(
          controller: _scrollController,
          primary: false,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(right: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overview,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.2,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.gameKeyFeatures,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                overview,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Now playing (preserved)

// ---------------------------------------------------------------------------
// Sección OST: tarjeta Now Playing + lista de temas (estilo app de música).

const _ostAccent = Color(0xFF8B7CF6);

int _parseOstSecs(String? duration) {
  if (duration == null) return 0;
  final parts = duration.split(':');
  if (parts.length != 2) return 0;
  final m = int.tryParse(parts[0]) ?? 0;
  final s = int.tryParse(parts[1]) ?? 0;
  return m * 60 + s;
}

String _fmtOstSecs(int total) {
  final m = (total ~/ 60).toString();
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _OstLoadingBox extends StatelessWidget {
  const _OstLoadingBox();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: AppLoader(size: 16, color: Colors.white54),
          ),
          const SizedBox(width: 10),
          Text(
            '${l10n.nowPlaying}...',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Aviso cuando ROMM no tiene banda sonora para el juego (sin carpeta
/// `soundtrack/` junto a la ROM en el NAS).
class _OstEmptyBox extends StatelessWidget {
  const _OstEmptyBox();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded, color: Colors.white38, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.ostNoSoundtrack,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.ostNoSoundtrackHint,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OstNowPlayingCard extends ConsumerStatefulWidget {
  const _OstNowPlayingCard({
    required this.ostAsync,
    required this.currentTrack,
    required this.game,
    this.compact = false,
  });
  final AsyncValue<List<GameOstTrack>> ostAsync;
  final GameOstTrack? currentTrack;
  final RommGame game;

  /// Versión estrecha para la columna bajo la carátula (210 px).
  final bool compact;

  @override
  ConsumerState<_OstNowPlayingCard> createState() => _OstNowPlayingCardState();
}

class _OstNowPlayingCardState extends ConsumerState<_OstNowPlayingCard> {
  Timer? _ticker;
  bool _shuffle = true;
  bool _showVolume = false;

  @override
  void initState() {
    super.initState();
    _shuffle = GameOstPlayer.instance.shuffleEnabled;
    // El OST hereda el volumen universal desde el arranque.
    try {
      final global = ref.read(appVolumeProvider).clamp(0, 100).toDouble();
      GameOstPlayer.instance.setVolume(global / 100);
    } catch (_) {}
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Volumen universal: lo aplica al OST en vivo sin reescribirlo.
    ref.listen<double>(appVolumeProvider, (_, v) {
      GameOstPlayer.instance.setVolume(v.clamp(0, 100).toDouble() / 100);
    });
    final globalVol = ref.watch(appVolumeProvider).clamp(0, 100).toDouble();
    return widget.ostAsync.when(
      loading: () => const _OstLoadingBox(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        final player = GameOstPlayer.instance;
        final current = widget.currentTrack;
        final posSecs = player.position.inSeconds;
        final lenSecs = player.trackLength.inSeconds > 0
            ? player.trackLength.inSeconds
            : _parseOstSecs(current?.duration);
        final sounding = player.sounding;
        final muted = player.isMuted;
        final compact = widget.compact;
        final marqueeEnabled =
            ref.watch(skinControllerProvider).value?.titleMarqueeOnHover ??
            false;
        // Las pistas OST no traen cover: se usa la portada del juego dueño.
        final gameCover = (widget.game.coverLargeUrl?.isNotEmpty == true)
            ? widget.game.coverLargeUrl!
            : (widget.game.coverSmallUrl ?? '');
        final coverFromTrack = current?.coverUrl?.trim().isNotEmpty == true
            ? current!.coverUrl!.trim()
            : null;
        final ostCover = coverFromTrack?.isNotEmpty == true
            ? coverFromTrack!
            : gameCover;
        final repoToken =
            ref.watch(rommRepositoryProvider)?.token?.trim() ?? '';
        final ostHeaders = repoToken.isNotEmpty
            ? <String, String>{'Authorization': 'Bearer $repoToken'}
            : null;
        final coverSize = compact ? 52.0 : 64.0;
        return Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, compact ? 12 : 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.nowPlaying.toUpperCase(),
                style: const TextStyle(
                  color: _ostAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ostCover.isNotEmpty
                        ? Image.network(
                            ostCover,
                            width: coverSize * 1.5,
                            height: coverSize * 1.5,
                            fit: BoxFit.fitHeight,
                            headers: ostHeaders,
                            errorBuilder: (_, _, _) => Container(
                              width: coverSize * 1.5,
                              height: coverSize * 1.5,
                              color: const Color(0xFF1A1A1A),
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                          )
                        : Container(
                            width: coverSize * 1.5,
                            height: coverSize * 1.5,
                            color: const Color(0xFF1A1A1A),
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarqueeText(
                          key: ValueKey(current?.name ?? tracks.first.name),
                          text: current?.name ?? tracks.first.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 16 : 22,
                            fontWeight: FontWeight.w800,
                          ),
                          isHovered: true,
                          enabled: marqueeEnabled,
                          velocity: 28,
                          gap: 36,
                        ),
                        const SizedBox(height: 2),
                        MarqueeText(
                          key: ValueKey(current?.artist ?? widget.game.name),
                          text: current?.artist ?? widget.game.name,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: compact ? 12 : 14,
                          ),
                          isHovered: true,
                          enabled: marqueeEnabled,
                          velocity: 28,
                          gap: 36,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: l10n.ostShuffle,
                    onPressed: () {
                      setState(() => _shuffle = !_shuffle);
                      unawaited(player.setShuffle(_shuffle));
                    },
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: _shuffle ? _ostAccent : Colors.white54,
                      size: compact ? 18 : 20,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.ostPrevious,
                    onPressed: () => unawaited(player.previous()),
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                      size: compact ? 22 : 26,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (player.isLoading)
                    Container(
                      width: compact ? 46 : 54,
                      height: compact ? 46 : 54,
                      decoration: BoxDecoration(
                        color: _ostAccent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: AppLoader(
                        size: compact ? 22 : 26,
                        color: Colors.white,
                      ),
                    )
                  else
                    AppHover(
                      effect: AppHoverEffect.highlightWithScale,
                      config: AppHoverConfig(
                        borderRadius: BorderRadius.circular(14),
                        highlightNormal: _ostAccent,
                        highlightHovered: const Color(0xFF9D8FF7),
                        scale: 1.06,
                      ),
                      onTap: () => unawaited(player.toggle()),
                      playSoundOnHover: true,
                      child: Container(
                        width: compact ? 46 : 54,
                        height: compact ? 46 : 54,
                        decoration: BoxDecoration(
                          color: _ostAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          sounding
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: compact ? 26 : 30,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: l10n.ostNext,
                    onPressed: () => unawaited(player.next()),
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: compact ? 22 : 26,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.volume,
                    onPressed: () => setState(() => _showVolume = !_showVolume),
                    icon: Icon(
                      muted
                          ? Icons.volume_off_rounded
                          : volumeIconFor(globalVol),
                      color: _showVolume ? _ostAccent : Colors.white70,
                      size: compact ? 18 : 20,
                    ),
                  ),
                ],
              ),
              if (_showVolume) ...[
                const SizedBox(height: 4),
                VolumeSliderRow(
                  volume: globalVol,
                  onChanged: (v) =>
                      ref.read(appVolumeProvider.notifier).setVolume(v),
                  muted: muted,
                  onToggleMute: () => unawaited(player.setMuted(!muted)),
                  volumeTooltip: l10n.volume,
                  muteTooltip: l10n.ostMute,
                  unmuteTooltip: l10n.ostUnmute,
                  accent: _ostAccent,
                  compact: compact,
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      _fmtOstSecs(posSecs),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: _ostAccent,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: _ostAccent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: lenSecs > 0
                            ? posSecs.clamp(0, lenSecs).toDouble()
                            : 0,
                        max: (lenSecs > 0 ? lenSecs : 1).toDouble(),
                        onChanged: lenSecs > 0
                            ? (v) => player.seek(Duration(seconds: v.round()))
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      _fmtOstSecs(lenSecs),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OstTrackList extends ConsumerStatefulWidget {
  const _OstTrackList({
    required this.ostAsync,
    required this.currentTrack,
    required this.game,
  });
  final AsyncValue<List<GameOstTrack>> ostAsync;
  final GameOstTrack? currentTrack;
  final RommGame game;

  @override
  ConsumerState<_OstTrackList> createState() => _OstTrackListState();
}

class _OstTrackListState extends ConsumerState<_OstTrackList> {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _itemKeys = [];
  String? _lastJumpUrl;

  void _ensureKeys(int count) {
    if (_itemKeys.length == count) return;
    _itemKeys = List.generate(count, (_) => GlobalKey());
  }

  void _scrollToCurrent(List<GameOstTrack> tracks, GameOstTrack? current) {
    if (current == null || tracks.isEmpty) return;
    final idx = tracks.indexWhere((t) => t.url == current.url);
    if (idx < 0) return;
    _ensureKeys(tracks.length);
    // Un salto por pista: los rebuilds repetidos no re-apilan intentos.
    if (_lastJumpUrl == current.url) return;
    _lastJumpUrl = current.url;
    var attempts = 0;
    void tryJump() {
      if (!mounted) return;
      if (widget.currentTrack?.url != current.url) return;
      final ctx = _itemKeys[idx].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
        return;
      }
      // El item aún no está construido (ListView.builder solo monta lo
      // visible): acerca el scroll estimado para que se monte y reintenta.
      if (attempts++ < 6) {
        try {
          _scrollController.animateTo(
            (idx * 64.0).clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        } catch (_) {}
        Future.delayed(const Duration(milliseconds: 300), tryJump);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryJump());
  }

  @override
  void didUpdateWidget(covariant _OstTrackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTrack?.url != widget.currentTrack?.url) {
      widget.ostAsync.whenData((tracks) {
        _scrollToCurrent(tracks, widget.currentTrack);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return widget.ostAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tracks) {
        if (tracks.isEmpty) return const _OstEmptyBox();
        final current = widget.currentTrack;
        final totalSecs = tracks.fold<int>(
          0,
          (s, t) => s + _parseOstSecs(t.duration),
        );
        _ensureKeys(tracks.length);
        // Scroll inicial cuando entra la primera pista.
        if (current != null) {
          final snapshot = current;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrent(tracks, snapshot);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              totalSecs > 0
                  ? l10n.ostTracksHeader(tracks.length, _fmtOstSecs(totalSecs))
                  : l10n.ostTracksCount(tracks.length),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: RawScrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                thickness: 4,
                radius: const Radius.circular(2),
                thumbColor: Colors.white38,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    final isCurrent = current != null && current.url == t.url;
                    return Container(
                      key: _itemKeys[i],
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        highlightColor: Colors.white.withValues(alpha: 0.06),
                        focusColor: Colors.white.withValues(alpha: 0.08),
                        onTap: () =>
                            unawaited(GameOstPlayer.instance.playTrack(t)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 26,
                                child: isCurrent
                                    ? const Icon(
                                        Icons.graphic_eq_rounded,
                                        color: _ostAccent,
                                        size: 18,
                                      )
                                    : Text(
                                        '${i + 1}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isCurrent
                                            ? _ostAccent
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      t.artist ?? widget.game.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (t.duration != null && t.duration!.isNotEmpty)
                                Text(
                                  t.duration!,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              OstFavoriteButton(track: t),
                              PopupMenuButton<String>(
                                tooltip: l10n.more,
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                color: const Color(0xFF232B3A),
                                onSelected: (_) => unawaited(
                                  GameOstPlayer.instance.playTrack(t),
                                ),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'play',
                                    child: Text(
                                      l10n.ostPlay,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
