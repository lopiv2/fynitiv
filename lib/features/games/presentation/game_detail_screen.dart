import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/audio/game_bg_player.dart';
import '../../../core/audio/khinsider_player.dart';
import '../../../core/settings/game_bg_music_controller.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../core/widgets/app_hover_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../application/khinsider_providers.dart';
import '../application/romm_providers.dart';
import '../data/khinsider/khinsider_models.dart';
import '../domain/romm_game.dart';

/// Detalle de un juego de ROMM con estilo Origin/EA (Mirror's Edge Catalyst).
/// Mantiene toda la funcionalidad previa: Play (streaming), Descargar,
/// Khinsider OST, last_played y mute.
class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with WidgetsBindingObserver {
  bool _launching = false;
  bool _downloading = false;
  StreamSubscription<KhinsiderTrack?>? _khinsiderSub;
  KhinsiderTrack? _currentTrack;
  bool _khinsiderStarted = false;
  List<KhinsiderTrack> _khinsiderQueue = [];

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
    Future.microtask(() => GameBgPlayer.instance.leave());
    _khinsiderSub = KhinsiderPlayer.instance.currentTrackStream.listen((track) {
      if (mounted) setState(() => _currentTrack = track);
    });
    _currentTrack = KhinsiderPlayer.instance.currentTrack;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _khinsiderSub?.cancel();
    KhinsiderPlayer.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      KhinsiderPlayer.instance.pauseForExternal();
    } else if (state == AppLifecycleState.resumed) {
      KhinsiderPlayer.instance.resumeIfNeeded();
    }
  }

  void _maybeStartKhinsider(List<KhinsiderTrack> tracks) {
    if (_khinsiderStarted || tracks.isEmpty) return;
    _khinsiderStarted = true;
    _khinsiderQueue = tracks;
    final muted = ref.read(gameBgMutedProvider);
    KhinsiderPlayer.instance.setMuted(muted);
    KhinsiderPlayer.instance.playQueue(tracks);
  }

  Future<void> _play(RommGame game) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    unawaited(
      repo
          .markPlayed(game.id)
          .then((_) => ref.invalidate(rommContinuePlayingProvider)),
    );
    setState(() => _launching = true);
    try {
      final host = await repo.claimStreamingSession(game.id);
      if (!mounted) return;
      if (host == null || host.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.gamesNoStreaming)));
        return;
      }
      final uri = Uri.tryParse(host);
      if (uri == null) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.gamesLaunchError)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.gamesNoFile)));
      }
      return;
    }
    setState(() => _downloading = true);
    try {
      final savePath = await _downloadPath(fileName);
      if (savePath == null) return;
      await repo.downloadGameFile(
        romId: game.id,
        fileName: fileName,
        savePath: savePath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.gamesDownloaded}\n$savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<String?> _downloadPath(String fileName) async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) return null;
      return '${dir.path}\\$fileName';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen<bool>(gameBgMutedProvider, (prev, muted) {
      KhinsiderPlayer.instance.setMuted(muted);
    });
    ref.listen<AsyncValue<List<KhinsiderTrack>>>(
      khinsiderTracksProvider(widget.gameId),
      (prev, next) {
        final tracks = next.value;
        if (tracks != null && tracks.isNotEmpty) {
          _maybeStartKhinsider(tracks);
        }
      },
    );
    final khinsiderAsync = ref.watch(khinsiderTracksProvider(widget.gameId));
    khinsiderAsync.whenData((tracks) {
      if (tracks.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybeStartKhinsider(tracks),
        );
      }
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
          final coverUrl = g.coverLargeUrl;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop: usa la portada escalada como hero art (igual que Mirror's Edge)
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

                          SizedBox(
                            height: compact ? 12 : constraints.maxHeight * 0.18,
                          ),

                          // Hero block: poster + info (or stacked in compact)
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
                                      _CoverCard(
                                        game: g,
                                        headers: headers,
                                        width: 200,
                                        height: 282,
                                      ),
                                      const SizedBox(height: 20),
                                      _GameHeroInfo(
                                        game: g,
                                        launching: _launching,
                                        downloading: _downloading,
                                        onPlay: () => _play(g),
                                        onDownload: () => _download(g),
                                        compact: true,
                                      ),
                                      const SizedBox(height: 18),
                                      _OriginDescription(
                                        game: g,
                                        compact: true,
                                      ),
                                      const SizedBox(height: 16),
                                      _NowPlayingBar(
                                        khinsiderAsync: khinsiderAsync,
                                        currentTrack: _currentTrack,
                                        queueLength: _khinsiderQueue.length,
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _CoverCard(
                                        game: g,
                                        headers: headers,
                                        width: 210,
                                        height: 296,
                                      ),
                                      const SizedBox(width: 32),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _GameHeroInfo(
                                              game: g,
                                              launching: _launching,
                                              downloading: _downloading,
                                              onPlay: () => _play(g),
                                              onDownload: () => _download(g),
                                              compact: false,
                                            ),
                                            const SizedBox(height: 18),
                                            _OriginDescription(
                                              game: g,
                                              compact: false,
                                            ),
                                            const SizedBox(height: 16),
                                            _NowPlayingBar(
                                              khinsiderAsync: khinsiderAsync,
                                              currentTrack: _currentTrack,
                                              queueLength:
                                                  _khinsiderQueue.length,
                                            ),
                                          ],
                                        ),
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

String _formatDate(DateTime? d) {
  if (d == null) return '';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  return '$dd.$mm.$yyyy';
}

// ---------------------------------------------------------------------------
// Poster

class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.game,
    required this.headers,
    required this.width,
    required this.height,
  });

  final RommGame game;
  final Map<String, String>? headers;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: game.coverLargeUrl != null && game.coverLargeUrl!.isNotEmpty
            ? Image.network(
                game.coverLargeUrl!,
                fit: BoxFit.cover,
                headers: headers,
                errorBuilder: (_, _, _) => _CoverFallback(game: game),
              )
            : _CoverFallback(game: game),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.game});
  final RommGame game;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A2568),
      alignment: Alignment.center,
      child: Text(
        game.name.isEmpty ? '?' : game.name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero info: title + stats + buttons (Origin layout)

class _GameHeroInfo extends StatelessWidget {
  const _GameHeroInfo({
    required this.game,
    required this.launching,
    required this.downloading,
    required this.onPlay,
    required this.onDownload,
    required this.compact,
  });

  final RommGame game;
  final bool launching;
  final bool downloading;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lastPlayedLabel = game.lastPlayed != null
        ? _formatDate(game.lastPlayed)
        : l10n.gameNever;
    // Time Played no disponible en RomM -> mimic Origin: Not Played / Played
    final timePlayedValue = game.lastPlayed != null ? '—' : l10n.gameNotPlayed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
        ),
        const SizedBox(height: 14),
        // Stats row like Origin: 4 cols
        Wrap(
          spacing: compact ? 20 : 28,
          runSpacing: 12,
          children: [
            _Stat(label: l10n.gameTimePlayed, value: timePlayedValue),
            _Stat(label: l10n.gameLastPlayed, value: lastPlayedLabel),
            _Stat(label: l10n.gameReleaseDate, value: '—'),
            _Stat(
              label: l10n.gamePlatform,
              value: game.platformDisplayName.isEmpty
                  ? '—'
                  : game.platformDisplayName,
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Buttons Origin style: Install (orange) + Options
        Row(
          children: [
            _OriginButton(
              label: l10n.gameInstall,
              primary: true,
              loading: launching,
              onTap: onPlay,
            ),
            const SizedBox(width: 10),
            _OriginButton(
              label: l10n.gameOptions,
              primary: false,
              loading: downloading,
              onTap: onDownload,
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
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
  });
  final String label;
  final bool primary;
  final VoidCallback onTap;
  final bool loading;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Coherencia con el resto de la app: usa AppHover / AppHoverButton.
    // Primario = filled blanco como WatchNowButton (_WideDetailButton primary),
    // Secundario = outlined translúcido como los botones secundarios de ItemDetail.
    // Respeta el skin para el radius y el acento.
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final config = primary
        ? AppHoverConfig(
            borderRadius: BorderRadius.circular(radius.clamp(8, 12).toDouble()),
            highlightNormal: Colors.white,
            highlightHovered: const Color(0xFFE6E6E6),
            scale: 1.04,
          )
        : AppHoverConfig(
            borderRadius: BorderRadius.circular(radius.clamp(8, 12).toDouble()),
            highlightNormal: const Color(0xFF363B43),
            highlightHovered: const Color(0xFF404752),
            scale: 1.04,
          );

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
            color: primary ? Colors.white : const Color(0xFF363B43),
            borderRadius: config.borderRadius,
            border: primary ? null : Border.all(color: Colors.white12),
          ),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? Colors.black : Colors.white,
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
        backgroundColor: Colors.white,
        textColor: Colors.black,
        iconSize: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        config: config,
        textStyle: const TextStyle(
          color: Colors.black,
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

class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({
    required this.khinsiderAsync,
    required this.currentTrack,
    required this.queueLength,
  });
  final AsyncValue<List<KhinsiderTrack>> khinsiderAsync;
  final KhinsiderTrack? currentTrack;
  final int queueLength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return khinsiderAsync.when(
      loading: () => Container(
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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${l10n.nowPlaying}...',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        final trackName = currentTrack?.name ?? tracks.first.name;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B7FFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Color(0xFF2B7FFF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.nowPlaying,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.nowPlayingTrack(trackName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (queueLength > 1)
                      Text(
                        '$queueLength tracks • shuffle',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.equalizer_rounded,
                color: Colors.white38,
                size: 18,
              ),
            ],
          ),
        );
      },
    );
  }
}
