import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../music/application/soloud_music_provider.dart';
import '../data/radio_icy.dart';
import 'radio_providers.dart';

/// Polling ICY solo para la emisora que está sonando.
/// Observa soloudMusicProvider (radio) y radioSelectedStationProvider.
/// Se actualiza cada 8-10s mientras siga la misma emisora.
final radioNowPlayingProvider = StreamProvider<RadioNowPlaying>((ref) async* {
  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  while (!cancelled) {
    final selected = ref.watch(radioSelectedStationProvider);
    final isPlaying = ref.watch(
      soloudMusicProvider.select(
        (s) => s.playing && s.session?.itemId == 'radio',
      ),
    );
    final streamUrl = ref.watch(
      soloudMusicProvider.select((s) => s.session?.streamUrl ?? ''),
    );
    final uuid = selected?.stationUuid;

    if (selected == null || !isPlaying || streamUrl.isEmpty || uuid == null) {
      yield const RadioNowPlaying();
      // Esperar a que cambie selección o estado de reproducción
      await Future.delayed(const Duration(seconds: 2));
      if (cancelled || !ref.mounted) return;
      continue;
    }

    // Fetch inmediato y luego cada 8s
    try {
      final current = await fetchIcyNowPlaying(streamUrl);
      if (cancelled || !ref.mounted) return;
      yield current;
    } catch (_) {
      if (cancelled || !ref.mounted) return;
      yield const RadioNowPlaying();
    }

    // Esperar 8s antes del siguiente poll, pero salir si cambia emisora o pausa
    for (var i = 0; i < 8; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (cancelled || !ref.mounted) return;
      final curSel = ref.read(radioSelectedStationProvider)?.stationUuid;
      final curPlaying = ref.read(
        soloudMusicProvider.select(
          (s) => s.playing && s.session?.itemId == 'radio',
        ),
      );
      if (curSel != uuid || !curPlaying) break;
    }
  }
});
