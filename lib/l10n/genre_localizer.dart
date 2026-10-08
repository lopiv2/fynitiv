import 'app_localizations.dart';

/// Traduce un género tal como lo entrega Jellyfin al idioma activo.
///
/// Los servidores Jellyfin suelen exponer los géneros en inglés
/// (`Action`, `Science Fiction`, `Sci-Fi & Fantasy`...). Normalizamos el valor
/// (minúsculas, sin acentos, espacios colapsados) y lo resolvemos contra las
/// variantes conocidas (inglés y español). Si no lo reconocemos devolvemos el
/// valor original para no perder información.
String localizeGenre(String? raw, AppLocalizations l10n) {
  final original = raw?.trim() ?? '';
  if (original.isEmpty) return '';
  final resolver = _resolvers[_normalize(original)];
  return resolver?.call(l10n) ?? original;
}

/// Aplica [localizeGenre] a una lista de géneros.
List<String> localizeGenres(Iterable<String> genres, AppLocalizations l10n) =>
    genres.map((g) => localizeGenre(g, l10n)).toList();

String _normalize(String value) {
  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_diacritics[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

const Map<String, String> _diacritics = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

final Map<String, String Function(AppLocalizations)> _resolvers = {
  'action': (l) => l.genreAction,
  'accion': (l) => l.genreAction,
  'adventure': (l) => l.genreAdventure,
  'aventura': (l) => l.genreAdventure,
  'action & adventure': (l) => l.genreActionAdventure,
  'action and adventure': (l) => l.genreActionAdventure,
  'accion y aventura': (l) => l.genreActionAdventure,
  'accion y aventuras': (l) => l.genreActionAdventure,
  'animation': (l) => l.genreAnimation,
  'animacion': (l) => l.genreAnimation,
  'anime': (l) => l.genreAnime,
  'comedy': (l) => l.genreComedy,
  'comedia': (l) => l.genreComedy,
  'crime': (l) => l.genreCrime,
  'crimen': (l) => l.genreCrime,
  'documentary': (l) => l.genreDocumentary,
  'documental': (l) => l.genreDocumentary,
  'drama': (l) => l.genreDrama,
  'family': (l) => l.genreFamily,
  'familia': (l) => l.genreFamily,
  'fantasy': (l) => l.genreFantasy,
  'fantasia': (l) => l.genreFantasy,
  'history': (l) => l.genreHistory,
  'historia': (l) => l.genreHistory,
  'horror': (l) => l.genreHorror,
  'terror': (l) => l.genreHorror,
  'kids': (l) => l.genreKids,
  'infantil': (l) => l.genreKids,
  'music': (l) => l.genreMusic,
  'musica': (l) => l.genreMusic,
  'mystery': (l) => l.genreMystery,
  'misterio': (l) => l.genreMystery,
  'news': (l) => l.genreNews,
  'noticias': (l) => l.genreNews,
  'reality': (l) => l.genreReality,
  'telerrealidad': (l) => l.genreReality,
  'romance': (l) => l.genreRomance,
  'science fiction': (l) => l.genreScienceFiction,
  'ciencia ficcion': (l) => l.genreScienceFiction,
  'sci-fi': (l) => l.genreScienceFiction,
  'sci fi': (l) => l.genreScienceFiction,
  'scifi': (l) => l.genreScienceFiction,
  'sci-fi & fantasy': (l) => l.genreSciFiFantasy,
  'sci fi & fantasy': (l) => l.genreSciFiFantasy,
  'ciencia ficcion y fantasia': (l) => l.genreSciFiFantasy,
  'soap': (l) => l.genreSoap,
  'telenovela': (l) => l.genreSoap,
  'talk show': (l) => l.genreTalkShow,
  'programa de entrevistas': (l) => l.genreTalkShow,
  'thriller': (l) => l.genreThriller,
  'suspense': (l) => l.genreThriller,
  'tv movie': (l) => l.genreTvMovie,
  'pelicula de tv': (l) => l.genreTvMovie,
  'war': (l) => l.genreWar,
  'guerra': (l) => l.genreWar,
  'war & politics': (l) => l.genreWarPolitics,
  'guerra y politica': (l) => l.genreWarPolitics,
  'western': (l) => l.genreWestern,
  'adult': (l) => l.genreAdult,
  'adultos': (l) => l.genreAdult,
};
