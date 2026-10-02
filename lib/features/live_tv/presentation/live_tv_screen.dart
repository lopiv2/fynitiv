import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_tab_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../radio/presentation/radio_screen.dart';
import '../application/live_state.dart';
import '../application/live_tv_ui.dart';
import 'live_tv_tab.dart';

/// Live TV + Radio con dos tabs (TV / Radio).
class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key});

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _prevTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _prevTabIndex = _tabController.index;
    _tabController.addListener(() {
      if (_tabController.index != _prevTabIndex &&
          !_tabController.indexIsChanging) {
        _prevTabIndex = _tabController.index;
        ref
            .read(liveTvTabActiveProvider.notifier)
            .setActive(_tabController.index == 0);
        if (mounted) setState(() {});
      } else if (_tabController.indexIsChanging &&
          _tabController.index != _prevTabIndex) {
        _prevTabIndex = _tabController.index;
        ref
            .read(liveTvTabActiveProvider.notifier)
            .setActive(_tabController.index == 0);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRadioTab = _tabController.index == 1;
    final headerTitle = isRadioTab ? l10n.liveTvTabRadio : l10n.liveTvTabTv;

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          children: [
            // Header con título dinámico + tabs centrados + controles
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
              child: Row(
                children: [
                  // Izquierda: título dinámico según toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRadioTab)
                        const Icon(
                          Icons.radio_rounded,
                          color: Colors.white,
                          size: 28,
                        )
                      else
                        const FaIcon(
                          FontAwesomeIcons.towerBroadcast,
                          color: Colors.white,
                          size: 28,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        headerTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  // Centro: tabs TV / Radio (widget común AppTabBar)
                  Expanded(
                    child: Center(
                      child: AppTabBar(
                        index: _tabController.index,
                        onChanged: (i) => _tabController.animateTo(i),
                        items: [
                          AppTabItem(
                            label: l10n.liveTvTabTv,
                            iconBuilder: (selected) => FaIcon(
                              FontAwesomeIcons.tv,
                              size: 24,
                              color: selected ? Colors.black : Colors.white70,
                            ),
                          ),
                          AppTabItem(
                            label: l10n.liveTvTabRadio,
                            iconBuilder: (selected) => Icon(
                              Icons.radio_rounded,
                              size: 28,
                              color: selected ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Derecha: solo retry en TV, nada en Radio (player duplicado eliminado)
                  if (!isRadioTab)
                    IconButton(
                      tooltip: l10n.retry,
                      onPressed: () =>
                          ref.read(liveTvStateProvider.notifier).reload(),
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
              child: TabBarView(
                controller: _tabController,
                children: const [LiveTvTab(), RadioScreen()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
