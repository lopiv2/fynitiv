import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSidebarExpandedKey = 'jellyfin.sidebar_expanded';

/// Estado de la barra lateral del dashboard.
class SidebarState {
  const SidebarState({
    required this.expanded,
    this.forceCollapsed = false,
  });

  final bool expanded;

  /// Colapsada por navegación en TV (al enfocar el contenido principal).
  final bool forceCollapsed;

  bool get visible => expanded && !forceCollapsed;

  SidebarState copyWith({bool? expanded, bool? forceCollapsed}) {
    return SidebarState(
      expanded: expanded ?? this.expanded,
      forceCollapsed: forceCollapsed ?? this.forceCollapsed,
    );
  }
}

class SidebarController extends Notifier<SidebarState> {
  @override
  SidebarState build() {
    _load();
    return const SidebarState(expanded: true);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_kSidebarExpandedKey);
    if (stored != null) {
      state = SidebarState(expanded: stored);
    }
  }

  /// Alterna expandida/colapsada (solo escritorio) y persiste.
  Future<void> toggle() async {
    final next = SidebarState(
      expanded: !state.expanded,
      forceCollapsed: false,
    );
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSidebarExpandedKey, next.expanded);
  }

  /// Expande la barra (usado al navegar hacia la izquierda en TV).
  void expand() => state = state.copyWith(forceCollapsed: false);

  /// Colapsa al enfocar el contenido principal (TV).
  void collapseForContent() => state = state.copyWith(forceCollapsed: true);
}

final sidebarControllerProvider =
    NotifierProvider<SidebarController, SidebarState>(SidebarController.new);
