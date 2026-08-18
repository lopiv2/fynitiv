import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/live_state.dart';
import '../../domain/channel.dart';

/// Columna izquierda de Live TV: búsqueda, favoritos, grupos y lista de
/// canales con selección.
class ChannelSidebar extends ConsumerStatefulWidget {
  const ChannelSidebar({super.key});

  @override
  ConsumerState<ChannelSidebar> createState() => _ChannelSidebarState();
}

class _ChannelSidebarState extends ConsumerState<ChannelSidebar> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(liveTvStateProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final channels = state.visibleChannels;
    final groups = state.groups;

    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: const Border(right: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.liveTvChannels,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.liveTvFavorites,
                  onPressed: () => ref
                      .read(liveTvStateProvider.notifier)
                      .toggleFavoritesOnly(),
                  icon: Icon(
                    state.showFavoritesOnly
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: state.showFavoritesOnly
                        ? const Color(0xFFFFC107)
                        : Colors.white54,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _search,
              onChanged: (v) =>
                  ref.read(liveTvStateProvider.notifier).setQuery(v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.liveTvSearch,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white38),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text(l10n.liveTvAll, style: const TextStyle(fontSize: 11)),
                    selected: state.group == null,
                    showCheckmark: false,
                    onSelected: (_) =>
                        ref.read(liveTvStateProvider.notifier).setGroup(null),
                    selectedColor: accent.withValues(alpha: 0.30),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  for (final g in groups)
                    ChoiceChip(
                      label: Text(g, style: const TextStyle(fontSize: 11)),
                      selected: state.group == g,
                      showCheckmark: false,
                      onSelected: (_) =>
                          ref.read(liveTvStateProvider.notifier).setGroup(g),
                      selectedColor: accent.withValues(alpha: 0.30),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: channels.length,
              itemBuilder: (context, i) => _ChannelTile(
                channel: channels[i],
                selected: channels[i].id == state.selectedChannelId,
                onTap: () =>
                    ref.read(liveTvStateProvider.notifier).selectChannel(channels[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  final Channel channel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  channel.number ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 42,
                  height: 30,
                  child: channel.logoUrl != null
                      ? Image.network(
                          channel.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              _TileFallback(name: channel.name),
                        )
                      : _TileFallback(name: channel.name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (channel.isFavorite)
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileFallback extends StatelessWidget {
  const _TileFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A2568),
      alignment: Alignment.center,
      child: Text(
        (name.isEmpty ? '?' : name.substring(0, 1)).toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
