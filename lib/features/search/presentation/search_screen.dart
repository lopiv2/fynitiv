import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/dashboard_background.dart';
import '../../../l10n/app_localizations.dart';
import '../application/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final results = ref.watch(searchHintsProvider(_term));

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _term = value),
                onSubmitted: (value) => setState(() => _term = value),
              ),
            ),
            Expanded(
              child: _term.isEmpty
                  ? const SizedBox.shrink()
                  : results.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (list) => list.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noResults,
                                style: const TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(24),
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final item = list[i];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.video_library_outlined,
                                    color: Colors.white70,
                                  ),
                                  title: Text(
                                    item.name ?? '',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    _subtitle(item),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () {},
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(SearchHint item) {
    final parts = <String>[
      if (item.type != null) item.type!.name,
      if (item.productionYear != null) '${item.productionYear}',
    ];
    return parts.join(' · ');
  }
}
