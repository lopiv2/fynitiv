import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../l10n/app_localizations.dart';
import '../application/library_providers.dart';
import 'widgets/content_row.dart';

/// Dashboard de la app: filas de contenido tipo Prime/Disney.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final resume = ref.watch(resumeItemsProvider);
    final latest = ref.watch(latestItemsProvider);
    final views = ref.watch(userViewsProvider);
    final skin = ref.watch(skinControllerProvider).value;

    return Scaffold(
      body: DashboardBackground(
        child: ListView(
          padding: const EdgeInsets.only(top: 54, bottom: 24),
          children: [
            if (skin?.showContinueRow ?? true)
              ContentRow(
                title: l10n.continueWatching,
                items: resume.value ?? const [],
                serverUrl: serverUrl,
              ),
            if (skin?.showNewReleasesRow ?? true)
              ContentRow(
                title: l10n.newReleases,
                items: latest.value ?? const [],
                serverUrl: serverUrl,
              ),
            for (final view in (views.value ?? const <BaseItemDto>[]).take(4))
              ContentRow(
                title: view.name ?? '',
                items:
                    ref.watch(libraryItemsProvider(view.id ?? '')).value ??
                    const [],
                serverUrl: serverUrl,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
