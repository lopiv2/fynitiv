import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado UI del Jukebox que sobrevive a salir/entrar de `/games/jukebox`.
/// Sin esto, al hacer pop y volver, el lateral derecho muestra `_PickHint`
/// vacío aunque antes había una selección (p. ej. Monkey Island).
class JukeboxUiState {
  const JukeboxUiState({
    this.tab = 'games',
    this.search = '',
    this.selGameId,
    this.selGameName,
    this.facetValue,
    this.shuffleEnabled = false,
  });

  final String tab;
  final String search;
  final int? selGameId;
  final String? selGameName;
  final String? facetValue;
  final bool shuffleEnabled;

  JukeboxUiState copyWith({
    String? tab,
    String? search,
    int? selGameId,
    String? selGameName,
    String? facetValue,
    bool? shuffleEnabled,
    bool clearGame = false,
    bool clearFacet = false,
  }) {
    return JukeboxUiState(
      tab: tab ?? this.tab,
      search: search ?? this.search,
      selGameId: clearGame ? null : (selGameId ?? this.selGameId),
      selGameName: clearGame ? null : (selGameName ?? this.selGameName),
      facetValue: clearFacet ? null : (facetValue ?? this.facetValue),
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
    );
  }

  bool get isSearching => search.isNotEmpty;
}

class JukeboxUiController extends Notifier<JukeboxUiState> {
  @override
  JukeboxUiState build() {
    ref.keepAlive();
    return const JukeboxUiState();
  }

  void setTab(String tab) {
    // Cambiar tab limpia selección de juego/facet y borra búsqueda
    // (prima Biblioteca sobre búsqueda, como se acordó).
    state = JukeboxUiState(tab: tab, search: '');
  }

  void setSearch(String search) => state = state.copyWith(search: search);

  void selectGame(int id, String name) =>
      state = state.copyWith(
        tab: 'games',
        selGameId: id,
        selGameName: name,
        clearFacet: true,
        search: '',
      );

  void selectFacet(String value) =>
      state = state.copyWith(facetValue: value, clearGame: true, search: '');

  void clearGame() => state = state.copyWith(clearGame: true);

  void clearFacet() => state = state.copyWith(clearFacet: true);

  void toggleShuffle() => state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
}

final jukeboxUiProvider = NotifierProvider<JukeboxUiController, JukeboxUiState>(JukeboxUiController.new);
