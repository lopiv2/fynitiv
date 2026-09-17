library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../household/application/household_provider.dart';
import '../data/radio_api.dart';
import '../data/radio_station.dart';

final radioApiProvider = Provider<RadioApi>((_) => RadioApi());

// ---------------------------------------------------------------------------
// Búsqueda / listados
// ---------------------------------------------------------------------------

class RadioSearchQuery {
  const RadioSearchQuery({
    this.name = '',
    this.tag = '',
    this.country = '',
    this.language = '',
    this.order = 'votes',
  });

  final String name;
  final String tag;
  final String country;
  final String language;
  final String order;

  bool get isEmpty =>
      name.trim().isEmpty &&
      tag.trim().isEmpty &&
      country.trim().isEmpty &&
      language.trim().isEmpty;

  RadioSearchQuery copyWith({
    String? name,
    String? tag,
    String? country,
    String? language,
    String? order,
  }) =>
      RadioSearchQuery(
        name: name ?? this.name,
        tag: tag ?? this.tag,
        country: country ?? this.country,
        language: language ?? this.language,
        order: order ?? this.order,
      );

  @override
  bool operator ==(Object other) =>
      other is RadioSearchQuery &&
      other.name == name &&
      other.tag == tag &&
      other.country == country &&
      other.language == language &&
      other.order == order;

  @override
  int get hashCode => Object.hash(name, tag, country, language, order);
}

class RadioSearchQueryNotifier extends Notifier<RadioSearchQuery> {
  @override
  RadioSearchQuery build() => const RadioSearchQuery();
  void set(RadioSearchQuery q) => state = q;
}

final radioSearchQueryProvider = NotifierProvider<RadioSearchQueryNotifier, RadioSearchQuery>(
  RadioSearchQueryNotifier.new,
);

final radioTopStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final api = ref.watch(radioApiProvider);
  return api.topStations(limit: 100, offset: 0);
});

final radioSearchProvider = FutureProvider<List<RadioStation>>((ref) async {
  final api = ref.watch(radioApiProvider);
  final q = ref.watch(radioSearchQueryProvider);
  if (q.isEmpty) {
    return api.topStations(limit: 100, offset: 0);
  }
  return api.search(
    name: q.name,
    tag: q.tag,
    country: q.country,
    language: q.language,
    order: q.order,
    limit: 100,
  );
});

const kRadioPageSize = 100;

class RadioPagedArgs {
  const RadioPagedArgs({required this.query, required this.page});
  final RadioSearchQuery query;
  final int page;
  @override
  bool operator ==(Object other) =>
      other is RadioPagedArgs && other.query == query && other.page == page;
  @override
  int get hashCode => Object.hash(query, page);
}

final radioSearchPageProvider =
    FutureProvider.family<List<RadioStation>, RadioPagedArgs>((ref, args) async {
  final api = ref.watch(radioApiProvider);
  final offset = args.page * kRadioPageSize;
  if (args.query.isEmpty) {
    return api.topStations(limit: kRadioPageSize, offset: offset);
  }
  return api.search(
    name: args.query.name,
    tag: args.query.tag,
    country: args.query.country,
    language: args.query.language,
    order: args.query.order,
    limit: kRadioPageSize,
    offset: offset,
  );
});

final radioCountriesProvider = FutureProvider<List<RadioCountry>>((ref) async {
  final api = ref.watch(radioApiProvider);
  return api.countries();
});

final radioLanguagesProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.watch(radioApiProvider);
  return api.languages(limit: 200);
});

final radioTagsProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.watch(radioApiProvider);
  return api.tags(limit: 200);
});

// ---------------------------------------------------------------------------
// Favoritos + recientes (global + por household/user)
// ---------------------------------------------------------------------------

const _kRadioFavsGlobal = 'radio.favs.global';
const _kRadioRecentGlobal = 'radio.recent.global';
const _kRadioFavsStationsGlobal = 'radio.favs.stations.global';
String _kRadioFavsHousehold(String? serverId, String? houseName) =>
    'radio.favs.${serverId ?? 'no_server'}.${houseName ?? 'default'}';
String _kRadioFavsStationsHousehold(String? serverId, String? houseName) =>
    'radio.favs.stations.${serverId ?? 'no_server'}.${houseName ?? 'default'}';

// Cache local de objetos RadioStation para favoritos (evita depender de API).
class RadioFavStationsCacheController extends Notifier<Map<String, RadioStation>> {
  @override
  Map<String, RadioStation> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Global cache
    final globalRaw = prefs.getString(_kRadioFavsStationsGlobal);
    final map = <String, RadioStation>{};
    void decodeInto(String? raw) {
      if (raw == null || raw.isEmpty) return;
      try {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            final s = RadioStation.fromJson(e);
            if (s.stationUuid.isNotEmpty) map[s.stationUuid] = s;
          } else if (e is Map) {
            final s = RadioStation.fromJson(e.cast<String, dynamic>());
            if (s.stationUuid.isNotEmpty) map[s.stationUuid] = s;
          }
        }
      } catch (_) {}
    }

    decodeInto(globalRaw);
    // Household cache también se mezcla
    final house = ref.read(householdProvider);
    final houseKey = _kRadioFavsStationsHousehold(house?.serverId, house?.name);
    decodeInto(prefs.getString(houseKey));
    if (map.isNotEmpty) state = map;

    ref.listen(householdProvider, (_, next) async {
      final p = await SharedPreferences.getInstance();
      final hk = _kRadioFavsStationsHousehold(next?.serverId, next?.name);
      final nextMap = <String, RadioStation>{};
      void decodeNext(String? raw) {
        if (raw == null || raw.isEmpty) return;
        try {
          final list = jsonDecode(raw) as List;
          for (final e in list) {
            if (e is Map<String, dynamic>) {
              final s = RadioStation.fromJson(e);
              if (s.stationUuid.isNotEmpty) nextMap[s.stationUuid] = s;
            } else if (e is Map) {
              final s = RadioStation.fromJson(e.cast<String, dynamic>());
              if (s.stationUuid.isNotEmpty) nextMap[s.stationUuid] = s;
            }
          }
        } catch (_) {}
      }

      decodeNext(p.getString(_kRadioFavsStationsGlobal));
      decodeNext(p.getString(hk));
      if (nextMap.isNotEmpty) state = nextMap;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = state.values.map((s) => s.toJson()).toList();
    await prefs.setString(_kRadioFavsStationsGlobal, jsonEncode(list));
    final house = ref.read(householdProvider);
    final houseKey = _kRadioFavsStationsHousehold(house?.serverId, house?.name);
    await prefs.setString(houseKey, jsonEncode(list));
  }

  Future<void> put(RadioStation station) async {
    if (station.stationUuid.isEmpty) return;
    state = {...state, station.stationUuid: station};
    await _persist();
  }

  Future<void> remove(String uuid) async {
    if (!state.containsKey(uuid)) return;
    final next = {...state}..remove(uuid);
    state = next;
    await _persist();
  }

  Future<void> putAll(List<RadioStation> stations) async {
    if (stations.isEmpty) return;
    final next = {...state};
    for (final s in stations) {
      if (s.stationUuid.isNotEmpty) next[s.stationUuid] = s;
    }
    state = next;
    await _persist();
  }
}

final radioFavStationsCacheProvider =
    NotifierProvider<RadioFavStationsCacheController, Map<String, RadioStation>>(
  RadioFavStationsCacheController.new,
);

class RadioFavoritesState {
  const RadioFavoritesState({
    this.globalIds = const {},
    this.householdIds = const {},
    this.userIds = const {},
  });

  final Set<String> globalIds;
  final Set<String> householdIds;
  final Set<String> userIds;

  Set<String> get allIds => {...globalIds, ...householdIds, ...userIds};

  bool isFav(String uuid) => allIds.contains(uuid);
  bool isFavorite(String uuid) => isFav(uuid);

  RadioFavoritesState copyWith({
    Set<String>? globalIds,
    Set<String>? householdIds,
    Set<String>? userIds,
  }) =>
      RadioFavoritesState(
        globalIds: globalIds ?? this.globalIds,
        householdIds: householdIds ?? this.householdIds,
        userIds: userIds ?? this.userIds,
      );
}

class RadioFavoritesController extends Notifier<RadioFavoritesState> {
  @override
  RadioFavoritesState build() {
    _load();
    return const RadioFavoritesState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final global = _decodeSet(prefs.getString(_kRadioFavsGlobal));
    // household key depends on current household
    final house = ref.read(householdProvider);
    final houseKey = _kRadioFavsHousehold(house?.serverId, house?.name);
    final houseSet = _decodeSet(prefs.getString(houseKey));
    // Para user: si hay household, carga todos los miembros como favoritos de user? No: solo global+household.
    // Mantener userIds vacío inicialmente (preparado para futuro por usuario actual).
    state = RadioFavoritesState(globalIds: global, householdIds: houseSet);

    // Re-escucha cambios de household para recargar.
    ref.listen(householdProvider, (_, next) async {
      final p = await SharedPreferences.getInstance();
      final hk = _kRadioFavsHousehold(next?.serverId, next?.name);
      final hs = _decodeSet(p.getString(hk));
      state = state.copyWith(householdIds: hs);
    });
  }

  Set<String> _decodeSet(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRadioFavsGlobal, jsonEncode(state.globalIds.toList()));
    final house = ref.read(householdProvider);
    final houseKey = _kRadioFavsHousehold(house?.serverId, house?.name);
    await prefs.setString(houseKey, jsonEncode(state.householdIds.toList()));
    // userIds se persistirían por usuario actual si se usara.
  }

  Future<void> toggle(RadioStation station) async {
    final uuid = station.stationUuid;
    if (uuid.isEmpty) return;
    final isFav = state.isFav(uuid);
    final cacheNotifier = ref.read(radioFavStationsCacheProvider.notifier);
    if (isFav) {
      // Quita de todos los sets donde esté.
      state = state.copyWith(
        globalIds: {...state.globalIds}..remove(uuid),
        householdIds: {...state.householdIds}..remove(uuid),
        userIds: {...state.userIds}..remove(uuid),
      );
      await _persist();
      await cacheNotifier.remove(uuid);
    } else {
      // Añade a global y household (favoritos globales + household user).
      state = state.copyWith(
        globalIds: {...state.globalIds, uuid},
        householdIds: {...state.householdIds, uuid},
      );
      await _persist();
      await cacheNotifier.put(station);
    }
  }

  bool isFavorite(String uuid) => state.isFav(uuid);

  // Alias para compatibilidad con RadioView (isFavorite vs isFav)
  bool isFavStation(String uuid) => state.isFav(uuid);
}

final radioFavoritesProvider = NotifierProvider<RadioFavoritesController, RadioFavoritesState>(
  RadioFavoritesController.new,
);

// Lista materializada de estaciones favoritas (hidrata por uuids).
// Usa cache local para mostrar favoritos sin depender de red; la API solo refresca.
final radioFavoriteStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final favs = ref.watch(radioFavoritesProvider);
  final ids = favs.allIds.toList();
  if (ids.isEmpty) return const [];
  final cache = ref.watch(radioFavStationsCacheProvider);
  final api = ref.watch(radioApiProvider);
  // Helper para construir resultado desde cache
  List<RadioStation> fromCache() =>
      [for (final id in ids) if (cache.containsKey(id)) cache[id]!];

  // Si cache ya tiene todas las favoritas, devolver inmediato y refrescar en background.
  final cachedFull = fromCache();
  if (cachedFull.length == ids.length && cachedFull.isNotEmpty) {
    // Refresco silencioso sin bloquear UI
    Future(() async {
      try {
        final remote = await api.byUuids(ids);
        if (remote.isNotEmpty) {
          await ref.read(radioFavStationsCacheProvider.notifier).putAll(remote);
        }
      } catch (_) {}
    });
    return cachedFull;
  }

  try {
    final remote = await api.byUuids(ids);
    if (remote.isEmpty) {
      // API no devolvió nada (error o vacío) -> fallback a cache
      final cached = fromCache();
      if (cached.isNotEmpty) return cached;
      return const [];
    }
    // Mezclar: usar remoto donde esté, cache donde falte
    final remoteMap = {for (final s in remote) s.stationUuid: s};
    final merged = <RadioStation>[];
    for (final id in ids) {
      if (remoteMap.containsKey(id)) {
        merged.add(remoteMap[id]!);
      } else if (cache.containsKey(id)) {
        merged.add(cache[id]!);
      }
    }
    // Actualizar cache con lo fresco en background (no bloquea return)
    if (remote.isNotEmpty) {
      // ignore: unawaited_futures
      ref.read(radioFavStationsCacheProvider.notifier).putAll(remote);
    }
    // Si merged quedó vacío pero había cache, devolver cache
    if (merged.isEmpty) {
      final cached = fromCache();
      if (cached.isNotEmpty) return cached;
    }
    return merged;
  } catch (_) {
    final cached = fromCache();
    if (cached.isNotEmpty) return cached;
    return const [];
  }
});

// ---------------------------------------------------------------------------
// Recientes
// ---------------------------------------------------------------------------

class RadioRecentController extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRadioRecentGlobal);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      state = list;
    } catch (_) {}
  }

  Future<void> push(RadioStation station) async {
    final uuid = station.stationUuid;
    if (uuid.isEmpty) return;
    final next = [uuid, ...state.where((e) => e != uuid)].take(20).toList();
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRadioRecentGlobal, jsonEncode(next));
  }
}

final radioRecentProvider = NotifierProvider<RadioRecentController, List<String>>(
  RadioRecentController.new,
);

final radioRecentStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final recentIds = ref.watch(radioRecentProvider);
  if (recentIds.isEmpty) return const [];
  final api = ref.watch(radioApiProvider);
  try {
    final list = await api.byUuids(recentIds);
    // Mantener orden de recientes.
    final map = {for (final s in list) s.stationUuid: s};
    return [for (final id in recentIds) if (map[id] != null) map[id]!];
  } catch (_) {
    return const [];
  }
});

// ---------------------------------------------------------------------------
// Estación actual seleccionada (para UI, no player)
// ---------------------------------------------------------------------------

class RadioSelectedStationNotifier extends Notifier<RadioStation?> {
  @override
  RadioStation? build() => null;
  void set(RadioStation? s) => state = s;
}

final radioSelectedStationProvider =
    NotifierProvider<RadioSelectedStationNotifier, RadioStation?>(
  RadioSelectedStationNotifier.new,
);
