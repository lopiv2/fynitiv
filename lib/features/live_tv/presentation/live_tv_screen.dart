import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../application/live_state.dart';
import '../application/live_tv_player_provider.dart';
import '../application/live_tv_ui.dart';
import '../domain/channel.dart';
import 'widgets/channel_sidebar.dart';
import 'widgets/epg_view.dart';
import 'widgets/epg_viewport.dart';
import 'widgets/floating_player.dart';
import 'widgets/live_preview.dart';
import 'widgets/mini_guide.dart';

/// Live TV: sidebar de canales + preview + guía EPG + reproductor flotante.
class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key});

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen>
    with WidgetsBindingObserver {
  final EpgViewportController _viewport = EpgViewportController();
  late final Timer _clock = Timer.periodic(
    const Duration(seconds: 30),
    (_) {
      if (mounted) setState(() => _now = DateTime.now());
    },
  );
  DateTime _now = DateTime.now();
  bool _playerDisposed = false;
  bool _wasOnLive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToRoute());
  }

  void _listenToRoute() {
    final router = GoRouter.of(context);
    router.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final location = GoRouterState.of(context).uri.toString();
    final isOnLive = location.startsWith('/live');
    if (_wasOnLive && !isOnLive) {
      _closeChannel();
      ref.read(liveTvPlayerProvider.notifier).close();
    }
    _wasOnLive = isOnLive;
  }

  @override
  void dispose() {
    GoRouter.of(context).routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    _stopPlayer();
    _clock.cancel();
    _viewport.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final playerState = ref.read(liveTvPlayerProvider);
    if (playerState.channelId == null) return;

    switch (state) {
      case AppLifecycleState.detached:
        _stopPlayer();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        ref.read(liveTvPlayerProvider.notifier).player.pause();
      case AppLifecycleState.resumed:
        break;
    }
  }

  Future<void> _stopPlayer() async {
    if (_playerDisposed) return;
    _playerDisposed = true;
    await ref.read(liveTvPlayerProvider.notifier).close();
  }

  void _selectChannel(Channel channel) {
    ref.read(liveTvStateProvider.notifier).selectChannel(channel.id);
  }

  void _openFullscreen() {
    context.push('/live/fullscreen');
  }

  void _closeChannel() {
    ref.read(liveTvStateProvider.notifier).selectChannel(null);
    ref.read(liveTvPlayerProvider.notifier).stop();
    ref.read(liveTvUiProvider.notifier).setFloating(false);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final visible = ref.read(liveTvStateProvider).visibleChannels;
    final selected = ref.read(liveTvStateProvider).selectedChannelId;
    final index = visible.indexWhere((c) => c.id == selected);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (index >= 0 && index < visible.length - 1) {
          _selectChannel(visible[index + 1]);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (index > 0) _selectChannel(visible[index - 1]);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _viewport.panBy(-80, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _viewport.panBy(80, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        _openFullscreen();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (ref.read(liveTvUiProvider).floating) {
          ref.read(liveTvUiProvider.notifier).setFloating(false);
        } else {
          _closeChannel();
        }
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(liveTvStateProvider);
    final ui = ref.watch(liveTvUiProvider);

    // Reproduce el canal al seleccionarlo.
    ref.listen<String?>(
      liveTvStateProvider.select((s) => s.selectedChannelId),
      (_, _) {
        final channel = ref.read(liveTvStateProvider).selectedChannel;
        if (channel != null) {
          ref.read(liveTvPlayerProvider.notifier).playChannel(channel);
        }
      },
    );

    return Scaffold(
      body: DashboardBackground(
        child: state.loading && state.channels.isEmpty
            ? const Center(child: AppLoader())
            : state.error != null && state.channels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.live_tv_rounded,
                          color: Colors.white24,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            '${state.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => ref
                              .read(liveTvStateProvider.notifier)
                              .reload(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(l10n.retry),
                        ),
                      ],
                    ),
                  )
                : Focus(
                    autofocus: true,
                    onKeyEvent: _onKeyEvent,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
                          child: Row(
                            children: [
                              Text(
                                l10n.liveTv,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: l10n.retry,
                                onPressed: () => ref
                                    .read(liveTvStateProvider.notifier)
                                    .reload(),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  const ChannelSidebar(),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        LivePreview(
                                          now: _now,
                                          onFullscreen: _openFullscreen,
                                          onClose: _closeChannel,
                                        ),
                                        MiniGuide(
                                          now: _now,
                                          onSelect: _selectChannel,
                                        ),
                                        Expanded(
                                          child: EpgView(
                                            viewport: _viewport,
                                            now: _now,
                                            onSelectChannel: _selectChannel,
                                            onOpenFullscreen: _openFullscreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (ui.floating)
                                FloatingPlayer(
                                  now: _now,
                                  onExpand: _openFullscreen,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
