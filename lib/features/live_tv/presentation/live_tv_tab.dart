import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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

/// Contenido exclusivo TV — extraído de LiveTvScreen para separar archivos.
///
/// Mantiene toda la lógica de Live TV (viewport EPG, reloj, selección de canal,
/// reproductor y guía). Se usa como tab TV dentro del shell LiveTvScreen y
/// puede reutilizarse de forma standalone si se necesita.
class LiveTvTab extends ConsumerStatefulWidget {
  const LiveTvTab({super.key});

  @override
  ConsumerState<LiveTvTab> createState() => _LiveTvTabState();
}

class _LiveTvTabState extends ConsumerState<LiveTvTab> with WidgetsBindingObserver {
  final EpgViewportController _viewport = EpgViewportController();
  late final Timer _clock = Timer.periodic(const Duration(seconds: 30), (_) {
    if (!mounted) return;
    // En la tab Radio no se reconstruye nada de Live TV.
    if (!ref.read(liveTvTabActiveProvider)) return;
    setState(() => _now = DateTime.now());
  });
  DateTime _now = DateTime.now();
  bool _playerDisposed = false;
  bool _wasOnLive = true;
  GoRouter? _router;
  // Guardar notifiers para uso seguro en dispose (ref no es seguro ahí)
  late LiveTvPlayerController _playerNotifier;
  late dynamic _stateNotifier;
  late dynamic _uiNotifier;

  @override
  void initState() {
    super.initState();
    // Capturar notifiers de forma segura para dispose
    _playerNotifier = ref.read(liveTvPlayerProvider.notifier);
    _stateNotifier = ref.read(liveTvStateProvider.notifier);
    _uiNotifier = ref.read(liveTvUiProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToRoute());
  }

  void _listenToRoute() {
    _router = GoRouter.of(context);
    _router!.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final location = GoRouterState.of(context).uri.toString();
    final isOnLive = location.startsWith('/live');
    if (_wasOnLive && !isOnLive) {
      _closeChannel();
      _playerNotifier.close();
    }
    _wasOnLive = isOnLive;
  }

  @override
  void dispose() {
    try {
      _router?.routerDelegate.removeListener(_onRouteChanged);
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    // No usar ref aquí — usar notifier guardado
    _stopPlayerSync();
    _clock.cancel();
    _viewport.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Usar notifier guardado si está disponible, si no fallback a container
    final playerState = ref.read(liveTvPlayerProvider);
    if (playerState.channelId == null) return;
    switch (state) {
      case AppLifecycleState.detached:
        _stopPlayerSync();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        try {
          _playerNotifier.player.pause();
        } catch (_) {
          try { ref.read(liveTvPlayerProvider.notifier).player.pause(); } catch (_) {}
        }
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _stopPlayerSync() {
    if (_playerDisposed) return;
    _playerDisposed = true;
    // Diferido fuera del ciclo de vida: dispose puede ocurrir durante un
    // build (transición del router) y Riverpod no permite modificar
    // providers ahí ("Tried to modify a provider while building").
    // Sin ref y sin await — seguro en dispose.
    Future(() {
      try {
        _playerNotifier.close();
      } catch (_) {
        // Fallback silencioso: no usar ref
      }
    });
  }

  void _selectChannel(Channel channel) {
    try {
      (_stateNotifier as dynamic).selectChannel(channel.id);
    } catch (_) {
      ref.read(liveTvStateProvider.notifier).selectChannel(channel.id);
    }
  }

  void _openFullscreen() {
    if (!mounted) return;
    context.push('/live/fullscreen');
  }

  void _closeChannel() {
    try {
      (_stateNotifier as dynamic).selectChannel(null);
      _playerNotifier.stop();
      (_uiNotifier as dynamic).setFloating(false);
    } catch (_) {
      try { ref.read(liveTvStateProvider.notifier).selectChannel(null); } catch (_) {}
      try { ref.read(liveTvPlayerProvider.notifier).stop(); } catch (_) {}
      try { ref.read(liveTvUiProvider.notifier).setFloating(false); } catch (_) {}
    }
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

    ref.listen<String?>(
      liveTvStateProvider.select((s) => s.selectedChannelId),
      (_, _) {
        final channel = ref.read(liveTvStateProvider).selectedChannel;
        if (channel != null) {
          ref.read(liveTvPlayerProvider.notifier).playChannel(channel);
        }
      },
    );

    if (state.loading && state.channels.isEmpty) {
      return const Center(child: AppLoader());
    }
    if (state.error != null && state.channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text('${state.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(liveTvStateProvider.notifier).reload(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Stack(
        children: [
          Row(
            children: [
              const ChannelSidebar(),
              Expanded(
                child: Column(
                  children: [
                    LivePreview(now: _now, onFullscreen: _openFullscreen, onClose: _closeChannel),
                    MiniGuide(now: _now, onSelect: _selectChannel),
                    Expanded(
                      child: EpgView(viewport: _viewport, now: _now, onSelectChannel: _selectChannel, onOpenFullscreen: _openFullscreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ui.floating) FloatingPlayer(now: _now, onExpand: _openFullscreen),
        ],
      ),
    );
  }
}
