import 'package:material_ui/material_ui.dart';

import '../../../../../core/skin/music_player_skin.dart';

/// Header reutilizable tematizable.
class MusicSectionHeader extends StatelessWidget {
  const MusicSectionHeader({
    super.key,
    required this.title,
    required this.skin,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final MusicPlayerSkin skin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: skin.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(color: skin.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
