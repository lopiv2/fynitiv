import 'package:material_ui/material_ui.dart';

import '../../../core/skin/home_scroll.dart';
import '../../../l10n/app_localizations.dart';

/// Estado de ánimo para las sugerencias del Home. Cada uno mapea a un conjunto
/// de géneros de Jellyfin ([JellyGenre]) y a un color propio del botón.
enum MoodKey {
  action,
  comedy,
  drama,
  horror,
  sciFi,
  thriller,
  relax,
  adventure,
}

/// Etiqueta localizada de un estado de ánimo.
String moodLabel(AppLocalizations l10n, MoodKey key) => switch (key) {
  MoodKey.action => l10n.moodAction,
  MoodKey.comedy => l10n.moodComedy,
  MoodKey.drama => l10n.moodDrama,
  MoodKey.horror => l10n.moodHorror,
  MoodKey.sciFi => l10n.moodSciFi,
  MoodKey.thriller => l10n.moodThriller,
  MoodKey.relax => l10n.moodRelax,
  MoodKey.adventure => l10n.moodAdventure,
};

/// Definición de un botón de sugerencia por estado de ánimo.
@immutable
class MoodSuggestion {
  const MoodSuggestion({
    required this.key,
    required this.icon,
    required this.color,
    required this.genres,
  });

  final MoodKey key;
  final IconData icon;
  final Color color;

  /// Géneros de Jellyfin asociados al mood (filtro OR en la API).
  final List<JellyGenre> genres;
}

/// Estados de ánimo disponibles (orden de aparición en el grid).
const List<MoodSuggestion> kMoodSuggestions = [
  MoodSuggestion(
    key: MoodKey.action,
    icon: Icons.bolt_rounded,
    color: Color(0xFFE53935),
    genres: [JellyGenre.action, JellyGenre.adventure, JellyGenre.thriller],
  ),
  MoodSuggestion(
    key: MoodKey.comedy,
    icon: Icons.sentiment_very_satisfied_rounded,
    color: Color(0xFFFFB300),
    genres: [JellyGenre.comedy, JellyGenre.family],
  ),
  MoodSuggestion(
    key: MoodKey.drama,
    icon: Icons.theater_comedy_rounded,
    color: Color(0xFFEC407A),
    genres: [JellyGenre.drama, JellyGenre.romance],
  ),
  MoodSuggestion(
    key: MoodKey.horror,
    icon: Icons.nightlight_round,
    color: Color(0xFF7E57C2),
    genres: [JellyGenre.horror, JellyGenre.mystery, JellyGenre.thriller],
  ),
  MoodSuggestion(
    key: MoodKey.sciFi,
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFF26C6DA),
    genres: [JellyGenre.sciFi, JellyGenre.fantasy],
  ),
  MoodSuggestion(
    key: MoodKey.thriller,
    icon: Icons.search_rounded,
    color: Color(0xFF5C6BC0),
    genres: [JellyGenre.mystery, JellyGenre.crime, JellyGenre.suspense],
  ),
  MoodSuggestion(
    key: MoodKey.relax,
    icon: Icons.spa_rounded,
    color: Color(0xFF66BB6A),
    genres: [JellyGenre.documentary, JellyGenre.family, JellyGenre.kids],
  ),
  MoodSuggestion(
    key: MoodKey.adventure,
    icon: Icons.explore_rounded,
    color: Color(0xFFFF7043),
    genres: [JellyGenre.adventure, JellyGenre.fantasy, JellyGenre.action],
  ),
];
