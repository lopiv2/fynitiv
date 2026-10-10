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

/// Frases localizadas para presentar cada estado de ánimo.
List<String> moodPhrases(AppLocalizations l10n, MoodKey key) => switch (key) {
  MoodKey.action => [
    l10n.moodAction,
    l10n.moodAction2,
    l10n.moodAction3,
    l10n.moodAction4,
    l10n.moodAction5,
    l10n.moodAction6,
  ],
  MoodKey.comedy => [
    l10n.moodComedy,
    l10n.moodComedy2,
    l10n.moodComedy3,
    l10n.moodComedy4,
    l10n.moodComedy5,
    l10n.moodComedy6,
  ],
  MoodKey.drama => [
    l10n.moodDrama,
    l10n.moodDrama2,
    l10n.moodDrama3,
    l10n.moodDrama4,
    l10n.moodDrama5,
    l10n.moodDrama6,
  ],
  MoodKey.horror => [
    l10n.moodHorror,
    l10n.moodHorror2,
    l10n.moodHorror3,
    l10n.moodHorror4,
    l10n.moodHorror5,
    l10n.moodHorror6,
  ],
  MoodKey.sciFi => [
    l10n.moodSciFi,
    l10n.moodSciFi2,
    l10n.moodSciFi3,
    l10n.moodSciFi4,
    l10n.moodSciFi5,
    l10n.moodSciFi6,
  ],
  MoodKey.thriller => [
    l10n.moodThriller,
    l10n.moodThriller2,
    l10n.moodThriller3,
    l10n.moodThriller4,
    l10n.moodThriller5,
    l10n.moodThriller6,
  ],
  MoodKey.relax => [
    l10n.moodRelax,
    l10n.moodRelax2,
    l10n.moodRelax3,
    l10n.moodRelax4,
    l10n.moodRelax5,
    l10n.moodRelax6,
  ],
  MoodKey.adventure => [
    l10n.moodAdventure,
    l10n.moodAdventure2,
    l10n.moodAdventure3,
    l10n.moodAdventure4,
    l10n.moodAdventure5,
    l10n.moodAdventure6,
  ],
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
