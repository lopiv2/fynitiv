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
  });

  final String tab;
  final String search;
  final int? selGameId;
  final String? selGameName;
  final String? facetValue;

  JukeboxUiState copyWith({
    String? tab,
    String? search,
    int? selGameId,
    String? selGameName,
    String? facetValue,
    bool clearGame = false,
    bool clearFacet = false,
  }) {
    return JukeboxUiState(
      tab: tab ?? this.tab,
      search: search ?? this.search,
      selGameId: clearGame ? null : (selGameId ?? this.selGameId),
      selGameName: clearGame ? null : (selGameName ?? this.selGameName),
      facetValue: clearFacet ? null : (facetValue ?? this.facetValue),
    );
  }
}

class JukeboxUiController extends Notifier<JukeboxUiState> {
  @override
  JukeboxUiState build() {
    ref.keepAlive();
    return const JukeboxUiState();
  }

  void setTab(String tab) {
    // Cambiar tab limpia selección de juego/facet (como _pickTab)
    state = JukeboxUiState(tab: tab, search: state.search);
  }

  void setSearch(String search) => state = state.copyWith(search: search);

  void selectGame(int id, String name) => state = state.copyWith(selGameId: id, selGameName: name, clearFacet: true);

  void selectFacet(String value) => state = state.copyWith(facetValue: value, clearGame: true);

  void clearGame() => state = state.copyWith(clearGame: true);

  void clearFacet() => state = state.copyWith(clearFacet: true);
}

final jukeboxUiProvider = NotifierProvider<JukeboxUiController, JukeboxUiState>(JukeboxUiController.new);
