import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/game_bg_player.dart';
import '../../../../core/settings/game_bg_music_controller.dart';

/// Envuelve la rama de juego online y gestiona la música de fondo.
/// Entra en /games o /games/* -> shuffle + play continuo (volumen 0.5).
/// Sale de /games* -> corta. Re-entrar hace shuffle nuevo.
/// Toggle mute via gameBgMutedProvider.
class GameMusicScope extends ConsumerStatefulWidget {
  const GameMusicScope({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<GameMusicScope> createState() => _GameMusicScopeState();
}

class _GameMusicScopeState extends ConsumerState<GameMusicScope> with WidgetsBindingObserver {
  bool _inside = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // asegura corte si scope se destruye
    GameBgPlayer.instance.leave();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      GameBgPlayer.instance.pauseForExternal();
    } else if (state == AppLifecycleState.resumed) {
      GameBgPlayer.instance.resumeIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(gameBgMutedProvider, (prev, muted) {
      GameBgPlayer.instance.setMuted(muted);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocation());
    return widget.child;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkLocation();
  }

  bool _isInsideGames(String loc) {
    if (loc == '/games') return true;
    if (loc.startsWith('/games/platform/')) return true;
    if (loc.startsWith('/games/platform')) return true;
    return false;
  }

  void _checkLocation() {
    if (!mounted) return;
    String loc;
    try {
      loc = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      try {
        loc = GoRouter.of(context).routeInformationProvider.value.uri.path;
      } catch (_) {
        return;
      }
    }
    final nowInside = _isInsideGames(loc);
    if (nowInside != _inside) {
      _inside = nowInside;
      if (_inside) {
        final muted = ref.read(gameBgMutedProvider);
        GameBgPlayer.instance.setMuted(muted);
        GameBgPlayer.instance.enter();
      } else {
        GameBgPlayer.instance.leave();
      }
    }
  }
}
