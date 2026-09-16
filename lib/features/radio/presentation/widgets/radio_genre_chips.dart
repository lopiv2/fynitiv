import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_hover.dart';
import '../../../radio/application/radio_providers.dart';

class RadioGenreChips extends ConsumerWidget {
  const RadioGenreChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final g = _genres[i];
          return AppHover(
            effect: AppHoverEffect.scale,
            config: AppHoverConfig.scaleOnly(scale: 1.04, radius: BorderRadius.circular(12)),
            playSoundOnHover: false,
            onTap: () => ref.read(radioSearchQueryProvider.notifier).set(RadioSearchQuery(tag: g.tag)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(g.icon, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(g.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Genre {
  const _Genre(this.label, this.tag, this.icon, this.color);
  final String label;
  final String tag;
  final IconData icon;
  final Color color;
}

const _genres = [
  _Genre('Pop', 'pop', Icons.music_note_rounded, Color(0xFFB0416A)),
  _Genre('Rock', 'rock', Icons.music_note_rounded, Color(0xFF8B3A3A)),
  _Genre('Dance', 'dance', Icons.music_note_rounded, Color(0xFF6B4CA8)),
  _Genre('Electrónica', 'electronic', Icons.music_note_rounded, Color(0xFF2F7A8A)),
  _Genre('Indie', 'indie', Icons.music_note_rounded, Color(0xFF4A7A3A)),
  _Genre('Noticias', 'news', Icons.article_rounded, Color(0xFF6B4A2A)),
  _Genre('Deportes', 'sports', Icons.sports_soccer_rounded, Color(0xFF2E5A8A)),
  _Genre('Clásica', 'classical', Icons.music_note_rounded, Color(0xFF6A4A8A)),
];
