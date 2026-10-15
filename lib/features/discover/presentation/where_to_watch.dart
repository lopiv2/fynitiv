import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../application/tmdb_providers.dart';
import '../data/tmdb_api.dart';
import '../domain/tmdb_models.dart';

/// "Dónde ver": proveedores de streaming/alquiler/compra de un título TMDB en
/// la región del usuario (datos de JustWatch vía TMDB).
class WhereToWatchSection extends ConsumerWidget {
  const WhereToWatchSection({super.key, required this.tmdb});

  final TmdbRef tmdb;

  static const _order = ['flatrate', 'free', 'ads', 'rent', 'buy'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final availability = ref.watch(tmdbWatchProvidersProvider(tmdb));
    return availability.when(
      data: (a) {
        if (a.isEmpty) {
          return Text(
            l10n.watchNoProviders,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          );
        }
        final groups = <String, List<TmdbProvider>>{};
        for (final p in a.providers) {
          groups.putIfAbsent(p.type, () => []).add(p);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final type in _order)
              if ((groups[type] ?? const []).isNotEmpty) ...[
                Text(
                  _typeLabel(l10n, type),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in groups[type]!) _ProviderChip(provider: p),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            Text(
              l10n.tmdbAttribution,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: AppLoader()),
      ),
      error: (_, _) => Text(
        l10n.watchNoProviders,
        style: const TextStyle(color: Colors.white54, fontSize: 14),
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'flatrate':
        return l10n.watchFlatrate;
      case 'free':
        return l10n.watchFree;
      case 'ads':
        return l10n.watchAds;
      case 'rent':
        return l10n.watchRent;
      case 'buy':
        return l10n.watchBuy;
      default:
        return type;
    }
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.provider});

  final TmdbProvider provider;

  @override
  Widget build(BuildContext context) {
    final logo = TmdbImages.logo(provider.logoPath);
    return AppHover(
      onTap: _open,
      effect: AppHoverEffect.scale,
      config: AppHoverConfig.scaleOnly(
        scale: 1.05,
        radius: BorderRadius.circular(10),
      ),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: logo == null
                  ? const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white54,
                      size: 28,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white54,
                          size: 28,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              provider.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    final url = provider.link;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
