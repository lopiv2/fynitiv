import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../library/application/library_providers.dart' hide jellyfinClientProvider;
import '../../../core/debug/live_tv_log.dart';
import '../domain/channel.dart';
import '../domain/live_repository.dart';
import '../domain/program.dart';
import 'jellyfin_live_repository.dart';

/// Repositorio activo de Live TV (Jellyfin por ahora; se podrá extender a
/// IPTV/ErsatzTV sin tocar la UI).
final liveRepositoryProvider = Provider<LiveRepository?>((ref) {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final serverUrl = ref.watch(authServerUrlProvider);
  if (client == null || userId == null) return null;
  return JellyfinLiveRepository(
    client: client,
    userId: userId,
    serverUrl: serverUrl,
  );
});

/// Estado del Live TV.
class LiveState {
  const LiveState({
    this.channels = const [],
    this.programs = const [],
    this.selectedChannelId,
    this.query = '',
    this.showFavoritesOnly = false,
    this.group,
    this.loading = true,
    this.error,
  });

  final List<Channel> channels;
  final List<Program> programs;
  final String? selectedChannelId;
  final String query;
  final bool showFavoritesOnly;
  final String? group;
  final bool loading;
  final Object? error;

  Channel? get selectedChannel {
    if (selectedChannelId == null) return null;
    for (final c in channels) {
      if (c.id == selectedChannelId) return c;
    }
    return null;
  }

  /// Grupos disponibles (no nulos) de los canales.
  List<String> get groups {
    final seen = <String>{};
    final result = <String>[];
    for (final c in channels) {
      final g = c.group;
      if (g != null && seen.add(g)) result.add(g);
    }
    return result;
  }

  /// Programas de guía indexados por canal y ordenados por startTime (UTC).
  Map<String, List<Program>> get programsByChannel {
    final map = <String, List<Program>>{};
    for (final p in programs) {
      map.putIfAbsent(p.channelId, () => []).add(p);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return map;
  }

  /// Canales visibles tras aplicar búsqueda, favoritos y grupo.
  List<Channel> get visibleChannels {
    var result = channels;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                (c.number ?? '').contains(q),
          )
          .toList();
    }
    if (showFavoritesOnly) {
      result = result.where((c) => c.isFavorite).toList();
    }
    if (group != null) {
      result = result.where((c) => c.group == group).toList();
    }
    return result;
  }

  /// Programa de guía que está en emisión en [channelId] en el instante [time].
  Program? currentProgramOf(String channelId, DateTime time) {
    Program? best;
    for (final p in programs) {
      if (p.channelId != channelId) continue;
      if (p.contains(time)) return p;
      if (best == null || p.startTime.isAfter(best.startTime)) {
        if (!p.endTime.isBefore(time)) best = p;
      }
    }
    return best;
  }

  LiveState copyWith({
    List<Channel>? channels,
    List<Program>? programs,
    String? Function()? selectedChannelId,
    String? query,
    bool? showFavoritesOnly,
    String? Function()? group,
    bool? loading,
    Object? Function()? error,
  }) {
    return LiveState(
      channels: channels ?? this.channels,
      programs: programs ?? this.programs,
      selectedChannelId: selectedChannelId != null
          ? selectedChannelId()
          : this.selectedChannelId,
      query: query ?? this.query,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      group: group != null ? group() : this.group,
      loading: loading ?? this.loading,
      error: error != null ? error() : this.error,
    );
  }
}

/// Controlador del estado de Live TV.
class LiveTvController extends Notifier<LiveState> {
  @override
  LiveState build() {
    _load();
    return const LiveState();
  }

  Future<void> _load() async {
    final repo = ref.watch(liveRepositoryProvider);
    if (repo == null) {
      state = state.copyWith(
        loading: false,
        error: () => Exception('No live repository available'),
      );
      return;
    }
    try {
      final now = DateTime.now().toUtc();
      final results = await Future.wait([
        repo.getChannels(),
        repo.getGuide(
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 4)),
        ),
      ]);
      final channels = results[0] as List<Channel>;
      final programs = results[1] as List<Program>;
      liveTvLog(
        'Live TV cargado: ${channels.length} canales, ${programs.length} programas '
        '(jellyfin=${channels.where((c) => c.sourceType.name == 'jellyfin').length}, '
        'iptv=${channels.where((c) => c.sourceType.name == 'iptv').length}, '
        'con streamUrl=${channels.where((c) => c.streamUrl != null).length})',
      );
      state = state.copyWith(
        channels: channels,
        programs: programs,
        loading: false,
        error: null,
      );
      if (state.selectedChannelId == null && channels.isNotEmpty) {
        state = state.copyWith(selectedChannelId: () => channels.first.id);
      }
    } catch (e) {
      liveTvLog('Live TV: fallo al cargar', error: e);
      state = state.copyWith(loading: false, error: () => e);
    }
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, error: null);
    await _load();
  }

  void selectChannel(String? channelId) {
    if (channelId == state.selectedChannelId) return;
    state = state.copyWith(selectedChannelId: () => channelId);
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleFavoritesOnly() =>
      state = state.copyWith(showFavoritesOnly: !state.showFavoritesOnly);

  void setGroup(String? group) => state = state.copyWith(group: () => group);
}

final liveTvStateProvider =
    NotifierProvider<LiveTvController, LiveState>(LiveTvController.new);
