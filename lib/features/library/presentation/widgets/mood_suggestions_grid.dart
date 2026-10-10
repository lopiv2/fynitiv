import 'dart:async';
import 'dart:math';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/scroll_title.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/library_providers.dart';
import '../../application/mood_providers.dart';
import '../../domain/mood_suggestion.dart';

String _phraseForMood(AppLocalizations l10n, MoodKey key, int seed) {
  final phrases = moodPhrases(l10n, key);
  return phrases[Random(seed).nextInt(phrases.length)];
}

/// Grid de sugerencias por estado de ánimo (sin scroll lateral).
///
/// Cada botón va coloreado según el mood y, al pulsarlo, abre el detalle de
/// una película o serie aleatoria acorde a los géneros de ese estado.
class MoodSuggestionsGrid extends ConsumerStatefulWidget {
  const MoodSuggestionsGrid({super.key});

  @override
  ConsumerState<MoodSuggestionsGrid> createState() =>
      _MoodSuggestionsGridState();
}

class _MoodSuggestionsGridState extends ConsumerState<MoodSuggestionsGrid> {
  GoRouter? _router;
  bool _wasOnHome = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToRoute());
  }

  void _listenToRoute() {
    if (!mounted) return;
    _router = GoRouter.of(context);
    _wasOnHome = _currentPath == '/home';
    _router!.routerDelegate.addListener(_onRouteChanged);
  }

  String get _currentPath =>
      _router?.routeInformationProvider.value.uri.path ?? '';

  void _onRouteChanged() {
    if (!mounted) return;
    final isOnHome = _currentPath == '/home';
    if (!_wasOnHome && isOnHome) {
      ref.read(moodRefreshProvider.notifier).refresh();
    }
    _wasOnHome = isOnHome;
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  Future<void> _openRandom(MoodSuggestion mood) async {
    final l10n = AppLocalizations.of(context)!;
    final client = ref.read(jellyfinClientProvider);
    final userId = ref.read(currentUserIdProvider);
    if (client == null || userId == null) return;

    unawaited(
      EasyLoading.show(
        status: l10n.moodLoading,
        maskType: EasyLoadingMaskType.none,
      ),
    );
    BaseItemDto? item;
    try {
      item = await fetchRandomMoodItem(
        client: client,
        userId: userId,
        genres: mood.genres,
      );
    } catch (_) {
      item = null;
    } finally {
      unawaited(EasyLoading.dismiss());
    }
    if (!mounted) return;
    if (item == null || (item.id ?? '').isEmpty) {
      unawaited(
        EasyLoading.showInfo(
          l10n.moodNoResults,
          maskType: EasyLoadingMaskType.none,
          dismissOnTap: true,
        ),
      );
      return;
    }
    context.push('/home/details/${item.id}', extra: item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final seed = ref.watch(moodRefreshProvider);
    final Map<MoodKey, String?> backdrops =
        ref.watch(moodBackdropsProvider).value ?? const <MoodKey, String?>{};
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ScrollTitle(title: l10n.moodSectionTitle),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns = (constraints.maxWidth / 320).floor().clamp(2, 4);
              final buttonWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Wrap(
                  spacing: spacing,
                  alignment: WrapAlignment.center,
                  runSpacing: spacing,
                  children: [
                    for (final (index, mood) in kMoodSuggestions.indexed)
                      _MoodButton(
                        mood: mood,
                        width: buttonWidth,
                        label: _phraseForMood(l10n, mood.key, seed + index),
                        backdropUrl: backdrops[mood.key],
                        onTap: () => _openRandom(mood),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.mood,
    required this.width,
    required this.label,
    required this.backdropUrl,
    required this.onTap,
  });

  final MoodSuggestion mood;
  final double width;
  final String label;
  final String? backdropUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = mood.color;
    // Degradado por mood: claro -> color -> oscuro.
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, Colors.white, 0.20)!.withValues(alpha: 0.85),
        base.withValues(alpha: 0.85),
        Color.lerp(base, Colors.black, 0.40)!.withValues(alpha: 0.85),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
    final tint = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, Colors.white, 0.20)!.withValues(alpha: 0.56),
        base.withValues(alpha: 0.48),
        Color.lerp(base, Colors.black, 0.40)!.withValues(alpha: 0.58),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
    return SizedBox(
      width: width,
      height: 132,
      child: AppHover(
        effect: AppHoverEffect.scaleHighlightOutline,
        config: AppHoverConfig.scaleHighlightOutline(
          radius: const BorderRadius.all(Radius.circular(18)),
          highlightNormal: Colors.transparent,
          highlightHovered: Colors.white.withValues(alpha: 0.10),
          outlineColor: Colors.white.withValues(alpha: 0.16),
          outlineHoveredColor: Colors.white,
          outlineHoveredWidth: 1.8,
          scale: 1.03,
        ),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo degradado según el mood.
            DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
            if (backdropUrl != null)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: backdropUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  maxWidthDiskCache: 800,
                  fadeInDuration: const Duration(milliseconds: 250),
                  useOldImageOnUrlChange: true,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // El tinte conserva el color de cada mood y deja ver el backdrop.
            DecoratedBox(decoration: BoxDecoration(gradient: tint)),
            // Degradado inferior para legibilidad del texto.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x73000000)],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(mood.icon, color: Colors.white, size: 30),
                  const Spacer(),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
