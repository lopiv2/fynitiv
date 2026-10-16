import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_hover.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/seerr_models.dart';

/// "Dónde ver" para un título de Seerr: plataformas donde se emite (región del
/// usuario), agrupadas por tipo, con los datos que ya devuelve Seerr.
class SeerrWatchProvidersView extends StatelessWidget {
  const SeerrWatchProvidersView({
    super.key,
    required this.providers,
    this.showAttribution = true,
  });

  final List<SeerrWatchProvider> providers;
  final bool showAttribution;

  static const _order = ['flatrate', 'buy'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (providers.isEmpty) {
      return Text(
        l10n.watchNoProviders,
        style: const TextStyle(color: Colors.white54, fontSize: 14),
      );
    }
    final groups = <String, List<SeerrWatchProvider>>{};
    for (final p in providers) {
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
        if (showAttribution)
          Text(
            l10n.tmdbAttribution,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
      ],
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

  final SeerrWatchProvider provider;

  @override
  Widget build(BuildContext context) {
    final logo = provider.logoUrl();
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
